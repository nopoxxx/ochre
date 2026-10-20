import QtQuick
import qs
import qs.services
import "../services/settings.js" as S

Row {
    id: ts
    property string name
    property real size: 8

    spacing: 1
    Repeater {
        model: S.themeStrip(ts.name, k => Settings.get(k))
        Rectangle {
            required property var modelData
            width: ts.size
            height: ts.size
            color: modelData
            border.color: Theme.bg2
            border.width: 1
        }
    }
}
