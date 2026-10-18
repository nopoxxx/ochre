import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy
import "services/calc.js" as Calc

// Меню в духе omarchy: сначала раздел (apps/, packages/, system/ …), потом действие.
// Разделы ведут себя как каталоги: путь в заголовке, Esc или ← — на уровень выше
// (но не выше раздела, в котором меню открыли: там Esc закрывает окно).
//   qs ipc call launcher toggle — корень меню
// Запрос в корне ищет по всему меню сразу: программы и вложенные действия (system/reboot).
// «=выражение» — калькулятор, ↵ копирует ответ.
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

    // fastfetch с конфигом ochre и акцентом shell; окно закрывается по Enter
    function about() {
        const c = Theme.accent;
        const ansi = "38;2;" + [c.r, c.g, c.b].map(x => Math.round(x * 255)).join(";");
        Term.float(["bash", "-c",
            'printf "\\e[?25l"; fastfetch -c "$1" --logo-type file --logo "$3" --logo-color-1 "$2" --logo-color-2 "$2"; printf "\\n  \\e[90m↵ — закрыть\\e[0m"; read -rs',
            "bash", Quickshell.shellDir + "/extras/fastfetch/config.jsonc", ansi, Quickshell.shellDir + "/extras/fastfetch/ochre-large.txt"]);
    }

    function openPicker(source) {
        Wallpaper.pickerSource = source;
        Wallpaper.pickerOpen = true;
    }

    function launchApp(entry) {
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

    // ── дерево меню ────────────────────────────────────────────────
    // Меню — для действий; всё, что настраивается, — в окне настроек (setup, Mod+S).
    // узел: { label, desc, icon, children | provider | run }
    //   alias — синонимы, ищутся как имя; confirm — запуск только со второго ↵

    readonly property var icons: ({
        apps: String.fromCodePoint(0xF003B),
        wallpaper: String.fromCodePoint(0xF03D8),
        setup: String.fromCodePoint(0xF0493),
        packages: String.fromCodePoint(0xF03D7),
        system: String.fromCodePoint(0xF0425),
        about: String.fromCodePoint(0xF02FD),
        shot: String.fromCodePoint(0xF0100),
        timer: String.fromCodePoint(0xF051B)
    })

    readonly property var menu: ({
        label: "~",
        children: [
            { label: "apps", icon: icons.apps, desc: "запуск программ (Mod+Space)", provider: "apps" },
            { label: "wallpaper", icon: icons.wallpaper, desc: "обои; Tab — wallhaven (Mod+Shift+W)", alias: ["обои"], run: () => openPicker("local") },
            // пауза — чтобы закрывающееся меню не попало в замороженный кадр
            { label: "screenshot", icon: icons.shot, desc: "снимок с разметкой (Mod+Shift+S); w — окно", alias: ["скриншот", "снимок"], run: () => spawn(["sh", "-c", 'sleep 0.3; exec "$@"', "sh", ...Ochre.ipcArgv(["shot", "region"])]) },
            { label: "setup", icon: icons.setup, desc: "все настройки, мониторы, сеть, звук (Mod+S)", alias: ["settings", "настройки"], run: () => Settings.show("") },
            // описания без Countdown.left: привязка пересоздавала бы menu каждую секунду, а узлы сравниваются по ссылке
            { label: "timer", icon: icons.timer, desc: "таймер; любой срок — запросом в корне: timer 25m чай",
              alias: ["таймер"], children: [
                ...["5m", "10m", "15m", "25m", "45m", "1h"].map(t => ({ label: t, desc: "запустить на " + Countdown.fmt(Countdown.parse(t)),
                    run: () => Countdown.start(Countdown.parse(t), "") })),
                { label: "stop", desc: "остановить таймер", alias: ["стоп"], run: () => Countdown.stop() }
            ] },
            { label: "packages", icon: icons.packages, desc: "установить, удалить, обновить", children: [
                { label: "install", desc: "из репозиториев pacman", provider: "repo" },
                { label: "aur", desc: "поиск в AUR через paru", provider: "aur" },
                { label: "remove", desc: "удалить установленные", provider: "installed" },
                { label: "update", desc: "обновить систему: paru -Syu" + (Updates.count > 0 ? " — доступно " + Updates.count : ""), alias: ["upgrade", "обновить"], run: () => Updates.run() }
            ] },
            { label: "system", icon: icons.system, desc: "питание и сессия", children: [
                { label: "lock", desc: "заблокировать экран (Super+Alt+L)", alias: ["блокировка"], run: () => Ochre.ipc("lock", "lock") },
                { label: "suspend", desc: "заблокировать и уснуть", alias: ["sleep", "сон"], run: () => spawn(["sh", "-c", '"$@"; sleep 0.5; systemctl suspend', "sh", ...Ochre.ipcArgv(["lock", "lock"])]) },
                { label: "logout", desc: "выйти из niri", alias: ["выход"], confirm: true, run: () => spawn(["niri", "msg", "action", "quit", "--skip-confirmation"]) },
                { label: "reboot", desc: "перезагрузка", alias: ["restart"], confirm: true, run: () => spawn(["systemctl", "reboot"]) },
                { label: "poweroff", desc: "выключение", alias: ["shutdown", "выключить"], confirm: true, run: () => spawn(["systemctl", "poweroff"]) }
            ] },
            { label: "about", icon: icons.about, desc: "о системе: fastfetch", run: () => about() },
            { label: "help", icon: icons.about, desc: "главные клавиши и подсказки (ochre --help)", alias: ["помощь", "справка", "клавиши"], run: () => Ochre.ipc("welcome", "open") }
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
            return DesktopEntries.applications.values
                .filter(e => !e.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name))
                .map(e => ({
                    label: e.name,
                    desc: e.genericName,
                    app: true,
                    search: [e.genericName, e.comment, ...e.keywords].join(" "),
                    run: () => launchApp(e)
                }));
        if (name === "aur")
            return query ? [{ label: "paru " + query, desc: "найти и установить из AUR", run: () => term("paru " + shq(query)) }] : [];
        return cache[name] ?? null; // null — ещё загружается
    }

    function load(name) {
        if (!["repo", "installed"].includes(name) || cache[name] || pkgProc.running) return;
        pkgProc.target = name;
        pkgProc.command = name === "repo" ? ["pacman", "-Sl"] : ["pacman", "-Qe"];
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
                    if (pkgProc.target === "repo" && f.length >= 3) {
                        const [repo, name, ver] = f;
                        items.push({ label: name, desc: repo + " " + ver + (f[3] ? "  [installed]" : ""), run: () => root.term("paru -S " + name) });
                    } else if (pkgProc.target === "installed" && f.length >= 2) {
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
            // в списках пакетов «=» — часть запроса, калькулятор там не нужен
            readonly property bool calcMode: query.startsWith("=") && !["aur", "repo", "installed"].includes(node?.provider)
            // запрос в корне ищет по всему меню (кроме списков пакетов: их тысячи)
            readonly property bool searchAll: node === root.menu && query !== ""
            readonly property var everything: root.flatten(root.menu.children, []).concat(root.providerItems("apps"))
            readonly property var items: !node ? [] : searchAll ? everything : (node.children ?? root.providerItems(node.provider, query))

            // пункт с confirm, по которому уже нажали ↵ один раз (ключ path + label)
            property string armed: ""

            function keyOf(it) { return (it.path ?? "") + it.label; }

            readonly property var calc: {
                if (!calcMode) return null;
                const r = Calc.evaluate(query.slice(1));
                if (r.value !== undefined)
                    return { label: "= " + r.value, desc: "↵ — скопировать", run: () => root.spawn(["wl-copy", "--", r.value]) };
                return { label: "=", desc: r.error || "+ - * / % ^ ( )  sqrt ln log sin cos …  pi e" };
            }

            // «timer 25m чай» в корне меню — запустить таймер (services/Countdown.qml)
            readonly property var timerItem: {
                const m = node === root.menu ? query.match(/^(?:timer|таймер)\s+(.+)$/i) : null;
                const p = m ? Countdown.parseSpec(m[1]) : null;
                if (!p) return null;
                return { label: "timer " + Countdown.fmt(p.sec) + (p.label ? " " + p.label : ""),
                         desc: "↵ — запустить таймер" + (Countdown.active ? " (текущий заменится)" : ""),
                         run: () => Countdown.start(p.sec, p.label) };
            }

            readonly property var results: {
                if (calc) return [{ item: calc, pos: [] }];
                if (timerItem) return [{ item: timerItem, pos: [] }];
                if (!items) return [];
                const q = query;
                if (!q || node.provider === "aur") return items.map(it => ({ item: it, pos: [] }));
                const out = [];
                for (const it of items) {
                    // в общем поиске при равенстве действия меню выше программ
                    const bonus = searchAll && !it.app ? 3 : 0;
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
                return out.sort((a, b) => (b.score - a.score) || (a.item.label.length - b.item.label.length));
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

            onNodeChanged: if (node?.provider) root.load(node.provider)
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

                // заголовок на линии рамки: ┌─[ ~/packages/install/ ]──── — каждый уровень пути кликается
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
                            text: win.calcMode ? "calc" : win.items === null ? "загрузка…" : win.results.length + "/" + win.items.length
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
                            readonly property bool isDir: !!(item.children || item.provider)
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
                                    color: row.isDir ? Theme.blue : row.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                    font.bold: row.current
                                }
                                T {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: row.armed ? "  точно? ↵" : row.item.desc ? "  " + row.item.desc : ""
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
