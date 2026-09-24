import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'glass_params.dart';
import 'glass_foreground.dart';
import 'glass_spring.dart';
import 'glass_surface.dart';
import 'reduced_transparency.dart';

/// 本层的形变矩阵所在节点——测试与调试靠它读实时缩放，
/// 而不是在子树里瞎猜第一个 Transform。
const Key glassPressTransformKey = ValueKey<String>('glass-press-transform');

/// 承载真实液态玻璃 + 指尖跟随 glow + 欠阻尼按压回摆的交互面。
///
/// 物理：Kyant 原值闭式阻尼弹簧，不写关键帧——按住缩到 `1-pressDepth`，松手时
/// 欠阻尼（k=300, ζ=0.5）自己过冲到略大于 1 再回摆，就是那个果冻感。
///
/// 坐标契约：[params] 与指针全局坐标均按逻辑 px 传，GlassSurface 统一转为物理 px。
class GlassPressSurface extends StatefulWidget {
  const GlassPressSurface({
    super.key,
    required this.params,
    required this.child,
    this.blurSigma = 2.0,
    this.pressDepth = 0.015,
    this.glowAlpha = 0.15,
    this.glowRadiusFactor = 1.5,
    this.border,
    this.outerShadow,
    this.interactive = true,
    this.dragFollow = true,
    this.pressLensCoupling = true,
    this.reduceTransparency,
  });

  /// 基础玻璃参数；glow 与几何缩放由本组件覆写。
  final GlassParams params;
  final Widget child;

  /// 底图模糊（逻辑 px）；0 = 纯透玻璃。
  final double blurSigma;

  /// 按住时的收缩量：1 → 1-pressDepth（松手回弹过冲由弹簧给出）。
  final double pressDepth;

  /// frag 注释的原始强度：`u_glow_alpha = 0.15 * pressProgress`。
  final double glowAlpha;

  /// 指尖光半径 = 短边 × 此系数（原 onDrawSurface 实现是 minDim*1.5）。
  final double glowRadiusFactor;

  /// 发丝描边（可选）；菲涅尔边缘已由 shader 画，这里只补结构线。
  final BoxBorder? border;

  // Logical pixels, independent of the shader's inner-shadow parameters.
  final BoxShadow? outerShadow;

  /// false = 仍出真玻璃，但不响应指针与按压（禁用态不许假装可交互）。
  final bool interactive;

  /// 按下拖动时的橡皮筋跟随 + 方向性 squash-stretch（Kyant LiquidButton 的
  /// layerBlock：translation = minDim·tanh(0.05·offset/minDim)，轴向拉伸与
  /// 拖拽方向同号）。false 时只保留按压缩放与指尖光——供 composer 这类内部
  /// 有文本选择/滚动的面关掉，避免拖动冲突。
  final bool dragFollow;

  /// 按压时透镜锐化（Kyant catalog：lens(h·p, a·p) + blur·(1−p)）——按下去
  /// 玻璃变薄、折射带收窄、模糊收敛，松开弹簧带回。false = 折射参数恒定。
  final bool pressLensCoupling;

  /// 减少透明度硬关断（预设或环境触发）：关断指尖高光并强制底面为实底。
  final bool? reduceTransparency;

  @override
  State<GlassPressSurface> createState() => _GlassPressSurfaceState();
}

