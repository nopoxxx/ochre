import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services

// Что придёт с обновлением — как `git log --oneline HEAD..origin/main`; [обновить] — pull и перезапуск
TuiPopup {
    id: pop

    title: "git log HEAD.." + (ShellUpdate.upstream || "origin/main")

    function c(color, s) { return `<font color="${color}">${s}</font>`; }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    T {
        visible: ShellUpdate.behind === 0 && !ShellUpdate.error
        text: ShellUpdate.checking ? I18n.tr("проверка…") : I18n.tr("ochre актуален")
        color: Theme.gray
    }

    Repeater {
        model: ShellUpdate.commits.slice(0, 15)

        T {
            required property var modelData
            Layout.maximumWidth: 900
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: pop.c(Theme.yellow, modelData.hash) + " " + pop.c(Theme.fg, pop.esc(modelData.subject))
        }
    }

    T {
        visible: ShellUpdate.behind > 15
        text: I18n.tr("… ещё %1", ShellUpdate.behind - 15)
        color: Theme.gray
    }

    T {
        visible: ShellUpdate.dirty
        text: I18n.tr("! есть локальные правки — git pull --ff-only может не пройти")
        color: Theme.yellow
    }

    T {
        visible: ShellUpdate.error !== ""
        Layout.maximumWidth: 900
        wrapMode: Text.Wrap
        text: ShellUpdate.error
        color: Theme.red
    }

    RowLayout {
        Layout.topMargin: 4
        spacing: 24

        T {
            visible: ShellUpdate.behind > 0
            text: ShellUpdate.updating ? I18n.tr("[обновление…]") : I18n.tr("[обновить]")
            color: Theme.accent
            font.bold: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellUpdate.update()
            }
        }

        T {
            text: I18n.tr("[проверить]")
            color: Theme.gray

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellUpdate.check(true)
            }
        }

        T {
            visible: ShellUpdate.greeterSeparate
            text: I18n.tr("[обновить greeter]")
            color: Theme.gray

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    pop.open = false;
                    ShellUpdate.updateGreeter();
                }
            }
        }
    }
}
