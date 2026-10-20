.pragma library
.import "themes.js" as P

var FASTFETCH_MARK = "// ochre: fastfetch";

const SEP = { type: "custom", format: "{#90}────────────────────────────────────────" };
const TITLE = { type: "title", format: "{#1;32}{user-name}{#0;90}@{#1;36}{host-name}" };
const COLORS = { type: "colors", symbol: "block", paddingLeft: 0 };

const M = {
    os: { type: "os", key: "os", format: "{pretty-name} {arch}" },
    kernel: { type: "kernel", key: "kernel", format: "{release}" },
    uptime: { type: "uptime", key: "uptime" },
    pkgs: { type: "packages", key: "pkgs" },
    wm: { type: "wm", key: "wm", format: "{pretty-name} {version}" },
    ochre: { type: "command", key: "ochre", text: "git -C ~/.config/quickshell log -1 --format='%h · %cr' 2>/dev/null || cat /usr/share/ochre/VERSION 2>/dev/null || echo '?'" },
    shell: { type: "command", key: "shell", text: "basename \"$SHELL\"" },
    term: { type: "terminal", key: "term", format: "{pretty-name} {version}" },
    cpu: { type: "cpu", key: "cpu", format: "{name} ×{cores-logical}" },
    gpu: { type: "gpu", key: "gpu", format: "{name}" },
    mem: { type: "memory", key: "mem", format: "{used} / {total} {#90}{percentage}" },
    disk: { type: "disk", key: "disk", folders: "/", format: "{size-used} / {size-total} {#90}{size-percentage}" },
    net: { type: "localip", key: "net", format: "{ifname} {ipv4}", showIpv4: true },
    temp: { type: "cpu", key: "temp", temp: true, format: "{temperature}" },
    bat: { type: "battery", key: "bat", format: "{capacity} {#90}{status}" },
    disp: { type: "display", key: "disp", format: "{width}×{height} @ {refresh-rate} Hz" },
    theme: { type: "theme", key: "theme" },
    icons: { type: "icons", key: "icons" },
    font: { type: "font", key: "font" },
    locale: { type: "locale", key: "locale" }
};
const pick = names => names.map(n => M[n]);

var FASTFETCH_STYLES = {
    panel: { logo: "ochre-large.txt",
        modules: ["break", TITLE, SEP, ...pick(["os", "kernel", "uptime", "pkgs", "wm", "ochre", "shell", "term"]), SEP,
            ...pick(["cpu", "gpu", "mem", "disk", "net"]), "break", COLORS] },
    compact: { logo: "ochre.txt",
        modules: ["break", TITLE, ...pick(["os", "wm", "shell", "term", "cpu", "mem"]), COLORS] },
    minimal: { logo: "ochre-small.txt",
        modules: ["break", TITLE, ...pick(["os", "wm", "uptime"]), "break", COLORS] },
    tty: { logo: null, box: true,
        modules: pick(["os", "kernel", "uptime", "wm", "shell", "term", "cpu", "mem", "disk"]) },
    full: { logo: "ochre-large.txt",
        modules: ["break", TITLE, SEP, ...pick(["os", "kernel", "uptime", "pkgs", "wm", "ochre", "shell", "term", "theme", "icons", "font", "locale"]), SEP,
            ...pick(["cpu", "temp", "gpu", "mem", "disk", "net", "disp", "bat"]), "break", COLORS] }
};

function ansi(hex) {
    return "38;2;" + [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16)).join(";");
}

function fastfetchConfig(get, dir) {
    const name = get("shell.fastfetch") in FASTFETCH_STYLES ? get("shell.fastfetch") : "panel";
    const st = FASTFETCH_STYLES[name];
    const color = ansi(P.palette(get).accent);
    const logo = st.logo
        ? { type: "file", source: dir + "/extras/fastfetch/" + st.logo, color: { "1": color, "2": color }, padding: { top: 1, left: 2, right: 4 } }
        : { type: "none" };
    const keys = st.box ? 10 : 8;
    let modules = st.modules;
    if (st.box) {
        const line = "─".repeat(38);
        modules = [
            "break",
            { type: "title", format: "{#" + color + "}┌─ {#1;32}{user-name}{#0;90}@{#1;36}{host-name}" },
            ...modules.map(m => Object.assign({}, m, { key: "{#" + color + "}│{#0;90} " + m.key })),
            { type: "custom", format: "{#" + color + "}└" + line },
            "break"
        ];
    }
    const display = {
        separator: "  ",
        color: { keys: "90", output: "default", separator: "90" },
        key: { width: keys },
        size: { binaryPrefix: "jedec", ndigits: 1 }
    };
    return [
        FASTFETCH_MARK + " — стиль " + name + " (Mod+S → вид → стиль fastfetch); сгенерировано ochre, ручные правки перезапишутся.",
        "// Свой конфиг: удалить эту строку — ochre перестанет его трогать.",
        "{",
        '    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",',
        '    "logo": ' + JSON.stringify(logo) + ",",
        '    "display": ' + JSON.stringify(display) + ",",
        '    "modules": [',
        modules.map(m => "        " + JSON.stringify(m)).join(",\n"),
        "    ]",
        "}",
        ""
    ].join("\n");
}
