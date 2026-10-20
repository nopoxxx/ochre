pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "services/settings.js" as S

Singleton {
    id: root

    readonly property var scheme: S.palette(k => Settings.get(k))
    readonly property bool dark: scheme.dark
    readonly property color bg: scheme.bg
    readonly property color bg0: scheme.bg0
    readonly property color bg1: scheme.bg1
    readonly property color bg2: scheme.bg2
    readonly property color bg3: scheme.bg3
    readonly property color hover: scheme.hover
    readonly property color fg: scheme.fg
    readonly property color fg0: scheme.fg0
    readonly property color fgDim: scheme.fgDim
    readonly property color gray: scheme.gray
    readonly property color red: scheme.red
    readonly property color green: scheme.green
    readonly property color yellow: scheme.yellow
    readonly property color ochre: scheme.ochre
    readonly property color blue: scheme.blue
    readonly property color purple: scheme.purple
    readonly property color aqua: scheme.aqua
    readonly property color orange: scheme.orange
    readonly property color accent: scheme.accent
    readonly property bool hasLight: Object.prototype.hasOwnProperty.call(S.THEMES, Settings.get("shell.theme.name"))
        && !!S.THEMES[Settings.get("shell.theme.name")].light

    function setMode(m) { Settings.set("shell.theme.mode", m); }
    function toggleMode() { setMode(Settings.get("shell.theme.mode") === "light" ? "dark" : "light"); }

    IpcHandler {
        target: "theme"
        function toggle(): void { root.toggleMode(); }
        function dark(): void { root.setMode("dark"); }
        function light(): void { root.setMode("light"); }
        function get(): string { return root.dark ? "dark" : "light"; }
    }

    // цвет по имени из настроек (акценты, цвета разметки скриншота): white/black — светлый и тёмный из fg/bg
    function named(n) {
        return ({ ochre: ochre, yellow: yellow, orange: orange, green: green, aqua: aqua, blue: blue, purple: purple,
                  red: red, white: dark ? fg : bg, black: dark ? bg : fg })[n] ?? gray;
    }

    readonly property string font: "Terminess Nerd Font Mono"
    // значки Nerd Font: в Mono-версии они ужаты в клетку и не читаются (см. services/glyphs.js)
    readonly property string iconFont: "Terminess Nerd Font"
    readonly property int fontSize: Settings.get("shell.fontSize")
    readonly property int barHeight: Settings.get("shell.bar.height")
    readonly property int pad: 10
}
