import 'dart:ui' as ui;

/// Asset keys for the bundled shaders.
///
/// In a consumer app the `packages/<name>/` prefix is required; inside this
/// package's own tests and examples the same shaders sit unprefixed.
abstract final class GlassShaderAssets {
  static const String packageName = 'flutter_liquid_glasses';
  static const String liquidGlass =
      'packages/$packageName/shaders/liquid_glass.frag';
  static const String highlight =
      'packages/$packageName/shaders/glass_highlight.frag';
}

/// Loads a bundled fragment program, tolerating both the package-prefixed key
/// (consumer builds) and the unprefixed key (this package's own tests).
Future<ui.FragmentProgram> loadGlassFragmentProgram(String fileName) async {
  try {
    return await ui.FragmentProgram.fromAsset(
      'packages/${GlassShaderAssets.packageName}/shaders/$fileName',
    );
  } catch (_) {
    return ui.FragmentProgram.fromAsset('shaders/$fileName');
  }
}
