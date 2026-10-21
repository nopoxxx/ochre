import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Система на столе: cpu, gpu, память полосками ▕███░░▏ и скорость сети.
Item {
    id: root

    property var cfg
    property real cw
    property real ch
    property bool editing

    readonly property int cells: Math.max(4, Math.floor(width / cw) - 18)

    function bar(v) {
        const n = Math.round(Math.max(0, Math.min(1, v)) * cells);
        return "▕" + "█".repeat(n) + "░".repeat(cells - n) + "▏";
    }

    function color(v) { return v > 0.9 ? Theme.red : v > 0.7 ? Theme.yellow : Theme.accent; }

    readonly property var rows: [
        { icon: "cpu", label: "cpu", v: Sys.cpu / 100, text: Sys.cpu + "%" + (Sys.cpuTemp >= 0 ? " " + Sys.cpuTemp + "°" : "") }
    ].concat(Sys.gpu >= 0 ? [{ icon: "monitor", label: "gpu", v: Sys.gpu / 100, text: Sys.gpu + "%" + (Sys.gpuTemp >= 0 ? " " + Sys.gpuTemp + "°" : "") }] : [])
     .concat([{ icon: "mem", label: "mem", v: Sys.memTotal ? Sys.memUsed / Sys.memTotal : 0, text: Sys.memUsed.toFixed(1) + "G" }])

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.rows
            RowLayout {
                required property var modelData
                spacing: 0
                T { font.family: Theme.iconFont; text: G.g(modelData.icon) + " "; color: Theme.gray }
                T { text: modelData.label.padEnd(4); color: Theme.gray }
                T { text: root.bar(modelData.v); color: root.color(modelData.v) }
                T { text: " " + modelData.text; color: Theme.fg }
            }
        }

        T {
            text: "↓ " + Sys.fmtRate(Sys.rx).padStart(6) + "  ↑ " + Sys.fmtRate(Sys.tx).padStart(6)
            color: Theme.gray
        }

        Item { Layout.fillHeight: true }
    }

    SysUse { metrics: ["cpu", "mem", "net", "gpu", "temp"] }
}
