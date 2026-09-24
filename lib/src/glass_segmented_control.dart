import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'glass_params.dart';
import 'glass_spring.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// One option in a [GlassSegmentedControl].
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Capsule segmented control with a refractive glass thumb, ported from
/// Kyant's `LiquidBottomTabs` + `DampedDragAnimation`.
///
/// The jelly feel is upstream's, not a generic squash:
///
/// - **Press** — the thumb inflates to `78/64 × trackHeight` on two springs
///   with *different* damping (scaleX ζ=0.6, scaleY ζ=0.7); the asymmetric
///   settling is the wobble. Its lens/highlight/shadow grow in with
///   pressProgress, so an idle thumb is a flat pill and a held thumb is a
///   live lens protruding past the track with a dispersion fringe.
/// - **Drag** — position chases the pointer through a *critically damped*
///   spring (ζ=1, k=1000): smooth trailing, no positional overshoot. The
///   animated position feeds a least-squares velocity tracker, normalized by
///   `segments.length - 1` and spring-smoothed (ζ=0.5, k=300) into
///   `scaleX /= 1−v·0.75`, `scaleY *= 1−v·0.25`. Tracking stops on release —
///   taps glide without stretch, only drags deform.
/// - **Release** — the press holds until the thumb settles within 0.02
///   index units of the target, then relaxes.
/// - **Layering** — the track is a glass capsule; labels sit above it; the
///   thumb is topmost so its lens refracts the label beneath it (the local
///   "puffed" look). The track's own `1 + 16px/width` press scale applies
///   to track + labels only, never to the thumb.
///
/// Controlled component: [onChanged] must update [selected] in the parent,
/// the same contract as [Switch]/[Slider].
class GlassSegmentedControl<T> extends StatefulWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    this.onChanged,
    this.blurSigma = 2.0,
    this.height = 36,
    this.inset = 3,
    this.enabled = true,
  }) : assert(segments.length >= 2);

  final List<GlassSegment<T>> segments;

  /// Currently selected value; must be one of [segments].value.
  final T selected;

  final ValueChanged<T>? onChanged;

  /// Backdrop blur behind the track glass (logical px). The thumb is
  /// unblurred, faithful to upstream (indicator has lens only, no blur()).
  final double blurSigma;

  final double height;

  /// Track padding around the thumb, in logical px.
  final double inset;

  /// false → ignores pointers and dims the labels.
  final bool enabled;

  @override
  State<GlassSegmentedControl<T>> createState() =>
      _GlassSegmentedControlState<T>();
}

