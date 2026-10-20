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
            for (const r of P.ROLES) if (v[r] || !["hover", "fgDim"].includes(r)) assert.match(v[r] ?? "", hex, `${id}.${mode}.${r}`);
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

test("palette: тема без dark и имена из прототипа не ломают палитру", () => {
    P.THEMES.lightOnly = { name: "Light", light: { bg: "#ffffff" } };
    try {
        assert.equal(P.palette(getter({ "shell.theme.name": "lightOnly" })).bg, "#ffffff");
        for (const name of ["constructor", "toString", "__proto__"])
            assert.equal(P.palette(getter({ "shell.theme.name": name })).bg, "#1d2021", name);
    } finally {
        delete P.THEMES.lightOnly;
    }
});

const lum = c => {
    const v = [1, 3, 5].map(i => parseInt(c.substr(i, 2), 16) / 255).map(x => x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4);
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
};
const contrast = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

test("THEMES: девять семейств, текст и акцент ochre читаются на фоне", () => {
    assert.deepEqual(Object.keys(P.THEMES), ["gruvbox", "catppuccin", "rosepine", "tokyonight", "everforest", "kanagawa", "solarized", "nord", "dracula"]);
    for (const [id, t] of Object.entries(P.THEMES)) {
        const v = t.dark;
        assert.ok(contrast(v.fg, v.bg) >= 4.5, `${id}: fg/bg ${contrast(v.fg, v.bg).toFixed(2)}`);
        assert.ok(contrast(v.ochre, v.bg) >= 3, `${id}: ochre/bg ${contrast(v.ochre, v.bg).toFixed(2)}`);
    }
});

test("схема: в списке тем — названия, а не id", () => {
    const row = S.sections([], undefined, undefined).flatMap(s => s.rows).find(r => r.key === "shell.theme.name");
    for (const id of row.options) assert.equal(row.labels[id], P.THEMES[id].name);
});

test("палитра доходит до niri и приложений", () => {
    const get = getter({ "shell.theme.name": "nord", "shell.accent": "blue" });
    const nord = P.THEMES.nord.dark;
    assert.match(S.niriFiles(get, {}, [])["layout.kdl"], new RegExp(nord.blue));
    assert.match(S.niriFiles(get, {}, [])["layout.kdl"], new RegExp(nord.bg2));
    const files = S.themeFiles(get, "/home/u");
    assert.match(files["gtk-4.0/ochre.css"], new RegExp("window_bg_color " + nord.bg));
    assert.match(files["qt6ct/colors/ochre.conf"], new RegExp(nord.fg));
    assert.match(files["btop/themes/ochre.theme"], new RegExp(nord.blue));
    assert.equal(S.niriFileOf("shell.theme.name"), "layout.kdl");
});
