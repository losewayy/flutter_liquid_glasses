import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_materials.dart';
import 'package:flutter_liquid_glasses/src/glass_navigation.dart';
import 'package:flutter_liquid_glasses/src/glass_surface.dart';
import 'package:flutter_liquid_glasses/src/glass_theme.dart';

void main() {
  test('theme changes glass tint without changing optical recipes', () {
    const original = GlassThemeData();
    final changed = original.copyWith(
      composerSurface: const Color.from(
        alpha: .6,
        red: .1,
        green: .2,
        blue: .3,
      ),
      navigationSurface: const Color.from(
        alpha: .7,
        red: .2,
        green: .3,
        blue: .4,
      ),
      commandPaletteSurface: const Color.from(
        alpha: .8,
        red: .3,
        green: .4,
        blue: .5,
      ),
    );
    final factories = [
      GlassMaterials.composer,
      GlassMaterials.navigation,
      GlassMaterials.commandPalette,
    ];
    final surfaces = [
      changed.composerSurface,
      changed.navigationSurface,
      changed.commandPaletteSurface,
    ];
    for (var i = 0; i < factories.length; i++) {
      final before = factories[i](original);
      final after = factories[i](changed);
      final surface = surfaces[i];
      expect(after.params.surfaceColor, [
        surface.r,
        surface.g,
        surface.b,
        surface.a,
      ]);
      expect(after.params.refractionHeight, before.params.refractionHeight);
      expect(after.params.refractionAmount, before.params.refractionAmount);
      expect(after.params.cornerRadius, before.params.cornerRadius);
      expect(after.params.chromatic, before.params.chromatic);
      expect(after.params.saturation, before.params.saturation);
      expect(after.params.highlightAlpha, before.params.highlightAlpha);
      expect(after.blurSigma, before.blurSigma);
      expect(after.outerShadow, before.outerShadow);
      expect(() => after.params.surfaceColor[0] = 0, throwsUnsupportedError);
    }
    final middle = original.lerp(changed, .5);
    expect(
      middle.composerSurface,
      Color.lerp(original.composerSurface, changed.composerSurface, .5),
    );
    expect(
      middle.navigationSurface,
      Color.lerp(original.navigationSurface, changed.navigationSurface, .5),
    );
    expect(
      middle.commandPaletteSurface,
      Color.lerp(
        original.commandPaletteSurface,
        changed.commandPaletteSurface,
        .5,
      ),
    );
  });

  testWidgets(
    'navigation surface takes explicit color, theme token when unset',
    (tester) async {
      const child = Column(
        children: [
          SizedBox(
            width: 275,
            height: 200,
            child: GlassNavigationSurface(
              active: true,
              child: SizedBox.expand(),
            ),
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: GlassSurface(
              key: ValueKey('reduced'),
              reduceTransparency: true,
              drawForeground: false,
            ),
          ),
        ],
      );
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: child)));
      final navigation = find.descendant(
        of: find.byType(GlassNavigationSurface),
        matching: find.byType(GlassSurface),
      );
      // 无显式色时取主题默认 navigationSurface rgba(16,16,20,.68)。
      expect(tester.widget<GlassSurface>(navigation).params.surfaceColor, [
        16 / 255,
        16 / 255,
        20 / 255,
        .68,
      ]);
      // 显式 surfaceColor 优先于主题 token。
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 275,
              height: 200,
              child: GlassNavigationSurface(
                active: true,
                surfaceColor: Color.from(alpha: .5, red: 1, green: 0, blue: 0),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      expect(tester.widget<GlassSurface>(navigation).params.surfaceColor, [
        1.0,
        0.0,
        0.0,
        .5,
      ]);
      // GlassTheme 换掉 navigationSurface → 默认盖面跟着换。
      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: const GlassThemeData(
              navigationSurface: Color.from(
                alpha: .75,
                red: 0,
                green: 1,
                blue: 0,
              ),
              fallbackSurface: Color(0xFF4B0082), // indigo
            ),
            child: const Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<GlassSurface>(navigation).params.surfaceColor, [
        0.0,
        1.0,
        0.0,
        .75,
      ]);
      final reduced = find.byKey(const ValueKey('reduced'));
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: reduced,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color!.a, 1);
      expect(decoration.color!.toARGB32(), const Color(0xFF4B0082).toARGB32());
      expect(
        find.descendant(of: reduced, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(GlassNavigationSurface)),
        const Size(275, 200),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
