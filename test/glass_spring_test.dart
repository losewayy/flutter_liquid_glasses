import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_liquid_glasses/src/glass_spring.dart';

void main() {
  group('GlassSpring — 闭式阻尼弹簧', () {
    test('欠阻尼（ζ=0.5）：过冲后收敛到 target', () {
      final s = GlassSpring(k: 300, zeta: 0.5)..setTarget(100);
      var overshot = false;
      for (var i = 0; i < 300; i++) {
        s.step(1 / 60);
        if (s.x > 100.5) overshot = true;
      }
      expect(overshot, isTrue, reason: '欠阻尼应过冲');
      expect(s.x, closeTo(100, 0.5), reason: '应收敛到 target');
      expect(s.settled, isTrue);
    });

    test('临界阻尼（ζ=1.0）：不过冲直接收敛', () {
      final s = GlassSpring(k: 1000, zeta: 1.0)..setTarget(50);
      for (var i = 0; i < 300; i++) {
        s.step(1 / 60);
        expect(s.x, lessThanOrEqualTo(50.01), reason: '临界阻尼不应过冲');
      }
      expect(s.x, closeTo(50, 0.5));
    });

    test('retarget 保持运动连续（速度不断崖）', () {
      final s = GlassSpring(k: 300, zeta: 0.5)..setTarget(100);
      for (var i = 0; i < 20; i++) {
        s.step(1 / 60);
      }
      final vBefore = s.v;
      s.setTarget(200);
      s.step(0.001);
      expect(s.v, closeTo(vBefore, 50), reason: 'retarget 后速度应连续');
    });

    test('snap 立即跳变且静止', () {
      final s = GlassSpring(k: 300, zeta: 0.5)..snap(42);
      expect(s.x, 42);
      expect(s.v, 0);
      expect(s.settled, isTrue);
    });
  });

  group('GlassVelocityTracker — 最小二乘速度', () {
    test('匀速运动还原速度', () {
      final t = GlassVelocityTracker();
      // 500px/s 匀速：每 16ms 走 8px
      for (var i = 0; i < 10; i++) {
        t.add(i * 16.0, i * 8.0);
      }
      expect(t.velocity(), closeTo(500, 1));
    });

    test('反向运动给负速度', () {
      final t = GlassVelocityTracker();
      for (var i = 0; i < 10; i++) {
        t.add(i * 16.0, 100 - i * 8.0);
      }
      expect(t.velocity(), closeTo(-500, 1));
    });

    test('静止为 0', () {
      final t = GlassVelocityTracker();
      for (var i = 0; i < 10; i++) {
        t.add(i * 16.0, 50.0);
      }
      expect(t.velocity(), closeTo(0, 0.001));
    });

    test('样本不足返回 0 不崩', () {
      final t = GlassVelocityTracker();
      expect(t.velocity(), 0);
      t.add(0, 10);
      expect(t.velocity(), 0);
    });
  });
}
