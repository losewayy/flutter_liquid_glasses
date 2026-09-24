/// Kyant-faithful liquid glass material for Flutter on Impeller.
///
/// Core surfaces:
/// - [GlassSurface] — refractive backdrop surface (SDF clip, circleMap lens,
///   7-path chromatic dispersion, hue-blend tint, pointer glow).
/// - [GlassPressSurface] — interactive variant: press squash, drag-follow
///   jelly, lens coupling, closed-form springs.
/// - [LiquidSwipeSurface] — swipe-to-dismiss wrapper with squash-stretch.
/// - [GlassSegmentedControl] — capsule selector whose glass thumb drags
///   and springs between segments.
///
/// Material recipes: [GlassMaterials] + [GlassMaterialToken], tinted by
/// [GlassTheme]/[GlassThemeData]. Ready-made shells: [GlassDialog],
/// [GlassPanel], [GlassNavigationSurface], [showGlassMenu], [GlassMenuButton],
/// [GlassSelect].
///
/// Accessibility: [ReducedTransparencyScope] hard-disables refraction and
/// falls back to an opaque surface.
library;

export 'src/glass_dialog.dart';
export 'src/glass_foreground.dart';
export 'src/glass_materials.dart';
export 'src/glass_menu.dart';
export 'src/glass_navigation.dart';
export 'src/glass_params.dart';
export 'src/glass_press_surface.dart';
export 'src/glass_segmented_control.dart';
export 'src/glass_shader_assets.dart' show GlassShaderAssets;
export 'src/glass_spring.dart';
export 'src/glass_surface.dart';
export 'src/glass_theme.dart';
export 'src/liquid_swipe_surface.dart';
export 'src/reduced_transparency.dart';
