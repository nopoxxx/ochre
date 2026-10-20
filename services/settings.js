.pragma library
.import "settings/common.js" as C
.import "settings/layouts.js" as L
.import "settings/apps.js" as A
.import "settings/binds.js" as B
.import "settings/niri.js" as N
.import "settings/apptheme.js" as T
.import "settings/themes.js" as P
.import "settings/term.js" as TM

// Схема окна настроек; генерация ~/.config/niri/ochre/*.kdl — в settings/niri.js.
//   niri.*      — уходят в конфиг niri
//   shell.*     — читает quickshell
//   wallpaper.* — хранится в сервисе Wallpaper
//
// Остальное — в services/settings/*.js; здесь только схема окна настроек. QML видит всё через S.*:
// имена модулей отдаются отсюда как были (S.comboKey, S.niriFiles…).
var ACCENTS = C.ACCENTS, WIDTHS = C.WIDTHS, SHELL_ANIMS = C.SHELL_ANIMS, SHELL_ANIM_HINT = C.SHELL_ANIM_HINT, NIRI_ANIMS = C.NIRI_ANIMS, q = C.q, f = C.f, head = C.head, text = C.text, SHOT_TOOLS = C.SHOT_TOOLS, SHOT_COLORS = C.SHOT_COLORS;
var MODULES = L.MODULES, DEFAULT_LAYOUT = L.DEFAULT_LAYOUT, HOME_SECTIONS = L.HOME_SECTIONS, DEFAULT_HOME = L.DEFAULT_HOME, LAYOUTS = L.LAYOUTS, ZONES = L.ZONES, moduleById = L.moduleById, normalizeLayout = L.normalizeLayout, zoneOf = L.zoneOf, moveModule = L.moveModule, placeModule = L.placeModule, setZone = L.setZone, layoutZones = L.layoutZones, zoneLabel = L.zoneLabel, reorderModule = L.reorderModule, layoutRows = L.layoutRows, barRows = L.barRows;
var TRAY_ICONS = A.TRAY_ICONS, trayGlyph = A.trayGlyph, TERMINALS = A.TERMINALS, FILE_MANAGERS = A.FILE_MANAGERS, SHELLS = A.SHELLS, SHELL_PKGS = A.SHELL_PKGS, BROWSERS = A.BROWSERS, termClass = A.termClass, termCmd = A.termCmd, filesCmd = A.filesCmd;
var MUTE_BINDS = B.MUTE_BINDS, COMBO_RE = B.COMBO_RE, MODS = B.MODS, comboKey = B.comboKey, BIND_GROUPS = B.BIND_GROUPS, titleGroup = B.titleGroup, bindGroup = B.bindGroup, groupBinds = B.groupBinds, parseBinds = B.parseBinds, actionKdl = B.actionKdl, keysKdl = B.keysKdl;
var APP_ENV = N.APP_ENV, OPEN_SHADER = N.OPEN_SHADER, CLOSE_SHADER = N.CLOSE_SHADER, glslColor = N.glslColor, animBlocks = N.animBlocks, HOT_CORNERS = N.HOT_CORNERS, TRANSFORMS = N.TRANSFORMS, niriTransform = N.niriTransform, logicalSize = N.logicalSize, NIRI_FILES = N.NIRI_FILES, niriFileOf = N.niriFileOf, GAME_OFF = N.GAME_OFF, niriFiles = N.niriFiles, greeterNiri = N.greeterNiri;
var FONT = T.FONT, ICONS = T.ICONS, GNOME_ACCENTS = T.GNOME_ACCENTS, fontPt = T.fontPt, gtkColors = T.gtkColors, gtkCss = T.gtkCss, qtColors = T.qtColors, qtFont = T.qtFont, themeFiles = T.themeFiles, btopTheme = T.btopTheme, themeGsettings = T.themeGsettings, iconTheme = T.iconTheme, iconOverlay = T.iconOverlay;
var TERM_COLORS = TM.TERM_COLORS, TERM_INCLUDE = TM.TERM_INCLUDE, termFiles = TM.termFiles, termMigrate = TM.termMigrate, termOsc = TM.termOsc;
var THEMES = P.THEMES, ROLES = P.ROLES, mix = P.mix, palette = P.palette, themeStrip = P.themeStrip;

