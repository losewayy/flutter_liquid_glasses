## 0.1.1

- `dart format` pass across the package; no behavior changes.

## 0.1.0

Initial extraction.

- `GlassSurface` / `GlassPressSurface` / `LiquidSwipeSurface` — refractive glass
  surfaces with interactive springs (Kyant `backdrop` optics port)
- `GlassSegmentedControl` — capsule selector with a refractive thumb
  (Kyant `LiquidBottomTabs`/`DampedDragAnimation` port)
- `GlassMaterials` recipes + `GlassTheme`/`GlassThemeData` tinting
- `GlassDialog`/`GlassPanel`, `showGlassMenu`/`GlassMenuButton`/`GlassSelect`,
  `GlassNavigationSurface`
- `ReducedTransparencyScope` accessibility fallback; honest non-Impeller fallback
- `liquid_glass.frag` + `glass_highlight.frag` runtime-effect shaders
