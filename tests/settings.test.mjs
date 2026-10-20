// node --test tests/ — схема настроек, генерация конфига niri, бинды, раскладки.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { S, getter } from "./load.mjs";

const rows = () => S.sections([], undefined, undefined).flatMap(s => s.rows).filter(r => r.key);

test("схема: ключи уникальны, у строк есть подпись и тип", () => {
    const seen = new Set();
    for (const r of rows()) {
        if (r.type === "module") continue;   // элементы раскладки: ключ — раскладка, повторяется
        assert.ok(!seen.has(r.key), "повтор ключа " + r.key);
        seen.add(r.key);
        assert.ok(r.label, "нет подписи у " + r.key);
        assert.ok(r.type, "нет типа у " + r.key);
    }
});

test("схема: умолчания укладываются в ограничения", () => {
    for (const r of rows()) {
        if (r.type === "enum") assert.ok(r.options.includes(r.def), `${r.key}: ${JSON.stringify(r.def)} нет в options`);
        if (r.type === "int" || r.type === "float") {
            assert.ok(r.def >= r.min && r.def <= r.max, `${r.key}: ${r.def} вне [${r.min}, ${r.max}]`);
            const steps = (r.def - r.min) / r.step;
            assert.ok(Math.abs(steps - Math.round(steps)) < 1e-9, `${r.key}: ${r.def} не попадает в шаг ${r.step}`);
        }
        if (r.type === "bool") assert.equal(typeof r.def, "boolean", r.key);
        if (r.type !== "action" && r.type !== "module")
            assert.deepEqual(S.defaultOf(r.key, []), r.def, `defaultOf(${r.key}) расходится со схемой`);
    }
});

// варианты, которые меняют генерацию сильнее всего: каждый должен давать конфиг, который принимает niri
const VARIANTS = {
    "по умолчанию": {},
    "игровой режим": { "shell.game": true },
    "все горячие углы": { "niri.hc.topLeft": true, "niri.hc.topRight": true, "niri.hc.bottomLeft": true, "niri.hc.bottomRight": true },
    "без анимаций": { "niri.anim": false },
    ...Object.fromEntries(S.NIRI_ANIMS.map(a => ["анимации " + a, { "niri.anim.style": a }])),
    ...Object.fromEntries(Object.keys(S.ACCENTS).map(a => ["акцент " + a, { "shell.accent": a }])),
};

