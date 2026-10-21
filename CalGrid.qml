import QtQuick
import QtQuick.Layouts
import qs.services

// Месяц как вывод `cal`, крупными клетками под мышь: ‹ › или колёсико — соседние месяцы, клик — выбрать день (picked),
// двойной клик — новое событие на этот день (addRequested). Под числом — точки календарей, у которых в этот день события.
// Общий для попапа часов (bar/CalPopup.qml) и секции календаря в меню home (через CalView).
ColumnLayout {
    id: grid

    spacing: 2

    function today() { now = new Date(); offset = 0; picked = new Date(); }
    function shift(d) { offset += d; }

    signal dayClicked(var day)
    signal addRequested(var day)

    property int offset: 0
    property var now: new Date()
    property var picked: new Date()
    property real cellWidth: cell.advanceWidth
    readonly property var loc: I18n.locale
    readonly property var month: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property bool away: offset !== 0 || !Calendar.sameDay(picked, now)
    readonly property int firstDay: loc.firstDayOfWeek % 7   // 0 — воскресенье, как в Date.getDay()
    readonly property var cells: {
        const y = month.getFullYear(), m = month.getMonth();
        const lead = (month.getDay() - firstDay + 7) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++) out.push(0);
        for (let d = 1; d <= days; d++) out.push(d);
        return out;
    }

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "0000"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        CalBtn { bare: true; label: "‹"; onClicked: grid.shift(-1) }
        T {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: grid.loc.standaloneMonthName(grid.month.getMonth()) + " " + grid.month.getFullYear()
            color: Theme.fg
            font.bold: true
        }
        CalBtn { visible: grid.away; label: I18n.tr("сегодня"); onClicked: grid.today() }
        CalBtn { bare: true; label: "›"; onClicked: grid.shift(1) }
    }

    Grid {
        columns: 7
        rowSpacing: 1

        Repeater {
            model: 7
            T {
                required property int index
                readonly property int day: (grid.firstDay + index) % 7
                width: grid.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: grid.loc.dayName(day, Locale.ShortFormat).slice(0, 2)
                color: day === 0 || day === 6 ? Theme.red : Theme.gray
            }
        }

        Repeater {
            model: grid.cells

            Rectangle {
                id: day
                required property int modelData
                required property int index
                readonly property int weekday: (grid.firstDay + index) % 7
                readonly property var date: new Date(grid.month.getFullYear(), grid.month.getMonth(), modelData)
                readonly property bool real: modelData > 0
                readonly property bool today: real && Calendar.sameDay(date, grid.now)
                readonly property bool chosen: real && grid.picked !== null && Calendar.sameDay(date, grid.picked)
                readonly property var srcs: real ? Calendar.srcsOn(date.getFullYear(), date.getMonth(), modelData) : []

                width: grid.cellWidth
                height: num.implicitHeight + dots.height
                color: today ? Theme.accent : chosen ? Theme.bg2 : area.containsMouse && real ? Theme.hover : "transparent"
                border.color: chosen ? Theme.accent : "transparent"
                border.width: 1

                T {
                    id: num
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.real ? day.modelData : ""
                    color: day.today ? Theme.bg : day.weekday === 0 || day.weekday === 6 ? Theme.red : Theme.fg
                    font.bold: day.today || day.chosen
                }

                Row {
                    id: dots
                    anchors { top: num.bottom; horizontalCenter: parent.horizontalCenter }
                    height: Math.round(Theme.fontSize * 0.6)
                    spacing: 2
                    Repeater {
                        model: day.srcs.slice(0, 3)
                        Rectangle {
                            required property int modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(3, Math.round(Theme.fontSize / 4))
                            height: width
                            radius: width / 2
                            color: day.today ? Theme.bg : Theme.calendars[modelData % Theme.calendars.length]
                        }
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: day.real
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = day.date;
                        grid.picked = d;
                        grid.dayClicked(d);
                    }
                    onDoubleClicked: grid.addRequested(day.date)
                }
            }
        }
        WheelHandler {
            onWheel: event => grid.shift(event.angleDelta.y > 0 ? -1 : 1)
        }
    }
}
