.pragma library

// Время за экраном (services/ScreenTime.qml): {«YYYY-MM-DD»: {app_id: секунды}}

function dayKey(ms) {
    const d = new Date(ms);
    const two = x => String(x).padStart(2, "0");
    return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate());
}

function nextMidnight(ms) {
    const d = new Date(ms);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime();
}

// интервал [from, to) мс — на app (sign −1 — снять); через полночь — по дням
function add(days, app, from, to, sign) {
    if (!app || !(to > from)) return days;
    const out = Object.assign({}, days);
    let t = from;
    while (t < to) {
        const end = Math.min(to, nextMidnight(t));
        const key = dayKey(t);
        const day = Object.assign({}, out[key]);
        const v = (day[app] ?? 0) + (sign ?? 1) * Math.round((end - t) / 1000);
        if (v > 0) day[app] = v; else delete day[app];
        out[key] = day;
        t = end;
    }
    return out;
}

// снять всё, что записано после t: отрезки recent — [{app, from, to}]
function undo(days, recent, t) {
    return recent.reduce((d, r) => add(d, r.app, Math.max(r.from, t), r.to, -1), days);
}

function prune(days, keep, now) {
    const d = new Date(now);
    const oldest = dayKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() - keep + 1).getTime());
    const out = {};
    for (const k in days) if (k >= oldest) out[k] = days[k];
    return out;
}

function top(day, n) {
    return Object.keys(day ?? {}).map(app => ({ app, sec: day[app] })).sort((a, b) => b.sec - a.sec).slice(0, n);
}

function total(day) {
    return Object.values(day ?? {}).reduce((s, v) => s + v, 0);
}

function fmt(sec) {
    const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
    if (!h && !m) return "<1m";
    return h ? h + "h" + String(m).padStart(2, "0") + "m" : m + "m";
}
