import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Шапка: user@host крупно, время работы, ядро и система. Фокуса нет — только смотреть.
Section {
    id: sec

    title: "whoami"
    count: 0

    property int uptime: 0      // секунд
    readonly property string os: (osRelease.text().match(/^PRETTY_NAME="?([^"\n]*)"?/m) ?? [])[1] ?? "Linux"

    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d ? I18n.tr("%1д %2ч %3м", d, h, m) : h ? I18n.tr("%1ч %2м", h, m) : I18n.tr("%1м", m);
    }

    FileView { id: osRelease; path: "/etc/os-release" }
    FileView { id: up; path: "/proc/uptime"; onLoaded: sec.uptime = parseFloat(text()) }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: up.reload() }

    RowLayout {
        spacing: 0
        T { font.family: Theme.iconFont; text: G.g("account") + " "; color: Theme.accent }
        T {
            textFormat: Text.StyledText
            text: `<font color="${Theme.green}"><b>${Sys.user}</b></font><font color="${Theme.gray}">@</font><font color="${Theme.aqua}"><b>${Sys.host}</b></font>`
        }
    }
    T {
        Layout.fillWidth: true
        elide: Text.ElideRight
        color: Theme.gray
        text: "up " + sec.fmtUptime(sec.uptime) + " · " + sec.os + " · " + Sys.kernel
    }
}
