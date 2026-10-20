import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/glyphs.js" as G

// Индикатор на экране: громкость и яркость при изменении — клавишами, колёсиком по vol, из pavucontrol.
//    vol ▕██████████████░░░░░░░░░░▏  62%
// Не перехватывает клики, на мониторе с фокусом; пока открыто меню home — молчит (там свои ползунки).
// Настройки: shell.osd, shell.osd.position.
Scope {
    id: root

    readonly property bool enabled: Settings.get("shell.osd") && !Settings.greeterMode
    property string kind: ""          // vol | bright
    property bool shown: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    // смена устройства по умолчанию (подключили наушники) — не изменение громкости
    property var lastSink: null
    property bool ready: false
    Timer { interval: 1500; running: true; onTriggered: root.ready = true }   // начальные значения при старте — тоже не повод

    function pop(k) {
        if (!enabled || !ready || Home.open) return;
        kind = k;
        shown = true;
        hide.restart();
    }

    function sinkMoved() {
        if (sink === lastSink) pop("vol");
        else lastSink = sink;   // сменилось устройство: запоминаем, без индикатора
    }

    Component.onCompleted: lastSink = sink
    onVolChanged: sinkMoved()
    onMutedChanged: sinkMoved()

    property int lastBright: -1
    Connections {
        target: Brightness
        function onRawChanged() {
            if (root.lastBright >= 0 && Brightness.raw !== root.lastBright) root.pop("bright");
            root.lastBright = Brightness.raw;
        }
    }

    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }

    LazyLoader {
        active: root.shown

        PanelWindow {
            readonly property string pos: Settings.get("shell.osd.position")

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { bottom: pos === "bottom"; top: pos === "top" }
            margins { bottom: pos === "bottom" ? 80 : 0; top: pos === "top" ? 80 : 0 }
            implicitWidth: box.width
            implicitHeight: box.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "ochre-osd"
            mask: Region {}

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            Rectangle {
                id: box

                readonly property bool isVol: root.kind === "vol"
                readonly property real value: isVol ? Math.min(1, root.vol) : Brightness.value
                readonly property bool off: isVol && root.muted
                readonly property int cells: 24
                readonly property int filled: Math.round(value * cells)

                width: row.implicitWidth + Theme.pad * 2
                height: row.implicitHeight + Theme.pad
                color: Theme.bg
                border.color: off ? Theme.gray : Theme.accent
                border.width: 2

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 0

                    T {
                        font.family: Theme.iconFont
                        text: (box.isVol ? G.g(box.off ? "volOff" : "vol") : G.g("bright")) + " "
                        color: box.off ? Theme.gray : Theme.accent
                    }
                    T { text: (box.isVol ? "vol" : I18n.tr("яркость")) + " "; color: Theme.gray }
                    T {
                        text: "▕" + "█".repeat(box.filled) + "░".repeat(box.cells - box.filled) + "▏"
                        color: box.off ? Theme.gray : Theme.accent
                    }
                    T {
                        text: box.off ? " muted" : (" " + Math.round(box.value * 100) + "%").padStart(5)
                        color: Theme.fg
                    }
                }
            }
        }
    }
}
