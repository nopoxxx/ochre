import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Календарь месяца и ближайшие события (services/Calendar.qml): ←→ — соседние месяцы, ↵ на сетке — к сегодняшнему,
// клик по дню — его события, ↵ на событии — открыть ссылку (встреча, URL), e — calendars.conf, r — обновить.
Section {
    id: sec

    readonly property int max: 6
    readonly property var shown: Calendar.configured ? (grid.picked ? Calendar.on(grid.picked) : Calendar.upcoming).slice(0, max) : []

    title: I18n.tr("календарь")
    count: 1 + (Calendar.configured ? shown.length : 1)

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) grid.offset--;
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) grid.offset++;
        else if (event.key === Qt.Key_R) Calendar.refresh();
        else if (event.key === Qt.Key_E) { Calendar.edit(); sec.panel.close(); }
        else return false;
        return true;
    }

    function activate(i) {
        if (i === 0) grid.today();
        else if (!Calendar.configured) { Calendar.edit(); sec.panel.close(); }
        else {
            const e = shown[i - 1];
            if (e?.link) { sec.panel.close(); Calendar.open(e); }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight
        color: sec.isCur(0) ? Theme.bg1 : "transparent"
        TapHandler { onTapped: sec.pick(0) }
        CalGrid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            onDayClicked: sec.pick(0)
        }
    }

    T {
        visible: Calendar.configured
        text: "── " + (grid.picked ? I18n.locale.toString(grid.picked, "ddd d MMMM") : I18n.tr("ближайшие")) + " ──"
        color: Theme.gray
    }

    T {
        visible: Calendar.configured && sec.shown.length === 0
        text: I18n.tr("событий нет")
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
            color: sec.isCur(index + 1) ? Theme.bg1 : hover.hovered ? Theme.hover : "transparent"

            CalEvent {
                id: lineText
                width: parent.width
                event: line.modelData
                withDay: !grid.picked
            }

            HoverHandler { id: hover; cursorShape: line.modelData.link ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: { const i = line.index + 1; sec.pick(i); sec.activate(i); } }
        }
    }

    Btn {
        visible: !Calendar.configured
        text: I18n.tr("подключить календари")
        current: sec.isCur(1)
        onClicked: { sec.pick(1); sec.activate(1); }
    }

    T {
        visible: Calendar.errorText() !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: Calendar.errorText()
        color: Theme.red
    }

    T {
        visible: sec.focused
        text: I18n.tr("←→ месяц  ↵ открыть  e календари  r обновить")
        color: Theme.gray
        font.pixelSize: Theme.fontSize - 2
    }
}
