import 'package:flutter/material.dart';

import 'glass_materials.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// 导航类玻璃面（侧栏/顶栏共用浅透镜档）。
///
/// [active] = false 时（底图是纯色平面、没有可折射的场景细节）直接画
/// [opaqueBackground]，不分配整条 BackdropFilter——性能口径，不是观感差异。
///
/// 盖面色顺序：[surfaceColor] 显式值 > [GlassTheme] 的
/// navigationSurface/topbarSurface（按 [surfaceRole] 选）。
class GlassNavigationSurface extends StatelessWidget {
  const GlassNavigationSurface({
    super.key,
    required this.active,
    required this.child,
    this.opaqueBackground = Colors.transparent,
    this.surfaceRole = GlassNavigationRole.sidebar,
    this.surfaceColor,
  });

  /// false = 底下是纯色平面，无场景细节可折射 → 画实底，不挂滤镜。
  final bool active;
  final Color opaqueBackground;
  final Widget child;

  /// 盖面色角色：侧栏取 [GlassThemeData.navigationSurface]、
  /// 顶栏取 [GlassThemeData.topbarSurface]。
  final GlassNavigationRole surfaceRole;

  /// 显式盖面色（如壁纸派生色）；null 走主题。
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    // A flat opaque canvas has no scene detail to refract. Keep its existing
    // appearance without allocating a full-height backdrop filter.
    if (!active) {
      return ColoredBox(color: opaqueBackground, child: child);
    }
    final theme = GlassTheme.of(context);
    final material = switch (surfaceRole) {
      GlassNavigationRole.sidebar => GlassMaterials.navigation(
        theme,
        surface: surfaceColor,
      ),
      GlassNavigationRole.topbar => GlassMaterials.topbar(
        theme,
        surface: surfaceColor,
      ),
    };
    return GlassSurface(
      blurSigma: material.blurSigma,
      drawForeground: false,
      params: material.params,
      child: child,
    );
  }
}

/// Which navigation chrome a [GlassNavigationSurface] is dressing:
/// `sidebar` uses the navigation material, `topbar` the palette variant.
enum GlassNavigationRole { sidebar, topbar }
