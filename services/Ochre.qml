pragma Singleton
import Quickshell
import QtQuick

// Как достучаться до этого экземпляра shell. Quickshell различает экземпляры по пути конфига:
// git-клон в ~/.config/quickshell — конфиг по умолчанию, хватает `qs`; пакет (/usr/share/ochre) и любой другой
// каталог — `qs -p <каталог>`, иначе `qs ipc call` уйдёт в конфиг по умолчанию («Target not found»).
//   Ochre.qs              argv запуска: ["qs"] или ["qs", "-p", dir]
//   Ochre.ipc(t, f, …)    qs ipc call этому экземпляру
//   Ochre.restartScript   sh-скрипт перезапуска; аргументы — Ochre.sel
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir
    readonly property bool isDefault: dir === Quickshell.env("HOME") + "/.config/quickshell"
    // поставлен пакетом: файлы меняет pacman, обновления — не git
    readonly property bool system: dir.startsWith("/usr/")
    readonly property var sel: isDefault ? [] : ["-p", dir]
    readonly property var qs: ["qs"].concat(sel)

    function ipcArgv(args) { return ["qs", "ipc"].concat(sel, ["call"], args); }
    function ipc(...args) { Quickshell.execDetached(ipcArgv(args)); }

    // перезапуск через отвязанный процесс: он переживёт выход самого quickshell. qs kill гасит по одному
    // экземпляру этого конфига — до ошибки «нет экземпляров»; другие конфиги quickshell не трогаем
    // qs kill может уронить Quickshell на выходе, и сторож падений сразу поднимает его снова — запуск поверх дал бы
    // две панели: гасим раундами, пока `qs list` не пуст
    readonly property string restartScript: 'for r in 1 2 3; do n=0; while [ $n -lt 10 ] && qs kill "$@" >/dev/null 2>&1; do n=$((n+1)); done; '
        + 'sleep 1.5; qs list "$@" 2>&1 | grep -q Instance || break; done; niri msg action spawn -- qs "$@"'
}
