import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'glass_spring.dart' show GlassSpring, GlassVelocityTracker;

/// 可拖走的液态表面（toast 消隐同款交互）：
///
/// - 水平拖动 1:1 跟随；
/// - 速度耦合 squash-stretch：拖向拉伸 ≤10%、垂向压扁 ≤6%；松手瞬间速度再喂
///   一次过冲（Kyant LiquidBottomTabs：scaleX /= 1−v·0.75、scaleY *= 1−v·0.25）；
/// - 松手 |dx|>80 或 |v|>0.5px/ms（=500px/s）→ 180ms fling 甩出 + onDismissed；
/// - 否则欠阻尼弹簧回位（k=350, ζ=0.75，与上游同参）；
/// - `prefers-reduced-motion`：不演弹簧，阈值判定立即生效。
///
/// 用 [Listener] 而不是手势竞技场：卡片里还有按钮要赢 tap，
/// 拖拽只对「按下后真的在水平挪」的指针生效。
class LiquidSwipeSurface extends StatefulWidget {
  const LiquidSwipeSurface({
    super.key,
    required this.child,
    this.onDismissed,
    this.enabled = true,
  });

  final Widget child;

  /// 甩出完成后的回调（toast 消隐等）。只在 fling 结束时触发一次。
  final VoidCallback? onDismissed;

  /// false 时完全透传子树，不接管指针。
  final bool enabled;

  @override
  State<LiquidSwipeSurface> createState() => _LiquidSwipeSurfaceState();
}

class _LiquidSwipeSurfaceState extends State<LiquidSwipeSurface>
    with SingleTickerProviderStateMixin {
  // 回位弹簧 = 上游 stiffness 350 / ζ 0.75（欠阻尼、明显回摆的果冻感）。
  final _x = GlassSpring(k: 350, zeta: 0.75);
  final _stretch = GlassSpring(k: 350, zeta: 0.75);
  final _vel = GlassVelocityTracker();

  Ticker? _ticker;
  Duration _last = Duration.zero;
  int? _pointer;
  double _downDx = 0;
  bool _motionEnabled = true;

  // fling 甩出：上游是 180ms 的线性离场，不走弹簧。
  bool _flinging = false;
  double _flingT = 0;
  double _flingStart = 0;
  double _flingEnd = 0;
  bool _dismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _wake() {
    final t = _ticker ??= createTicker(_onTick);
    if (!t.isActive) t.start();
  }

  double get _stretchAmount =>
      (_vel.velocity().abs() / 2000).clamp(0.0, 1.0);

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _dismissed || _pointer != null) return;
    _pointer = event.pointer;
    _downDx = _x.x;
    _vel.reset();
    _vel.add(event.timeStamp.inMilliseconds.toDouble(), _x.x);
    _flinging = false;
    _ticker?.stop();
    _last = Duration.zero;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _dismissed) return;
    final next = _x.x + event.delta.dx;
    _x.snap(next);
    _vel.add(event.timeStamp.inMilliseconds.toDouble(), next);
    _stretch.snap(_stretchAmount);
    setState(() {});
  }

  void _onPointerEnd(PointerEvent event, {required bool cancelled}) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    if (_dismissed) return;
    final v = _vel.velocity();
    final dx = _x.x - _downDx;
    // 上游阈值：位移 80px 或速度 0.5px/ms（500px/s），取方向一致的判定；
    // 取消（指针被系统抢走）不视为用户甩走，只回位。
    final shouldDismiss =
        !cancelled && (dx.abs() > 80 || v.abs() > 500);
    if (!shouldDismiss) {
      _springBack();
      return;
    }
    if (!_motionEnabled) {
      _finishDismiss();
      return;
    }
    // fling：沿当前位移/速度方向甩出屏幕外。
    final dir = dx != 0 ? dx.sign : (v != 0 ? v.sign : 1.0);
    _flinging = true;
    _flingT = 0;
    _flingStart = _x.x;
    _flingEnd =
        dir * (MediaQuery.sizeOf(context).width + (context.size?.width ?? 0));
    _stretch.setTarget(0);
    _wake();
  }

  void _springBack() {
    if (!_motionEnabled) {
      _x.snap(0);
      _stretch.snap(0);
      setState(() {});
      return;
    }
    _x.setTarget(0);
    _stretch.setTarget(0);
    _wake();
  }

  void _finishDismiss() {
    _dismissed = true;
    _ticker?.stop();
    widget.onDismissed?.call();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    if (_flinging) {
      _flingT += dt;
      final p = (_flingT / 0.18).clamp(0.0, 1.0);
      // ease-in 甩出：起步已有初速度观感，尾段加速离场。
      final eased = p * p;
      _x.snap(_flingStart + (_flingEnd - _flingStart) * eased);
      _stretch.step(dt);
      if (p >= 1) {
        _finishDismiss();
        return;
      }
    } else {
      _x.step(dt);
      _stretch.step(dt);
      if (_x.settled && _stretch.settled) {
        _x.snap(_x.target);
        _stretch.snap(_stretch.target);
        _ticker?.stop();
        _last = Duration.zero;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final stretch = _stretch.x;
    // Kyant LiquidBottomTabs/Toggle 的松手速度耦合：scaleX /= 1−v·0.75、
    // scaleY *= 1−v·0.25（v 归一化到 ±0.2）。我们的 v 是 px/s，除 2500 归一；
    // 拖拽中的基础 squash 仍是 _stretch（速度/2000）。
    final v = (_vel.velocity() / 2500).clamp(-0.2, 0.2);
    final sx = (1 + 0.10 * stretch) / (1 - v * 0.75);
    final sy = (1 - 0.06 * stretch) * (1 - v * 0.25);
    return Transform.translate(
      offset: Offset(_x.x, 0),
      child: Transform.scale(
        scaleX: sx,
        scaleY: sy,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (e) => _onPointerEnd(e, cancelled: false),
          onPointerCancel: (e) => _onPointerEnd(e, cancelled: true),
          child: widget.child,
        ),
      ),
    );
  }
}
