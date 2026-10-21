import QtQuick
import QtQuick.Layouts
import qs.services

// Новое событие: название, день (‹ › или колёсико), время «10:00–11:00» (колёсико или ↑↓ — по 15 минут, конец идёт
// за началом) или [весь день] на N дней, место или ссылка, календарь (‹ › — свой «ochre» или CalDAV).
// ↵ в любом поле или [сохранить] — записать, Esc или [отмена] — закрыть.
ColumnLayout {
    id: form

    property var day: new Date()
    property bool allDay: false
    property int startMin: 10 * 60
    property int length: 60
    property int days: 1
    property int calIndex: 0
    readonly property var cals: Calendar.writable.length ? Calendar.writable : ["ochre"]
    readonly property string cal: cals[Math.min(calIndex, cals.length - 1)]
    readonly property int calSrc: Math.max(0, Calendar.sources.findIndex(s => s.name === cal))
    signal done()

    spacing: 4

    function hm(min) {
        const m = ((min % 1440) + 1440) % 1440;
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    // «10», «10:30», «1030», «9.15» → минуты; не разобрали — -1
    function parseTime(s) {
        const m = s.trim().match(/^(\d{1,2})(?:[:.\s]?(\d{2}))?$/);
        if (!m || +m[1] > 23 || +(m[2] ?? 0) > 59) return -1;
        return +m[1] * 60 + +(m[2] ?? 0);
    }

    // открыть форму на день: время — ближайшие полчаса после текущего, если день сегодня, иначе 10:00
    function reset(d) {
        const now = new Date();
        day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        allDay = false;
        startMin = Calendar.sameDay(day, now) ? Math.min(23 * 60, Math.ceil((now.getHours() * 60 + now.getMinutes() + 1) / 30) * 30) : 10 * 60;
        length = 60;
        days = 1;
        title.text = "";
        place.text = "";
        startField.text = hm(startMin);
        endField.text = hm(startMin + length);
        title.input.forceActiveFocus();
    }

    function shiftDay(d) { day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + d); }

    function setStart(min) {
        startMin = Math.max(0, Math.min(1439, min));
        startField.text = hm(startMin);
        endField.text = hm(startMin + length);
    }

    function setEnd(min) {
        length = Math.max(15, min - startMin);
        endField.text = hm(startMin + length);
    }

    function save() {
        const s = parseTime(startField.text), e = parseTime(endField.text);
        if (!allDay && s >= 0) startMin = s;
        if (!allDay && e >= 0) length = e > startMin ? e - startMin : e + 1440 - startMin;
        const y = day.getFullYear(), m = day.getMonth(), d = day.getDate();
        Calendar.add({
            cal: cal,
            title: title.text.trim() || I18n.tr("без названия"),
            allDay: allDay,
            start: allDay ? new Date(y, m, d) : new Date(y, m, d, 0, startMin),
            end: allDay ? new Date(y, m, d + days) : new Date(y, m, d, 0, startMin + length),
            location: place.text.trim()
        });
        done();
    }

    CalInput {
        id: title
        Layout.fillWidth: true
        hint: I18n.tr("название")
        onAccepted: form.save()
        onCanceled: form.done()
    }

    RowLayout {
        spacing: 0
        CalBtn { bare: true; label: "‹"; onClicked: form.shiftDay(-1) }
        T {
            text: " " + I18n.locale.toString(form.day, "ddd d MMMM") + " "
            color: Theme.fg
            font.bold: true
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => form.shiftDay(wheel.angleDelta.y > 0 ? -1 : 1)
            }
        }
        CalBtn { bare: true; label: "›"; onClicked: form.shiftDay(1) }
        Item { Layout.fillWidth: true }
        CalBtn { label: I18n.tr("весь день"); on: form.allDay; onClicked: form.allDay = !form.allDay }
    }

    RowLayout {
        visible: !form.allDay
        spacing: 4
        CalInput {
            id: startField
            chars: 5
            wheel: true
            onWheeled: dir => form.setStart(form.startMin + dir * 15)
            onEdited: { const m = form.parseTime(text); if (m >= 0) { form.startMin = m; endField.text = form.hm(m + form.length); } }
            onAccepted: form.save()
            onCanceled: form.done()
        }
        T { text: "–"; color: Theme.gray }
        CalInput {
            id: endField
            chars: 5
            wheel: true
            onWheeled: dir => form.setEnd(form.startMin + form.length + dir * 15)
            onEdited: { const m = form.parseTime(text); if (m > form.startMin) form.length = m - form.startMin; }
            onAccepted: form.save()
            onCanceled: form.done()
        }
        T {
            text: form.length % 60 ? I18n.tr("%1 мин", form.length) : I18n.tr("%1 ч", form.length / 60)
            color: Theme.gray
        }
    }

    RowLayout {
        visible: form.allDay
        spacing: 0
        T { text: I18n.tr("дней") + " "; color: Theme.gray }
        CalBtn { bare: true; label: "‹"; onClicked: form.days = Math.max(1, form.days - 1) }
        T {
            text: " " + form.days + " "
            color: Theme.fg
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => form.days = Math.max(1, Math.min(60, form.days + (wheel.angleDelta.y > 0 ? 1 : -1)))
            }
        }
        CalBtn { bare: true; label: "›"; onClicked: form.days = Math.min(60, form.days + 1) }
    }

    CalInput {
        id: place
        Layout.fillWidth: true
        hint: I18n.tr("место или ссылка")
        onAccepted: form.save()
        onCanceled: form.done()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        T { text: "●"; color: Theme.calendars[form.calSrc % Theme.calendars.length] }
        CalBtn {
            visible: form.cals.length > 1
            bare: true
            label: "‹"
            onClicked: form.calIndex = (form.calIndex + form.cals.length - 1) % form.cals.length
        }
        T { text: form.cals.length > 1 ? form.cal : " " + form.cal; color: Theme.fg }
        CalBtn {
            visible: form.cals.length > 1
            bare: true
            label: "›"
            onClicked: form.calIndex = (form.calIndex + 1) % form.cals.length
        }
        Item { Layout.fillWidth: true }
        CalBtn { label: I18n.tr("отмена"); onClicked: form.done() }
        T { text: " " }
        CalBtn { label: I18n.tr("сохранить"); on: true; onClicked: form.save() }
    }
}
