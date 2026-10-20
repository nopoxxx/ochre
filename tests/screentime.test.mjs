import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const ST = load("services/screentime.js");

const at = (d, h, m = 0, s = 0) => new Date(2026, 9, d, h, m, s).getTime();

test("dayKey: местная дата", () => {
    assert.equal(ST.dayKey(at(5, 23, 59)), "2026-10-05");
    assert.equal(ST.dayKey(at(20, 0, 0)), "2026-10-20");
});

test("add: секунды на приложение, исходный объект не меняется", () => {
    const d0 = {};
    const d1 = ST.add(d0, "kitty", at(20, 10), at(20, 10, 1, 30));
    assert.deepEqual(d0, {});
    assert.deepEqual(d1, { "2026-10-20": { kitty: 90 } });
    const d2 = ST.add(d1, "kitty", at(20, 11), at(20, 11, 0, 10));
    assert.equal(d2["2026-10-20"].kitty, 100);
});

test("add: интервал через полночь делится по дням", () => {
    const d = ST.add({}, "firefox", at(19, 23, 50), at(20, 0, 15));
    assert.deepEqual(d, { "2026-10-19": { firefox: 600 }, "2026-10-20": { firefox: 900 } });
});

test("add: пустое приложение, пустой или обратный интервал — без изменений", () => {
    const d = { "2026-10-20": { a: 5 } };
    assert.equal(ST.add(d, "", at(20, 1), at(20, 2)), d);
    assert.equal(ST.add(d, "a", at(20, 2), at(20, 1)), d);
    assert.equal(ST.add(d, "a", at(20, 2), at(20, 2)), d);
});

test("prune: остаются последние keep дней", () => {
    const d = { "2026-10-10": { a: 1 }, "2026-10-14": { a: 2 }, "2026-10-20": { a: 3 } };
    assert.deepEqual(Object.keys(ST.prune(d, 7, at(20, 12))).sort(), ["2026-10-14", "2026-10-20"]);
});

test("top: по убыванию, n штук; total — сумма", () => {
    const day = { a: 10, b: 300, c: 60 };
    assert.deepEqual(ST.top(day, 2), [{ app: "b", sec: 300 }, { app: "c", sec: 60 }]);
    assert.equal(ST.total(day), 370);
    assert.deepEqual(ST.top(undefined, 3), []);
    assert.equal(ST.total(undefined), 0);
});

test("fmt: часы и минуты", () => {
    assert.equal(ST.fmt(30), "<1m");
    assert.equal(ST.fmt(45 * 60), "45m");
    assert.equal(ST.fmt(2 * 3600 + 5 * 60 + 20), "2h05m");
});

test("add: sign −1 снимает, ноль удаляет ключ", () => {
    const d = ST.add({}, "a", at(20, 10), at(20, 10, 2));
    assert.deepEqual(ST.add(d, "a", at(20, 10, 1), at(20, 10, 2), -1), { "2026-10-20": { a: 60 } });
    assert.deepEqual(ST.add(d, "a", at(20, 10), at(20, 10, 5), -1), { "2026-10-20": {} });
});

test("undo: снимает только время после t", () => {
    let d = ST.add({}, "a", at(20, 10), at(20, 10, 3));
    d = ST.add(d, "b", at(20, 10, 3), at(20, 10, 6));
    const recent = [{ app: "a", from: at(20, 10), to: at(20, 10, 3) }, { app: "b", from: at(20, 10, 3), to: at(20, 10, 6) }];
    assert.deepEqual(ST.undo(d, recent, at(20, 10, 2)), { "2026-10-20": { a: 120 } });
});
