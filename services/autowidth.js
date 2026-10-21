.pragma library

function tiledSets(windows) {
    const out = {};
    for (const w of Object.values(windows)) {
        if (w.is_floating || w.workspace_id == null) continue;
        (out[w.workspace_id] = out[w.workspace_id] || []).push(w.id);
    }
    for (const k in out) out[k] = out[k].sort((a, b) => a - b).join(",");
    return out;
}

function changed(prev, next) {
    const keys = Object.keys(Object.assign({}, prev, next));
    return keys.filter(k => prev[k] !== next[k] && next[k]).map(Number);
}

function plan(wins) {
    const cols = new Map();
    for (const w of wins) {
        if (w.is_floating) continue;
        const pos = w.layout?.pos_in_scrolling_layout;
        const col = pos ? "c" + pos[0] : "w" + w.id;
        if (!cols.has(col)) cols.set(col, w.id);
    }
    const ids = Array.from(cols.values());
    if (ids.length === 1) return [[ids[0], "100%"]];
    if (ids.length === 2) return ids.map(id => [id, "50%"]);
    return [];
}
