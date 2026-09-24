import 'dart:math' as math;

/// Kyant 原版阻尼弹簧——闭式解（非欧拉积分）。
///
/// 移植自 Kyant catalog 的 spring 常数（DampedDragAnimation.kt）：x(t) 用
/// 欠阻尼闭式解，v(t) 为其解析导数。retarget 时以当前 (x,v) 为新初值，
/// 运动连续。
///
/// 参数对照：
/// - 位置弹簧：k=300, ζ=0.5（欠阻尼过冲 → 果冻回摆）
/// - 形变弹簧：k=250, ζX=0.6 / ζY=0.7（两轴阻尼差 → 歪扭感）
/// - 按压弹簧：k=1000, ζ=1.0（临界阻尼，无过冲）
class GlassSpring {
  GlassSpring({required this.k, required this.zeta, double x = 0})
    : _x = x,
      target = x;

  /// 刚度（原版 K 值）。
  final double k;

  /// 阻尼比：<1 欠阻尼（过冲回摆），=1 临界，>1 过阻尼。
  final double zeta;

  double _x;
  double _v = 0;
  double target;

  double get x => _x;
  double get v => _v;

  bool get settled => (_x - target).abs() < 0.003 && _v.abs() < 0.003;

  void setTarget(double t) => target = t;

  /// 直接跳变（无动画初始化）。
  void snap(double value) {
    _x = value;
    _v = 0;
    target = value;
  }

  /// 推进 dt 秒（闭式解求值，非积分）。
  void step(double dt) {
    if (dt <= 0) return;
    final wn = math.sqrt(k);
    final dx = _x - target;
    if (zeta >= 1.0) {
      // 临界/过阻尼：x(t) = target + (dx + (v + wn*dx) t) e^(-wn t)
      final e = math.exp(-wn * dt);
      final b = _v + wn * dx;
      _x = target + (dx + b * dt) * e;
      _v = (b - wn * (dx + b * dt)) * e;
      return;
    }
    final wd = wn * math.sqrt(1 - zeta * zeta);
    final a = dx;
    final b = (_v + zeta * wn * dx) / wd;
    final e = math.exp(-zeta * wn * dt);
    final cosT = math.cos(wd * dt);
    final sinT = math.sin(wd * dt);
    _x = target + e * (a * cosT + b * sinT);
    _v =
        e * ((wd * b - zeta * wn * a) * cosT - (wd * a + zeta * wn * b) * sinT);
  }
}

/// 拖拽速度追踪——环形缓冲 + 最小二乘拟合（与 Kyant catalog 的
/// VelocityTracker 用法对齐）。
///
/// Named `GlassVelocityTracker` to avoid colliding with the class of the same
/// name in `package:flutter/gestures.dart`.
class GlassVelocityTracker {
  static const int _capacity = 20;
  static const double _windowMs = 100;

  final List<({double t, double x})> _samples = [];

  void add(double tMs, double x) {
    _samples.add((t: tMs, x: x));
    if (_samples.length > _capacity) _samples.removeAt(0);
  }

  void reset() => _samples.clear();

  /// 最近 ~100ms 的最小二乘速度（单位/秒）。
  double velocity() {
    if (_samples.length < 2) return 0;
    final newest = _samples.last;
    final cutoff = newest.t - _windowMs;
    final window = _samples.where((s) => s.t >= cutoff).toList();
    if (window.length < 2) return 0;
    var sumT = 0.0, sumX = 0.0;
    for (final s in window) {
      sumT += s.t;
      sumX += s.x;
    }
    final meanT = sumT / window.length;
    final meanX = sumX / window.length;
    var num = 0.0, den = 0.0;
    for (final s in window) {
      num += (s.t - meanT) * (s.x - meanX);
      den += (s.t - meanT) * (s.t - meanT);
    }
    if (den < 1e-9) return 0;
    return num / den * 1000; // px/ms → px/s
  }
}
