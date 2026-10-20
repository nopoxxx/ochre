pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import "sounds.js" as Snd

// Звуки на события: extras/sounds/ochre/<событие>.wav, свой файл — ~/.config/ochre/sounds/<событие>.{wav,oga,ogg}.
// Громкость, зарядка, батарея, запись и мелодия входа отслеживаются здесь; остальное зовёт play() (Notifs, LockScreen,
// MuteNotify, ShotWindow, Countdown). Настройки: shell.sound.*; пока играет музыка — тише (shell.sound.duck).
Singleton {
    id: root

    readonly property string themeDir: Quickshell.shellDir + "/extras/sounds/ochre"
    readonly property string userDir: Quickshell.env("HOME") + "/.config/ochre/sounds"
    readonly property bool music: Mpris.players.values.some(p => p.isPlaying)
    property bool ready: false
    property var lastAt: ({})
    property double anyAt: 0

    function get(k) { return Settings.get(k); }

    function play(event) {
        if (Settings.greeterMode || !Settings.loaded || !Snd.allowed(get, event, Notifs.dnd)) return;
        const now = Date.now();
        if (now - (lastAt[event] ?? 0) < 120) return;
        lastAt = Object.assign({}, lastAt, { [event]: now });
        anyAt = now;
        const v = Snd.volume(get, music);
        if (v > 0) Quickshell.execDetached(Snd.argv(userDir, themeDir, event, v));
    }

    function test() {
        Quickshell.execDetached(Snd.argv(userDir, themeDir, "login", Snd.volume(get, false)));
    }

    function recent(ms) { return Date.now() - anyAt < ms; }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    property var lastSink: null

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    onVolChanged: {
        if (sink !== lastSink) lastSink = sink;
        else if (ready) play("volume");
    }

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat?.isLaptopBattery ?? false
    readonly property bool charging: hasBat && (bat.state === UPowerDeviceState.Charging
        || bat.state === UPowerDeviceState.PendingCharge || bat.state === UPowerDeviceState.FullyCharged)
    readonly property int pct: hasBat ? Math.round(bat.percentage <= 1 ? bat.percentage * 100 : bat.percentage) : 100
    readonly property bool low: hasBat && !charging && pct <= 15

    onChargingChanged: if (ready) play(charging ? "plug" : "unplug")
    onLowChanged: if (ready && low) play("battery-low")

    Connections {
        target: Recorder
        function onRecordingChanged() { root.play(Recorder.recording ? "rec-start" : "rec-stop"); }
    }

    Timer {
        running: Settings.loaded && !Settings.greeterMode && !root.ready
        interval: 1500
        onTriggered: {
            root.lastSink = root.sink;
            root.ready = true;
            const a = Snd.allowed(root.get, "login", false) ? Snd.argv(root.userDir, root.themeDir, "login", Snd.volume(root.get, root.music)) : [];
            Quickshell.execDetached(["sh", "-c", 'm="${XDG_RUNTIME_DIR:-/tmp}/ochre-login-sound"; [ -e "$m" ] && exit 0; : > "$m"; [ $# -gt 0 ] || exit 0; exec "$@"', "sh"].concat(a));
        }
    }
}