test("niriFiles: в тексте нет undefined / NaN / [object Object], скобки сбалансированы", () => {
    for (const [name, over] of Object.entries(VARIANTS)) {
        for (const [file, text] of Object.entries(S.niriFiles(getter(over), {}, []))) {
            assert.doesNotMatch(text, /\bundefined\b|\bNaN\b|\[object Object\]/, `${name}: ${file}`);
            const noStr = text.replace(/r#*"[\s\S]*?"#*|"(?:\\.|[^"\\])*"|\/\/.*$/gm, "");
            const depth = [...noStr].reduce((d, c) => d + (c === "{") - (c === "}"), 0);
            assert.equal(depth, 0, `${name}: ${file} — несбалансированные { }`);
        }
    }
});

const niri = spawnSync("niri", ["--version"]).status === 0;

test("niriFiles: niri validate принимает каждый вариант", { skip: !niri && "нет niri" }, () => {
    const dir = mkdtempSync(join(tmpdir(), "ochre-kdl-"));
    try {
        mkdirSync(join(dir, "ochre"));
        writeFileSync(join(dir, "config.kdl"), 'include "ochre/main.kdl"\n');
        for (const [name, over] of Object.entries(VARIANTS)) {
            for (const [file, text] of Object.entries(S.niriFiles(getter(over), {}, [])))
                writeFileSync(join(dir, "ochre", file), text);
            const r = spawnSync("niri", ["validate", "-c", join(dir, "config.kdl")], { encoding: "utf8" });
            assert.equal(r.status, 0, `${name}: niri validate\n${r.stdout}${r.stderr}`);
        }
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
});

test("niriFiles: каждый ключ niri.* из схемы знает свой файл", () => {
    const files = Object.keys(S.niriFiles(getter(), {}, []));
    for (const r of rows()) {
        if (!r.key.startsWith("niri.") || r.type === "action") continue;
        const f = S.niriFileOf(r.key);
        assert.ok(f, `niriFileOf(${r.key}) пусто`);
        assert.ok(files.includes(f), `${r.key} → ${f}, такого файла нет`);
    }
});

test("comboKey: регистр и порядок модификаторов не важны", () => {
    assert.equal(S.comboKey("Shift+Mod+T"), S.comboKey("mod+shift+t"));
    assert.equal(S.comboKey("Control+Alt+Delete"), S.comboKey("Alt+Ctrl+Delete"));
    assert.notEqual(S.comboKey("Mod+T"), S.comboKey("Mod+Shift+T"));
});

test("actionKdl: ввод человека → KDL", () => {
    assert.equal(S.actionKdl("close-window"), "close-window");
    assert.equal(S.actionKdl("focus-workspace 3"), "focus-workspace 3");
    assert.equal(S.actionKdl("spawn kitty"), 'spawn "kitty"');
    assert.equal(S.actionKdl("spawn kitty -e btop"), 'spawn-sh "kitty -e btop"');
    assert.equal(S.actionKdl('spawn "foot" "-e" "htop";'), 'spawn "foot" "-e" "htop"');
    assert.equal(S.actionKdl("set-column-width -10%"), 'set-column-width "-10%"');
});

test("parseBinds: однострочные бинды, подпись, null, комментарии", () => {
    const text = [
        "binds {",
        '    Mod+T hotkey-overlay-title="Терминал" { spawn "kitty"; }',
        "    Mod+Q { close-window; }",
        "    // Mod+X { quit; }",
        '    Mod+Shift+E hotkey-overlay-title=null { quit; }',
        "    Mod+Z {",
        "        spawn \"multi\";",
        "    }",
        "}",
        "Mod+O { outside; }",
    ].join("\n");
    const b = S.parseBinds(text, "config");
    assert.deepEqual(b.map(x => x.combo), ["Mod+T", "Mod+Q", "Mod+Shift+E"]);
    assert.equal(b[0].title, "Терминал");
    assert.equal(b[0].action, 'spawn "kitty"');
    assert.equal(b[2].hidden, true);
    assert.equal(b[1].source, "config");
});

test("keysKdl → parseBinds: свои бинды читаются обратно", () => {
    const keys = {
        [S.comboKey("Mod+Y")]: { combo: "Mod+Y", action: 'spawn "yazi"', title: "Файлы" },
        [S.comboKey("Mod+U")]: { combo: "Mod+U", action: "off", title: "" },
    };
    const back = S.parseBinds(S.keysKdl(keys), "own");
    const y = back.find(x => x.combo === "Mod+Y");
    assert.ok(y, "Mod+Y не прочитался");
    assert.equal(y.action, 'spawn "yazi"');
    assert.equal(y.title, "Файлы");
    assert.ok(back.find(x => x.combo === "Mod+U"), "отключённый Mod+U не прочитался");
});

test("normalizeLayout: каждый модуль ровно в одной зоне, пустая раскладка = умолчание", () => {
    for (const key of Object.keys(S.LAYOUTS)) {
        const L = S.LAYOUTS[key];
        const n = S.normalizeLayout(undefined, key);
        const all = L.zones.flatMap(z => n[z]);
        assert.equal(new Set(all).size, all.length, `${key}: модуль в двух зонах`);
        for (const it of L.items) assert.ok(all.includes(it.id), `${key}: ${it.id} потерялся`);
    }
});

test("normalizeLayout: новый модуль встаёт в свою зону, а не теряется", () => {
    const key = "shell.bar.layout";
    const full = S.normalizeLayout(undefined, key);
    const zone = Object.keys(full).find(z => full[z].includes("clock"));
    const old = Object.fromEntries(Object.entries(full).map(([z, ids]) => [z, ids.filter(i => i !== "clock")]));
    const n = S.normalizeLayout(old, key);
    assert.ok(n[zone].includes("clock"), "clock не вернулся в " + zone);
});

test("moveModule / placeModule: модуль переезжает и не дублируется", () => {
    const key = "shell.bar.layout";
    const l = S.normalizeLayout(undefined, key);
    const moved = S.placeModule(l, "clock", "left", null, key);
    assert.ok(moved.left.includes("clock"));
    const all = Object.values(S.normalizeLayout(moved, key)).flat();
    assert.equal(all.filter(i => i === "clock").length, 1);
});

test("searchRows: находит по подписи, ключу и переводу", () => {
    const secs = S.sections([], undefined, undefined);
    const byLabel = S.searchRows(secs, "акцентный");
    assert.ok(byLabel.some(r => r.key === "shell.accent"));
    const byKey = S.searchRows(secs, "shell.accent");
    assert.ok(byKey.some(r => r.key === "shell.accent"));
    const tr = s => (s === "акцентный цвет" ? "accent color" : s);
    assert.ok(S.searchRows(secs, "accent color", tr).some(r => r.key === "shell.accent"));
});

const mon = (name, make, model, serial) => ({ name, make, model, serial });

test("outputIds: make model serial, без серийника или у двух одинаковых — разъём", () => {
    const ids = S.outputIds([
        mon("DP-1", "Dell Inc.", "DELL U2720Q", "ABC123"),
        mon("eDP-1", "BOE", "0x0BCA", ""),
        mon("HDMI-A-1", "LG", "27GL850", "X1"),
        mon("HDMI-A-2", "LG", "27GL850", "x1")
    ]);
    assert.deepEqual(ids, { "DP-1": "Dell Inc. DELL U2720Q ABC123", "eDP-1": "eDP-1", "HDMI-A-1": "HDMI-A-1", "HDMI-A-2": "HDMI-A-2" });
});

test("migrateOutputKeys: разъём → модель, вместе с «расположением»", () => {
    const ids = { "DP-1": "Dell Inc. DELL U2720Q ABC123", "eDP-1": "eDP-1" };
    const v = S.migrateOutputKeys({
        "niri.out.DP-1.scale": 1.5,
        "niri.out.DP-1.place": "right:eDP-1",
        "niri.out.eDP-1.place": "left:DP-1",
        "shell.accent": "blue"
    }, ids);
    assert.deepEqual(v, {
        "niri.out.Dell Inc. DELL U2720Q ABC123.scale": 1.5,
        "niri.out.Dell Inc. DELL U2720Q ABC123.place": "right:eDP-1",
        "niri.out.eDP-1.place": "left:Dell Inc. DELL U2720Q ABC123",
        "shell.accent": "blue"
    });
    assert.equal(S.migrateOutputKeys(v, ids), null);
});

test("migrateOutputKeys: уже есть ключ по модели — он важнее старого", () => {
    const v = S.migrateOutputKeys({ "niri.out.M S 1.scale": 2, "niri.out.DP-1.scale": 1 }, { "DP-1": "M S 1" });
    assert.deepEqual(v, { "niri.out.M S 1.scale": 2 });
});

test("niriFiles: монитор по модели — output с make model serial", () => {
    const files = S.niriFiles(getter(), { "Dell Inc. DELL U2720Q ABC123": { scale: 1.5 } }, []);
    assert.match(files["displays.kdl"], /output "Dell Inc\. DELL U2720Q ABC123" \{\n    scale 1\.5/);
});
