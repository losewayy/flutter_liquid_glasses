import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass_params.dart';
import 'glass_shader_assets.dart';

/// Highlight / inner-shadow / glow decorations painted above glass content.
///
/// Decorations belong above content, not inside the backdrop filter. Params use
/// physical pixels supplied by GlassSurface/GlassPressSurface; canvas uses logical pixels.
class GlassForeground extends StatefulWidget {
  const GlassForeground({super.key, required this.params, required this.child});

  final GlassParams params;
  final Widget child;

  @override
  State<GlassForeground> createState() => _GlassForegroundState();
}

class _GlassForegroundState extends State<GlassForeground> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;
  bool _loading = false;
  bool _loadFailed = false;

  bool get _needsShader =>
      widget.params.highlightMode < 1.5 &&
      widget.params.highlightAlpha > 0 &&
      widget.params.highlightStroke > 0;

  @override
  void initState() {
    super.initState();
    _syncShader();
  }

  @override
  void didUpdateWidget(covariant GlassForeground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncShader();
  }

  void _syncShader() {
    if (!_needsShader) {
      _shader?.dispose();
      _shader = null;
    } else if (_shader == null && !_loading && !_loadFailed) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final program = await (_program ??= loadGlassFragmentProgram(
        'glass_highlight.frag',
      ));
      // The preference can change while the asset is loading.
      if (mounted && _needsShader) {
        setState(() => _shader = program.fragmentShader());
      }
    } catch (error) {
      _loadFailed = true;
      debugPrint(
        'Glass highlight shader unavailable; using plain edge: $error',
      );
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _GlassForegroundPainter(
      widget.params,
      MediaQuery.devicePixelRatioOf(context),
      _shader,
    ),
    child: widget.child,
  );
}

class _GlassForegroundPainter extends CustomPainter {
  const _GlassForegroundPainter(this.params, this.dpr, this.shader);

  final GlassParams params;
  final double dpr;
  final ui.FragmentShader? shader;

  Color _color(List<double> rgb, double alpha) =>
      Color.from(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: alpha);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = params;
    final radius = p.cornerRadius / dpr;
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final plain = p.highlightMode >= 1.5 || shader == null;
    if (p.highlightAlpha > 0 &&
        p.highlightStroke > 0 &&
        (plain || shader != null)) {
      final widthPx = math
          .min(p.highlightStroke, size.shortestSide * dpr / 2)
          .ceilToDouble();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = widthPx * 2 / dpr
        ..blendMode = BlendMode.plus;
      if (plain) {
        paint.color = _color(p.highlightColor, p.highlightAlpha);
      } else {
        shader!
          ..setFloat(0, size.width)
          ..setFloat(1, size.height)
          ..setFloat(2, radius)
          ..setFloat(3, p.highlightAngle)
          ..setFloat(4, p.highlightFalloff)
          ..setFloat(5, p.highlightColor[0])
          ..setFloat(6, p.highlightColor[1])
          ..setFloat(7, p.highlightColor[2])
          ..setFloat(8, p.highlightAlpha);
        paint.shader = shader;
      }
      if (p.highlightBlur > 0) {
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          p.highlightBlur / dpr,
        );
      }
      canvas.save();
      canvas.clipRRect(shape);
      canvas.drawRRect(shape, paint);
      canvas.restore();
    }

    final offset = Offset(p.shadowOffsetX / dpr, p.shadowOffsetY / dpr);
    if (p.shadowAlpha <= 0 || offset == Offset.zero) return;
    final sigma = p.shadowBlur / dpr;
    // Kyant inner shadow: clip(S, blur(S - translate(S, offset))).
    // Clear acts only on this isolated layer, never on text or the backdrop.
    canvas.save();
    canvas.clipRRect(shape);
    final layerPaint = Paint();
    if (sigma > 0) {
      layerPaint.imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      );
    }
    canvas.saveLayer(
      shape.outerRect.inflate(math.max(0, sigma) * 4 + 1),
      layerPaint,
    );
    canvas.drawRRect(
      shape,
      Paint()..color = _color(p.shadowColor, p.shadowAlpha),
    );
    canvas.drawRRect(shape.shift(offset), Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassForegroundPainter oldDelegate) =>
      params != oldDelegate.params ||
      dpr != oldDelegate.dpr ||
      shader != oldDelegate.shader;
}
