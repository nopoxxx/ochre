# Обои на монитор и стол — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** свои обои у монитора и стола, слайдшоу из папки, дневной и ночной вариант.

**Architecture:** чистая логика выбора — `services/wallpaper.js` (тесты в node); сервис `Wallpaper` хранит
state в JSON, листает папки и отдаёт `imageFor(output, wsKey)`; `Background`, `LockScreen`, пикер — потребители.

**Tech Stack:** Quickshell (QML, Qt 6), JS `.pragma library`, `node --test`.

**Spec:** `docs/superpowers/specs/2026-10-20-wallpaper-per-output-design.md`

## Global Constraints

- Без комментариев-пересказов; camelCase; стиль окружающего кода.
- Нет методов вне движка QML: `flatMap`, `trimEnd`, `trimStart`, `findLast`, `toSorted`, `replaceAll`, `??=`, `||=`, `&&=`.
- Строки интерфейса — по-русски через `I18n.tr`, переводы — `python3 lang/update.py` + `lang/en.json`.
- State: `~/.local/state/ochre/wallpapers.json`; старый `wallpaper` не удаляется.
- `shell.wallpaper.interval` int 0–240 шаг 5 def 30; `shell.wallpaper.order` enum `cycle|random` def `random`.

## Review Focus

- Битый/пустой JSON — пустой state, файл не перезаписан до первого назначения → тест `parseState`.
- Папка пуста — слот как незаданный, цепочка идёт дальше → тест `resolve` с пустым `dirs`.
- Именованный стол — ключ по имени, не по idx → тест `wsKey`.
- `sun` = null — день 07:00–19:00 → тест `isNight`.
- random на папке из одной картинки не зацикливается → тест `pick`.

---

### Task 1: `services/wallpaper.js`

**Files:** Create `services/wallpaper.js`, `tests/wallpaper.test.mjs`.

**Produces:**
- `wsKey(ws) -> string` — `ws.output + "/" + (ws.name || ws.idx)`; `""` для `null`.
- `parseState(text) -> {all, outputs, workspaces}` — битый JSON → пустой state.
- `slotFor(state, output, wsKey, night) -> {path, level, time} | null` — уровни ws → output → all; ночью `night || day`, днём `day`.
- `nightVariant(path) -> string` — файл `a/foo.png` → `a/foo-night.png`; иначе (папка) `path + "/night"`.
- `isNight(now: Date, sun: {rise, set} | null) -> bool`.
- `pick(n, cur, order, rnd) -> int` — `cycle`: `(cur + 1) % n`; `random`: `floor(rnd*(n-1))`, сдвиг на ≥cur+1, при `n<=1` → 0.
- `resolve(state, output, wsKey, night, exists, listDir, pos) -> string` — `exists(path)`: файл существует; `listDir(path)`: массив файлов папки или `null`. Шаги: slot → если ночь и `time === "day"`, пробует `nightVariant` (файл — `exists`, папка — непустой `listDir`) → если путь — папка: пустая → слот пропускается (повтор `slotFor` без этого уровня), иначе `list[pos % list.length]`.

- [ ] Тесты: цепочка (стол важнее монитора, монитор — всех), ночь узкого уровня, `-night.png`, `night/`, пустая папка, `wsKey` с именем, `isNight` с sun и без, `pick` cycle/random/n=1, `parseState("{")`.
- [ ] `node --test tests/wallpaper.test.mjs` — FAIL, затем реализовать, затем PASS.
- [ ] Commit `Wallpaper: resolve per output and workspace`.

### Task 2: сервис `Wallpaper` и настройки

**Files:** Modify `services/Wallpaper.qml`, `services/settings.js` (раздел «обои»).

**Consumes:** Task 1. **Produces:**
- `state`, `night`, `dirs` (`{path: [files]}`), `pos` (`{output: int}`).
- `imageFor(output: string, wsKey: string) -> string`.
- `current` — `imageFor` сфокусированного выхода/стола.
- `assign(level: "all"|"output"|"ws", time: "day"|"night", path: string)` — цель по сфокусированному экрану/столу; `path === ""` — сбросить.
- `slotPath(level, time) -> string` — значение слота цели (для отметки в пикере).
- `next()` — сдвинуть все позиции.
- `set(path)` = `assign("all", "day", path)`.

- [ ] FileView `wallpapers.json`; FileNotFound → читать старый `wallpaper` → `all.day`; нет и его → horizon.
- [ ] Подмена фирменных по акценту — по всем слотам.
- [ ] Папки: `Process find -maxdepth 1 -type f` картинок для каждой папки из слотов и её `night/`; перезапуск при смене state и на тике слайдшоу.
- [ ] Таймер ночи — 60 с; таймер слайдшоу — `interval * 60000`, выкл. при 0; `pos` стартует с индекса выхода в `Quickshell.screens`.
- [ ] settings.js: две строки после `shell.wallpaper.transition`.
- [ ] `node --test tests/` — PASS. Commit `Wallpaper: state per output and workspace, slideshow, day/night`.

### Task 3: показ

**Files:** Modify `Background.qml`, `LockScreen.qml`, `GreeterSync.qml` (без изменений, если `current` сохраняет смысл).

- [ ] `Background.src` от `Wallpaper.imageFor(screen.name, Wl.wsKey(активный стол выхода))`.
- [ ] `LockScreen`: поверхность — `imageFor(screen.name, …)`.
- [ ] Commit `Wallpaper: each screen shows its own`.

### Task 4: пикер

**Files:** Modify `WallPicker.qml`.

- [ ] `target` (`all|output|ws`) и `time` (`day|night`) в окне; Ctrl+T, Ctrl+N, Ctrl+Delete; строка «куда».
- [ ] Папки: подпапки `Wallpaper.dir` (кроме `night`) и сама коллекция — элементы `{path, thumb: первая картинка, name: "▸имя/", dir: true}`; список папок — свойство `Wallpaper.folders` (`find -mindepth 1 -maxdepth 1 -type d`).
- [ ] `apply` → `Wallpaper.assign(target, time, path)`; отметка ● — `slotPath(target, time) === path`; скачанное с wallhaven — в цель.
- [ ] IPC: `assign(path, level, time)`, `next()`.
- [ ] Подсказка клавиш: `^t куда`, `^n день/ночь`.
- [ ] Commit `Wallpaper picker: assign to screen or workspace, day or night, folders`.

### Task 5: переводы и проверка

- [ ] `python3 lang/update.py`, заполнить пустые в `lang/en.json`.
- [ ] `extras/check.sh` — всё ✓ (qmllint может отсутствовать — сказать об этом).
- [ ] Отметить пункт в TODO не нужно (TODO вне репо). Commit `Lang: wallpaper strings`.
