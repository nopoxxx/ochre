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
    },
    catppuccin: {
        name: "Catppuccin",
        dark: {
            bg: "#181825", bg0: "#1e1e2e", bg1: "#313244", bg2: "#45475a", bg3: "#585b70",
            fg: "#cdd6f4", fg0: "#f5e0dc", gray: "#7f849c",
            red: "#f38ba8", green: "#a6e3a1", yellow: "#f9e2af", orange: "#fab387",
            blue: "#89b4fa", purple: "#cba6f7", aqua: "#94e2d5", ochre: "#facb9b",
            ansi: ["#45475a", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de",
                "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8"],
            icons: "Papirus-Dark"
        }
    },
    rosepine: {
        name: "Rosé Pine",
        dark: {
            bg: "#191724", bg0: "#1f1d2e", bg1: "#26233a", bg2: "#403d52", bg3: "#524f67",
            fg: "#e0def4", fg0: "#e0def4", gray: "#6e6a86",
            red: "#eb6f92", green: "#31748f", yellow: "#f6c177", orange: "#ebbcba",
            blue: "#9ccfd8", purple: "#c4a7e7", aqua: "#56949f", ochre: "#f1bf99",
            ansi: ["#26233a", "#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4",
                "#6e6a86", "#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4"],
            icons: "Papirus-Dark"
        }
    },
    tokyonight: {
        name: "Tokyo Night",
        dark: {
            bg: "#16161e", bg0: "#1a1b26", bg1: "#292e42", bg2: "#3b4261", bg3: "#545c7e",
            fg: "#c0caf5", fg0: "#c0caf5", gray: "#565f89",
            red: "#f7768e", green: "#9ece6a", yellow: "#e0af68", orange: "#ff9e64",
            blue: "#7aa2f7", purple: "#bb9af7", aqua: "#7dcfff", ochre: "#f0a766",
            ansi: ["#15161e", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
                "#414868", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5"],
            icons: "Papirus-Dark"
        }
    },
    everforest: {
        name: "Everforest",
        dark: {
            bg: "#1e2326", bg0: "#272e33", bg1: "#374145", bg2: "#414b50", bg3: "#4f5b58",
            fg: "#d3c6aa", fg0: "#d3c6aa", gray: "#859289",
            red: "#e67e80", green: "#a7c080", yellow: "#dbbc7f", orange: "#e69875",
            blue: "#7fbbb3", purple: "#d699b6", aqua: "#83c092", ochre: "#e1aa7a",
            ansi: ["#374145", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa",
                "#4f5b58", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa"],
            icons: "Papirus-Dark"
        }
    },
    kanagawa: {
        name: "Kanagawa",
        dark: {
            bg: "#16161d", bg0: "#1f1f28", bg1: "#2a2a37", bg2: "#363646", bg3: "#54546d",
            fg: "#dcd7ba", fg0: "#dcd7ba", gray: "#727169",
            red: "#e46876", green: "#98bb6c", yellow: "#e6c384", orange: "#ffa066",
            blue: "#7e9cd8", purple: "#957fb8", aqua: "#7aa89f", ochre: "#dca561",
            ansi: ["#16161d", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589", "#c8c093",
                "#727169", "#e82424", "#98bb6c", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f", "#dcd7ba"],
            icons: "Papirus-Dark"
        }
    },
    solarized: {
        name: "Solarized",
        dark: {
            bg: "#002b36", bg0: "#073642", bg1: "#1f4751", bg2: "#586e75", bg3: "#657b83",
            fg: "#839496", fg0: "#93a1a1", gray: "#586e75",
            red: "#dc322f", green: "#859900", yellow: "#b58900", orange: "#cb4b16",
            blue: "#268bd2", purple: "#6c71c4", aqua: "#2aa198", ochre: "#b58900",
            ansi: ["#073642", "#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198", "#eee8d5",
                "#002b36", "#cb4b16", "#586e75", "#657b83", "#839496", "#6c71c4", "#93a1a1", "#fdf6e3"],
            icons: "Papirus-Dark"
        }
    },
    nord: {
        name: "Nord",
        dark: {
            bg: "#242933", bg0: "#2e3440", bg1: "#3b4252", bg2: "#434c5e", bg3: "#4c566a",
            fg: "#d8dee9", fg0: "#eceff4", gray: "#616e88",
            red: "#bf616a", green: "#a3be8c", yellow: "#ebcb8b", orange: "#d08770",
            blue: "#81a1c1", purple: "#b48ead", aqua: "#88c0d0", ochre: "#dea97e",
            ansi: ["#3b4252", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0",
                "#4c566a", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#8fbcbb", "#eceff4"],
            icons: "Papirus-Dark"
        }
    },
    dracula: {
        name: "Dracula",
        dark: {
            bg: "#21222c", bg0: "#282a36", bg1: "#44475a", bg2: "#505878", bg3: "#59658e",
            fg: "#f8f8f2", fg0: "#ffffff", gray: "#6272a4",
            red: "#ff5555", green: "#50fa7b", yellow: "#f1fa8c", orange: "#ffb86c",
            blue: "#bd93f9", purple: "#ff79c6", aqua: "#8be9fd", ochre: "#f8d97c",
            ansi: ["#21222c", "#ff5555", "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
                "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5", "#d6acff", "#ff92df", "#a4ffff", "#ffffff"],
            icons: "Papirus-Dark"
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
    const pick = (o, k) => o && Object.prototype.hasOwnProperty.call(o, k) ? o[k] : undefined;
    const theme = pick(user, name) ?? pick(THEMES, name) ?? THEMES.gruvbox;
    const base = THEMES.gruvbox.dark;
    const own = theme.dark ?? theme.light ?? base;
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