class _GlassPressSurfaceState extends State<GlassPressSurface>
    with SingleTickerProviderStateMixin {
  final _press = GlassSpring(k: 300, zeta: 0.5);
  final _glowX = GlassSpring(k: 300, zeta: 0.5);
  final _glowY = GlassSpring(k: 300, zeta: 0.5);

  /// glow 出现/消失用临界阻尼：透明度过冲会先亮爆再回落，看着像闪灯。
  final _presence = GlassSpring(k: 400, zeta: 1.0);

  /// 拖拽位移两轴——Kyant catalog scale 弹簧族：ζX=0.6 / ζY=0.7, k=250
  /// （两轴阻尼差给出歪扭的果冻回摆；位移本身拖拽时是 1:1 瞬时值，弹簧只管回位）。
  final _dragX = GlassSpring(k: 250, zeta: 0.6);
  final _dragY = GlassSpring(k: 250, zeta: 0.7);
  final _dragVel = GlassVelocityTracker();

  Ticker? _ticker;
  Duration _last = Duration.zero;
  int? _activePointer;

  /// 内层 LayoutBuilder 回填的真实尺寸（外层 LayoutBuilder 的约束在宽松
  /// 父级下是无限的，而 jelly 需要真实宽高算 tanh 归一化）。
  Size? _glassSize;
  Offset _dragOrigin = Offset.zero; // pointer-local 按下点
  bool _mouseInside = false;
  bool _motionEnabled = true;
  bool _reduceTransparency = false;

  bool get _interactive => widget.interactive && _motionEnabled;

  void _resetInteraction() {
    _activePointer = null;
    _mouseInside = false;
    _dragOrigin = Offset.zero;
    _press.snap(0);
    _presence.snap(0);
    _glowX.snap(0);
    _glowY.snap(0);
    _dragX.snap(0);
    _dragY.snap(0);
    _ticker?.stop();
    _last = Duration.zero;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _reduceTransparency =
        widget.reduceTransparency ?? ReducedTransparencyScope.of(context);
    if (!_interactive) _resetInteraction();
  }

  @override
  void didUpdateWidget(covariant GlassPressSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduceTransparency =
        widget.reduceTransparency ?? ReducedTransparencyScope.of(context);
    if (!_interactive) _resetInteraction();
  }

  @override
  void deactivate() {
    _resetInteraction();
    super.deactivate();
  }

  bool get _settled =>
      _press.settled &&
      _glowX.settled &&
      _glowY.settled &&
      _presence.settled &&
      _dragX.settled &&
      _dragY.settled;

  void _wake() {
    final t = _ticker ??= createTicker(_onTick);
    if (!t.isActive) t.start();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) return;
    _press.step(dt);
    _glowX.step(dt);
    _glowY.step(dt);
    _presence.step(dt);
    _dragX.step(dt);
    _dragY.step(dt);
    if (_settled) {
      _press.snap(_press.target);
      _glowX.snap(_glowX.target);
      _glowY.snap(_glowY.target);
      _presence.snap(_presence.target);
      _dragX.snap(_dragX.target);
      _dragY.snap(_dragY.target);
      _ticker?.stop();
      _last = Duration.zero;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _enter(Offset global) {
    // 首次进入直接把指尖光放到指针上：从 0,0 飞过来会看到一团光划过。
    _glowX.snap(global.dx);
    _glowY.snap(global.dy);
    _presence.setTarget(1);
    _wake();
  }

  void _hover(Offset global) {
    _glowX.setTarget(global.dx);
    _glowY.setTarget(global.dy);
    _wake();
  }

  void _exit() {
    _mouseInside = false;
    if (_activePointer == null) {
      _presence.setTarget(0);
      _press.setTarget(0);
      _wake();
    }
  }

  void _pressed(bool down) {
    _press.setTarget(down ? 1 : 0);
    _wake();
  }

  void _pointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _dragOrigin = event.localPosition;
    _dragVel.reset();
    _dragVel.add(event.timeStamp.inMilliseconds.toDouble(), 0);
    _dragX.snap(0);
    _dragY.snap(0);
    _enter(event.position);
    _pressed(true);
  }

  void _pointerMove(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    _hover(event.position);
    if (!widget.dragFollow) return;
    final delta = event.localPosition - _dragOrigin;
    _dragX.snap(delta.dx);
    _dragY.snap(delta.dy);
    _dragVel.add(event.timeStamp.inMilliseconds.toDouble(), delta.dx);
    setState(() {});
  }

  void _pointerEnd(PointerEvent event, {bool cancelled = false}) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _press.setTarget(0);
    // 松手：拖拽位移弹簧回零。松手瞬间的速度喂进拉伸轴——Kyant 用
    // velocity 直接调 scaleX/scaleY，回弹过冲由欠阻尼弹簧给出。
    _dragX.setTarget(0);
    _dragY.setTarget(0);
    _presence.setTarget(
      !cancelled && event.kind == PointerDeviceKind.mouse && _mouseInside
          ? 1
          : 0,
    );
    _wake();
  }

  GlassParams _live(double w, double h) {
    final p = widget.params;
    // 按压透镜耦合（Kyant catalog LiquidSlider/LiquidToggle：lens(h·p, a·p)
    // + blur·(1−p) 的一半——折射带随按下收窄，玻璃「变薄」）。
    GlassParams base = p;
    if (widget.pressLensCoupling && _interactive && !_reduceTransparency) {
      final prog = _press.x;
      if (prog > 0.001 && p.refractionHeight > 0) {
        final t = (1 - 0.6 * prog).clamp(0.3, 1.0);
        base = p.copyWith(
          refractionHeight: p.refractionHeight * t,
          refractionAmount: p.refractionAmount * t,
        );
      }
    }
    if (!_interactive || _reduceTransparency) {
      return base.copyWith(glowAlpha: 0);
    }
    final alpha = widget.glowAlpha * _presence.x;
    if (alpha <= 0.001) return base.copyWith(glowAlpha: 0);
    return base.copyWith(
      glowX: _glowX.x,
      glowY: _glowY.x,
      glowRadius: w < h
          ? w * widget.glowRadiusFactor
          : h * widget.glowRadiusFactor,
      glowAlpha: alpha,
    );
  }

  /// Kyant LiquidButton layerBlock：translation = minDim·tanh(0.05·offset/minDim)
  /// （原点斜率 0.05 的饱和橡皮筋），轴向 squash-stretch 与拖拽方向同号，
  /// 松手速度再喂一次过冲。返回 (translate, scaleX, scaleY)。
  /// 按压缩放不受 dragFollow 控制——它是独立的 press 通道。
  ({double dx, double dy, double sx, double sy}) _jelly(Size size) {
    final pressScale = 1 - widget.pressDepth * _press.x;
    if (!widget.dragFollow || !_interactive || _reduceTransparency) {
      return (dx: 0, dy: 0, sx: pressScale, sy: pressScale);
    }
    // 宽松父级（Column 等）首帧拿不到真实尺寸——_glassSize 还没回填。
    // 0 宽高的 tanh 归一化会除零出 NaN，NaN 偏移进 Transform 会毒化整个
    // 合成层，必须按无形变处理。
    if (!size.isFinite || size.isEmpty) {
      return (dx: 0, dy: 0, sx: pressScale, sy: pressScale);
    }
    final drag = Offset(_dragX.x, _dragY.x);
    final pressed = _activePointer != null;
    // 松手后位移弹簧还在回位，同样过 tanh——回摆沿同一条橡皮筋曲线。
    final minDim = size.shortestSide;
    final maxDim = size.longestSide;
    final maxOffset = minDim;
    const kDeriv = 0.05;
    final tx = maxOffset * _tanh(kDeriv * drag.dx / maxOffset);
    final ty = maxOffset * _tanh(kDeriv * drag.dy / maxOffset);

    // 方向性形变：拖拽方向的轴拉长 4dp/高，正交轴反向微缩。
    final maxDragScale = 4.0 / size.height;
    final angle = math.atan2(drag.dy, drag.dx);
    var sx =
        pressScale +
        maxDragScale *
            (math.cos(angle) * drag.dx / maxDim).abs() *
            (size.width / size.height).clamp(0.0, 1.0);
    var sy =
        pressScale +
        maxDragScale *
            (math.sin(angle) * drag.dy / maxDim).abs() *
            (size.height / size.width).clamp(0.0, 1.0);
    // 松手速度过冲（LiquidBottomTabs: scaleX /= 1−v·0.75, scaleY *= 1−v·0.25，
    // v 归一化到 ±0.2）。我们的 v 是 px/s，除 2500 近似归一。
    if (!pressed) {
      final v = (_dragVel.velocity() / 2500).clamp(-0.2, 0.2);
      sx /= 1 - v * 0.75;
      sy *= 1 - v * 0.25;
    }
    return (dx: tx, dy: ty, sx: sx, sy: sy);
  }

  static double _tanh(double x) {
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final radius = widget.params.cornerRadius;
    final corners = BorderRadius.circular(radius);
    final outerShadow = widget.outerShadow;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Center 这类宽松父级给无限约束；真实尺寸由 Positioned.fill 里的
        // 内层 LayoutBuilder 回填到 _glassSize（首帧为空时按无拖拽处理）。
        final jelly = _jelly(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight
              ? constraints.biggest
              : (_glassSize ?? Size.zero),
        );
        return Transform.translate(
          offset: Offset(jelly.dx, jelly.dy),
          child: Transform.scale(
            key: glassPressTransformKey,
            scaleX: jelly.sx,
            scaleY: jelly.sy,
            alignment: Alignment.bottomCenter,
            child: MouseRegion(
              onEnter: _interactive
                  ? (e) {
                      _mouseInside = true;
                      if (_activePointer == null) _enter(e.position);
                    }
                  : null,
              onHover: _interactive
                  ? (e) {
                      if (_activePointer == null) _hover(e.position);
                    }
                  : null,
              onExit: _interactive ? (_) => _exit() : null,
              child: Listener(
                // 用 Listener 而不是 GestureDetector：材质要对「按下」出果冻反馈，但绝不该
                // 参与手势竞技场。TapGestureRecognizer 在按下时还没赢（内层输入框会赢），
                // 反馈就永远不来；Listener 只读原始指针，事件仍完整交给子节点。
                behavior: HitTestBehavior.translucent,
                onPointerDown: _interactive ? _pointerDown : null,
                onPointerMove: _interactive ? _pointerMove : null,
                onPointerUp: _interactive ? _pointerEnd : null,
                onPointerCancel: _interactive
                    ? (e) => _pointerEnd(e, cancelled: true)
                    : null,
                child: CustomPaint(
                  painter: outerShadow == null
                      ? null
                      : _GlassOuterShadowPainter(radius, outerShadow),
                  child: GlassForeground(
                    params:
                        (_reduceTransparency
                                ? widget.params.copyWith(highlightMode: 2)
                                : widget.params)
                            .toPhysical(dpr),
                    child: Stack(
                      children: [
                        // 玻璃层：Stack 由下面的内容定尺寸，这里才拿到真实短边（写在本层
                        // 的 LayoutBuilder 里，避免用父级那套「整块聊天区」的假高度）。
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _glassSize = constraints.biggest;
                              return GlassSurface(
                                params: _live(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                blurSigma: widget.blurSigma,
                                drawForeground: false,
                                reduceTransparency: _reduceTransparency,
                              );
                            },
                          ),
                        ),
                        if (widget.border != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: corners,
                                  border: widget.border,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ClipRRect(borderRadius: corners, child: widget.child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassOuterShadowPainter extends CustomPainter {
  const _GlassOuterShadowPainter(this.radius, this.shadow);

  final double radius;
  final BoxShadow shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || shadow.color.a == 0) return;
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final cast = shape.shift(shadow.offset).inflate(shadow.spreadRadius);
    final bounds = shape.outerRect.expandToInclude(
      cast.outerRect.inflate(shadow.blurSigma * 4 + 1),
    );
    // Kyant: blur the offset silhouette, then clear the original shape.
    // Isolate Clear so it cannot erase the scene. A normal BoxDecoration
    // leaves a solid shadow underneath translucent glass and darkens its input.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRRect(cast, shadow.toPaint());
    canvas.drawRRect(shape, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassOuterShadowPainter oldDelegate) =>
      radius != oldDelegate.radius || shadow != oldDelegate.shadow;
}
