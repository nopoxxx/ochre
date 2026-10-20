import QtQuick
import qs
import qs.bar
import qs.services

// mem 3.1G — клик: топ процессов по памяти
Seg {
    id: root

    label: "mem"
    value: Sys.memUsed.toFixed(1) + "G"
    valueColor: Sys.memTotal && Sys.memUsed / Sys.memTotal > 0.85 ? Theme.red : Theme.fg
    onLeftClicked: procs.toggle()

    ProcsPopup { id: procs; owner: root; bar: root.bar; sort: "mem" }

    SysUse { metrics: ["mem"] }   // Sys читает метрики, только пока модуль есть
}
