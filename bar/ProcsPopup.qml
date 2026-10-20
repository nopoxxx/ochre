import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar

// Топ процессов как вывод ps; наведение показывает [kill]
TuiPopup {
    id: pop

    property string sort: "cpu"   // cpu | mem
    property var procs: []

    title: "ps --sort=-%" + sort

    Process {
        id: ps
        command: ["ps", "-eo", "pid=,pcpu=,pmem=,comm=", "--sort=-p" + pop.sort]
        stdout: StdioCollector {
            onStreamFinished: pop.procs = this.text.trim().split("\n").slice(0, 12).map(l => {
                const f = l.trim().split(/\s+/);
                return { pid: f[0], cpu: f[1], mem: f[2], comm: f.slice(3).join(" ") };
            })
        }
    }

    Timer {
        interval: 2000
        running: pop.open
        repeat: true
        triggeredOnStart: true
        onTriggered: ps.running = true
    }

    T {
        text: "    PID  %CPU  %MEM  COMMAND".padEnd(46)
        color: Theme.gray
    }

    Repeater {
        model: pop.procs

        Item {
            id: line

            required property var modelData

            implicitWidth: rowText.implicitWidth
            implicitHeight: rowText.implicitHeight

            T {
                id: rowText
                text: line.modelData.pid.padStart(7) + line.modelData.cpu.padStart(6) + line.modelData.mem.padStart(6)
                    + "  " + line.modelData.comm.slice(0, 20).padEnd(20) + "      "
                color: hover.hovered ? Theme.fg : Theme.fgDim
            }

            T {
                anchors.right: parent.right
                visible: hover.hovered
                text: "[kill]"
                color: Theme.red

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["kill", line.modelData.pid]);
                        ps.running = true;
                    }
                }
            }

            HoverHandler { id: hover }
        }
    }
}
