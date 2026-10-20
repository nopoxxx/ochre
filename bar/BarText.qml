import QtQuick
import qs

// Текст модуля панели: высота и базовая линия — от шрифта, а не от содержимого.
// Знаки, которых нет в Terminess (◑ ✳ в заголовке Claude Code, эмодзи), Qt берёт из запасного шрифта
// с более высокой строкой: текст рос на 3–6 px, и зона, выровненная по центру, сдвигалась вверх.
T {
    id: t

    height: fm.height
    // запасной шрифт опускает базовую линию — возвращаем её на место, вровень с соседями
    transform: Translate { y: Math.round(fm.ascent - t.baselineOffset) }

    FontMetrics { id: fm; font: t.font }
}
