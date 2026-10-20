#!/usr/bin/env python3
# Собирает services/emoji.js для меню (emoji/, префикс «:»): одиночные кодовые точки, которые есть
# в цветном шрифте эмодзи, с именами из unicodedata. Флаги и ZWJ-последовательности не входят.
#   python3 extras/emoji-gen.py [/usr/share/fonts/noto/NotoColorEmoji.ttf]
import sys, unicodedata, pathlib, json
from fontTools.ttLib import TTFont

font = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/noto/NotoColorEmoji.ttf"
cmap = TTFont(font).getBestCmap()
skip = set(range(0x1F1E6, 0x1F200)) | set(range(0x1F3FB, 0x1F400)) | set(range(0xE0000, 0xE0080)) \
    | {0x200D, 0x20E3, 0xFE0F, 0x2640, 0x2642, 0x2695}
rows = []
for cp in sorted(cmap):
    if cp < 0xA9 or cp in skip or 0x1F9B0 <= cp <= 0x1F9B3:   # ASCII, модификаторы, «волосы» для ZWJ
        continue
    name = unicodedata.name(chr(cp), "").lower()
    if not name:
        continue
    # у символов до U+1F000 по умолчанию текстовый вид — VS16 просит цветной
    ch = chr(cp) + ("️" if cp < 0x1F000 else "")
    rows.append(ch + "\t" + name)

out = pathlib.Path(__file__).resolve().parent.parent / "services/emoji.js"
out.write_text(".pragma library\n\n// Сгенерировано extras/emoji-gen.py — не править вручную. Строка: символ \\t имя.\n"
               "var LIST = " + json.dumps("\n".join(rows), ensure_ascii=False) + ";\n", encoding="utf-8")
print(len(rows), "emoji →", out)
