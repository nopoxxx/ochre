import QtQuick
import qs
import qs.bar
import qs.services

// timer 04:32 чай — таймер (services/Countdown.qml); без таймера модуля не видно.
// Клик — пауза / продолжить, правый — остановить, колёсико — ±1 мин. Запуск — из меню: «timer 25m чай».
Seg {
    id: root

    available: Countdown.active
    label: "timer"
    value: Countdown.fmt(Countdown.left) + (Countdown.paused ? " ‖" : "") + (Countdown.label ? " " + Countdown.label : "")
    valueColor: Countdown.paused ? Theme.gray : Countdown.left <= 10 ? Theme.red : Theme.accent
    bold: !Countdown.paused

    onLeftClicked: Countdown.toggle()
    onRightClicked: Countdown.stop()
    scrollable: true
    onScrolled: dir => Countdown.add(dir * 60)
}
