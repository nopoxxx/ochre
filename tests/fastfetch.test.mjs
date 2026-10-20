import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { S, getter, ROOT } from "./load.mjs";

const jsonc = text => JSON.parse(text.replace(/^\s*\/\/.*$/gm, ""));

test("fastfetchConfig: каждый стиль — валидный JSONC с меткой ochre и существующим логотипом", () => {
    for (const style of Object.keys(S.FASTFETCH_STYLES)) {
        const text = S.fastfetchConfig(getter({ "shell.fastfetch": style }), ROOT);
        assert.ok(text.startsWith(S.FASTFETCH_MARK), style);
        assert.doesNotMatch(text, /undefined|NaN/, style);
        const c = jsonc(text);
        assert.ok(c.modules.length > 0, style);
        if (c.logo.type === "file") assert.ok(existsSync(c.logo.source), style + ": " + c.logo.source);
        else assert.equal(c.logo.type, "none", style);
    }
});

test("fastfetchConfig: логотип цветом акцента, неизвестный стиль — panel", () => {
    const c = jsonc(S.fastfetchConfig(getter({ "shell.accent": "blue" }), ROOT));
    assert.equal(c.logo.color["1"], "38;2;131;165;152");
    assert.equal(S.fastfetchConfig(getter({ "shell.fastfetch": "nope" }), ROOT), S.fastfetchConfig(getter(), ROOT));
});

test("extras/fastfetch: поставляемый конфиг — это fastfetchConfig по умолчанию", () => {
    assert.equal(readFileSync(join(ROOT, "extras/fastfetch/config.jsonc"), "utf8"), S.fastfetchConfig(getter(), "~/.config/quickshell"));
});
