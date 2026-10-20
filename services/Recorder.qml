pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Запись экрана через wf-recorder: область (slurp) или монитор с фокусом, звук — по shell.rec.audio.
// Остановка — SIGINT: так wf-recorder дописывает файл. Пока идёт запись — модуль rec на панели.
//   qs ipc call record toggle | stop          (Mod+Alt+R — toggle, что записывать — shell.rec.target)
//   qs ipc call record region | screen        — начать с явной целью
Singleton {
    id: root

    property bool available: false
    property bool recording: false
    property bool selecting: false
    property date startedAt
    property string file: ""
    property int elapsed: 0           // секунд, для панели

    readonly property string dir: Settings.get("shell.rec.dir").replace(/^~(?=\/|$)/, Quickshell.env("HOME"))

    function toggle() {
        if (recording) stop();
        else start();
    }

    // target: "region" | "screen"; без него — из настроек
    function start(target) {
        if (!available || recording || selecting) return;
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        file = dir + "/rec_" + stamp + ".mp4";
        if ((target ?? Settings.get("shell.rec.target")) === "region") {
            selecting = true;
            slurp.running = true;
        } else {
            launch(["-o", Niri.focusedWorkspace?.output ?? ""]);
        }
    }

    function stop() {
        if (recording) rec.signal(2);
    }

    function launch(target) {
        const audio = Settings.get("shell.rec.audio");
        // system — монитор вывода по умолчанию, mic — источник по умолчанию (--audio без устройства)
        rec.command = ["sh", "-c", `
            mkdir -p "$1" || exit 1
            out=$2; shift 2
            case "$AUDIO" in
                system) set -- "$@" "--audio=$(pactl get-default-sink).monitor" ;;
                mic) set -- "$@" --audio ;;
            esac
            exec wf-recorder -y -f "$out" "$@" >/dev/null 2>&1`, "sh", dir, file, ...target];
        rec.environment = { AUDIO: audio };
        rec.running = true;
    }

    Process {
        command: ["sh", "-c", "command -v wf-recorder && command -v slurp"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: slurp
        command: ["slurp", "-d"]
        stdout: StdioCollector {
            onStreamFinished: {
                const geom = this.text.trim();
                root.selecting = false;
                if (geom) root.launch(["-g", geom]);   // Esc в slurp — пусто, записи нет
            }
        }
    }

    Process {
        id: rec
        onStarted: {
            root.recording = true;
            root.startedAt = new Date();
            root.elapsed = 0;
        }
        onExited: code => {
            root.recording = false;
            if (Settings.get("shell.rec.notify"))
                Quickshell.execDetached(["sh", "-c", `
                    if [ -s "$1" ]; then
                        a=$(notify-send -a ochre -i video-x-generic -A open="$3" "$4" "$1")
                        [ "$a" = open ] && xdg-open "$(dirname "$1")"
                    else
                        notify-send -a ochre -u critical "$5" "$6"
                    fi`, "sh", root.file, String(code), I18n.tr("папка"), I18n.tr("Запись сохранена"), I18n.tr("Запись не удалась"),
                    I18n.tr("wf-recorder завершился с кодом %1", code)]);
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }

    IpcHandler {
        target: "record"
        function toggle(): void { root.toggle(); }
        function region(): void { root.start("region"); }
        function screen(): void { root.start("screen"); }
        function stop(): void { root.stop(); }
    }
}
