pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Виджеты на рабочем столе (DesktopWidgets.qml): список shell.desktop.widgets и режим правки.
// Показ — shell.desktop.on; пауза (виджеты не строятся вовсе, метрики и cava не читаются) — блокировка,
// игровой режим и окно во весь монитор (shell.desktop.pause).
//   qs ipc call desktop edit | done | toggle (показывать или нет) | get
Singleton {
    id: root

    readonly property bool on: Settings.get("shell.desktop.on")
    readonly property var widgets: S.normalizeWidgets(Settings.get("shell.desktop.widgets"))
    property bool editing: false
    property string screenName: ""   // монитор режима правки

    onEditingChanged: if (!editing) Settings.back()

    function shownOn(output) {
        return on && !(editing && output === screenName) && !Wallpaper.locked && !Game.on
            && !(Settings.get("shell.desktop.pause") === "fullscreen" && Wallpaper.fullscreenOn(output));
    }

    // полоски звука нужны, только если виджет viz сейчас на каком-то экране
    readonly property bool wantViz: widgets.some(w => w.type === "viz")
        && (editing || Quickshell.screens.some(s => shownOn(s.name)))

    function edit() {
        screenName = Niri.focusedWorkspace?.output ?? Quickshell.screens[0]?.name ?? "";
        editing = true;
    }

    function save(list) {
        if (list.length) Settings.set("shell.desktop.widgets", list);
        else Settings.reset("shell.desktop.widgets");
    }

    // добавленный виджет должно быть видно и после режима правки
    function add(w) {
        save(widgets.concat([w]));
        if (!on) Settings.set("shell.desktop.on", true);
    }

    function update(id, patch) { save(S.updateWidget(widgets, id, patch)); }
    function remove(id) { save(S.removeWidget(widgets, id)); }

    IpcHandler {
        target: "desktop"
        function edit(): void { root.edit(); }
        function done(): void { root.editing = false; }
        function toggle(): void { Settings.set("shell.desktop.on", !root.on); }
        function get(): string { return JSON.stringify({ on: root.on, editing: root.editing, widgets: root.widgets }); }
    }
}
