pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

Singleton {
    id: root

    readonly property bool on: Settings.writable && Settings.get("shell.theme.name") === "wallpaper"
    readonly property string scheme: Settings.get("shell.theme.scheme")
    readonly property string src: Wallpaper.still   // у видео и шейдера — постер: matugen берёт только картинки
    readonly property string want: on && src ? src + "\n" + scheme : ""
    property var cache: ({})
    property bool warned: false

    onWantChanged: debounce.restart()

    Timer { id: debounce; interval: 600; onTriggered: root.update() }

    function update() {
        if (!want) return;
        const cur = Settings.get("shell.theme.wallpaper");
        if (cur && cur.src === src && cur.scheme === scheme) return;
        if (cache[want]) { store(want, cache[want]); return; }
        if (gen.running) { debounce.restart(); return; }
        gen.key = want;
        gen.command = ["sh", "-c", `
            command -v matugen >/dev/null || exit 127
            matugen image "$1" -t "scheme-$2" --json hex --dry-run --source-color-index 0 2>/dev/null \\
                || matugen image "$1" -t "scheme-$2" --json hex --dry-run 2>/dev/null`, "sh", src, scheme];
        gen.running = true;
    }

    function store(key, t) {
        const [path, sch] = key.split("\n");
        Settings.set("shell.theme.wallpaper", { src: path, scheme: sch, dark: t.dark, light: t.light });
    }

    Process {
        id: gen
        property string key: ""
        stdout: StdioCollector { id: out }
        onExited: code => {
            if (code === 127) {
                if (!root.warned) Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Нет matugen"),
                    I18n.tr("Тема Wallpaper строит палитру из обоев через matugen — установите его")]);
                root.warned = true;
                return;
            }
            let t = null;
            try { t = S.wallTheme(JSON.parse(out.text).colors); } catch (e) {}
            if (!t) { console.warn("WallPalette: no palette from matugen for", key.split("\n")[0]); return; }
            const c = Object.assign({}, root.cache);
            c[key] = t;
            root.cache = c;
            if (key === root.want) root.store(key, t);
            else root.update();
        }
    }
}
