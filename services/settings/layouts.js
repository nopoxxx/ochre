.pragma library

// Раскладки модулей панели и секций home: реестры MODULES / HOME_SECTIONS, зоны, перенос и порядок.
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.

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
    { id: "usage", dash: 1, label: "экран", file: "Usage", desc: "время за экраном сегодня: всего и по приложениям (по фокусу окон)" },
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
