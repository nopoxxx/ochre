// node --test tests/ — калькулятор меню (`= …`) и нечёткий поиск.
import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const C = load("services/calc.js");
const F = load("services/fuzzy.js");

test("calc: приоритет, скобки, степень, функции", () => {
    const v = e => C.evaluate(e).value;
    assert.equal(v("2+2*2"), "6");
    assert.equal(v("(2+2)*2"), "8");
    assert.equal(v("2^10"), "1024");
    assert.equal(v("sqrt(16)"), "4");
    assert.equal(v("10 % 3"), "1");
});

test("calc: ошибки — текст для I18n.tr, а не исключение", () => {
    for (const e of ["1/0", "2+", "(1+2", "2 $ 3"]) {
        const r = C.evaluate(e);
        assert.ok(r.error, `${e}: ждали ошибку, получили ${JSON.stringify(r)}`);
    }
    assert.deepEqual(C.evaluate(""), { error: "" });
});

test("fuzzy: подпоследовательность находится, чужое — нет, ближе к началу — выше", () => {
    assert.ok(F.match("ff", "firefox"));
    assert.equal(F.match("zz", "firefox"), null);
    assert.ok(F.match("set", "settings").score > F.match("set", "reset").score);
});
