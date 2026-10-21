.pragma library

// Звуки на события (services/Sounds.qml): событие → переключатель shell.sound.<группа>, громкость, команда pw-play
var EVENTS = {
    "notify": "notify",
    "critical": "notify",
    "lock": "lock",
    "unlock": "lock",
    "auth-fail": "lock",
    "screenshot": "shot",
    "rec-start": "shot",
    "rec-stop": "shot",
    "plug": "power",
    "unplug": "power",
    "battery-low": "power",
    "volume": "volume",
    "mute": "mute",
    "unmute": "mute",
    "timer": "timer",
    "login": "login"
};

var QUIET = ["notify"];

function allowed(get, event, dnd) {
    const group = EVENTS[event];
    if (!group || !get("shell.sound") || !get("shell.sound." + group)) return false;
    return !(dnd && QUIET.indexOf(event) >= 0);
}

function volume(get, music) {
    const v = get("shell.sound.level") / 100;
    return Math.round((music ? v * get("shell.sound.duck") / 100 : v) * 100) / 100;
}

function argv(userDir, themeDir, event, vol) {
    if (!EVENTS[event]) return null;
    return ["sh", "-c", `
        for f in "$1/$3.wav" "$1/$3.oga" "$1/$3.ogg" "$2/$3.wav"; do
            [ -f "$f" ] && exec pw-play --media-role=Notification --volume="$4" "$f"
        done`, "sh", userDir, themeDir, event, String(vol)];
}
