pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Распознавание песни (songrec — клиент Shazam): 10 секунд звука в wav, потом `songrec audio-file-to-recognized-song`.
// Звук — системный (монитор выхода по умолчанию: pw-record со stream.capture.sink) или микрофон. Результат — уведомлением
// с [копировать] и [shazam]. Повторный вызов во время записи — отмена. Запуск — Mod+Shift+M, кнопка в home → сейчас играет,
// модуль панели songrec.
//   qs ipc call songrec recognize | mic | cancel | get
Singleton {
    id: root

    readonly property int seconds: 10
    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ochre-songrec.wav"

    property string phase: "idle"     // idle | listening | searching
    readonly property bool busy: phase !== "idle"
    property var last: null           // {title, artist, album, url}
    property bool cancelled: false
    property int remaining: 0

    function notify(title, body, critical) {
        Quickshell.execDetached(["notify-send", "-a", "ochre", "-t", "3000", "-h", "boolean:transient:true"]
            .concat(critical ? ["-u", "critical"] : []).concat([title, body]));
    }

    function recognize(mic) {
        if (busy) { cancel(); return; }
        cancelled = false;
        remaining = seconds;
        phase = "listening";
        recorder.command = ["sh", "-c", 'command -v songrec >/dev/null || exit 127; f=$1; shift; rm -f "$f"; exec pw-record "$@" "$f"',
            "sh", file].concat(mic ? [] : ["-P", "{ stream.capture.sink = true }"]);
        recorder.running = true;
        notify(I18n.tr("Слушаю…"), mic ? I18n.tr("%1 с с микрофона", seconds) : I18n.tr("%1 с системного звука", seconds));
    }

    function cancel() {
        if (!busy) return;
        cancelled = true;
        if (recorder.running) recorder.signal(2);
        if (searcher.running) searcher.signal(15);
    }

    function found(text) {
        let r = null;
        try { r = JSON.parse(text); } catch (e) {}
        const t = r?.track;
        if (!t?.title) {
            notify(I18n.tr("Песня не распознана"), I18n.tr("попробуйте ещё раз погромче или подольше"));
            return;
        }
        const album = (t.sections ?? []).map(s => (s.metadata ?? []).find(m => m.title === "Album")?.text).find(x => x) ?? "";
        last = { title: t.title, artist: t.subtitle ?? "", album, url: t.url ?? "" };
        const name = (last.artist ? last.artist + " — " : "") + last.title;
        Quickshell.execDetached(["sh", "-c", `
            a=$(notify-send -a ochre -A copy="$4" -A open="$5" "$1" "$2") || exit 0
            case $a in
                copy) printf '%s' "$1" | wl-copy ;;
                open) [ -n "$3" ] && xdg-open "$3" ;;
            esac`,
            "sh", name, album, last.url, I18n.tr("копировать"), "shazam"]);
    }

    Process {
        id: recorder
        onExited: code => {
            if (code === 127) {
                root.phase = "idle";
                root.notify(I18n.tr("songrec не установлен"), "sudo pacman -S songrec", true);
                return;
            }
            if (root.cancelled) { root.phase = "idle"; return; }
            root.phase = "searching";
            searcher.command = ["songrec", "audio-file-to-recognized-song", root.file];
            searcher.running = true;
        }
    }

    Timer {
        running: root.phase === "listening" && recorder.running
        interval: 1000
        repeat: true
        onTriggered: if (--root.remaining <= 0) recorder.signal(2)
    }

    Process {
        id: searcher
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: code => {
            root.phase = "idle";
            if (root.cancelled) return;
            if (code === 0) root.found(out.text);
            else root.notify(I18n.tr("songrec: ошибка"), err.text.trim().split("\n").pop() || I18n.tr("нет связи с Shazam?"), true);
        }
    }

    IpcHandler {
        target: "songrec"
        function recognize(): void { root.recognize(false); }
        function mic(): void { root.recognize(true); }
        function cancel(): void { root.cancel(); }
        function get(): string {
            if (root.busy) return root.phase;
            return root.last ? (root.last.artist ? root.last.artist + " — " : "") + root.last.title + (root.last.url ? "\n" + root.last.url : "") : "";
        }
    }
}
