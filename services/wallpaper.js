.pragma library

var IMAGE = /\.(png|jpe?g|webp)$/i;

function wsKey(ws) {
    return ws ? ws.output + "/" + (ws.name || ws.idx) : "";
}

function parseState(text) {
    let s = {};
    try { s = JSON.parse(text) || {}; } catch (e) { s = {}; }
    return { all: s.all || {}, outputs: s.outputs || {}, workspaces: s.workspaces || {} };
}

function nightVariant(path) {
    const m = path.match(IMAGE);
    return m ? path.slice(0, m.index) + "-night" + m[0] : path + "/night";
}

function levels(state, output, ws) {
    return [
        { level: "ws", key: ws, slot: state.workspaces[ws] },
        { level: "output", key: output, slot: state.outputs[output] },
        { level: "all", key: "", slot: state.all }
    ];
}

function resolve(state, output, ws, night, exists, listDir, pos) {
    for (const l of levels(state, output, ws)) {
        const s = l.slot || {};
        const path = night && s.night ? s.night : s.day;
        if (!path) continue;
        const tries = night && !s.night ? [nightVariant(path), path] : [path];
        for (let i = 0; i < tries.length; i++) {
            const p = tries[i];
            const list = listDir(p);
            if (list && list.length) return { path: list[pos % list.length], count: list.length };
            if (IMAGE.test(p) && (i === tries.length - 1 || exists(p))) return { path: p, count: 0 };
        }
    }
    return { path: "", count: 0 };
}

function isNight(now, sun) {
    const min = d => d.getHours() * 60 + d.getMinutes();
    const t = min(now);
    return sun ? t < min(sun.rise) || t >= min(sun.set) : t < 7 * 60 || t >= 19 * 60;
}

function pick(n, cur, order, rnd) {
    if (n <= 1) return 0;
    if (order === "cycle") return (cur + 1) % n;
    return (cur + 1 + Math.floor(rnd * (n - 1))) % n;
}
