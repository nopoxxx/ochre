// Загрузка JS-библиотек shell (.pragma library) в node: файл выполняется как тело функции, `.import "x.js" as X`
// подставляются параметрами (загружаются так же, один раз), наружу — все имена верхнего уровня.
// Движок QML старее node: синтаксис ловит qmllint в extras/check.sh, здесь проверяется только поведение.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

const cache = new Map();

export function load(rel) {
    if (cache.has(rel)) return cache.get(rel);
    let src = readFileSync(join(ROOT, rel), "utf8");
    const deps = [...src.matchAll(/^\.import\s+"([^"]+\.js)"\s+as\s+(\w+)/gm)].map(m => [join(dirname(rel), m[1]), m[2]]);
    src = src.replace(/^\.(pragma|import)\b.*$/gm, "");
    const names = [...new Set([...src.matchAll(/^(?:const|var|let|function)\s+([A-Za-z_$][\w$]*)/gm)].map(m => m[1])
        .concat([...src.matchAll(/^var\s+(.*);$/gm)].flatMap(m => [...m[1].matchAll(/(?:^|,\s*)([A-Za-z_$][\w$]*)\s*=/g)].map(x => x[1]))))];
    const mod = new Function(...deps.map(d => d[1]), src + "\nreturn {" + names.join(",") + "};")(...deps.map(d => load(d[0])));
    cache.set(rel, mod);
    return mod;
}

export const S = load("services/settings.js");

// get(key) с умолчаниями схемы и своими значениями поверх
export function getter(over = {}) {
    return k => (k in over ? over[k] : S.defaultOf(k, []));
}
