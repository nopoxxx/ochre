.pragma library
.import "common.js" as C
.import "apps.js" as A
.import "binds.js" as B
.import "themes.js" as P

// Генерация ~/.config/niri/ochre/*.kdl: niriFiles(), в каком файле живёт настройка, анимации и шейдеры, мониторы.
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.

var WIDTHS = C.WIDTHS;
var q = C.q;
var f = C.f;
var head = C.head;
var text = C.text;
var BROWSERS = A.BROWSERS;
var termCmd = A.termCmd;
var filesCmd = A.filesCmd;
var MUTE_BINDS = B.MUTE_BINDS;
var COMBO_RE = B.COMBO_RE;

// окружение программ при включённых темах (shell.theme.sync). niri получает его блоком environment в misc.kdl,
// но выдаёт только тому, что запустит после этого; программам, которые запускает сам shell, — Settings.appEnv()
var APP_ENV = { QT_QPA_PLATFORMTHEME: "qt6ct" };

// ── анимации niri ──────────────────────────────────────────────────

// terminal: окно выводится строками сверху вниз, курсор █ цвета акцента — в начале следующей строки
const OPEN_SHADER = [
    "vec4 open_color(vec3 coords_geo, vec3 size_geo) {",
    "    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)",
    "        return vec4(0.0);",
    "    float row = 24.0 / size_geo.y;",
    "    float done = floor(niri_clamped_progress * ceil(1.0 / row)) * row;",
    "    if (coords_geo.y < done)",
    "        return texture2D(niri_tex, (niri_geo_to_tex * coords_geo).st);",
    "    float px = coords_geo.x * size_geo.x;",
    "    if (niri_clamped_progress < 1.0 && coords_geo.y < done + row && px >= 4.0 && px < 16.0)",
    "        return ACCENT;",
    "    return vec4(0.0);",
    "}"
];

// terminal: закрытое окно сжимается в линию, линия — в точку и гаснет, как выключенный кинескоп
const CLOSE_SHADER = [
    "vec4 close_color(vec3 coords_geo, vec3 size_geo) {",
    "    float p = niri_clamped_progress;",
    "    float sy = max(1.0 - p / 0.6, 2.0 / size_geo.y);",
    "    float sx = max(1.0 - max(p - 0.6, 0.0) / 0.4, 0.002);",
    "    vec2 c = (coords_geo.xy - 0.5) / vec2(sx, sy) + 0.5;",
    "    if (c.x < 0.0 || c.x > 1.0 || c.y < 0.0 || c.y > 1.0)",
    "        return vec4(0.0);",
    "    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * vec3(c, 1.0)).st);",
    "    color.rgb = mix(color.rgb, vec3(color.a), smoothstep(0.2, 0.6, p));",
    "    return color * (1.0 - smoothstep(0.85, 1.0, p));",
    "}"
];

// "#fabd2f" → "vec4(0.980, 0.741, 0.184, 1.0)"
function glslColor(hex) {
    const n = [1, 3, 5].map(i => (parseInt(hex.substr(i, 2), 16) / 255).toFixed(3));
    return "vec4(" + n.join(", ") + ", 1.0)";
}

