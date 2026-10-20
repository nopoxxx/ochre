import QtQuick
import qs
import qs.bar
import qs.services

// temp 58° — температура cpu; без датчика модуль скрыт
Seg {
    available: Sys.cpuTemp >= 0
    label: "temp"
    value: Sys.cpuTemp + "°"
    valueColor: Sys.cpuTemp > 85 ? Theme.red : Sys.cpuTemp > 70 ? Theme.yellow : Theme.fg

    SysUse { metrics: ["temp"] }   // Sys читает метрики, только пока модуль есть
}
