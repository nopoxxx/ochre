import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { load, getter, ROOT } from "./load.mjs";

const Snd = load("services/sounds.js");

test("у каждого события есть файл в extras/sounds/ochre и переключатель в схеме", () => {
    const get = getter();
    for (const [event, group] of Object.entries(Snd.EVENTS)) {
        assert.ok(existsSync(join(ROOT, "extras/sounds/ochre", event + ".wav")), event);
        assert.equal(typeof get("shell.sound." + group), "boolean", group);
    }
});

test("allowed: общий выключатель, группа, неизвестное событие", () => {
    assert.equal(Snd.allowed(getter(), "notify", false), true);
    assert.equal(Snd.allowed(getter({ "shell.sound": false }), "notify", false), false);
    assert.equal(Snd.allowed(getter({ "shell.sound.lock": false }), "unlock", false), false);
    assert.equal(Snd.allowed(getter(), "volume", false), false);
    assert.equal(Snd.allowed(getter(), "nope", false), false);
});

test("allowed: «не беспокоить» глушит только обычные уведомления", () => {
    assert.equal(Snd.allowed(getter(), "notify", true), false);
    assert.equal(Snd.allowed(getter(), "critical", true), true);
    assert.equal(Snd.allowed(getter(), "battery-low", true), true);
});

test("volume: доля громкости, тише при музыке", () => {
    assert.equal(Snd.volume(getter({ "shell.sound.level": 60 }), false), 0.6);
    assert.equal(Snd.volume(getter({ "shell.sound.level": 60, "shell.sound.duck": 50 }), true), 0.3);
    assert.equal(Snd.volume(getter({ "shell.sound.duck": 0 }), true), 0);
});

test("argv: пути и событие аргументами, не в тексте скрипта", () => {
    const a = Snd.argv("/u", "/t", "lock", 0.5);
    assert.deepEqual(a.slice(3), ["sh", "/u", "/t", "lock", "0.5"]);
    assert.ok(!a[2].includes("/u") && !a[2].includes("lock"));
    assert.equal(Snd.argv("/u", "/t", "../x", 1), null);
});
