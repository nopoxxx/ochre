import QtQuick
import QtQuick.Layouts
import qs.services

// Месяц как вывод `cal`: ‹ › или колёсико — соседние месяцы, сегодня выделено акцентом.
// Дни с событиями календарей (services/Calendar.qml) подчёркнуты; клик по дню выбирает его (picked).
// Общий для попапа часов (bar/CalPopup.qml) и секции календаря в меню home.
ColumnLayout {
    id: grid

    spacing: 2

    function today() { now = new Date(); offset = 0; picked = null; }

    signal dayClicked(var day)

    property int offset: 0
    property var now: new Date()
    property var picked: null
    readonly property var loc: I18n.locale
    readonly property var month: new Date(now.getFullYear(), now.getMonth() + offset, 1)
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
        text: "000"
    }

    RowLayout {
        Layout.fillWidth: true

        T {
            text: "‹"
            color: Theme.accent
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: grid.offset-- }
        }
        T {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: grid.loc.standaloneMonthName(grid.month.getMonth()) + " " + grid.month.getFullYear()
            color: Theme.fg
            font.bold: true
        }
        T {
            text: "›"
            color: Theme.accent
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: grid.offset++ }
        }
    }

    Grid {
        columns: 7

        Repeater {
            model: 7
            T {
                required property int index
                readonly property int day: (grid.firstDay + index) % 7
                width: cell.advanceWidth
                horizontalAlignment: Text.AlignHCenter
                text: grid.loc.dayName(day, Locale.ShortFormat).slice(0, 2)
                color: day === 0 || day === 6 ? Theme.red : Theme.gray
            }
        }

        Repeater {
            model: grid.cells

            Rectangle {
                required property int modelData
                required property int index
                readonly property bool today: modelData > 0 && grid.offset === 0 && modelData === grid.now.getDate()
                readonly property int weekday: (grid.firstDay + index) % 7
                readonly property var date: new Date(grid.month.getFullYear(), grid.month.getMonth(), modelData)
                readonly property bool busy: modelData > 0 && Calendar.count(date.getFullYear(), date.getMonth(), modelData) > 0
                readonly property bool chosen: modelData > 0 && grid.picked !== null && Calendar.sameDay(date, grid.picked)

                width: cell.advanceWidth
                height: dayText.implicitHeight
                color: today ? Theme.accent : chosen ? Theme.bg2 : "transparent"

                T {
                    id: dayText
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? parent.modelData : ""
                    color: parent.today ? Theme.bg : parent.weekday === 0 || parent.weekday === 6 ? Theme.red : Theme.fg
                    font.bold: parent.today || parent.busy
                    font.underline: parent.busy
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.modelData > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = parent.date;
                        grid.picked = d;
                        grid.dayClicked(d);
                    }
                }
            }
        }
        // колёсико по календарю листает месяцы
        WheelHandler {
            onWheel: event => grid.offset += event.angleDelta.y > 0 ? -1 : 1
        }
    }
}
