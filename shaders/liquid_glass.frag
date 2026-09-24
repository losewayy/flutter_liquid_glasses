#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Kyant-inspired backdrop optics for Flutter Impeller runtime_effect.
//
// Production pipeline:
//   1. SDF clip (±0.5px AA — crisp glass edge, NOT a soft fade)
//   2. Sample backdrop (native color controls then blur, ~2dp)
//   3. applyColorControls — identity in production; direct-shader tests supply controls
//   4. Lens refraction (circleMap × amount × grad + depthEffect + 7-path dispersion)
//   5. onDrawSurface: tint (BlendMode.Hue + 0.75 SrcOver) then surfaceColor
//   6. Interactive glow; content/highlight/inner shadow are separate host layers
// -----------------------------------------------------------------------------

// Injected by Impeller: filter-region size + backdrop texture
uniform vec2 u_size;
uniform sampler2D u_texture_input;

// Card geometry (physical window px)
uniform vec2 u_card_origin;
uniform vec2 u_card_size;
uniform vec4 u_corner_radii; // TL,TR,BR,BL

// Lens
uniform float u_refraction_height; // px, edge band depth
uniform float u_refraction_amount; // px, negative = inward pull (Kyant convention)
uniform float u_depth_effect;      // 0/1 — bend normals toward radial
uniform float u_chromatic;         // 0 = off; >0 = 7-path dispersion, doubles as
                                   // a strength multiplier (Kyant ships a hard 1f;
                                   // we keep the gate and let >1 widen the fringe)

// Vibrancy (colorControls)
uniform float u_saturation; // 1.5
uniform float u_brightness; // 0
uniform float u_contrast;   // 1

// onDrawSurface layers
uniform vec4 u_tint_color;    // Hue-blend tint (a=0 off)
uniform vec4 u_surface_color; // SrcOver surface tint (a=0 off)

// Interactive highlight — press/drag glow following the pointer.
// Faithful to InteractiveHighlight.kt: radial white glow, Plus blend,
// intensity = smoothstep(radius, radius*0.5, dist), radius = minDim*1.5.
uniform vec2 u_glow_pos;     // pointer position in window physical px
uniform float u_glow_radius; // px
uniform float u_glow_alpha;  // 0.15 * pressProgress in the original

out vec4 fragColor;

float radiusAt(vec2 coord, vec4 radii) {
    if (coord.x >= 0.0) {
        return coord.y <= 0.0 ? radii.y : radii.z;
    }
    return coord.y <= 0.0 ? radii.x : radii.w;
}

float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, vec2(0.0))) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, vec2(0.0)));
    }
    // Same qx=qy diagonal crease as the original AGSL; at backdrop blur
    // sampling it stays invisible.
    float gradX = step(cornerCoord.y, cornerCoord.x);
    return sign(coord) * vec2(gradX, 1.0 - gradX);
}

float circleMap(float x) {
    float c = clamp(x, 0.0, 1.0);
    return 1.0 - sqrt(1.0 - c * c);
}

// Exact port of ColorFilter.kt colorControlsColorFilter.
vec3 applyColorControls(vec3 c, float brightness, float contrast, float saturation) {
    float invSat = 1.0 - saturation;
    float r = 0.213 * invSat;
    float g = 0.715 * invSat;
    float b = 0.072 * invSat;
    float t = (0.5 - contrast * 0.5 + brightness) * 255.0;
    float cs = contrast * saturation;
    float cr = contrast * r;
    float cg = contrast * g;
    float cb = contrast * b;
    vec3 outc;
    outc.r = (cr + cs) * c.r + cg * c.g + cb * c.b + t / 255.0;
    outc.g = cr * c.r + (cg + cs) * c.g + cb * c.b + t / 255.0;
    outc.b = cr * c.r + cg * c.g + (cb + cs) * c.b + t / 255.0;
    return outc;
}

// Non-separable Hue blend (Skia/W3C), not HSV hue replacement. Hue preserves
// backdrop luminosity and saturation; HSV's max-channel "value" is different.
float blendLum(vec3 c) {
    return dot(c, vec3(0.3, 0.59, 0.11));
}

