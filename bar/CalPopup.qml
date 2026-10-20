import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services

// Календарь под часами — CalGrid в TUI-рамке, под ним ближайшие события (клик по дню — события этого дня)
TuiPopup {
    id: pop

    title: "cal"

    readonly property int max: 8
    readonly property real wide: grid.implicitWidth * 1.8
    readonly property var shown: (grid.picked ? Calendar.on(grid.picked) : Calendar.upcoming).slice(0, max)

    onOpenChanged: if (open) grid.today()

    CalGrid { id: grid }

    ColumnLayout {
        visible: Calendar.configured
        Layout.fillWidth: true
        spacing: 2

        T {
            text: "── " + (grid.picked ? I18n.locale.toString(grid.picked, "ddd d MMMM") : I18n.tr("ближайшие")) + " ──"
            color: Theme.gray
        }

        T {
            visible: pop.shown.length === 0
            text: I18n.tr("событий нет")
            color: Theme.gray
        }

        Repeater {
            model: pop.shown

            CalEvent {
                required property var modelData
                Layout.fillWidth: true
                Layout.maximumWidth: pop.wide
                event: modelData
                withDay: !grid.picked

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.event.link !== ""
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { const e = parent.event; pop.open = false; Calendar.open(e); }
                }
            }
        }

        T {
            visible: Calendar.errorText() !== ""
            Layout.fillWidth: true
            Layout.maximumWidth: pop.wide
            wrapMode: Text.Wrap
            text: Calendar.errorText()
            color: Theme.red
        }
    }
}
