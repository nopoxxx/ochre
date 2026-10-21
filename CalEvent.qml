import QtQuick
import qs.services

// Строка события: «● 10:30–11:00 standup», точка — цвет календаря. withDay — день недели и число у событий не сегодня.
// Основа CalRow (список событий в CalView).
T {
    id: line

    property var event
    property bool withDay: false
    readonly property bool past: event.end <= Calendar.now

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    elide: Text.ElideRight
    textFormat: Text.StyledText
    text: `<font color="${Theme.calendars[event.src % Theme.calendars.length]}">●</font> `
        + `<font color="${past ? Theme.gray : event.start <= Calendar.now ? Theme.accent : Theme.aqua}">${esc(Calendar.when(event, withDay))}</font> `
        + `<font color="${past ? Theme.gray : Theme.fg}">${esc(event.title || I18n.tr("без названия"))}</font>`
        + (event.location && !/^https?:\/\//.test(event.location) ? ` <font color="${Theme.gray}">· ${esc(event.location)}</font>` : "")
}
