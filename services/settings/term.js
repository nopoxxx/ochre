.pragma library
.import "themes.js" as P

var TERM_COLORS = {
    kitty: "ochre/term/kitty.conf",
    alacritty: "ochre/term/alacritty.toml",
    ghostty: "ochre/term/ghostty",
    foot: "ochre/term/foot.ini"
};

var TERM_INCLUDE = {
    kitty: "include ~/.config/ochre/term/kitty.conf",
    alacritty: 'import = ["~/.config/ochre/term/alacritty.toml"]',
    ghostty: "config-file = ?../ochre/term/ghostty",
    foot: "include=~/.config/ochre/term/foot.ini"
};

const HEAD = "# ochre: цвета терминала из темы (Mod+S → вид → тема) — сгенерировано ochre, ручные правки перезапишутся";
const NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];

function kittyColors(c) {
    const kv = (k, v) => k.padEnd(22) + v;
    return [HEAD, "",
        kv("background", c.bg), kv("foreground", c.fg), kv("cursor", c.fg), kv("cursor_text_color", c.bg),
        kv("selection_background", c.bg2), kv("selection_foreground", c.fg), kv("url_color", c.blue), "",
        ...c.ansi.map((x, i) => ("color" + i).padEnd(8) + x), ""].join("\n");
}

function alacrittyColors(c) {
    const table = (name, rows) => ["[colors." + name + "]", ...rows.map(r => r[0] + ' = "' + r[1] + '"'), ""];
    return [HEAD, "",
        ...table("primary", [["background", c.bg], ["foreground", c.fg]]),
        ...table("cursor", [["text", c.bg], ["cursor", c.fg]]),
        ...table("selection", [["text", c.fg], ["background", c.bg2]]),
        ...table("normal", NAMES.map((n, i) => [n, c.ansi[i]])),
        ...table("bright", NAMES.map((n, i) => [n, c.ansi[i + 8]]))].join("\n");
}

function ghosttyColors(c) {
    const h = x => x.slice(1);
    return [HEAD, "",
        "background = " + h(c.bg), "foreground = " + h(c.fg), "cursor-color = " + h(c.fg), "cursor-text = " + h(c.bg),
        "selection-background = " + h(c.bg2), "selection-foreground = " + h(c.fg), "",
        ...c.ansi.map((x, i) => "palette = " + i + "=" + x), ""].join("\n");
}

function footColors(c) {
    const h = x => x.slice(1);
    return [HEAD, "", "[colors-dark]",
        "background=" + h(c.bg), "foreground=" + h(c.fg),
        "selection-background=" + h(c.bg2), "selection-foreground=" + h(c.fg),
        ...c.ansi.slice(0, 8).map((x, i) => "regular" + i + "=" + h(x)),
        ...c.ansi.slice(8).map((x, i) => "bright" + i + "=" + h(x)), ""].join("\n");
}

function termFiles(get) {
    const c = P.palette(get);
    return {
        [TERM_COLORS.kitty]: kittyColors(c),
        [TERM_COLORS.alacritty]: alacrittyColors(c),
        [TERM_COLORS.ghostty]: ghosttyColors(c),
        [TERM_COLORS.foot]: footColors(c)
    };
}

function dropSections(lines, re) {
    let skip = false;
    return lines.filter(l => {
        if (/^\[/.test(l)) skip = re.test(l);
        return !skip;
    });
}

function afterHead(lines, add) {
    let i = 0;
    while (i < lines.length && /^#/.test(lines[i])) i++;
    return lines.slice(0, i).concat("", add, lines.slice(i));
}

function termMigrate(name, text) {
    text = text.replace(/\r\n/g, "\n");
    const ours = /^# ochre:/.test(text) || (/^# Gruvbox dark \(hard\)$/m.test(text) && /Terminess/.test(text));
    if (!ours || text.includes(TERM_INCLUDE[name])) return null;
    if (name === "alacritty" && /^\s*import\s*=/m.test(text)) return null;
    let lines = text.split("\n");
    const head = "# ochre: Terminess, цвета — из темы ochre (" + TERM_COLORS[name].replace("ochre/", "~/.config/ochre/") + ")";
    if (/^# ochre:/.test(lines[0])) lines[0] = head;
    else lines.unshift(head, "");
    if (name === "kitty") {
        lines = lines.filter(l => !/^(background|foreground|cursor|cursor_text_color|selection_background|selection_foreground|url_color|color\d+)\s/.test(l)
            && !/^# Gruvbox/.test(l)).concat("", TERM_INCLUDE.kitty);
    } else if (name === "ghostty") {
        lines = lines.filter(l => !/^(background|foreground|cursor-color|cursor-text|selection-background|selection-foreground|palette)\s*=/.test(l))
            .concat("", TERM_INCLUDE.ghostty);
    } else if (name === "alacritty") {
        lines = dropSections(lines, /^\[colors[.\]]/);
        const g = lines.findIndex(l => /^\[general\]\s*$/.test(l));
        if (g >= 0) lines.splice(g + 1, 0, TERM_INCLUDE.alacritty);
        else lines = afterHead(lines, ["[general]", TERM_INCLUDE.alacritty]);
    } else if (name === "foot") {
        lines = afterHead(dropSections(lines, /^\[colors(-dark|-light)?\]\s*$/), [TERM_INCLUDE.foot]);
    } else {
        return null;
    }
    return lines.join("\n").replace(/\n{3,}/g, "\n\n").replace(/\s*$/, "\n");
}

function termOsc(c) {
    const osc = (code, v) => "\x1b]" + code + ";" + v + "\x1b\\";
    return c.ansi.map((x, i) => osc(4, i + ";" + x)).join("")
        + osc(10, c.fg) + osc(11, c.bg) + osc(12, c.fg) + osc(17, c.bg2) + osc(19, c.fg);
}
