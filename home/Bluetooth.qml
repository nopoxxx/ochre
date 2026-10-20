import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Устройства bluetooth: подключённые и сопряжённые сверху, дальше найденные рядом (пока меню открыто, адаптер ищет).
// ↵ / клик: подключённое — отключить, сопряжённое — подключить, новое — сопряжение и подключение;
// del / x — забыть. Нет адаптера — секции не видно; выключен — переключатель в «быстро».
Section {
    id: sec

    title: "bluetooth"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devs: (adapter?.devices.values ?? [])
        .filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        .slice(0, 10)
    property var pending: ({})    // адрес → подключить после сопряжения

    available: adapter !== null
    count: adapter?.enabled ? devs.length : 0

    Component.onCompleted: if (adapter?.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter?.discovering) adapter.discovering = false

    function icon(d) {
        const i = d.icon ?? "";
        return G.g(i.includes("headset") || i.includes("headphone") ? "headphones"
            : i.includes("mouse") ? "mouse" : i.includes("keyboard") ? "keyboard"
            : i.includes("phone") ? "phone" : i.includes("audio") ? "speaker" : "bt");
    }

    function status(d) {
        if (d.pairing) return I18n.tr("сопряжение…");
        if (d.state === BluetoothDeviceState.Connecting) return I18n.tr("подключение…");
        if (d.state === BluetoothDeviceState.Disconnecting) return I18n.tr("отключение…");
        if (d.connected) return (d.batteryAvailable ? I18n.tr("подключено %1%", Math.round(d.battery * 100)) : I18n.tr("подключено"));
        return d.paired ? I18n.tr("сопряжено") : "";
    }

    function activate(i) {
        const d = devs[i];
        if (!d) return;
        if (d.connected) d.disconnect();
        else if (d.paired) d.connect();
        else {
            d.trusted = true;
            pending = Object.assign({}, pending, { [d.address]: true });
            d.pair();
        }
    }

    function key(event) {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_X) && devs[cur]?.paired) {
            devs[cur].forget();
            return true;
        }
        return false;
    }

    T {
        visible: sec.adapter !== null && !sec.adapter.enabled
        text: I18n.tr("bluetooth выключен — включить в «быстро»")
        color: Theme.gray
    }
    T {
        visible: (sec.adapter?.enabled ?? false) && sec.devs.length === 0
        text: I18n.tr("ищу устройства…")
        color: Theme.gray
    }

    Repeater {
        model: sec.adapter?.enabled ? sec.devs : []

        Rectangle {
            id: item
            required property var modelData
            required property int index
            readonly property var d: modelData

            Layout.fillWidth: true
            implicitHeight: row.implicitHeight
            color: sec.isCur(index) ? Theme.bg1 : hover.hovered ? Qt.darker(Theme.bg1, 1.3) : "transparent"

            // сопряжение закончилось — подключаем, раз его начали отсюда
            Connections {
                target: item.d
                function onPairedChanged() {
                    if (item.d.paired && sec.pending[item.d.address]) {
                        const p = Object.assign({}, sec.pending);
                        delete p[item.d.address];
                        sec.pending = p;
                        item.d.connect();
                    }
                }
            }

            RowLayout {
                id: row
                width: parent.width
                spacing: 0
                T { text: sec.isCur(item.index) ? "▌" : " "; color: Theme.accent }
                T { font.family: Theme.iconFont; text: sec.icon(item.d) + " "; color: item.d.connected ? Theme.accent : Theme.gray }
                T {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: item.d.name
                    color: item.d.connected ? Theme.accent : item.d.paired ? Theme.fg : Qt.darker(Theme.fg, 1.3)
                    font.bold: item.d.connected || sec.isCur(item.index)
                }
                T { text: sec.status(item.d); color: Theme.gray }
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { sec.pick(item.index); sec.activate(item.index); } }
        }
    }
}
