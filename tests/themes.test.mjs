// node --test tests/ — палитры тем (services/settings/themes.js).
import { test } from "node:test";
import assert from "node:assert/strict";
import { load, getter, S } from "./load.mjs";

const P = load("services/settings/themes.js");
const hex = /^#[0-9a-f]{6}$/;

test("palette: по умолчанию — Gruvbox dark", () => {
    const p = P.palette(getter());
    for (const r of P.ROLES) assert.equal(p[r], P.THEMES.gruvbox.dark[r], r);
    assert.equal(p.accent, "#d79921");
    assert.equal(p.dark, true);
});

test("palette: неизвестная тема — Gruvbox", () => {
    assert.equal(P.palette(getter({ "shell.theme.name": "nope" })).bg, "#1d2021");
});

test("palette: акцент — цвет палитры по имени", () => {
    assert.equal(P.palette(getter({ "shell.accent": "blue" })).accent, "#83a598");
    assert.equal(P.palette(getter({ "shell.accent": "nope" })).accent, "#d79921");
});

test("palette: недостающие роли — из Gruvbox, hover/fgDim/ansi вычисляются", () => {
    P.THEMES.stub = { name: "Stub", dark: { bg: "#000000", bg1: "#202020", fg: "#ffffff", gray: "#808080" } };
    try {
        const p = P.palette(getter({ "shell.theme.name": "stub" }));
        assert.equal(p.hover, P.mix("#000000", "#202020", 0.5));
        assert.equal(p.fgDim, P.mix("#ffffff", "#808080", 0.3));
        assert.equal(p.red, P.THEMES.gruvbox.dark.red);
        assert.equal(p.ansi.length, 16);
        assert.equal(p.ansi[1], p.red);
        assert.equal(p.ansi[15], p.fg);
    } finally {
        delete P.THEMES.stub;
    }
});

test("mix: линейно по каналам", () => {
    assert.equal(P.mix("#000000", "#ffffff", 0.5), "#808080");
    assert.equal(P.mix("#123456", "#abcdef", 0), "#123456");
    assert.equal(P.mix("#123456", "#abcdef", 1), "#abcdef");
});

test("THEMES: у каждого варианта все роли и 16 цветов ansi", () => {
    for (const [id, t] of Object.entries(P.THEMES)) {
        assert.ok(t.name, id);
        for (const mode of ["dark", "light"]) {
            const v = t[mode];
            if (!v) continue;
            for (const r of P.ROLES) assert.match(v[r] ?? "", hex, `${id}.${mode}.${r}`);
            assert.equal(v.ansi.length, 16, `${id}.${mode}.ansi`);
            for (const c of v.ansi) assert.match(c, hex, `${id}.${mode}.ansi`);
            assert.ok(v.icons, `${id}.${mode}.icons`);
        }
    }
});

test("схема: shell.theme.name — темы из THEMES, по умолчанию gruvbox", () => {
    const row = S.sections([], undefined, undefined).flatMap(s => s.rows).find(r => r.key === "shell.theme.name");
    assert.ok(row, "нет строки shell.theme.name");
    assert.deepEqual(row.options, Object.keys(P.THEMES));
    assert.equal(S.defaultOf("shell.theme.name", []), "gruvbox");
});
