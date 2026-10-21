import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const AW = load("services/autowidth.js");

const win = (id, ws, col, extra = {}) => Object.assign({ id, workspace_id: ws, is_floating: false, layout: col == null ? {} : { pos_in_scrolling_layout: [col, 1] } }, extra);

test("plan: одна колонка — 100%, две — по 50%, три и больше — не трогать", () => {
    assert.deepEqual(AW.plan([win(1, 1, 1)]), [[1, "100%"]]);
    assert.deepEqual(AW.plan([win(1, 1, 1), win(2, 1, 2)]), [[1, "50%"], [2, "50%"]]);
    assert.deepEqual(AW.plan([win(1, 1, 1), win(2, 1, 2), win(3, 1, 3)]), []);
});

test("plan: окна одной колонки — одна колонка, плавающие не в счёт, без позиции — по окну", () => {
    assert.deepEqual(AW.plan([win(1, 1, 1), win(2, 1, 1)]), [[1, "100%"]]);
    assert.deepEqual(AW.plan([win(1, 1, 1), win(2, 1, null, { is_floating: true })]), [[1, "100%"]]);
    assert.deepEqual(AW.plan([win(1, 1, null), win(2, 1, null)]), [[1, "50%"], [2, "50%"]]);
});

test("changed: столы, где сменился набор окон в раскладке; опустевшие и смена фокуса — нет", () => {
    const a = AW.tiledSets({ 1: win(1, 1, 1), 2: win(2, 2, 1) });
    assert.deepEqual(AW.changed(a, AW.tiledSets({ 1: win(1, 1, 1, { is_focused: true }), 2: win(2, 2, 1) })), []);
    assert.deepEqual(AW.changed(a, AW.tiledSets({ 1: win(1, 1, 1), 2: win(2, 2, 1), 3: win(3, 1, 2) })), [1]);
    assert.deepEqual(AW.changed(a, AW.tiledSets({ 1: win(1, 1, 1) })), []);
    assert.deepEqual(AW.changed(a, AW.tiledSets({ 1: win(1, 2, 2), 2: win(2, 2, 1) })), [2]);
    assert.deepEqual(AW.changed(a, AW.tiledSets({ 1: win(1, 1, 1, { is_floating: true }), 2: win(2, 2, 1) })), []);
});
