import QtQuick
import qs
import qs.bar
import qs.services

// ● REC 01:23 — идёт запись экрана (services/Recorder.qml); клик — остановить. Без записи модуля не видно.
Seg {
    id: root

    available: Recorder.recording
    label: ""
    value: "● REC " + String(Math.floor(Recorder.elapsed / 60)).padStart(2, "0") + ":" + String(Recorder.elapsed % 60).padStart(2, "0")
    compact: value.replace("REC ", "REC\n")
    valueColor: Recorder.elapsed % 2 ? Theme.red : Qt.darker(Theme.red, 1.4)
    bold: true

    onLeftClicked: Recorder.stop()
}
