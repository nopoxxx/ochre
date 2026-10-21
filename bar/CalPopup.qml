import QtQuick
import qs
import qs.bar
import qs.services

// Календарь под часами — CalView в TUI-рамке: месяц, события дня, добавление и удаление мышью
TuiPopup {
    id: pop

    title: "cal"

    onOpenChanged: if (open) view.today()

    CalView {
        id: view
        onCloseRequested: pop.open = false
    }
}
