import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Последние уведомления строками журнала: ↵ / клик — действие, del / x — убрать, последняя строка — [clear].
// Вся история — log на панели.
Section {
    id: sec

    title: I18n.tr("уведомления") + (Notifs.history.length ? " · " + Notifs.history.length : "")

    readonly property var shown: Notifs.history.slice(0, 5)
    count: shown.length + (shown.length ? 1 : 0)

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function levelColor(u) {
        return u === NotificationUrgency.Critical ? Theme.red : u === NotificationUrgency.Low ? Theme.gray : Theme.accent;
    }

    function key(event) {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_X) && cur < shown.length) {
            Notifs.remove(shown[cur]);
            return true;
        }
        return false;
    }

    function activate(i) {
        if (i < shown.length) Notifs.invoke(shown[i]);
        else Notifs.clear();
    }

    Component.onCompleted: Notifs.markRead()

    T {
        visible: sec.shown.length === 0
        text: "-- No entries --"
        color: Theme.gray
    }

    Repeater {
        model: sec.shown

        Rectangle {
            id: line
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: lineText.implicitHeight
            color: sec.isCur(index) ? Theme.bg1 : hover.hovered ? Theme.hover : "transparent"

            T {
                id: lineText
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: {
                    const e = line.modelData;
                    const msg = e.summary + (e.body ? " — " + e.body.replace(/\s+/g, " ") : "");
                    return `<font color="${Theme.gray}">${Qt.formatTime(e.time, "HH:mm")}</font> `
                        + `<font color="${Theme.aqua}">${sec.esc(e.app)}</font>`
                        + `<font color="${sec.levelColor(e.urgency)}">[${Notifs.level(e.urgency)}]</font>: `
                        + sec.esc(msg);
                }
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { sec.pick(line.index); sec.activate(line.index); } }
        }
    }

    Btn {
        visible: sec.shown.length > 0
        text: "clear"
        onColor: Theme.red
        on: true
        current: sec.isCur(sec.shown.length)
        onClicked: { sec.pick(sec.shown.length); sec.activate(sec.shown.length); }
    }
}
