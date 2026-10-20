import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services

// Ошибки shell и niri как лог компилятора (services/Errors.qml), в углу монитора с фокусом:
//   ┌[ ~/log/errors ]──────────────────────────────────┐
//   │ qs   bar/Privacy.qml:42  TypeError: Cannot read … │
//   │ niri ochre/layout.kdl:3  unexpected node `foo`    │
//   │ [скопировать] [сообщить] [очистить] [закрыть]     │
// Фокус клавиатуры не забирает. Закрытое окно снова появляется только на новую ошибку.
Scope {
    id: root

    function c(color, s) {
        return "<font color='" + color + "'>" + s + "</font>";
    }
    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    LazyLoader {
        active: Errors.open && Errors.list.length > 0

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { bottom: true; right: true }
            margins { bottom: Theme.pad * 2; right: Theme.pad * 2 }
            implicitWidth: frame.width
            implicitHeight: frame.y + frame.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "ochre-errors"

            TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

            // ширина колонки места — по самому длинному file:line
            readonly property int placeW: Math.min(36, Math.max(...Errors.list.map(e => (e.file + (e.line ? ":" + e.line : "")).length)))

            Rectangle {
                id: frame

                y: title.height / 2
                width: cell.advanceWidth * 80 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2 + title.height / 2
                color: Theme.bg
                border.color: Theme.red
                border.width: 2

                ColumnLayout {
                    id: col
                    x: Theme.pad
                    y: Theme.pad + title.height / 2
                    width: parent.width - Theme.pad * 2
                    spacing: 2

                    Repeater {
                        model: Errors.list.slice(-12)
                        T {
                            required property var modelData
                            readonly property string place: modelData.file ? modelData.file + (modelData.line ? ":" + modelData.line : "") : ""
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: root.c(Theme.gray, modelData.src.padEnd(5).replace(/ /g, "&nbsp;"))
                                + root.c(Theme.aqua, root.esc(place.padEnd(placeW + 1)).replace(/ /g, "&nbsp;"))
                                + root.c(Theme.red, root.esc(modelData.text))
                                + (modelData.count > 1 ? root.c(Theme.gray, " ×" + modelData.count) : "")
                        }
                    }

                    T {
                        visible: Errors.list.length > 12
                        text: I18n.tr("… ещё %1 выше", Errors.list.length - 12)
                        color: Theme.gray
                    }

                    Row {
                        Layout.topMargin: Theme.pad / 2
                        spacing: cell.advanceWidth
                        Repeater {
                            model: [
                                { label: I18n.tr("скопировать"), run: () => Errors.copy() },
                                { label: Errors.reporting ? I18n.tr("собираю…") : I18n.tr("сообщить"), run: () => Errors.report() },
                                { label: I18n.tr("очистить"), run: () => Errors.clear() },
                                { label: I18n.tr("закрыть"), run: () => Errors.close() }
                            ]
                            T {
                                required property var modelData
                                text: "[" + modelData.label + "]"
                                color: ma.containsMouse ? Theme.accent : Theme.fg
                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.modelData.run()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: title
                x: Theme.pad
                width: titleText.implicitWidth + cell.advanceWidth
                height: titleText.implicitHeight
                color: Theme.bg
                T {
                    id: titleText
                    anchors.centerIn: parent
                    text: "[ ~/log/errors ]"
                    color: Theme.red
                    font.bold: true
                }
            }
        }
    }
}
