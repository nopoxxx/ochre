import QtQuick
import QtQuick.Layouts
import qs.services

// Календарь целиком: месяц (CalGrid), события выбранного дня (CalRow), «дальше» — ближайшие после него, форма нового
// события (CalForm). Всё — мышью: клик по дню — его события, двойной клик или [+ событие] — добавить, колёсико — месяцы.
// Внизу — [календари] (calendars.conf) и [обновить]. Общий для попапа часов и секции календаря в home.
ColumnLayout {
    id: view

    property int maxRows: 6
    property real chars: 34          // ширина списка в символах
    property bool adding: false
    readonly property alias grid: grid
    readonly property var day: grid.picked ?? new Date()
    readonly property var dayEvents: Calendar.on(day)
    readonly property var later: Calendar.upcoming.filter(e => e.start >= new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1))
        .slice(0, Math.max(0, maxRows - dayEvents.length))
    signal closeRequested()

    spacing: 2

    function today() { adding = false; grid.today(); }
    function add(d) {
        if (d) grid.picked = d;
        adding = true;
        form.reset(view.day);
    }

    TextMetrics { id: cm; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

    CalGrid {
        id: grid
        Layout.alignment: Qt.AlignHCenter
        cellWidth: Math.floor(cm.advanceWidth * view.chars / 7)
        onAddRequested: d => view.add(d)
        onDayClicked: view.adding = false
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: cm.advanceWidth * view.chars
        Layout.topMargin: 4
        spacing: 0
        T {
            text: "── " + I18n.locale.toString(view.day, "ddd d MMMM") + " "
            color: Theme.gray
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }
        CalBtn { visible: !view.adding; label: I18n.tr("+ событие"); onClicked: view.add() }
    }

    CalForm {
        id: form
        visible: view.adding
        Layout.fillWidth: true
        onDone: view.adding = false
    }

    T {
        visible: !view.adding && view.dayEvents.length === 0
        text: I18n.tr("событий нет · двойной клик по дню — добавить")
        color: Theme.gray
    }

    Repeater {
        model: view.adding ? [] : view.dayEvents.slice(0, view.maxRows)

        CalRow {
            required property var modelData
            Layout.fillWidth: true
            Layout.maximumWidth: cm.advanceWidth * view.chars
            event: modelData
            onOpened: { const e = modelData; view.closeRequested(); Calendar.open(e); }
        }
    }

    T {
        visible: !view.adding && view.dayEvents.length > view.maxRows
        text: I18n.tr("… ещё %1", view.dayEvents.length - view.maxRows)
        color: Theme.gray
    }

    T {
        visible: !view.adding && view.later.length > 0
        Layout.topMargin: 4
        text: "── " + I18n.tr("дальше") + " ──"
        color: Theme.gray
    }

    Repeater {
        model: view.adding ? [] : view.later

        CalRow {
            required property var modelData
            Layout.fillWidth: true
            Layout.maximumWidth: cm.advanceWidth * view.chars
            event: modelData
            withDay: true
            onOpened: { const e = modelData; view.closeRequested(); Calendar.open(e); }
        }
    }

    T {
        visible: Calendar.errorText() !== ""
        Layout.fillWidth: true
        Layout.maximumWidth: cm.advanceWidth * view.chars
        wrapMode: Text.Wrap
        text: Calendar.errorText()
        color: Theme.red
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 0
        T {
            Layout.fillWidth: true
            text: Calendar.busy ? I18n.tr("сохраняю…") : Calendar.loading ? I18n.tr("обновляю…") : ""
            color: Theme.gray
        }
        CalBtn { label: I18n.tr("календари"); onClicked: { view.closeRequested(); Calendar.edit(); } }
        T { text: " " }
        CalBtn { label: I18n.tr("обновить"); onClicked: Calendar.refresh() }
    }
}
