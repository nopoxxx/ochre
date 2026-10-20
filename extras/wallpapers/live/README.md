# Шейдерные обои

Фирменные: `ochre-rain`, `ochre-grid`, `ochre-dots`. Рядом с каждым `.frag` лежит собранный `.frag.qsb`:
после правки исходника его надо пересобрать.

```sh
qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o ochre-rain.frag.qsb ochre-rain.frag
```

Свой шейдер положите в `~/Pictures/Wallpapers` как `.frag`: shell соберёт его сам (нужен `qt6-shadertools`)
в `~/.cache/ochre/wall-shaders/`. Готовый `.qsb` тоже подойдёт.

Униформы задаёт shell, имена должны совпадать:

```glsl
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // секунды, на паузе стоит
    vec2 resolution;   // размер экрана в пикселях
    vec4 accent;       // акцент темы
    vec4 bg;           // фон темы
    vec4 fg;           // текст темы
};
```
