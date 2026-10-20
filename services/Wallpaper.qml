pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "wallpaper.js" as Wl

// Текущие обои, локальная коллекция, фирменные обои ochre и загрузка с wallhaven.cc.
// Живые обои (видео, шейдеры): постеры ~/.cache/ochre/wall-posters/<md5 пути>.png — для greeter, хуков, блокировки
// и окна выбора; видео — кадр ffmpeg, шейдер — снимок из Background. Свой .frag собирается qsb в ~/.cache/ochre/wall-shaders.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/ochre/wallpaper"
    readonly property string slotsFile: Quickshell.env("HOME") + "/.local/state/ochre/wallpapers.json"

    property var slots: Wl.parseState("")
    property var dirs: ({})
    property var probes: ({})
    property var pos: ({})
    property date clock: new Date()
    readonly property bool hasNight: ["all", "outputs", "workspaces"].some(l => JSON.stringify(slots[l]).includes('"night":"'))
        || Object.keys(probes).length > 0 || Object.keys(dirs).some(d => d.endsWith("/night") && dirs[d].length > 0)
    readonly property bool night: hasNight && Wl.isNight(clock, Weather.sun)
    readonly property string focusedOutput: Niri.focusedWorkspace?.output ?? Quickshell.screens[0]?.name ?? ""
    readonly property string current: imageFor(focusedOutput, wsKeyOf(Niri.focusedWorkspace))
    property var folders: []
    property string fill: "fill"           // fill | fit | stretch
    readonly property var fillModes: ["fill", "fit", "stretch"]
    property var local: []                 // пути к файлам в dir
    property string downloading: ""        // id обоев, которые сейчас качаются

    readonly property string posterDir: Quickshell.env("HOME") + "/.cache/ochre/wall-posters"
    readonly property string shaderDir: Quickshell.env("HOME") + "/.cache/ochre/wall-shaders"
    property var posters: ({})             // путь живых обоев → есть постер
    property var shaders: ({})             // путь .frag → собранный .qsb
    property var shaderErrors: ({})        // путь .frag → ошибка qsb (уведомление — один раз)
    readonly property string still: stillOf(current)
    property bool locked: false            // ставит LockScreen: под блокировкой живые обои стоят

    // фирменные живые обои — шейдеры extras/wallpapers/live, цвета берут из темы сами
    readonly property var brandLiveNames: ["rain", "grid", "dots"]
    readonly property var brandLive: brandLiveNames.map(n => brandDir + "/live/ochre-" + n + ".frag")

    // окно выбора
    property bool pickerOpen: false
    property string pickerSource: "local"  // local | wallhaven

    // Фирменные обои (extras/wallpapers): sundown, horizon и field нарисованы под каждый акцент
    // (accents/<акцент>-<имя>.png, у акцента ochre — ochre-<имя>.png), tty — один. Стоят фирменные — при смене
    // акцента меняются на его вариант; обоев ещё нет совсем (первый запуск) — ставится horizon.
    readonly property string brandDir: Quickshell.shellDir + "/extras/wallpapers"
    readonly property var brandNames: ["horizon", "sundown", "field", "tty"]
    readonly property string accent: Settings.get("shell.accent")
    readonly property var brand: brandNames.map(n => brandPath(n, accent))

    function brandPath(name, acc) {
        return name === "tty" || acc === "ochre" ? brandDir + "/ochre-" + name + ".png"
            : brandDir + "/accents/" + acc + "-" + name + ".png";
    }

    // имя фирменных обоев по пути, "" — свои
    function brandNameOf(path) {
        if (!path.startsWith(brandDir + "/")) return "";
        const m = path.match(/[-/](horizon|sundown|field|tty)\.png$/);
        return m ? m[1] : "";
    }

    // до чтения настроек акцент — по умолчанию: не дёргать обои туда-обратно
    onAccentChanged: {
        if (!Settings.writable) return;
        const s = JSON.parse(JSON.stringify(slots));
        let changed = false;
        for (const slot of slotsOf(s)) for (const t of ["day", "night"]) {
            const n = slot[t] ? brandNameOf(slot[t]) : "";
            if (n && brandPath(n, accent) !== slot[t]) { slot[t] = brandPath(n, accent); changed = true; }
        }
        if (changed) save(s);
    }

    // ни wallpapers.json, ни старого файла — обои ни разу не выбирали; ставим фирменные, когда настройки (акцент) уже прочитаны
    property bool _noState: false
    readonly property bool _wantDefault: _noState && Settings.writable
    on_WantDefaultChanged: if (_wantDefault) { _noState = false; set(brandPath("horizon", accent)); }

    function kindOf(path) { return Wl.kindOf(path); }

    function posterOf(path) {
        return posterDir + "/" + Qt.md5(path) + ".png";
    }

    // картинка вместо обоев там, где живые не нужны или невозможны (greeter, хуки, превью); "" — постера ещё нет
    function stillOf(path) {
        return !path || !Wl.isLive(path) ? path : posters[path] ? posterOf(path) : "";
    }

    function posterSaved(path) {
        posters = Object.assign({}, posters, { [path]: true });
    }

    // .qsb для ShaderEffect: готовый файл, собранный рядом (фирменные: name.frag.qsb) или в кэше; "" — ещё не собран
    function shaderOf(path) {
        if (/\.qsb$/i.test(path)) return path;
        if (path.startsWith(brandDir + "/")) return path + ".qsb";
        return shaders[path] ?? "";
    }

    // пауза живых обоев: shell.wallpaper.live выключен, блокировка, игровой режим, батарея, fullscreen-окно на мониторе
    function livePlaying(output) {
        return Settings.get("shell.wallpaper.live") && !locked && !Game.on
            && !(Settings.get("shell.wallpaper.live.battery") && UPower.onBattery)
            && !(Settings.get("shell.wallpaper.live.pause") === "fullscreen" && fullscreenOn(output));
    }

    // активное окно стола на мониторе — во весь монитор (у niri в IPC нет флага fullscreen: сверяем размер окна)
    function fullscreenOn(output) {
        const ws = Niri.workspaces.find(w => w.output === output && w.is_active);
        const win = ws && ws.active_window_id != null ? Niri.windows[ws.active_window_id] : null;
        const size = win && !win.is_floating ? win.layout?.window_size : null;
        const out = Settings.outputs.find(o => o.name === output);
        return !!(size && out && out.w && size[0] >= out.w - 1 && size[1] >= out.h - 1);
    }

    // все живые обои, которые могут понадобиться: назначенные, в папках слайдшоу, в коллекции и фирменные
    readonly property var liveFiles: {
        const all = [];
        for (const slot of slotsOf(slots)) for (const t of ["day", "night"]) if (slot[t]) all.push(slot[t]);
        for (const d in dirs) for (const f of dirs[d]) all.push(f);
        for (const f of local.concat(brandLive)) all.push(f);
        return all.filter((p, i) => Wl.isLive(p) && all.indexOf(p) === i).sort();
    }
    onLiveFilesChanged: prepTimer.restart()

    function prep() {
        if (preparer.running) { prepTimer.restart(); return; }
        const args = [];
        for (const p of liveFiles) {
            const k = Wl.kindOf(p);
            if (k === "video") { if (!posters[p]) args.push("V", p, posterOf(p)); }
            else {
                if (!posters[p]) args.push("P", p, posterOf(p));
                if (/\.frag$/i.test(p) && !p.startsWith(brandDir + "/") && !shaders[p]) args.push("S", p, shaderDir + "/" + Qt.md5(p) + ".qsb");
            }
        }
        if (!args.length) return;
        // V: кадр ffmpeg (с 1-й секунды, у коротких — первый); P: есть ли снимок; S: готовый name.frag.qsb рядом, свежий кэш или qsb
        preparer.command = ["sh", "-c", `
            q=$(command -v qsb || command -v qsb6 || echo /usr/lib/qt6/bin/qsb)
            while [ $# -ge 3 ]; do
                case $1 in
                V) [ -f "$3" ] || { ffmpeg -nostdin -loglevel error -y -ss 1 -i "$2" -frames:v 1 -vf "scale='min(1920,iw)':-2" "$3.part.png" 2>/dev/null \
                        && [ -s "$3.part.png" ] || ffmpeg -nostdin -loglevel error -y -i "$2" -frames:v 1 -vf "scale='min(1920,iw)':-2" "$3.part.png"; } \
                        && [ -s "$3.part.png" ] && mv -f "$3.part.png" "$3"
                    rm -f "$3.part.png"
                    [ -f "$3" ] && printf 'P\t%s\n' "$2" ;;
                P) [ -f "$3" ] && printf 'P\t%s\n' "$2" ;;
                S) if [ -f "$2.qsb" ] && [ ! "$2" -nt "$2.qsb" ]; then printf 'Q\t%s\t%s\n' "$2" "$2.qsb"
                    elif [ -f "$3" ] && [ ! "$2" -nt "$3" ]; then printf 'Q\t%s\t%s\n' "$2" "$3"
                    elif err=$("$q" --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$3" "$2" 2>&1); then printf 'Q\t%s\t%s\n' "$2" "$3"
                    else printf 'E\t%s\t%s\n' "$2" "$(printf '%s' "$err" | tr '\n\t' '  ' | cut -c1-300)"; fi ;;
                esac
                shift 3
            done`, "sh"].concat(args);
        preparer.running = true;
    }

    function slotsOf(s) {
        return [s.all].concat(Object.values(s.outputs), Object.values(s.workspaces));
    }

    function wsKeyOf(ws) {
        return Wl.wsKey(ws, ws ? Settings.outKey(ws.output) : "");
    }

    function activeWs(output) {
        return wsKeyOf(Niri.workspaces.find(w => w.output === output && w.is_active) ?? null);
    }

    function migrateOutputs() {
        if (!Settings.writable || !Settings.outputs.length) return;
        const s = Wl.migrateOutputs(slots, Settings.outputIds);
        if (s) save(s);
    }

    Connections {
        target: Settings
        function onOutputIdsChanged() { root.migrateOutputs(); }
        function onWritableChanged() { root.migrateOutputs(); }
    }

    function resolveFor(output, ws) {
        const i = Quickshell.screens.findIndex(s => s.name === output);
        return Wl.resolve(slots, Settings.outKey(output), ws, night, p => probes[p] === true, p => dirs[p] ?? null, pos[output] ?? Math.max(0, i));
    }

    function imageFor(output, ws) {
        return resolveFor(output, ws).path;
    }

    function targetKey(level) {
        return level === "output" ? Settings.outKey(focusedOutput) : level === "ws" ? wsKeyOf(Niri.focusedWorkspace) : "";
    }

    function slotOf(s, level, key) {
        return level === "all" ? s.all : (level === "output" ? s.outputs : s.workspaces)[key];
    }

    function slotPath(level, time) {
        return (slotOf(slots, level, targetKey(level)) || {})[time] || "";
    }

    function assign(level, time, path) {
        if (!["all", "output", "ws"].includes(level) || !["day", "night"].includes(time)) return;
        const key = targetKey(level);
        if (level !== "all" && !key) return;
        const s = JSON.parse(JSON.stringify(slots));
        const map = level === "output" ? s.outputs : s.workspaces;
        let slot = slotOf(s, level, key);
        if (!slot) slot = map[key] = {};
        if (path) slot[time] = path;
        else delete slot[time];
        if (level !== "all" && !slot.day && !slot.night) delete map[key];
        save(s);
    }

    function set(path) {
        assign("all", "day", path);
    }

    function save(s) {
        slots = s;
        slotsView.setText(JSON.stringify(s, null, 2) + "\n");
        scan();
    }

    function next() {
        const order = Settings.get("shell.wallpaper.order");
        const p = Object.assign({}, pos);
        for (const scr of Quickshell.screens) {
            const r = resolveFor(scr.name, activeWs(scr.name));
            if (r.count > 1) p[scr.name] = Wl.pick(r.count, (p[scr.name] ?? 0) % r.count, order, Math.random());
        }
        pos = p;
        scan();
    }

    property bool _rescan: false
    function scan() {
        if (scanner.running) { _rescan = true; return; }
        const args = [];
        for (const slot of slotsOf(slots)) for (const t of ["day", "night"]) {
            const v = slot[t];
            if (!v) continue;
            if (Wl.MEDIA.test(v)) { if (t === "day") args.push("F:" + Wl.nightVariant(v)); }
            else args.push("D:" + v, "D:" + v + "/night");
        }
        scanner.command = ["sh", "-c", `
            for a; do
                p=\${a#?:}
                case $a in
                D:*) [ -d "$p" ] || continue; printf 'E\\t%s\\n' "$p"
                    find "$p" -maxdepth 1 -type f | grep -iE '${root.extRe}' |
                        while IFS= read -r f; do printf 'D\\t%s\\t%s\\n' "$p" "$f"; done ;;
                F:*) [ -f "$p" ] && printf 'F\\t%s\\n' "$p" ;;
                esac
            done`, "sh"].concat(args);
        scanner.running = true;
    }

    function setFill(mode) {
        if (!fillModes.includes(mode)) return;
        fill = mode;
        fillState.setText(mode + "\n");
    }

    function cycleFill() {
        setFill(fillModes[(fillModes.indexOf(fill) + 1) % fillModes.length]);
    }

    function refresh() {
        lister.running = true;
        folderLister.running = true;
    }

    function localPathFor(w) {
        return dir + "/wallhaven-" + w.id + w.path.slice(w.path.lastIndexOf("."));
    }

    function download(w, level, time) {
        const dest = localPathFor(w);
        if (local.includes(dest)) { assign(level, time, dest); return; }
        if (downloading) return;
        downloading = w.id;
        dl.dest = dest;
        dl.level = level;
        dl.time = time;
        dl.command = ["sh", "-c", 'curl -fsSL -o "$1.part" "$2" && mv "$1.part" "$1"', "sh", dest, w.path];
        dl.running = true;
    }

    // поиск на wallhaven; cb({ items, lastPage }) или cb({ error })
    function search(query, page, cb) {
        const p = {
            q: query,
            categories: "110",   // general + anime
            purity: "100",       // только SFW
            sorting: query ? "relevance" : "toplist",
            topRange: "1M",
            atleast: "1920x1080",
            ratios: "landscape",
            page: page
        };
        const qs = Object.keys(p).map(k => k + "=" + encodeURIComponent(p[k])).join("&");
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { cb({ error: "wallhaven: HTTP " + xhr.status }); return; }
            try {
                const r = JSON.parse(xhr.responseText);
                cb({ items: r.data, lastPage: r.meta.last_page });
            } catch (e) {
                cb({ error: "wallhaven: " + e });
            }
        };
        xhr.open("GET", "https://wallhaven.cc/api/v1/search?" + qs);
        xhr.send();
    }

    // расширения обоев для grep -E в скриптах (константа из wallpaper.js, не данные пользователя)
    readonly property string extRe: "\\.(" + Wl.EXTS.join("|") + ")$"

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir, stateFile.slice(0, stateFile.lastIndexOf("/")), posterDir, shaderDir])

    Timer {
        id: prepTimer
        interval: 300
        onTriggered: root.prep()
    }

    Process {
        id: preparer
        stdout: StdioCollector {
            onStreamFinished: {
                const p = Object.assign({}, root.posters);
                const q = Object.assign({}, root.shaders);
                const e = Object.assign({}, root.shaderErrors);
                for (const l of this.text.split("\n")) {
                    const c = l.split("\t");
                    if (c[0] === "P") p[c[1]] = true;
                    else if (c[0] === "Q") { q[c[1]] = c[2]; delete e[c[1]]; }
                    else if (c[0] === "E" && !(c[1] in e)) {
                        e[c[1]] = c[2];
                        Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Шейдер обоев не собрался"),
                            c[1].slice(c[1].lastIndexOf("/") + 1) + ": " + (c[2] || I18n.tr("нет qsb (qt6-shadertools)"))]);
                    }
                }
                root.posters = p;
                root.shaders = q;
                root.shaderErrors = e;
            }
        }
    }

    FileView {
        id: slotsView
        // после переезда с nopox-shell: ~/.local/state/nopox → ochre (Settings.renamed)
        path: Settings.renamed ? root.slotsFile : ""
        onLoaded: {
            root.slots = Wl.parseState(text());
            root.scan();
            root.migrateOutputs();
        }
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) legacy.path = root.stateFile; }
    }

    FileView {
        id: legacy
        onLoaded: {
            const p = text().trim();
            if (p) root.set(p);
            else root._noState = true;
        }
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) root._noState = true; }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.clock = new Date()
    }

    Timer {
        interval: Settings.get("shell.wallpaper.interval") * 60000
        running: interval > 0
        repeat: true
        onTriggered: root.next()
    }

    Process {
        id: scanner
        onExited: if (root._rescan) { root._rescan = false; root.scan(); }
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                const f = {};
                for (const l of this.text.split("\n")) {
                    const c = l.split("\t");
                    if (c[0] === "E") d[c[1]] = d[c[1]] ?? [];
                    else if (c[0] === "D") (d[c[1]] = d[c[1]] ?? []).push(c[2]);
                    else if (c[0] === "F") f[c[1]] = true;
                }
                for (const k in d) d[k].sort();
                root.dirs = d;
                root.probes = f;
            }
        }
    }

    FileView {
        id: fillState
        path: Settings.renamed ? root.stateFile + "-fill" : ""
        onLoaded: {
            const m = text().trim();
            if (root.fillModes.includes(m)) root.fill = m;
        }
    }

    Process {
        id: lister
        running: true
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "("].concat(Wl.findNames(), [")"])
        stdout: StdioCollector {
            onStreamFinished: root.local = this.text.split("\n").filter(l => l).sort()
        }
    }

    Process {
        id: folderLister
        running: true
        command: ["sh", "-c", `
            for d in "$1"/*/; do
                [ -d "$d" ] || continue
                d=\${d%/}
                [ "\${d##*/}" = night ] && continue
                f=$(find "$d" -maxdepth 1 -type f | grep -iE '${root.extRe}' | sort | head -n 1)
                printf '%s\\t%s\\n' "$d" "$f"
            done`, "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.folders = this.text.split("\n").filter(l => l).map(l => l.split("\t"))
        }
    }

    Process {
        id: dl

        property string dest
        property string level
        property string time

        onExited: code => {
            root.downloading = "";
            if (code === 0) {
                root.assign(level, time, dest);
                root.refresh();
            }
        }
    }
}
