# ochre — планы

Идеи взяты из [SekaiPop](https://github.com/Blapples/SekaiPop) (Quickshell + Hyprland, GPL-3.0) и переложены на
терминальный стиль ochre. Порядок — порядок работы; `[x]` — сделано.

- [x] **Приватность** — модуль панели `privacy`: кто пишет микрофон (`mic firefox`) и кто показывает экран (`cast obs`).
      Микрофон — связи PipeWire (поток записи ← невыключенный Audio/Source), экран — `niri casts`; без опроса.
- [x] **Ошибки shell** — после перезагрузки конфига всплывает окно как лог компилятора: ошибки QML (`файл:строка: текст`),
      туда же ошибки `niri validate` сгенерированного конфига.
- [x] **Скриншот: ocr и пипетка** — `^O` / `Mod+Shift+T` (tesseract → буфер), пипетка `i` / `Mod+Shift+C` (`niri msg pick-color`).
- [x] **Игровой режим** — `Mod+Shift+G`: анимации, тени, прозрачность niri выкл. поверх своих значений, DND; home/Quick, IPC `game`.
- [x] **polkit-агент** — `Quickshell.Services.Polkit`, окно в стиле `[sudo] password for user:` в TUI-рамке.
- [x] **Бинды: группы** — без запроса список разбит на группы: приставка подписи (`Игры: …`, от двух) или тип действия niri.
- [x] **Таймер, todo, заметки** — модуль `timer 04:32` (меню `timer 25m чай`, IPC `timer`); секции home `todo` (todo.txt) и `notes`.
- [x] **Визуализатор cava** — полоски `▁▂▅▇` в модуле media и home/Media; cava работает, только пока играет и видно.
- [x] **Тексты песен** — LRCLIB (синхронный LRC), текущая строка в home/Media, кэш в `~/.cache/ochre/lyrics`.
- [x] **Переходы обоев** — type (печать строками с курсором), blocks, scan, fade, random — маска + MultiEffect, без своих шейдеров.
- [x] **Первый запуск** — окно «ochre --help» с клавишами и подсказками, один раз; снова — меню → help, IPC `welcome open`.
