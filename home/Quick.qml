import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Быстрые переключатели: wifi, bluetooth, ночной режим, «не беспокоить», игровой режим, микрофон, запись экрана.
// ←→ — выбор, ↵ / Space / клик — переключить. Нет устройства или программы — кнопка серая.
Section {
    id: sec

    title: "быстро"

    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev?.networks.values.find(n => n.connected) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: (adapter?.devices.values ?? []).filter(d => d.connected)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false

    PwObjectTracker { objects: sec.source ? [sec.source] : [] }

    function short(s, n) { return s.length > n ? s.slice(0, n - 1) + "…" : s; }

    // плитки: name — что это, sub — состояние
    readonly property var buttons: [
        { icon: G.g(Networking.wifiEnabled ? "wifi" : "wifiOff"), name: "wi-fi", page: "wifi",
          sub: !Networking.wifiEnabled ? "выкл" : wifiNet ? wifiNet.name : "не подключено",
          on: Networking.wifiEnabled, active: wifiDev !== null && Networking.wifiHardwareEnabled,
          run: () => Networking.wifiEnabled = !Networking.wifiEnabled },
        { icon: G.g(!adapter?.enabled ? "btOff" : btConnected.length ? "btOn" : "bt"), name: "bluetooth", page: "bluetooth",
          sub: !adapter ? "нет адаптера" : !adapter.enabled ? "выкл" : btConnected.length ? btConnected[0].name : "вкл",
          on: adapter?.enabled ?? false, active: adapter !== null,
          run: () => adapter.enabled = !adapter.enabled },
        { icon: G.g("moon"), name: "ночь", sub: NightLight.on ? "тёплый экран" : "выкл", on: NightLight.on, active: NightLight.available,
          run: () => NightLight.toggle() },
        { icon: G.g(Notifs.dnd ? "dnd" : "bell"), name: "не беспокоить", sub: Notifs.dnd ? "только критичные" : "выкл",
          on: Notifs.dnd, active: true, onColor: Theme.purple, run: () => Notifs.toggleDnd() },
        { icon: G.g("game"), name: "игровой режим", sub: Game.on ? "без анимаций" : "выкл", on: Game.on, active: true, onColor: Theme.green,
          run: () => Game.toggle() },
        { icon: G.g(micMuted ? "micOff" : "mic"), name: "микрофон", sub: !source ? "нет" : micMuted ? "выкл" : "вкл",
          on: !micMuted && source !== null, active: source?.audio !== undefined && source !== null,
          run: () => sec.source.audio.muted = !sec.micMuted },
        { icon: G.g(Recorder.recording ? "stop" : "rec"), name: "запись",
          sub: Recorder.recording ? Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0") + " — остановить" : "экран",
          on: Recorder.recording, active: Recorder.available, onColor: Theme.red,
          run: () => { if (!Recorder.recording) sec.panel.close(); Recorder.toggle(); } }
    ]

    count: buttons.length

    function key(event) {
        // o — подробности плитки (страница wi-fi / bluetooth в виде control)
        const b = buttons[cur];
        if (event.key === Qt.Key_O && b?.page && b.active && panel.canPage(b.page)) { panel.openPage(b.page); return true; }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) cur = Math.max(0, cur - 1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) cur = Math.min(count - 1, cur + 1);
        else return false;
        return true;
    }

    function activate(i) {
        const b = buttons[i];
        if (b?.active) b.run();
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: sec.panel.cell.advanceWidth
        rowSpacing: sec.panel.cell.advanceWidth * 0.6

        Repeater {
            model: sec.buttons
            Btn {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 1   // колонки поровну
                tile: true
                icon: modelData.icon
                text: modelData.name
                sub: modelData.sub
                on: modelData.on
                active: modelData.active
                onColor: modelData.onColor ?? Theme.accent
                current: sec.isCur(index)
                more: !!modelData.page && modelData.active && sec.panel.canPage(modelData.page)
                onClicked: { sec.pick(index); sec.activate(index); }
                onMoreClicked: sec.panel.openPage(modelData.page)
            }
        }
    }
}
