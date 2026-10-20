.pragma library
.import "settings.js" as S

// Хуки на события (services/Hooks.qml): исполняемый файл ~/.config/ochre/hooks/<событие>, данные — аргументами
var EVENTS = ["wallpaper", "theme", "lock", "unlock", "game", "dnd"];

function argv(dir, event, args) {
    if (EVENTS.indexOf(event) < 0) return null;
    return ["sh", "-c", '[ -x "$1" ] || exit 0; exec "$@"', "sh", dir + "/" + event].concat(args.map(String));
}

function themeArgs(get) {
    const p = S.palette(get);
    return [String(p.accent), get("shell.accent"), get("shell.theme.name"), p.dark ? "dark" : "light"];
}

function onOff(v) {
    return v ? "on" : "off";
}
