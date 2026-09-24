// Shared glass interaction lifecycle regressions.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_params.dart';
import 'package:flutter_liquid_glasses/src/glass_press_surface.dart';
import 'package:flutter_liquid_glasses/src/glass_surface.dart';

Widget _surface({
  bool interactive = true,
  bool disableAnimations = false,
  bool tickerEnabled = true,
  VoidCallback? onTap,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: TickerMode(
      enabled: tickerEnabled,
      child: Center(
        child: GlassPressSurface(
          params: const GlassParams(),
          interactive: interactive,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(width: 240, height: 80),
          ),
        ),
      ),
    ),
  ),
);

double _scale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(glassPressTransformKey))
    .transform
    .storage[0];

double _glow(WidgetTester tester) =>
    tester.widget<GlassSurface>(find.byType(GlassSurface)).params.glowAlpha;

Future<void> _advance(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final muteTicker in [false, true]) {
    testWidgets('motion gate changes during press reset state ($muteTicker)', (
      tester,
    ) async {
      await tester.pumpWidget(_surface());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GlassPressSurface)),
      );
      await _advance(tester);
      expect(_scale(tester), lessThan(0.999));
      await tester.pumpWidget(
        _surface(disableAnimations: !muteTicker, tickerEnabled: !muteTicker),
      );
      expect(_scale(tester), 1);
      expect(_glow(tester), 0);
      expect(tester.binding.transientCallbackCount, 0);
      await gesture.up();
      await tester.pumpWidget(_surface());
      await _advance(tester);
      expect(_scale(tester), 1);
      expect(_glow(tester), 0);
    });
  }

  testWidgets(
    'mouse release retains hover until exit, child still receives tap',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(_surface(onTap: () => taps++));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final center = tester.getCenter(find.byType(GlassPressSurface));
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(center);
      await _advance(tester);
      await mouse.down(center);
      await _advance(tester);
      await mouse.up();
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(taps, 1);
      expect(_scale(tester), 1);
      expect(_glow(tester), greaterThan(0));
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(_glow(tester), 0);
      expect(tester.binding.transientCallbackCount, 0);
      await mouse.removePointer();
    },
  );

  testWidgets('disabling during a press resets geometry and stops animation', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassPressSurface)),
    );
    await _advance(tester);
    expect(_scale(tester), lessThan(0.999));
    await tester.pumpWidget(_surface(interactive: false));
    expect(_scale(tester), 1);
    expect(_glow(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
    await gesture.up();
    await tester.pumpWidget(_surface());
    await _advance(tester);
    expect(_scale(tester), 1);
    expect(_glow(tester), 0);
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'touch ${cancel ? "cancel" : "release"} clears glow and tickers',
      (tester) async {
        await tester.pumpWidget(_surface());
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(GlassPressSurface)),
        );
        await _advance(tester);
        expect(_glow(tester), greaterThan(0));
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        expect(_scale(tester), closeTo(1, 0.0001));
        expect(_glow(tester), 0);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets('reduced motion preserves child taps without spring or glow', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _surface(disableAnimations: true, onTap: () => taps++),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassPressSurface)),
    );
    await _advance(tester);
    expect(_scale(tester), 1);
    expect(_glow(tester), 0);
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a second pointer cannot release the first pointer spring', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    final center = tester.getCenter(find.byType(GlassPressSurface));
    final first = await tester.startGesture(center, pointer: 1);
    await _advance(tester);
    final second = await tester.startGesture(center, pointer: 2);
    await second.up();
    await _advance(tester, 30);
    expect(_scale(tester), lessThan(0.99));
    await first.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(_scale(tester), closeTo(1, 0.0001));
    expect(_glow(tester), 0);
  });

  testWidgets('pointer drag moves glow coordinates towards current pointer', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    final center = tester.getCenter(find.byType(GlassPressSurface));
    final gesture = await tester.startGesture(center);
    await _advance(tester, 10);
    expect(_glow(tester), greaterThan(0));
    final initialParams = tester
        .widget<GlassSurface>(find.byType(GlassSurface))
        .params;
    expect(initialParams.glowX, closeTo(center.dx, 1.0));
    expect(initialParams.glowY, closeTo(center.dy, 1.0));

    final target = center + const Offset(50, 20);
    await gesture.moveTo(target);
    await _advance(tester, 40);
    final movedParams = tester
        .widget<GlassSurface>(find.byType(GlassSurface))
        .params;
    expect(movedParams.glowX, closeTo(target.dx, 1.0));
    expect(movedParams.glowY, closeTo(target.dy, 1.0));

    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(_scale(tester), closeTo(1, 0.0001));
    expect(_glow(tester), 0);
  });

  testWidgets('drag-follow 橡皮筋：按住拖动有位移+方向性形变，松手回位', (tester) async {
    await tester.pumpWidget(_surface());
    final surface = find.byType(GlassPressSurface);
    final center = tester.getCenter(surface);
    final origin = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 240),
    );
    final gesture = await tester.startGesture(center);
    await _advance(tester, 10);

    // 按住向右下拖 60/30：tanh 橡皮筋只让玻璃挪一小段（不是 1:1 贴指针）。
    await gesture.moveTo(center + const Offset(60, 30));
    await _advance(tester, 6);
    final draggedOrigin = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 240),
    );
    final dx = draggedOrigin.dx - origin.dx;
    final dy = draggedOrigin.dy - origin.dy;
    expect(dx, greaterThan(0.3), reason: '橡皮筋跟随必须有位移');
    expect(dx, lessThan(10), reason: 'tanh 饱和：位移远小于拖拽量 60');
    expect(dy, greaterThan(0.1));
    expect(dy, lessThan(6));

    // 拖拽方向的轴拉长（x 主导 → scaleX > scaleY）。
    final transform = tester.widget<Transform>(
      find.byKey(glassPressTransformKey),
    );
    final sx = transform.transform.storage[0];
    final sy = transform.transform.storage[5];
    expect(sx, greaterThan(sy), reason: '横向拖拽应在 x 轴拉伸');

    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(_scale(tester), closeTo(1, 0.0001));
    final settledOrigin = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 240),
    );
    expect(settledOrigin.dx, closeTo(origin.dx, 0.5));
    expect(settledOrigin.dy, closeTo(origin.dy, 0.5));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('unbounded parent first frame produces no NaN transform', (
    tester,
  ) async {
    // Column gives unbounded height → _jelly falls back to _glassSize which
    // is empty on the first build. Without the guard that first frame emits
    // Transform.translate(Offset(NaN, NaN)) and poisons the compositor layer.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              GlassPressSurface(
                params: GlassParams(),
                child: SizedBox(width: 220, height: 56),
              ),
            ],
          ),
        ),
      ),
    );
    for (final t in tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(GlassPressSurface),
        matching: find.byType(Transform),
      ),
    )) {
      for (var i = 0; i < 16; i++) {
        expect(
          t.transform.storage[i].isFinite,
          isTrue,
          reason: 'transform matrix entry $i must be finite',
        );
      }
    }
  });

  testWidgets('dragFollow=false 时按下只有收缩、无位移', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: GlassPressSurface(
            params: const GlassParams(),
            dragFollow: false,
            child: const SizedBox(width: 240, height: 80),
          ),
        ),
      ),
    );
    final surface = find.byType(GlassPressSurface);
    final center = tester.getCenter(surface);
    final origin = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 240),
    );
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(60, 30));
    await _advance(tester, 10);
    final draggedOrigin = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 240),
    );
    // 按压缩放锚点 bottomCenter：左上角会因收缩挪 ~2px（240·0.015/2），
    // 这不是拖拽位移。判据是「位移量 ≪ 拖拽量」——真橡皮筋 60px 拖拽也只挪 ~3px。
    expect(draggedOrigin.dx, closeTo(origin.dx, 3.5));
    expect(draggedOrigin.dy, closeTo(origin.dy, 3.5));
    expect(_scale(tester), lessThan(0.999));
    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
  });
}
