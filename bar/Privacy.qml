import QtQuick
import qs
import qs.bar
import qs.services

// mic discord · cast obs — кто слушает микрофон и кто показывает экран (services/Privacy.qml).
// Пока никто — модуля не видно.
Item {
    id: root

    property var bar
    readonly property bool available: Privacy.active

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function names(list) {
        return list.length > 2 ? list.slice(0, 2).join(",") + " +" + (list.length - 2) : list.join(",");
    }

    Row {
        id: row
        spacing: cell.advanceWidth
        Seg {
            visible: Privacy.micApps.length > 0
            bar: root.bar
            label: "mic"
            value: root.names(Privacy.micApps)
            valueColor: Theme.orange
            bold: true
        }
        Seg {
            visible: Privacy.screenApps.length > 0
            bar: root.bar
            label: "cast"
            value: root.names(Privacy.screenApps)
            valueColor: Theme.red
            bold: true
        }
    }

    TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }
}
