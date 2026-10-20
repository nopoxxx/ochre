import QtQuick
import qs

// тумблер: █ слева — выкл., справа акцентом — вкл.
Rectangle {
    property var win
    property var r
    property int idx

    readonly property bool on: win.shown(r) === true
    implicitWidth: win.cw * 5
    implicitHeight: Math.round(win.cellH * 0.95)
    color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
    border.color: on ? Theme.accent : Theme.bg2
    border.width: 1
    Rectangle {
        y: 3
        x: parent.on ? parent.width - width - 3 : 3
        width: parent.width / 2 - 3
        height: parent.height - 6
        color: parent.on ? Theme.accent : Theme.gray
        Behavior on x { NumberAnimation { duration: 90 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: win.pick(idx, !win.value(win.rows[idx]))
    }
}
