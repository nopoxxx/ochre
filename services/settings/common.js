.pragma library

// Общее для модулей настроек: акценты, списки анимаций, варианты скриншотов, помощники KDL (q, f, head, text).
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.

// ochre — цвет бренда (gruvbox neutral yellow), он же по умолчанию; остальные — bright-цвета палитры
const ACCENTS = {
    ochre: "#d79921",
    yellow: "#fabd2f",
    orange: "#fe8019",
    green: "#b8bb26",
    aqua: "#8ec07c",
    blue: "#83a598",
    purple: "#d3869b",
    red: "#fb4934"
};

const WIDTHS = { "1/3": "0.33333", "1/2": "0.5", "2/3": "0.66667", "1": "1.0" };

// анимации: окна shell (Reveal.qml) — меню Mod+D, меню home, уведомления; пресеты niri — animBlocks()
var SHELL_ANIMS = ["slide", "fade", "pop", "unfold", "type", "none"];
const SHELL_ANIM_HINT = "slide — выезжает, fade — проявляется, pop — вырастает из центра, unfold — разворачивается сверху вниз, type — печатается по символу из случайных знаков";
var NIRI_ANIMS = ["default", "snappy", "bouncy", "terminal"];

// ── генерация KDL ──────────────────────────────────────────────────

const q = s => JSON.stringify(String(s));
const f = x => Number(x).toFixed(2);

// ── скриншоты (ShotWindow) ───────────────────────────────────────────
var SHOT_TOOLS = ["rect", "ellipse", "line", "arrow", "pen", "marker", "text", "step", "blur", "pixel"];
var SHOT_COLORS = ["red", "orange", "yellow", "green", "aqua", "blue", "purple", "white", "black"];   // = ShotWindow.colors

function head(what) {
    return [
        "// ochre: " + what,
        "// Сгенерировано ochre (Mod+S) из ~/.config/ochre/settings.json — ручные правки перезапишутся.",
        "// Свои настройки пишите в ~/.config/niri/config.kdl.",
        ""
    ];
}

function text(lines) {
    return lines.filter(l => l !== null).join("\n") + "\n";
}
