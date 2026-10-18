pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "settings.js" as S

// Полоски звука ▁▃▅▇ из cava (raw ascii в stdout) — для модуля media на панели и секции «сейчас играет» в home.
// cava работает, только пока что-то играет и полоски где-то видны: модуль media на панели (shell.bar.viz)
// или открытое меню home с секцией media (shell.home.viz). Нет cava — полосок нет.
Singleton {
    id: root

    readonly property int count: 32
    readonly property string glyphs: "▁▂▃▄▅▆▇█"
    property var levels: []          // count чисел 0..7
    property bool installed: false

    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool onBar: Settings.get("shell.bar.viz")
        && S.zoneOf(Settings.get("shell.bar.layout"), "media") !== "off"
    readonly property bool onHome: Settings.get("shell.home.viz") && Home.open
        && S.zoneOf(Settings.get("shell.home.layout"), "media", "shell.home.layout") !== "off"
    readonly property bool active: installed && playing && !Settings.greeterMode && (onBar || onHome)

    readonly property string conf: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ochre-cava.conf"

    // n полосок: из count — максимумом по группе (n ≤ count) или повтором
    function bars(n) {
        if (!levels.length) return glyphs[0].repeat(n);
        let s = "";
        for (let i = 0; i < n; i++) {
            const a = Math.floor(i * count / n), b = Math.max(a + 1, Math.floor((i + 1) * count / n));
            let v = 0;
            for (let j = a; j < b; j++) v = Math.max(v, levels[j] ?? 0);
            s += glyphs[Math.min(7, v)];
        }
        return s;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        onExited: code => root.installed = code === 0
    }

    FileView {
        id: confFile
        path: root.conf
        printErrors: false
    }

    Component.onCompleted: confFile.setText([
        "[general]", "bars = " + count, "framerate = 24", "autosens = 1",
        "[input]", "method = pipewire",
        "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 7",
        "bar_delimiter = 59", "frame_delimiter = 10",
        "[smoothing]", "noise_reduction = 70", ""
    ].join("\n"))

    Process {
        running: root.active
        command: ["cava", "-p", root.conf]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(x => x !== "").map(Number)
        }
        onRunningChanged: if (!running) root.levels = []
    }
}
