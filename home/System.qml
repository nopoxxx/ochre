import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// cpu, память, диск / и температуры полосками. ↵ — btop (или htop / top) в терминале.
Section {
    id: sec

    title: I18n.tr("система")
    count: 1

    property real diskUsed: 0
    property real diskTotal: 0
    readonly property int cells: Math.max(8, Settings.get("shell.home.width") - 26)

    function activate(i) {
        sec.panel.close();
        Term.float(["sh", "-c", "exec btop 2>/dev/null || exec htop 2>/dev/null || exec top"], { hold: false });
    }

    function bar(v) {
        const n = Math.round(Math.max(0, Math.min(1, v)) * cells);
        return "▕" + "█".repeat(n) + "░".repeat(cells - n) + "▏";
    }

    function color(v) { return v > 0.9 ? Theme.red : v > 0.7 ? Theme.yellow : Theme.accent; }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split("\n")[1]?.trim().split(/\s+/).map(Number);
                if (f?.length === 2) { sec.diskUsed = f[0] / 1073741824; sec.diskTotal = f[1] / 1073741824; }
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: df.running = true }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight
        color: sec.isCur(0) ? Theme.bg1 : "transparent"
        TapHandler { onTapped: { sec.pick(0); sec.activate(0); } }
        HoverHandler { cursorShape: Qt.PointingHandCursor }

        ColumnLayout {
            id: rows
            width: parent.width
            spacing: 0

            Repeater {
                model: [
                    { icon: "cpu", label: "cpu", v: Sys.cpu / 100, text: Sys.cpu + "%" },
                    { icon: "mem", label: "mem", v: Sys.memTotal ? Sys.memUsed / Sys.memTotal : 0,
                      text: Sys.memUsed.toFixed(1) + "/" + Sys.memTotal.toFixed(0) + "G" },
                    { icon: "disk", label: "disk /", v: sec.diskTotal ? sec.diskUsed / sec.diskTotal : 0,
                      text: Math.round(sec.diskUsed) + "/" + Math.round(sec.diskTotal) + "G" }
                ]
                RowLayout {
                    required property var modelData
                    spacing: 0
                    T { font.family: Theme.iconFont; text: " " + G.g(modelData.icon) + " "; color: Theme.gray }
                    T { text: modelData.label.padEnd(7); color: Theme.gray }
                    T { text: sec.bar(modelData.v); color: sec.color(modelData.v) }
                    T { text: " " + modelData.text; color: Theme.fg }
                }
            }

            T {
                visible: Sys.cpuTemp >= 0 || Sys.gpuTemp >= 0
                color: Theme.gray
                textFormat: Text.StyledText
                text: " " + G.g("temp") + " " + [
                    Sys.cpuTemp >= 0 ? "cpu " + Sys.cpuTemp + "°" : "",
                    Sys.gpu >= 0 ? "gpu " + Sys.gpu + "%" + (Sys.gpuTemp >= 0 ? " " + Sys.gpuTemp + "°" : "") : ""
                ].filter(x => x).join(" · ")
            }
        }
    }
}
