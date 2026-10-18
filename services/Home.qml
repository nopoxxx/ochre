pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Меню home (HomePanel.qml): открыто ли и на каком мониторе.
// Открывают клик по user@host на панели, Mod+A и строка в настройках.
//   qs ipc call home toggle | open | close | page <wifi|bluetooth> — сразу страница (вид control)
Singleton {
    id: root

    property bool open: false
    property string screenName: ""    // монитор; пусто — с фокусом
    signal pageRequested(string id)    // HomePanel откроет страницу, если в этом виде она есть

    // screen — монитор панели, по которой кликнули; из IPC — монитор с фокусом
    function toggle(screen) {
        if (open) open = false;
        else show(screen);
    }

    function show(screen) {
        screenName = screen ?? Niri.focusedWorkspace?.output ?? "";
        open = true;
    }

    IpcHandler {
        target: "home"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.open = false; }
        function page(id: string): void { root.show(); root.pageRequested(id); }
    }
}