// строки внутрь animations { } для пресета
function animBlocks(style, accent) {
    const block = (name, body) => ["    " + name + " {", ...body.map(l => l === "" ? "" : "        " + l), "    }"];
    const ease = (ms, curve) => ["duration-ms " + ms, "curve " + q(curve)];
    const spring = (d, k, e) => ["spring damping-ratio=" + d + " stiffness=" + k + " epsilon=" + e];
    // в сыром KDL-строке r"…" нет экранирования — в шейдерах не должно быть кавычек
    const shader = lines => ["custom-shader r\"", ...lines.map(l => "    " + l.replace("ACCENT", glslColor(accent))), "\""];
    switch (style) {
    case "snappy": return [
        ...block("workspace-switch", ease(150, "ease-out-cubic")),
        ...block("horizontal-view-movement", ease(150, "ease-out-cubic")),
        ...block("window-movement", ease(120, "ease-out-cubic")),
        ...block("window-resize", ease(120, "ease-out-cubic")),
        ...block("window-open", ease(100, "ease-out-expo")),
        ...block("window-close", ease(80, "ease-out-quad")),
        ...block("overview-open-close", ease(150, "ease-out-cubic"))
    ];
    case "bouncy": return [
        ...block("workspace-switch", spring(0.7, 800, 0.0001)),
        ...block("horizontal-view-movement", spring(0.7, 600, 0.0001)),
        ...block("window-movement", spring(0.65, 600, 0.0001)),
        ...block("window-resize", spring(0.75, 600, 0.0001)),
        ...block("window-open", spring(0.6, 600, 0.001)),
        ...block("overview-open-close", spring(0.75, 700, 0.0001))
    ];
    case "terminal": return [
        ...block("window-open", [...ease(240, "linear"), ...shader(OPEN_SHADER)]),
        ...block("window-close", [...ease(260, "linear"), ...shader(CLOSE_SHADER)])
    ];
    default: return [];
    }
}

// горячие углы: ключ настройки → имя угла в niri (gestures { hot-corners { … } })
var HOT_CORNERS = [["niri.hc.topLeft", "top-left"], ["niri.hc.topRight", "top-right"],
    ["niri.hc.bottomLeft", "bottom-left"], ["niri.hc.bottomRight", "bottom-right"]];

// ── мониторы ───────────────────────────────────────────────────────

var TRANSFORMS = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"];

// transform из JSON niri («Normal», «_90», «Flipped90») → значение для конфига
function niriTransform(t) {
    const s = String(t ?? "normal").toLowerCase().replace(/^_/, "");
    if (s === "flipped" || !s.startsWith("flipped")) return s;
    return "flipped-" + s.slice(7);
}

// логический размер: пиксели режима / масштаб, при повороте на 90° стороны меняются
function logicalSize(mode, scale, transform) {
    const m = String(mode).match(/^(\d+)x(\d+)/);
    if (!m) return { w: 0, h: 0 };
    let w = Number(m[1]) / scale, h = Number(m[2]) / scale;
    if (/90|270/.test(transform)) [w, h] = [h, w];
    return { w: Math.round(w), h: Math.round(h) };
}

function outputIds(outs) {
    const full = o => o.make && o.model && o.serial ? o.make + " " + o.model + " " + o.serial : "";
    const ids = {};
    for (const o of outs) {
        const id = full(o);
        ids[o.name] = id && outs.filter(x => full(x).toLowerCase() === id.toLowerCase()).length === 1 ? id : o.name;
    }
    return ids;
}

function migrateOutputKeys(values, ids) {
    const out = {};
    let changed = false;
    for (const k in values) {
        const m = k.match(/^niri\.out\.(.+)\.(\w+)$/);
        if (!m) {
            out[k] = values[k];
            continue;
        }
        const nk = "niri.out." + (ids[m[1]] ?? m[1]) + "." + m[2];
        let v = values[k];
        if (m[2] === "place" && typeof v === "string" && v.includes(":")) {
            const i = v.indexOf(":"), to = v.slice(i + 1);
            if (ids[to]) v = v.slice(0, i + 1) + ids[to];
        }
        if (nk !== k || v !== values[k]) changed = true;
        if (nk !== k && nk in values) continue;
        out[nk] = v;
    }
    return changed ? out : null;
}

// ── файлы ~/.config/niri/ochre/ ───────────────────────────────────
// main.kdl подключает остальные; в config.kdl — include "ochre/main.kdl" и в самом конце include "ochre/keys.kdl"

var NIRI_FILES = ["input", "displays", "layout", "window-rules", "cursor", "animations", "misc", "binds"];