class _GlassSegmentedControlState<T> extends State<GlassSegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  // Upstream spring specs (DampedDragAnimation.kt), in segment-index units:
  //   value:     ζ=1.0  k=1000 (critical — position never overshoots)
  //   velocity:  ζ=0.5  k=300  (spring-smoothed tracker output)
  //   press:     ζ=1.0  k=1000
  //   scaleX/Y:  ζ=0.6 / ζ=0.7, k=250 (the two-axis damping gap IS the jelly)
  //   panel:     ζ=1.0  k=300  (offsetAnimation → 0 on release)
  final _pos = GlassSpring(k: 1000, zeta: 1.0);
  final _vel = GlassSpring(k: 300, zeta: 0.5);
  final _press = GlassSpring(k: 1000, zeta: 1.0);
  final _scaleX = GlassSpring(k: 250, zeta: 0.6, x: 1);
  final _scaleY = GlassSpring(k: 250, zeta: 0.7, x: 1);
  final _panel = GlassSpring(k: 300, zeta: 1.0);
  final _velTracker = GlassVelocityTracker();

  Ticker? _ticker;
  Duration _last = Duration.zero;
  int? _pointer;
  double _downX = 0;
  double _dragStartIndex = 0;
  bool _dragging = false;
  bool _holdingPress = false;
  bool _motionEnabled = true;

  int get _selectedIndex {
    final i = widget.segments.indexWhere((s) => s.value == widget.selected);
    return i < 0 ? 0 : i;
  }

  /// valueRange span — upstream normalizes tracked velocity by
  /// `tabsCount - 1` (valueRange = 0..(count-1)).
  double get _span => (widget.segments.length - 1).toDouble();

  static const _slopPx = 4.0;

  @override
  void initState() {
    super.initState();
    _pos.snap(_selectedIndex.toDouble());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(covariant GlassSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _selectedIndex.toDouble();
    if (!_dragging && _pos.target != index) {
      // setTabSelected (tap/programmatic): velocity reset → no stretch.
      _velTracker.reset();
      _vel.snap(0);
      _animateTo(index);
    }
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

  /// Upstream: pressed thumb is 78dp tall inside a 64dp container
  /// (78/56 on the 56dp thumb). Generalized: pressed thumb height =
  /// (78/64) × track height → `s = (78/64)·h / (h − 2·inset)`.
  double get _pressedScale => (78 / 64) * widget.height / _thumbH;

  double get _thumbH => widget.height - widget.inset * 2;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _downX = event.localPosition.dx;
    _dragging = false;
    _velTracker.reset();
    _vel.snap(0); // press() → velocityTracker.resetTracking() + velocity = 0
    if (!_motionEnabled) return;
    // Upstream press(): inflate + pressProgress, while position stays put.
    _press.setTarget(1);
    final s = _pressedScale;
    _scaleX.setTarget(s);
    _scaleY.setTarget(s);
    _wake();
  }

  void _onPointerMove(PointerMoveEvent event, double segW) {
    if (_pointer != event.pointer || !widget.enabled || segW <= 0) return;
    final totalDx = event.localPosition.dx - _downX;
    if (!_dragging && totalDx.abs() < _slopPx) return;
    if (!_dragging) {
      // Drag begins: target index at drag start, velocity tracking restarts.
      _dragging = true;
      _dragStartIndex = _pos.target;
      _velTracker.reset();
    }
    final n = _span;
    // Position target = startIndex + totalDx/tabWidth; the critical spring
    // supplies the trailing lag. Panel rubber-band: ≤4px spring target,
    // EaseOut(|Δx| / maxWidth) shaped (quadratic, upstream).
    final target = (_dragStartIndex + totalDx / segW).clamp(0.0, n);
    final frac = (totalDx / (segW * widget.segments.length)).clamp(-1.0, 1.0);
    final eased = 1 - (1 - frac.abs()) * (1 - frac.abs());
    _panel.setTarget(4.0 * frac.sign * eased);
    if (_motionEnabled) {
      _pos.setTarget(target);
    } else {
      _pos.snap(target);
    }
    _wake();
    setState(() {});
  }

  void _onPointerEnd(
    PointerEvent event,
    double segW, {
    required bool cancelled,
  }) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _panel.setTarget(0);
    // endTabDrag: tracker reset, no post-release tracking — the velocity
    // spring decays to 0 on its own (residual wobble, no new stretch).
    _velTracker.reset();
    _vel.setTarget(0);

    if (!_dragging && !cancelled && segW > 0) {
      final i = ((event.localPosition.dx - widget.inset) / segW).floor().clamp(
        0,
        widget.segments.length - 1,
      );
      _select(i);
      _animateTo(i.toDouble());
      return;
    }
    _dragging = false;
    final target = _pos.target.round().clamp(0, widget.segments.length - 1);
    _select(target);
    _animateTo(target.toDouble());
  }

  void _select(int index) {
    final value = widget.segments[index].value;
    if (value != widget.selected) widget.onChanged?.call(value);
  }

  /// Upstream animateToValue: press → move → hold press until near target.
  /// Taps zero the velocity (no stretch on programmatic/tap moves).
  void _animateTo(double index) {
    _panel.setTarget(0);
    if (!_motionEnabled) {
      _pos.snap(index);
      _press.snap(0);
      _scaleX.snap(1);
      _scaleY.snap(1);
      _vel.snap(0);
      setState(() {});
      return;
    }
    if (_press.target == 0 && _press.x < 0.5) {
      final s = _pressedScale;
      _press.setTarget(1);
      _scaleX.setTarget(s);
      _scaleY.setTarget(s);
    }
    _holdingPress = true;
    _pos.setTarget(index);
    _wake();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) return;
    final tMs = elapsed.inMicroseconds / 1e3;

    _pos.step(dt);
    // Velocity tracking — faithful to DampedDragAnimation.updateVelocity():
    // the tracker sees the ANIMATED position, normalized by the value-range
    // span, and only while dragging. After release the spring decays to 0.
    if (_dragging) {
      _velTracker.add(tMs, _pos.x);
      _vel.setTarget(_velTracker.velocity() / _span);
    }
    _vel.step(dt);
    _panel.step(dt);

    // Upstream release(): press holds until within 0.02 of the target index.
    if (_holdingPress && !_dragging && (_pos.x - _pos.target).abs() < 0.02) {
      _holdingPress = false;
      _press.setTarget(0);
      _scaleX.setTarget(1);
      _scaleY.setTarget(1);
    }

    _press.step(dt);
    _scaleX.step(dt);
    _scaleY.step(dt);

    if (_pos.settled &&
        _vel.settled &&
        _press.settled &&
        _scaleX.settled &&
        _scaleY.settled &&
        _panel.settled) {
      _pos.snap(_pos.target);
      _vel.snap(0);
      _panel.snap(0);
      _ticker?.stop();
      _last = Duration.zero;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final h = widget.height;
    final inset = widget.inset;
    final p = _press.x.clamp(0.0, 1.0);
    final hs = h / 64; // upstream geometry is authored at 64dp container height

    // Track glass — upstream container Row: vibrancy + blur(8dp) +
    // lens(24dp, 24dp), Highlight.Default(0.5), Shadow.Default, 0.4 surface.
    final mc = theme.menuSurface;
    final trackParams = GlassParams(
      cornerRadius: h / 2,
      refractionHeight: 24 * hs,
      refractionAmount: -24 * hs,
      depthEffect: 1,
      saturation: 1.5,
      surfaceColor: [mc.r, mc.g, mc.b, 0.4],
      highlightAlpha: 0.5,
      highlightStroke: 0.5,
      shadowAlpha: 0.1,
      shadowBlur: 24 * hs,
      shadowOffsetY: 4 * hs,
    );

    // Thumb — upstream indicator: lens(10dp·p, 14dp·p, chromatic=true),
    // no blur, no vibrancy; highlight/shadow/dim all modulated by p.
    // onDrawSurface draws two rects — dim@0.10·(1−p) then black@0.03·p —
    // folded here into a single surface overlay (gray value lerps with p).
    final wa = 0.10 * (1 - p);
    final ba = 0.03 * p;
    final sa = wa + ba;
    final srgb = sa > 0 ? wa / sa : 1.0;
    final thumbParams = GlassParams(
      cornerRadius: _thumbH / 2,
      refractionHeight: 10 * hs * p,
      refractionAmount: -14 * hs * p,
      chromatic: p,
      saturation: 1.0,
      surfaceColor: [srgb, srgb, srgb, sa],
      highlightStroke: 0.5,
      highlightAlpha: .5 * p,
      shadowAlpha: .1 * p,
      shadowBlur: 24 * hs,
      shadowOffsetY: 4 * hs,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return SizedBox(height: h);
        }
        final segW = (width - inset * 2) / widget.segments.length;
        // Upstream velocity coupling: v = velocity/10, then
        // scaleX /= 1−v·0.75, scaleY *= 1−v·0.25, clamped ±0.2.
        final v = (_vel.x / 10).clamp(-0.2, 0.2);
        final sx = _scaleX.x / (1 - v * 0.75);
        final sy = _scaleY.x * (1 - v * 0.25);
        final thumbX = inset + _pos.x * segW + _panel.x;
        final active = _pos.x.round().clamp(0, widget.segments.length - 1);
        // Container press scale: applies to track + labels, NOT the thumb
        // (upstream indicator is a sibling of the container, not a child).
        final containerScale = 1 + (16 / width) * p;
        final contentScale = containerScale * (1 + 0.2 * p);
        final panelShift = _panel.x;

        return Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: (e) => _onPointerMove(e, segW),
            onPointerUp: (e) => _onPointerEnd(e, segW, cancelled: false),
            onPointerCancel: (e) => _onPointerEnd(e, segW, cancelled: true),
            child: SizedBox(
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track (container glass) — shifts + scales on press.
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(panelShift, 0),
                      child: Transform.scale(
                        scale: containerScale,
                        child: GlassSurface(
                          params: trackParams,
                          blurSigma: widget.blurSigma,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  // Labels — above the track, below the thumb so the thumb
                  // lens refracts them (the local "puffed" look).
                  Positioned.fill(
                    left: inset,
                    right: inset,
                    child: Transform.translate(
                      offset: Offset(panelShift, 0),
                      child: Transform.scale(
                        scale: contentScale,
                        child: Row(
                          children: [
                            for (var i = 0; i < widget.segments.length; i++)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    widget.segments[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: i == active
                                          ? const Color(0xFFFFFFFF)
                                          : const Color(0x99FFFFFF),
                                      fontWeight: i == active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Thumb — topmost: refracts track + labels beneath it.
                  // Gets panelOffset but NOT the container scale.
                  Positioned(
                    left: thumbX,
                    top: inset,
                    width: segW,
                    bottom: inset,
                    child: Transform.scale(
                      scaleX: sx,
                      scaleY: sy,
                      child: GlassSurface(
                        params: thumbParams,
                        blurSigma: 0,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
