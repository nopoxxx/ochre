#!/usr/bin/env bash
# Проверка shell перед коммитом (её же зовёт .githooks/pre-commit):
#   1. синтаксис QML/JS — qmllint; провал только на [syntax] (движок QML старее node: ??=, ||= — здесь);
#   2. методы, которых нет в движке QML (TypeError только при вызове): flatMap, trimEnd, trimStart…;
#   3. node --test tests/ — схема настроек, генерация KDL (+ niri validate), бинды, калькулятор;
#   4. lang/update.py --check — у каждой строки интерфейса есть перевод.
#
#   extras/check.sh            всё
#   extras/check.sh --staged   1–2 только по файлам в индексе (быстрее; так зовёт хук)
#
# Пропустить хук разово: git commit --no-verify.
set -uo pipefail
cd "$(dirname "$0")/.."

red() { printf '\033[31m%s\033[0m\n' "$*"; }
ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
fail=0

if [ "${1:-}" = "--staged" ]; then
    mapfile -t files < <(git diff --cached --name-only --diff-filter=ACMR -- '*.qml' '*.js' | grep -v '^\(docs\|extras\)/')
else
    mapfile -t files < <(git ls-files -co --exclude-standard -- '*.qml' '*.js' | grep -v '^\(docs\|extras\)/')
fi

QMLLINT=$(command -v qmllint || command -v qmllint6 || echo /usr/lib/qt6/bin/qmllint)
if [ ${#files[@]} -eq 0 ]; then
    ok "qml/js: нечего проверять"
elif [ -x "$QMLLINT" ] || command -v "$QMLLINT" >/dev/null; then
    out=$("$QMLLINT" "${files[@]}" 2>&1 | grep '\[syntax\]')
    if [ -n "$out" ]; then red "синтаксис (qmllint):"; echo "$out"; fail=1; else ok "синтаксис qml/js (${#files[@]} файлов)"; fi
else
    red "нет qmllint (qt6-declarative) — синтаксис не проверен"
fi

# методы, которых нет в Qt 6.12 (AGENTS.md §9); комментарии не считаются
if [ ${#files[@]} -gt 0 ]; then
    out=$(awk '{ sub(/(^|[^:"])\/\/.*/, ""); print FILENAME ":" FNR ": " $0 }' "${files[@]}" \
        | grep -E '\.(flatMap|trimEnd|trimStart|findLast|findLastIndex|toSorted|toReversed|replaceAll)\(|\?\?=|\|\|=|&&=')
    if [ -n "$out" ]; then red "нет в движке QML:"; echo "$out"; fail=1; else ok "методы JS"; fi
fi

if command -v node >/dev/null; then
    if out=$(node --test tests/ 2>&1); then ok "node --test tests/"; else red "тесты:"; echo "$out" | grep -E '^not ok|Error|expected|actual|niri validate' | head -40; fail=1; fi
else
    red "нет node — тесты не запущены"
fi

if out=$(python3 -I lang/update.py --check 2>&1); then ok "переводы"; else red "переводы (python3 lang/update.py, потом перевести пустые):"; echo "$out"; fail=1; fi

exit $fail
