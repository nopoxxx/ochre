import QtQuick
import qs
import qs.bar
import qs.services

// gpu 34% 58° — amdgpu; без датчика модуль скрыт
Seg {
    available: Sys.gpu >= 0
    label: "gpu"
    value: Sys.gpu + "%" + (Sys.gpuTemp >= 0 ? " " + Sys.gpuTemp + "°" : "")
    valueColor: Sys.gpu > 80 || Sys.gpuTemp > 85 ? Theme.red : Sys.gpu > 50 ? Theme.yellow : Theme.fg

    SysUse { metrics: ["gpu"] }   // Sys читает метрики, только пока модуль есть
}
