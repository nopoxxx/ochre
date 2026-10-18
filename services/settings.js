.pragma library

// Схема окна настроек и генерация ~/.config/niri/ochre/*.kdl.
//   niri.*      — уходят в конфиг niri
//   shell.*     — читает quickshell
//   wallpaper.* — хранится в сервисе Wallpaper

// ochre — цвет бренда (gruvbox neutral yellow), он же по умолчанию; остальные — bright-цвета палитры
const ACCENTS = {
    ochre: "#d79921",
    yellow: "#fabd2f",
    orange: "#fe8019",
    green: "#b8bb26",
    aqua: "#8ec07c",
    blue: "#83a598",
    purple: "#d3869b",
    red: "#fb4934"
};

const WIDTHS = { "1/3": "0.33333", "1/2": "0.5", "2/3": "0.66667", "1": "1.0" };

// анимации: окна shell (Reveal.qml) — меню Mod+D, меню home, уведомления; пресеты niri — animBlocks()
var SHELL_ANIMS = ["slide", "fade", "pop", "unfold", "type", "none"];
const SHELL_ANIM_HINT = "slide — выезжает, fade — проявляется, pop — вырастает из центра, unfold — разворачивается сверху вниз, type — печатается по символу из случайных знаков";
var NIRI_ANIMS = ["default", "snappy", "bouncy", "terminal"];

// ── модули панели ──────────────────────────────────────────────────
// file — bar/<file>.qml; inline — часть prompt: между двумя inline-модулями пробел, а не разделитель

const MODULES = [
    { id: "user", file: "User", inline: true, desc: "user@host — стиль в bar/ → prompt" },
    { id: "workspaces", file: "Workspaces", inline: true, desc: "~/ws/{1,[2],3}: клик — перейти; колёсико по панели — листать" },
    { id: "jobs", file: "Jobs", inline: true, desc: "[3] — число окон на текущем столе" },
    { id: "command", file: "Command", inline: true, desc: "❯ активное окно как набранная команда" },
    { id: "media", file: "Media", desc: "♪ плеер: клик — пауза, правый — следующий, средний — предыдущий" },
    { id: "privacy", file: "Privacy", desc: "mic app · cast app — кто слушает микрофон и показывает экран; иначе скрыт" },
    { id: "timer", file: "Countdown", desc: "timer 04:32 — таймер (меню: timer 25m чай); клик — пауза, правый — стоп; иначе скрыт" },
    { id: "tray", file: "Tray", desc: "[трей] текстом: клик — открыть, правый — меню" },
    { id: "cpu", file: "Cpu", desc: "загрузка cpu, клик — процессы" },
    { id: "mem", file: "Mem", desc: "память, клик — процессы" },
    { id: "gpu", file: "Gpu", desc: "загрузка и температура amdgpu" },
    { id: "temp", file: "Temp", desc: "температура cpu (k10temp / coretemp)" },
    { id: "netspeed", file: "NetSpeed", desc: "скорость сети ↓↑" },
    { id: "net", file: "Net", desc: "сеть: eth / wifi / offline, клик — nmtui" },
    { id: "vol", file: "Vol", desc: "громкость: колёсико, клик — микшер, правый — mute" },
    { id: "bat", file: "Bat", desc: "батарея — видна только на ноутбуках" },
    { id: "updates", file: "Upd", desc: "обновления: клик — paru -Syu, правый — проверить" },
    { id: "shellupd", file: "ShellUpd", desc: "ochre ↑3 — обновления ochre с GitHub: клик — список и [обновить]" },
    { id: "notify", file: "Notify", desc: "уведомления: клик — история, правый — «не беспокоить»" },
    { id: "kbd", file: "Kbd", desc: "раскладка, клик — переключить" },
    { id: "clock", file: "Clock", desc: "часы, клик — календарь" },
    { id: "rec", file: "Rec", desc: "● REC 01:23 — идёт запись экрана, клик — остановить (видно только во время записи)" },
    { id: "home", file: "Home", desc: "значок меню home — для тех, у кого user@host убран с панели" }
];

const DEFAULT_LAYOUT = {
    left: ["user", "workspaces", "jobs", "command"],
    center: [],
    right: ["media", "rec", "privacy", "timer", "tray", "cpu", "mem", "net", "vol", "bat", "shellupd", "updates", "notify", "kbd", "clock"]
};

// ── секции меню home (клик по user@host, Mod+A) ────────────────────
// file — home/<file>.qml, label — подпись в настройках (= заголовок секции). Секция без устройства (bluetooth, батарея, подсветка) прячется сама.

