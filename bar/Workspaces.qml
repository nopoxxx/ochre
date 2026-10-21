import QtQuick
import qs
import qs.services

// ~/ws/{1,[2],3} — как раскрытие скобок в shell.
// Показаны столы с окнами и активный; клик — перейти. Колёсико листает столы по всей панели (Bar.qml).
Item {
    id: root

    property var bar
    property bool available: true

    readonly property string output: bar?.screen?.name ?? ""
    readonly property var wsList: {
        const l = Niri.workspaces.filter(w => w.output === output);
        return l.length ? l : Niri.workspaces;
    }
    readonly property var shown: wsList.filter(w => w.is_active || w.is_urgent || Niri.windowsOn(w.id).length > 0)
    readonly property bool braces: shown.length > 1
    readonly property bool vertical: bar?.vertical ?? false

    implicitWidth: vertical ? col.implicitWidth : row.implicitWidth
    implicitHeight: vertical ? col.implicitHeight : row.implicitHeight

    Column {
        id: col
        visible: root.vertical

        Repeater {
            model: root.vertical ? root.shown : []

            BarText {
                required property var modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.name ?? String(modelData.idx)
                color: modelData.is_urgent ? Theme.red : modelData.is_active ? Theme.accent : Theme.blue
                font.bold: modelData.is_active

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspace(parent.modelData)
                }
            }
        }
        BarText { visible: Niri.overview; anchors.horizontalCenter: parent.horizontalCenter; text: "ov"; color: Theme.purple }
    }

    Row {
        id: row
        visible: !root.vertical

        BarText { text: "~/ws/"; color: Theme.blue }
        BarText { visible: root.braces; text: "{"; color: Theme.gray }

        Repeater {
            model: root.shown

            Row {
                id: ws

                required property var modelData
                required property int index
                readonly property string name: modelData.name ?? String(modelData.idx)

                BarText { visible: ws.index > 0; text: ","; color: Theme.gray }
                BarText {
                    text: ws.modelData.is_active && root.braces ? "[" + ws.name + "]" : ws.name
                    color: ws.modelData.is_urgent ? Theme.red : ws.modelData.is_active ? Theme.accent : Theme.blue
                    font.bold: ws.modelData.is_active

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Niri.focusWorkspace(ws.modelData)
                    }
                }
            }
        }

        BarText { visible: root.braces; text: "}"; color: Theme.gray }
        BarText { visible: Niri.overview; text: " (overview)"; color: Theme.purple }
    }
}
