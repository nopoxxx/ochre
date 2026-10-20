import QtQuick
import qs
import qs.services

// ❯ app  # title — активное окно как набранная команда.
// Символ краснеет, если какое-то окно требует внимания (как ненулевой $?).
// При смене окна команда «печатается» по символу; обновления заголовка — без анимации.
Item {
    id: root

    property var bar
    property bool available: true
    readonly property bool vertical: bar?.vertical ?? false

    readonly property var win: Niri.focusedWindow
    readonly property string app: win?.app_id ?? ""
    readonly property int maxLen: Settings.get("shell.bar.titleMax")
    readonly property string full: {
        if (!win) return "";
        const s = app + "  # " + (win.title ?? "");
        return s.length > maxLen ? s.slice(0, maxLen - 1) + "…" : s;
    }

    property int typed: 0
    property var lastId: null
    readonly property bool typing: typed < full.length
    readonly property string shownText: full.slice(0, typed)

    onFullChanged: {
        const id = win?.id ?? null;
        if (Settings.get("shell.bar.typing") && full && id !== lastId) {
            typed = 0;
            typer.restart();
        } else {
            typed = full.length;
        }
        lastId = id;
    }

    Component.onCompleted: {
        typed = full.length;
        lastId = win?.id ?? null;
    }

    Timer {
        id: typer
        interval: 14
        repeat: true
        onTriggered: {
            root.typed = Math.min(root.full.length, root.typed + 1);
            if (!root.typing) stop();
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        BarText {
            text: Settings.get("shell.bar.symbol") + (root.vertical ? "" : " ")
            color: Niri.urgent ? Theme.red : Theme.accent
            font.bold: true
        }
        BarText { visible: !root.vertical; text: root.shownText.slice(0, root.app.length); color: Theme.fg }
        BarText { visible: !root.vertical; text: root.shownText.slice(root.app.length); color: Theme.gray }

        // курсор: мигает, когда «команды» нет, и стоит в конце, пока она печатается
        BarText {
            id: cursor

            visible: !root.vertical && (!root.win || root.typing)
            text: "█"
            color: Theme.fg
            opacity: 1

            Timer {
                interval: 530
                running: !root.win
                repeat: true
                onTriggered: cursor.opacity = cursor.opacity > 0 ? 0 : 1
                onRunningChanged: if (!running) cursor.opacity = 1
            }
        }
    }
}
