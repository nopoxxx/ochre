pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Оболочка входа и браузер по умолчанию (настройки shell.sh и shell.browser, system/ → приложения).
// Правда — в системе: при старте и после каждого применения настройки берутся из /etc/passwd
// и xdg-settings, поэтому отменённый chsh или неудачная установка просто откатывают выбор.
// Выбор применяется через 1.5 с после последнего изменения — пролистывание ←→ не запускает chsh на каждом шаге.
//   оболочка — плавающий терминал: pacman -S (если нет), конфиг ochre (если своего нет), chsh -s;
//   браузер  — xdg-settings set default-web-browser; не установлен — сначала paru -S в терминале.
Singleton {
    id: root

    readonly property string sh: Settings.get("shell.sh")
    readonly property string browser: Settings.get("shell.browser")

    property bool probed: false
    property string sysSh: ""         // имя оболочки из /etc/passwd
    property string sysBrowser: ""    // id из S.BROWSERS, если браузер по умолчанию — один из них
    property var desktops: ({})       // id установленного браузера → его .desktop

    readonly property bool active: Settings.writable
    onActiveChanged: if (active) probe.running = true
    Component.onCompleted: if (active) probe.running = true   // настройки могли загрузиться раньше

    onShChanged: if (probed) apply.restart()
    onBrowserChanged: if (probed) apply.restart()

    Timer {
        id: apply
        interval: 1500
        onTriggered: root.applyNow()
    }

    function applyNow() {
        if (runner.running) { apply.restart(); return; }
        const s = sh !== sysSh && S.SHELLS.includes(sh) ? sh : "";
        const b = S.BROWSERS[browser] && browser !== sysBrowser ? S.BROWSERS[browser] : null;
        if (!s && !b) return;
        const desk = b ? (desktops[browser] ?? "") : "";
        const argv = ["sh", "-c", applyScript, "sh",
            s, s ? S.SHELL_PKGS[s] : "", Quickshell.shellDir + "/extras/shell",
            b ? b.pkg : "", desk,
            I18n.tr("── оболочка: %1", s), I18n.tr("готово: %1 — с нового входа", s), I18n.tr("── браузер: %1", b ? b.pkg : ""),
            I18n.tr("браузер по умолчанию:"), I18n.tr("~/.zshrc: приглашение ochre")];
        // терминал нужен для пароля (chsh, sudo) и для установки; известный браузер ставится молча
        runner.command = s || (b && !desk) ? Term.cmd(argv, { cls: "ochre-term", hold: true }) : argv;
        runner.running = true;
    }

    // $1 оболочка, $2 её пакеты, $3 extras/shell, $4 пакет браузера, $5 его .desktop (пусто — не установлен);
    // $6…$10 — переведённые сообщения (I18n): в тексте скрипта русского нет.
    // Шаги независимы: отказ от chsh не мешает сменить браузер
    readonly property string applyScript: `
        desktop_of() { pacman -Qlq "$1" 2>/dev/null | grep -m1 '^/usr/share/applications/.*[.]desktop$' | xargs -r basename; }
        s=$1 spkgs=$2 ex=$3 bpkg=$4 bdesk=$5 m_shell=$6 m_done=$7 m_browser=$8 m_default=$9 m_zsh=\${10}
        [ -n "$s" ] && (
            set -e
            echo "$m_shell"
            command -v "$s" >/dev/null || sudo pacman -S --needed $spkgs
            case "$s" in
                zsh) [ -f ~/.zshrc ] || { cp "$ex/zshrc" ~/.zshrc; echo "$m_zsh"; } ;;
                fish) install -Dm644 "$ex/ochre.fish" ~/.config/fish/conf.d/ochre.fish
                      f=~/.config/fish/functions/fish_prompt.fish
                      [ -f "$f" ] || install -Dm644 "$ex/fish_prompt.fish" "$f" ;;
                bash) grep -qsE '>>> (ochre|nopox-shell) >>>' ~/.bashrc || { echo; cat "$ex/bashrc"; } >> ~/.bashrc ;;
            esac
            chsh -s "$(command -v "$s")"
            echo "$m_done"
        )
        [ -n "$bpkg" ] && (
            set -e
            if [ -z "$bdesk" ]; then
                echo "$m_browser"
                paru -S --needed "$bpkg"
                bdesk=$(desktop_of "$bpkg")
            fi
            xdg-settings set default-web-browser "$bdesk"
            echo "$m_default $bdesk"
        )
        true`

    // после применения — перечитать систему: настройки покажут то, что вышло на самом деле
    Process {
        id: runner
        onExited: probe.running = true
    }

    // вывод: оболочка, .desktop браузера по умолчанию, затем «id .desktop» установленных браузеров
    Process {
        id: probe
        command: ["sh", "-c", `
            basename "$(getent passwd "$USER" | cut -d: -f7)"
            xdg-settings get default-web-browser 2>/dev/null || echo
            while [ $# -gt 0 ]; do
                d=$(pacman -Qlq "$2" 2>/dev/null | grep -m1 '^/usr/share/applications/.*[.]desktop$' | xargs -r basename)
                [ -n "$d" ] && echo "$1 $d"
                shift 2
            done`, "sh"].concat(Object.keys(S.BROWSERS).filter(k => S.BROWSERS[k])
            .reduce((a, k) => a.concat([k, S.BROWSERS[k].pkg]), []))   // flatMap в движке Qt нет
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const def = (lines[1] ?? "").trim();
                const d = {};
                for (const l of lines.slice(2)) {
                    const [id, file] = l.trim().split(" ");
                    if (id && file) d[id] = file;
                }
                root.desktops = d;
                root.sysSh = (lines[0] ?? "").trim();
                root.sysBrowser = Object.keys(d).find(k => d[k] === def) ?? "";
                // синхронизация с системой — не выбор пользователя: применять нечего
                root.probed = false;
                if (S.SHELLS.includes(root.sysSh)) Settings.set("shell.sh", root.sysSh);
                if (root.sysBrowser) Settings.set("shell.browser", root.sysBrowser);
                root.probed = true;
            }
        }
    }
}
