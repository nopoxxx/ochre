pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Бинды niri: что действует сейчас (config.kdl + ochre/binds.kdl + свои) и свои изменения.
// Свои хранятся в настройке niri.keys и генерируются в ~/.config/niri/ochre/keys.kdl,
// который подключается в config.kdl последним — поэтому перекрывает одноимённые бинды.
// После записи — niri validate; если конфиг не прошёл, изменение откатывается.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/niri"
    readonly property var keys: Settings.get("niri.keys") ?? ({})

    property string configText: ""
    property var configBinds: []
    property var ochreBinds: []
    property var actions: []          // [{ name, desc }] из niri msg action --help
    property string error: ""
    property var _prevKeys: null      // до последнего изменения — для отката

    readonly property bool included: /^\s*include\s+"ochre\/keys\.kdl"/m.test(configText)

    // действующие бинды: config.kdl, поверх — ochre/binds.kdl, поверх — свои
    readonly property var all: {
        const map = {};
        for (const b of configBinds) map[S.comboKey(b.combo)] = Object.assign({}, b);
        for (const b of ochreBinds) map[S.comboKey(b.combo)] = Object.assign({}, b);
        for (const k in keys) {
            const own = keys[k];
            const base = map[k] ?? null;
            map[k] = {
                combo: own.combo,
                title: own.action === "off" ? "" : (own.title ?? ""),
                hidden: own.action === "off",
                action: own.action === "off" ? "off" : S.actionKdl(own.action),
                source: base ? "changed" : "own",
                off: own.action === "off",
                base
            };
        }
        return Object.values(map).sort((a, b) => a.combo.localeCompare(b.combo));
    }

    // Qt-клавиша → имя клавиши niri (xkb keysym); символы с Shift — обратно к базовой клавише
    function keyName(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1);
        const map = {
            [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "Space", [Qt.Key_Tab]: "Tab",
            [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete",
            [Qt.Key_Escape]: "Escape", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up",
            [Qt.Key_Down]: "Down", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up",
            [Qt.Key_PageDown]: "Page_Down", [Qt.Key_Insert]: "Insert", [Qt.Key_Print]: "Print",
            [Qt.Key_Minus]: "Minus", [Qt.Key_Underscore]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_Plus]: "Equal",
            [Qt.Key_Comma]: "Comma", [Qt.Key_Less]: "Comma", [Qt.Key_Period]: "Period", [Qt.Key_Greater]: "Period",
            [Qt.Key_Slash]: "Slash", [Qt.Key_Question]: "Slash", [Qt.Key_Backslash]: "Backslash", [Qt.Key_Bar]: "Backslash",
            [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Colon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe",
            [Qt.Key_QuoteDbl]: "Apostrophe", [Qt.Key_BracketLeft]: "BracketLeft", [Qt.Key_BraceLeft]: "BracketLeft",
            [Qt.Key_BracketRight]: "BracketRight", [Qt.Key_BraceRight]: "BracketRight", [Qt.Key_QuoteLeft]: "Grave",
            [Qt.Key_AsciiTilde]: "Grave", [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3",
            [Qt.Key_Dollar]: "4", [Qt.Key_Percent]: "5", [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7",
            [Qt.Key_Asterisk]: "8", [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MediaPlay]: "XF86AudioPlay",
            [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
            [Qt.Key_MicMute]: "XF86AudioMicMute"
        };
        return map[key] ?? "";
    }

    // нажатие → сочетание для niri: «Mod+Shift+M»; "" — нажат только модификатор
    function comboOf(event) {
        const name = keyName(event.key, event.text);
        if (!name) return "";
        const m = event.modifiers, mods = [];
        if (m & Qt.MetaModifier) mods.push("Mod");
        if (m & Qt.ControlModifier) mods.push("Ctrl");
        if (m & Qt.AltModifier) mods.push("Alt");
        if (m & Qt.ShiftModifier) mods.push("Shift");
        return mods.concat([name]).join("+");
    }

    // кто ещё занимает сочетание (кроме строки настроек с этим действием) — для предупреждения
    function conflict(combo, ownAction) {
        const k = S.comboKey(combo);
        return all.find(b => S.comboKey(b.combo) === k && !b.off && b.action !== ownAction) ?? null;
    }

    function set(newKeys) {
        _prevKeys = keys;
        error = "";
        if (Object.keys(newKeys).length) Settings.set("niri.keys", newKeys);
        else Settings.reset("niri.keys");
    }

    function setKey(combo, action, title) {
        const k = Object.assign({}, keys);
        k[S.comboKey(combo)] = { combo, action, title: title ?? "" };
        set(k);
    }

    // переименование: старое сочетание — отключить (если оно из конфига) или убрать (если своё)
    function replaceKey(oldCombo, combo, action, title) {
        const k = Object.assign({}, keys);
        const oldK = S.comboKey(oldCombo);
        if (oldCombo && oldK !== S.comboKey(combo)) {
            const fromConfig = [...configBinds, ...ochreBinds].some(b => S.comboKey(b.combo) === oldK);
            if (fromConfig) k[oldK] = { combo: oldCombo, action: "off", title: "" };
            else delete k[oldK];
        }
        k[S.comboKey(combo)] = { combo, action, title: title ?? "" };
        set(k);
    }

    function disable(combo) { setKey(combo, "off", ""); }

    function reset(combo) {
        const k = Object.assign({}, keys);
        delete k[S.comboKey(combo)];
        set(k);
    }

    // для старых установок: в config.kdl ещё нет include "ochre/keys.kdl"
    function ensureIncluded() {
        includer.running = true;
    }

    property string _written: ""

    function writeKeys() {
        if (!Settings.writable) return;
        const text = S.keysKdl(keys);
        if (text === _written) return;   // иначе niri перечитывал бы конфиг при любом изменении настроек
        _written = text;
        keysFile.setText(text);
        validate.restart();
    }

    onKeysChanged: writeKeys()

    Connections {
        target: Settings
        function onLoadedChanged() { root.writeKeys(); }
    }

    FileView {
        id: configFile
        path: Settings.greeterMode ? "" : root.dir + "/config.kdl"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.configText = text();
            root.configBinds = S.parseBinds(text(), "config");
        }
    }

    FileView {
        id: ochreFile
        path: Settings.greeterMode || !Settings.renamed ? "" : root.dir + "/ochre/binds.kdl"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.ochreBinds = S.parseBinds(text(), "ochre")
    }

    FileView {
        id: keysFile
        path: Settings.greeterMode || !Settings.renamed ? "" : root.dir + "/ochre/keys.kdl"
    }

    // niri перечитывает конфиг сам; проверяем, что новый вариант корректен
    Timer {
        id: validate
        interval: 300
        onTriggered: validator.running = true
    }

    Process {
        id: validator
        command: ["niri", "validate", "-c", root.dir + "/config.kdl"]
        stderr: StdioCollector { id: validateErr }
        onExited: code => {
            if (code === 0) {
                root._prevKeys = null;
                return;
            }
            if (root._prevKeys === null) return;
            // в выводе niri — рамки диагностики; берём последнюю строку «× …» и место «╭─[файл:строка]»
            const lines = validateErr.text.split("\n").map(l => l.replace(/\x1b\[[0-9;]*m/g, ""));
            const what = lines.filter(l => l.includes("×")).map(l => l.split("×").pop().trim()).pop() ?? I18n.tr("ошибка конфига");
            const where = lines.map(l => l.match(/╭─\[([^\]]+)\]/)?.[1]).filter(x => x).pop();
            root.error = I18n.tr("niri не принял бинд — отменено: %1", what + (where ? " (" + where + ")" : ""));
            const prev = root._prevKeys;
            root._prevKeys = null;
            if (Object.keys(prev).length) Settings.set("niri.keys", prev);
            else Settings.reset("niri.keys");
        }
    }

    Process {
        id: includer
        command: ["sh", "-c", 'grep -q "^include \\"ochre/keys.kdl\\"" "$1/config.kdl" || printf "\\n// свои бинды из окна биндов ochre — последними, чтобы перекрывать остальные\\ninclude \\"ochre/keys.kdl\\"\\n" >> "$1/config.kdl"', "sh", root.dir]
    }

    Process {
        running: !Settings.greeterMode
        command: ["niri", "msg", "action", "--help"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const out = [];
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^  ([a-z0-9-]+)\s*$/);
                    if (m && m[1] !== "help") out.push({ name: m[1], desc: (lines[i + 1] ?? "").trim() });
                }
                root.actions = out;
            }
        }
    }
}
