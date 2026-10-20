import QtQuick

// Подписка на метрики Sys, пока жив элемент: SysUse { metrics: ["cpu", "mem"] } внутри модуля или секции.
// Без подписчиков Sys не читает /proc и /sys вовсе. metrics задаётся один раз, при создании.
QtObject {
    property var metrics: []
    Component.onCompleted: Sys.use(metrics, 1)
    Component.onDestruction: Sys.use(metrics, -1)
}
