.pragma library
.import "common.js" as C
.import "themes.js" as P
.import "term.js" as TM

// Темы приложений вслед за shell: GTK, Qt (qt6ct), btop, gsettings.
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.

var head = C.head;
var text = C.text;

// ── темы приложений: GTK и Qt вслед за shell ───────────────────────
// Пишет services/AppTheme.qml: файлы — в ~/.config, параметры GTK — через gsettings
// (их же отдаёт xdg-desktop-portal: Firefox, Chromium, libadwaita).

const FONT = "Terminess Nerd Font Mono";

// иконки в цветах Gruvbox (AUR gruvbox-plus-icon-theme, ставит install.sh); без них GTK и Qt берут hicolor
const ICONS = "Gruvbox-Plus-Dark";

// accent-color в GNOME — фиксированный набор; точный цвет задаёт ochre.css
const GNOME_ACCENTS = { ochre: "yellow", yellow: "yellow", orange: "orange", green: "green", aqua: "teal", blue: "blue", purple: "purple", red: "red" };

// пиксели shell → пункты GTK/Qt (96 dpi)
function fontPt(get) {
    return Math.max(6, Math.round(get("shell.fontSize") * 0.75));
}

// именованные цвета libadwaita; их понимает и adw-gtk3 для GTK3-приложений
function gtkColors(c, accent) {
    const shade = a => "rgba(0, 0, 0, " + a + ")";
    const out = {
        accent_color: accent, accent_bg_color: accent, accent_fg_color: c.bg,
        destructive_color: c.red, destructive_bg_color: c.red, destructive_fg_color: c.bg,
        success_color: c.green, success_bg_color: c.green, success_fg_color: c.bg,
        warning_color: c.yellow, warning_bg_color: c.yellow, warning_fg_color: c.bg,
        error_color: c.red, error_bg_color: c.red, error_fg_color: c.bg,
        window_bg_color: c.bg, window_fg_color: c.fg,
        view_bg_color: c.bg0, view_fg_color: c.fg,
        headerbar_bg_color: c.bg0, headerbar_fg_color: c.fg, headerbar_border_color: c.bg2,
        headerbar_backdrop_color: c.bg, headerbar_shade_color: shade(0.36), headerbar_darker_shade_color: shade(0.9),
        card_bg_color: c.bg0, card_fg_color: c.fg, card_shade_color: shade(0.36),
        dialog_bg_color: c.bg0, dialog_fg_color: c.fg,
        popover_bg_color: c.bg0, popover_fg_color: c.fg, popover_shade_color: shade(0.25),
        thumbnail_bg_color: c.bg1, thumbnail_fg_color: c.fg,
        shade_color: shade(0.25), scrollbar_outline_color: shade(0.5)
    };
    for (const p of ["sidebar", "secondary_sidebar"])
        Object.assign(out, {
            [p + "_bg_color"]: c.bg0, [p + "_fg_color"]: c.fg, [p + "_backdrop_color"]: c.bg,
            [p + "_shade_color"]: shade(0.25), [p + "_border_color"]: c.bg1
        });
    return out;
}

function gtkCss(colors, vars) {
    const head = [
        "/* ochre: палитра shell для GTK — сгенерировано ochre (Mod+S → look/ → темы Qt и GTK).",
        "   Ручные правки перезапишутся; свои стили пишите в gtk.css после строки @import. */",
        ""
    ];
    const defs = Object.keys(colors).map(k => "@define-color " + k + " " + colors[k] + ";");
    // libadwaita ≥ 1.6 читает цвета из CSS-переменных — задаём и их
    const css = vars ? ["", ":root {", ...Object.keys(colors).map(k => "    --" + k.replace(/_/g, "-") + ": " + colors[k] + ";"), "}"] : [];
    return head.concat(defs, css).join("\n") + "\n";
}

// палитра qt6ct: роли QPalette по порядку, от WindowText до Accent
function qtColors(c, accent, disabled) {
    const alt = P.mix(c.bg0, c.bg1, 0.5);
    const text = disabled ? c.gray : c.fg;
    return [
        text, c.bg1, c.bg2, c.bg1, c.bg, alt,     // WindowText Button Light Midlight Dark Mid
        text, c.fg0, text, c.bg0, c.bg, "#000000",      // Text BrightText ButtonText Base Window Shadow
        disabled ? c.bg2 : accent, c.bg,                // Highlight HighlightedText
        c.blue, c.purple, alt, c.bg,              // Link LinkVisited AlternateBase NoRole
        c.bg0, c.fg, c.gray, disabled ? c.bg2 : accent  // ToolTipBase ToolTipText PlaceholderText Accent
    ].join(", ");
}

// QFont::toString(): семейство, размер в пунктах, -1, 5, вес 50 (обычный), остальное — нули
function qtFont(pt) {
    return '"' + FONT + "," + pt + ',-1,5,50,0,0,0,0,0"';
}

