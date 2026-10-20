import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services

// История уведомлений как вывод journalctl:  21:06 firefox[INFO]: Загрузка завершена — file.zip
// Клик по строке — действие, наведение — [×]; внизу [clear] и переключатель «не беспокоить».
TuiPopup {
    id: pop

    readonly property int limit: 15
    readonly property var shown: Notifs.history.slice(0, limit)

    title: "journalctl --user -n " + Notifs.history.length

    onOpenChanged: Notifs.centerOpen = open

    function c(color, s) { return `<font color="${color}">${s}</font>`; }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function levelColor(u) {
        return u === NotificationUrgency.Critical ? Theme.red : u === NotificationUrgency.Low ? Theme.gray : Theme.accent;
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

    Repeater {
        model: pop.shown

        Rectangle {
            id: line

            required property var modelData
            readonly property var e: modelData

            Layout.preferredWidth: cell.advanceWidth * 64
            implicitHeight: lineText.implicitHeight
            color: hover.hovered ? Theme.bg1 : "transparent"

            T {
                id: lineText

                width: parent.width - del.width - cell.advanceWidth
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: {
                    const e = line.e;
                    const msg = e.summary + (e.body ? " — " + e.body.replace(/\s+/g, " ") : "");
                    return pop.c(Theme.gray, Qt.formatTime(e.time, "HH:mm")) + " "
                        + pop.c(Theme.aqua, pop.esc(e.app))
                        + pop.c(pop.levelColor(e.urgency), "[" + Notifs.level(e.urgency) + "]") + ": "
                        + pop.c(Theme.fg, pop.esc(msg));
                }
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.invoke(line.e)
            }

            T {
                id: del
                anchors.right: parent.right
                visible: hover.hovered
                text: "[×]"
                color: Theme.red

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.remove(line.e)
                }
            }
        }
    }

    T {
        visible: Notifs.history.length > pop.limit
        text: I18n.tr("… ещё %1", Notifs.history.length - pop.limit)
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
    }
}
