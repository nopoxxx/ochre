.pragma library

// Калькулятор для меню (строка «=выражение»). Свой разбор, без eval/Function:
// текст из меню не должен становиться кодом. Рекурсивный спуск:
//   expr  := term (("+" | "-") term)*
//   term  := unary (("*" | "/" | "%") unary)*
//   unary := ("-" | "+") unary | power
//   power := atom ("^" unary)?          — правоассоциативно, -2^2 = -4
//   atom  := число | константа | функция "(" expr ")" | "(" expr ")"
// Возвращает { value: "строка" } или { error: "текст", arg } — текст с %1 переводит вызывающий (I18n.tr(error, arg)).

const CONSTS = { pi: Math.PI, e: Math.E };
const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    ln: Math.log, log: Math.log10, sin: Math.sin, cos: Math.cos, tan: Math.tan
};

function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const ch = s[i];
        if (/\s/.test(ch)) { i++; continue; }
        let m = /^0x[0-9a-f]+/i.exec(s.slice(i))
             || /^(\d+([.,]\d*)?|[.,]\d+)(e[+-]?\d+)?/i.exec(s.slice(i));
        if (m) {
            out.push({ t: "num", v: Number(m[0].replace(",", ".")) });
            i += m[0].length;
            continue;
        }
        m = /^[a-z]+/i.exec(s.slice(i));
        if (m) {
            out.push({ t: "id", v: m[0].toLowerCase() });
            i += m[0].length;
            continue;
        }
        if ("+-*/%^()".includes(ch)) {
            out.push({ t: ch });
            i++;
            continue;
        }
        if (ch === "×") { out.push({ t: "*" }); i++; continue; }
        if (ch === "÷") { out.push({ t: "/" }); i++; continue; }
        throw ["непонятный символ «%1»", ch];
    }
    return out;
}

function evaluate(expr) {
    let toks, p = 0;
    const peek = () => toks[p]?.t;
    const take = t => {
        if (peek() !== t) throw t === ")" ? ["не хватает «)»"] : ["ожидалось «%1»", t];
        p++;
    };

    function parseExpr() {
        let v = parseTerm();
        while (peek() === "+" || peek() === "-")
            v = toks[p++].t === "+" ? v + parseTerm() : v - parseTerm();
        return v;
    }
    function parseTerm() {
        let v = parseUnary();
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            const op = toks[p++].t;
            const r = parseUnary();
            if ((op === "/" || op === "%") && r === 0) throw ["деление на ноль"];
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function parseUnary() {
        if (peek() === "-") { p++; return -parseUnary(); }
        if (peek() === "+") { p++; return parseUnary(); }
        return parsePower();
    }
    function parsePower() {
        const v = parseAtom();
        if (peek() === "^") { p++; return Math.pow(v, parseUnary()); }
        return v;
    }
    function parseAtom() {
        const tok = toks[p];
        if (!tok) throw ["выражение не закончено"];
        if (tok.t === "num") { p++; return tok.v; }
        if (tok.t === "(") { p++; const v = parseExpr(); take(")"); return v; }
        if (tok.t === "id") {
            p++;
            if (tok.v in CONSTS) return CONSTS[tok.v];
            if (tok.v in FUNCS) { take("("); const v = parseExpr(); take(")"); return FUNCS[tok.v](v); }
            throw ["неизвестно: %1", tok.v];
        }
        throw ["лишний «%1»", tok.t];
    }

    try {
        toks = tokenize(expr);
        if (!toks.length) return { error: "" };
        const v = parseExpr();
        if (p < toks.length) throw ["лишний «%1»", toks[p].v ?? toks[p].t];
        if (!isFinite(v)) return { error: "результат не число" };
        return { value: format(v) };
    } catch (e) {
        return Array.isArray(e) ? { error: e[0], arg: e[1] ?? "" } : { error: String(e) };
    }
}

// 12 значащих цифр без хвостовых нулей: 0.1+0.2 → 0.3, 2^64 → 1.84467440737e+19
function format(v) {
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
    let s = v.toPrecision(12);
    if (s.includes("e")) {
        const [m, ex] = s.split("e");
        return (m.includes(".") ? m.replace(/\.?0+$/, "") : m) + "e" + ex;
    }
    return s.includes(".") ? s.replace(/\.?0+$/, "") : s;
}
