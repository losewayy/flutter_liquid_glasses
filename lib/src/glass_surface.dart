import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'glass_foreground.dart';
import 'glass_params.dart';
import 'glass_shader_assets.dart';
import 'glass_theme.dart';
import 'reduced_transparency.dart';

/// 液态玻璃表面——BackdropFilter + runtime_effect shader 的可复用封装。
///
/// 管线：场景内容 → ColorFilter → ImageFilter.blur(sigma) → liquid_glass.frag（折射/色散/
/// 染色/指尖 glow）→ 内容 → 原生描边高光 → 内阴影。
///
/// 几何在 paint 阶段绑定：LayoutBuilder 首次布局时祖先还未放置子节点，
/// 此时读 localToGlobal 会得到零原点，导致远离左上角的玻璃被 SDF 裁光。
/// 输入纹理采样由引擎 u_size 归一化，卡片几何只用于 SDF。
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    this.params = const GlassParams(),
    this.blurSigma = 2.0,
    this.child,
    this.drawForeground = true,
    this.reduceTransparency,
    this.fallbackColor,
  });

  // All lengths, including global glow coordinates, are logical pixels.
  final GlassParams params;
  // False when a parent paints the foreground above separately laid-out content.
  final bool drawForeground;

  /// 内层底图模糊（逻辑 px）——原版 2dp；0 = 纯透玻璃。
  final double blurSigma;

  /// 玻璃区域内的内容（画在玻璃效果之上；底层内容由调用方用 Stack 布局）。
  final Widget? child;

  /// 减少透明度硬关断（预设或环境触发）：移除 BackdropFilter 与 shader，回落到不透明
  /// [GlassThemeData.fallbackSurface]（或 [fallbackColor]）。
  final bool? reduceTransparency;

  /// 减透明降级时用的不透明底色；null → [GlassThemeData.fallbackSurface]。
  final Color? fallbackColor;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  ui.FragmentProgram? _program;
  bool _loading = false;
  bool _loadFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureProgram();
  }

  @override
  void didUpdateWidget(covariant GlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureProgram();
  }

  void _ensureProgram() {
    final reduced =
        widget.reduceTransparency ?? ReducedTransparencyScope.of(context);
    if (reduced || !ui.ImageFilter.isShaderFilterSupported ||
        _program != null || _loading || _loadFailed) {
      return;
    }
    _loading = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await loadGlassFragmentProgram('liquid_glass.frag');
      if (mounted) setState(() => _program = p);
    } catch (error) {
      _loadFailed = true;
      debugPrint('Liquid glass shader unavailable; using native fallback: $error');
    } finally {
      _loading = false;
    }
  }

  /// Impeller 可用性探测——ImageFilter.shader 仅在 Impeller 下支持；
  /// 非 Impeller（测试绑定/老 Skia 通道）降级为半透明磨砂面而非崩溃。
  static bool _shaderSupported = true;

  @override
  Widget build(BuildContext context) {
    final isReduced =
        widget.reduceTransparency ?? ReducedTransparencyScope.of(context);
    if (isReduced) {
      final opaqueSurface = ClipRRect(
        borderRadius: BorderRadius.circular(widget.params.cornerRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (widget.fallbackColor ??
                    GlassTheme.of(context).fallbackSurface)
                .withValues(alpha: 1),
            borderRadius: BorderRadius.circular(widget.params.cornerRadius),
          ),
          child:
              widget.child ??
              const SizedBox.expand(
                child: ColoredBox(color: Colors.transparent),
              ),
        ),
      );
      return widget.drawForeground
          ? GlassForeground(
              params: widget.params.copyWith(highlightMode: 2).toPhysical(
                MediaQuery.devicePixelRatioOf(context),
              ),
              child: opaqueSurface,
            )
          : opaqueSurface;
    }

    final surface = _buildSurface(context);
    return widget.drawForeground
        ? GlassForeground(
            params: widget.params.toPhysical(
              MediaQuery.devicePixelRatioOf(context),
            ),
            child: surface,
          )
        : surface;
  }

  Widget _buildSurface(BuildContext context) {
    final program = _program;
    if (program == null || !_shaderSupported) {
      return _fallback();
    }
    if (!ui.ImageFilter.isShaderFilterSupported) {
      _shaderSupported = false;
      return _fallback();
    }
    // 调试件（GLASS_DEBUG_TINT=1）：每个玻璃面循环染一支高饱和
    // 纯色（backdrop 折射还在，只把盖面 token 打满 alpha），用来从截图里
    // 认出某块玻璃是谁——定位 stray 渲染洞用，生产路径不受影响。
    final params = widget.params.toPhysical(
      MediaQuery.devicePixelRatioOf(context),
    );
    return ClipRect(
      child: _GlassBackdrop(
        program: program,
        params: _debugGlassTint
            ? params.copyWith(surfaceColor: _nextDebugTint())
            : params,
        dpr: MediaQuery.devicePixelRatioOf(context),
        blurSigma: widget.blurSigma,
        child:
            widget.child ??
            const SizedBox.expand(child: ColoredBox(color: Colors.transparent)),
      ),
    );
  }

  /// 非 Impeller 降级：blur+半透明近似磨砂（无折射/色散，诚实降级不伪造）。
  Widget _fallback() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.params.cornerRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          inner: widget.params.colorFilter,
        ),
        child: CustomPaint(
          painter: _GlassFallbackTintPainter(widget.params),
          child: widget.child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GlassFallbackTintPainter extends CustomPainter {
  const _GlassFallbackTintPainter(this.params);
  final GlassParams params;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final tint = params.tintColor;
    if (tint[3] > 0) {
      final color = Color.from(
        alpha: tint[3],
        red: tint[0],
        green: tint[1],
        blue: tint[2],
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color
          ..blendMode = BlendMode.hue,
      );
      canvas.drawRect(
        bounds,
        Paint()..color = color.withValues(alpha: tint[3] * .75),
      );
    }
    final surface = params.surfaceColor;
    canvas.drawRect(
      bounds,
      Paint()
        ..color = Color.from(
          alpha: surface[3],
          red: surface[0],
          green: surface[1],
          blue: surface[2],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassFallbackTintPainter oldDelegate) =>
      params != oldDelegate.params;
}

// 调试件：GLASS_DEBUG_TINT=1 时每个 GlassSurface 循环染一支纯色。
const _debugGlassTint =
    bool.fromEnvironment('GLASS_DEBUG_TINT');
var _debugTintCursor = 0;
const _debugTintPalette = <List<double>>[
  [1, 0, 0, 1], // 红
  [0, 1, 0, 1], // 绿
  [0, 0, 1, 1], // 蓝
  [1, 1, 0, 1], // 黄
  [1, 0, 1, 1], // 品红
  [0, 1, 1, 1], // 青
  [1, 0.5, 0, 1], // 橙
  [0.5, 0, 1, 1], // 紫
];
List<double> _nextDebugTint() {
  final tint = _debugTintPalette[_debugTintCursor % _debugTintPalette.length];
  _debugTintCursor++;
  return tint;
}

class _GlassBackdrop extends SingleChildRenderObjectWidget {
  const _GlassBackdrop({
    required this.program,
    required this.params,
    required this.dpr,
    required this.blurSigma,
    required super.child,
  });

  final ui.FragmentProgram program;
  final GlassParams params;
  final double dpr;
  final double blurSigma;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(program.fragmentShader(), params, dpr, blurSigma);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderGlassBackdrop renderObject,
  ) {
    renderObject.update(params, dpr, blurSigma);
  }
}

class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop(this._shader, this._params, this._dpr, this._blurSigma);

  final ui.FragmentShader _shader;
  GlassParams _params;
  double _dpr;
  double _blurSigma;

  void update(GlassParams params, double dpr, double blurSigma) {
    if (_params == params && _dpr == dpr && _blurSigma == blurSigma) return;
    _params = params;
    _dpr = dpr;
    _blurSigma = blurSigma;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) return;
    // Read geometry only after layout/placement. A parent moving this card
    // without rebuilding it must still update the uniforms on this paint.
    final bounds = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    _params.bind(
      _shader,
      bounds.left * _dpr,
      bounds.top * _dpr,
      bounds.width * _dpr,
      bounds.height * _dpr,
      backdropColorControlled: true,
    );
    final blur = ui.ImageFilter.blur(
      sigmaX: _blurSigma > 0 ? _blurSigma : 0.0001,
      sigmaY: _blurSigma > 0 ? _blurSigma : 0.0001,
    );
    // An identity matrix is not free on Impeller: its extra intermediate
    // introduced one-level edge differences even with zero lens displacement.
    // Skip only the exact identity; non-neutral controls still precede blur.
    final neutral =
        _params.saturation == 1 &&
        _params.brightness == 0 &&
        _params.contrast == 1;
    final filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(_shader),
      inner: neutral
          ? blur
          : ui.ImageFilter.compose(outer: blur, inner: _params.colorFilter),
    );
    final backdropLayer =
        (layer ??= BackdropFilterLayer()) as BackdropFilterLayer;
    backdropLayer
      ..filter = filter
      ..blendMode = BlendMode.srcOver;
    context.pushLayer(backdropLayer, super.paint, offset);
  }

  @override
  void dispose() {
    _shader.dispose();
    super.dispose();
  }
}
