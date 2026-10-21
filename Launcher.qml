import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy
import "services/calc.js" as Calc
import "services/emoji.js" as Emoji
import "services/settings.js" as S

// Меню в духе omarchy: сначала раздел (apps/, system/ …), потом действие.
// Разделы ведут себя как каталоги: путь в заголовке, Esc или ← — на уровень выше
// (но не выше раздела, в котором меню открыли: там Esc закрывает окно).
//   qs ipc call launcher toggle — корень меню
// Запрос в корне ищет по меню сразу: программы и вложенные действия (system/reboot).
// Остальное — только префиксами в корне (настраиваются, look/ → меню): «=выражение» — калькулятор,
// «> cmd» — в терминале, «/имя» — файлы, «? запрос» — веб-поиск, «:имя» — эмодзи в буфер,
// «@имя» — окна niri, «+пакет» / «-пакет» — установить / удалить, «%25m чай» — таймер,
// «!вопрос» — Claude Code в терминале или Google AI Mode в браузере.
//   qs ipc call launcher apps   — сразу список программ
Scope {
    id: root

    property bool open: false
    property string startAt: ""
    readonly property int rows: Settings.get("shell.launcher.rows")

    // окно живёт, пока доигрывает закрытие (Reveal.qml)
    Reveal {
        id: reveal
        open: root.open
        style: Settings.get("shell.launcher.anim")
        duration: 150
        distance: 30
    }

    IpcHandler {
        target: "launcher"
        // не `show`: это имя занято подкомандой `qs ipc show`
        function toggle(): void { root.startAt = ""; root.open = !root.open; }
        function apps(): void { root.startAt = "apps"; root.open = !root.open; }
        function open(): void { root.startAt = ""; root.open = true; }
        function close(): void { root.open = false; }
    }

    // ── действия ───────────────────────────────────────────────────

    function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }

    // команда в плавающем окне терминала (Term); с hold вывод остаётся на экране
    function term(cmd, hold = true) {
        Term.float(["bash", "-c", cmd], { hold });
    }

    function spawn(argv) { Quickshell.execDetached(argv); }

    // AI-агент (shell.launcher.ai.cmd, по умолчанию claude) в обычном окне терминала, из ~
    function ai(args) {
        const cmd = String(Settings.get("shell.launcher.ai.cmd") ?? "").trim() || "claude";
        Term.open(["bash", "-c",
            'cd ~; command -v "${1%% *}" >/dev/null || { printf "%s\\n" "$2"; read -rs; exit 1; }; exec $1 "${@:3}"',
            "bash", cmd, I18n.tr("не найдено: %1 — поставь Claude Code или смени команду в look/ → меню", cmd)].concat(args));
    }

    function openPicker(source) {
        Wallpaper.pickerSource = source;
        Wallpaper.pickerOpen = true;
    }

    function launchApp(entry) {
        bump("apps", entry.id);
        if (entry.runInTerminal)
            Term.open(entry.command);
        else
            // не entry.execute(): он отдаёт окружение qs, а тот мог стартовать до включения тем (QT_QPA_PLATFORMTHEME)
            Quickshell.execDetached({
                command: entry.command,
                workingDirectory: entry.workingDirectory || Quickshell.env("HOME"),
                environment: Settings.appEnv()
            });
    }

    // ── частота: что запускали часто и недавно — выше ─────────────
    // ~/.local/state/ochre/launcher.json: { apps: { "<id .desktop>": {n, last} }, emoji: { "<символ>": {n, last} } }

    readonly property bool frequent: Settings.get("shell.launcher.frequent")
    property var usage: ({ apps: {}, emoji: {} })
    property bool usageLoaded: false

    // число запусков, каждый месяц давности вдвое легче
    function weight(kind, id) { return weightOf(usage[kind]?.[id]); }
    function weightOf(u) { return u ? u.n * Math.pow(0.5, Math.max(0, Date.now() - u.last) / (30 * 86400000)) : 0; }

    // прибавка к счёту поиска: заметная при равенстве, но точное имя всё равно выше
    function freqBonus(w) { return frequent && w > 0 ? Math.min(Math.log2(1 + w) * 2, 8) : 0; }

    function bump(kind, id) {
        if (!usageLoaded || Settings.greeterMode || !id) return;
        let k = Object.assign({}, usage[kind] ?? {});
        k[id] = { n: (k[id]?.n ?? 0) + 1, last: Date.now() };
        // не копить бесконечно: 300 самых весомых
        const ids = Object.keys(k);
        if (ids.length > 300) {
            const all = k;
            k = {};
            for (const i of ids.sort((a, b) => weightOf(all[b]) - weightOf(all[a])).slice(0, 300)) k[i] = all[i];
        }
        usage = Object.assign({}, usage, { [kind]: k });
        usageFile.setText(JSON.stringify(usage));
    }

    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/ochre/launcher.json"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.usage = { apps: d.apps ?? {}, emoji: d.emoji ?? {} };
            } catch (e) {}
            root.usageLoaded = true;
        }
        onLoadFailed: root.usageLoaded = true
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/ochre"])

    // ── префиксы запроса в корне (look/ → меню; пусто — выключен) ──

    readonly property var prefixes: [
        { kind: "cmd", p: Settings.get("shell.launcher.prefix.cmd") },
        { kind: "files", p: Settings.get("shell.launcher.prefix.files") },
        { kind: "web", p: Settings.get("shell.launcher.prefix.web") },
        { kind: "emoji", p: Settings.get("shell.launcher.prefix.emoji") },
        { kind: "windows", p: Settings.get("shell.launcher.prefix.windows") },
        { kind: "install", p: Settings.get("shell.launcher.prefix.install") },
        { kind: "remove", p: Settings.get("shell.launcher.prefix.remove") },
        { kind: "timer", p: Settings.get("shell.launcher.prefix.timer") },
        { kind: "calc", p: Settings.get("shell.launcher.prefix.calc") },
        { kind: "ai", p: Settings.get("shell.launcher.prefix.ai") }
    ].map(x => ({ kind: x.kind, p: String(x.p ?? "").trim() })).filter(x => x.p)
     .sort((a, b) => b.p.length - a.p.length)   // «>>» раньше «>», если заданы оба

    function prefixOf(kind) { return prefixes.find(x => x.kind === kind)?.p ?? ""; }

    // ── веб-поиск ──

    function webUrl(q) {
        return S.webUrl(Settings.get("shell.launcher.web"), Settings.get("shell.launcher.web.url"), q);
    }

    // ── файлы: fd по имени, нечётко (буквы запроса по порядку) ──

    readonly property string filesDir: {
        const d = String(Settings.get("shell.launcher.files.dir") || "~");
        return d.replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/\/+$/, "") || "/";
    }
    property var fileHits: []          // null — ищем
    property string fileQuery: ""
    property int fileSeq: 0

    function findFiles(q) {
        fileQuery = q;
        fileSeq++;
        fileHits = q ? null : [];
        if (q) fileTimer.restart(); else fileTimer.stop();
    }

    Timer {
        id: fileTimer
        interval: 120
        onTriggered: {
            // fd ищет по имени, не по пути: «/» в образце он не принимает
            const re = Array.from(root.fileQuery.replace(/[\s\/]+/g, ""))
                .map(c => c.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*");
            if (!re) { root.fileHits = []; return; }
            fdProc.createObject(root, {
                seq: root.fileSeq,
                command: ["fd", "--base-directory", root.filesDir, "--color", "never", "-i", "--max-results", "1500", "--", re],
                running: true
            });
        }
    }

    Component {
        id: fdProc

        Process {
            id: proc

            property int seq
            property int done: 0
            function finish() { if (++done === 2) proc.destroy(); }

            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.seq === root.fileSeq)
                        root.fileHits = this.text.split("\n").filter(l => l).map(l => {
                            const dir = l.endsWith("/");
                            const p = dir ? l.slice(0, -1) : l;
                            const i = p.lastIndexOf("/");
                            return { label: p.slice(i + 1), path: p.slice(0, i + 1), dir, file: true,
                                     run: () => root.spawn(["xdg-open", root.filesDir + "/" + p]) };
                        });
                    proc.finish();
                }
            }
            onExited: (code) => {
                // fd не установлен или каталога нет — пустой список, а не вечная «загрузка…»
                if (code !== 0 && proc.seq === root.fileSeq && root.fileHits === null) root.fileHits = [];
                proc.finish();
            }
        }
    }

    // ── эмодзи: services/emoji.js (extras/emoji-gen.py) ──

    readonly property var emojiList: Emoji.LIST.split("\n").map(l => {
        const i = l.indexOf("\t");
        return { ch: l.slice(0, i), name: l.slice(i + 1) };
    })

    // ── дерево меню ────────────────────────────────────────────────
    // Меню — для действий; всё, что настраивается, — в окне настроек (settings, Mod+S).
    // узел: { label, desc, icon, children | provider | run }
    //   alias — синонимы, ищутся как имя; confirm — запуск только со второго ↵

    readonly property var icons: ({
        apps: String.fromCodePoint(0xF003B),
        wallpaper: String.fromCodePoint(0xF03D8),
        settings: String.fromCodePoint(0xF0493),
        system: String.fromCodePoint(0xF0425),
        about: String.fromCodePoint(0xF02FD)
    })

    readonly property var menu: ({
        label: "~",
        children: [
            { label: "apps", icon: icons.apps, desc: I18n.tr("запуск программ (Mod+Space)"), provider: "apps" },
            { label: "wallpaper", icon: icons.wallpaper, desc: I18n.tr("обои; Tab — wallhaven (Mod+Shift+W)"), alias: [I18n.tr("обои")], run: () => openPicker("local") },
            // пауза — чтобы закрывающееся меню не попало в замороженный кадр
            { label: "settings", icon: icons.settings, desc: I18n.tr("все настройки, мониторы, сеть, звук (Mod+S)"), alias: ["setup", I18n.tr("настройки")], run: () => Settings.show("") },
            { label: "system", icon: icons.system, desc: I18n.tr("питание и сессия"), children: [
                { label: "lock", desc: I18n.tr("заблокировать экран (Super+Alt+L)"), alias: [I18n.tr("блокировка")], run: () => Ochre.ipc("lock", "lock") },
                { label: "suspend", desc: I18n.tr("заблокировать и уснуть"), alias: ["sleep", I18n.tr("сон")], run: () => spawn(["sh", "-c", '"$@"; sleep 0.5; systemctl suspend', "sh", ...Ochre.ipcArgv(["lock", "lock"])]) },
                { label: "logout", desc: I18n.tr("выйти из niri"), alias: [I18n.tr("выход")], confirm: true, run: () => spawn(["niri", "msg", "action", "quit", "--skip-confirmation"]) },
                { label: "reboot", desc: I18n.tr("перезагрузка"), alias: ["restart"], confirm: true, run: () => spawn(["systemctl", "reboot"]) },
                { label: "poweroff", desc: I18n.tr("выключение"), alias: ["shutdown", I18n.tr("выключить")], confirm: true, run: () => spawn(["systemctl", "poweroff"]) }
            ] },
            { label: "about", icon: icons.about, desc: I18n.tr("о системе: fastfetch"), run: () => Term.fastfetch() },
            { label: "help", icon: icons.about, desc: I18n.tr("главные клавиши и подсказки (ochre --help)"), alias: [I18n.tr("помощь"), I18n.tr("справка"), I18n.tr("клавиши")], run: () => Ochre.ipc("welcome", "open") }
        ]
    })

    // Дерево плоским списком для поиска из корня. trail — узлы над пунктом: вход в найденный
    // раздел кладёт их в стек, чтобы путь и Esc работали как при обычном переходе.
    function flatten(nodes, trail) {
        let out = [];
        for (const n of nodes) {
            const path = trail.map(t => t.label + "/").join("");
            // search — с путём: «sys reb» находит system/reboot
            out.push(trail.length ? Object.assign({}, n, { trail, path, search: path + n.label + " " + (n.desc ?? "") }) : n);
            if (n.children) out = out.concat(flatten(n.children, trail.concat([n])));
        }
        return out;
    }

    // ── источники динамических списков ─────────────────────────────

    property var cache: ({})

    onOpenChanged: if (open) cache = {}   // после install/remove списки устаревают

    function providerItems(name, query) {
        if (name === "apps")
            // частые — сверху (вес из usage), остальные по алфавиту
            return DesktopEntries.applications.values
                .filter(e => !e.noDisplay)
                .map(e => ({ e, w: frequent ? weight("apps", e.id) : 0 }))
                .sort((a, b) => (b.w - a.w) || a.e.name.localeCompare(b.e.name))
                .map(({ e, w }) => ({
                    label: e.name,
                    desc: e.genericName,
                    app: true,
                    freq: w,
                    search: [e.genericName, e.comment, ...e.keywords].join(" "),
                    run: () => launchApp(e)
                }));
        if (name === "windows") {
            const ws = {};
            for (const w of Niri.workspaces) ws[w.id] = w;
            const ts = w => (w.focus_timestamp?.secs ?? 0) + (w.focus_timestamp?.nanos ?? 0) / 1e9;
            // недавние сверху, текущее окно — в конце (переходить к нему незачем)
            return Object.values(Niri.windows)
                .sort((a, b) => (a.is_focused - b.is_focused) || (ts(b) - ts(a)))
                .map(w => {
                    const s = ws[w.workspace_id];
                    return {
                        label: w.title || w.app_id || "?",
                        desc: (w.app_id ?? "") + (s ? " · " + (Quickshell.screens.length > 1 ? s.output + " " : "") + "ws " + s.idx : "")
                            + (w.is_focused ? I18n.tr(" · текущее") : ""),
                        search: w.app_id ?? "",
                        run: () => Niri.action("focus-window", "--id", String(w.id))
                    };
                });
        }
        if (name === "install") {
            // сверху всегда: без запроса — обновление системы, с запросом — поиск в AUR
            const head = query
                ? { label: "paru " + query, desc: I18n.tr("найти и установить из AUR"), pin: true, run: () => term("paru " + shq(query)) }
                : { label: "update", desc: Updates.count > 0 ? I18n.tr("обновить систему: paru -Syu — доступно %1", Updates.count) : I18n.tr("обновить систему: paru -Syu"), pin: true, run: () => Updates.run() };
            return cache.install ? [head].concat(cache.install) : null;
        }
        if (name === "timer") {
            const p = query ? Countdown.parseSpec(query) : null;
            const stop = { label: "stop", desc: I18n.tr("остановить таймер"), pin: true, run: () => Countdown.stop() };
            if (p)
                return [{ label: "timer " + Countdown.fmt(p.sec) + (p.label ? " " + p.label : ""), pin: true,
                          desc: Countdown.active ? I18n.tr("↵ — запустить таймер (текущий заменится)") : I18n.tr("↵ — запустить таймер"),
                          run: () => Countdown.start(p.sec, p.label) }].concat(Countdown.active ? [stop] : []);
            if (/^(stop|стоп)$/i.test(query))
                return [stop];
            if (query)
                return [{ label: prefixOf("timer") + query, desc: I18n.tr("не понял длительность: 25m, 1h30m, 90s, 5:00"), pin: true }];
            return ["5m", "10m", "15m", "25m", "45m", "1h"].map(t => ({ label: t, desc: I18n.tr("запустить на %1", Countdown.fmt(Countdown.parse(t))), pin: true,
                    run: () => Countdown.start(Countdown.parse(t), "") })).concat(Countdown.active ? [stop] : []);
        }
        if (name === "cmd")
            return query ? [{ label: prefixOf("cmd") + " " + query, desc: I18n.tr("↵ — выполнить в терминале"), pin: true, run: () => term(query) }]
                : [{ label: prefixOf("cmd"), desc: I18n.tr("команда для терминала, например htop"), pin: true }];
        if (name === "web")
            return query ? [{ label: query, desc: I18n.tr("↵ — искать: %1", Settings.get("shell.launcher.web")), pin: true, run: () => spawn(["xdg-open", webUrl(query)]) }]
                : [{ label: prefixOf("web"), desc: I18n.tr("что искать в интернете"), pin: true }];
        if (name === "ai" && Settings.get("shell.launcher.ai") === "google")
            return query ? [{ label: prefixOf("ai") + " " + query, desc: I18n.tr("↵ — спросить Google AI"), pin: true,
                              run: () => spawn(["xdg-open", "https://www.google.com/search?udm=50&q=" + encodeURIComponent(query)]) }]
                : [{ label: prefixOf("ai"), desc: I18n.tr("вопрос для Google AI Mode"), pin: true }];
        if (name === "ai")
            return query ? [{ label: prefixOf("ai") + " " + query, desc: I18n.tr("↵ — спросить в Claude Code"), pin: true, run: () => ai([query]) }]
                : [{ label: "new", desc: I18n.tr("новая сессия Claude Code"), pin: true, run: () => ai([]) },
                   { label: "continue", desc: I18n.tr("продолжить последнюю сессию"), pin: true, run: () => ai(["--continue"]) }];
        if (name === "files")
            return query ? fileHits : [];
        if (name === "emoji")
            return emojiList
                .map(x => ({ x, w: weight("emoji", x.ch) }))
                .sort((a, b) => b.w - a.w)   // sort стабильный: остальные — в порядке Unicode
                .map(({ x, w }) => ({
                    label: x.name,
                    icon: x.ch,
                    freq: w,
                    run: () => { bump("emoji", x.ch); spawn(["wl-copy", "--", x.ch]); }
                }));
        return cache[name] ?? null; // null — ещё загружается
    }

    function load(name) {
        if (!["install", "remove"].includes(name) || cache[name] || pkgProc.running) return;
        pkgProc.target = name;
        pkgProc.command = name === "install" ? ["pacman", "-Sl"] : ["pacman", "-Qe"];
        pkgProc.running = true;
    }

    Process {
        id: pkgProc

        property string target

        stdout: StdioCollector {
            onStreamFinished: {
                const items = [];
                for (const line of this.text.split("\n")) {
                    const f = line.split(" ");
                    if (pkgProc.target === "install" && f.length >= 3) {
                        const [repo, name, ver] = f;
                        items.push({ label: name, desc: repo + " " + ver + (f[3] ? "  [installed]" : ""), run: () => root.term("paru -S " + name) });
                    } else if (pkgProc.target === "remove" && f.length >= 2) {
                        const [name, ver] = f;
                        items.push({ label: name, desc: ver, run: () => root.term("sudo pacman -Rns " + name) });
                    }
                }
                root.cache = Object.assign({}, root.cache, { [pkgProc.target]: items });
            }
        }
    }

    // ── окно ───────────────────────────────────────────────────────

    LazyLoader {
        active: reveal.loaded

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "ochre-launcher"

            property var stack: []
            // глубина, с которой меню открыли: выше неё Esc не поднимается, а закрывает окно
            property int base: 1
            readonly property var node: stack[stack.length - 1] ?? null
            readonly property string path: "~/" + stack.slice(1).map(n => n.label + "/").join("")
            readonly property string query: input.text.trim()
            // префикс в корне (> cmd, /файл, @окно, +пакет …) — как вход в раздел с остатком запроса;
            // в остальных разделах — только калькулятор
            readonly property var prefixHit: {
                const top = node === root.menu;
                for (const x of root.prefixes)
                    if ((top || x.kind === "calc") && query.startsWith(x.p))
                        return { kind: x.kind, rest: query.slice(x.p.length).trim() };
                return null;
            }
            readonly property bool calcMode: prefixHit?.kind === "calc"
            readonly property string provider: prefixHit && !calcMode ? prefixHit.kind : (node?.provider ?? "")
            readonly property string pquery: prefixHit && !calcMode ? prefixHit.rest : query
            // запрос в корне ищет по меню и программам; окна, файлы, пакеты … — только префиксом
            readonly property bool searchAll: node === root.menu && query !== "" && !prefixHit
            readonly property var everything: root.flatten(root.menu.children, []).concat(root.providerItems("apps"))
            readonly property var items: !node ? [] : searchAll ? everything
                : provider ? root.providerItems(provider, pquery) : (node.children ?? [])

            onProviderChanged: { root.findFiles(provider === "files" ? pquery : ""); root.load(provider); }
            onPqueryChanged: if (provider === "files") root.findFiles(pquery)

            // пункт с confirm, по которому уже нажали ↵ один раз (ключ path + label)
            property string armed: ""

            function keyOf(it) { return (it.path ?? "") + it.label; }

            readonly property var calc: {
                if (!calcMode) return null;
                const r = Calc.evaluate(prefixHit.rest);
                if (r.value !== undefined)
                    return { label: "= " + r.value, desc: I18n.tr("↵ — скопировать"), run: () => root.spawn(["wl-copy", "--", r.value]) };
                return { label: root.prefixOf("calc"), desc: I18n.tr(r.error, r.arg ?? "") || "+ - * / % ^ ( )  sqrt ln log sin cos …  pi e" };
            }

            readonly property var results: {
                if (calc) return [{ item: calc, pos: [] }];
                if (!items) return [];
                const q = pquery;
                if (!q) return items.map(it => ({ item: it, pos: [] }));
                // pin — служебные строки (AUR, команда, таймер): всегда сверху и без фильтра
                const pinned = items.filter(it => it.pin).map(it => ({ item: it, pos: [] }));
                const out = [];
                for (const it of items) {
                    if (it.pin) continue;
                    // в общем поиске при равенстве действия меню выше программ;
                    // часто запускаемое — выше редкого
                    const bonus = (searchAll ? (it.app ? 0 : 3) : 0) + root.freqBonus(it.freq ?? 0);
                    let byName = Fuzzy.match(q, it.label);
                    // синоним совпал лучше имени — счёт его, подсветки нет
                    for (const a of it.alias ?? []) {
                        const m = Fuzzy.match(q, a);
                        if (m && (!byName || m.score > byName.score)) byName = { score: m.score, pos: [] };
                    }
                    const byExtra = Fuzzy.match(q, it.search ?? it.desc ?? "");
                    const nameScore = byName ? byName.score + 5 + bonus : -Infinity;
                    const extraScore = byExtra ? byExtra.score * 0.8 + bonus : -Infinity;
                    if (byName && nameScore >= extraScore)
                        out.push({ item: it, pos: byName.pos, score: nameScore });
                    else if (byExtra)
                        out.push({ item: it, pos: [], score: extraScore });
                }
                // при равном счёте — более короткое имя выше (neovim раньше neovim-qt)
                return pinned.concat(out.sort((a, b) => (b.score - a.score) || (a.item.label.length - b.item.label.length)));
            }

            function reset() {
                const s = [root.menu];
                const start = root.menu.children.find(c => c.label === root.startAt);
                if (start) s.push(start);
                stack = s;
                base = s.length;
                input.text = "";
            }

            Component.onCompleted: reset()

            // открыли снова, пока доигрывало закрытие: окно то же — начать с начала
            Connections {
                target: root
                function onOpenChanged() { if (root.open) win.reset(); }
            }

            onResultsChanged: { list.currentIndex = 0; armed = ""; }

            function enter(it) {
                if (it.children || it.provider) {
                    stack = stack.concat(it.trail ?? [], [it]);
                    input.text = "";
                } else if (!it.run) {
                    // строка калькулятора с ошибкой: запускать нечего
                } else if (it.confirm && armed !== keyOf(it)) {
                    armed = keyOf(it);
                } else {
                    it.run();
                    root.open = false;
                }
            }

            function back() {
                if (stack.length > base) {
                    stack = stack.slice(0, -1);
                    input.text = "";
                } else {
                    root.open = false;
                }
            }

            property point lastMouse
            property bool lastMouseSet: false

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            // на уровень выше — кнопкой ‹, кликом по пути в заголовке или боковой кнопкой мыши «назад»
            function up(depth) {
                if (depth < base) { root.open = false; return; }
                stack = stack.slice(0, depth);
                input.text = "";
                input.forceActiveFocus();
            }

            // клик мимо окна закрывает меню
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.BackButton
                onClicked: mouse => mouse.button === Qt.BackButton ? win.back() : root.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: cell.advanceWidth * 64 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2
                opacity: reveal.alpha
                scale: reveal.zoom
                transform: [
                    Translate { y: reveal.dy },
                    Scale { origin.y: -title.height / 2; yScale: reveal.ys }
                ]

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.BackButton
                    onClicked: win.back()
                }

                // заголовок на линии рамки: ┌─[ ~/system/ ]──── — каждый уровень пути кликается
                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    Row {
                        id: title
                        T { text: "[ "; color: Theme.accent; font.bold: true }
                        Repeater {
                            model: win.stack.length
                            T {
                                required property int index
                                readonly property bool last: index === win.stack.length - 1
                                readonly property bool can: !last && index + 1 >= win.base
                                text: (index === 0 ? "~" : win.stack[index].label) + "/"
                                color: can && crumb.containsMouse ? Theme.fg : Theme.accent
                                font.bold: true
                                font.underline: can && crumb.containsMouse
                                MouseArea {
                                    id: crumb
                                    anchors.fill: parent
                                    enabled: parent.can
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.up(parent.index + 1)
                                }
                            }
                        }
                        T { text: " ]"; color: Theme.accent; font.bold: true }
                    }
                }

                ColumnLayout {
                    id: col

                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        // ‹ — на уровень выше (на нижней границе — закрыть)
                        T {
                            visible: win.stack.length > win.base
                            font.family: Theme.iconFont
                            text: String.fromCodePoint(0xF0141) + " "
                            color: backHover.containsMouse ? Theme.accent : Theme.gray
                            MouseArea { id: backHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.back() }
                        }
                        T { text: "❯ "; color: Theme.accent; font.bold: true }

                        TextInput {
                            id: input

                            Layout.fillWidth: true
                            focus: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            selectionColor: Theme.bg2
                            renderType: Text.NativeRendering

                            cursorDelegate: Rectangle {
                                id: caret
                                width: cell.advanceWidth
                                color: Theme.fg
                                Timer {
                                    interval: 530
                                    running: true
                                    repeat: true
                                    onTriggered: caret.opacity = caret.opacity > 0 ? 0 : 1
                                }
                            }

                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier;
                                const empty = input.text.length === 0;
                                const cur = win.results[list.currentIndex];
                                if (event.key === Qt.Key_Escape) {
                                    win.back();
                                } else if (empty && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) && win.stack.length > win.base) {
                                    win.back();
                                } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                    list.incrementCurrentIndex();
                                } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                    list.decrementCurrentIndex();
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (cur) win.enter(cur.item);
                                } else if (event.key === Qt.Key_Right && cur && (cur.item.children || cur.item.provider)) {
                                    win.enter(cur.item);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        T {
                            text: win.calcMode ? "calc" : win.items === null ? I18n.tr("загрузка…") : (win.prefixHit ? win.provider + " " : "") + win.results.length + "/" + win.items.length
                            color: Theme.gray
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        implicitHeight: cell.height * 1.5 * root.rows
                        clip: true
                        model: win.results
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds
                        onCurrentIndexChanged: win.armed = ""

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property var item: modelData.item
                            readonly property bool isDir: !!(item.children || item.provider || item.dir)
                            readonly property bool current: ListView.isCurrentItem
                            readonly property bool armed: win.armed !== "" && win.armed === win.keyOf(item)

                            width: list.width
                            height: cell.height * 1.5
                            color: current ? Theme.bg1 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                T {
                                    text: row.current ? "▌ " : "  "
                                    color: Theme.accent
                                }
                                T {
                                    visible: !!row.item.icon
                                    text: (row.item.icon ?? "") + " "
                                    color: row.current ? Theme.accent : Theme.gray
                                }
                                // где пункт лежит в меню — при поиске из корня
                                T {
                                    visible: !!row.item.path
                                    text: row.item.path ?? ""
                                    color: Theme.gray
                                }
                                // разделы — как каталоги в ls: синие и со слешем
                                T {
                                    textFormat: Text.StyledText
                                    text: Fuzzy.highlight(row.item.label, row.modelData.pos, Theme.orange) + (row.isDir ? "/" : "")
                                    color: row.isDir ? Theme.blue : row.current ? Theme.fg : Theme.fgDim
                                    font.bold: row.current
                                }
                                T {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: row.armed ? I18n.tr("  точно? ↵") : row.item.desc ? "  " + row.item.desc : ""
                                    color: row.armed ? Theme.red : Theme.gray
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                // Qt шлёт hover-события и когда строка проезжает под неподвижным курсором,
                                // поэтому выделяем только при реальном сдвиге мыши
                                onPositionChanged: mouse => {
                                    const p = mapToGlobal(mouse.x, mouse.y);
                                    if (win.lastMouseSet && (p.x !== win.lastMouse.x || p.y !== win.lastMouse.y))
                                        list.currentIndex = row.index;
                                    win.lastMouse = p;
                                    win.lastMouseSet = true;
                                }
                                onClicked: win.enter(row.item)
                            }
                        }
                    }
                }
            }

            TypeOn {
                anchors.fill: parent
                source: box
                margin: title.height / 2
                p: reveal.p
                active: reveal.printing
            }
        }
    }
}
