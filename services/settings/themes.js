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
        },
        light: {
            bg: "#f9f5d7", bg0: "#f2e5bc", bg1: "#ebdbb2", bg2: "#d5c4a1", bg3: "#bdae93",
            fg: "#3c3836", fg0: "#282828", gray: "#7c6f64",
            red: "#9d0006", green: "#79740e", yellow: "#b57614", orange: "#af3a03",
            blue: "#076678", purple: "#8f3f71", aqua: "#427b58", ochre: "#b57614",
            ansi: ["#fbf1c7", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#7c6f64",
                "#928374", "#9d0006", "#79740e", "#b57614", "#076678", "#8f3f71", "#427b58", "#3c3836"],
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
        },
        light: {
            bg: "#eff1f5", bg0: "#e6e9ef", bg1: "#ccd0da", bg2: "#bcc0cc", bg3: "#acb0be",
            fg: "#4c4f69", fg0: "#4c4f69", gray: "#7c7f93",
            red: "#d20f39", green: "#40a02b", yellow: "#df8e1d", orange: "#fe640b",
            blue: "#1e66f5", purple: "#8839ef", aqua: "#179299", ochre: "#bb7718",
            ansi: ["#5c5f77", "#d20f39", "#40a02b", "#df8e1d", "#1e66f5", "#ea76cb", "#179299", "#acb0be",
                "#6c6f85", "#d20f39", "#40a02b", "#df8e1d", "#1e66f5", "#ea76cb", "#179299", "#bcc0cc"],
            icons: "Papirus-Light"
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
        },
        light: {
            bg: "#faf4ed", bg0: "#fffaf3", bg1: "#f2e9e1", bg2: "#dfdad9", bg3: "#cecacd",
            fg: "#575279", fg0: "#575279", gray: "#797593",
            red: "#b4637a", green: "#286983", yellow: "#ea9d34", orange: "#d7827e",
            blue: "#56949f", purple: "#907aa9", aqua: "#3f7f91", ochre: "#b77a29",
            ansi: ["#f2e9e1", "#b4637a", "#286983", "#ea9d34", "#56949f", "#907aa9", "#d7827e", "#575279",
                "#9893a5", "#b4637a", "#286983", "#ea9d34", "#56949f", "#907aa9", "#d7827e", "#575279"],
            icons: "Papirus-Light"
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
        },
        light: {
            bg: "#e1e2e7", bg0: "#d0d5e3", bg1: "#c4c8da", bg2: "#a8aecb", bg3: "#8990b3",
            fg: "#3760bf", fg0: "#3760bf", gray: "#6172b0",
            red: "#f52a65", green: "#587539", yellow: "#8c6c3e", orange: "#b15c00",
            blue: "#2e7de9", purple: "#9854f1", aqua: "#007197", ochre: "#9f641f",
            ansi: ["#e9e9ed", "#f52a65", "#587539", "#8c6c3e", "#2e7de9", "#9854f1", "#007197", "#6172b0",
                "#a1a6c5", "#f52a65", "#587539", "#8c6c3e", "#2e7de9", "#9854f1", "#007197", "#3760bf"],
            icons: "Papirus-Light"
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
        },
        light: {
            bg: "#fffbef", bg0: "#f8f5e4", bg1: "#e8e5d5", bg2: "#bec5b2", bg3: "#a6b0a0",
            fg: "#5c6a72", fg0: "#5c6a72", gray: "#829181",
            red: "#f85552", green: "#8da101", yellow: "#dfa000", orange: "#f57d26",
            blue: "#3a94c5", purple: "#df69ba", aqua: "#35a77c", ochre: "#b78300",
            ansi: ["#e8e5d5", "#f85552", "#8da101", "#dfa000", "#3a94c5", "#df69ba", "#35a77c", "#5c6a72",
                "#a6b0a0", "#f85552", "#8da101", "#dfa000", "#3a94c5", "#df69ba", "#35a77c", "#5c6a72"],
            icons: "Papirus-Light"
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
        },
        light: {
            bg: "#f2ecbc", bg0: "#e5ddb0", bg1: "#dcd5ac", bg2: "#d5cea3", bg3: "#8a8980",
            fg: "#545464", fg0: "#43436c", gray: "#716e61",
            red: "#c84053", green: "#6f894e", yellow: "#77713f", orange: "#cc6d00",
            blue: "#4d699b", purple: "#624c83", aqua: "#597b75", ochre: "#ad7700",
            ansi: ["#1f1f28", "#c84053", "#6f894e", "#77713f", "#4d699b", "#b35b79", "#597b75", "#545464",
                "#8a8980", "#d7474b", "#6e915f", "#836f4a", "#6693bf", "#624c83", "#5e857a", "#43436c"],
            icons: "Papirus-Light"
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
        },
        light: {
            bg: "#fdf6e3", bg0: "#eee8d5", bg1: "#d3d3c5", bg2: "#93a1a1", bg3: "#839496",
            fg: "#586e75", fg0: "#073642", gray: "#839496",
            red: "#dc322f", green: "#859900", yellow: "#b58900", orange: "#cb4b16",
            blue: "#268bd2", purple: "#6c71c4", aqua: "#2aa198", ochre: "#aa8100",
            ansi: ["#eee8d5", "#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198", "#073642",
                "#fdf6e3", "#cb4b16", "#93a1a1", "#839496", "#657b83", "#6c71c4", "#586e75", "#002b36"],
            icons: "Papirus-Light"
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
    const mode = get("shell.theme.mode") === "light" && theme.light ? "light" : "dark";
    const own = theme[mode] ?? theme.dark ?? theme.light ?? THEMES.gruvbox.dark;
    const isDark = own !== theme.light;
    const base = THEMES.gruvbox[isDark ? "dark" : "light"];
    const p = { dark: isDark };
    for (const r of ROLES) p[r] = own[r] ?? base[r];
    if (!own.hover) p.hover = mix(p.bg, p.bg1, 0.5);
    if (!own.fgDim) p.fgDim = mix(p.fg, p.gray, 0.3);
    const eight = [p.bg0, p.red, p.green, p.yellow, p.blue, p.purple, p.aqua, p.fg];
    p.ansi = own.ansi ?? eight.concat(eight);
    p.icons = own.icons ?? base.icons;
    p.accent = p[get("shell.accent")] ?? p.ochre;
    return p;
}

function themeStrip(name, get) {
    const p = palette(k => k === "shell.theme.name" ? name : get(k));
    return [p.bg, p.fg, p.red, p.green, p.yellow, p.blue, p.purple, p.aqua, p.ochre];
}
