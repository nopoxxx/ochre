import QtQuick
import qs
import qs.bar
import qs.services

// ↓1.2M ↑40K — суммарно по интерфейсам
Seg {
    value: "↓" + Sys.fmtRate(Sys.rx) + " ↑" + Sys.fmtRate(Sys.tx)
    compact: value.replace(" ", "\n")

    SysUse { metrics: ["net"] }   // Sys читает метрики, только пока модуль есть
}
