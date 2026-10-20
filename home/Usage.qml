import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Время за экраном сегодня: всего и пять приложений, дольше всех бывших в фокусе (services/ScreenTime.qml).
Section {
    id: sec

    title: I18n.tr("экран")
    count: 0

    readonly property int nameLen: 12
    readonly property int cells: Math.max(6, Settings.get("shell.home.width") - nameLen - 14)
    readonly property var apps: ScreenTime.top(5)
    readonly property int most: apps.length ? apps[0].sec : 1

    function bar(v) {
        const n = Math.max(1, Math.round(v * cells));
        return "▕" + "█".repeat(n) + "░".repeat(cells - n) + "▏";
    }

    Component.onCompleted: ScreenTime.flush()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: ScreenTime.flush() }

    RowLayout {
        spacing: 0
        T { font.family: Theme.iconFont; text: " " + G.g("clock") + " "; color: Theme.gray }
        T { text: I18n.tr("сегодня") + " "; color: Theme.gray }
        T { text: ScreenTime.fmt(ScreenTime.todayTotal); color: Theme.accent; font.bold: true }
    }

    T {
        visible: sec.apps.length === 0
        text: I18n.tr("пока ничего — время идёт, пока окно в фокусе")
        color: Theme.gray
    }

    Repeater {
        model: sec.apps
        RowLayout {
            required property var modelData
            spacing: 0
            T {
                text: "   " + (modelData.app.length > sec.nameLen ? modelData.app.slice(0, sec.nameLen - 1) + "…" : modelData.app.padEnd(sec.nameLen))
                color: Theme.fg
            }
            T { text: " " + sec.bar(modelData.sec / sec.most); color: Theme.accent }
            T { text: " " + ScreenTime.fmt(modelData.sec); color: Theme.gray }
        }
    }
}
