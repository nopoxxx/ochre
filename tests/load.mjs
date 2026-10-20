// Загрузка JS-библиотек shell (.pragma library) в node: файл выполняется как тело функции,
// наружу — перечисленные имена. Движок QML старее node: синтаксис ловит qmllint в extras/check.sh,
// здесь проверяется только поведение.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

export function load(rel, names) {
    const src = readFileSync(join(ROOT, rel), "utf8").replace(/^\.(pragma|import)\b.*$/gm, "");
    return new Function(src + "\nreturn {" + names.join(",") + "};")();
}

export const S = load("services/settings.js", [
    "sections", "defaultOf", "niriFiles", "niriFileOf", "normalizeLayout", "moveModule", "placeModule",
    "parseBinds", "actionKdl", "comboKey", "keysKdl", "searchRows", "LAYOUTS", "MODULES", "HOME_SECTIONS",
    "DEFAULT_LAYOUT", "NIRI_ANIMS", "ACCENTS", "COMBO_RE"
]);

// get(key) с умолчаниями схемы и своими значениями поверх
export function getter(over = {}) {
    return k => (k in over ? over[k] : S.defaultOf(k, []));
}
