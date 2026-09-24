import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_press_surface.dart';
import 'package:flutter_liquid_glasses/src/glass_surface.dart';
import 'package:flutter_liquid_glasses/src/glass_navigation.dart';

void main() {
  testWidgets('navigation shares one quiet lens without changing layout or taps',
      (tester) async {
    var taps = 0;
    for (final active in [false, true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 275,
            height: 500,
            child: GlassNavigationSurface(
              active: active,
              opaqueBackground: const Color(0xFF161616),
              child: Column(children: [
                TextButton(
                  onPressed: () => taps++,
                  child: const Text('导航'),
                ),
                const Expanded(child: SizedBox()),
              ]),
            ),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(GlassNavigationSurface)),
          const Size(275, 500));
      expect(find.byType(GlassPressSurface), findsNothing);
      if (active) {
        final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
        expect(glass.params.refractionHeight, 14);
        expect(glass.params.refractionAmount, -24);
        // 色散 = 已授权增强项（强度 2× 上游基线）：上游机制存在但各档
        // 未启用——本钉的是"它开着"，不是抄上游档位值。
        expect(glass.params.chromatic, 2.0);
        expect(glass.params.highlightAlpha, 0);
        expect(glass.params.surfaceColor, [16 / 255, 16 / 255, 20 / 255, .68]);
        expect(glass.blurSigma, 0);
        expect(glass.drawForeground, false);
      } else {
        expect(find.byType(GlassSurface), findsNothing);
      }
      await tester.tap(find.text('导航'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(taps, 3);
  });
}
