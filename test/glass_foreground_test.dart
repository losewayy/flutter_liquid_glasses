import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_params.dart';
import 'package:flutter_liquid_glasses/src/glass_press_surface.dart';
import 'package:flutter_liquid_glasses/src/glass_foreground.dart';

void main() {
  testWidgets(
    'normal shader preserves directional lighting and premultiplied alpha',
    (tester) async {
      await tester.runAsync(() async {
        final program = await ui.FragmentProgram.fromAsset(
          'shaders/glass_highlight.frag',
        );
        final shader = program.fragmentShader();
        shader
          ..setFloat(0, 100)
          ..setFloat(1, 80)
          ..setFloat(2, 12)
          ..setFloat(3, 0)
          ..setFloat(4, 1)
          ..setFloat(5, 0.8)
          ..setFloat(6, 0.4)
          ..setFloat(7, 0.2)
          ..setFloat(8, 0.5);
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 100, 80),
          Paint()..shader = shader,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(100, 80);
        final bytes = (await image.toByteData())!;
        for (final x in [0, 99]) {
          final i = (40 * 100 + x) * 4;
          for (var channel = 0; channel < 4; channel++) {
            expect(
              bytes.getUint8(i + channel),
              closeTo([102, 51, 26, 128][channel], 1),
            );
          }
        }
        expect(bytes.getUint8((0 * 100 + 50) * 4 + 3), 0);
        expect(bytes.getUint8((79 * 100 + 50) * 4 + 3), 0);
        image.dispose();
        picture.dispose();
        shader.dispose();
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inner shadow is above content, clipped, and follows shape difference',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const key = ValueKey('inner-shadow');
      for (final offset in [0.0, 8.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: GlassForeground(
                  params: GlassParams(
                    cornerRadius: 10,
                    highlightAlpha: 0,
                    shadowAlpha: 1,
                    shadowOffsetY: offset,
                    shadowBlur: 0,
                  ),
                  child: const SizedBox(
                    width: 100,
                    height: 80,
                    child: ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData())!;
          int red(int x, int y) => bytes.getUint8((y * image.width + x) * 4);
          expect(red(50, 2), offset == 0 ? 255 : 0);
          expect(red(50, 40), 255);
          expect(red(50, 77), 255);
          expect(
            red(0, 0),
            255,
            reason: 'shadow cannot leak outside rounded shape',
          );
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'glass highlight is above opaque content and keeps its inner width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const boundaryKey = ValueKey('glass-pixels');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: GlassPressSurface(
                interactive: false,
                params: GlassParams(
                  cornerRadius: 12,
                  highlightMode: 2,
                  highlightStroke: 1.25,
                  highlightBlur: 0,
                  highlightAlpha: 1,
                ),
                child: SizedBox(
                  width: 100,
                  height: 80,
                  child: ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData())!;
        int red(int x, int y) => bytes.getUint8((y * image.width + x) * 4);
        // Kyant ceil(widthPx) * 2 stroke, clipped inside: two lit rows.
        expect(red(50, 0), greaterThan(245));
        expect(red(50, 1), greaterThan(245));
        expect(red(50, 3), 0);
        expect(red(50, 40), 0);
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    },
  );
}
