pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "wallpaper.js" as Wl

// Текущие обои, локальная коллекция, фирменные обои ochre и загрузка с wallhaven.cc
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
    readonly property string current: imageFor(focusedOutput, Wl.wsKey(Niri.focusedWorkspace))
    property var folders: []
    property string fill: "fill"           // fill | fit | stretch
    readonly property var fillModes: ["fill", "fit", "stretch"]
    property var local: []                 // пути к файлам в dir
    property string downloading: ""        // id обоев, которые сейчас качаются

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

    function slotsOf(s) {
        return [s.all].concat(Object.values(s.outputs), Object.values(s.workspaces));
    }

    function activeWs(output) {
        return Wl.wsKey(Niri.workspaces.find(w => w.output === output && w.is_active) ?? null);
    }

    function resolveFor(output, ws) {
        const i = Quickshell.screens.findIndex(s => s.name === output);
        return Wl.resolve(slots, output, ws, night, p => probes[p] === true, p => dirs[p] ?? null, pos[output] ?? Math.max(0, i));
    }

    function imageFor(output, ws) {
        return resolveFor(output, ws).path;
    }

    function targetKey(level) {
        return level === "output" ? focusedOutput : level === "ws" ? Wl.wsKey(Niri.focusedWorkspace) : "";
    }

    function slotOf(s, level, key) {
        return level === "all" ? s.all : (level === "output" ? s.outputs : s.workspaces)[key];
    }

    function slotPath(level, time) {
        return (slotOf(slots, level, targetKey(level)) || {})[time] || "";
    }

    // path "" — сбросить слот: уровень наследует более широкий
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

    // папки из слотов (и их night/) и ночные варианты файлов — одним вызовом
    property bool _rescan: false
    function scan() {
        if (scanner.running) { _rescan = true; return; }
        const args = [];
        for (const slot of slotsOf(slots)) for (const t of ["day", "night"]) {
            const v = slot[t];
            if (!v) continue;
            if (/\.(png|jpe?g|webp)$/i.test(v)) { if (t === "day") args.push("F:" + Wl.nightVariant(v)); }
            else args.push("D:" + v, "D:" + v + "/night");
        }
        scanner.command = ["sh", "-c", `
            for a; do
                p=\${a#?:}
                case $a in
                D:*) [ -d "$p" ] || continue; printf 'E\\t%s\\n' "$p"
                    find "$p" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) |
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

    function download(w) {
        const dest = localPathFor(w);
        if (local.includes(dest)) { set(dest); return; }
        if (downloading) return;
        downloading = w.id;
        dl.dest = dest;
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

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir, stateFile.slice(0, stateFile.lastIndexOf("/"))])

    FileView {
        id: slotsView
        // после переезда с nopox-shell: ~/.local/state/nopox → ochre (Settings.renamed)
        path: Settings.renamed ? root.slotsFile : ""
        onLoaded: {
            root.slots = Wl.parseState(text());
            root.scan();
        }
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) legacy.path = root.stateFile; }
    }

    // одни обои на все экраны (до wallpapers.json) — переезжают в all.day, сам файл остаётся
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
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.local = this.text.split("\n").filter(l => l).sort()
        }
    }

    Process {
        id: folderLister
        running: true
        command: ["find", root.dir, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "!", "-name", "night"]
        stdout: StdioCollector {
            onStreamFinished: root.folders = this.text.split("\n").filter(l => l).sort()
        }
    }

    Process {
        id: dl

        property string dest

        onExited: code => {
            root.downloading = "";
            if (code === 0) {
                root.set(dest);
                root.refresh();
            }
        }
    }
}
