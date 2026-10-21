pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Темы приложений вслед за shell (настройки shell.theme.*, shell.accent, shell.fontSize, niri.cursor.size):
//   GTK — ~/.config/gtk-{3,4}.0/ochre.css (палитра темы и акцент; @import в начале gtk.css)
//         и gsettings org.gnome.desktop.interface (тёмная схема, adw-gtk3-dark, акцент, шрифт, курсор);
//   Qt  — ~/.config/qt6ct/ (палитра, Fusion, шрифт); QT_QPA_PLATFORMTHEME задаёт misc.kdl;
//   btop — ~/.config/btop/themes/ochre.theme и color_theme / theme_background / rounded_corners в btop.conf.
// Что писать — S.themeFiles() и S.themeGsettings(); здесь только запись, и лишь когда результат изменился.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property string termText: ""
    property string fastfetchText: ""
    readonly property string termRel: Term.configPath.slice((home + "/.config/").length)
    readonly property var termMigrated: termText ? S.termMigrate(Term.name, termText) : null

    // весь результат одной строкой: настройки меняются часто, а пишем только при реальной разнице
    readonly property string state: Settings.writable
        ? JSON.stringify({
            files: Object.assign(S.themeFiles(k => Settings.get(k), home),
                fastfetchText.startsWith(S.FASTFETCH_MARK) ? { "fastfetch/config.jsonc": S.fastfetchConfig(k => Settings.get(k), Quickshell.shellDir) } : {}),
            migrate: termMigrated ? [termRel, termMigrated, termText] : [],
            osc: termMigrated || (S.TERM_INCLUDE[Term.name] && termText.includes(S.TERM_INCLUDE[Term.name]))
                ? S.termOsc(S.palette(k => Settings.get(k))) : "",
            icons: S.iconOverlay(k => Settings.get(k)),
            gsettings: S.themeGsettings(k => Settings.get(k))
        })
        : ""
    property string _applied: ""
    property string _osc: ""

    onStateChanged: debounce.restart()

    function apply() {
        if (!state || state === _applied) return;
        if (writer.running) { debounce.restart(); return; }
        _applied = state;
        const s = JSON.parse(state);
        const args = [];
        for (const path in s.files) args.push(path, s.files[path]);
        const osc = _osc && s.osc !== _osc ? s.osc : "";
        if (s.osc) _osc = s.osc;
        args.push("--", osc);
        args.push(...(s.migrate.length ? s.migrate : ["", "", ""]));
        args.push(...(s.icons ? [s.icons.name, s.icons.base, s.icons.color, s.icons.index] : ["", "", "", ""]));
        for (const [key, value] of s.gsettings) args.push(key, value);
        writer.command = ["sh", "-c", `
            d=$1; shift
            # файлы: путь от ~/.config и содержимое; через временный файл — приложения не увидят половину
            while [ "$1" != "--" ]; do
                mkdir -p "$(dirname "$d/$1")"
                printf '%s' "$2" > "$d/$1.ochre-tmp" && mv -f "$d/$1.ochre-tmp" "$d/$1"
                shift 2
            done
            shift
            osc=$1; shift
            [ -n "$osc" ] && for t in /dev/pts/[0-9]*; do
                [ -O "$t" ] && [ -w "$t" ] && timeout 1 sh -c 'printf "%s" "$1" > "$2"' sh "$osc" "$t"
            done 2>/dev/null
            if [ -n "$1" ] && [ ! -e "$d/$1.bak-ochre" ]; then
                printf '%s' "$3" > "$d/$1.bak-ochre" && printf '%s' "$2" > "$d/$1.ochre-tmp" && mv -f "$d/$1.ochre-tmp" "$d/$1"
            fi
            shift 3
            # папки Papirus цвета акцента: тема-надстройка из ссылок на folder-<цвет>-*.svg, как у papirus-folders, но без sudo
            ic=\${XDG_DATA_HOME:-$HOME/.local/share}/icons
            if [ -n "$1" ]; then
                for o in "$ic"/ochre-Papirus-*; do
                    [ -e "$o" ] && [ "$o" != "$ic/$1" ] && rm -rf "$o"
                done
                src=
                for r in "$ic" /usr/local/share/icons /usr/share/icons; do [ -d "$r/$2" ] && { src=$r/$2; break; }; done
                t=$ic/$1
                if [ ! -f "$t/index.theme" ] || { [ -n "$src" ] && [ ! -e "$t/48x48/places/folder.svg" ]; }; then
                    rm -rf "$t"
                    for z in 22x22 24x24 32x32 48x48 64x64; do
                        mkdir -p "$t/$z/places"
                        [ -n "$src" ] && for f in "$src/$z/places/folder-$3"*.svg "$src/$z/places/user-$3"*.svg; do
                            n=\${f##*/}
                            case $n in folder-$3.svg|folder-$3-*.svg|user-$3.svg|user-$3-*.svg) ;; *) continue ;; esac
                            [ -f "$f" ] && [ ! -L "$f" ] && ln -sf "$f" "$t/$z/places/$(printf '%s' "$n" | sed "s/-$3//")"
                        done
                    done
                    printf '%s' "$4" > "$t/index.theme"
                fi
            fi
            shift 4
            # ochre.css — последним среди @import в gtk.css: из одинаковых @define-color побеждает последний,
            # а остатки других тем (noctalia.css и т.п.) иначе перебили бы палитру. @import — до остальных правил
            for v in gtk-3.0 gtk-4.0; do
                f="$d/$v/gtk.css"
                if [ ! -s "$f" ]; then mkdir -p "$d/$v"; printf '@import "ochre.css";\\n' > "$f"; continue; fi
                last=$(awk '/^[[:space:]]*@import/ { n = NR } END { print n + 0 }' "$f")
                ours=$(grep -n '^@import "ochre.css";$' "$f" | tail -1 | cut -d: -f1)
                [ "$ours" = "$last" ] && continue
                sed -i '/^@import "ochre.css";$/d' "$f"
                last=$(awk '/^[[:space:]]*@import/ { n = NR } END { print n + 0 }' "$f")
                if [ "$last" -gt 0 ]; then sed -i "\${last}a @import \\"ochre.css\\";" "$f"; else sed -i '1i @import "ochre.css";' "$f"; fi
            done
            # btop: тема ochre, фон терминала, прямые углы — как рамки shell. btop перечитывает btop.conf
            # при запуске и переписывает при выходе, сохраняя эти значения; запущенный увидит их со следующего раза
            if [ -f "$d/btop/themes/ochre.theme" ]; then
                b="$d/btop/btop.conf"
                [ -f "$b" ] || printf '#? ochre: btop.conf создан ochre, btop дополнит его сам\\n' > "$b"
                for kv in 'color_theme = "ochre"' 'theme_background = False' 'rounded_corners = False'; do
                    k=\${kv%% =*}
                    if grep -q "^$k = " "$b"; then sed -i "s|^$k = .*|$kv|" "$b"; else printf '%s\\n' "$kv" >> "$b"; fi
                done
            fi
            # gsettings: ключ и значение; пустое значение — вернуть по умолчанию
            while [ $# -gt 1 ]; do
                if [ -n "$2" ]; then gsettings set org.gnome.desktop.interface "$1" "$2"
                else gsettings reset org.gnome.desktop.interface "$1"; fi 2>/dev/null
                shift 2
            done`,
            "sh", home + "/.config"].concat(args);
        writer.running = true;
    }

    // стрелкой можно пролистать несколько значений подряд — пишем один раз
    Timer {
        id: debounce
        interval: 500
        onTriggered: root.apply()
    }

    FileView {
        path: Settings.writable && Term.configPath ? Term.configPath : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.termText = text()
        onLoadFailed: root.termText = ""
    }

    FileView {
        path: Settings.writable ? root.home + "/.config/fastfetch/config.jsonc" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.fastfetchText = text()
        onLoadFailed: root.fastfetchText = ""
    }

    Process {
        id: writer
        onExited: if (root.state !== root._applied) debounce.restart()
    }
}
