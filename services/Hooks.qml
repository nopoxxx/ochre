pragma Singleton
import Quickshell
import QtQuick
import "hooks.js" as H

// Хуки на события: исполняемый ~/.config/ochre/hooks/<событие> с данными в аргументах (нет файла — ничего).
//   wallpaper <картинка> <монитор> <файл>    обои на мониторе в фокусе; у живых (видео, шейдер) картинка — постер, файл — сами обои
//   theme <hex акцента> <акцент> <тема> <dark|light>
//   lock, unlock                              блокировка (зовёт LockScreen)
//   game on|off, dnd on|off                   игровой режим, действующий «не беспокоить»
// Значения при старте shell — не события: хуки начинают работать через 3 с после чтения настроек; в greeter — никогда.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/ochre/hooks"
    property bool ready: false
    property var last: ({})

    readonly property string wallpaper: Wallpaper.still ? JSON.stringify([Wallpaper.still, Wallpaper.focusedOutput, Wallpaper.current]) : ""
    readonly property string theme: JSON.stringify(H.themeArgs(k => Settings.get(k)))
    readonly property bool game: Game.on
    readonly property bool dnd: Notifs.dnd

    function run(event, args) {
        if (!ready) return;
        const a = H.argv(dir, event, args ?? []);
        if (a) Quickshell.execDetached(a);
    }

    function changed(key, value, fire) {
        if (!ready || last[key] === value) return;
        last = Object.assign({}, last, { [key]: value });
        fire();
    }

    onWallpaperChanged: wallTimer.restart()
    onThemeChanged: themeTimer.restart()
    onGameChanged: changed("game", game, () => run("game", [H.onOff(game)]))
    onDndChanged: changed("dnd", dnd, () => run("dnd", [H.onOff(dnd)]))

    Timer {
        id: wallTimer
        interval: 500
        onTriggered: if (root.wallpaper) root.changed("wallpaper", root.wallpaper, () => root.run("wallpaper", JSON.parse(root.wallpaper)))
    }

    Timer {
        id: themeTimer
        interval: 300
        onTriggered: root.changed("theme", root.theme, () => root.run("theme", JSON.parse(root.theme)))
    }

    Timer {
        running: Settings.loaded && !Settings.greeterMode && !root.ready
        interval: 3000
        onTriggered: {
            root.last = { wallpaper: root.wallpaper, theme: root.theme, game: root.game, dnd: root.dnd };
            root.ready = true;
        }
    }
}
