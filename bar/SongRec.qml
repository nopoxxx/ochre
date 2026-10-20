import QtQuick
import qs
import qs.bar
import qs.services

// ♪? — распознать песню (services/SongRec.qml): клик — системный звук, правый — микрофон, во время записи — отмена.
Seg {
    id: root

    label: ""
    value: SongRec.phase === "listening" ? I18n.tr("♪ слушаю %1", SongRec.remaining)
        : SongRec.phase === "searching" ? I18n.tr("♪ ищу…") : "♪?"
    valueColor: SongRec.busy ? Theme.accent : Theme.gray
    bold: SongRec.busy

    onLeftClicked: SongRec.recognize(false)
    onRightClicked: SongRec.recognize(true)
}
