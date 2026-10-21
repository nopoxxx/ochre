import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Копирует настройки, обои (у живых — постер) и режим заполнения в /var/lib/ochre-greeter/$USER —
// greeter (под пользователем greeter) не может читать домашнюю папку, а оттуда — может.
// Каталог создаёт extras/install-greeter.sh; без него ничего не делает. Greeter, поставленный ещё под именем
// nopox-shell, читает /var/lib/nopox-greeter — пишем туда, пока его не переустановят.
Scope {
    Timer {
        id: debounce
        interval: 2000
        // до загрузки настроек settings.json по новому пути ещё нет — не затереть копию greeter
        onTriggered: if (Settings.writable) sync.running = true
    }

    Connections {
        target: Settings
        function onValuesChanged() { debounce.restart(); }
        function onWritableChanged() { debounce.restart(); }
    }

    Connections {
        target: Wallpaper
        function onStillChanged() { debounce.restart(); }
        function onFillChanged() { debounce.restart(); }
    }

    Component.onCompleted: debounce.restart()

    Process {
        id: sync
        command: ["sh", "-c", `
            d=/var/lib/ochre-greeter/$USER
            [ -d "$d" ] || d=/var/lib/nopox-greeter/$USER
            [ -d "$d" ] && [ -w "$d" ] || exit 0
            if [ -f "$1" ]; then cp -f "$1" "$d/settings.json"; else rm -f "$d/settings.json"; fi
            if [ -n "$2" ] && [ -f "$2" ]; then cp -f "$2" "$d/wallpaper"; else rm -f "$d/wallpaper"; fi
            printf '%s\\n' "$3" > "$d/wallpaper-fill"
            chmod 644 "$d"/* 2>/dev/null || true`,
            "sh", Settings.file, Wallpaper.still, Wallpaper.fill]
    }
}
