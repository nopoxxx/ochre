.pragma library

var ROLES = ["bg", "bg0", "bg1", "bg2", "bg3", "hover", "fg", "fg0", "fgDim", "gray",
    "red", "green", "yellow", "orange", "blue", "purple", "aqua", "ochre"];

var THEMES = {
    gruvbox: {
        name: "Gruvbox",
        dark: {
            bg: "#1d2021", bg0: "#282828", bg1: "#3c3836", bg2: "#504945", bg3: "#665c54", hover: "#2c2928",
            fg: "#ebdbb2", fg0: "#fbf1c7", fgDim: "#ccbe9b", gray: "#928374",
            red: "#fb4934", green: "#b8bb26", yellow: "#fabd2f", orange: "#fe8019",
            blue: "#83a598", purple: "#d3869b", aqua: "#8ec07c", ochre: "#d79921",
            ansi: ["#282828", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984",
                "#928374", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#ebdbb2"],
            icons: "Gruvbox-Plus-Dark"
        }
    }
};

function mix(a, b, t) {
    const ch = (c, i) => parseInt(c.substr(1 + i * 2, 2), 16);
    let out = "#";
    for (let i = 0; i < 3; i++)
        out += ("0" + Math.round(ch(a, i) + (ch(b, i) - ch(a, i)) * t).toString(16)).slice(-2);
    return out;
}

function palette(get, user) {
    const name = get("shell.theme.name");
    const theme = (user ?? {})[name] ?? THEMES[name] ?? THEMES.gruvbox;
    const base = THEMES.gruvbox.dark;
    const own = theme.dark;
    const p = { dark: true };
    for (const r of ROLES) p[r] = own[r] ?? base[r];
    if (!own.hover) p.hover = mix(p.bg, p.bg1, 0.5);
    if (!own.fgDim) p.fgDim = mix(p.fg, p.gray, 0.3);
    const eight = [p.bg0, p.red, p.green, p.yellow, p.blue, p.purple, p.aqua, p.fg];
    p.ansi = own.ansi ?? eight.concat(eight);
    p.icons = own.icons ?? base.icons;
    p.accent = p[get("shell.accent")] ?? p.ochre;
    return p;
}
