import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Календарь (CalView): месяц, события выбранного дня и ближайшие, добавление и удаление — мышью.
// С клавиатуры: ←→ — соседние месяцы, ↵ — к сегодняшнему, a — новое событие, e — calendars.conf, r — обновить.
Section {
    id: sec

    title: I18n.tr("календарь")
    count: 1

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) view.grid.shift(-1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) view.grid.shift(1);
        else if (event.key === Qt.Key_A || event.key === Qt.Key_N) view.add();
        else if (event.key === Qt.Key_R) Calendar.refresh();
        else if (event.key === Qt.Key_E) { Calendar.edit(); sec.panel.close(); }
        else return false;
        return true;
    }

    function activate(i) { view.today(); }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: view.implicitHeight + 4
        color: sec.isCur(0) && !view.adding ? Theme.bg1 : "transparent"
        TapHandler { onTapped: sec.pick(0) }
        CalView {
            id: view
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 2 }
            chars: Math.max(28, Math.floor(sec.width / Math.max(1, sec.panel.cell.advanceWidth)) - 2)
            onCloseRequested: sec.panel.close()
            onAddingChanged: if (!adding) sec.panel.focusSection(sec)
        }
    }

    T {
        visible: sec.focused && !view.adding
        text: I18n.tr("←→ месяц  ↵ сегодня  a событие  e календари  r обновить")
        color: Theme.gray
        font.pixelSize: Theme.fontSize - 2
    }
}
