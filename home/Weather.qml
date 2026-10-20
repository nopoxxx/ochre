import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Погода Open-Meteo: сейчас (значок, температура, ощущается, ветер, влажность) и прогноз по дням.
// ↵ — обновить. Город, единицы и число дней — в настройках (home/ → погода).
Section {
    id: sec

    title: I18n.tr("погода") + (Weather.place ? " · " + Weather.place.name : "")
    count: 1

    readonly property var now: Weather.current ? Weather.describe(Weather.current.code, Weather.current.day) : null

    function activate(i) { Weather.refresh(); }

    function deg(t) { return (t > 0 ? "+" : "") + t + "°"; }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight
        color: sec.isCur(0) ? Theme.bg1 : "transparent"

        TapHandler { onTapped: { sec.pick(0); sec.activate(0); } }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 2

            T {
                visible: !Weather.current
                color: Weather.error ? Theme.red : Theme.gray
                text: Weather.error ? I18n.tr("%1 — ↵ повторить", Weather.error) : I18n.tr("загрузка…")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            RowLayout {
                visible: !!Weather.current
                spacing: 0
                T {
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize * 2
                    text: sec.now?.icon ?? ""
                    color: Theme.accent
                    Layout.rightMargin: Theme.pad
                }
                ColumnLayout {
                    spacing: 0
                    T {
                        textFormat: Text.StyledText
                        text: `<b>${sec.deg(Weather.current?.temp ?? 0)}${Weather.tempUnit.slice(1)}</b>  ${sec.now?.text ?? ""}`
                    }
                    T {
                        color: Theme.gray
                        text: I18n.tr("ощущается %1 · ветер %2 %3", sec.deg(Weather.current?.feels ?? 0), Weather.current?.wind ?? 0, Weather.windUnit)
                            + " · " + (Weather.current?.humidity ?? 0) + "%"
                    }
                }
            }

            // пт 󰖙 +9° +3°   сб 󰖗 +7° +2°
            Flow {
                Layout.fillWidth: true
                visible: Weather.daily.length > 1
                spacing: sec.panel.cell.advanceWidth * 2
                Repeater {
                    model: Weather.daily.slice(1)
                    Row {
                        required property var modelData
                        T { text: I18n.locale.toString(modelData.date, "ddd") + " "; color: Theme.gray }
                        T { font.family: Theme.iconFont; text: Weather.describe(modelData.code, true).icon + " "; color: Theme.accent }
                        T { text: sec.deg(modelData.max) + " "; color: Theme.fg }
                        T { text: sec.deg(modelData.min); color: Theme.gray }
                    }
                }
            }
        }
    }
}
