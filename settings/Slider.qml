import QtQuick
import qs

// число: [−] ▕████░░░░▏ [+] значение; полосу можно тянуть
Row {
    id: sl
    property var win
    property var r
    property int idx
    property bool current

    readonly property real v: win.shown(r)
    readonly property int cells: 18
    readonly property int filled: Math.round(Math.max(0, Math.min(1, (v - r.min) / (r.max - r.min))) * cells)
    readonly property int decimals: r.type === "float" ? (String(r.step).split(".")[1]?.length ?? 0) : 0
    spacing: 0
    function at(x) {
        const f = Math.max(0, Math.min(1, x / (cells * win.cw)));
        const n = r.min + Math.round(f * (r.max - r.min) / r.step) * r.step;
        return r.type === "int" ? Math.round(n) : Number(n.toFixed(2));
    }
    T {
        font.family: Theme.iconFont
        text: String.fromCodePoint(0xF0374) + " "
        color: minus.containsMouse ? Theme.accent : Theme.gray
        MouseArea { id: minus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sl.win.nudge(sl.idx, -1) }
    }
    T {
        text: "█".repeat(sl.filled) + "░".repeat(sl.cells - sl.filled)
        color: sl.win.drafted(sl.r) ? Theme.accent : Qt.darker(Theme.accent, sl.current ? 1 : 1.25)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => sl.win.pick(sl.idx, sl.at(mouse.x))
            onPositionChanged: mouse => { if (pressed) { const v = sl.at(mouse.x); if (v !== sl.win.value(sl.win.rows[sl.idx])) sl.win.pick(sl.idx, v); } }
        }
    }
    T {
        font.family: Theme.iconFont
        text: " " + String.fromCodePoint(0xF0415)
        color: plus.containsMouse ? Theme.accent : Theme.gray
        MouseArea { id: plus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sl.win.nudge(sl.idx, 1) }
    }
    T {
        text: " " + Number(sl.v).toFixed(sl.decimals).padStart(5)
        color: sl.win.drafted(sl.r) ? Theme.accent : Theme.fg
        font.bold: true
    }
}