// home — домашняя папка: путь к схеме в qt6ct.conf абсолютный.
// Возвращает { путь от ~/.config: текст }. С выключенной синхронизацией ochre.css пустые — GTK как без shell;
// qt6ct не трогаем: без QT_QPA_PLATFORMTHEME (misc.kdl) он не используется.
function themeFiles(get, home) {
    if (!get("shell.theme.sync")) {
        const off = "/* ochre: синхронизация тем выключена (Mod+S → look/ → темы Qt и GTK) */\n";
        return Object.assign({ "gtk-3.0/ochre.css": off, "gtk-4.0/ochre.css": off }, TM.termFiles(get));
    }
    const c = P.palette(get);
    const accent = c.accent;
    const colors = gtkColors(c, accent);
    const pt = fontPt(get);
    return Object.assign(TM.termFiles(get), {
        "gtk-3.0/ochre.css": gtkCss(colors, false),
        "gtk-4.0/ochre.css": gtkCss(colors, true),
        "btop/themes/ochre.theme": btopTheme(c, accent),
        "qt6ct/colors/ochre.conf": [
            "; ochre: палитра shell для Qt — сгенерировано ochre, ручные правки перезапишутся",
            "[ColorScheme]",
            "active_colors=" + qtColors(c, accent, false),
            "disabled_colors=" + qtColors(c, accent, true),
            "inactive_colors=" + qtColors(c, accent, false),
            ""
        ].join("\n"),
        "qt6ct/qt6ct.conf": [
            "; ochre: сгенерировано ochre (Mod+S → look/ → темы Qt и GTK), ручные правки перезапишутся",
            "[Appearance]",
            "color_scheme_path=" + home + "/.config/qt6ct/colors/ochre.conf",
            "custom_palette=true",
            "icon_theme=" + ICONS,
            "standard_dialogs=xdgdesktopportal",
            "style=Fusion",
            "",
            "[Fonts]",
            "fixed=" + qtFont(pt),
            ...(get("shell.theme.font") ? ["general=" + qtFont(pt)] : []),
            ""
        ].join("\n")
    });
}

// btop в стиле shell: рамки и заголовки — акцент, разделители — bg2, подписи — серые, градиенты Gruvbox.
// Фон пустой — btop рисует на фоне терминала (theme_background = False ставит AppTheme в btop.conf).
function btopTheme(c, accent) {
    const aqua = c.aqua, orange = c.orange;
    const t = {
        main_bg: "", main_fg: c.fg, title: accent, hi_fg: accent,
        selected_bg: c.bg1, selected_fg: accent, inactive_fg: c.bg3, graph_text: c.gray, meter_bg: c.bg1,
        proc_misc: aqua, cpu_box: accent, mem_box: accent, net_box: accent, proc_box: accent, div_line: c.bg2,
        temp_start: c.green, temp_mid: c.yellow, temp_end: c.red,
        cpu_start: c.green, cpu_mid: c.yellow, cpu_end: c.red,
        free_start: c.bg2, free_mid: aqua, free_end: c.green,
        cached_start: c.bg2, cached_mid: c.blue, cached_end: aqua,
        available_start: c.bg2, available_mid: orange, available_end: c.yellow,
        used_start: c.green, used_mid: orange, used_end: c.red,
        download_start: c.bg2, download_mid: c.blue, download_end: aqua,
        upload_start: c.bg2, upload_mid: c.purple, upload_end: accent,
        process_start: c.green, process_mid: c.yellow, process_end: c.red
    };
    return ["# ochre: тема btop в цветах shell — сгенерировано ochre (Mod+S → look/ → темы), ручные правки перезапишутся",
        ...Object.keys(t).map(k => "theme[" + k + "]=" + JSON.stringify(t[k])), ""].join("\n");
}

// [[ключ org.gnome.desktop.interface, значение GVariant | "" — сбросить]].
// С выключенной синхронизацией — ничего: свои настройки GTK пользователь задаёт сам.
function themeGsettings(get) {
    if (!get("shell.theme.sync")) return [];
    const s = v => "'" + v + "'";
    const dark = P.palette(get).dark;
    const font = s(FONT + " " + fontPt(get));
    return [
        ["color-scheme", s(dark ? "prefer-dark" : "prefer-light")],
        ["gtk-theme", s(dark ? "adw-gtk3-dark" : "adw-gtk3")],
        ["icon-theme", s(ICONS)],
        ["accent-color", s(GNOME_ACCENTS[get("shell.accent")] ?? "yellow")],
        ["cursor-size", String(get("niri.cursor.size"))],
        ["monospace-font-name", font],
        ["font-name", get("shell.theme.font") ? font : ""],
        ["document-font-name", get("shell.theme.font") ? font : ""]
    ];
}
