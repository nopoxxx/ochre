pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Ошибки shell и niri — для окна ErrorsWindow (как лог компилятора).
// Shell: `qs log -f` своего экземпляра — ошибки выполнения (`WARN scene: @файл[строка:столбец]: TypeError…`) и
// неудачная перезагрузка конфига (`ERROR: caused by @…`; старый shell при этом продолжает работать).
// Лог читается с начала, поэтому строка «Reloading configuration...» очищает список: ошибки старого кода больше не нужны.
// niri: событие ConfigLoaded с failed — текст ошибки берётся из `niri validate`.
// Настройка shell.errors (system/ → ochre). IPC: errors open | clear | get (не show — его занимает qs ipc show).
Singleton {
    id: root

    readonly property bool enabled: Settings.get("shell.errors") && !Settings.greeterMode
    // {key, src: qs|niri, file, line, text, count}; новые — в конце
    property var list: []
    property bool open: false
    property int seen: 0        // сколько ошибок было, когда окно закрыли: показываем снова только на новые

    readonly property int total: list.reduce((n, e) => n + e.count, 0)

    function add(src, file, line, text) {
        const key = src + "|" + file + "|" + line + "|" + text;
        const i = list.findIndex(e => e.key === key);
        if (i >= 0)
            list = list.map((e, j) => j === i ? Object.assign({}, e, { count: e.count + 1 }) : e);
        else
            list = list.concat([{ key, src, file, line, text, count: 1 }]).slice(-50);
        if (enabled && total > seen) open = true;
    }

    function clearSrc(src) {
        list = list.filter(e => e.src !== src);
        seen = Math.min(seen, total);
        if (!list.length) open = false;
    }

    function close() {
        open = false;
        seen = total;
    }

    function clear() {
        list = [];
        seen = 0;
        open = false;
    }

    function asText() {
        return list.map(e => (e.file ? e.file + (e.line ? ":" + e.line : "") + ": " : e.src + ": ") + e.text
            + (e.count > 1 ? " (×" + e.count + ")" : "")).join("\n");
    }

    function copy() {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | wl-copy', "sh", asText()]);
    }

    // своё окно вместо встроенного попапа Quickshell о неудачной перезагрузке — чтобы не было двух
    Component.onCompleted: if (enabled) Quickshell.inhibitReloadPopup()

    // ── shell ──
    function parse(raw) {
        const line = raw.replace(/\x1b\[[0-9;]*m/g, "");
        if (/^\s*INFO: Reloading configuration/.test(line)) { clearSrc("qs"); return; }
        // @services/Privacy.qml[42:7]: TypeError: … — у ошибок загрузки перед ним «caused by»
        let m = line.match(/^\s*(?:WARN scene|ERROR):\s+(?:caused by )?@([^\[\s]+)\[(\d+):-?\d+\]: (.*)$/);
        if (m) { add("qs", m[1], +m[2], m[3]); return; }
        m = line.match(/^\s*ERROR: (?!Failed to load configuration|\s*caused by)(.*)$/);
        if (m && !/crash|restarted/i.test(m[1])) add("qs", "", 0, m[1]);
    }

    Process {
        running: !Settings.greeterMode
        // $PPID у sh — сам qs: читаем лог именно этого экземпляра, даже если запущено два
        command: ["sh", "-c", 'exec qs log -f --pid "$PPID"']
        stdout: SplitParser { onRead: line => root.parse(line) }
    }

    // ── niri ──
    Connections {
        target: Niri
        function onConfigFailedChanged() {
            if (!Niri.configFailed) root.clearSrc("niri");
            else if (!validate.running) validate.running = true;
        }
    }

    // вывод miette: блоки «Error: × текст», у нужного — «╭─[файл:строка:столбец]», строки исходника «N │ …»
    // и под ошибочной — «· ╰── пояснение». Берём последний блок с местом: он самый конкретный (внутри include).
    function parseNiri(text) {
        const blocks = text.split(/^Error:/m).map(b => b.split("\n")).filter(b => b.length && b[0].includes("×"));
        const b = blocks.filter(b => b.some(l => /╭─\[/.test(l))).pop() ?? blocks.pop() ?? [];
        let file = "config.kdl", line = 0, label = "", last = 0;
        for (const l of b) {
            let m = l.match(/╭─\[([^\]]+?):(\d+):\d+\]/);
            if (m) { file = m[1].replace(/^.*\/\.config\/niri\//, ""); line = +m[2]; continue; }
            m = l.match(/^\s*(\d+)\s│/);
            if (m) { last = +m[1]; continue; }
            m = l.match(/^\s*·.*╰──\s*(.*)$/);
            if (m && !label) { label = m[1].trim(); line = last || line; }
        }
        const title = (b[0] ?? "").replace(/^[\s×]+/, "").trim() || I18n.tr("конфиг не прошёл проверку");
        return { file, line, text: label && !title.toLowerCase().includes(label.toLowerCase()) ? title + " — " + label : title };
    }

    Process {
        id: validate
        command: ["niri", "validate"]
        stdout: StdioCollector { id: vOut }
        stderr: StdioCollector { id: vErr }
        onExited: code => {
            if (code === 0) return;
            const text = (vErr.text + vOut.text).replace(/\x1b\[[0-9;]*m/g, "");
            root.clearSrc("niri");
            const e = root.parseNiri(text);
            root.add("niri", e.file, e.line, e.text);
        }
    }

    IpcHandler {
        target: "errors"
        function open(): void { root.open = true; }
        function clear(): void { root.clear(); }
        function get(): string { return root.asText(); }
    }
}
