import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Календарь месяца: ←→ — соседние месяцы, ↵ — вернуться к сегодняшнему.
Section {
    id: sec

    title: I18n.tr("календарь")
    count: 1

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) grid.offset--;
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) grid.offset++;
        else return false;
        return true;
    }

    function activate(i) { grid.today(); }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight
        color: sec.isCur(0) ? Theme.bg1 : "transparent"
        TapHandler { onTapped: sec.pick(0) }
        CalGrid { id: grid; anchors.horizontalCenter: parent.horizontalCenter }
    }
}