float blendSat(vec3 c) {
    return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

vec3 blendHue(vec3 dst, vec3 src) {
    float srcSat = blendSat(src);
    float srcMin = min(src.r, min(src.g, src.b));
    vec3 c = srcSat > 1e-6
        ? (src - vec3(srcMin)) * (blendSat(dst) / srcSat)
        : vec3(0.0);
    c += vec3(blendLum(dst) - blendLum(c));
    float l = blendLum(c);
    float n = min(c.r, min(c.g, c.b));
    float x = max(c.r, max(c.g, c.b));
    if (n < 0.0) {
        c = vec3(l) + ((c - vec3(l)) * l) / max(l - n, 1e-6);
    }
    if (x > 1.0) {
        c = vec3(l) + ((c - vec3(l)) * (1.0 - l)) / max(x - l, 1e-6);
    }
    return c;
}

// Sampling and shape geometry are different coordinate spaces. The engine
// supplies coordinates and u_size for the INPUT TEXTURE, not the card bounds.
// The Windows backdrop probe confirms scene-sized input. Never divide by the
// card size or subtract its origin when sampling.
vec2 localUv(vec2 c) {
    vec2 uv = clamp(c / u_size, vec2(0.0), vec2(1.0));
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
    uv.y = 1.0 - uv.y;
#endif
    return uv;
}

// Each wavelength samples the color-controlled backdrop. A saturation matrix
// mixes channels, so it does NOT commute with the per-channel seven-tap weights.
// This corrects dispersion ordering; moving controls before the blur is a
// separate pipeline concern (intermediate clamping can affect that ordering).
vec4 sampleBackdrop(vec2 coord) {
    vec4 sampleColor = texture(u_texture_input, localUv(coord));
    // Texture samples are premultiplied. Color controls operate on straight RGB;
    // in particular brightness must not create light in fully transparent input.
    vec3 straight = sampleColor.a > 1e-6
        ? sampleColor.rgb / sampleColor.a : vec3(0.0);
    sampleColor.rgb = clamp(applyColorControls(
        straight, u_brightness, u_contrast, u_saturation), 0.0, 1.0) * sampleColor.a;
    return sampleColor;
}

void sourceOver(inout vec3 color, inout float alpha, vec3 source, float coverage) {
    color = source * coverage + color * (1.0 - coverage);
    alpha = coverage + alpha * (1.0 - coverage);
}

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 localCoord = coord - u_card_origin;
    vec2 halfSize = u_card_size * 0.5;
    vec2 centeredCoord = localCoord - halfSize;

    float radius = radiusAt(centeredCoord, u_corner_radii);
    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    // --- 1. Clip: ±0.5px AA centered ON the edge — crisp glass boundary ---
    // (discard is not permitted in Impeller runtime effects — emit transparent)
    float edgeAlpha = 1.0 - smoothstep(-0.5, 0.5, sd);
    if (sd > 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    // --- 2. Backdrop sample (the inner ImageFilter.blur already applied) ---
    vec4 backdrop = sampleBackdrop(coord);
    vec3 color = backdrop.rgb;
    float alpha = backdrop.a;

    // --- 3. Lens refraction (SDF + circleMap) ------------------------------
    if (u_refraction_height > 0.5 && (-sd) < u_refraction_height) {
        float sdClamped = min(sd, 0.0);
        float d = circleMap(1.0 - (-sdClamped) / u_refraction_height) * u_refraction_amount;

        float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
        vec2 grad = gradSdRoundedRect(centeredCoord, halfSize, gradRadius);
        vec2 depthVec = length(centeredCoord) > 1e-6 ? normalize(centeredCoord) : vec2(0.0);
        vec2 gradSum = grad + u_depth_effect * depthVec;
        if (length(gradSum) > 1e-6) grad = normalize(gradSum);

        vec2 refractedCoord = coord + d * grad;

        if (u_chromatic > 0.0) {
            // Faithful 7-path dispersion (ROYGCBP + purple), weighted channels.
            // Kyant multiplies the corner-ness factor by a hard 1f; our uniform
            // doubles as strength so dense UI can dial the fringe up (a plain
            // multiplication outside the corner-ness term — the signed product
            // and per-channel weights are unchanged).
            float dispersionIntensity = u_chromatic * ((centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y));
            vec2 dispersed = d * grad * dispersionIntensity;

            vec4 sRed    = sampleBackdrop(refractedCoord + dispersed);
            vec4 sOrange = sampleBackdrop(refractedCoord + dispersed * (2.0 / 3.0));
            vec4 sYellow = sampleBackdrop(refractedCoord + dispersed * (1.0 / 3.0));
            vec4 sGreen  = sampleBackdrop(refractedCoord);
            vec4 sCyan   = sampleBackdrop(refractedCoord - dispersed * (1.0 / 3.0));
            vec4 sBlue   = sampleBackdrop(refractedCoord - dispersed * (2.0 / 3.0));
            vec4 sPurple = sampleBackdrop(refractedCoord - dispersed);

            vec3 dispColor = vec3(0.0);
            float dispAlpha = 0.0;
            dispColor.r += sRed.r / 3.5;                    dispAlpha += sRed.a / 7.0;
            dispColor.r += sOrange.r / 3.5;
            dispColor.g += sOrange.g / 7.0;                 dispAlpha += sOrange.a / 7.0;
            dispColor.r += sYellow.r / 3.5;
            dispColor.g += sYellow.g / 3.5;                 dispAlpha += sYellow.a / 7.0;
            dispColor.g += sGreen.g / 3.5;                  dispAlpha += sGreen.a / 7.0;
            dispColor.g += sCyan.g / 3.5;
            dispColor.b += sCyan.b / 3.0;                   dispAlpha += sCyan.a / 7.0;
            dispColor.b += sBlue.b / 3.0;                   dispAlpha += sBlue.a / 7.0;
            dispColor.r += sPurple.r / 7.0;
            dispColor.b += sPurple.b / 3.0;                 dispAlpha += sPurple.a / 7.0;

            color = dispColor;
            alpha = dispAlpha;
        } else {
            vec4 refracted = sampleBackdrop(refractedCoord);
            color = refracted.rgb;
            alpha = refracted.a;
        }
    }

    // --- 4. onDrawSurface: tint (Hue blend) then surfaceColor (SrcOver) ----
    if (u_tint_color.a > 0.001) {
        vec3 straight = alpha > 1e-6 ? color / alpha : vec3(0.0);
        vec3 hueBlended = blendHue(straight, u_tint_color.rgb);
        // Blend applies only where source and backdrop overlap. Outside the
        // backdrop, the tint contributes its own color, not a black Hue result.
        color = color * (1.0 - u_tint_color.a)
              + u_tint_color.a * ((1.0 - alpha) * u_tint_color.rgb + alpha * hueBlended);
        alpha = u_tint_color.a + alpha * (1.0 - u_tint_color.a);
        sourceOver(color, alpha, u_tint_color.rgb, 0.75 * u_tint_color.a);
    }
    if (u_surface_color.a > 0.001) {
        sourceOver(color, alpha, u_surface_color.rgb, u_surface_color.a);
    }

    // --- 5. Interactive highlight: two Plus layers per Kyant InteractiveHighlight.kt ---
    if (u_glow_alpha > 0.001) {
        float press = u_glow_alpha / 0.15;
        vec2 gpos = clamp(u_glow_pos, u_card_origin, u_card_origin + u_card_size);
        // Layer 1: flat whole bounds Plus (0.08 * press)
        color += vec3(1.0) * (0.08 * press);
        alpha = min(1.0, alpha + 0.08 * press);
        // Layer 2: radial Plus at pointer (0.15 * press)
        float glowDist = distance(coord, gpos);
        float glowI = smoothstep(u_glow_radius, u_glow_radius * 0.5, glowDist);
        color += vec3(1.0) * glowI * (0.15 * press);
        alpha = min(1.0, alpha + glowI * (0.15 * press));
    }

    // Dispersion's unequal channel weights can exceed averaged alpha at a
    // transparent boundary. Clamp to representable premultiplied coverage, and
    // apply the geometric AA to all four channels, not just alpha.
    fragColor = vec4(clamp(color, vec3(0.0), vec3(alpha)), alpha) * edgeAlpha;
}
