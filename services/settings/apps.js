.pragma library

// Программы: терминалы, файловые менеджеры, оболочки, браузеры, запуск в терминале, значки трея.
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.

// ── значки трея ────────────────────────────────────────────────────
// Глифы Terminess Nerd Font: шаблон ищется в id, заголовке и имени иконки элемента трея (в нижнем регистре).
// Первое совпадение выигрывает — частные шаблоны выше общих. Новый глиф проверять по шрифту
// (fontTools: getBestCmap() и имена вида md-discord), иначе вместо значка будет пустой квадрат.
var TRAY_ICONS = [
    [/discord|vesktop|webcord|legcord|armcord/, 0xF066F],       // md-discord
    [/steam/, 0xF04D3],                                         // md-steam
    [/telegram|ayugram|kotatogram/, 0xF2C6],                    // fa-telegram
    [/spotify/, 0xF04C7],                                       // md-spotify
    [/firefox|librewolf|floorp|\bzen\b/, 0xF0239],                  // md-firefox
    [/chrom|helium|brave|vivaldi/, 0xF02AF],                    // md-google_chrome
    [/slack/, 0xF04B1],                                         // md-slack
    [/skype/, 0xF04AF],                                         // md-skype
    [/whatsapp/, 0xF05A3],                                      // md-whatsapp
    [/element|matrix|nheko|fractal/, 0xF0628],                  // md-matrix
    [/\bobs\b|obs-studio/, 0xF044B],                            // md-record_rec
    [/throne|nekoray|nekobox|hiddify|v2ray|clash|sing-?box|mullvad|proton.?vpn|wireguard|vpn/, 0xF099D], // md-shield_lock
    [/qbittorrent|transmission|deluge|ktorrent|fragments/, 0xF0347], // md-magnet
    [/syncthing/, 0xF04E6],                                     // md-sync
    [/nextcloud|owncloud|insync|megasync|rclone/, 0xF015F],     // md-cloud
    [/dropbox/, 0xF01E3],                                       // md-dropbox
    [/keepass|bitwarden|1password|proton.?pass/, 0xF0306],      // md-key
    [/kdeconnect|gsconnect|valent/, 0xF0121],                   // md-cellphone_link
    [/blueman|bluetooth/, 0xF00AF],                             // md-bluetooth
    [/nm-applet|network|iwgtk/, 0xF05A9],                       // md-wifi
    [/easyeffects|pavucontrol|pasystray|volume|audio/, 0xF057E], // md-volume_high
    [/lutris|heroic|bottles|gamemode/, 0xF0296],                // md-gamepad
    [/\bcode\b|vscode|codium/, 0xF0A1E],                     // md-microsoft_visual_studio_code
    [/solaar|piper|mouse/, 0xF037D],                            // md-mouse
    [/clipboard|copyq|clipman|cliphist/, 0xF014D],              // md-clipboard_text
    [/mpv|vlc|player|music/, 0xF040C],                          // md-play_circle
    [/update|pamac|octopi/, 0xF06B0],                           // md-update
    [/docker|podman/, 0xF0868],                                 // md-docker
    [/mail|thunderbird|geary/, 0xF01EE]                         // md-email
];

// значок элемента трея или "" — тогда Tray покажет первую букву
function trayGlyph(id, title, icon) {
    const hay = [id, title, icon].filter(x => x).join(" ").toLowerCase();
    for (const [re, cp] of TRAY_ICONS)
        if (re.test(hay)) return String.fromCodePoint(cp);
    return "";
}

// ── терминал и файловый менеджер ───────────────────────────────────

var TERMINALS = ["kitty", "alacritty", "ghostty", "foot"];
var FILE_MANAGERS = ["none", "thunar", "nautilus", "dolphin", "nemo", "yazi"];

// оболочка: пакеты, которые ставятся, если её нет (как в install.sh)
var SHELLS = ["zsh", "fish", "bash"];
var SHELL_PKGS = { zsh: "zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions", fish: "fish", bash: "bash bash-completion" };

// браузер: пакет (по нему ищется .desktop для xdg-settings) и команда для Mod+Shift+B
var BROWSERS = {
    none: null,
    helium: { pkg: "helium-browser-bin", bin: "helium-browser" },
    firefox: { pkg: "firefox", bin: "firefox" },
    zen: { pkg: "zen-browser-bin", bin: "zen-browser" },
    chromium: { pkg: "chromium", bin: "chromium" },
    brave: { pkg: "brave-bin", bin: "brave" },
    vivaldi: { pkg: "vivaldi", bin: "vivaldi-stable" }
};

// ghostty принимает только идентификатор приложения с точкой
function termClass(term, c) {
    return term === "ghostty" ? "dev.ochre." + c.replace(/^ochre-/, "") : c;
}

// argv — команда; opts: { cls, hold }. Общая для Term.qml и binds.kdl
function termCmd(term, argv, opts) {
    argv = argv ?? [];
    const hold = opts?.hold ?? false;
    const c = opts?.cls ? termClass(term, opts.cls) : "";
    switch (term) {
    case "foot":
        return ["foot"].concat(c ? ["--app-id=" + c] : [], hold ? ["--hold"] : [], argv);
    case "alacritty":
        return ["alacritty"].concat(c ? ["--class", c] : [], hold ? ["--hold"] : [], argv.length ? ["-e"].concat(argv) : []);
    case "ghostty":
        return ["ghostty"].concat(c ? ["--class=" + c] : [], hold ? ["--wait-after-command=true"] : [], argv.length ? ["-e"].concat(argv) : []);
    default:
        return ["kitty"].concat(c ? ["--class", c] : [], hold ? ["--hold"] : [], argv.length ? ["-e"].concat(argv) : []);
    }
}

// файловый менеджер: yazi — терминальный, остальные — свой бинарник
function filesCmd(term, fm) {
    if (!fm || fm === "none") return null;
    return fm === "yazi" ? termCmd(term, ["yazi"]) : [fm];
}
