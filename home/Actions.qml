import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Нижняя строка: запись экрана, настройки, блокировка, сон, выход, перезагрузка, выключение.
// ←→ — выбор, ↵ — нажать. Выход, перезагрузку и выключение надо нажать дважды: «точно?».
Section {
    id: sec

    title: I18n.tr("действия")

    property int confirm: -1

    readonly property var buttons: [
        { icon: G.g(Recorder.recording ? "stop" : "rec"), text: Recorder.recording ? I18n.tr("стоп") : I18n.tr("запись"), ok: Recorder.available,
          run: () => { sec.panel.close(); Recorder.toggle(); } },
        { icon: G.g("cog"), text: I18n.tr("настройки"), ok: true, run: () => { sec.panel.close(); Settings.show(""); } },
        { icon: G.g("lock"), text: "lock", ok: true, run: () => { sec.panel.close(); Ochre.ipc("lock", "lock"); } },
        { icon: G.g("sleep"), text: I18n.tr("сон"), ok: true,
          run: () => { sec.panel.close(); spawn(["sh", "-c", '"$@"; sleep 0.5; systemctl suspend', "sh", ...Ochre.ipcArgv(["lock", "lock"])]); } },
        { icon: G.g("logout"), text: I18n.tr("выход"), ok: true, ask: true, run: () => spawn(["niri", "msg", "action", "quit", "--skip-confirmation"]) },
        { icon: G.g("restart"), text: I18n.tr("перезагрузка"), ok: true, ask: true, run: () => spawn(["systemctl", "reboot"]) },
        { icon: G.g("power"), text: I18n.tr("выключить"), ok: true, ask: true, run: () => spawn(["systemctl", "poweroff"]) }
    ]

    count: buttons.length
    onCurChanged: confirm = -1
    onFocusedChanged: if (!focused) confirm = -1

    function spawn(argv) { Quickshell.execDetached(argv); }

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) cur = Math.max(0, cur - 1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) cur = Math.min(count - 1, cur + 1);
        else return false;
        return true;
    }

    function activate(i) {
        const b = buttons[i];
        if (!b?.ok) return;
        if (b.ask && confirm !== i) { confirm = i; return; }
        confirm = -1;
        b.run();
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
                text: sec.confirm === index ? I18n.tr("точно? ↵") : modelData.text
                active: modelData.ok
                on: sec.confirm === index || (index === 0 && Recorder.recording)
                onColor: Theme.red
                current: sec.isCur(index)
                onClicked: { sec.pick(index); sec.activate(index); }
            }
        }
    }
}
