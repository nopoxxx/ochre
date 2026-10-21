import Quickshell
import QtQuick
import qs
import qs.services

// Часы на столе: крупные цифры из блоков, как tty-clock, и дата; размер цифр — по месту в рамке.
Item {
    id: root

    property var cfg
    property real cw
    property real ch
    property bool editing

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // «HH:mm» в «пикселях» BigClock: 4 цифры по 6, двоеточие 2 и 4 промежутка — 30 × 5
    readonly property real px: Math.max(2, Math.floor(Math.min(width / 30, (height - date.implicitHeight - root.ch * 0.5) / 5)))

    Column {
        anchors.centerIn: parent
        spacing: root.ch * 0.5

        BigClock {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            px: root.px
        }

        T {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.locale.toString(clock.date, "dddd, d MMMM")
            color: Theme.gray
        }
    }
}
