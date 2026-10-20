import { test } from "node:test";
import assert from "node:assert/strict";
import { load, getter } from "./load.mjs";

const H = load("services/hooks.js");

test("argv: путь хука и аргументы строками, данные не в тексте скрипта", () => {
    const a = H.argv("/h", "game", ["on", 1]);
    assert.equal(a[0], "sh");
    assert.equal(a[3], "sh");
    assert.deepEqual(a.slice(4), ["/h/game", "on", "1"]);
    assert.ok(!a[2].includes("/h"));
});

test("argv: неизвестное событие — null", () => {
    assert.equal(H.argv("/h", "../x", []), null);
    assert.equal(H.argv("/h", "nope", []), null);
});

test("themeArgs: hex акцента, акцент, тема, режим", () => {
    const a = H.themeArgs(getter({ "shell.accent": "blue" }));
    assert.match(a[0], /^#[0-9a-f]{6}$/i);
    assert.deepEqual(a.slice(1), ["blue", "gruvbox", "dark"]);
});

test("themeArgs: смена акцента меняет hex", () => {
    assert.notEqual(H.themeArgs(getter({ "shell.accent": "blue" }))[0], H.themeArgs(getter({ "shell.accent": "red" }))[0]);
});

test("onOff", () => {
    assert.equal(H.onOff(true), "on");
    assert.equal(H.onOff(false), "off");
});
