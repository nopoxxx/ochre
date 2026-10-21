import QtQuick
import QtQuick.Layouts
import qs.services

// Событие в списке календаря: клик — подробности (календарь, место, ссылка), справа под мышью — [↗] открыть ссылку
// и [×] удалить (из своего календаря и CalDAV; второй клик подтверждает, у повторяющегося — удаляется серия).
Rectangle {
    id: row

    property var event
    property bool withDay: false
    property bool current: false
    property bool expanded: false
    property bool confirm: false
    signal opened()

    readonly property bool hot: hover.hovered || current

    implicitHeight: col.implicitHeight + 2
    color: current ? Theme.bg1 : hover.hovered ? Theme.hover : "transparent"

    onHotChanged: if (!hot) confirm = false

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: { row.expanded = !row.expanded; row.confirm = false; } }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            CalEvent {
                Layout.fillWidth: true
                event: row.event
                withDay: row.withDay
            }
            CalBtn {
                visible: row.hot && row.event.link !== ""
                label: "↗"
                onClicked: row.opened()
            }
            CalBtn {
                visible: row.hot && row.event.rw
                label: row.confirm ? (row.event.recurring ? I18n.tr("удалить серию?") : I18n.tr("удалить?")) : "×"
                danger: row.confirm
                onClicked: {
                    if (!row.confirm) { row.confirm = true; return; }
                    const e = row.event;
                    row.confirm = false;
                    Calendar.remove(e);
                }
            }
        }

        T {
            visible: row.expanded
            Layout.fillWidth: true
            Layout.leftMargin: cellM.advanceWidth * 2
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            color: Theme.gray
            text: [
                row.esc(row.event.cal) + (row.event.rw ? "" : " · " + I18n.tr("только чтение")),
                row.event.location ? row.esc(row.event.location) : "",
                row.event.link && row.event.link !== row.event.location ? `<font color="${Theme.blue}">${row.esc(row.event.link)}</font>` : ""
            ].filter(x => x).join("<br>")
        }
    }

    TextMetrics { id: cellM; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }
}
