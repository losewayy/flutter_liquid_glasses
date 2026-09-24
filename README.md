# flutter_liquid_glasses

English · [中文](README_zh.md)

Apple-style **liquid glass** material for Flutter on Impeller — a faithful port of
[Kyant's AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)
optics (`backdrop` library), extended to desktop-class surfaces.

Real refraction, real dispersion, real springs — not a frosted-blur approximation.

![Interactive playground: drag the segmented thumb, jelly the press surface](doc/demo.gif)

## What it renders

- **SDF-clipped glass edge** — ±0.5px anti-aliased boundary, not a soft fade
- **Lens refraction** — `circleMap` displacement along the rounded-rect SDF gradient,
  with optional `depthEffect` (normals bend toward radial)
- **7-path chromatic dispersion** — ROYGCBP channel-separated sampling
  (prism fringes at corners)
- **Vibrancy controls** — saturation/brightness/contrast matrix applied to the
  backdrop, faithful to Kyant's `colorControls`
- **Hue-blend tint + surface cover** — non-separable Hue blend preserving
  backdrop luminosity, then a SrcOver cover color
- **Directional highlight** — SDF-gradient rim lighting (Kyant `Highlight.Default`),
  plus a plain rim mode
- **Inner shadow** — clipped `blur(S − translate(S))` trick, isolated so `Clear`
  never erases the scene
- **Interactive glow** — pointer-following radial Plus highlight
  (0.08 flat + 0.15 radial, Kyant `InteractiveHighlight`)
- **Closed-form damped springs** — underdamped press/drag/settle motion
  (k=300 ζ=0.5, k=250 ζ 0.6/0.7, k=1000 ζ=1.0 — same constants as Kyant's
  `DampedDragAnimation`)
- **Honest fallbacks** — `ReducedTransparencyScope` (accessibility) and a
  non-Impeller frosted fallback; nothing pretends to be glass when it isn't

## Requirements

- Flutter ≥ 3.35, **Impeller rendering** (default on modern iOS/Android/desktop)
- Refraction requires `ImageFilter.shader`, which exists **only on Impeller**.
  On other backends — **including Flutter web** (CanvasKit and Skwasm are both
  Skia, not Impeller) — every surface degrades to a blur + tint fallback
  (no crash, no fake refraction). Springs, gestures, highlight painters and
  tint controls still work in the fallback; lens/dispersion params are inert
  by design.

## Usage

```dart
import 'package:flutter_liquid_glasses/flutter_liquid_glasses.dart';

// Static glass surface over your content.
Stack(
  children: [
    myBackdropContent,
    GlassSurface(
      params: const GlassParams(
        cornerRadius: 20,
        refractionHeight: 18,
        refractionAmount: -34,
        depthEffect: 1,
        chromatic: 2.0,
        saturation: 1.5,
      ),
      blurSigma: 2,
      child: myForegroundContent,
    ),
  ],
)

// Interactive surface: press squash + drag-follow jelly + pointer glow.
GlassPressSurface(
  params: GlassMaterials.composer(GlassTheme.of(context)).params,
  child: myButton,
)

// Swipe-to-dismiss (toasts, chips).
LiquidSwipeSurface(
  onDismissed: () => hideToast(),
  child: toastCard,
)

// Segmented control with a refractive thumb (Kyant LiquidBottomTabs):
// press inflates the thumb into a live lens that protrudes past the
// track, drag lags through a critical spring, release settles then
// relaxes — taps glide without stretch.
GlassSegmentedControl<int>(
  segments: const [
    GlassSegment(value: 0, label: 'Left'),
    GlassSegment(value: 1, label: 'Center'),
    GlassSegment(value: 2, label: 'Right'),
  ],
  selected: tab,
  onChanged: (v) => setState(() => tab = v),
)

// Material recipes + tinting.
final material = GlassMaterials.overlay(GlassTheme.of(context));
GlassDialog(child: dialogBody);              // overlay tier shell
showGlassMenu(context: context, anchor: pos, // popup menu in glass
    items: [GlassMenuItem(value: 1, child: Text('Item'))]);
```

## Upstream fidelity

This package is a line-level port of Kyant's AGSL/Kotlin implementation.
Where we deviate, it's deliberate and documented:

| This package (`GlassParams`) | Kyant `backdrop` | Status |
|---|---|---|
| `refractionHeight` / `refractionAmount` | `lens(refractionHeight, refractionAmount)` | identical math; sign convention kept (negative = inward pull) |
| `depthEffect` | `depthEffect` | identical |
| `chromatic` (float, 0 = off) | `chromaticAberration` (bool, uniform fixed `1f`) | **deviation** — ours doubles as a strength multiplier |
| `saturation`/`brightness`/`contrast` | `colorControls(brightness, contrast, saturation)` | identical matrix |
| `tintColor` + `surfaceColor` | drawn as separate surface layers | folded into the shader pass |
| highlight stroke/blur/alpha/angle/falloff | `Highlight(width, blurRadius, alpha, style)` | identical pipeline; upstream's `Ambient` style not ported (roadmap) |
| `shadow*` | `InnerShadow` | identical technique |
| `glow*` | `InteractiveHighlight` | identical weights (0.08 flat + 0.15 radial, radius = minDim·1.5) |
| `GlassSpring` k/ζ | `DampedDragAnimation` spring specs | same constants, closed-form instead of `Animatable` |
| `cornerRadius` (uniform) | `cornerRadii` (per-corner) | **simplification** — per-corner radii on the roadmap |

## Platform notes

Desktop is a first-class target: the full pipeline (refraction + dispersion +
glow) runs on Windows/Impeller. Widget tests cover the shader math directly;
premultiplied-alpha correctness at the AA edge is asserted per-pixel.

## Credits

Optics and interaction design are ported from
**[Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)**
(Apache-2.0) — the `backdrop` library is the reference implementation this
package tracks. Huge thanks to Kyant for publishing it.

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
