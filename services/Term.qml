pragma Singleton
import Quickshell
import QtQuick
import "settings.js" as S

// Выбранный терминал (настройка shell.terminal) и команды запуска для него.
//   Term.open(["btop"])                         — обычное окно
//   Term.float(["paru", "-Syu"], { hold: true }) — плавающее окно ochre-term по центру (правило в window-rules.kdl);
//                                                 hold — окно не закрывается после команды
//   Term.edit(path)                             — открыть файл или папку в vim в плавающем окне
Singleton {
    id: root

    readonly property string name: Settings.get("shell.terminal")

    // конфиг выбранного терминала — для «system/ → конфиги → терминал»
    readonly property string configPath: Quickshell.env("HOME") + ({
        kitty: "/.config/kitty/kitty.conf",
        alacritty: "/.config/alacritty/alacritty.toml",
        ghostty: "/.config/ghostty/config",
        foot: "/.config/foot/foot.ini"
    })[name]

    function cmd(argv, opts) { return S.termCmd(name, argv, opts); }
    // окружение — свежее (Settings.appEnv), а не то, с которым стартовал qs: из терминала тоже запускают программы
    function run(argv) { Quickshell.execDetached({ command: argv, environment: Settings.appEnv() }); }
    function open(argv) { run(cmd(argv)); }
    function float(argv, opts) { run(cmd(argv, Object.assign({ cls: "ochre-term" }, opts ?? {}))); }
    function edit(path) { float(["vim", path]); }
    function fastfetch() {
        const config = S.fastfetchConfig(k => Settings.get(k), Quickshell.shellDir);
        float(["bash", "-c",
            'f=${XDG_RUNTIME_DIR:-/tmp}/ochre-fastfetch.jsonc; printf "%s" "$1" > "$f"; printf "\\e[?25l"; fastfetch -c "$f"; printf "\\n  \\e[90m%s\\e[0m" "$2"; read -rs',
            "bash", config, I18n.tr("↵ — закрыть")]);
    }
}
