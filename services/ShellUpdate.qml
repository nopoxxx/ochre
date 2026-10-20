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
        command: ["sh", "-c", 'cd "$1" && GIT_TERMINAL_PROMPT=0 git pull --ff-only --quiet 2>&1', "sh", root.dir]
        stdout: StdioCollector { id: pullOut }
        onExited: code => {
            root.updating = false;
            if (code !== 0) {
                root.error = "git pull: " + (pullOut.text.trim().split("\n").pop() || I18n.tr("код %1", code));
                return;
            }
            root.commits = [];
            root.updated = true;
            root.restartShell(I18n.tr("ochre обновлён"),
                root.greeterSeparate ? I18n.tr("Greeter обновляется отдельно: Mod+S → system/ → обновить greeter") : "");
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
