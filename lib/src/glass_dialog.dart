import 'package:flutter/material.dart';

import 'glass_materials.dart';
import 'glass_press_surface.dart';
import 'glass_theme.dart';

/// 玻璃对话框壳——overlay 档（band 16 / amount −24 / blur 12 / sat 1.5 /
/// 均匀 0.38 描边 / 0 8px 32px 投影）。
///
/// 用法：把 `Dialog(backgroundColor: …, shape: …, child: content)` 换成
/// `GlassDialog(child: content)`——背景色/圆角/描边/阴影全部由玻璃壳承担，
/// 不要在外层再画实底（会盖住折射采样）。
///
/// 不走 `showDialog` 的壳层 overlay（全屏遮罩 + 点击关闭）用
/// [GlassPanel]：同一块玻璃壳，不带 `Dialog` 包装。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.width,
    this.surfaceColor,
  });

  final Widget child;

  /// 固定宽度（等价 dialog 的 maxWidth 约束）。
  final double? width;

  /// 盖面色；null → [GlassThemeData.menuSurface]。
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final material = GlassMaterials.overlay(
      GlassTheme.of(context),
      surface: surfaceColor,
    );
    return SizedBox(
      width: width,
      child: GlassPressSurface(
        // 对话框不可拖拽/按压形变（无 pressable 语义）。
        interactive: false,
        params: material.params,
        blurSigma: material.blurSigma,
        outerShadow: material.outerShadow,
        child: child,
      ),
    );
  }
}

/// Overlay-tier glass dialog shell — wraps [child] in a non-interactive
/// [GlassPressSurface] using the overlay material recipe.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.child,
    this.width,
    this.surfaceColor,
  });

  /// 对话框内容（自带 padding 与宽度约束，或传 [width] 由壳层固定）。
  final Widget child;

  /// 固定宽度（等价 dialog 的 maxWidth 约束）。
  final double? width;

  /// 盖面色；null → [GlassThemeData.menuSurface]。
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final material = GlassMaterials.overlay(
      GlassTheme.of(context),
      surface: surfaceColor,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(material.params.cornerRadius),
      ),
      child: GlassPanel(
        width: width,
        surfaceColor: surfaceColor,
        child: child,
      ),
    );
  }
}
