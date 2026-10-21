import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const W = load("services/wallpaper.js");

const st = (o = {}) => Object.assign({ all: {}, outputs: {}, workspaces: {} }, o);
const none = () => false;
const noDirs = () => null;
const dirs = m => p => (p in m ? m[p] : null);
const files = list => p => list.includes(p);
const at = (state, o = {}) => W.resolve(state, o.output ?? "DP-1", o.ws ?? "DP-1/1", o.night ?? false,
    o.exists ?? none, o.listDir ?? noDirs, o.pos ?? 0);

test("wsKey: по имени, иначе по idx", () => {
    assert.equal(W.wsKey({ output: "DP-1", idx: 2, name: null }), "DP-1/2");
    assert.equal(W.wsKey({ output: "DP-1", idx: 2, name: "chat" }), "DP-1/chat");
    assert.equal(W.wsKey(null), "");
});

test("parseState: битый и пустой текст — пустой state", () => {
    assert.deepEqual(W.parseState("{"), st());
    assert.deepEqual(W.parseState(""), st());
    assert.deepEqual(W.parseState('{"all":{"day":"/a.png"}}'), st({ all: { day: "/a.png" } }));
});

test("resolve: стол важнее монитора, монитор — всех", () => {
    const s = st({ all: { day: "/all.png" }, outputs: { "DP-1": { day: "/out.png" } }, workspaces: { "DP-1/2": { day: "/ws.png" } } });
    assert.equal(at(s, { ws: "DP-1/2" }).path, "/ws.png");
    assert.equal(at(s, { ws: "DP-1/1" }).path, "/out.png");
    assert.equal(at(s, { output: "HDMI-A-1", ws: "HDMI-A-1/1" }).path, "/all.png");
});

test("resolve: ничего не задано — пусто", () => {
    assert.equal(at(st()).path, "");
});

test("resolve: днём уровень с одним night пропускается", () => {
    const s = st({ all: { day: "/all.png" }, workspaces: { "DP-1/1": { night: "/n.png" } } });
    assert.equal(at(s).path, "/all.png");
    assert.equal(at(s, { night: true }).path, "/n.png");
});

test("resolve: ночью узкий day важнее широкого night", () => {
    const s = st({ outputs: { "DP-1": { night: "/out-n.png" } }, workspaces: { "DP-1/1": { day: "/ws.png" } } });
    assert.equal(at(s, { night: true }).path, "/ws.png");
});

test("resolve: ночью у файла берётся -night рядом", () => {
    const s = st({ all: { day: "/w/foo.png" } });
    assert.equal(at(s, { night: true, exists: files(["/w/foo-night.png"]) }).path, "/w/foo-night.png");
    assert.equal(at(s, { night: true }).path, "/w/foo.png");
});

test("resolve: папка листается по pos, ночью — её night/", () => {
    const s = st({ all: { day: "/w/space" } });
    const listDir = dirs({ "/w/space": ["/w/space/a.png", "/w/space/b.png"], "/w/space/night": ["/w/space/night/n.png"] });
    assert.deepEqual(at(s, { listDir, pos: 3 }), { path: "/w/space/b.png", count: 2 });
    assert.deepEqual(at(s, { listDir, night: true }), { path: "/w/space/night/n.png", count: 1 });
});

test("resolve: пустая папка — уровень пропускается", () => {
    const s = st({ all: { day: "/all.png" }, outputs: { "DP-1": { day: "/w/empty" } } });
    assert.equal(at(s, { listDir: dirs({ "/w/empty": [] }) }).path, "/all.png");
    assert.equal(at(s).path, "/all.png");
});

test("isNight: по восходу и закату, без них — 07:00–19:00", () => {
    const d = h => new Date(2026, 9, 20, h, 30);
    const sun = { rise: d(8), set: d(17) };
    assert.equal(W.isNight(d(7), sun), true);
    assert.equal(W.isNight(d(12), sun), false);
    assert.equal(W.isNight(d(18), sun), true);
    assert.equal(W.isNight(d(6), null), true);
    assert.equal(W.isNight(d(7), null), false);
    assert.equal(W.isNight(d(19), null), true);
});

