import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { S, getter, ROOT } from "./load.mjs";

const TERMS = ["kitty", "alacritty", "ghostty", "foot"];
const EXTRAS = { kitty: "kitty/kitty.conf", alacritty: "alacritty/alacritty.toml", ghostty: "ghostty/config", foot: "foot/foot.ini" };
const read = p => readFileSync(join(ROOT, p), "utf8");
const old = t => read("tests/fixtures/term-old/" + t);
const gruv = S.THEMES.gruvbox.dark;
const nord = S.THEMES.nord.dark;

test("termFiles: по файлу на терминал, цвета темы", () => {
    const files = S.termFiles(getter({ "shell.theme.name": "nord" }));
    assert.deepEqual(Object.keys(files).sort(), TERMS.map(t => S.TERM_COLORS[t]).sort());
    for (const text of Object.values(files)) {
        assert.doesNotMatch(text, /undefined|NaN/);
        assert.match(text, new RegExp(nord.bg.slice(1)));
        assert.match(text, new RegExp(nord.ansi[1].slice(1)));
        assert.match(text, new RegExp(nord.ansi[15].slice(1)));
    }
    assert.match(files[S.TERM_COLORS.kitty], /^color9 +#bf616a$/m);
    assert.match(files[S.TERM_COLORS.alacritty], /^\[colors\.bright\]$/m);
    assert.match(files[S.TERM_COLORS.ghostty], /^palette = 9=#bf616a$/m);
    assert.match(files[S.TERM_COLORS.foot], /^bright1=bf616a$/m);
});

test("extras/term: поставляемые цвета — это termFiles по умолчанию", () => {
    const files = S.termFiles(getter());
    for (const t of TERMS) assert.equal(read("extras/term/" + S.TERM_COLORS[t].split("/").pop()), files[S.TERM_COLORS[t]], t);
});

test("extras: конфиги терминалов подключают цвета и не задают своих", () => {
    for (const t of TERMS) {
        const text = read("extras/" + EXTRAS[t]);
        assert.ok(text.includes(S.TERM_INCLUDE[t]), t);
        assert.equal(S.termMigrate(t, text), null, t);
        assert.doesNotMatch(text, new RegExp(gruv.ansi[1].slice(1)), t);
    }
});

test("termMigrate: старый конфиг ochre — без цветов, с include, остальное на месте", () => {
    for (const t of TERMS) {
        const out = S.termMigrate(t, old(t));
        assert.ok(out, t);
        assert.ok(out.includes(S.TERM_INCLUDE[t]), t);
        assert.doesNotMatch(out, new RegExp(gruv.ansi[1].slice(1)), t);
        assert.doesNotMatch(out, new RegExp(gruv.bg.slice(1)), t);
        assert.match(out, /Terminess/, t);
        assert.equal(S.termMigrate(t, out), null, t);
    }
});

test("termMigrate: чужой конфиг не трогаем", () => {
    for (const t of TERMS) assert.equal(S.termMigrate(t, old(t).replace(/^# (ochre:.*|Gruvbox dark \(hard\))\n/gm, "")), null, t);
    assert.equal(S.termMigrate("kitty", ""), null);
});

test("termOsc: палитра, фон, текст и курсор для открытых окон", () => {
    const osc = S.termOsc(S.palette(getter()));
    assert.ok(osc.includes("\x1b]4;1;#cc241d\x1b\\"));
    assert.ok(osc.includes("\x1b]4;15;#ebdbb2\x1b\\"));
    assert.ok(osc.includes("\x1b]10;#ebdbb2\x1b\\"));
    assert.ok(osc.includes("\x1b]11;#1d2021\x1b\\"));
    assert.ok(osc.includes("\x1b]12;#ebdbb2\x1b\\"));
});

test("themeFiles: цвета терминалов пишутся и без синхронизации тем Qt/GTK", () => {
    for (const sync of [true, false]) {
        const files = S.themeFiles(getter({ "shell.theme.sync": sync }), "/home/u");
        for (const t of TERMS) assert.ok(files[S.TERM_COLORS[t]], `${t} sync=${sync}`);
    }
});

test("termMigrate: CRLF, [general] с пробелом, свой import и чужой kitty", () => {
    const foot = S.termMigrate("foot", old("foot").replace(/\n/g, "\r\n"));
    assert.doesNotMatch(foot, new RegExp(gruv.ansi[1].slice(1)));
    const ala = old("alacritty") + "\n[general] \nlive_config_reload = true\n";
    const out = S.termMigrate("alacritty", ala);
    assert.equal(out.match(/^\[general\]/gm).length, 1);
    assert.ok(out.includes(S.TERM_INCLUDE.alacritty));
    assert.equal(S.termMigrate("alacritty", old("alacritty") + '\nimport = ["x.toml"]\n'), null);
    assert.equal(S.termMigrate("alacritty", old("alacritty") + '\n[general]\nimport = ["x.toml"]\n'), null);
    assert.equal(S.termMigrate("kitty", "# Gruvbox dark (hard)\nbackground #000000\n"), null);
});
