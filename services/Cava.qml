pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import "settings.js" as S

// Полоски звука ▁▃▅▇ из cava (raw ascii в stdout) — для модуля media на панели и секции «сейчас играет» в home.
// cava работает, только пока что-то играет и полоски где-то видны: модуль media на панели (shell.bar.viz)
// или открытое меню home с секцией media (shell.home.viz). Нет cava — полосок нет.
// Звук — shell.viz.source: player — только поток плеера (по умолчанию): его процесс MPRIS по dbusName, а поток вывода
// PipeWire — тот, чей процесс — потомок плеера (у Electron и Chromium звук выводит дочерний аудиопроцесс); его object.serial —
// source cava. Потока нет (пауза — Chromium его убирает) — нет и полосок. system — всё, что звучит (монитор вывода по умолчанию).
Singleton {
    id: root

    readonly property int count: 32
    readonly property string glyphs: "▁▂▃▄▅▆▇█"
    property var levels: []          // count чисел 0..7
    property bool installed: false

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool onBar: Settings.get("shell.bar.viz")
        && S.zoneOf(Settings.get("shell.bar.layout"), "media") !== "off"
    readonly property bool onHome: Settings.get("shell.home.viz") && Home.open
        && S.zoneOf(Settings.get("shell.home.layout"), "media", "shell.home.layout") !== "off"
    readonly property bool wanted: installed && playing && !Settings.greeterMode && (onBar || onHome)

    readonly property bool perPlayer: Settings.get("shell.viz.source") === "player"
    // источник cava: object.serial потока плеера, "auto" — весь звук, "" — потока плеера нет
    property string target: ""
    readonly property string source: perPlayer ? target : "auto"
    readonly property bool active: wanted && source !== ""

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")

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

    // ── какой поток у плеера ──
    PwObjectTracker { objects: root.outputs }
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isStream)
    // «pid serial» потоков вывода — пересчитываются, когда появляется или пропадает поток
    readonly property var pairs: outputs
        .filter(n => n.properties?.["media.class"] === "Stream/Output/Audio" && n.properties?.["application.process.id"])
        .map(n => n.properties["application.process.id"] + " " + n.properties["object.serial"])
    readonly property string query: perPlayer && wanted && player ? player.dbusName + "|" + pairs.join(",") : ""

    onQueryChanged: if (query) resolve.restart(); else target = ""
    Timer { id: resolve; interval: 150; onTriggered: if (!finder.running) finder.run(); else again.start() }
    Timer { id: again; interval: 300; onTriggered: resolve.restart() }

    Process {
        id: finder
        function run() {
            command = ["sh", "-c", `
                pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \\
                      GetConnectionUnixProcessID s "$1" 2>/dev/null | cut -d' ' -f2)
                [ -n "$pid" ] || exit 0
                shift
                for pair; do
                    p=\${pair% *} serial=\${pair#* }
                    # вверх по родителям: поток принадлежит плееру, если среди предков — процесс плеера
                    while [ "$p" -gt 1 ] 2>/dev/null; do
                        [ "$p" = "$pid" ] && { echo "$serial"; exit 0; }
                        p=$(cut -d' ' -f4 "/proc/$p/stat" 2>/dev/null) || break
                    done
                done`, "sh", root.player?.dbusName ?? ""].concat(root.pairs);
            running = true;
        }
        stdout: StdioCollector { onStreamFinished: root.target = text.trim() }
    }

    // ── cava ──
    // конфиг — на источник: смена потока = новый файл и перезапуск процесса (тем же тактом Process не перезапустить)
    readonly property string conf: dir + "/ochre-cava-" + (source || "none") + ".conf"
    property bool confReady: false

    onConfChanged: { confReady = false; writeConf.restart(); }
    Component.onCompleted: writeConf.restart()
    Timer {
        id: writeConf
        interval: 100
        onTriggered: {
            confFile.setText([
                "[general]", "bars = " + root.count, "framerate = 24", "autosens = 1",
                "[input]", "method = pipewire", "source = " + (root.source || "auto"),
                "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 7",
                "bar_delimiter = 59", "frame_delimiter = 10",
                "[smoothing]", "noise_reduction = 70", ""
            ].join("\n"));
            root.confReady = true;
        }
    }

    FileView {
        id: confFile
        path: root.conf
        printErrors: false
    }

    Process {
        running: root.active && root.confReady
        command: ["cava", "-p", root.conf]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(x => x !== "").map(Number)
        }
        onRunningChanged: if (!running) root.levels = []
    }

    IpcHandler {
        target: "cava"
        function get(): string {
            return "source " + (root.source || "—") + (root.perPlayer ? " (поток " + (root.player?.dbusName ?? "?") + ")" : " (весь звук)")
                + (root.active ? ", работает" : ", стоит");
        }
    }
}
