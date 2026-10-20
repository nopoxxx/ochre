import QtQuick
import qs.services

// Строка события: «● 10:30–11:00 standup», точка — цвет календаря. withDay — день недели и число у событий не сегодня.
// Общая для попапа часов (bar/CalPopup.qml) и секции календаря в home.
T {
    id: line

    property var event
    property bool withDay: false
    readonly property var colors: [Theme.blue, Theme.green, Theme.purple, Theme.aqua, Theme.orange, Theme.yellow, Theme.red]
    readonly property bool past: event.end <= Calendar.now

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    elide: Text.ElideRight
    textFormat: Text.StyledText
    text: `<font color="${colors[event.src % colors.length]}">●</font> `
        + `<font color="${past ? Theme.gray : event.start <= Calendar.now ? Theme.accent : Theme.aqua}">${esc(Calendar.when(event, withDay))}</font> `
        + `<font color="${past ? Theme.gray : Theme.fg}">${esc(event.title || I18n.tr("без названия"))}</font>`
        + (event.location && !/^https?:\/\//.test(event.location) ? ` <font color="${Theme.gray}">· ${esc(event.location)}</font>` : "")
}