// dash — колонка секции в виде dashboard (0 — управление, 1 — медиа и время, 2 — списки)
const HOME_SECTIONS = [
    { id: "user", dash: 0, label: "whoami", file: "User", desc: "user@host, время работы, ядро" },
    { id: "quick", dash: 0, label: "быстро", file: "Quick", desc: "переключатели: wifi, bluetooth, ночной режим, не беспокоить, микрофон" },
    { id: "levels", dash: 0, label: "звук и экран", file: "Levels", desc: "громкость, микрофон, яркость (если есть подсветка экрана)" },
    { id: "media", dash: 1, label: "сейчас играет", file: "Media", desc: "плеер: обложка, трек, прогресс, кнопки; несколько плееров — ‹ › переключают" },
    { id: "weather", dash: 1, label: "погода", file: "Weather", desc: "погода Open-Meteo: сейчас и на несколько дней; город — ниже, в погоде" },
    { id: "calendar", dash: 1, label: "календарь", file: "Calendar", desc: "календарь месяца: ←→ — листать" },
    { id: "todo", dash: 2, label: "todo", file: "Todo", desc: "список дел ~/.config/ochre/todo.txt: ↵ — сделано, a — добавить, del — удалить, e — редактор" },
    { id: "notes", dash: 2, label: "заметки", file: "Notes", desc: "начало ~/.config/ochre/notes.md; ↵ — открыть в редакторе" },
    { id: "notifs", dash: 2, label: "уведомления", file: "Notifs", desc: "последние уведомления: ↵ — действие, del — убрать" },
    { id: "system", dash: 1, label: "система", file: "System", desc: "cpu, память, диск, температура" },
    { id: "power", dash: 0, label: "питание", file: "Power", desc: "батарея и профиль питания (power-profiles-daemon)" },
    { id: "wifi", dash: 2, label: "wi-fi", file: "Wifi", desc: "сети Wi-Fi: подключиться, отключиться, пароль" },
    { id: "bluetooth", dash: 2, label: "bluetooth", file: "Bluetooth", desc: "устройства bluetooth: подключить, сопряжение, забыть" },
    { id: "actions", dash: 0, label: "действия", file: "Actions", desc: "запись экрана, настройки, блокировка, сон, выход, перезагрузка, выключение" }
];

const DEFAULT_HOME = {
    on: ["user", "quick", "levels", "media", "weather", "calendar", "todo", "notifs", "system", "power", "wifi", "bluetooth", "actions"]
};

// ── раскладки: модули панели и секции home устроены одинаково ──────
// items — что раскладываем, zones — куда (последняя — «выключены»), labels — подписи зон в настройках.
// off хранится явно: элемент, которого нет ни в одной зоне и ни в off, — новый (появился после обновления)
// и встаёт в свою зону по умолчанию, а не пропадает в «выключенных».

const LAYOUTS = {
    "shell.bar.layout": { items: MODULES, zones: ["left", "center", "right", "off"], def: DEFAULT_LAYOUT,
                          labels: { left: "left", center: "center", right: "right", off: "выключены" },
                          hint: "←→ зона, ↵ — применить, ⇧↑↓ или K/J — порядок" },
    "shell.home.layout": { items: HOME_SECTIONS, zones: ["on", "off"], def: DEFAULT_HOME,
                           labels: { on: "показаны", off: "скрыты" },
                           hint: "←→ показать / скрыть, ↵ — применить, ⇧↑↓ или K/J — порядок" }
};
const ZONES = LAYOUTS["shell.bar.layout"].zones;

function moduleById(id, key) {
    return LAYOUTS[key ?? "shell.bar.layout"].items.find(m => m.id === id) ?? null;
}

// убирает неизвестные и повторяющиеся id; новые — в зону по умолчанию
function normalizeLayout(l, key) {
    const L = LAYOUTS[key ?? "shell.bar.layout"];
    const src = l ?? L.def;
    const seen = new Set();
    const out = {};
    for (const z of L.zones) out[z] = [];
    for (const z of L.zones)
        for (const id of src[z] ?? [])
            if (L.items.some(m => m.id === id) && !seen.has(id)) {
                seen.add(id);
                out[z].push(id);
            }
    for (const m of L.items) {
        if (seen.has(m.id)) continue;
        const z = L.zones.find(z => (L.def[z] ?? []).includes(m.id)) ?? "off";
        // рядом с соседом по раскладке по умолчанию: rec — после media, а не в конце после clock;
        // соседа слева нет (media выключен) — перед соседом справа
        const def = L.def[z] ?? [];
        const at = def.indexOf(m.id);
        const prev = def.slice(0, at).reverse().find(id => out[z].includes(id));
        const next = def.slice(at + 1).find(id => out[z].includes(id));
        out[z].splice(prev ? out[z].indexOf(prev) + 1 : next ? out[z].indexOf(next) : out[z].length, 0, m.id);
    }
    return out;
}

function zoneOf(l, id, key) {
    const n = normalizeLayout(l, key);
    return LAYOUTS[key ?? "shell.bar.layout"].zones.find(z => n[z].includes(id));
}

// перенос в соседнюю зону (по кругу, последняя — off), элемент встаёт в конец
function moveModule(l, id, d, key) {
    const zones = LAYOUTS[key ?? "shell.bar.layout"].zones;
    const n = normalizeLayout(l, key);
    const from = zones.find(z => n[z].includes(id));
    const to = zones[(zones.indexOf(from) + d + zones.length) % zones.length];
    n[from] = n[from].filter(x => x !== id);
    n[to].push(id);
    return n;
}

// перетаскивание в окне настроек: id — в зону zone перед элементом before (null — в конец зоны)
function placeModule(l, id, zone, before, key) {
    const L = LAYOUTS[key ?? "shell.bar.layout"];
    const n = normalizeLayout(l, key);
    const out = {};
    for (const z of L.zones) out[z] = n[z].filter(x => x !== id);
    const i = before && before !== id ? out[zone].indexOf(before) : -1;
    out[zone].splice(i >= 0 ? i : out[zone].length, 0, id);
    return out;
}

// поставить в зону (в конец); строки раскладки в окне настроек меняют зону черновиком и применяют этим
function setZone(l, id, zone, key) {
    const n = normalizeLayout(l, key);
    for (const z of LAYOUTS[key ?? "shell.bar.layout"].zones) n[z] = n[z].filter(x => x !== id);
    n[zone].push(id);
    return n;
}