function themeLabels() {
    const out = {};
    for (const id in THEMES) out[id] = THEMES[id].name;
    return out;
}

// Строка раздела: { header } или { key, label, type, def, hint, … }.
// type: bool | int | float (min, max, step) | enum (options) | text | action (action — имя действия,
// обработчик в SettingsWindow.actions) | module (раздел bar/, строится barRows) | combo (сочетание клавиш:
// ↵ — захват нажатия, ⇥ — ввод текстом; action — его строка KDL для проверки конфликтов).
// У действий ключ action.<имя>: значения у них нет, ключ нужен только для поиска и подсказки.
function act(name, label, hint) {
    return { key: "action." + name, label, type: "action", action: name, hint: hint ?? "" };
}

// outputs: [{ name, scale, make, model, mode }] из `niri msg --json outputs`
// layout: текущее значение shell.bar.layout — из него строится раздел bar/
// home: значение shell.home.layout — из него строится раздел home/
function sections(outputs, layout, home) {
    return [
        { id: "look", title: "вид", rows: [
            { header: "цвет и шрифт" },
            { key: "shell.theme.name", label: "тема", type: "enum", options: Object.keys(THEMES), labels: themeLabels(), def: "gruvbox", hint: "палитра shell и приложений" },
            { key: "shell.theme.mode", label: "тёмная или светлая", type: "enum", options: ["dark", "light"], def: "dark",
              hint: "светлой нет у Nord и Dracula — у них остаётся тёмная; переключить: ochre ipc call theme toggle" },
            { key: "shell.accent", label: "акцентный цвет", type: "enum", options: Object.keys(ACCENTS), def: "ochre", hint: "рамки окон shell, prompt, рамка фокуса niri и акцент в приложениях" },
            { key: "shell.fontSize", label: "размер шрифта", type: "int", min: 10, max: 28, step: 1, def: 16 },
            { key: "shell.lang", label: "язык", type: "enum", options: ["auto", "ru", "en"], def: "auto",
              hint: "auto — по $LANG (нет перевода — английский); переводы — lang/<код>.json" },

            { header: "приложения" },
            { key: "shell.theme.sync", label: "темы Qt и GTK", type: "bool", def: true,
              hint: "схема (тёмная или светлая), палитра темы, акцент и иконки (Gruvbox Plus или Papirus с папками цвета акцента) в GTK (adw-gtk3, libadwaita) и Qt (qt6ct); открытые окна — после перезапуска приложения" },
            { key: "shell.theme.font", label: "шрифт shell в приложениях", type: "bool", def: true,
              hint: "Terminess в интерфейсе GTK- и Qt-приложений; моноширинный шрифт ставится всегда" },

            { header: "обои" },
            act("picker", "выбрать обои", "локальная коллекция ~/Pictures/Wallpapers (Mod+Shift+W); Ctrl+T — все экраны, экран или стол, Ctrl+N — день или ночь"),
            act("wallhaven", "найти на wallhaven", "поиск на wallhaven.cc, скачанные — в коллекцию"),
            { key: "shell.wallpaper.transition", label: "переход", type: "enum", options: ["type", "blocks", "scan", "fade", "none", "random"], def: "type",
              hint: "type — печатается строками, blocks — клетками, scan — развёрткой, fade — проявляется, random — каждый раз другой" },
            { key: "shell.wallpaper.interval", label: "слайдшоу", type: "int", min: 0, max: 240, step: 5, def: 30,
              hint: "минуты между картинками, если обоям экрана или стола назначена папка; 0 — не листать" },
            { key: "shell.wallpaper.order", label: "порядок слайдшоу", type: "enum", options: ["random", "cycle"], def: "random", hint: "random — случайно, cycle — по кругу" },
            { key: "wallpaper.fill", label: "заполнение", type: "enum", options: ["fill", "fit", "stretch"], def: "fill", hint: "fill — обрезать, fit — вписать с полосами, stretch — растянуть" },

            { header: "меню" },
            { key: "shell.launcher.rows", label: "строк в меню", type: "int", min: 6, max: 24, step: 1, def: 12, hint: "высота меню Mod+D" },
            { key: "shell.launcher.anim", label: "анимация меню", type: "enum", options: SHELL_ANIMS, def: "pop", hint: "меню Mod+D и Mod+Space; " + SHELL_ANIM_HINT },
            { key: "shell.launcher.frequent", label: "частые программы выше", type: "bool", def: true,
              hint: "apps/ и поиск учитывают, как часто и как давно запускали; счётчик — ~/.local/state/ochre/launcher.json" },
            { key: "shell.launcher.prefix.cmd", label: "префикс: команда", type: "text", def: ">", hint: "«> htop» в корне меню — запуск в окне терминала ochre-term; пусто — выключено" },
            { key: "shell.launcher.prefix.files", label: "префикс: файлы", type: "text", def: "/", hint: "«/отчёт» — поиск файлов (fd), ↵ — открыть; пусто — выключено" },
            { key: "shell.launcher.prefix.web", label: "префикс: веб-поиск", type: "text", def: "?", hint: "«? quickshell» — открыть поиск в браузере; пусто — выключено" },
            { key: "shell.launcher.prefix.emoji", label: "префикс: эмодзи", type: "text", def: ":", hint: "«:smile» — эмодзи по английскому имени, ↵ — в буфер; пусто — выключено" },
            { key: "shell.launcher.prefix.windows", label: "префикс: окна", type: "text", def: "@", hint: "«@firefox» — открытые окна niri, ↵ — перейти; пусто — выключено" },
            { key: "shell.launcher.prefix.install", label: "префикс: установить", type: "text", def: "+", hint: "«+htop» — пакеты pacman и строка AUR через paru; пустой запрос — обновить систему; пусто — выключено" },
            { key: "shell.launcher.prefix.remove", label: "префикс: удалить", type: "text", def: "-", hint: "«-htop» — установленные пакеты, ↵ — pacman -Rns; пусто — выключено" },
            { key: "shell.launcher.prefix.timer", label: "префикс: таймер", type: "text", def: "%", hint: "«%25m чай» — таймер; без срока — готовые и стоп; пусто — выключено" },
            { key: "shell.launcher.prefix.calc", label: "префикс: калькулятор", type: "text", def: "=", hint: "«=2^10» — калькулятор, ↵ — копировать ответ; пусто — выключено" },
            { key: "shell.launcher.files.dir", label: "где искать файлы", type: "text", def: "~", hint: "каталог для поиска файлов; скрытые и из .gitignore пропускаются" },
            { key: "shell.launcher.web", label: "поисковик", type: "enum", options: ["duckduckgo", "google", "startpage", "brave", "custom"], def: "duckduckgo",
              hint: "custom — адрес из строки ниже" },
            { key: "shell.launcher.web.url", label: "свой адрес поиска", type: "text", def: "https://duckduckgo.com/?q=%s", hint: "%s — запрос; используется при поисковике custom" },

            { header: "индикаторы" },
            { key: "shell.osd", label: "громкость и яркость", type: "bool", def: true, hint: "полоска на экране при изменении громкости или яркости — клавишами, колёсиком, из других программ" },
            { key: "shell.osd.position", label: "положение", type: "enum", options: ["bottom", "top", "center"], def: "bottom" },

            { header: "анимации" },
            { key: "shell.anim.speed", label: "скорость анимаций shell", type: "float", min: 0.25, max: 4, step: 0.25, def: 1,
              hint: "меню, home, уведомления: 2 — вдвое быстрее, 0.5 — вдвое медленнее; стили — в их разделах; окна niri — windows/ → анимации" }
        ] },

        { id: "windows", title: "окна", rows: [
            { header: "раскладка" },
            { key: "niri.gaps", label: "отступы", type: "int", min: 0, max: 64, step: 2, def: 8 },
            { key: "niri.colWidth", label: "ширина новой колонки", type: "enum", options: ["1/3", "1/2", "2/3", "1"], def: "1/2" },
            { key: "niri.center", label: "центрировать колонку", type: "enum", options: ["never", "always", "on-overflow"], def: "never" },

            { header: "рамки и тени" },
            { key: "niri.ring", label: "рамка фокуса", type: "int", min: 0, max: 12, step: 1, def: 2, hint: "толщина в px, 0 — выключить; цвет — акцент (look/)" },
            { key: "niri.border", label: "обводка окон", type: "int", min: 0, max: 12, step: 1, def: 0, hint: "толщина в px, 0 — выключить" },
            { key: "niri.shadow", label: "тени", type: "bool", def: false },
            { key: "niri.rules.radius", label: "скругление углов", type: "int", min: 0, max: 24, step: 2, def: 0, hint: "радиус в px, 0 — прямые углы" },

            { header: "поведение" },
            { key: "niri.rules.inactiveOpacity", label: "прозрачность неактивных, %", type: "int", min: 50, max: 100, step: 5, def: 100, hint: "100 — непрозрачные" },
            { key: "niri.csd", label: "без декораций приложений", type: "bool", def: true, hint: "prefer-no-csd: просить приложения не рисовать свои заголовки" },

            { header: "анимации" },
            { key: "niri.anim", label: "включены", type: "bool", def: true },
            { key: "niri.anim.style", label: "стиль", type: "enum", options: NIRI_ANIMS, def: "default",
              hint: "default — как в niri; snappy — коротко и резко; bouncy — пружины с отскоком; terminal — окно выводится строками с курсором, закрытое гаснет, как кинескоп" },
            { key: "niri.anim.slowdown", label: "замедление", type: "float", min: 0.25, max: 3, step: 0.25, def: 1 },

            { header: "игровой режим" },
            { key: "shell.game", label: "включён", type: "bool", def: false,
              hint: "анимации, тени и прозрачность неактивных niri выкл. — свои значения вернутся сами; Mod+Shift+G, home → быстро" },
            { key: "shell.game.dnd", label: "не беспокоить", type: "bool", def: true, hint: "пока включён — только критичные уведомления" }
        ] },

        { id: "input", title: "ввод", rows: [
            { header: "клавиатура" },
            { key: "niri.kb.layout", label: "раскладки", type: "text", def: "us,ru", hint: "XKB-раскладки через запятую, например us,ru,ua" },
            { key: "niri.kb.options", label: "опции xkb", type: "text", def: "grp:alt_shift_toggle", hint: "например grp:win_space_toggle,ctrl:nocaps" },
            { key: "niri.kb.repeatDelay", label: "задержка повтора, мс", type: "int", min: 150, max: 1000, step: 25, def: 600 },
            { key: "niri.kb.repeatRate", label: "скорость повтора, /с", type: "int", min: 10, max: 80, step: 5, def: 25 },
            { key: "niri.kb.numlock", label: "numlock при входе", type: "bool", def: true },

            { header: "клавиши" },
            act("binds", "бинды", "все сочетания niri и ochre: изменить, добавить, отключить"),
            act("hotkeys", "подсказка клавиш", "окно niri со всеми сочетаниями (Mod+Shift+/)"),
            { key: "niri.key.micMute", label: "мьют микрофона", type: "combo", def: "", action: MUTE_BINDS["niri.key.micMute"].action, hint: "вкл/выкл микрофон по умолчанию (wpctl); работает и на экране блокировки" },
            { key: "niri.key.audioMute", label: "мьют звука", type: "combo", def: "", action: MUTE_BINDS["niri.key.audioMute"].action, hint: "вкл/выкл звук на устройстве вывода по умолчанию — наушники или колонки (wpctl)" },

            { header: "горячие углы" },
            { key: "niri.hc.topLeft", label: "↖ левый верхний", type: "bool", def: true, hint: "курсор в угол экрана — обзор столов и окон (как Mod+Tab)" },
            { key: "niri.hc.topRight", label: "↗ правый верхний", type: "bool", def: false, hint: "курсор в угол экрана — обзор столов и окон" },
            { key: "niri.hc.bottomLeft", label: "↙ левый нижний", type: "bool", def: false, hint: "курсор в угол экрана — обзор столов и окон" },
            { key: "niri.hc.bottomRight", label: "↘ правый нижний", type: "bool", def: false, hint: "курсор в угол экрана — обзор столов и окон" },

            { header: "мышь и тачпад" },
            { key: "niri.tp.tap", label: "тап для клика", type: "bool", def: true, hint: "тачпад" },
            { key: "niri.tp.natural", label: "естественная прокрутка", type: "bool", def: true, hint: "тачпад" },
            { key: "niri.mouse.accel", label: "ускорение мыши", type: "float", min: -1, max: 1, step: 0.1, def: 0 },
            { key: "niri.mouse.profile", label: "профиль ускорения", type: "enum", options: ["adaptive", "flat"], def: "adaptive" },
            { key: "niri.ffm", label: "фокус следует за мышью", type: "bool", def: false },
            { key: "niri.warp", label: "курсор за фокусом", type: "bool", def: false, hint: "переносить курсор в окно, получившее фокус с клавиатуры" },

            { header: "курсор" },
            { key: "niri.cursor.size", label: "размер", type: "int", min: 16, max: 64, step: 4, def: 24 },
            { key: "niri.cursor.hide", label: "прятать при наборе", type: "bool", def: false }
        ] },

        { id: "bar", title: "панель", rows: [
            ...barRows(layout),

            { header: "панель" },
            { key: "shell.bar.position", label: "положение", type: "enum", options: ["top", "bottom"], def: "top" },
            { key: "shell.bar.height", label: "высота", type: "int", min: 18, max: 48, step: 2, def: 26 },
            { key: "shell.bar.style", label: "стиль", type: "enum", options: ["full", "floating"], def: "full", hint: "floating — с отступами от краёв и рамкой цвета акцента" },
            { key: "shell.bar.opacity", label: "непрозрачность, %", type: "int", min: 30, max: 100, step: 5, def: 100 },
            { key: "shell.bar.autohide", label: "автоскрытие", type: "bool", def: false, hint: "панель появляется при наведении мыши на край экрана" },
            { key: "shell.bar.monitors", label: "мониторы", type: "enum", options: ["all", "primary"], def: "all" },
            { key: "shell.bar.wheelWorkspaces", label: "колёсико — рабочие столы", type: "bool", def: true, hint: "прокрутка по панели листает столы её монитора; vol и kbd — своё колёсико" },
            { key: "shell.bar.separator", label: "разделитель", type: "enum", options: [" · ", " | ", " / ", " │ ", "  "], def: " · " },

            { header: "prompt" },
            { key: "shell.bar.prompt", label: "стиль prompt", type: "enum", options: ["user@host", "[user@host]", "user", "host"], def: "user@host" },
            { key: "shell.bar.symbol", label: "символ", type: "enum", options: ["❯", "$", "#", "λ", ">", "→"], def: "❯", hint: "красный, если какое-то окно требует внимания — как $? в shell" },
            { key: "shell.bar.typing", label: "эффект набора", type: "bool", def: true, hint: "новое активное окно «печатается» по символу" },
            { key: "shell.bar.titleMax", label: "длина команды", type: "int", min: 20, max: 160, step: 10, def: 80, hint: "максимум символов для приложения и заголовка" },

            { header: "модули" },
            { key: "shell.bar.clock", label: "формат часов", type: "enum", options: ["HH:mm", "HH:mm:ss", "ddd HH:mm", "dd.MM HH:mm"], def: "HH:mm" },
            { key: "shell.bar.cpuGraph", label: "график cpu", type: "bool", def: true, hint: "▂▃▅▇ — история загрузки, как в btop" },
            { key: "shell.bar.viz", label: "полоски звука в media", type: "bool", def: true, hint: "▁▃▅▇ после трека, пока играет; нужен cava" },
            { key: "shell.bar.trayStyle", label: "трей", type: "enum", options: ["icons", "names"], def: "icons", hint: "icons — значки Nerd Font для известных программ, остальные — первой буквой; names — короткие названия" },
            { key: "shell.bar.trayCollapsed", label: "трей свёрнут", type: "bool", def: false, hint: "на панели переключается кликом по ‹ / +N; просящие внимания видны всегда" },
            { key: "shell.bar.trayTyping", label: "анимация трея", type: "bool", def: true, hint: "названия печатаются при разворачивании и стираются при сворачивании" }
        ] },

        { id: "home", title: "меню home", rows: [
            ...layoutRows("shell.home.layout", home),

            { header: "меню" },
            act("home", "открыть", "клик по user@host на панели или Mod+A"),
            { key: "shell.home.style", label: "вид", type: "enum", options: ["control", "column", "dashboard", "classic"], def: "control",
              hint: "control — центр управления под панелью, wi-fi и bluetooth — страницами (› на плитке); column — колонка у края, секции карточками; dashboard — три колонки посередине; classic — как раньше" },
            { key: "shell.home.side", label: "край экрана", type: "enum", options: ["left", "right"], def: "left" },
            { key: "shell.home.width", label: "ширина, символов", type: "int", min: 40, max: 80, step: 2, def: 52 },
            { key: "shell.home.anim", label: "анимация", type: "enum", options: SHELL_ANIMS, def: "slide", hint: SHELL_ANIM_HINT },
            { key: "shell.home.lyrics", label: "текст песни", type: "bool", def: true, hint: "текущая строка под треком — LRCLIB (lrclib.net), ищется, пока меню открыто" },
            { key: "shell.home.viz", label: "полоски звука", type: "bool", def: true, hint: "▁▃▅▇ в «сейчас играет», пока меню открыто; нужен cava" },
            { key: "shell.viz.source", label: "звук для полосок", type: "enum", options: ["player", "system"], def: "player",
              hint: "player — только приложение, которое играет музыку (YouTube Music, Spotify…); system — всё, что звучит, и звонки тоже. И в home, и на панели" },

            { header: "погода" },
            { key: "shell.weather.city", label: "город", type: "text", def: "", hint: "например Москва или Berlin; пусто — по IP (ipinfo.io). Данные — Open-Meteo, без ключа" },
            { key: "shell.weather.units", label: "единицы", type: "enum", options: ["metric", "imperial"], def: "metric", hint: "metric — °C и м/с, imperial — °F и mph" },
            { key: "shell.weather.days", label: "прогноз, дней", type: "int", min: 0, max: 7, step: 1, def: 3 },

            { header: "ночной режим" },
            { key: "shell.night.on", label: "включён", type: "bool", def: false, hint: "тёплые цвета экрана (gammastep); переключатель — и в меню home" },
            { key: "shell.night.temp", label: "температура, K", type: "int", min: 2500, max: 6000, step: 100, def: 4000, hint: "меньше — теплее; днём — 6500" },
            { key: "shell.night.auto", label: "по закату", type: "bool", def: false, hint: "включённый режим действует от заката до рассвета в городе погоды; выключено — всё время" },

            { header: "запись экрана" },
            act("record", "начать / остановить", "Mod+Alt+R; во время записи на панели ● REC — клик останавливает"),
            { key: "shell.rec.target", label: "что записывать", type: "enum", options: ["region", "screen"], def: "region", hint: "region — выделить область (slurp), screen — монитор с фокусом" },
            { key: "shell.rec.audio", label: "звук", type: "enum", options: ["none", "system", "mic"], def: "none", hint: "system — то, что слышно в колонках, mic — микрофон по умолчанию" },
            { key: "shell.rec.dir", label: "папка", type: "text", def: "~/Videos/Screencasts" },
            { key: "shell.rec.notify", label: "уведомление", type: "bool", def: true, hint: "по окончании записи: путь к файлу, клик — открыть папку" }
        ] },

        { id: "notify", title: "уведомления", rows: [
            { header: "уведомления" },
            { key: "shell.notify.dnd", label: "не беспокоить", type: "bool", def: false, hint: "показывать только критичные; остальные — в истории (log на панели)" },
            { key: "shell.notify.position", label: "положение", type: "enum", options: ["top-right", "top-left", "bottom-right", "bottom-left"], def: "top-right" },
            { key: "shell.notify.timeout", label: "время показа, с", type: "int", min: 2, max: 60, step: 1, def: 6, hint: "если приложение не задало своё" },
            { key: "shell.notify.max", label: "максимум на экране", type: "int", min: 1, max: 10, step: 1, def: 4 },
            { key: "shell.notify.criticalSticky", label: "критичные не исчезают", type: "bool", def: true, hint: "ERROR висит, пока не закроете" },
            { key: "shell.notify.mute", label: "мьют микрофона и звука", type: "bool", def: true, hint: "уведомление, когда микрофон или звук по умолчанию выключается и включается — биндом, клавишей, pavucontrol" },
            { key: "shell.notify.typing", label: "эффект набора", type: "bool", def: true, hint: "заголовок уведомления печатается по символу" },
            { key: "shell.notify.anim", label: "анимация", type: "enum", options: SHELL_ANIMS, def: "slide", hint: "появление и исчезновение; slide — от края экрана. " + SHELL_ANIM_HINT },
            act("notifyTest", "проверить", "прислать тестовое уведомление")
        ] },

        { id: "lock", title: "блокировка", rows: [
            { header: "блокировка экрана" },
            { key: "shell.lock.idle", label: "блокировать через, мин", type: "int", min: 0, max: 60, step: 1, def: 10, hint: "после бездействия; 0 — не блокировать; видеоплееры могут запретить" },
            { key: "shell.lock.echo", label: "эхо пароля", type: "enum", options: ["*", "●", "none"], def: "*", hint: "none — как в консоли: ничего не видно при вводе" },
            { key: "shell.lock.clock", label: "часы", type: "bool", def: true, hint: "крупные часы как tty-clock" },
            { key: "shell.lock.motd", label: "фраза под приглашением", type: "bool", def: true, hint: "как motd в консоли: «с возвращением.», «идёт закат…» — каждый раз другая; и в greeter" },
            { key: "shell.lock.wallpaper", label: "обои на фоне", type: "bool", def: true, hint: "приглушённые текущие обои под приглашением" },
            act("lockPreview", "предпросмотр", "экран блокировки без проверки пароля; Esc — закрыть"),
            act("lock", "заблокировать сейчас", "Super+Alt+L")
        ] },

        { id: "system", title: "система", rows: [
            { header: "устройства" },
            act("displays", "мониторы", (outputs ?? []).map(o => o.name).join(", ") + " — режим, масштаб, поворот, расположение, VRR"),
            act("wifi", "сеть", "nmtui — Wi-Fi и проводные подключения"),
            act("audio", "звук", "pavucontrol — устройства и громкость приложений; быстрый микшер — клик по vol на панели"),

            { header: "приложения" },
            { key: "shell.terminal", label: "терминал", type: "enum", options: TERMINALS, def: "kitty", hint: "Mod+Return и окна, которые открывает shell (обновления, nmtui, …)" },
            { key: "shell.files", label: "файловый менеджер", type: "enum", options: FILE_MANAGERS, def: "none", hint: "Mod+E; yazi — в терминале" },
            { key: "shell.sh", label: "оболочка", type: "enum", options: SHELLS, def: "zsh", hint: "chsh в терминале (спросит пароль), действует с нового входа; нет пакета — поставит" },
            { key: "shell.browser", label: "браузер", type: "enum", options: Object.keys(BROWSERS), def: "none", hint: "Mod+Shift+B и браузер по умолчанию (xdg-settings); нет пакета — поставит через paru" },

            { header: "скриншоты" },
            { key: "shell.shot.dir", label: "папка", type: "text", def: "~/Pictures/Screenshots", hint: "куда сохраняет ^S; Mod+Shift+S или Print — снимок с разметкой" },
            { key: "shell.shot.enter", label: "по ↵", type: "enum", options: ["copy", "save", "both"], def: "copy", hint: "что делает ↵ в редакторе; ^C — копировать, ^S — сохранить, ⇧↵ — и то и другое" },
            { key: "shell.shot.notify", label: "уведомление", type: "bool", def: true, hint: "после копирования или сохранения" },
            { key: "shell.shot.tool", label: "инструмент", type: "enum", options: SHOT_TOOLS, def: "rect", hint: "последний выбранный в редакторе" },
            { key: "shell.shot.color", label: "цвет", type: "enum", options: SHOT_COLORS, def: "red", hint: "последний выбранный в редакторе (1-9)" },
            { key: "shell.shot.width", label: "толщина", type: "int", min: 1, max: 12, step: 1, def: 3, hint: "линий, текста и шагов ([ ] или колёсико в редакторе)" },

            { header: "конфиги" },
            act("editNiri", "niri", "~/.config/niri/config.kdl — свои настройки niri; ochre/ генерирует shell"),
            act("editShell", "код shell", "~/.config/quickshell/ — QML и JS ochre"),
            act("editTerminal", "терминал", "конфиг выбранного терминала"),

            { header: "ochre" },
            act("shellUpdate", "обновить", "git pull и перезапуск; если новых коммитов нет — проверить (ochre ↑ на панели)"),
            { key: "shell.update.check", label: "проверять обновления", type: "bool", def: true, hint: "git fetch в папке shell; нужен git-клон и доступ к репозиторию" },
            { key: "shell.update.hours", label: "раз в, ч", type: "int", min: 1, max: 48, step: 1, def: 6 },
            { key: "shell.update.notify", label: "уведомлять", type: "bool", def: true, hint: "уведомление, когда появились новые коммиты" },
            { key: "shell.cast", label: "выбор демонстрации экрана", type: "bool", def: true, hint: "окно ochre вместо GTK-диалога, когда Discord, браузер или OBS просят показать экран; выключено — снова GNOME" },
            { key: "shell.polkit", label: "polkit-агент", type: "bool", def: true, hint: "запрос пароля pkexec, systemctl и т.п. окном ochre вместо polkit-gnome" },
            { key: "shell.errors", label: "показывать ошибки", type: "bool", def: true, hint: "окно ~/log/errors: ошибки QML shell и конфига niri, как лог компилятора" },
            act("restartShell", "перезапустить shell", "qs kill и запуск заново"),
            act("report", "сообщить о проблеме", "архив логов в ~/Downloads и новый issue на GitHub с версиями и ошибками; архив прикрепить вручную"),
            act("greeterUpdate", "обновить greeter", "переустановить экран входа из текущего shell (sudo)")
        ] }
    ];
}

