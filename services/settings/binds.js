.pragma library
.import "common.js" as C

// Бинды niri: сравнение сочетаний, разбор config.kdl, ввод действия → KDL, keys.kdl, группы, свои сочетания мьюта.
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.

var text = C.text;

// ── свои сочетания из настроек (type: "combo") ─────────────────────
// Пустое значение — бинда нет. action — готовая строка KDL: по ней Binds.conflict отличает этот бинд от чужих.
var MUTE_BINDS = {
    "niri.key.micMute": { title: "Mute Microphone", action: 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"' },
    "niri.key.audioMute": { title: "Mute Audio", action: 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"' }
};

// в KDL сочетание идёт без кавычек — пропускаем только имена клавиш и модификаторы через «+»
var COMBO_RE = /^[A-Za-z0-9_]+(\+[A-Za-z0-9_]+)*$/;

// ── бинды ──────────────────────────────────────────────────────────

var MODS = ["mod", "super", "ctrl", "alt", "shift", "iso_level3_shift", "iso_level5_shift"];

// ключ для сравнения: регистр и порядок модификаторов не важны, Control = Ctrl
function comboKey(c) {
    const parts = String(c).split("+").map(s => s.trim().toLowerCase()).filter(s => s);
    const key = parts.pop() ?? "";
    const mods = parts.map(m => m === "control" ? "ctrl" : m)
        .sort((a, b) => MODS.indexOf(a) - MODS.indexOf(b));
    return mods.concat([key]).join("+");
}

// группы в окне биндов: подпись «Группа: …» (как у SekaiPop, от двух биндов) — её группа, иначе по действию niri; порядок — BIND_GROUPS
const BIND_GROUPS = ["ochre", "программы", "окна", "фокус", "перемещение", "размеры", "столы", "мониторы", "звук и медиа",
                     "скриншоты", "система", "отключено", "прочее"];

function titleGroup(b) {
    const m = String(b.title ?? "").match(/^([^:]{2,24}):\s+\S/);
    return m ? m[1].trim() : "";
}

function bindGroup(b) {
    const a = String(b.action ?? "");
    if (b.off || a === "off") return "отключено";
    if (/^spawn(-sh)? "qs" "ipc"|^spawn(-sh)? "ochre" "ipc"/.test(a)) return "ochre";
    if (/^spawn/.test(a)) return /wpctl|playerctl|pactl|brightnessctl|pamixer/.test(a) ? "звук и медиа" : "программы";
    if (/screenshot/.test(a)) return "скриншоты";
    if (/workspace/.test(a)) return "столы";
    if (/monitor/.test(a)) return "мониторы";
    if (/^focus-|^switch-focus/.test(a)) return "фокус";
    if (/^(move-|consume|expel|swap)/.test(a)) return "перемещение";
    if (/width|height|maximize|fullscreen|expand-column|center-/.test(a)) return "размеры";
    if (/^(close-window|toggle-window|toggle-column|toggle-overview)/.test(a)) return "окна";
    if (/^(quit|power-|suspend|show-hotkey|toggle-keyboard|toggle-debug|do-screen)/.test(a)) return "система";
    return "прочее";
}

// список с заголовками групп: [{header, count} | {b, pos: []}]; группы из подписей — после известных, по алфавиту
function groupBinds(list) {
    // группа из подписи — только если в ней хотя бы два бинда: «Browser: helium» у ochre одна, её место — по действию
    const n = {};
    for (const b of list) { const t = titleGroup(b); if (t) n[t] = (n[t] ?? 0) + 1; }
    const by = {};
    for (const b of list) {
        const t = titleGroup(b), g = n[t] > 1 ? t : bindGroup(b);
        (by[g] = by[g] ?? []).push(b);   // ??= движок QML не понимает
    }
    const names = Object.keys(by).sort((x, y) => {
        const i = BIND_GROUPS.indexOf(x), j = BIND_GROUPS.indexOf(y);
        return (i < 0 ? 99 : i) - (j < 0 ? 99 : j) || x.localeCompare(y);
    });
    // своя группа из подписи — сразу после «ochre», а не в конце рядом с «прочее»
    const known = names.filter(n => BIND_GROUPS.includes(n)), own = names.filter(n => !BIND_GROUPS.includes(n));
    const k = known[0] === "ochre" ? 1 : 0;
    const order = known.slice(0, k).concat(own, known.slice(k));
    // flatMap движок QML не знает
    return order.reduce((out, n) => out.concat([{ header: n, count: by[n].length }], by[n].map(b => ({ b, pos: [] }))), []);
}

// однострочные бинды из блоков binds { … }: [{ combo, title, hidden, action, source }]
function parseBinds(text, source) {
    const out = [];
    let inBinds = false;
    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.trim();
        if (!inBinds) {
            if (/^binds\s*\{\s*$/.test(line)) inBinds = true;
            continue;
        }
        if (line === "}") { inBinds = false; continue; }
        if (line.startsWith("//") || line.startsWith("/-")) continue;
        const m = line.match(/^([A-Za-z0-9_]+(?:\+[A-Za-z0-9_]+)*)((?:\s+[a-z-]+=(?:"[^"]*"|[^\s{]+))*)\s*\{\s*(.*?)\s*\}\s*(?:\/\/.*)?$/);
        if (!m) continue;
        const t = m[2].match(/hotkey-overlay-title=(?:"([^"]*)"|null)/);
        out.push({
            combo: m[1],
            title: t?.[1] ?? "",
            hidden: /hotkey-overlay-title=null/.test(m[2]),
            action: m[3].replace(/;\s*$/, ""),
            source
        });
    }
    return out;
}

// действие, как его ввёл человек, → KDL:
//   close-window → close-window      focus-workspace 3 → focus-workspace 3
//   spawn kitty → spawn "kitty"      spawn kitty -e btop → spawn-sh "kitty -e btop"
//   с кавычками — как есть
function actionKdl(a) {
    a = String(a ?? "").trim().replace(/;\s*$/, "");
    if (!a || a.includes('"')) return a;
    const [name, ...args] = a.split(/\s+/);
    if (name === "spawn-sh" || (name === "spawn" && args.length > 1)) return "spawn-sh " + JSON.stringify(args.join(" "));
    return [name, ...args.map(x => /^-?\d+(\.\d+)?$/.test(x) ? x : JSON.stringify(x))].join(" ");
}

// keys: { comboKey: { combo, action, title } }; action "off" — сочетание отключено
function keysKdl(keys) {
    const lines = [
        "// ochre: свои бинды — окно биндов (Mod+S → input/ → бинды), из ~/.config/ochre/settings.json.",
        "// Подключается в config.kdl последним (include \"ochre/keys.kdl\") и перекрывает одноимённые бинды.",
        "// Ручные правки перезапишутся.",
        "",
        "binds {"
    ];
    for (const k in keys) {
        const b = keys[k];
        if (b.action === "off")
            lines.push("    " + b.combo + ' hotkey-overlay-title=null { spawn "true"; }');
        else
            lines.push("    " + b.combo + (b.title ? " hotkey-overlay-title=" + JSON.stringify(b.title) : "")
                + " { " + actionKdl(b.action) + "; }");
    }
    lines.push("}");
    return lines.join("\n") + "\n";
}
