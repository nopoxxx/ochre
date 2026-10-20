import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Громкость, микрофон и яркость (если есть подсветка экрана): ←→ / колёсико ±5%, клик по полосе — значение,
// ↵ или клик по подписи — mute. Приложения по отдельности — микшер на vol в панели.
Section {
    id: sec

    title: I18n.tr("звук и экран")

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [sec.sink, sec.source].filter(x => x) }

    readonly property var gauges: [
        sink?.audio ? { kind: "sink", node: sink } : null,
        source?.audio ? { kind: "source", node: source } : null,
        Brightness.available ? { kind: "bright" } : null
    ].filter(x => x)

    available: gauges.length > 0
    count: gauges.length

    function setValue(g, v) {
        if (g.kind === "bright") Brightness.set(v);
        else g.node.audio.volume = v;
    }

    function key(event) {
        const g = gauges[cur];
        if (!g) return false;
        const d = event.key === Qt.Key_Left || event.key === Qt.Key_H ? -1 : event.key === Qt.Key_Right || event.key === Qt.Key_L ? 1 : 0;
        if (!d) return false;
        const v = g.kind === "bright" ? Brightness.value : g.node.audio.volume;
        setValue(g, Math.max(0, Math.min(1, v + d * 0.05)));
        return true;
    }

    function activate(i) {
        const g = gauges[i];
        if (g && g.kind !== "bright") g.node.audio.muted = !g.node.audio.muted;
    }

    Repeater {
        model: sec.gauges

        Gauge {
            required property var modelData
            required property int index
            readonly property bool bright: modelData.kind === "bright"
            readonly property bool mic: modelData.kind === "source"

            Layout.fillWidth: true
            current: sec.isCur(index)
            icon: bright ? G.g("bright") : mic ? G.g(off ? "micOff" : "mic") : G.g(off ? "volOff" : "vol")
            label: bright ? I18n.tr("яркость") : mic ? "mic" : "vol"
            value: bright ? Brightness.value : Math.min(1, modelData.node.audio.volume)
            off: !bright && modelData.node.audio.muted
            onMoved: v => { sec.pick(index); sec.setValue(modelData, v); }
            onToggled: { sec.pick(index); sec.activate(index); }
        }
    }
}
