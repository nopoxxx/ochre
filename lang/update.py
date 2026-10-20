#!/usr/bin/env python3
"""Собирает строки интерфейса и дописывает новые ключи в lang/*.json.

Исходный язык — русский: ключ — сама строка из кода (см. services/I18n.qml).
Источники:
  1. строки с кириллицей в аргументах I18n.tr(…) в .qml/.js shell (и все строки services/calc.js);
  2. схема настроек: services/settings.js выполняется в node, из sections() и реестров
     берутся заголовки, подписи, подсказки — в том числе склеенные в коде.
Подсказки делятся по «  ·  », как их переводит I18n.tr().

  python3 lang/update.py            # обновить все lang/*.json
  python3 lang/update.py --check    # только сказать, чего не хватает (код выхода 1, если есть пустые)

Существующие переводы не трогаются; ключи, которых больше нет в коде, удаляются (их число печатается).
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANG = ROOT / "lang"
SKIP_DIRS = {"lang", "extras", "docs", ".git"}
CYR = re.compile(r"[А-Яа-яЁё]")
SEP = "  ·  "


ESC = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "b": "\b", "f": "\f", "v": "\v"}


def unescape(raw):
    """Escape-последовательности JS: \\n, \\", \\uXXXX, \\u{…}; остальное — сам символ."""
    def one(m):
        e = m.group(1)
        if e[0] == "u":
            return chr(int(e[2:-1] if e[1] == "{" else e[1:], 16))
        if e[0] == "x":
            return chr(int(e[1:], 16))
        return ESC.get(e, e)
    return re.sub(r"\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|.)", one, raw, flags=re.S)


def literals(text):
    """Строковые литералы JS/QML вне комментариев: "…", '…' и `…` без ${}."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "/" and text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                break
            continue
        if c == "/" and text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in "\"'`":
            j, buf = i + 1, []
            while j < n and text[j] != c:
                if text[j] == "\\" and j + 1 < n:
                    buf.append(text[j:j + 2])
                    j += 2
                    continue
                buf.append(text[j])
                j += 1
            raw = "".join(buf)
            if not (c == "`" and "${" in raw):
                out.append(unescape(raw))
            i = j + 1
            continue
        i += 1
    return out


def tr_args(text):
    """Тексты аргументов всех вызовов I18n.tr(…) — со скобками по балансу, строки внутри не считаются."""
    out, pos = [], 0
    while (i := text.find("I18n.tr(", pos)) >= 0:
        j, depth, quote = i + len("I18n.tr("), 1, None
        while j < len(text) and depth:
            c = text[j]
            if quote:
                if c == "\\":
                    j += 1
                elif c == quote:
                    quote = None
            elif c in "\"'`":
                quote = c
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            j += 1
        out.append(text[i + len("I18n.tr("):j - 1])
        pos = j
    return out


# файлы, где все строки — для интерфейса, а переводит их вызывающий (I18n.tr(error, arg))
WHOLE = {"services/calc.js"}


def from_sources():
    found = set()
    for p in ROOT.rglob("*"):
        rel = p.relative_to(ROOT)
        if p.suffix not in (".qml", ".js") or SKIP_DIRS & set(rel.parts) or p.name == "I18n.qml":
            continue
        text = p.read_text(encoding="utf-8")
        chunks = [text] if rel.as_posix() in WHOLE else tr_args(text)
        for chunk in chunks:
            found.update(s for s in literals(chunk) if CYR.search(s))
    return found


NODE = r"""
const fs = require("fs");
const src = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*$/m, "");
const S = new Function(src + "\nreturn { sections, MODULES, HOME_SECTIONS, LAYOUTS };")();
const out = new Set();
const add = s => { if (typeof s === "string" && s) out.add(s); };
for (const sec of S.sections([], undefined, undefined)) {
    add(sec.title);
    for (const r of sec.rows) { add(r.header); add(r.label); add(r.hint); add(r.zoneLabel); }
}
for (const m of S.MODULES.concat(S.HOME_SECTIONS)) { add(m.label); add(m.desc); add(m.title); }
for (const L of Object.values(S.LAYOUTS)) { Object.values(L.labels).forEach(add); add(L.hint); }
console.log(JSON.stringify([...out]));
"""


def from_schema():
    res = subprocess.run(["node", "-e", NODE, str(ROOT / "services" / "settings.js")],
                         capture_output=True, text=True, check=True)
    return {s for s in json.loads(res.stdout) if CYR.search(s)}


def split(strings):
    out = set()
    for s in strings:
        parts = s.split(SEP) if SEP in s else [s]
        out.update(p for p in parts if CYR.search(p))
    return out


def main():
    check = "--check" in sys.argv
    keys = split(from_sources() | from_schema())
    files = sorted(LANG.glob("*.json"))
    if not files:
        print("нет lang/*.json")
        return 1
    missing_any = False
    for f in files:
        d = json.loads(f.read_text(encoding="utf-8"))
        old = d.get("strings", {})
        new = {k: old.get(k, "") for k in sorted(keys)}
        empty = sum(1 for v in new.values() if not v)
        added = len(keys - old.keys())
        gone = len(old.keys() - keys)
        missing_any |= empty > 0
        print(f"{f.name}: строк {len(new)}, без перевода {empty}, новых {added}, удалено {gone}")
        if not check:
            d["strings"] = new
            f.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return 1 if check and missing_any else 0


if __name__ == "__main__":
    sys.exit(main())
