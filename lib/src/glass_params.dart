import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 液态玻璃参数组：背景采样 shader 与内容上方的高光/内阴影共用。
///
/// uniform 契约（Impeller ImageFilter.shader）：
/// - floats[0,1] = u_size：引擎自动绑定输入纹理尺寸，Dart 侧不得写入
/// - floats[2..28] = 背景参数，顺序即 shader 声明序；装饰由 GlassForeground 绘制
class GlassParams {
  const GlassParams({
    this.cornerRadius = 20,
    this.refractionHeight = 12,
    this.refractionAmount = -24,
    this.depthEffect = 0,
    this.chromatic = 0,
    this.saturation = 1.5,
    this.brightness = 0, // 加性偏移，0 = 中性（原版 colorControls 默认）
    this.contrast = 1.0,
    this.tintColor = const [0, 0, 0, 0],
    this.surfaceColor = const [0, 0, 0, 0],
    this.highlightColor = const [1, 1, 1],
    this.highlightAngle = 0.785398, // +45°，原版 Kyant 默认光源方位（照明左上与右下）
    this.highlightFalloff = 1.0,
    this.highlightAlpha = 0.5,
    this.highlightStroke = 2.0,
    this.highlightBlur = 0.25,
    this.highlightMode = 0, // 0=Default 方向性, 2=Plain 均匀描边
    this.shadowColor = const [0, 0, 0],
    this.shadowAlpha = 0,
    this.shadowOffsetX = 0,
    this.shadowOffsetY = 1.0,
    this.shadowBlur = 3.0,
    this.glowX = 0,
    this.glowY = 0,
    this.glowRadius = 0,
    this.glowAlpha = 0,
  });

  final double cornerRadius;
  final double refractionHeight;
  final double refractionAmount;
  final double depthEffect;
  /// 0 = 关闭色散；>0 = 开启且作为强度乘数（Kyant 上游硬编码 1f，这里放开成可调）。
  final double chromatic;
  final double saturation;
  final double brightness;
  final double contrast;
  final List<double> tintColor;
  final List<double> surfaceColor;
  final List<double> highlightColor;
  final double highlightAngle;
  final double highlightFalloff;
  final double highlightAlpha;
  final double highlightStroke;
  final double highlightBlur;
  final double highlightMode;
  final List<double> shadowColor;
  final double shadowAlpha;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double shadowBlur;
  final double glowX;
  final double glowY;
  final double glowRadius;
  final double glowAlpha;

  /// Converts every length from logical pixels to physical pixels exactly once.
  /// Angles, color controls and opacity are dimensionless and remain unchanged.
  GlassParams toPhysical(double dpr) {
    assert(dpr.isFinite && dpr > 0);
    return GlassParams(
      cornerRadius: cornerRadius * dpr,
      refractionHeight: refractionHeight * dpr,
      refractionAmount: refractionAmount * dpr,
      depthEffect: depthEffect,
      chromatic: chromatic,
      saturation: saturation,
      brightness: brightness,
      contrast: contrast,
      tintColor: tintColor,
      surfaceColor: surfaceColor,
      highlightColor: highlightColor,
      highlightAngle: highlightAngle,
      highlightFalloff: highlightFalloff,
      highlightAlpha: highlightAlpha,
      highlightStroke: highlightStroke * dpr,
      highlightBlur: highlightBlur * dpr,
      highlightMode: highlightMode,
      shadowColor: shadowColor,
      shadowAlpha: shadowAlpha,
      shadowOffsetX: shadowOffsetX * dpr,
      shadowOffsetY: shadowOffsetY * dpr,
      shadowBlur: shadowBlur * dpr,
      glowX: glowX * dpr,
      glowY: glowY * dpr,
      glowRadius: glowRadius * dpr,
      glowAlpha: glowAlpha,
    );
  }

