import QtQuick
import qs
import qs.bar
import qs.services

// cpu ▂▃▅▇ 34% — клик: топ процессов по cpu
Seg {
    id: root

    readonly property string spark: Settings.get("shell.bar.cpuGraph")
        ? Sys.cpuHistory.map(v => "▁▂▃▄▅▆▇█"[Math.min(7, Math.floor(v / 12.5))]).join("") + " "
        : ""

    label: "cpu"
    value: spark + Sys.cpu + "%"
    valueColor: Sys.cpu > 80 ? Theme.red : Sys.cpu > 50 ? Theme.yellow : Theme.fg
    onLeftClicked: procs.toggle()

    ProcsPopup { id: procs; owner: root; bar: root.bar; sort: "cpu" }

    SysUse { metrics: ["cpu"] }   // Sys читает метрики, только пока модуль есть
}
