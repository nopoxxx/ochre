import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services

// История уведомлений как вывод journalctl:  21:06 firefox[INFO]: Загрузка завершена — file.zip
// Несколько записей одного приложения — группа «▾ firefox (3)», больше трёх — свёрнута.
// ↑↓/jk — строка, ↵ — действие (на группе — свернуть), ␣ ←→ — свернуть/развернуть, Del/x — убрать, d — DND, Esc — закрыть.
// Клик по строке — то же, что ↵, наведение — [×]; внизу [clear] и переключатель «не беспокоить».
TuiPopup {
    id: pop

    readonly property int maxRows: 20
    readonly property int rowH: Math.ceil(cell.height)
    property var collapsed: ({})
    property int cur: 0

    readonly property var groups: {
        const byApp = {};
        const list = [];
        for (const e of Notifs.history) {
            let g = byApp[e.app];
            if (!g) {
                g = byApp[e.app] = { app: e.app, items: [] };
                list.push(g);
            }
            g.items.push(e);
        }
        return list;
    }

    readonly property var rows: {
        const r = [];
        for (const g of groups) {
            if (g.items.length === 1) {
                r.push({ e: g.items[0], g: null });
                continue;
            }
            const shut = collapsed[g.app] ?? g.items.length > 3;
            r.push({ e: null, g: g, shut: shut });
            if (!shut)
                for (const e of g.items) r.push({ e: e, g: g });
        }
        return r;
    }

    title: "journalctl --user -n " + Notifs.history.length

    onOpenChanged: {
        Notifs.centerOpen = open;
        if (!open) return;
        cur = 0;
        list.forceActiveFocus();
    }
    onRowsChanged: cur = Math.max(0, Math.min(cur, rows.length - 1))
    onCurChanged: list.positionViewAtIndex(cur, ListView.Contain)

    function c(color, s) { return `<font color="${color}">${s}</font>`; }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function levelColor(u) {
        return u === NotificationUrgency.Critical ? Theme.red : u === NotificationUrgency.Low ? Theme.gray : Theme.accent;
    }
    function msg(e) { return e.summary + (e.body ? " — " + e.body.replace(/\s+/g, " ") : ""); }

    function setShut(g, shut) {
        const next = Object.assign({}, collapsed);
        next[g.app] = shut;
        collapsed = next;
        cur = rows.findIndex(r => !r.e && r.g.app === g.app);
    }

    function activate(i) {
        const r = rows[i];
        if (!r) return;
        cur = i;
        if (r.e) Notifs.invoke(r.e);
        else setShut(r.g, !r.shut);
    }

    function remove(i) {
        const r = rows[i];
        if (!r) return;
        if (r.e) Notifs.remove(r.e);
        else Notifs.removeAll(r.g.items);
    }

    function key(event) {
        const k = event.key;
        const r = rows[cur];
        if (k === Qt.Key_Escape || k === Qt.Key_Q) open = false;
        else if (k === Qt.Key_Down || k === Qt.Key_J) cur = Math.min(cur + 1, rows.length - 1);
        else if (k === Qt.Key_Up || k === Qt.Key_K) cur = Math.max(cur - 1, 0);
        else if (k === Qt.Key_Home) cur = 0;
        else if (k === Qt.Key_End) cur = Math.max(rows.length - 1, 0);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) activate(cur);
        else if (k === Qt.Key_Space && r?.g) setShut(r.g, r.e ? true : !r.shut);
        else if ((k === Qt.Key_Left || k === Qt.Key_H) && r?.g) setShut(r.g, true);
        else if ((k === Qt.Key_Right || k === Qt.Key_L) && r?.g) setShut(r.g, false);
        else if (k === Qt.Key_Delete || k === Qt.Key_X) remove(cur);
        else if (k === Qt.Key_D) Notifs.toggleDnd();
        else return;
        event.accepted = true;
    }

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "M"
    }

    T {
        visible: Notifs.history.length === 0
        text: "-- No entries --"
        color: Theme.gray
    }

    ListView {
        id: list

        Layout.preferredWidth: cell.advanceWidth * 64
        Layout.preferredHeight: Math.min(pop.rows.length, pop.maxRows) * pop.rowH
        visible: pop.rows.length > 0
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        model: pop.rows

        Keys.onPressed: event => pop.key(event)

        delegate: Rectangle {
            id: line

            required property var modelData
            required property int index
            readonly property var e: modelData.e
            readonly property var g: modelData.g

            width: ListView.view.width
            height: pop.rowH
            color: pop.cur === index ? Theme.bg1 : hover.hovered ? Theme.hover : "transparent"

            T {
                id: lineText

                width: parent.width - del.width - cell.advanceWidth
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: {
                    const e = line.e;
                    const g = line.g;
                    if (!e) {
                        const last = g.items[0];
                        return pop.c(Theme.aqua, (line.modelData.shut ? "▸ " : "▾ ") + pop.esc(g.app))
                            + pop.c(Theme.gray, " (" + g.items.length + ")")
                            + (line.modelData.shut
                                ? " " + pop.c(Theme.gray, Qt.formatTime(last.time, "HH:mm") + " " + pop.esc(pop.msg(last)))
                                : "");
                    }
                    return (g ? "  " : "")
                        + pop.c(Theme.gray, Qt.formatTime(e.time, "HH:mm")) + " "
                        + (g ? "" : pop.c(Theme.aqua, pop.esc(e.app)))
                        + pop.c(pop.levelColor(e.urgency), "[" + Notifs.level(e.urgency) + "]") + ": "
                        + pop.c(Theme.fg, pop.esc(pop.msg(e)));
                }
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: pop.activate(line.index)
            }

            T {
                id: del
                anchors.right: parent.right
                visible: hover.hovered || pop.cur === line.index
                text: "[×]"
                color: Theme.red

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.remove(line.index)
                }
            }
        }
    }

    T {
        readonly property int below: Math.round((list.contentHeight - list.contentY - list.height) / pop.rowH)
        visible: below > 0
        text: I18n.tr("… ещё %1", below)
        color: Theme.gray
    }

    RowLayout {
        Layout.topMargin: 4
        spacing: cell.advanceWidth * 2

        T {
            text: "[clear]"
            color: Notifs.history.length ? Theme.red : Theme.gray

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clear()
            }
        }

        T {
            text: "[dnd: " + (Notifs.dnd ? "on" : "off") + "]"
            color: Notifs.dnd ? Theme.purple : Theme.gray

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.toggleDnd()
            }
        }

        T {
            visible: Notifs.history.length > 0
            text: "↑↓ ↵ ␣ del"
            color: Theme.gray
        }
    }
}
