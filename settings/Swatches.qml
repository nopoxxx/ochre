import QtQuick
import qs

// цвета: квадраты, выбранный — в рамке, название рядом
Row {
    id: sw
    property var win
    property var r
    property int idx

    spacing: win.cw * 0.5
    Repeater {
        model: sw.r.options
        Rectangle {
            required property var modelData
            readonly property bool sel: modelData === sw.win.shown(sw.r)
            width: Math.round(sw.win.cellH * 1.1)
            height: width
            color: "transparent"
            border.color: sel ? Theme.fg : swHover.containsMouse ? Theme.bg2 : "transparent"
            border.width: 2
            Rectangle { anchors { fill: parent; margins: 3 } color: Theme.named(parent.modelData); border.color: Theme.bg2; border.width: parent.modelData === "black" ? 1 : 0 }
            MouseArea {
                id: swHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sw.win.pick(sw.idx, parent.modelData)
            }
        }
    }
    T { anchors.verticalCenter: parent.verticalCenter; text: " " + sw.win.shown(sw.r); color: Theme.gray }
}
