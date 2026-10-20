import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services

// Микшер: общая громкость, громкость приложений, выбор устройства вывода
TuiPopup {
    id: pop

    title: "mixer"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var nodes: Pipewire.nodes.values
    readonly property var streams: nodes.filter(n => n.isStream && !n.isSink && n.audio)
    readonly property var sinks: nodes.filter(n => !n.isStream && n.isSink && n.audio)

    function nameOf(n) {
        return n.properties?.["application.name"] || n.nickname || n.description || n.name || "?";
    }

    PwObjectTracker {
        objects: [pop.sink].concat(pop.streams, pop.sinks).filter(x => x)
    }

    VolBar { node: pop.sink; label: "master" }

    T {
        visible: pop.streams.length > 0
        text: I18n.tr("── приложения ") + "─".repeat(30)
        color: Theme.gray
    }

    Repeater {
        model: pop.streams
        VolBar {
            required property var modelData
            node: modelData
            label: pop.nameOf(modelData)
        }
    }

    T {
        text: I18n.tr("── вывод ") + "─".repeat(34)
        color: Theme.gray
    }

    Repeater {
        model: pop.sinks

        T {
            required property var modelData
            readonly property bool current: modelData === pop.sink

            text: (current ? "● " : "  ") + (modelData.description || modelData.name)
            color: current ? Theme.accent : Theme.fg

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }
}
