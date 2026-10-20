import QtQuick
import qs

// много вариантов: ‹ значение ▾ ›, клик — список (DropList в окне)
Rectangle {
    id: dc
    property var win
    property var r
    property int idx

    implicitWidth: Math.max(win.cw * 16, dcT.implicitWidth + win.cw * 4)
    implicitHeight: dcT.implicitHeight + 4
    color: dcHover.containsMouse ? Theme.bg1 : "transparent"
    border.color: win.drop === idx ? Theme.accent : Theme.bg2
    border.width: 1
    T {
        id: dcT
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: dc.win.cw }
        text: dc.win.optionLabel(dc.r, dc.win.shown(dc.r))
        color: dc.win.drafted(dc.r) ? Theme.accent : Theme.fg
    }
    T {
        anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: dc.win.cw * 0.6 }
        font.family: Theme.iconFont
        text: String.fromCodePoint(0xF0140)
        color: Theme.gray
    }
    MouseArea {
        id: dcHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dc.win.drop === dc.idx ? dc.win.drop = -1 : dc.win.openDrop(dc.idx, dc)
    }
}
