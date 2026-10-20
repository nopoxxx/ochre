pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Переводы интерфейса: lang/<код>.json — {"meta": {"name", "locale"}, "strings": {"русский текст": "перевод"}}.
// Исходный язык — русский: ключ — сама строка из кода (как в gettext), перевода нет — показывается она же.
//   I18n.tr("Скриншот сохранён")         → «Screenshot saved»
//   I18n.tr("прошло %1", "25:00")         → %1, %2… — аргументы по порядку
// Строки из settings.js (подписи, подсказки) переводятся при показе: tr() делит строку по «  ·  » и переводит части.
// Язык — shell.lang: auto (по $LANG / $LC_MESSAGES), ru, en, … — любой файл в lang/. Новые строки в файлы
// дописывает lang/update.py. Даты — по locale языка (I18n.locale вместо Qt.locale()).
Singleton {
    id: root

    readonly property string setting: Settings.get("shell.lang") ?? "auto"
    readonly property string sys: (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "ru")
        .split(/[_.@]/)[0].toLowerCase()
    // auto: язык системы, если для него есть файл; иначе английский (русский — исходный, файл ему не нужен)
    readonly property string code: setting !== "auto" ? setting : sys === "ru" || available.includes(sys) ? sys : "en"
    readonly property bool source: code === "ru"

    property var strings: ({})
    property var meta: ({})
    // какие языки есть: ru — всегда, остальные — по файлам lang/*.json
    property var available: ["en"]

    readonly property var locale: Qt.locale(meta.locale || (code === "ru" ? "ru_RU" : code === "en" ? "en_US" : code))

    function lookup(s) {
        if (source || !s) return s;
        const t = strings[s];
        return t === undefined || t === "" ? s : t;
    }

    function tr(s, ...args) {
        let out = String(s ?? "");
        if (!source && out) out = out.includes("  ·  ") ? out.split("  ·  ").map(lookup).join("  ·  ") : lookup(out);
        for (let i = 0; i < args.length; i++) out = out.split("%" + (i + 1)).join(String(args[i]));
        return out;
    }

    FileView {
        id: file
        path: root.source ? "" : Quickshell.shellDir + "/lang/" + root.code + ".json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.strings = d.strings ?? {};
                root.meta = d.meta ?? {};
            } catch (e) {
                console.warn("i18n: lang/" + root.code + ".json не читается:", e);
                root.strings = {};
                root.meta = {};
            }
        }
        onLoadFailed: { root.strings = {}; root.meta = {}; }
    }
    onSourceChanged: if (source) { strings = {}; meta = {}; }

    Process {
        running: true
        command: ["sh", "-c", 'for f in "$1"/lang/*.json; do [ -f "$f" ] && basename "$f" .json; done', "sh", Quickshell.shellDir]
        stdout: StdioCollector { onStreamFinished: root.available = text.split("\n").filter(x => x) }
    }
}
