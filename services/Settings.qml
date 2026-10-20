pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Настройки ochre: ~/.config/ochre/settings.json (только отличия от умолчаний)
// и сгенерированные из них файлы ~/.config/niri/ochre/*.kdl — по файлу на раздел.
// В greeter (OCHRE_GREETER=1) — только чтение копии настроек пользователя profile
// из /var/lib/ochre-greeter/<user>/, её туда кладёт GreeterSync из сессии пользователя.
Singleton {
    id: root

    readonly property bool greeterMode: Quickshell.env("OCHRE_GREETER") === "1"
    property string profile: ""
    readonly property string file: greeterMode
        ? (profile ? "/var/lib/ochre-greeter/" + profile + "/settings.json" : "")
        : Quickshell.env("HOME") + "/.config/ochre/settings.json"
    readonly property string niriDir: Quickshell.env("HOME") + "/.config/niri/ochre"
    // переезд с nopox-shell на ochre (rename) закончен — до этого файлы по новым путям не читаем и не пишем
    property bool renamed: greeterMode

    property var values: ({})
    property bool loaded: false
    // settings.json есть, но не читается (битый, пустой, нет прав): работаем на умолчаниях и ничего
    // не пишем — иначе первое же сохранение затрёт все настройки, вместе со своими биндами
    property bool broken: false
    // можно писать файлы по настройкам (settings.json, ochre/*.kdl, темы) — проверять перед любой записью
    readonly property bool writable: loaded && !greeterMode && !broken
    property int _retries: 0
    property var outputs: []
    readonly property var outputIds: S.outputIds(outputs)
    property bool open: false   // окно настроек
    property string page: ""    // открытый раздел (id из S.sections) — окно возвращается к нему

    // окно, открытое из настроек (мониторы, бинды, обои, предпросмотр блокировки), при закрытии
    // возвращает в настройки: такое окно вызывает back() в onOpenChanged
    property bool returnHere: false

    // открыть окно настроек; section — id раздела, "" — последний открытый
    function show(section) {
        if (section) page = section;
        open = true;
    }

    function back() {
        if (!returnHere) return;
        returnHere = false;
        open = true;
    }

    // окружение для программ, которые запускает shell (меню, терминалы): qs мог стартовать до включения тем
    // и держит старое окружение. Темы выключены — убираем только то, что поставили мы сами
    function appEnv() {
        const env = {};
        for (const k in S.APP_ENV) {
            if (get("shell.theme.sync")) env[k] = S.APP_ENV[k];
            else if (Quickshell.env(k) === S.APP_ENV[k]) env[k] = null;
        }
        return env;
    }

    function get(key) {
        return key in values ? values[key] : S.defaultOf(key, outputs);
    }

    function isDefault(key) {
        return !(key in values);
    }

    function set(key, value) {
        const v = Object.assign({}, values);
        if (value === S.defaultOf(key, outputs)) delete v[key];
        else v[key] = value;
        values = v;
        save.restart();
    }

    function reset(key) {
        if (isDefault(key)) return;
        const v = Object.assign({}, values);
        delete v[key];
        values = v;
        save.restart();
    }

    // заменить все ключи с префиксом разом (откат настроек мониторов)
    function replacePrefix(prefix, obj) {
        const v = {};
        for (const k in values)
            if (!k.startsWith(prefix)) v[k] = values[k];
        Object.assign(v, obj);
        values = v;
        save.restart();
    }

    function snapshotPrefix(prefix) {
        const out = {};
        for (const k in values)
            if (k.startsWith(prefix)) out[k] = values[k];
        return out;
    }

    function refreshOutputs() { outputsProc.running = true; }

    function outKey(name) { return outputIds[name] ?? name; }

    function migrateOutputs() {
        if (!writable || !outputs.length) return;
        const v = S.migrateOutputKeys(values, outputIds);
        if (!v) return;
        values = v;
        save.restart();
    }
    onOutputIdsChanged: migrateOutputs()
    onWritableChanged: migrateOutputs()

    function writeNiri() {
        if (!writable) return;
        const outs = {};
        for (const k in values) {
            const m = k.match(/^niri\.out\.(.+)\.(\w+)$/);
            if (!m) continue;
            if (!outs[m[1]]) outs[m[1]] = {};
            outs[m[1]][m[2]] = values[k];
        }
        // пишем только изменившиеся файлы: niri перечитывает конфиг при каждой записи
        const files = S.niriFiles(get, outs, Ochre.sel);
        const args = [];
        for (const name in files)
            if (_written[name] !== files[name]) args.push(name, files[name]);
        if (!args.length) return;
        _pending = args;
        flushNiri();
    }

    property var _written: ({})
    property var _pending: null

    function flushNiri() {
        if (writer.running || !_pending) return;
        const args = _pending;
        _pending = null;
        for (let i = 0; i < args.length; i += 2) _written[args[i]] = args[i + 1];
        // через временный файл и mv — niri не увидит наполовину записанный файл
        writer.command = ["sh", "-c", 'd=$1; shift; mkdir -p "$d"; while [ $# -gt 1 ]; do printf "%s" "$2" > "$d/.$1.tmp" && mv -f "$d/.$1.tmp" "$d/$1"; shift 2; done',
            "sh", niriDir].concat(args);
        writer.running = true;
    }

    Component.onCompleted: if (!greeterMode) rename.running = true

    // Переезд nopox-shell → ochre (один раз, у тех, кто ставил shell под старым именем):
    // ~/.config/nopox → ochre, ~/.local/state/nopox → ochre, ~/.config/niri/nopox → ochre и include в config.kdl
    // (не прошёл niri validate, хотя до замены проходил, — config.kdl как был), старые файлы тем GTK/Qt/btop,
    // conf.d/nopox.fish и адрес репозитория в git-клоне shell. Новое не затирается: cp -n.
    Process {
        id: rename
        command: ["sh", "-c", `
            h=$HOME; n=$h/.config/niri; did=""
            movedir() { [ -d "$1" ] || return 1; mkdir -p "$2" && cp -an "$1"/. "$2"/ && rm -rf "$1"; }
            movedir "$h/.config/nopox" "$h/.config/ochre" && did="$did settings"
            movedir "$h/.local/state/nopox" "$h/.local/state/ochre"
            if [ -d "$n/nopox" ]; then
                mkdir -p "$n/ochre" && cp -an "$n/nopox"/. "$n/ochre"/
                ok=1
                if [ -f "$n/config.kdl" ] && grep -qE '^include "nopox/(main|keys)\.kdl"' "$n/config.kdl"; then
                    niri validate -c "$n/config.kdl" >/dev/null 2>&1 && was=1 || was=0
                    cp "$n/config.kdl" "$n/config.kdl.bak-ochre"
                    sed -i -e 's#^include "nopox/main\.kdl"#include "ochre/main.kdl"#' \
                           -e 's#^include "nopox/keys\.kdl"#include "ochre/keys.kdl"#' \
                           -e 's#^// >>> nopox-shell >>>#// >>> ochre >>>#' -e 's#^// <<< nopox-shell <<<#// <<< ochre <<<#' "$n/config.kdl"
                    if [ $was = 1 ] && ! niri validate -c "$n/config.kdl" >/dev/null 2>&1; then
                        mv -f "$n/config.kdl.bak-ochre" "$n/config.kdl"; ok=0
                    fi
                fi
                if [ $ok = 1 ]; then rm -rf "$n/nopox"; did="$did niri"; else echo NIRIFAIL; fi
            fi
            for v in gtk-3.0 gtk-4.0; do
                f=$h/.config/$v/gtk.css
                [ -f "$f" ] && grep -q '^@import "nopox.css";$' "$f" && sed -i '/^@import "nopox.css";$/d' "$f"
                rm -f "$h/.config/$v/nopox.css"
            done
            rm -f "$h/.config/qt6ct/colors/nopox.conf" "$h/.config/btop/themes/nopox.theme"
            fd=$h/.config/fish/conf.d
            if [ -f "$fd/nopox.fish" ]; then [ -e "$fd/ochre.fish" ] || cp "$fd/nopox.fish" "$fd/ochre.fish"; rm -f "$fd/nopox.fish"; fi
            if u=$(git -C "$1" remote get-url origin 2>/dev/null) && [ "$u" != "\${u#*nopoxxx/nopox-shell}" ]; then
                git -C "$1" remote set-url origin "$(printf '%s' "$u" | sed 's#nopoxxx/nopox-shell#nopoxxx/ochre#')"
            fi
            # greeter ставится через sudo — только напомнить, и один раз, вместе с переездом
            [ -n "$did" ] && [ -d /usr/share/nopox-shell ] && [ ! -f /etc/greetd/ochre-niri.kdl ] && did="$did greeter"
            mkdir -p "$h/.config/ochre" "$n/ochre"
            [ -n "$did" ] && echo "DID$did"
            exit 0`, "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text;
                if (out.includes("NIRIFAIL"))
                    Quickshell.execDetached(["notify-send", "-a", "ochre", "-u", "critical", I18n.tr("ochre: config.kdl не переведён"),
                        I18n.tr("После замены include \"nopox/…\" на \"ochre/…\" niri validate не проходит — config.kdl оставлен как был.")
                        + " " + I18n.tr("Поправьте include в ~/.config/niri/config.kdl вручную (Mod+S → system/ → niri).")]);
                const did = (out.match(/^DID(.*)$/m) ?? ["", ""])[1].trim().split(" ").filter(x => x);
                if (did.length)
                    Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("nopox-shell теперь ochre"),
                        I18n.tr("Настройки — ~/.config/ochre, конфиг niri — ~/.config/niri/ochre.")
                        + (did.includes("greeter") ? " " + I18n.tr("Greeter стоит под старым именем — обновите его: Mod+S → system/ → обновить greeter.") : "")]);
            }
        }
        onExited: root.renamed = true
    }

    // небольшая задержка: стрелкой можно пролистать несколько значений подряд, а niri перечитает конфиг один раз
    Timer {
        id: save
        interval: 250
        onTriggered: {
            if (!root.writable) return;
            json.setText(JSON.stringify(root.values, null, 2) + "\n");
            root.writeNiri();
        }
    }

    FileView {
        id: json
        path: root.renamed ? root.file : ""
        atomicWrites: true   // через временный файл: при падении или перезапуске qs файл не останется наполовину
        onLoaded: {
            let v = null;
            try { v = JSON.parse(text()); } catch (e) { console.warn("settings.json:", e); }
            if (!v || typeof v !== "object" || Array.isArray(v)) {
                // пустой или битый — возможно, застали запись: перечитать, и только потом сдаваться
                if (root._retries < 3) {
                    root._retries++;
                    retry.restart();
                    return;
                }
                root.giveUp(I18n.tr("не разбирается как JSON"));
                return;
            }
            root._retries = 0;
            root.broken = false;
            root.values = v;
            root.loaded = true;
            root.writeNiri();   // схема могла измениться после обновления
        }
        onLoadFailed: error => {
            if (root.greeterMode) {
                // greeter: у этого пользователя нет копии — умолчания, а не настройки предыдущего
                root.values = {};
            } else if (error !== FileViewError.FileNotFound) {
                root.giveUp(FileViewError.toString(error));
                return;
            }
            // файла нет — первый запуск: умолчания, первое сохранение его создаст
            root.loaded = true;
            root.writeNiri();
        }
    }

    Timer {
        id: retry
        interval: 300
        onTriggered: json.reload()
    }

    function giveUp(why) {
        broken = true;
        loaded = true;
        console.warn("settings.json не прочитан (" + why + ") — работаю на умолчаниях, сохранение выключено");
        if (!greeterMode)
            Quickshell.execDetached(["notify-send", "-a", "ochre", "-u", "critical", I18n.tr("Настройки не прочитаны"),
                I18n.tr("%1: %2. Shell работает на умолчаниях и ничего не сохраняет, чтобы не затереть файл.", file, why)
                + " " + I18n.tr("Исправьте или удалите его и перезапустите shell.")]);
    }

    property bool _migrated: false

    Process {
        id: writer
        onExited: {
            if (!root._migrated) {
                root._migrated = true;
                migrate.running = true;
            }
            root.flushNiri();
        }
    }

    // Самая старая схема (до разбиения, ещё под именем nopox): nopox.kdl, nopox-binds.kdl, nopox-keys.kdl рядом
    // с config.kdl. Переводим include на ochre/…, проверяем niri validate и только тогда удаляем старые файлы;
    // если не прошло — возвращаем config.kdl как был.
    Process {
        id: migrate
        command: ["sh", "-c", `
            cd "$1/.." || exit 0
            [ -f config.kdl ] && grep -qE '^include "nopox(-binds|-keys)?\.kdl"' config.kdl || exit 0
            cp config.kdl config.kdl.bak-ochre-split
            sed -i -e 's#^include "nopox\.kdl"#include "ochre/main.kdl"#' \
                   -e '/^include "nopox-binds\.kdl"/d' \
                   -e 's#^include "nopox-keys\.kdl"#include "ochre/keys.kdl"#' config.kdl
            # main.kdl уже подключает binds.kdl; keys.kdl мог ещё не успеть записаться — пустой на время проверки
            [ -f "$1/keys.kdl" ] || printf 'binds {\\n}\\n' > "$1/keys.kdl"
            if niri validate -c config.kdl >/dev/null 2>&1; then
                rm -f nopox.kdl nopox-binds.kdl nopox-keys.kdl
                notify-send -a ochre "$2" "$3"
            else
                mv -f config.kdl.bak-ochre-split config.kdl
            fi`, "sh", root.niriDir, I18n.tr("Настройки niri разложены по файлам"), I18n.tr("~/.config/niri/ochre/ — input, displays, layout, window-rules, …")]
    }

    Process {
        id: outputsProc
        running: true
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(this.text);
                    const modeStr = m => m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3);
                    root.outputs = Object.values(o).map(x => {
                        // режимы без повторов: сначала крупнее, внутри — чаще
                        const modes = [...new Set((x.modes ?? [])
                            .slice().sort((a, b) => b.width * b.height - a.width * a.height || b.refresh_rate - a.refresh_rate)
                            .map(modeStr))];
                        const cur = x.modes?.[x.current_mode];
                        const pref = (x.modes ?? []).find(m => m.is_preferred);
                        return {
                            name: x.name,
                            make: x.make ?? "",
                            model: x.model ?? "",
                            serial: x.serial ?? "",
                            physical: x.physical_size ?? [0, 0],
                            modes,
                            mode: cur ? modeStr(cur) : "",
                            preferred: pref ? modeStr(pref) : "",
                            enabled: x.logical !== null && x.current_mode !== null,
                            scale: x.logical?.scale ?? 1,
                            transform: S.niriTransform(x.logical?.transform),
                            x: x.logical?.x ?? 0,
                            y: x.logical?.y ?? 0,
                            w: x.logical?.width ?? 0,
                            h: x.logical?.height ?? 0,
                            vrrSupported: x.vrr_supported ?? false,
                            vrr: x.vrr_enabled ?? false
                        };
                    }).sort((a, b) => a.name.localeCompare(b.name));
                } catch (e) {
                    console.warn("niri outputs:", e);
                }
            }
        }
    }
}
