<p align="center"><img src="docs/brand/ochre-lockup-horizontal.svg" alt="ochre" width="520"></p>

# ochre

*тёплая терминальная оболочка для niri*

Оболочка рабочего стола для [niri](https://github.com/YaLTeR/niri) на [Quickshell](https://quickshell.org) в стиле терминала:
панель — строка shell, меню — fzf, настройки — menuconfig. Девять палитр (по умолчанию Gruvbox), тёмные и светлые, шрифт Terminess.

```
user@ochre ~/ws/{1,[2]} [1] ❯ kitty  # ~        [‹ 󰙯 󰓓] · cpu ▂▃▅▇ 4% · mem 1.7G · vol 40% · ru · 21:58
```

**Документация: [nopoxxx.github.io/ochre](https://nopoxxx.github.io/ochre/)**

Раньше назывался nopox-shell: при обновлении настройки и конфиг niri переедут в `~/.config/ochre/` и `~/.config/niri/ochre/` сами.

## Установка

Arch Linux и производные, от обычного пользователя:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/ochre/main/install.sh)
```

Установщик спросит терминал, оболочку, браузер, файловый менеджер и программы, покажет итог и только потом поставит.
Флаги и ручная установка — в [документации](https://nopoxxx.github.io/ochre/#install).

Пакетом (в AUR пока нет — собирается из репозитория, обновляется вместе с системой):

```sh
git clone https://github.com/nopoxxx/ochre && cd ochre/extras/aur/ochre-git && makepkg -si
ochre setup
```

## Клавиши

| | |
|---|---|
| `Mod+D` | меню: программы, обои, пакеты, питание |
| `Mod+Space` | программы |
| `Mod+S` | настройки |
| `Mod+Return` | терминал |
| `Mod+Shift+S` | скриншот с разметкой |
| `Mod+Shift+T` / `Mod+Shift+C` | текст с экрана / цвет в буфер |
| `Mod+Shift+V` | история буфера обмена |
| `Mod+A` | меню home: переключатели, звук, медиа, погода, Wi-Fi, bluetooth (или клик по `user@host`) |
| `Mod+Alt+R` | запись экрана |
| `Mod+Shift+G` | игровой режим: niri без анимаций и теней, уведомления молчат |
| `Mod+Shift+M` | распознать песню, что сейчас играет (songrec) |
| `Super+Alt+L` | блокировка |
| `Mod+/` | шпаргалка клавиш: все сочетания по группам, с поиском |
| `Mod+Shift+/` | все клавиши niri |

## Разработка

Исходник документации — [`docs/index.html`](docs/index.html).

## Лицензия

[GPL-3.0-or-later](LICENSE). Скриншот с разметкой сделан по мотивам [rishot](https://github.com/ryoku-dev/ryoshot) (MIT).