test("pick: по кругу, случайно без повтора, одна картинка", () => {
    assert.equal(W.pick(3, 2, "cycle", 0.5), 0);
    for (const r of [0, 0.3, 0.6, 0.99]) {
        const i = W.pick(4, 1, "random", r);
        assert.ok(i >= 0 && i < 4 && i !== 1, String(i));
    }
    assert.equal(W.pick(1, 0, "random", 0.7), 0);
    assert.equal(W.pick(0, 0, "cycle", 0), 0);
});

test("isNight: вчерашний восход и закат — по времени суток", () => {
    const sun = { rise: new Date(2026, 9, 19, 8, 0), set: new Date(2026, 9, 19, 17, 0) };
    assert.equal(W.isNight(new Date(2026, 9, 20, 12, 0), sun), false);
    assert.equal(W.isNight(new Date(2026, 9, 20, 20, 0), sun), true);
});

test("wsKey: с ключом монитора", () => {
    assert.equal(W.wsKey({ output: "DP-1", idx: 2, name: null }, "M S 1"), "M S 1/2");
});

test("migrateOutputs: обои экранов и столов — с разъёма на модель", () => {
    const ids = { "DP-1": "M S 1", "eDP-1": "eDP-1" };
    const s = W.migrateOutputs(st({
        all: { day: "/a.png" },
        outputs: { "DP-1": { day: "/o.png" }, "eDP-1": { day: "/e.png" } },
        workspaces: { "DP-1/chat": { day: "/w.png" }, "eDP-1/1": { day: "/w1.png" } }
    }), ids);
    assert.deepEqual(s, st({
        all: { day: "/a.png" },
        outputs: { "M S 1": { day: "/o.png" }, "eDP-1": { day: "/e.png" } },
        workspaces: { "M S 1/chat": { day: "/w.png" }, "eDP-1/1": { day: "/w1.png" } }
    }));
    assert.equal(W.migrateOutputs(s, ids), null);
});

test("kindOf: картинки, анимации, видео, шейдеры", () => {
    assert.equal(W.kindOf("/w/a.PNG"), "image");
    assert.equal(W.kindOf("/w/a.jpeg"), "image");
    assert.equal(W.kindOf("/w/a.gif"), "anim");
    assert.equal(W.kindOf("/w/a.webp"), "anim");
    assert.equal(W.kindOf("/w/a.webm"), "video");
    assert.equal(W.kindOf("/w/a.MP4"), "video");
    assert.equal(W.kindOf("/w/a.frag"), "shader");
    assert.equal(W.kindOf("/w/a.frag.qsb"), "shader");
    assert.equal(W.kindOf("/w/space"), "");
    assert.ok(W.isLive("/w/a.mkv") && W.isLive("/w/a.frag") && !W.isLive("/w/a.gif") && !W.isLive("/w/a.png"));
});

test("findNames: аргументы find на все форматы", () => {
    const a = W.findNames();
    assert.deepEqual(a.slice(0, 5), ["-iname", "*.jpg", "-o", "-iname", "*.jpeg"]);
    assert.equal(a.filter(x => x === "-o").length, W.EXTS.length - 1);
    assert.ok(a.includes("*.mp4") && a.includes("*.frag"));
});

test("resolve: видео и шейдер — как картинка, ночью — свой -night", () => {
    assert.equal(at(st({ all: { day: "/w/rain.mp4" } })).path, "/w/rain.mp4");
    const s = st({ all: { day: "/w/sea.frag" } });
    assert.equal(at(s, { night: true, exists: files(["/w/sea-night.frag"]) }).path, "/w/sea-night.frag");
    assert.equal(W.nightVariant("/w/rain.webm"), "/w/rain-night.webm");
});
