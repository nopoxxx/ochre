import Quickshell
import QtQuick
import qs
import qs.bar
import qs.services

// 21:40 — клик: календарь
Seg {
    id: root

    readonly property string format: Settings.get("shell.bar.clock")

    // I18n.locale — «ddd» на языке интерфейса (Qt.formatDate всегда пишет по-английски)
    value: I18n.locale.toString(clock.date, format)
    compact: value.split(/[ :]/).join("\n")
    valueColor: Theme.orange
    bold: true
    onLeftClicked: cal.toggle()

    SystemClock {
        id: clock
        precision: root.format.includes("ss") ? SystemClock.Seconds : SystemClock.Minutes
    }

    CalPopup { id: cal; owner: root; bar: root.bar }
}
