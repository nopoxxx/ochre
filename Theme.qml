pragma Singleton
import Quickshell
import QtQuick
import qs.services

// Gruvbox dark (hard) — единая палитра ochre
Singleton {
    readonly property color bg: "#1d2021"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color fg: "#ebdbb2"
    readonly property color gray: "#928374"
    readonly property color red: "#fb4934"
    readonly property color green: "#b8bb26"
    readonly property color yellow: "#fabd2f"
    readonly property color ochre: "#d79921"     // цвет бренда — gruvbox neutral yellow
    readonly property color blue: "#83a598"
    readonly property color purple: "#d3869b"
    readonly property color aqua: "#8ec07c"
    readonly property color orange: "#fe8019"

    // акцент из настроек: рамки, prompt (и рамка фокуса niri — см. services/settings.js)
    readonly property color accent: ({
        ochre: ochre, yellow: yellow, orange: orange, green: green, aqua: aqua,
        blue: blue, purple: purple, red: red
    })[Settings.get("shell.accent")] ?? ochre

    // цвет по имени из настроек (акценты, цвета разметки скриншота): white/black — fg/bg
    function named(n) {
        return ({ ochre: ochre, yellow: yellow, orange: orange, green: green, aqua: aqua, blue: blue, purple: purple,
                  red: red, white: fg, black: bg })[n] ?? gray;
    }

    readonly property string font: "Terminess Nerd Font Mono"
    // значки Nerd Font: в Mono-версии они ужаты в клетку и не читаются (см. services/glyphs.js)
    readonly property string iconFont: "Terminess Nerd Font"
    readonly property int fontSize: Settings.get("shell.fontSize")
    readonly property int barHeight: Settings.get("shell.bar.height")
    readonly property int pad: 10
}
