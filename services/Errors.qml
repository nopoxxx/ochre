pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Ошибки shell и niri — для окна ErrorsWindow (как лог компилятора).
// Shell: `qs log -f` своего экземпляра — ошибки выполнения (`WARN scene: @файл[строка:столбец]: TypeError…`) и
// неудачная перезагрузка конфига (`ERROR: caused by @…`; старый shell при этом продолжает работать).
// Лог читается с начала, поэтому строка «Reloading configuration...» очищает список: ошибки старого кода больше не нужны.
// niri: событие ConfigLoaded с failed — текст ошибки берётся из `niri validate`.
// Настройка shell.errors (system/ → ochre). IPC: errors open | clear | get | report (не show — его занимает qs ipc show).
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

    // ── сообщить о проблеме: архив логов и issue на GitHub с заполненным текстом; архив прикрепляют вручную ──
    readonly property string repo: "https://github.com/nopoxxx/ochre"
    property bool reporting: false

    function report() {
        if (reporter.running) return;
        const values = Object.assign({}, Settings.values);
        if (values["shell.weather.city"]) values["shell.weather.city"] = "…";
        reporting = true;
        reporter.command = ["sh", "-c", root.reportScript, "sh", asText(), Quickshell.shellDir, JSON.stringify(values, null, 2) + "\n"];
        reporter.running = true;
    }

    // URL у GitHub — не длиннее ~8 КБ: лишние строки ошибок отбрасываются с начала (новые — в конце)
    function issueUrl(versions, errors, archive) {
        const title = (errors[errors.length - 1] ?? "").replace(/\s+\(×\d+\)$/, "").slice(0, 100);
        const body = errs => "### " + I18n.tr("Что случилось") + "\n\n\n\n### " + I18n.tr("Как повторить") + "\n\n1. \n\n"
            + (errs.length ? "### " + I18n.tr("Ошибки") + "\n\n```\n" + errs.join("\n") + "\n```\n\n" : "")
            + "### " + I18n.tr("Версии") + "\n\n```\n" + versions.join("\n") + "\n```\n\n"
            + I18n.tr("Архив логов: перетащите сюда %1", "`" + archive + "`") + "\n";
        const url = errs => repo + "/issues/new?title=" + encodeURIComponent(title) + "&body=" + encodeURIComponent(body(errs));
        let errs = errors;
        while (errs.length && url(errs).length > 7500) errs = errs.slice(1);
        return url(errs);
    }

    // $1 — ошибки текстом, $2 — папка shell, $3 — settings.json; $PPID — сам qs.
    // Личное убирается из всех файлов: $HOME → ~, имя пользователя → user, имя машины → host
    readonly property string reportScript: `
        r=ochre-report-$(date +%Y%m%d-%H%M%S)
        d=$(mktemp -d) || exit 1
        w="$d/$r"
        mkdir "$w"
        {
            echo "ochre: $(git -C "$2" describe --always --dirty --tags 2>/dev/null || cat "$2/VERSION" 2>/dev/null || echo ?) ($2)"
            echo "quickshell: $(qs --version 2>&1 | head -1)"
            echo "niri: $(niri --version 2>&1 | head -1)"
            echo "os: $(. /etc/os-release 2>/dev/null; echo "\${PRETTY_NAME:-?}"), $(uname -r)"
            echo "session: \${XDG_CURRENT_DESKTOP:-?}, \${LANG:-?}"
        } > "$w/versions.txt"
        printf '%s\\n' "$1" > "$w/errors.txt"
        printf '%s' "$3" > "$w/settings.json"
        qs log --pid "$PPID" 2>&1 | sed 's/\\x1b\\[[0-9;]*m//g' | tail -n 5000 > "$w/qs.log"
        journalctl --user -b --no-pager -o short-iso _COMM=niri 2>&1 | tail -n 3000 > "$w/niri.log"
        niri validate > "$w/niri-validate.txt" 2>&1
        cp -r "$HOME/.config/niri/ochre" "$w/niri-ochre" 2>/dev/null
        esc() { printf '%s' "$1" | sed 's/[][\\.*^$/]/\\\\&/g'; }
        set -- -e "s/$(esc "$HOME")/~/g"
        u=$(id -un); [ \${#u} -ge 2 ] && set -- "$@" -e "s/\\\\b$(esc "$u")\\\\b/user/g"
        n=$(uname -n); [ \${#n} -ge 2 ] && set -- "$@" -e "s/\\\\b$(esc "$n")\\\\b/host/g"
        find "$w" -type f -exec sed -i "$@" {} +
        out=$(xdg-user-dir DOWNLOAD 2>/dev/null)
        [ -d "$out" ] || out=$HOME
        tar -czf "$out/$r.tar.gz" -C "$d" "$r" || { rm -rf "$d"; exit 1; }
        echo "A $out/$r.tar.gz"
        sed 's/^/V /' "$w/versions.txt"
        sed '/^$/d; s/^/E /' "$w/errors.txt"
        rm -rf "$d"`

    Process {
        id: reporter
        stdout: StdioCollector { id: reportOut }
        onExited: code => {
            root.reporting = false;
            const lines = reportOut.text.split("\n");
            const archive = (lines.find(l => l.startsWith("A ")) ?? "").slice(2);
            if (code !== 0 || !archive) {
                Quickshell.execDetached(["notify-send", "-a", "ochre", "-u", "critical", I18n.tr("Не удалось собрать архив логов"), I18n.tr("код %1", code)]);
                return;
            }
            const home = Quickshell.env("HOME");
            const shown = archive.startsWith(home + "/") ? "~" + archive.slice(home.length) : archive;
            const pick = p => lines.filter(l => l.startsWith(p)).map(l => l.slice(2));
            Quickshell.execDetached(["xdg-open", root.issueUrl(pick("V "), pick("E "), shown.split("/").pop())]);
            Quickshell.execDetached(["sh", "-c", 'a=$(notify-send -a ochre -A open="$2" "$3" "$4"); [ "$a" = open ] && xdg-open "$(dirname "$1")"',
                "sh", archive, I18n.tr("папка"), I18n.tr("Архив логов готов"), I18n.tr("%1 — перетащите его в окно issue", shown)]);
        }
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
        function report(): void { root.report(); }
    }
}
