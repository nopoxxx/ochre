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

    Grid {
        id: row
        readonly property bool vertical: root.bar?.vertical ?? false
        rows: vertical ? -1 : 1
        columns: vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        spacing: vertical ? 0 : cell.advanceWidth
        Seg {
            visible: Privacy.micApps.length > 0
            bar: root.bar
            label: "mic"
            value: root.names(Privacy.micApps)
            compact: String(Privacy.micApps.length)
            valueColor: Theme.orange
            bold: true
        }
        Seg {
            visible: Privacy.screenApps.length > 0
            bar: root.bar
            label: "cast"
            value: root.names(Privacy.screenApps)
            compact: String(Privacy.screenApps.length)
            valueColor: Theme.red
            bold: true
        }
    }

    TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }
}
