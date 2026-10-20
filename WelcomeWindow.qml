import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services

// Первый запуск: «ochre --help» — главные клавиши и подсказки, строки печатаются по одной.
// Показывается один раз (~/.local/state/ochre/welcome); снова — меню → help или IPC.
// ↵ / Esc / q — закрыть, d — документация в браузере.
//   qs ipc call welcome open | close
Scope {
    id: root

    property bool open: false
    readonly property string mark: Quickshell.env("HOME") + "/.local/state/ochre/welcome"
    readonly property string docs: "https://nopoxxx.github.io/ochre/"

    readonly property var keys: [
        ["Mod+D", I18n.tr("меню: программы, обои, таймер, пакеты, питание")],
        ["Mod+Space", I18n.tr("программы")],
        ["Mod+Return", I18n.tr("терминал")],
        ["Mod+A", I18n.tr("меню home: звук, медиа, todo (или клик по user@host)")],
        ["Mod+S", I18n.tr("настройки")],
        ["Mod+Shift+S", I18n.tr("скриншот с разметкой")],
        ["Mod+Shift+T", I18n.tr("текст с экрана в буфер")],
        ["Mod+Shift+C", I18n.tr("пипетка")],
        ["Mod+Shift+V", I18n.tr("история буфера обмена")],
        ["Mod+Alt+R", I18n.tr("запись экрана")],
        ["Mod+Shift+G", I18n.tr("игровой режим")],
        ["Super+Alt+L", I18n.tr("блокировка")],
        ["Mod+Shift+/", I18n.tr("все клавиши niri")]
    ]
    readonly property var tips: [
        [I18n.tr("колёсико по панели"), I18n.tr("листать рабочие столы")],
        [I18n.tr("timer 25m чай"), I18n.tr("в меню — таймер на панели")],
        ["=2^10", I18n.tr("в меню — калькулятор")],
        ["~/log/errors", I18n.tr("окно в углу — ошибки shell и niri")]
    ]

    function close() {
        open = false;
        markFile.setText(new Date().toISOString() + "\n");
    }

    // нет отметки — показать (в greeter не показываем)
    FileView {
        id: markFile
        path: root.mark
        printErrors: false
        onLoadFailed: if (!Settings.greeterMode) root.open = true
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/ochre"])

    IpcHandler {
        target: "welcome"
        function open(): void { root.open = true; }
        function close(): void { root.close(); }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#99000000"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-welcome"

            TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

            function c(color, s) { return `<font color="${color}">${s}</font>`; }
            function pad(s, n) { return (s + " ".repeat(n)).slice(0, Math.max(n, s.length)).replace(/ /g, "&nbsp;"); }

            // строки страницы: StyledText; печатаются по одной
            readonly property var lines: [
                c(Theme.accent, "<b>ochre</b>") + I18n.tr(" — тёплая терминальная оболочка для niri"),
                "",
                c(Theme.gray, "USAGE"),
                ...root.keys.map(([k, d]) => "&nbsp;&nbsp;" + c(Theme.blue, pad(k, 14)) + d),
                "",
                c(Theme.gray, "TIPS"),
                ...root.tips.map(([k, d]) => "&nbsp;&nbsp;" + c(Theme.aqua, pad(k, 20)) + d),
                "",
                c(Theme.gray, "SEE ALSO"),
                "&nbsp;&nbsp;" + c(Theme.accent, root.docs) + c(Theme.gray, I18n.tr(" — документация (d)"))
            ]
            property int printed: 0
            Timer {
                running: win.printed < win.lines.length
                interval: 28 / Settings.get("shell.anim.speed")
                repeat: true
                onTriggered: win.printed++
            }

            Item {
                focus: true
                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Escape || k === Qt.Key_Q) root.close();
                    else if (k === Qt.Key_D) Quickshell.execDetached(["xdg-open", root.docs]);
                    else if (k === Qt.Key_Space) win.printed = win.lines.length;   // допечатать сразу
                    else return;
                    event.accepted = true;
                }
            }

            MouseArea { anchors.fill: parent; onClicked: root.close() }

            Rectangle {
                id: box
                anchors.centerIn: parent
                width: cell.advanceWidth * 78 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: col
                    x: Theme.pad
                    y: Theme.pad
                    width: parent.width - Theme.pad * 2
                    spacing: 2

                    T {
                        textFormat: Text.StyledText
                        text: win.c(Theme.accent, "❯ ") + "ochre --help"
                    }

                    Repeater {
                        model: win.lines.length
                        T {
                            required property int index
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            // ещё не напечатанные строки занимают место — окно не прыгает по высоте
                            opacity: index < win.printed ? 1 : 0
                            text: win.lines[index] || " "
                        }
                    }

                    Row {
                        Layout.topMargin: Theme.pad / 2
                        spacing: cell.advanceWidth * 2
                        T {
                            text: I18n.tr("[понятно ↵]")
                            color: ok.containsMouse ? Theme.accent : Theme.fg
                            MouseArea { id: ok; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                        }
                        T {
                            text: I18n.tr("[документация d]")
                            color: dm.containsMouse ? Theme.accent : Theme.fg
                            MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", root.docs]) }
                        }
                        BlinkCursor {}
                    }
                }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: titleT.implicitWidth + cell.advanceWidth
                    height: titleT.implicitHeight
                    color: Theme.bg
                    T { id: titleT; anchors.centerIn: parent; text: "[ ~/welcome/ ]"; color: Theme.accent; font.bold: true }
                }
            }
        }
    }
}
