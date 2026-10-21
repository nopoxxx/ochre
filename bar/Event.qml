import QtQuick
import qs
import qs.bar
import qs.services

// cal 14:30 standup — ближайшее событие календарей (services/Calendar.qml) в пределах 12 часов; нет — модуль скрыт.
// За shell.calendar.remind минут до начала — «через 10м», идёт — «сейчас». Клик — календарь, правый — ссылка события.
Seg {
    id: root

    readonly property var e: Calendar.next
    readonly property bool soon: e !== null && e.start - Calendar.now <= Math.max(Calendar.remind, 1) * 60000
    readonly property string name: e ? Array.from(e.title || I18n.tr("без названия")).slice(0, 24).join("") : ""

    available: e !== null
    label: "cal"
    value: !e ? "" : (e.start <= Calendar.now ? I18n.tr("сейчас") : soon ? Calendar.until(e) : I18n.locale.toString(e.start, "HH:mm")) + " " + name
    valueColor: !e ? Theme.fg : e.start <= Calendar.now ? Theme.accent : soon ? Theme.orange : Theme.aqua
    bold: soon

    onLeftClicked: cal.toggle()
    onRightClicked: if (e) Calendar.open(e)

    CalPopup { id: cal; owner: root; bar: root.bar }
}
