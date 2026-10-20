pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Обновления самого ochre: если папка конфига — git-клон, периодически делает
// `git fetch` и сравнивает с upstream; update() — `git pull --ff-only` и перезапуск shell.
// Поставлен пакетом (Ochre.system) — обновляет pacman: раз в минуту сверяем VERSION и предлагаем перезапуск.
// Для приватного репозитория git должен уметь авторизоваться (например, `gh auth setup-git`).
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir
    property bool isRepo: false
    property bool checking: false
    property bool updating: false
    property bool dirty: false          // локальные правки — pull может не пройти
    property string upstream: ""
    property var commits: []            // [{ hash, subject }] — новые в upstream
    readonly property int behind: commits.length
    property string error: ""
    property bool updated: false        // уже обновились в этом запуске — напомнить про greeter
    // greeter настроен (его конфиг niri для greetd) — в том числе под старым именем nopox-shell
    readonly property bool greeterInstalled: greeterCheck.text().length > 0 || legacyGreeter.text().length > 0
    // копию greeter обновлять отдельно нужно только git-установке: у пакета greeter — те же файлы
    readonly property bool greeterSeparate: greeterInstalled && !Ochre.system
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/ochre"
    property string prevHead: ""

    // force — проверить, даже если автопроверка выключена в настройках
    function check(force) {
        if (checker.running || updating) return;
        if (!force && !Settings.get("shell.update.check")) return;
        checking = true;
        checker.running = true;
    }

    function update() {
        if (updater.running || behind === 0) return;
        updating = true;
        error = "";
        updater.running = true;
    }

    // перезапуск через отвязанный процесс (Ochre.restartScript): он переживёт выход самого quickshell.
    // Уведомление — уже новому shell: старый вместе с историей уведомлений закрывается.
    function restartShell(title, body) {
        Quickshell.execDetached(["sh", "-c",
            't=$1 b=$2; shift 2; sleep 0.5; ' + Ochre.restartScript + '; sleep 3; [ -n "$t" ] && notify-send -a ochre "$t" "$b"',
            "sh", title ?? "", body ?? ""].concat(Ochre.sel));
    }

    function booted() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && touch "$1/update-ok"', "sh", stateDir]);
    }

    function rollback() {
        if (Ochre.system || !prevHead) {
            Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Нет прошлой версии"),
                I18n.tr("Откат доступен после обновления через ochre ↑ или system/ → обновить")]);
            return;
        }
        if (rollbacker.running || updating) return;
        error = "";
        rollbacker.running = true;
    }

    function updateGreeter() {
        Term.float(["sudo", "bash", dir + "/extras/install-greeter.sh"], { hold: true });
    }

    // файл-маркер: greeter установлен из этого shell
    FileView {
        id: greeterCheck
        path: "/etc/greetd/ochre-niri.kdl"
        printErrors: false
    }

    FileView {
        id: prevFile
        path: root.stateDir + "/update-prev"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.prevHead = text().trim()
        onLoadFailed: root.prevHead = ""
    }

    FileView {
        id: legacyGreeter
        path: "/usr/share/nopox-shell/greeter.qml"
        printErrors: false
    }

    Process {
        id: checker
        command: ["sh", "-c", `
            cd "$1" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo NOREPO; exit 0; }
            up=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || { echo NOUPSTREAM; exit 0; }
            GIT_TERMINAL_PROMPT=0 git fetch --quiet 2>/tmp/ochre-fetch.$$ || { echo "FETCHFAIL $(tail -1 /tmp/ochre-fetch.$$)"; rm -f /tmp/ochre-fetch.$$; exit 0; }
            rm -f /tmp/ochre-fetch.$$
            echo "UP $up"
            [ -n "$(git status --porcelain --untracked-files=no)" ] && echo DIRTY
            git log --format='C %h%x09%s' "HEAD..$up"`,
            "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const prev = root.behind;
                const commits = [];
                root.isRepo = true;
                root.dirty = false;
                root.error = "";
                for (const line of this.text.split("\n")) {
                    if (line === "NOREPO") root.isRepo = false;
                    else if (line === "NOUPSTREAM") root.error = I18n.tr("у ветки нет upstream");
                    else if (line.startsWith("FETCHFAIL")) root.error = "git fetch: " + line.slice(10);
                    else if (line.startsWith("UP ")) root.upstream = line.slice(3);
                    else if (line === "DIRTY") root.dirty = true;
                    else if (line.startsWith("C ")) {
                        const [hash, subject] = line.slice(2).split("\t");
                        commits.push({ hash, subject });
                    }
                }
                root.commits = commits;
                root.checking = false;
                if (prev === 0 && commits.length > 0 && Settings.get("shell.update.notify"))
                    Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Доступно обновление ochre"),
                        I18n.tr("%1 новых коммитов в %2 — клик по ochre ↑ на панели", commits.length, root.upstream)]);
            }
        }
    }

    Process {
        id: updater
        command: ["sh", "-c", 'cd "$1" && prev=$(git rev-parse HEAD) && GIT_TERMINAL_PROMPT=0 git pull --ff-only --quiet 2>&1 && mkdir -p "$2" && echo "$prev" > "$2/update-prev"',
            "sh", root.dir, root.stateDir]
        stdout: StdioCollector { id: pullOut }
        onExited: code => {
            root.updating = false;
            if (code !== 0) {
                root.error = "git pull: " + (pullOut.text.trim().split("\n").pop() || I18n.tr("код %1", code));
                return;
            }
            root.commits = [];
            root.updated = true;
            Quickshell.execDetached(["sh", "-c",
                't=$1 b=$2 s=$3 d=$4 ft=$5 fb=$6; shift 6; rm -f "$s/update-ok"; sleep 0.5; ' + Ochre.restartScript + '; '
                + 'i=0; while [ $i -lt 30 ] && [ ! -e "$s/update-ok" ]; do sleep 1; i=$((i+1)); done; sleep 3; '
                + 'if [ -e "$s/update-ok" ] && qs list "$@" 2>&1 | grep -q Instance; then [ -n "$t" ] && notify-send -a ochre "$t" "$b"; exit 0; fi; '
                + 'p=$(cat "$s/update-prev") && git -C "$d" reset --keep --quiet "$p" && rm -f "$s/update-prev" || exit 1; '
                + Ochre.restartScript + '; sleep 3; notify-send -a ochre -u critical "$ft" "$fb"',
                "sh", I18n.tr("ochre обновлён"),
                root.greeterSeparate ? I18n.tr("Greeter обновляется отдельно: Mod+S → system/ → обновить greeter") : "",
                root.stateDir, root.dir,
                I18n.tr("Обновление ochre откачено"),
                I18n.tr("Новая версия не запустилась, вернул прошлую. Лог: qs log; повторить — ochre ↑ на панели")].concat(Ochre.sel));
        }
    }

    Process {
        id: rollbacker
        command: ["sh", "-c", 'git -C "$1" reset --keep --quiet "$2" 2>&1 && rm -f "$3/update-prev" && git -C "$1" log -1 --format=%h', "sh", root.dir, root.prevHead, root.stateDir]
        stdout: StdioCollector { id: rollbackOut }
        onExited: code => {
            const out = rollbackOut.text.trim();
            if (code !== 0) {
                root.error = "git reset: " + (out.split("\n").pop() || I18n.tr("код %1", code));
                Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Откат не удался"), root.error]);
                return;
            }
            root.restartShell(I18n.tr("ochre возвращён к %1", out), I18n.tr("Обновить снова — ochre ↑ на панели"));
        }
    }

    // ── пакет: pacman заменил файлы под работающим shell (автоперезагрузка выключена, см. shell.qml) ──

    property string version: ""

    FileView {
        id: versionFile
        path: Ochre.system ? root.dir + "/VERSION" : ""
        printErrors: false
        onLoaded: {
            const v = text().trim();
            if (root.version && v && v !== root.version)
                Quickshell.execDetached(["sh", "-c",
                    'a=$(notify-send -a ochre -A restart="$1" "$2" "$3"); shift 3; '
                    + '[ "$a" = restart ] || exit 0; ' + Ochre.restartScript,
                    "sh", I18n.tr("перезапустить"), I18n.tr("ochre обновлён до %1", v), I18n.tr("Перезапустите shell, чтобы взять новую версию")].concat(Ochre.sel));
            if (v) root.version = v;
        }
    }

    Timer {
        interval: 60 * 1000
        running: Ochre.system
        repeat: true
        onTriggered: versionFile.reload()
    }

    // первая проверка — через минуту после запуска, дальше по расписанию
    Timer {
        interval: 60 * 1000
        running: true
        onTriggered: root.check()
    }

    Timer {
        interval: Settings.get("shell.update.hours") * 3600 * 1000
        running: Settings.get("shell.update.check")
        repeat: true
        onTriggered: root.check()
    }
}
