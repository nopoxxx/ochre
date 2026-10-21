#version 440
// ochre/rain: столбцы клеток терминала, по которым стекают строки цвета акцента
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

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    float rows = 40.0;
    vec2 cell = vec2(resolution.y / rows * 0.55, resolution.y / rows);
    vec2 px = qt_TexCoord0 * resolution;
    vec2 id = floor(px / cell);
    vec2 f = fract(px / cell);

    float col = id.x;
    float on = step(0.55, hash(vec2(col, 7.0)));
    float speed = 3.0 + hash(vec2(col, 1.0)) * 9.0;
    float len = 6.0 + hash(vec2(col, 2.0)) * 18.0;
    float period = rows + len + hash(vec2(col, 3.0)) * rows;
    float head = mod(time * speed + hash(vec2(col, 4.0)) * period, period);
    float d = head - id.y;
    float trail = d >= 0.0 && d < len ? 1.0 - d / len : 0.0;

    // «знак» в клетке: часть пикселей сетки 3×5 горит, меняется со временем
    vec2 g = floor(f * vec2(3.0, 5.0));
    float glyph = step(0.35, hash(id * 3.1 + g + floor(time * 2.0 + hash(id) * 8.0)));
    float inside = step(0.12, f.x) * step(f.x, 0.88) * step(0.1, f.y) * step(f.y, 0.9);

    float lit = on * trail * glyph * inside;
    float isHead = d >= 0.0 && d < 1.0 ? 1.0 : 0.0;
    vec3 c = mix(bg.rgb, accent.rgb, lit * 0.85);
    c = mix(c, fg.rgb, lit * isHead * 0.7);
    c *= 0.92 + 0.08 * step(0.5, fract(px.y / 3.0));
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
