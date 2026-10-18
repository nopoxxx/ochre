import QtQuick
import QtQuick.Layouts
import qs

// Кнопка меню home в рамке, с полями — по ней легко попасть мышкой: on — включено (акцент), current — фокус с клавиатуры.
// tile: плитка быстрых переключателей — значок, название и строка состояния (sub) под ним.
Rectangle {
    id: btn

    property string icon: ""
    property string text: ""
    property string sub: ""          // только у плитки: состояние под названием
    property bool tile: false
    property bool on: false
    property bool current: false
    property bool active: true       // false — нечего переключать (нет устройства)
    property color onColor: Theme.accent
    property bool more: false        // у плитки — › справа: открыть подробности (страница wi-fi, bluetooth)
    signal clicked()
    signal moreClicked()

    TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

    implicitWidth: (tile ? tileRow.implicitWidth : row.implicitWidth) + cell.advanceWidth * (tile ? 2 : 1.6)
    implicitHeight: (tile ? tileRow.implicitHeight + cell.height * 0.7 : row.implicitHeight + 6)
    color: !active ? "transparent"
        : on ? Qt.rgba(onColor.r, onColor.g, onColor.b, hover.hovered ? 0.3 : 0.18)
        : current || hover.hovered ? Theme.bg1 : "transparent"
    border.color: !active ? Theme.bg1 : current ? Theme.accent : on ? onColor : hover.hovered ? Theme.gray : Theme.bg2
    border.width: 1

    readonly property color fg: !active ? Theme.bg2 : on ? onColor : current || hover.hovered ? Theme.fg : Qt.darker(Theme.fg, 1.15)

    Row {
        id: row
        visible: !btn.tile
        anchors.centerIn: parent
        T { visible: btn.icon !== ""; font.family: Theme.iconFont; text: btn.icon + (btn.text ? " " : ""); color: btn.fg }
        T { text: btn.text; color: btn.fg; font.bold: btn.current || btn.on }
    }

    RowLayout {
        id: tileRow
        visible: btn.tile
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: cell.advanceWidth; rightMargin: cell.advanceWidth }
        spacing: cell.advanceWidth
        T {
            font.family: Theme.iconFont
            font.pixelSize: Math.round(Theme.fontSize * 1.4)
            text: btn.icon
            color: btn.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            T { Layout.fillWidth: true; elide: Text.ElideRight; text: btn.text; color: btn.fg; font.bold: true }
            T {
                visible: btn.sub !== ""
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: btn.sub
                color: btn.active ? Theme.gray : Theme.bg2
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
            }
        }
        // › — отдельная зона клика: плитка переключает, стрелка открывает подробности
        Rectangle {
            visible: btn.more
            Layout.fillHeight: true
            implicitWidth: cell.advanceWidth * 2.5
            color: moreHover.containsMouse ? Theme.bg2 : "transparent"
            T {
                anchors.centerIn: parent
                font.family: Theme.iconFont
                text: String.fromCodePoint(0xF0142)
                color: moreHover.containsMouse ? Theme.fg : Theme.gray
            }
            MouseArea {
                id: moreHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.moreClicked()
            }
        }
    }

    HoverHandler { id: hover; enabled: btn.active; cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor }
    // под содержимым: клик по › забирает своя MouseArea, плитка при этом не переключается
    MouseArea { anchors.fill: parent; z: -1; enabled: btn.active; onClicked: btn.clicked() }
}
