pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Уведомление, когда микрофон или звук по умолчанию выключается и включается — любым способом:
// бинд из input/, мультимедийная клавиша, pavucontrol, правый клик по vol (настройка shell.notify.mute).
// Смена устройства по умолчанию (подключили наушники) — не мьют: состояние нового устройства просто запоминается.
// Предыдущее уведомление о мьюте закрывается перед новым — частое переключение не копит стопку;
// transient — в историю (log) не попадает.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("shell.notify.mute") && !Settings.greeterMode

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(n => n) }

    component Watch: QtObject {
        required property var node
        required property bool mic
        property int nodeId: -1
        property var known: undefined     // последнее состояние этого устройства; undefined — ещё не знаем

        readonly property var muted: node?.audio?.muted

        function remember() {
            nodeId = node ? node.id : -1;
            known = muted;
        }

        onNodeChanged: remember()
        onMutedChanged: {
            if (muted === undefined) return;
            if (!node || node.id !== nodeId || known === undefined) { remember(); return; }
            if (muted === known) return;
            known = muted;
            if (root.enabled) root.announce(mic, muted, node.description || node.nickname || node.name || "");
        }
    }

    Watch { node: Pipewire.defaultAudioSource; mic: true }
    Watch { node: Pipewire.defaultAudioSink; mic: false }

    property string lastId: ""     // id нашего прошлого уведомления — закрыть перед новым
    property var queued: null

    function announce(mic, muted, device) {
        const title = mic ? (muted ? I18n.tr("Микрофон выключен") : I18n.tr("Микрофон включён")) : (muted ? I18n.tr("Звук выключен") : I18n.tr("Звук включён"));
        const icon = mic ? (muted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high")
            : (muted ? "audio-volume-muted" : "audio-volume-high");
        queued = [title, device, icon];
        if (!sender.running) flush();
    }

    function flush() {
        if (!queued) return;
        sender.command = ["sh", "-c", `
            [ -n "$1" ] && gdbus call --session --dest org.freedesktop.Notifications \\
                --object-path /org/freedesktop/Notifications \\
                --method org.freedesktop.Notifications.CloseNotification "$1" >/dev/null 2>&1
            notify-send -p -a ochre -t 2000 -i "$4" -h boolean:transient:true -- "$2" "$3"`,
            "sh", lastId].concat(queued);   // id — на момент отправки: прошлый send мог только что закончиться
        queued = null;
        sender.running = true;
    }

    Process {
        id: sender
        stdout: StdioCollector { onStreamFinished: root.lastId = text.trim() }
        onExited: Qt.callLater(root.flush)   // после StdioCollector: lastId должен успеть обновиться
    }
}