// в каком файле живёт настройка — для подсказки в окне настроек
function niriFileOf(key) {
    if (/^niri\.(kb|tp|mouse)\.|^niri\.(ffm|warp)$/.test(key)) return "input.kdl";
    if (/^niri\.(gaps|colWidth|center|ring|border|shadow)$/.test(key) || key === "shell.accent" || key === "shell.theme.name" || key === "shell.theme.mode") return "layout.kdl";
    if (/^niri\.rules\./.test(key)) return "window-rules.kdl";
    if (/^niri\.cursor\./.test(key)) return "cursor.kdl";
    if (/^niri\.anim/.test(key)) return "animations.kdl";
    if (key === "niri.csd" || key === "shell.theme.sync" || /^niri\.hc\./.test(key)) return "misc.kdl";
    if (/^niri\.out\./.test(key) || key === "action.displays") return "displays.kdl";
    if (key === "action.binds") return "keys.kdl";
    if (key === "shell.terminal" || key === "shell.files" || key === "shell.browser" || key in MUTE_BINDS) return "binds.kdl";
    return "";
}

// «keepassxc org.telegram.desktop» → (?i)(^|[.])(keepassxc|org[.]telegram[.]desktop)$; пусто — null
function privateAppIds(list) {
    const ids = String(list ?? "").split(/[\s,]+/).map(s => s.replace(/[^\w.-]/g, "")).filter(s => s);
    return ids.length ? "(?i)(^|[.])(" + ids.map(s => s.replace(/[.]/g, "[.]")).join("|") + ")$" : null;
}

