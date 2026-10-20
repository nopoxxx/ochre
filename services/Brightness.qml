pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Яркость подсветки экрана (/sys/class/backlight, первое устройство). Нет подсветки (десктоп) — available: false.
// Изменения извне (клавиши → brightnessctl) inotify в sysfs не видит. Ядро шлёт uevent change на каждую запись
// яркости (sysfs, горячие клавиши ACPI) — слушаем `udevadm monitor`. Пока событий не было, опрос раз в 400 мс:
// вдруг на этом железе их нет; после первого — раз в 5 с, на случай пропущенных.
Singleton {
    id: root

    property string dev: ""
    property int max: 0
    property int raw: -1
    readonly property bool available: dev !== "" && max > 0
    readonly property real value: available && raw >= 0 ? raw / max : 0

    function set(v) {
        if (!available) return;
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        Quickshell.execDetached(["brightnessctl", "--class=backlight", "--device=" + dev, "set", pct + "%"]);
        raw = Math.round(max * pct / 100);   // сразу, не дожидаясь опроса: ползунок не прыгает
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -r "$d/max_brightness" ] && { echo "${d##*/} $(cat "$d/max_brightness")"; break; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const [dev, max] = this.text.trim().split(" ");
                if (!dev) return;
                root.max = Number(max);
                root.dev = dev;
            }
        }
    }

    FileView {
        id: file
        path: root.dev ? "/sys/class/backlight/" + root.dev + "/actual_brightness" : ""
        onLoaded: root.raw = parseInt(text())
    }

    property bool events: false   // udev уже присылал события: опрос можно реже

    Process {
        running: root.available
        // pdeathsig: умрёт вместе с qs — иначе каждый перезапуск shell оставлял бы ещё один udevadm
        command: ["setpriv", "--pdeathsig", "TERM", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (!/\bchange\b/.test(line)) return;
                root.events = true;
                file.reload();
            }
        }
    }

    Timer {
        interval: root.events ? 5000 : 400
        running: root.available
        repeat: true
        onTriggered: file.reload()
    }
}