  /// Kyant ColorFilter.kt: controls precede blur and lens in the effect chain.
  ui.ColorFilter get colorFilter {
    final r = contrast * 0.213 * (1 - saturation);
    final g = contrast * 0.715 * (1 - saturation);
    final b = contrast * 0.072 * (1 - saturation);
    final s = contrast * saturation;
    final t = (0.5 - contrast * 0.5 + brightness) * 255;
    return ui.ColorFilter.matrix([
      r + s,
      g,
      b,
      0,
      t,
      r,
      g + s,
      b,
      0,
      t,
      r,
      g,
      b + s,
      0,
      t,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  /// 交互层只改几何与指尖光，其余参数原样带过去——避免调用方为了动一下 glow
  /// 就重抄一遍十几项折射参数（抄漏一项就静默改材质）。
  GlassParams copyWith({
    double? cornerRadius,
    double? refractionHeight,
    double? refractionAmount,
    double? depthEffect,
    double? chromatic,
    double? saturation,
    double? brightness,
    double? contrast,
    List<double>? tintColor,
    List<double>? surfaceColor,
    List<double>? highlightColor,
    double? highlightAngle,
    double? highlightFalloff,
    double? highlightAlpha,
    double? highlightStroke,
    double? highlightBlur,
    double? highlightMode,
    List<double>? shadowColor,
    double? shadowAlpha,
    double? shadowOffsetX,
    double? shadowOffsetY,
    double? shadowBlur,
    double? glowX,
    double? glowY,
    double? glowRadius,
    double? glowAlpha,
  }) {
    return GlassParams(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      refractionHeight: refractionHeight ?? this.refractionHeight,
      refractionAmount: refractionAmount ?? this.refractionAmount,
      depthEffect: depthEffect ?? this.depthEffect,
      chromatic: chromatic ?? this.chromatic,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      tintColor: tintColor ?? this.tintColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      highlightColor: highlightColor ?? this.highlightColor,
      highlightAngle: highlightAngle ?? this.highlightAngle,
      highlightFalloff: highlightFalloff ?? this.highlightFalloff,
      highlightAlpha: highlightAlpha ?? this.highlightAlpha,
      highlightStroke: highlightStroke ?? this.highlightStroke,
      highlightBlur: highlightBlur ?? this.highlightBlur,
      highlightMode: highlightMode ?? this.highlightMode,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowAlpha: shadowAlpha ?? this.shadowAlpha,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      glowX: glowX ?? this.glowX,
      glowY: glowY ?? this.glowY,
      glowRadius: glowRadius ?? this.glowRadius,
      glowAlpha: glowAlpha ?? this.glowAlpha,
    );
  }

  /// 绑定背景 uniforms 2..28（floats[0,1] 归引擎）。
  /// [originX]/[originY]/[w]/[h]：玻璃矩形在场景空间的物理 px。
  void bind(
    ui.FragmentShader shader,
    double originX,
    double originY,
    double w,
    double h, {
    bool backdropColorControlled = false,
  }) {
    // Degenerate capsule guard: an SDF radius beyond min(w,h)/2 makes the
    // rounded-rect distance field turn inside-out. Clamp at the uniform
    // boundary so every caller (and any future per-corner radii) is safe.
    final maxR = (w < h ? w : h) * 0.5;
    final r = cornerRadius.clamp(0.0, maxR);
    shader
      ..setFloat(2, originX)
      ..setFloat(3, originY)
      ..setFloat(4, w)
      ..setFloat(5, h)
      ..setFloat(6, r)
      ..setFloat(7, r)
      ..setFloat(8, r)
      ..setFloat(9, r)
      ..setFloat(10, refractionHeight)
      ..setFloat(11, refractionAmount)
      ..setFloat(12, depthEffect)
      ..setFloat(13, chromatic)
      ..setFloat(14, backdropColorControlled ? 1 : saturation)
      ..setFloat(15, backdropColorControlled ? 0 : brightness)
      ..setFloat(16, backdropColorControlled ? 1 : contrast)
      ..setFloat(17, tintColor[0])
      ..setFloat(18, tintColor[1])
      ..setFloat(19, tintColor[2])
      ..setFloat(20, tintColor[3])
      ..setFloat(21, surfaceColor[0])
      ..setFloat(22, surfaceColor[1])
      ..setFloat(23, surfaceColor[2])
      ..setFloat(24, surfaceColor[3])
      ..setFloat(25, glowX)
      ..setFloat(26, glowY)
      ..setFloat(27, glowRadius)
      ..setFloat(28, glowAlpha);
  }

  // shouldRepaint 全靠 `params != old.params`——没有 == 就是恒真，
  // 每次 paint 都当参数变了重绑 shader。
  @override
  bool operator ==(Object other) =>
      other is GlassParams &&
      other.cornerRadius == cornerRadius &&
      other.refractionHeight == refractionHeight &&
      other.refractionAmount == refractionAmount &&
      other.depthEffect == depthEffect &&
      other.chromatic == chromatic &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      listEquals(other.tintColor, tintColor) &&
      listEquals(other.surfaceColor, surfaceColor) &&
      listEquals(other.highlightColor, highlightColor) &&
      other.highlightAngle == highlightAngle &&
      other.highlightFalloff == highlightFalloff &&
      other.highlightAlpha == highlightAlpha &&
      other.highlightStroke == highlightStroke &&
      other.highlightBlur == highlightBlur &&
      other.highlightMode == highlightMode &&
      listEquals(other.shadowColor, shadowColor) &&
      other.shadowAlpha == shadowAlpha &&
      other.shadowOffsetX == shadowOffsetX &&
      other.shadowOffsetY == shadowOffsetY &&
      other.shadowBlur == shadowBlur &&
      other.glowX == glowX &&
      other.glowY == glowY &&
      other.glowRadius == glowRadius &&
      other.glowAlpha == glowAlpha;

  @override
  int get hashCode => Object.hashAll([
        cornerRadius,
        refractionHeight,
        refractionAmount,
        depthEffect,
        chromatic,
        saturation,
        brightness,
        contrast,
        Object.hashAll(tintColor),
        Object.hashAll(surfaceColor),
        Object.hashAll(highlightColor),
        highlightAngle,
        highlightFalloff,
        highlightAlpha,
        highlightStroke,
        highlightBlur,
        highlightMode,
        Object.hashAll(shadowColor),
        shadowAlpha,
        shadowOffsetX,
        shadowOffsetY,
        shadowBlur,
        glowX,
        glowY,
        glowRadius,
        glowAlpha,
      ]);
}
