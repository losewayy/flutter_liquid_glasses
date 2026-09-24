import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_foreground.dart';
import 'package:flutter_liquid_glasses/src/glass_params.dart';
import 'package:flutter_liquid_glasses/src/glass_press_surface.dart';
import 'package:flutter_liquid_glasses/src/glass_surface.dart';
import 'package:flutter_liquid_glasses/src/reduced_transparency.dart';

void main() {
  testWidgets(
    'reduced transparency uses plain foreground through live toggles',
    (tester) async {
      for (final press in [false, true]) {
        for (final reduced in [false, true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              home: ReducedTransparencyScope(
                reduceTransparency: reduced,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    height: 60,
                    child: press
                        ? const GlassPressSurface(
                            params: GlassParams(highlightMode: 0),
                            child: SizedBox(width: 120, height: 60),
                          )
                        : const GlassSurface(
                            params: GlassParams(highlightMode: 0),
                          ),
                  ),
                ),
              ),
            ),
          );
          final foreground = tester.widget<GlassForeground>(
            find.byType(GlassForeground),
          );
          expect(foreground.params.highlightMode, reduced ? 2 : 0);
          if (reduced) expect(find.byType(BackdropFilter), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  for (final dpr in [1.0, 1.25, 1.75, 2.0]) {
    testWidgets('direct and press surfaces use logical lengths at DPR $dpr', (
      tester,
    ) async {
      const params = GlassParams(cornerRadius: 12, highlightStroke: 2);
      for (final press in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(devicePixelRatio: dpr),
              child: Center(
                child: SizedBox(
                  width: 120,
                  height: 60,
                  child: press
                      ? const GlassPressSurface(
                          params: params,
                          interactive: false,
                          child: SizedBox(width: 120, height: 60),
                        )
                      : const GlassSurface(params: params),
                ),
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<GlassSurface>(find.byType(GlassSurface))
              .params
              .cornerRadius,
          12,
        );
        final foreground = tester.widget<GlassForeground>(
          find.byType(GlassForeground),
        );
        expect(foreground.params.cornerRadius, 12 * dpr);
        expect(foreground.params.highlightStroke, 2 * dpr);
        final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
        expect(clips, isNotEmpty);
        for (final clip in clips) {
          expect(clip.borderRadius, BorderRadius.circular(12));
        }
      }
    });
  }

  testWidgets(
    'fallback preserves dark backdrop and applies requested surface',
    (tester) async {
      for (final alpha in [0.0, 0.5]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color.fromARGB(255, 40, 60, 80)),
                      GlassSurface(
                        drawForeground: false,
                        blurSigma: 0,
                        params: GlassParams(
                          saturation: 1,
                          surfaceColor: [0, 0, 0, alpha],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset = (40 * image!.width + 40) * 4;
        for (var channel = 0; channel < 3; channel++) {
          expect(
            bytes!.getUint8(offset + channel),
            closeTo([40, 60, 80][channel] * (1 - alpha), 1),
          );
        }
        expect(bytes!.getUint8(offset + 3), 255);
        image.dispose();
      }
    },
  );

  testWidgets(
    'reduced transparency disables BackdropFilter and applies opaque bgSurface',
    (tester) async {
      // 1. Direct parameter
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 120,
              height: 60,
              child: GlassSurface(
                reduceTransparency: true,
                params: GlassParams(cornerRadius: 12),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassForeground), findsOneWidget);
      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      expect(
        boxes.any(
          (b) =>
              b.decoration is BoxDecoration &&
              (b.decoration as BoxDecoration).color == Color(0xFF181818),
        ),
        isTrue,
      );

      // 2. Ambient ReducedTransparencyScope
      await tester.pumpWidget(
        const MaterialApp(
          home: ReducedTransparencyScope(
            reduceTransparency: true,
            child: Center(
              child: SizedBox(
                width: 120,
                height: 60,
                child: GlassPressSurface(
                  params: GlassParams(cornerRadius: 12),
                  child: SizedBox(width: 120, height: 60),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassForeground), findsOneWidget);
      final innerGlass = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(innerGlass.reduceTransparency, isTrue);
      expect(innerGlass.params.glowAlpha, 0);

      // 3. Pixel verification: opaque bgSurface completely covers background
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Color(0xFFFF5500),
                    ), // Bright orange background
                    GlassSurface(
                      reduceTransparency: true,
                      drawForeground: false,
                      params: GlassParams(cornerRadius: 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage());
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final centerPixel = (40 * image!.width + 40) * 4;
      // Should match Color(0xFF181818): Color(0xFF181818) -> R=24, G=24, B=24, A=255
      expect(bytes!.getUint8(centerPixel), 24);
      expect(bytes.getUint8(centerPixel + 1), 24);
      expect(bytes.getUint8(centerPixel + 2), 24);
      expect(bytes.getUint8(centerPixel + 3), 255);
      image.dispose();
    },
  );
}