function layoutZones(key) { return LAYOUTS[key ?? "shell.bar.layout"].zones; }
function zoneLabel(key, zone) { return LAYOUTS[key ?? "shell.bar.layout"].labels[zone] ?? zone; }

// сдвиг внутри зоны; null — двигать некуда
function reorderModule(l, id, d, key) {
    const n = normalizeLayout(l, key);
    const z = LAYOUTS[key ?? "shell.bar.layout"].zones.slice(0, -1).find(z => n[z].includes(id));
    if (!z) return null;
    const a = n[z], i = a.indexOf(id), j = i + d;
    if (j < 0 || j >= a.length) return null;
    [a[i], a[j]] = [a[j], a[i]];
    return n;
}

function layoutRows(key, layout) {
    const L = LAYOUTS[key];
    const n = normalizeLayout(layout, key);
    const rows = [];
    for (const z of L.zones) {
        rows.push({ header: L.labels[z] });
        for (const id of n[z])
            rows.push({ type: "module", id, zone: z, zoneLabel: L.labels[z], label: moduleById(id, key).label ?? id, key, hint: moduleById(id, key).desc + "  ·  " + L.hint });
    }
    return rows;
}

function barRows(layout) { return layoutRows("shell.bar.layout", layout); }

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
            { key: "shell.accent", label: "акцентный цвет", type: "enum", options: Object.keys(ACCENTS), def: "ochre", hint: "рамки окон shell, prompt, рамка фокуса niri и акцент в приложениях" },
            { key: "shell.fontSize", label: "размер шрифта", type: "int", min: 10, max: 28, step: 1, def: 16 },

            { header: "приложения" },
            { key: "shell.theme.sync", label: "темы Qt и GTK", type: "bool", def: true,
              hint: "тёмная схема, палитра Gruvbox, акцент и иконки Gruvbox Plus в GTK (adw-gtk3, libadwaita) и Qt (qt6ct); открытые окна — после перезапуска приложения" },
            { key: "shell.theme.font", label: "шрифт shell в приложениях", type: "bool", def: true,
              hint: "Terminess в интерфейсе GTK- и Qt-приложений; моноширинный шрифт ставится всегда" },

            { header: "обои" },
            act("picker", "выбрать обои", "локальная коллекция ~/Pictures/Wallpapers (Mod+Shift+W)"),
            act("wallhaven", "найти на wallhaven", "поиск на wallhaven.cc, скачанные — в коллекцию"),
            { key: "shell.wallpaper.transition", label: "переход", type: "enum", options: ["type", "blocks", "scan", "fade", "none", "random"], def: "type",
              hint: "type — печатается строками, blocks — клетками, scan — развёрткой, fade — проявляется, random — каждый раз другой" },
            { key: "wallpaper.fill", label: "заполнение", type: "enum", options: ["fill", "fit", "stretch"], def: "fill", hint: "fill — обрезать, fit — вписать с полосами, stretch — растянуть" },

            { header: "меню" },
            { key: "shell.launcher.rows", label: "строк в меню", type: "int", min: 6, max: 24, step: 1, def: 12, hint: "высота меню Mod+D" },
            { key: "shell.launcher.anim", label: "анимация меню", type: "enum", options: SHELL_ANIMS, def: "pop", hint: "меню Mod+D и Mod+Space; " + SHELL_ANIM_HINT },

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
            act("greeterUpdate", "обновить greeter", "переустановить экран входа из текущего shell (sudo)")
        ] }
    ];
}

