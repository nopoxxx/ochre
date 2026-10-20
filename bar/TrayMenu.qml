import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services

// Меню приложения из трея (DBusMenu) в TUI-рамке вместо нативного QMenu.
// Подменю открываются на месте, как каталоги: ‹ .. — назад.
TuiPopup {
    id: pop

    property var trayItem: null
    property string name: ""
    property var stack: []
    readonly property var entries: opener.children?.values ?? []

    title: name + (stack.length > 1 ? "/" + stack.slice(1).map(e => clean(e.text)).join("/") : "")

    // в DBusMenu «_» отмечает горячую клавишу, «__» — настоящее подчёркивание
    function clean(s) {
        return (s ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    function openFor(owner, item, shortName) {
        pop.owner = owner;
        trayItem = item;
        name = shortName;
        stack = [item.menu];
        show();
    }

    function activate(entry) {
        if (!entry.enabled || entry.isSeparator) return;
        if (entry.hasChildren) {
            stack = stack.concat([entry]);
        } else {
            entry.triggered();
            open = false;
        }
    }

    QsMenuOpener {
        id: opener
        menu: pop.stack[pop.stack.length - 1] ?? null
    }

    // назад из подменю
    T {
        visible: pop.stack.length > 1
        text: "‹ .."
        color: Theme.blue

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pop.stack = pop.stack.slice(0, -1)
        }
    }

    Repeater {
        model: pop.entries

        Rectangle {
            id: line

            required property var modelData
            readonly property var e: modelData
            readonly property bool active: hover.hovered && e.enabled && !e.isSeparator

            Layout.fillWidth: true
            Layout.minimumWidth: label.implicitWidth + 4
            implicitHeight: label.implicitHeight
            color: active ? Theme.bg1 : "transparent"

            T {
                id: label

                text: {
                    const e = line.e;
                    if (e.isSeparator) return " ";
                    const checked = e.checkState === Qt.Checked;
                    const box = e.buttonType === QsMenuButtonType.CheckBox ? (checked ? "[x] " : "[ ] ")
                        : e.buttonType === QsMenuButtonType.RadioButton ? (checked ? "(•) " : "( ) ")
                        : "";
                    return (line.active ? "▌ " : "  ") + box + pop.clean(e.text) + (e.hasChildren ? "  ›" : "");
                }
                color: line.e.isSeparator ? Theme.bg2
                    : !line.e.enabled ? Theme.gray
                    : line.e.hasChildren ? Theme.blue
                    : line.active ? Theme.fg : Theme.fgDim
                font.bold: line.active
            }

            // разделитель — линия во всю ширину меню
            Rectangle {
                visible: line.e.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Theme.bg2
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                cursorShape: line.e.enabled && !line.e.isSeparator ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: pop.activate(line.e)
            }
        }
    }

    T {
        visible: pop.entries.length === 0
        text: I18n.tr("  загрузка…")
        color: Theme.gray
    }
}
