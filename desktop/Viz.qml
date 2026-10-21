import QtQuick
import qs
import qs.services

// Полоски звука на столе: столбики из ▁▂▃▄▅▆▇█ во всю высоту рамки — то, что играет сейчас (cava).
Item {
    id: root

    property var cfg
    property real cw
    property real ch
    property bool editing

    readonly property string glyphs: " ▁▂▃▄▅▆▇█"
    readonly property int n: Math.max(1, Math.floor(width / cw / 2))
    readonly property int rows: Math.max(1, Math.floor(height / ch))

    // n столбиков из Cava.count уровней 0…7 — максимумом по группе, как Cava.bars
    readonly property var values: {
        const lv = Cava.levels, out = [];
        for (let i = 0; i < n; i++) {
            const a = Math.floor(i * Cava.count / n), b = Math.max(a + 1, Math.floor((i + 1) * Cava.count / n));
            let v = 0;
            for (let j = a; j < b; j++) v = Math.max(v, lv[j] ?? 0);
            out.push(lv.length ? (v + 1) / 8 : 0);
        }
        return out;
    }

    T {
        anchors.centerIn: parent
        visible: !Cava.installed
        text: I18n.tr("нужен cava")
        color: Theme.gray
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Cava.installed

        Repeater {
            model: root.rows
            T {
                required property int index
                readonly property int fromBottom: root.rows - 1 - index
                text: root.values.map(v => {
                    const k = Math.round(Math.max(0, Math.min(1, v * root.rows - fromBottom)) * 8);
                    return root.glyphs[k] + " ";
                }).join("")
                color: Theme.accent
                lineHeight: root.ch
                lineHeightMode: Text.FixedHeight
            }
        }
    }
}
