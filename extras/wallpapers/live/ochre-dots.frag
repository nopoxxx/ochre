#version 440
// ochre/dots: поле точек на сетке терминала, по нему медленно идут волны цвета акцента
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

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    float rows = 40.0;
    float size = resolution.y / rows;
    vec2 px = qt_TexCoord0 * resolution;
    vec2 id = floor(px / size);
    vec2 f = fract(px / size) - 0.5;

    vec2 q = id / 14.0;
    float v = noise(q + vec2(time * 0.07, time * 0.03)) * 0.6 + noise(q * 2.3 - vec2(time * 0.05, 0.0)) * 0.4;
    v = smoothstep(0.35, 0.8, v);

    float r = mix(0.06, 0.34, v);
    float disc = smoothstep(r, r - 0.08, length(f));
    vec3 c = mix(bg.rgb, mix(bg.rgb, fg.rgb, 0.12), disc);
    c = mix(c, accent.rgb, disc * v);
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
