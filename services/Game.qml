pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Игровой режим (shell.game): niri без анимаций, теней и прозрачности неактивных (GAME_OFF в settings.js — поверх
// своих значений, сами настройки не меняются), уведомления — только критичные (shell.game.dnd, через Notifs.dnd).
// Переключение — Mod+Shift+G, home → быстро → game, настройки windows/ → игровой режим.
//   qs ipc call game toggle | on | off | get
Singleton {
    id: root

    readonly property bool on: Settings.get("shell.game")

    // уведомление — до включения: с shell.game.dnd оно пришло бы уже в «не беспокоить» и не показалось
    property bool pending: false
    function set(v) {
        if (v === on || apply.running) return;
        Quickshell.execDetached(["notify-send", "-a", "ochre", "-t", "2000", "-h", "boolean:transient:true",
            v ? "Игровой режим включён" : "Игровой режим выключен",
            v ? "без анимаций и теней" + (Settings.get("shell.game.dnd") ? ", уведомления — только критичные" : "") : "эффекты niri вернулись"]);
        pending = v;
        apply.start();
    }

    Timer { id: apply; interval: 300; onTriggered: Settings.set("shell.game", root.pending) }

    function toggle() { set(!on); }

    IpcHandler {
        target: "game"
        function toggle(): void { root.toggle(); }
        function on(): void { root.set(true); }
        function off(): void { root.set(false); }
        function get(): string { return root.on ? "on" : "off"; }
    }
}
