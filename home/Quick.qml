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

    readonly property var buttons: [
        { icon: G.g(Networking.wifiEnabled ? "wifi" : "wifiOff"),
          text: !Networking.wifiEnabled ? "wifi: off" : wifiNet ? short(wifiNet.name, 12) : "wifi",
          on: Networking.wifiEnabled, active: wifiDev !== null && Networking.wifiHardwareEnabled,
          run: () => Networking.wifiEnabled = !Networking.wifiEnabled },
        { icon: G.g(!adapter?.enabled ? "btOff" : btConnected.length ? "btOn" : "bt"),
          text: !adapter?.enabled ? "bt: off" : btConnected.length ? short(btConnected[0].name, 12) : "bt",
          on: adapter?.enabled ?? false, active: adapter !== null,
          run: () => adapter.enabled = !adapter.enabled },
        { icon: G.g("moon"), text: "ночь", on: NightLight.on, active: NightLight.available,
          run: () => NightLight.toggle() },
        { icon: G.g(Notifs.dnd ? "dnd" : "bell"), text: "dnd", on: Notifs.dnd, active: true, onColor: Theme.purple,
          run: () => Notifs.toggleDnd() },
        { icon: G.g("game"), text: "game", on: Game.on, active: true, onColor: Theme.green,
          run: () => Game.toggle() },
        { icon: G.g(micMuted ? "micOff" : "mic"), text: micMuted ? "mic: off" : "mic", on: !micMuted && source !== null,
          active: source?.audio !== undefined && source !== null,
          run: () => sec.source.audio.muted = !sec.micMuted },
        { icon: G.g(Recorder.recording ? "stop" : "rec"),
          text: Recorder.recording ? "rec " + Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0") : "rec",
          on: Recorder.recording, active: Recorder.available, onColor: Theme.red,
          run: () => { if (!Recorder.recording) sec.panel.close(); Recorder.toggle(); } }
    ]

    count: buttons.length

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) cur = Math.max(0, cur - 1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) cur = Math.min(count - 1, cur + 1);
        else return false;
        return true;
    }

    function activate(i) {
        const b = buttons[i];
        if (b?.active) b.run();
    }

    Flow {
        Layout.fillWidth: true
        spacing: sec.panel.cell.advanceWidth

        Repeater {
            model: sec.buttons
            Btn {
                required property var modelData
                required property int index
                icon: modelData.icon
                text: modelData.text
                on: modelData.on
                active: modelData.active
                onColor: modelData.onColor ?? Theme.accent
                current: sec.isCur(index)
                onClicked: { sec.pick(index); sec.activate(index); }
            }
        }
    }
}
