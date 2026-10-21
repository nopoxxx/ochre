import Quickshell.Services.Pipewire
import QtQuick
import qs
import qs.bar

// vol 45% — колёсико ±5%, клик: микшер, правый клик: mute
Seg {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null

    available: audio !== null
    label: "vol"
    value: audio?.muted ? "muted" : Math.round((audio?.volume ?? 0) * 100) + "%"
    compact: audio?.muted ? "mute" : value
    valueColor: audio?.muted ? Theme.gray : Theme.fg

    onLeftClicked: mixer.toggle()
    onRightClicked: if (audio) audio.muted = !audio.muted
    scrollable: true
    onScrolled: dir => {
        if (audio) audio.volume = Math.max(0, Math.min(1, audio.volume + dir * 0.05));
    }

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    MixerPopup { id: mixer; owner: root; bar: root.bar }
}
