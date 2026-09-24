#version 460 core
#include <flutter/runtime_effect.glsl>

// Kyant directional highlight. The host draws/blurs/clips the actual outline;
// this shader supplies only its rounded-rectangle normal lighting.
uniform vec2 u_size;
uniform float u_radius;
uniform float u_angle;
uniform float u_falloff;
uniform vec4 u_color;
out vec4 fragColor;

void main() {
    vec2 halfSize = u_size * 0.5;
    vec2 p = FlutterFragCoord().xy - halfSize;
    float radius = min(u_radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - (halfSize - vec2(radius));
    vec2 corner = max(q, vec2(0.0));
    vec2 grad;
    if (length(corner) > 1e-6) {
        grad = sign(p) * normalize(corner);
    } else {
        float x = step(q.y, q.x);
        grad = sign(p) * vec2(x, 1.0 - x);
    }
    float intensity = pow(abs(dot(grad, vec2(cos(u_angle), sin(u_angle)))), u_falloff);
    float alpha = u_color.a * intensity;
    fragColor = vec4(u_color.rgb * alpha, alpha);
}
