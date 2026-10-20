import QtQuick
import qs

// кнопки вариантов: [fill] [fit] [stretch]; у строк раскладки — зоны и порядок ↑↓
Row {
    id: seg
    property var win
    property var r
    property int idx

    spacing: win.cw * 0.5
    Repeater {
        model: seg.win.optionsOf(seg.r)
        Rectangle {
            required property var modelData
            readonly property bool sel: modelData === seg.win.shown(seg.r)
            width: segT.implicitWidth + seg.win.cw * 1.6
            height: segT.implicitHeight + 4
            color: sel ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : segHover.containsMouse ? Theme.bg1 : "transparent"
            border.color: sel ? Theme.accent : Theme.bg2
            border.width: 1
            T {
                id: segT
                anchors.centerIn: parent
                text: seg.win.optionLabel(seg.r, parent.modelData)
                color: parent.sel ? Theme.accent : segHover.containsMouse ? Theme.fg : Theme.gray
                font.bold: parent.sel
            }
            MouseArea {
                id: segHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seg.win.pick(seg.idx, parent.modelData)
            }
        }
    }
    // порядок модуля в зоне
    Repeater {
        model: seg.r.type === "module" ? [[-1, 0xF005D], [1, 0xF0045]] : []
        T {
            required property var modelData
            // у выключенных порядка нет — место остаётся, чтобы кнопки зон стояли ровно
            opacity: seg.r.zone !== "off" ? 1 : 0
            font.family: Theme.iconFont
            text: " " + String.fromCodePoint(modelData[1])
            color: ordHover.containsMouse ? Theme.accent : Theme.gray
            MouseArea {
                id: ordHover
                anchors.fill: parent
                enabled: seg.r.zone !== "off"
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { seg.win.focusRow(seg.idx); seg.win.reorderModule(seg.win.rows[seg.idx], parent.modelData[0]); }
            }
        }
    }
}
