.pragma library

// Виджеты на рабочем столе: каталог и список shell.desktop.widgets.
// Часть services/settings.js: QML импортирует только его, он отдаёт все имена этого файла.
// Виджет — { id, type, screen, x, y, w, h, frame, bg, text?, path? }: x y w h — доли экрана (0…1), чтобы раскладка
// пережила смену разрешения и масштаба; screen — имя монитора, нет такого — виджет на первом мониторе.

// file — desktop/<file>.qml; w, h — размер нового виджета в символах; min — меньше нельзя сжать
var WIDGETS = [
    { id: "clock", file: "Clock", label: "часы", desc: "крупные часы из блоков и дата", w: 34, h: 9, min: [14, 5] },
    { id: "media", file: "Media", label: "сейчас играет", desc: "обложка, трек, прогресс и кнопки плеера; без плеера — «тишина»", w: 44, h: 7, min: [24, 5] },
    { id: "system", file: "System", label: "система", desc: "cpu, gpu, память и сеть полосками", w: 40, h: 8, min: [24, 6] },
    { id: "viz", file: "Viz", label: "полоски звука", desc: "cava: что сейчас играет; нужен cava", w: 40, h: 8, min: [8, 3] },
    { id: "sticker", file: "Sticker", label: "стикер", desc: "заметка: текст правится в режиме правки (↵)", w: 28, h: 8, min: [10, 4] },
    { id: "image", file: "Picture", label: "картинка", desc: "файл с диска: путь — ↵ в режиме правки или перетащите файл на стол", w: 30, h: 14, min: [6, 3] }
];

var BGS = ["dim", "solid", "none"];

function widgetById(id) {
    return WIDGETS.find(w => w.id === id) ?? null;
}

function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
}

// битые и неизвестные записи выбрасываются, поля — в допустимых пределах
function normalizeWidgets(list) {
    if (!Array.isArray(list)) return [];
    const seen = {};
    const out = [];
    for (const w of list) {
        if (!w || typeof w !== "object" || !widgetById(w.type)) continue;
        const id = String(w.id || "") || w.type + out.length;
        if (seen[id]) continue;
        seen[id] = true;
        const ww = clamp(Number(w.w) || 0.2, 0.02, 1), hh = clamp(Number(w.h) || 0.2, 0.02, 1);
        out.push(Object.assign({}, w, {
            id,
            screen: String(w.screen ?? ""),
            w: ww,
            h: hh,
            x: clamp(Number(w.x) || 0, 0, 1 - ww),
            y: clamp(Number(w.y) || 0, 0, 1 - hh),
            frame: w.frame !== false,
            bg: BGS.includes(w.bg) ? w.bg : "dim"
        }));
    }
    return out;
}

// новый виджет посередине экрана; cw, ch — клетка символа в долях экрана
function newWidget(type, screen, cw, ch, now) {
    const t = widgetById(type);
    const w = clamp(t.w * cw, 0.02, 1), h = clamp(t.h * ch, 0.02, 1);
    return normalizeWidgets([{
        id: type + "-" + now.toString(36),
        type, screen,
        x: (1 - w) / 2, y: (1 - h) / 2, w, h,
        text: type === "sticker" ? "" : undefined,
        path: type === "image" ? "" : undefined
    }])[0];
}

// чьи виджеты рисует монитор: свои и те, чьего монитора нет (на первом)
function widgetsOn(list, screen, screens) {
    const first = screens[0] ?? "";
    return list.filter(w => w.screen === screen || (screen === first && !screens.includes(w.screen)));
}

// заменить поля виджета (копией — иначе привязки не увидят)
function updateWidget(list, id, patch) {
    return normalizeWidgets(list.map(w => w.id === id ? Object.assign({}, w, patch) : w));
}

function removeWidget(list, id) {
    return list.filter(w => w.id !== id);
}
