import 'package:flutter/material.dart';

import 'glass_params.dart';
import 'glass_theme.dart';

/// A material recipe: optical [params] plus the host-side blur radius and an
/// optional outer shadow. Lengths are logical pixels; [GlassSurface] converts
/// to physical pixels at the shader boundary.
///
/// Callers select a recipe rather than reconstructing optics.
class GlassMaterialToken {
  const GlassMaterialToken({
    required this.params,
    required this.blurSigma,
    this.outerShadow,
  });

  final GlassParams params;
  final double blurSigma;
  final BoxShadow? outerShadow;
}

/// Material recipes for common UI tiers.
///
/// [surface] overrides the cover tint per call — e.g. when a wallpaper-derived
/// palette supplies a different tone — without touching the optics. With no
/// override each recipe takes its surface color from [GlassThemeData].
abstract final class GlassMaterials {
  /// Input capsule: measured tint/radius/frost/shadow, band 18 / amount −34,
  /// depthEffect 1, chromatic 2.0.
  static GlassMaterialToken composer(GlassThemeData theme, {Color? surface}) =>
      _resolve(_composer, surface ?? theme.composerSurface);

  /// Navigation rail / sidebar tier: shallow lens (band 14 / amount −24),
  /// no inner blur, no highlight stroke.
  static GlassMaterialToken navigation(
    GlassThemeData theme, {
    Color? surface,
  }) => _resolve(_navigation, surface ?? theme.navigationSurface);

  static GlassMaterialToken topbar(GlassThemeData theme, {Color? surface}) =>
      _resolve(_navigation, surface ?? theme.topbarSurface);

  /// Command palette: strong lens (band 20 / amount −36) over 12px frost.
  static GlassMaterialToken commandPalette(
    GlassThemeData theme, {
    Color? surface,
  }) => _resolve(_commandPalette, surface ?? theme.commandPaletteSurface);

  /// Content/settings card: no lens (band/amount 0), tint + plain rim + shadow.
  static GlassMaterialToken card(GlassThemeData theme, {Color? surface}) =>
      _resolve(_card, surface ?? theme.menuSurface);

  /// Menu / toast tier: band 12 / amount −20 over 8px frost.
  static GlassMaterialToken toast(GlassThemeData theme, {Color? surface}) =>
      _resolve(_toast, surface ?? theme.menuSurface);

  /// Dialog / large overlay tier: strongest lens (band 16 / amount −24,
  /// depthEffect 1) over 12px frost, plain rim α .38, lg shadow.
  static GlassMaterialToken overlay(GlassThemeData theme, {Color? surface}) =>
      _resolve(_overlay, surface ?? theme.menuSurface);

  static GlassMaterialToken _resolve(
    GlassMaterialToken optics,
    Color surface,
  ) => GlassMaterialToken(
    params: optics.params.copyWith(
      surfaceColor: List<double>.unmodifiable([
        surface.r,
        surface.g,
        surface.b,
        surface.a,
      ]),
    ),
    blurSigma: optics.blurSigma,
    outerShadow: optics.outerShadow,
  );

  static const _composer = GlassMaterialToken(
    blurSigma: 2,
    params: GlassParams(
      cornerRadius: 25,
      refractionHeight: 18,
      refractionAmount: -34,
      depthEffect: 1,
      chromatic: 2.0,
      saturation: 1.5,
      brightness: 0,
      highlightStroke: 1,
      highlightAlpha: .38,
      highlightAngle: .785398,
    ),
    outerShadow: BoxShadow(
      color: Color.fromRGBO(0, 0, 0, .18),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  );

  static const _navigation = GlassMaterialToken(
    blurSigma: 0,
    params: GlassParams(
      cornerRadius: 0,
      refractionHeight: 14,
      refractionAmount: -24,
      depthEffect: 1,
      saturation: 1.5,
      chromatic: 2.0,
      highlightAlpha: 0,
    ),
  );

  static const _commandPalette = GlassMaterialToken(
    blurSigma: 12,
    params: GlassParams(
      cornerRadius: 20,
      refractionHeight: 20,
      refractionAmount: -36,
      depthEffect: 1,
      chromatic: 2.0,
      highlightStroke: 1,
    ),
    outerShadow: BoxShadow(
      color: Color.fromRGBO(0, 0, 0, .28),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  );

  // Content cards deliberately take the cheap path: tint + edge light + shadow,
  // no lens — a refracting fill over a wallpaper washes the text out.
  static const _card = GlassMaterialToken(
    blurSigma: 0,
    params: GlassParams(
      cornerRadius: 15,
      refractionHeight: 0,
      refractionAmount: 0,
      depthEffect: 0,
      saturation: 1.5,
      chromatic: 0,
      highlightMode: 2,
      highlightStroke: 1,
      highlightAlpha: .3,
    ),
  );

  static const _toast = GlassMaterialToken(
    blurSigma: 8,
    params: GlassParams(
      cornerRadius: 16,
      refractionHeight: 12,
      refractionAmount: -20,
      depthEffect: 1,
      saturation: 1.5,
      chromatic: 2.0,
      highlightStroke: 1,
      highlightAlpha: .3,
    ),
    outerShadow: BoxShadow(
      color: Color.fromRGBO(0, 0, 0, .18),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  );

  static const _overlay = GlassMaterialToken(
    blurSigma: 12,
    params: GlassParams(
      cornerRadius: 12,
      refractionHeight: 16,
      refractionAmount: -24,
      depthEffect: 1,
      saturation: 1.5,
      chromatic: 2.0,
      highlightMode: 2,
      highlightStroke: 1,
      highlightAlpha: .38,
    ),
    outerShadow: BoxShadow(
      color: Color.fromRGBO(0, 0, 0, .28),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  );
}