// поиск по всем разделам: каждое слово запроса — подстрока подписи, подсказки, ключа, заголовка группы
// или имени раздела. Строки остаются как есть (плюс section — индекс раздела) и группируются под
// заголовками «раздел/ · группа» — по одной подписи («размер») не понять, чего она касается.
function searchRows(secs, query) {
    const words = String(query).toLowerCase().split(/\s+/).filter(w => w);
    const out = [];
    secs.forEach((s, i) => {
        let group = "", shown = "";
        for (const r of s.rows) {
            if (r.header) { group = r.header; continue; }
            // у модулей панели общий ключ shell.bar.layout — ищем по их id
            const fields = [r.label, r.hint, r.type === "module" ? r.id : r.key, group, s.id, s.title];
            if (!words.every(w => fields.some(x => String(x ?? "").toLowerCase().includes(w)))) continue;
            const h = s.id + "/ · " + group;
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

// ── генерация KDL ──────────────────────────────────────────────────

const q = s => JSON.stringify(String(s));
const f = x => Number(x).toFixed(2);

// окружение программ при включённых темах (shell.theme.sync). niri получает его блоком environment в misc.kdl,
// но выдаёт только тому, что запустит после этого; программам, которые запускает сам shell, — Settings.appEnv()
var APP_ENV = { QT_QPA_PLATFORMTHEME: "qt6ct" };

// ── анимации niri ──────────────────────────────────────────────────

// terminal: окно выводится строками сверху вниз, курсор █ цвета акцента — в начале следующей строки
const OPEN_SHADER = [
    "vec4 open_color(vec3 coords_geo, vec3 size_geo) {",
    "    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)",
    "        return vec4(0.0);",
    "    float row = 24.0 / size_geo.y;",
    "    float done = floor(niri_clamped_progress * ceil(1.0 / row)) * row;",
    "    if (coords_geo.y < done)",
    "        return texture2D(niri_tex, (niri_geo_to_tex * coords_geo).st);",
    "    float px = coords_geo.x * size_geo.x;",
    "    if (niri_clamped_progress < 1.0 && coords_geo.y < done + row && px >= 4.0 && px < 16.0)",
    "        return ACCENT;",
    "    return vec4(0.0);",
    "}"
];

// terminal: закрытое окно сжимается в линию, линия — в точку и гаснет, как выключенный кинескоп
const CLOSE_SHADER = [
    "vec4 close_color(vec3 coords_geo, vec3 size_geo) {",
    "    float p = niri_clamped_progress;",
    "    float sy = max(1.0 - p / 0.6, 2.0 / size_geo.y);",
    "    float sx = max(1.0 - max(p - 0.6, 0.0) / 0.4, 0.002);",
    "    vec2 c = (coords_geo.xy - 0.5) / vec2(sx, sy) + 0.5;",
    "    if (c.x < 0.0 || c.x > 1.0 || c.y < 0.0 || c.y > 1.0)",
    "        return vec4(0.0);",
    "    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * vec3(c, 1.0)).st);",
    "    color.rgb = mix(color.rgb, vec3(color.a), smoothstep(0.2, 0.6, p));",
    "    return color * (1.0 - smoothstep(0.85, 1.0, p));",
    "}"
];

// "#fabd2f" → "vec4(0.980, 0.741, 0.184, 1.0)"
function glslColor(hex) {
    const n = [1, 3, 5].map(i => (parseInt(hex.substr(i, 2), 16) / 255).toFixed(3));
    return "vec4(" + n.join(", ") + ", 1.0)";
}

// строки внутрь animations { } для пресета
function animBlocks(style, accent) {
    const block = (name, body) => ["    " + name + " {", ...body.map(l => l === "" ? "" : "        " + l), "    }"];
    const ease = (ms, curve) => ["duration-ms " + ms, "curve " + q(curve)];
    const spring = (d, k, e) => ["spring damping-ratio=" + d + " stiffness=" + k + " epsilon=" + e];
    // в сыром KDL-строке r"…" нет экранирования — в шейдерах не должно быть кавычек
    const shader = lines => ["custom-shader r\"", ...lines.map(l => "    " + l.replace("ACCENT", glslColor(accent))), "\""];
    switch (style) {
    case "snappy": return [
        ...block("workspace-switch", ease(150, "ease-out-cubic")),
        ...block("horizontal-view-movement", ease(150, "ease-out-cubic")),
        ...block("window-movement", ease(120, "ease-out-cubic")),
        ...block("window-resize", ease(120, "ease-out-cubic")),
        ...block("window-open", ease(100, "ease-out-expo")),
        ...block("window-close", ease(80, "ease-out-quad")),
        ...block("overview-open-close", ease(150, "ease-out-cubic"))
    ];
    case "bouncy": return [
        ...block("workspace-switch", spring(0.7, 800, 0.0001)),
        ...block("horizontal-view-movement", spring(0.7, 600, 0.0001)),
        ...block("window-movement", spring(0.65, 600, 0.0001)),
        ...block("window-resize", spring(0.75, 600, 0.0001)),
        ...block("window-open", spring(0.6, 600, 0.001)),
        ...block("overview-open-close", spring(0.75, 700, 0.0001))
    ];
    case "terminal": return [
        ...block("window-open", [...ease(240, "linear"), ...shader(OPEN_SHADER)]),
        ...block("window-close", [...ease(260, "linear"), ...shader(CLOSE_SHADER)])
    ];
    default: return [];
    }
}

// горячие углы: ключ настройки → имя угла в niri (gestures { hot-corners { … } })
var HOT_CORNERS = [["niri.hc.topLeft", "top-left"], ["niri.hc.topRight", "top-right"],
    ["niri.hc.bottomLeft", "bottom-left"], ["niri.hc.bottomRight", "bottom-right"]];

// ── скриншоты (ShotWindow) ───────────────────────────────────────────
var SHOT_TOOLS = ["rect", "ellipse", "line", "arrow", "pen", "marker", "text", "step", "blur", "pixel"];
var SHOT_COLORS = ["red", "orange", "yellow", "green", "aqua", "blue", "purple", "white", "black"];   // = ShotWindow.colors

// ── свои сочетания из настроек (type: "combo") ─────────────────────
// Пустое значение — бинда нет. action — готовая строка KDL: по ней Binds.conflict отличает этот бинд от чужих.
var MUTE_BINDS = {
    "niri.key.micMute": { title: "Mute Microphone", action: 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"' },
    "niri.key.audioMute": { title: "Mute Audio", action: 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"' }
};

// в KDL сочетание идёт без кавычек — пропускаем только имена клавиш и модификаторы через «+»
var COMBO_RE = /^[A-Za-z0-9_]+(\+[A-Za-z0-9_]+)*$/;

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

// ── бинды ──────────────────────────────────────────────────────────

var MODS = ["mod", "super", "ctrl", "alt", "shift", "iso_level3_shift", "iso_level5_shift"];

// ключ для сравнения: регистр и порядок модификаторов не важны, Control = Ctrl
function comboKey(c) {
    const parts = String(c).split("+").map(s => s.trim().toLowerCase()).filter(s => s);
    const key = parts.pop() ?? "";
    const mods = parts.map(m => m === "control" ? "ctrl" : m)
        .sort((a, b) => MODS.indexOf(a) - MODS.indexOf(b));
    return mods.concat([key]).join("+");
}

// группы в окне биндов: подпись «Группа: …» (как у SekaiPop, от двух биндов) — её группа, иначе по действию niri; порядок — BIND_GROUPS
const BIND_GROUPS = ["ochre", "программы", "окна", "фокус", "перемещение", "размеры", "столы", "мониторы", "звук и медиа",
                     "скриншоты", "система", "отключено", "прочее"];

function titleGroup(b) {
    const m = String(b.title ?? "").match(/^([^:]{2,24}):\s+\S/);
    return m ? m[1].trim() : "";
}

function bindGroup(b) {
    const a = String(b.action ?? "");
    if (b.off || a === "off") return "отключено";
    if (/^spawn(-sh)? "qs" "ipc"|^spawn(-sh)? "ochre" "ipc"/.test(a)) return "ochre";
    if (/^spawn/.test(a)) return /wpctl|playerctl|pactl|brightnessctl|pamixer/.test(a) ? "звук и медиа" : "программы";
    if (/screenshot/.test(a)) return "скриншоты";
    if (/workspace/.test(a)) return "столы";
    if (/monitor/.test(a)) return "мониторы";
    if (/^focus-|^switch-focus/.test(a)) return "фокус";
    if (/^(move-|consume|expel|swap)/.test(a)) return "перемещение";
    if (/width|height|maximize|fullscreen|expand-column|center-/.test(a)) return "размеры";
    if (/^(close-window|toggle-window|toggle-column|toggle-overview)/.test(a)) return "окна";
    if (/^(quit|power-|suspend|show-hotkey|toggle-keyboard|toggle-debug|do-screen)/.test(a)) return "система";
    return "прочее";
}

// список с заголовками групп: [{header, count} | {b, pos: []}]; группы из подписей — после известных, по алфавиту
function groupBinds(list) {
    // группа из подписи — только если в ней хотя бы два бинда: «Browser: helium» у ochre одна, её место — по действию
    const n = {};
    for (const b of list) { const t = titleGroup(b); if (t) n[t] = (n[t] ?? 0) + 1; }
    const by = {};
    for (const b of list) {
        const t = titleGroup(b), g = n[t] > 1 ? t : bindGroup(b);
        (by[g] = by[g] ?? []).push(b);   // ??= движок QML не понимает
    }
    const names = Object.keys(by).sort((x, y) => {
        const i = BIND_GROUPS.indexOf(x), j = BIND_GROUPS.indexOf(y);
        return (i < 0 ? 99 : i) - (j < 0 ? 99 : j) || x.localeCompare(y);
    });
    // своя группа из подписи — сразу после «ochre», а не в конце рядом с «прочее»
    const known = names.filter(n => BIND_GROUPS.includes(n)), own = names.filter(n => !BIND_GROUPS.includes(n));
    const k = known[0] === "ochre" ? 1 : 0;
    const order = known.slice(0, k).concat(own, known.slice(k));
    // flatMap движок QML не знает
    return order.reduce((out, n) => out.concat([{ header: n, count: by[n].length }], by[n].map(b => ({ b, pos: [] }))), []);
}

// однострочные бинды из блоков binds { … }: [{ combo, title, hidden, action, source }]
function parseBinds(text, source) {
    const out = [];
    let inBinds = false;
    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.trim();
        if (!inBinds) {
            if (/^binds\s*\{\s*$/.test(line)) inBinds = true;
            continue;
        }
        if (line === "}") { inBinds = false; continue; }
        if (line.startsWith("//") || line.startsWith("/-")) continue;
        const m = line.match(/^([A-Za-z0-9_]+(?:\+[A-Za-z0-9_]+)*)((?:\s+[a-z-]+=(?:"[^"]*"|[^\s{]+))*)\s*\{\s*(.*?)\s*\}\s*(?:\/\/.*)?$/);
        if (!m) continue;
        const t = m[2].match(/hotkey-overlay-title=(?:"([^"]*)"|null)/);
        out.push({
            combo: m[1],
            title: t?.[1] ?? "",
            hidden: /hotkey-overlay-title=null/.test(m[2]),
            action: m[3].replace(/;\s*$/, ""),
            source
        });
    }
    return out;
}

// действие, как его ввёл человек, → KDL:
//   close-window → close-window      focus-workspace 3 → focus-workspace 3
//   spawn kitty → spawn "kitty"      spawn kitty -e btop → spawn-sh "kitty -e btop"
//   с кавычками — как есть
function actionKdl(a) {
    a = String(a ?? "").trim().replace(/;\s*$/, "");
    if (!a || a.includes('"')) return a;
    const [name, ...args] = a.split(/\s+/);
    if (name === "spawn-sh" || (name === "spawn" && args.length > 1)) return "spawn-sh " + JSON.stringify(args.join(" "));
    return [name, ...args.map(x => /^-?\d+(\.\d+)?$/.test(x) ? x : JSON.stringify(x))].join(" ");
}

// keys: { comboKey: { combo, action, title } }; action "off" — сочетание отключено
function keysKdl(keys) {
    const lines = [
        "// ochre: свои бинды — окно биндов (Mod+S → input/ → бинды), из ~/.config/ochre/settings.json.",
        "// Подключается в config.kdl последним (include \"ochre/keys.kdl\") и перекрывает одноимённые бинды.",
        "// Ручные правки перезапишутся.",
        "",
        "binds {"
    ];
    for (const k in keys) {
        const b = keys[k];
        if (b.action === "off")
            lines.push("    " + b.combo + ' hotkey-overlay-title=null { spawn "true"; }');
        else
            lines.push("    " + b.combo + (b.title ? " hotkey-overlay-title=" + JSON.stringify(b.title) : "")
                + " { " + actionKdl(b.action) + "; }");
    }
    lines.push("}");
    return lines.join("\n") + "\n";
}

// ── мониторы ───────────────────────────────────────────────────────

var TRANSFORMS = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"];

// transform из JSON niri («Normal», «_90», «Flipped90») → значение для конфига
function niriTransform(t) {
    const s = String(t ?? "normal").toLowerCase().replace(/^_/, "");
    if (s === "flipped" || !s.startsWith("flipped")) return s;
    return "flipped-" + s.slice(7);
}

// логический размер: пиксели режима / масштаб, при повороте на 90° стороны меняются
function logicalSize(mode, scale, transform) {
    const m = String(mode).match(/^(\d+)x(\d+)/);
    if (!m) return { w: 0, h: 0 };
    let w = Number(m[1]) / scale, h = Number(m[2]) / scale;
    if (/90|270/.test(transform)) [w, h] = [h, w];
    return { w: Math.round(w), h: Math.round(h) };
}

// ── файлы ~/.config/niri/ochre/ ───────────────────────────────────
// main.kdl подключает остальные; в config.kdl — include "ochre/main.kdl" и в самом конце include "ochre/keys.kdl"

var NIRI_FILES = ["input", "displays", "layout", "window-rules", "cursor", "animations", "misc", "binds"];

// в каком файле живёт настройка — для подсказки в окне настроек
function niriFileOf(key) {
    if (/^niri\.(kb|tp|mouse)\.|^niri\.(ffm|warp)$/.test(key)) return "input.kdl";
    if (/^niri\.(gaps|colWidth|center|ring|border|shadow)$/.test(key) || key === "shell.accent") return "layout.kdl";
    if (/^niri\.rules\./.test(key)) return "window-rules.kdl";
    if (/^niri\.cursor\./.test(key)) return "cursor.kdl";
    if (/^niri\.anim/.test(key)) return "animations.kdl";
    if (key === "niri.csd" || key === "shell.theme.sync" || /^niri\.hc\./.test(key)) return "misc.kdl";
    if (/^niri\.out\./.test(key) || key === "action.displays") return "displays.kdl";
    if (key === "action.binds") return "keys.kdl";
    if (key === "shell.terminal" || key === "shell.files" || key === "shell.browser" || key in MUTE_BINDS) return "binds.kdl";
    return "";
}

function head(what) {
    return [
        "// ochre: " + what,
        "// Сгенерировано ochre (Mod+S) из ~/.config/ochre/settings.json — ручные правки перезапишутся.",
        "// Свои настройки пишите в ~/.config/niri/config.kdl.",
        ""
    ];
}

function text(lines) {
    return lines.filter(l => l !== null).join("\n") + "\n";
}

// get(key) — значение с учётом умолчаний;
// outs — { имя: { enabled, mode, scale, transform, x, y, vrr, primary } }, только то, что задано вручную.
// Возвращает { "input.kdl": текст, … } — все файлы папки ochre/, кроме keys.kdl (его пишет Binds).
// sel — как выбрать этот экземпляр shell в qs (Ochre.sel): [] для конфига по умолчанию, ["-p", каталог] для пакета
const GAME_OFF = { "niri.anim": false, "niri.shadow": false, "niri.rules.inactiveOpacity": 100 };

function niriFiles(get0, outs, sel) {
    // игровой режим: поверх своих значений — без эффектов; сами настройки не меняются и вернутся при выключении
    const get = k => get0("shell.game") && k in GAME_OFF ? GAME_OFF[k] : get0(k);
    const qsRun = ["qs"].concat(sel ?? []).map(q).join(" ");
    const ipc = (t, f) => " { spawn " + ["qs", "ipc"].concat(sel ?? [], ["call", t, f]).map(q).join(" ") + "; }";
    const accent = ACCENTS[get("shell.accent")] ?? ACCENTS.ochre;
    const ring = get("niri.ring");
    const border = get("niri.border");
    const radius = get("niri.rules.radius");
    const inactive = get("niri.rules.inactiveOpacity");
    const files = {};

    files["main.kdl"] = text([
        "// ochre: все настройки niri из ochre — по файлу на раздел.",
        "// Подключается из config.kdl: include \"ochre/main.kdl\". Свои бинды (keys.kdl) — отдельно, в конце config.kdl.",
        "",
        ...NIRI_FILES.map(n => "include " + q(n + ".kdl"))
    ]);

    files["input.kdl"] = text([
        ...head("ввод — клавиатура, мышь, тачпад"),
        "input {",
        "    keyboard {",
        "        xkb {",
        "            layout " + q(get("niri.kb.layout")),
        "            options " + q(get("niri.kb.options")),
        "        }",
        "        repeat-delay " + get("niri.kb.repeatDelay"),
        "        repeat-rate " + get("niri.kb.repeatRate"),
        get("niri.kb.numlock") ? "        numlock" : null,
        "    }",
        "    touchpad {",
        get("niri.tp.tap") ? "        tap" : null,
        get("niri.tp.natural") ? "        natural-scroll" : null,
        "    }",
        "    mouse {",
        "        accel-speed " + f(get("niri.mouse.accel")),
        "        accel-profile " + q(get("niri.mouse.profile")),
        "    }",
        get("niri.ffm") ? "    focus-follows-mouse" : null,
        get("niri.warp") ? "    warp-mouse-to-focus" : null,
        "}"
    ]);

    const displays = head("мониторы — окно мониторов (Mod+S → system/ → мониторы)");
    for (const name in outs) {
        const o = outs[name];
        const body = [];
        if (o.enabled === false) {
            body.push("    off");
        } else {
            if (o.mode) body.push("    mode " + q(o.mode));
            if (o.scale !== undefined) body.push("    scale " + f(o.scale));
            if (o.transform) body.push("    transform " + q(o.transform));
            // окно мониторов пишет обе координаты, но в старых настройках бывает одна — вторая тогда 0
            if (o.x !== undefined || o.y !== undefined) body.push("    position x=" + Math.round(o.x ?? 0) + " y=" + Math.round(o.y ?? 0));
            if (o.vrr) body.push("    variable-refresh-rate");
            if (o.primary) body.push("    focus-at-startup");
        }
        if (body.length) displays.push("output " + q(name) + " {", ...body, "}", "");
    }
    if (displays.length === 4) displays.push("// ничего не задано — niri настраивает мониторы сам");
    files["displays.kdl"] = text(displays);

    files["layout.kdl"] = text([
        ...head("раскладка окон — отступы, колонки, рамка фокуса, обводка, тени"),
        "layout {",
        "    // прозрачный фон: под рабочими столами видны обои quickshell",
        '    background-color "transparent"',
        "    gaps " + get("niri.gaps"),
        "    center-focused-column " + q(get("niri.center")),
        "    preset-column-widths {",
        "        proportion 0.33333",
        "        proportion 0.5",
        "        proportion 0.66667",
        "    }",
        "    default-column-width { proportion " + WIDTHS[get("niri.colWidth")] + "; }",
        "    focus-ring {",
        ...(ring > 0
            ? ["        width " + ring, "        active-color " + q(accent), '        inactive-color "#504945"']
            : ["        off"]),
        "    }",
        "    border {",
        ...(border > 0
            ? ["        width " + border, "        active-color " + q(accent), '        inactive-color "#504945"', '        urgent-color "#fb4934"']
            : ["        off"]),
        "    }",
        "    shadow {",
        get("niri.shadow") ? "        on" : null,
        "        softness 30",
        "        spread 5",
        "        offset x=0 y=5",
        '        color "#0007"',
        "    }",
        "}"
    ]);

    files["window-rules.kdl"] = text([
        ...head("правила окон"),
        ...(radius > 0 ? [
            "// скруглённые углы у всех окон",
            "window-rule {",
            "    geometry-corner-radius " + radius,
            "    clip-to-geometry true",
            "}",
            ""] : []),
        ...(inactive < 100 ? [
            "// неактивные окна полупрозрачные",
            "window-rule {",
            "    match is-active=false",
            "    opacity " + (inactive / 100).toFixed(2),
            "}",
            ""] : []),
        "// терминалы, открытые из меню ochre (install / remove / update …), — плавающие по центру",
        "window-rule {",
        // [.] вместо \. — в строках KDL такой escape недопустим
        '    match app-id="^(ochre-term|dev[.]ochre[.]term)$"',
        "    open-floating true",
        "    default-column-width { fixed 960; }",
        "    default-window-height { fixed 600; }",
        "}",
        "",
        "// обои quickshell видны и как фон режима обзора",
        "layer-rule {",
        '    match namespace="^ochre-wallpaper$"',
        "    place-within-backdrop true",
        "}"
    ]);

    files["cursor.kdl"] = text([
        ...head("курсор"),
        "cursor {",
        "    xcursor-size " + get("niri.cursor.size"),
        get("niri.cursor.hide") ? "    hide-when-typing" : null,
        "}"
    ]);

    files["animations.kdl"] = text([
        ...head("анимации"),
        "animations {",
        get("niri.anim") ? null : "    off",
        "    slowdown " + f(get("niri.anim.slowdown")),
        ...animBlocks(get("niri.anim.style"), accent),
        "}"
    ]);

    files["misc.kdl"] = text([
        ...head("прочее"),
        "// просить приложения не рисовать свои заголовки",
        "prefer-no-csd " + (get("niri.csd") ? "true" : "false"),
        "",
        "// горячие углы открывают обзор; ни одного — off (пустой блок niri понял бы как «по умолчанию»)",
        "gestures {",
        "    hot-corners {",
        ...(HOT_CORNERS.some(([k]) => get(k)) ? HOT_CORNERS.filter(([k]) => get(k)).map(([, c]) => "        " + c) : ["        off"]),
        "    }",
        "}",
        ...(get("shell.theme.sync") ? [
            "",
            "// Qt-приложения берут палитру и шрифт из qt6ct — его настраивает shell (темы Qt и GTK)",
            "environment {",
            ...Object.keys(APP_ENV).map(k => "    " + k + " " + q(APP_ENV[k])),
            "}"] : [])
    ]);

    files["binds.kdl"] = text([
        ...head("клавиши ochre и автозапуск shell. Свои — в окне биндов (Mod+S → input/ → бинды), они в keys.kdl"),
        "spawn-at-startup " + qsRun,
        "",
        "binds {",
        "    Mod+Return hotkey-overlay-title=" + q("Open a Terminal: " + get("shell.terminal")) + " { spawn " + termCmd(get("shell.terminal")).map(q).join(" ") + "; }",
        ...(filesCmd(get("shell.terminal"), get("shell.files"))
            ? ["    Mod+E hotkey-overlay-title=" + q("Files: " + get("shell.files")) + " { spawn " + filesCmd(get("shell.terminal"), get("shell.files")).map(q).join(" ") + "; }"]
            : []),
        ...(BROWSERS[get("shell.browser")]
            ? ["    Mod+Shift+B hotkey-overlay-title=" + q("Browser: " + get("shell.browser")) + " { spawn " + q(BROWSERS[get("shell.browser")].bin) + "; }"]
            : []),
        ...Object.keys(MUTE_BINDS).filter(k => COMBO_RE.test(get(k) ?? "")).map(k =>
            "    " + get(k) + " allow-when-locked=true hotkey-overlay-title=" + q(MUTE_BINDS[k].title) + " { " + MUTE_BINDS[k].action + "; }"),
        '    Mod+D hotkey-overlay-title="Menu"' + ipc("launcher", "toggle"),
        '    Mod+Space hotkey-overlay-title="Run an Application"' + ipc("launcher", "apps"),
        '    Mod+Shift+W hotkey-overlay-title="Wallpapers"' + ipc("wallpaper", "picker"),
        '    Mod+Shift+V hotkey-overlay-title="Clipboard History"' + ipc("clipboard", "toggle"),
        '    Mod+A hotkey-overlay-title="Home Menu"' + ipc("home", "toggle"),
        '    Mod+Alt+R hotkey-overlay-title="Record the Screen"' + ipc("record", "toggle"),
        '    Mod+Shift+S hotkey-overlay-title="Screenshot"' + ipc("shot", "region"),
        '    Print hotkey-overlay-title="Screenshot"' + ipc("shot", "region"),
        '    Mod+Shift+T hotkey-overlay-title="Copy Text from the Screen"' + ipc("shot", "ocr"),
        '    Mod+Shift+C hotkey-overlay-title="Pick a Color"' + ipc("shot", "pick"),
        '    Mod+Shift+G hotkey-overlay-title="Game Mode"' + ipc("game", "toggle"),
        '    Mod+S hotkey-overlay-title="Settings"' + ipc("settings", "toggle"),
        '    Super+Alt+L hotkey-overlay-title="Lock the Screen"' + ipc("lock", "lock"),
        "}"
    ]);

    return files;
}

// ── темы приложений: GTK и Qt вслед за shell ───────────────────────
// Пишет services/AppTheme.qml: файлы — в ~/.config, параметры GTK — через gsettings
// (их же отдаёт xdg-desktop-portal: Firefox, Chromium, libadwaita).

const GRUVBOX = {
    bg: "#1d2021", bg0: "#282828", bg1: "#3c3836", bg2: "#504945", bg3: "#665c54",
    fg: "#ebdbb2", fg0: "#fbf1c7", gray: "#928374",
    red: "#fb4934", green: "#b8bb26", yellow: "#fabd2f", blue: "#83a598", purple: "#d3869b"
};

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
function gtkColors(accent) {
    const c = GRUVBOX;
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
function qtColors(accent, disabled) {
    const c = GRUVBOX;
    const text = disabled ? c.gray : c.fg;
    return [
        text, c.bg1, c.bg2, c.bg1, c.bg, "#32302f",     // WindowText Button Light Midlight Dark Mid
        text, c.fg0, text, c.bg0, c.bg, "#000000",      // Text BrightText ButtonText Base Window Shadow
        disabled ? c.bg2 : accent, c.bg,                // Highlight HighlightedText
        c.blue, c.purple, "#32302f", c.bg,              // Link LinkVisited AlternateBase NoRole
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
        return { "gtk-3.0/ochre.css": off, "gtk-4.0/ochre.css": off };
    }
    const accent = ACCENTS[get("shell.accent")] ?? ACCENTS.ochre;
    const colors = gtkColors(accent);
    const pt = fontPt(get);
    return {
        "gtk-3.0/ochre.css": gtkCss(colors, false),
        "gtk-4.0/ochre.css": gtkCss(colors, true),
        "btop/themes/ochre.theme": btopTheme(accent),
        "qt6ct/colors/ochre.conf": [
            "; ochre: палитра shell для Qt — сгенерировано ochre, ручные правки перезапишутся",
            "[ColorScheme]",
            "active_colors=" + qtColors(accent, false),
            "disabled_colors=" + qtColors(accent, true),
            "inactive_colors=" + qtColors(accent, false),
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
    };
}

// btop в стиле shell: рамки и заголовки — акцент, разделители — bg2, подписи — серые, градиенты Gruvbox.
// Фон пустой — btop рисует на фоне терминала (theme_background = False ставит AppTheme в btop.conf).
function btopTheme(accent) {
    const c = GRUVBOX, aqua = ACCENTS.aqua, orange = ACCENTS.orange;
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
    const font = s(FONT + " " + fontPt(get));
    return [
        ["color-scheme", s("prefer-dark")],
        ["gtk-theme", s("adw-gtk3-dark")],
        ["icon-theme", s(ICONS)],
        ["accent-color", s(GNOME_ACCENTS[get("shell.accent")] ?? "yellow")],
        ["cursor-size", String(get("niri.cursor.size"))],
        ["monospace-font-name", font],
        ["font-name", get("shell.theme.font") ? font : ""],
        ["document-font-name", get("shell.theme.font") ? font : ""]
    ];
}