function greeterNiri(get) {
    const bg = P.palette(get).bg;
    return "layout {\n    background-color " + q(/^#[0-9a-f]{6}$/i.test(bg) ? bg : "#1d2021") + "\n}\n";
}

// get(key) — значение с учётом умолчаний;
// outs — { имя: { enabled, mode, scale, transform, x, y, vrr, primary } }, только то, что задано вручную.
// Возвращает { "input.kdl": текст, … } — все файлы папки ochre/, кроме keys.kdl (его пишет Binds).
// sel — как выбрать этот экземпляр shell в qs (Ochre.sel): [] для конфига по умолчанию, ["-p", каталог] для пакета
const GAME_OFF = { "niri.anim": false, "niri.shadow": false, "niri.rules.inactiveOpacity": 100 };

function niriFiles(get0, outs, sel) {
    // игровой режим: поверх своих значений — без эффектов; сами настройки не меняются и вернутся при выключении
    const get = k => get0("shell.game") && k in GAME_OFF ? GAME_OFF[k] : get0(k);
    const qsRun = ["qs"].concat(sel ?? []).map(q).join(" ");
    const ipc = (t, f) => " { spawn " + ["qs", "ipc"].concat(sel ?? [], ["call", t, f]).map(q).join(" ") + "; }";
    const pal = P.palette(get);
    const accent = pal.accent;
    const ring = get("niri.ring");
    const border = get("niri.border");
    const radius = get("niri.rules.radius");
    const inactive = get("niri.rules.inactiveOpacity");
    const priv = privateAppIds(get("niri.rules.private"));
    const files = {};

    files["main.kdl"] = text([
        "// ochre: все настройки niri из ochre — по файлу на раздел.",
        "// Подключается из config.kdl: include \"ochre/main.kdl\". Свои бинды (keys.kdl) — отдельно, в конце config.kdl.",
        "",
        ...NIRI_FILES.map(n => "include " + q(n + ".kdl"))
    ]);

    files["input.kdl"] = text([
        ...head("ввод — клавиатура, мышь, тачпад"),
        "input {",
        "    keyboard {",
        "        xkb {",
        "            layout " + q(get("niri.kb.layout")),
        "            options " + q(get("niri.kb.options")),
        "        }",
        "        repeat-delay " + get("niri.kb.repeatDelay"),
        "        repeat-rate " + get("niri.kb.repeatRate"),
        get("niri.kb.numlock") ? "        numlock" : null,
        "    }",
        "    touchpad {",
        get("niri.tp.tap") ? "        tap" : null,
        get("niri.tp.natural") ? "        natural-scroll" : null,
        "    }",
        "    mouse {",
        "        accel-speed " + f(get("niri.mouse.accel")),
        "        accel-profile " + q(get("niri.mouse.profile")),
        "    }",
        get("niri.ffm") ? "    focus-follows-mouse" : null,
        get("niri.warp") ? "    warp-mouse-to-focus" : null,
        "}"
    ]);

    const displays = head("мониторы — окно мониторов (Mod+S → system/ → мониторы)");
    for (const name in outs) {
        const o = outs[name];
        const body = [];
        if (o.enabled === false) {
            body.push("    off");
        } else {
            if (o.mode) body.push("    mode " + q(o.mode));
            if (o.scale !== undefined) body.push("    scale " + f(o.scale));
            if (o.transform) body.push("    transform " + q(o.transform));
            // окно мониторов пишет обе координаты, но в старых настройках бывает одна — вторая тогда 0
            if (o.x !== undefined || o.y !== undefined) body.push("    position x=" + Math.round(o.x ?? 0) + " y=" + Math.round(o.y ?? 0));
            if (o.vrr) body.push("    variable-refresh-rate");
            if (o.primary) body.push("    focus-at-startup");
        }
        if (body.length) displays.push("output " + q(name) + " {", ...body, "}", "");
    }
    if (displays.length === 4) displays.push("// ничего не задано — niri настраивает мониторы сам");
    files["displays.kdl"] = text(displays);

    files["layout.kdl"] = text([
        ...head("раскладка окон — отступы, колонки, рамка фокуса, обводка, тени"),
        "layout {",
        "    // прозрачный фон: под рабочими столами видны обои quickshell",
        '    background-color "transparent"',
        "    gaps " + get("niri.gaps"),
        "    center-focused-column " + q(get("niri.center")),
        "    preset-column-widths {",
        "        proportion 0.33333",
        "        proportion 0.5",
        "        proportion 0.66667",
        "    }",
        "    default-column-width { proportion " + WIDTHS[get("niri.colWidth")] + "; }",
        "    focus-ring {",
        ...(ring > 0
            ? ["        width " + ring, "        active-color " + q(accent), "        inactive-color " + q(pal.bg2)]
            : ["        off"]),
        "    }",
        "    border {",
        ...(border > 0
            ? ["        width " + border, "        active-color " + q(accent), "        inactive-color " + q(pal.bg2), "        urgent-color " + q(pal.red)]
            : ["        off"]),
        "    }",
        "    shadow {",
        get("niri.shadow") ? "        on" : null,
        "        softness 30",
        "        spread 5",
        "        offset x=0 y=5",
        '        color "#0007"',
        "    }",
        "}"
    ]);

    files["window-rules.kdl"] = text([
        ...head("правила окон"),
        ...(radius > 0 ? [
            "// скруглённые углы у всех окон",
            "window-rule {",
            "    geometry-corner-radius " + radius,
            "    clip-to-geometry true",
            "}",
            ""] : []),
        ...(inactive < 100 ? [
            "// неактивные окна полупрозрачные",
            "window-rule {",
            "    match is-active=false",
            "    opacity " + (inactive / 100).toFixed(2),
            "}",
            ""] : []),
        ...(priv ? [
            "// приватные окна: в стримах — чёрный прямоугольник, на экране — зелёная обводка",
            "window-rule {",
            "    match app-id=" + q(priv),
            "    block-out-from " + q(get("niri.rules.privateShots") ? "screen-capture" : "screencast"),
            "    border {",
            "        on",
            "        width " + Math.max(border, 2),
            "        active-color " + q(pal.green),
            "        inactive-color " + q(pal.green),
            "    }",
            "}",
            ""] : []),
        "// терминалы, открытые из меню ochre (install / remove / update …), — плавающие по центру",
        "window-rule {",
        // [.] вместо \. — в строках KDL такой escape недопустим
        '    match app-id="^(ochre-term|dev[.]ochre[.]term)$"',
        "    open-floating true",
        "    default-column-width { fixed 960; }",
        "    default-window-height { fixed 600; }",
        "}",
        "",
        "// обои quickshell видны и как фон режима обзора",
        "layer-rule {",
        '    match namespace="^ochre-wallpaper$"',
        "    place-within-backdrop true",
        "}"
    ]);

    files["cursor.kdl"] = text([
        ...head("курсор"),
        "cursor {",
        "    xcursor-size " + get("niri.cursor.size"),
        get("niri.cursor.hide") ? "    hide-when-typing" : null,
        "}"
    ]);

    files["animations.kdl"] = text([
        ...head("анимации"),
        "animations {",
        get("niri.anim") ? null : "    off",
        "    slowdown " + f(get("niri.anim.slowdown")),
        ...animBlocks(get("niri.anim.style"), accent),
        "}"
    ]);

    files["misc.kdl"] = text([
        ...head("прочее"),
        "// просить приложения не рисовать свои заголовки",
        "prefer-no-csd " + (get("niri.csd") ? "true" : "false"),
        "",
        "// горячие углы открывают обзор; ни одного — off (пустой блок niri понял бы как «по умолчанию»)",
        "gestures {",
        "    hot-corners {",
        ...(HOT_CORNERS.some(([k]) => get(k)) ? HOT_CORNERS.filter(([k]) => get(k)).map(([, c]) => "        " + c) : ["        off"]),
        "    }",
        "}",
        ...(get("shell.theme.sync") ? [
            "",
            "// Qt-приложения берут палитру и шрифт из qt6ct — его настраивает shell (темы Qt и GTK)",
            "environment {",
            ...Object.keys(APP_ENV).map(k => "    " + k + " " + q(APP_ENV[k])),
            "}"] : [])
    ]);

    files["binds.kdl"] = text([
        ...head("клавиши ochre и автозапуск shell. Свои — в окне биндов (Mod+S → input/ → бинды), они в keys.kdl"),
        "spawn-at-startup " + qsRun,
        "",
        "binds {",
        "    Mod+Return hotkey-overlay-title=" + q("Open a Terminal: " + get("shell.terminal")) + " { spawn " + termCmd(get("shell.terminal")).map(q).join(" ") + "; }",
        ...(filesCmd(get("shell.terminal"), get("shell.files"))
            ? ["    Mod+E hotkey-overlay-title=" + q("Files: " + get("shell.files")) + " { spawn " + filesCmd(get("shell.terminal"), get("shell.files")).map(q).join(" ") + "; }"]
            : []),
        ...(BROWSERS[get("shell.browser")]
            ? ["    Mod+Shift+B hotkey-overlay-title=" + q("Browser: " + get("shell.browser")) + " { spawn " + q(BROWSERS[get("shell.browser")].bin) + "; }"]
            : []),
        ...Object.keys(MUTE_BINDS).filter(k => COMBO_RE.test(get(k) ?? "")).map(k =>
            "    " + get(k) + " allow-when-locked=true hotkey-overlay-title=" + q(MUTE_BINDS[k].title) + " { " + MUTE_BINDS[k].action + "; }"),
        '    Mod+D hotkey-overlay-title="Menu"' + ipc("launcher", "toggle"),
        '    Mod+Space hotkey-overlay-title="Run an Application"' + ipc("launcher", "apps"),
        '    Mod+Shift+W hotkey-overlay-title="Wallpapers"' + ipc("wallpaper", "picker"),
        '    Mod+Shift+V hotkey-overlay-title="Clipboard History"' + ipc("clipboard", "toggle"),
        '    Mod+A hotkey-overlay-title="Home Menu"' + ipc("home", "toggle"),
        '    Mod+Alt+R hotkey-overlay-title="Record the Screen"' + ipc("record", "toggle"),
        '    Mod+Shift+S hotkey-overlay-title="Screenshot"' + ipc("shot", "region"),
        '    Print hotkey-overlay-title="Screenshot"' + ipc("shot", "region"),
        '    Mod+Shift+T hotkey-overlay-title="Copy Text from the Screen"' + ipc("shot", "ocr"),
        '    Mod+Shift+C hotkey-overlay-title="Pick a Color"' + ipc("shot", "pick"),
        '    Mod+Shift+G hotkey-overlay-title="Game Mode"' + ipc("game", "toggle"),
        '    Mod+S hotkey-overlay-title="Settings"' + ipc("settings", "toggle"),
        '    Super+Alt+L hotkey-overlay-title="Lock the Screen"' + ipc("lock", "lock"),
        "}"
    ]);

    return files;
}
