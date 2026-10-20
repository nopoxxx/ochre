import QtQuick
import qs
import qs.services

// действие — кнопка «открыть» (окно) или «выполнить»
Rectangle {
    id: ac
    property var win
    property var r
    property bool current

    implicitWidth: acT.implicitWidth + win.cw * 3
    implicitHeight: acT.implicitHeight + 6
    color: acHover.pressed ? Theme.accent : acHover.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
    border.color: acHover.containsMouse || current ? Theme.accent : Theme.bg2
    border.width: 1
    T {
        id: acT
        anchors.centerIn: parent
        text: ac.win.opens.includes(ac.r.action) ? I18n.tr("открыть") : I18n.tr("выполнить")
        color: acHover.pressed ? Theme.bg : Theme.accent
    }
    MouseArea {
        id: acHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ac.win.runAction(ac.r.action)
    }
}
