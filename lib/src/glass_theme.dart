import 'package:flutter/widgets.dart';

/// Surface-tint palette for the glass materials.
///
/// Each field is a cover color drawn over the refracted backdrop (the
/// `surfaceColor` uniform family). Defaults reproduce a dark chrome scheme;
/// wrap the subtree in a [GlassTheme] to re-tint every glass surface, or pass
/// a `surface` override to individual [GlassMaterials] factories / widgets.
class GlassThemeData {
  const GlassThemeData({
    this.composerSurface = const Color.from(
      alpha: .52,
      red: .232549,
      green: .232549,
      blue: .232549,
    ),
    this.navigationSurface = const Color.from(
      alpha: .68,
      red: 16 / 255,
      green: 16 / 255,
      blue: 20 / 255,
    ),
    this.topbarSurface = const Color.from(
      alpha: .68,
      red: 16 / 255,
      green: 16 / 255,
      blue: 20 / 255,
    ),
    this.commandPaletteSurface = const Color.from(
      alpha: .4,
      red: 45 / 255,
      green: 45 / 255,
      blue: 45 / 255,
    ),
    // Menus, toasts, cards, dialogs and overlays share this family.
    this.menuSurface = const Color.from(
      alpha: .70,
      red: 30 / 255,
      green: 30 / 255,
      blue: 30 / 255,
    ),
    // Opaque color used when transparency is reduced (accessibility) or when
    // shaders are unsupported. Must be fully opaque to be an honest fallback.
    this.fallbackSurface = const Color(0xFF181818),
  });

  final Color composerSurface;
  final Color navigationSurface;
  final Color topbarSurface;
  final Color commandPaletteSurface;
  final Color menuSurface;
  final Color fallbackSurface;

  GlassThemeData copyWith({
    Color? composerSurface,
    Color? navigationSurface,
    Color? topbarSurface,
    Color? commandPaletteSurface,
    Color? menuSurface,
    Color? fallbackSurface,
  }) => GlassThemeData(
    composerSurface: composerSurface ?? this.composerSurface,
    navigationSurface: navigationSurface ?? this.navigationSurface,
    topbarSurface: topbarSurface ?? this.topbarSurface,
    commandPaletteSurface: commandPaletteSurface ?? this.commandPaletteSurface,
    menuSurface: menuSurface ?? this.menuSurface,
    fallbackSurface: fallbackSurface ?? this.fallbackSurface,
  );

  GlassThemeData lerp(GlassThemeData? other, double t) {
    if (other == null) return this;
    return GlassThemeData(
      composerSurface: Color.lerp(composerSurface, other.composerSurface, t)!,
      navigationSurface: Color.lerp(
        navigationSurface,
        other.navigationSurface,
        t,
      )!,
      topbarSurface: Color.lerp(topbarSurface, other.topbarSurface, t)!,
      commandPaletteSurface: Color.lerp(
        commandPaletteSurface,
        other.commandPaletteSurface,
        t,
      )!,
      menuSurface: Color.lerp(menuSurface, other.menuSurface, t)!,
      fallbackSurface: Color.lerp(fallbackSurface, other.fallbackSurface, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassThemeData &&
      other.composerSurface == composerSurface &&
      other.navigationSurface == navigationSurface &&
      other.topbarSurface == topbarSurface &&
      other.commandPaletteSurface == commandPaletteSurface &&
      other.menuSurface == menuSurface &&
      other.fallbackSurface == fallbackSurface;

  @override
  int get hashCode => Object.hash(
    composerSurface,
    navigationSurface,
    topbarSurface,
    commandPaletteSurface,
    menuSurface,
    fallbackSurface,
  );
}

/// Supplies a [GlassThemeData] to the subtree. Absent = [GlassThemeData]
/// defaults.
class GlassTheme extends InheritedWidget {
  const GlassTheme({super.key, required this.data, required super.child});

  final GlassThemeData data;

  static GlassThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassTheme>()?.data;

  static GlassThemeData of(BuildContext context) =>
      maybeOf(context) ?? const GlassThemeData();

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => data != oldWidget.data;
}
