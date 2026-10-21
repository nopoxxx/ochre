#version 440
// ochre/grid: солнце в полосах над сеткой, которая едет навстречу; горизонт и сетка — цвета акцента
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 accent;
    vec4 bg;
    vec4 fg;
};

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    float horizon = 0.62;
    vec3 c = bg.rgb;

    if (uv.y < horizon) {
        // небо: к горизонту теплее
        float t = uv.y / horizon;
        c = mix(bg.rgb, mix(bg.rgb, accent.rgb, 0.22), pow(t, 3.0));
        // солнце с полосами, которые сползают вниз
        vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - horizon + 0.02);
        float r = length(p);
        float sun = smoothstep(0.205, 0.2, r);
        float band = (uv.y - (horizon - 0.2)) / 0.2;
        float slats = step(0.5 * clamp(band, 0.0, 1.0), fract(uv.y * 34.0 - time * 0.35));
        sun *= band < 0.0 ? 1.0 : slats;
        c = mix(c, mix(accent.rgb, fg.rgb, 0.25 * (1.0 - t)), sun);
        c += accent.rgb * 0.18 * smoothstep(0.45, 0.2, r);
    } else {
        // пол: перспектива, линии едут к зрителю
        float z = (uv.y - horizon) / (1.0 - horizon);
        float depth = 1.0 / max(z, 0.002);
        float x = (uv.x - 0.5) * aspect * depth;
        float y = depth + time * 1.2;
        float dx = 0.5 - abs(fract(x) - 0.5);
        float dy = 0.5 - abs(fract(y) - 0.5);
        float lx = 1.0 - smoothstep(0.0, fwidth(x) * 1.5, dx);
        float ly = 1.0 - smoothstep(0.0, fwidth(y) * 1.5, dy);
        float line = max(lx, ly) * clamp(z * 4.0, 0.0, 1.0);
        c = mix(bg.rgb, accent.rgb, line * 0.75);
        c += accent.rgb * 0.12 * (1.0 - z);
    }

    // строки кинескопа
    c *= 0.9 + 0.1 * step(0.5, fract(uv.y * resolution.y / 3.0));
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
