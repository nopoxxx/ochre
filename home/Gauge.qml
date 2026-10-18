import QtQuick
import QtQuick.Layouts
import qs

// Ползунок «󰕾 vol   ▕██████████░░░░▏  62%»: клик и перетаскивание по полосе, колёсико ±5%,
// с клавиатуры ←→ (секция вызывает step). Клик по подписи — toggled (mute).
RowLayout {
    id: g

    property string icon: ""
    property string label: ""
    property real value: 0            // 0…1
    property bool off: false          // mute — серым
    property bool current: false
    // длина полосы — по месту: в карточке или узкой колонке дашборда 20 знаков не влезали
    readonly property int cells: Math.max(6, Math.floor(bar.width / cellG.advanceWidth) - 2)
    signal moved(real v)
    signal toggled()

    readonly property int filled: Math.round(Math.max(0, Math.min(1, value)) * cells)

    function step(d) { moved(Math.max(0, Math.min(1, value + d * 0.05))); }

    TextMetrics { id: cellG; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

    spacing: 0
    Layout.topMargin: 3
    Layout.bottomMargin: 3

    T { text: g.current ? "▌" : " "; color: Theme.accent }
    Item {
        implicitWidth: lbl.implicitWidth
        implicitHeight: lbl.implicitHeight
        Row {
            id: lbl
            T { font.family: Theme.iconFont; text: g.icon + " "; color: g.off ? Theme.gray : Theme.accent }
            T { text: g.label.padEnd(8); color: g.off ? Theme.gray : g.current ? Theme.fg : Qt.darker(Theme.fg, 1.15); font.bold: g.current }
        }
        TapHandler { onTapped: g.toggled() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    T {
        id: bar
        // ширину задаёт раскладка, а не текст: иначе длина полосы и ширина зациклятся
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        clip: true
        text: "▕" + "█".repeat(g.filled) + "░".repeat(g.cells - g.filled) + "▏"
        color: g.off ? Theme.gray : Theme.accent

        // зона захвата выше самой полосы — по ней легко попасть и тянуть
        MouseArea {
            anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            function at(x) {
                const ch = bar.width / (g.cells + 2);
                g.moved(Math.max(0, Math.min(1, (x - ch) / (bar.width - 2 * ch))));
            }
            onPressed: mouse => at(mouse.x)
            onPositionChanged: mouse => { if (pressed) at(mouse.x); }
            onWheel: wheel => g.step(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }
    T {
        text: g.off ? " muted" : (" " + Math.round(g.value * 100) + "%").padStart(5)
        color: Theme.gray
    }
}