// поиск по всем разделам: каждое слово запроса — подстрока подписи, подсказки, ключа, заголовка группы
// или имени раздела. Строки остаются как есть (плюс section — индекс раздела) и группируются под
// заголовками «раздел/ · группа» — по одной подписи («размер») не понять, чего она касается.
// tr — перевод (I18n.tr): ищем и по исходной строке, и по переводу; заголовок результата — уже переведённый
function searchRows(secs, query, tr) {
    const t = tr ?? (x => x);
    const words = String(query).toLowerCase().split(/\s+/).filter(w => w);
    const out = [];
    secs.forEach((s, i) => {
        let group = "", shown = "";
        for (const r of s.rows) {
            if (r.header) { group = r.header; continue; }
            // у модулей панели общий ключ shell.bar.layout — ищем по их id
            const fields = [r.label, r.hint, r.type === "module" ? r.id : r.key, group, s.id, s.title, t(r.label), t(r.hint), t(group), t(s.title)];
            if (!words.every(w => fields.some(x => String(x ?? "").toLowerCase().includes(w)))) continue;
            const h = s.id + "/ · " + t(group);
            if (h !== shown) out.push({ header: shown = h });
            out.push(Object.assign({ section: i }, r));
        }
    });
    return out;
}

function find(key, outputs) {
    for (const s of sections(outputs, null))
        for (const r of s.rows)
            if (r.key === key && r.type !== "module") return r;
    return null;
}

function defaultOf(key, outputs) {
    if (key in LAYOUTS) return JSON.parse(JSON.stringify(LAYOUTS[key].def));
    return find(key, outputs)?.def;
}
