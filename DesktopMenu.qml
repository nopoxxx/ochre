import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services

Scope {
    id: root

    property var screen
    property bool open: false
    property real atX: 0
    property real atY: 0
    property var stack: []
    property int cur: 0
    property string armed: ""

    function openAt(x, y) {
        atX = x;
        atY = y;
        stack = [];
        cur = 0;
        armed = "";
        open = true;
    }

    function spawn(argv) { Quickshell.execDetached(argv); }

    readonly property var menu: [
        { label: "terminal", desc: I18n.tr("открыть терминал"), run: () => Term.open([]) },
        { label: "apps", desc: I18n.tr("запуск программ (Mod+Space)"), run: () => Ochre.ipc("launcher", "apps") },
        { label: "screenshot", desc: I18n.tr("снимок области"), run: () => Ochre.ipc("shot", "region") },
        { label: "wallpaper", desc: I18n.tr("выбрать обои"), run: () => { Wallpaper.pickerSource = "local"; Wallpaper.pickerOpen = true; } },
        { label: "theme", desc: I18n.tr("светлая или тёмная тема"), ok: Theme.hasLight, value: () => Theme.dark ? "dark" : "light", stay: true, run: () => Theme.toggleMode() },
        { label: "night", desc: I18n.tr("ночной режим"), value: () => NightLight.on ? "on" : "off", stay: true, run: () => NightLight.toggle() },
        { label: "dnd", desc: I18n.tr("не беспокоить"), value: () => Notifs.dnd ? "on" : "off", stay: true, run: () => Notifs.toggleDnd() },
        { label: "home", desc: I18n.tr("меню home (Mod+A)"), run: () => Home.show(root.screen?.name) },
        { label: "settings", desc: I18n.tr("все настройки (Mod+S)"), run: () => Settings.show("") },
        { label: "system", desc: I18n.tr("питание и сессия"), children: [
            { label: "lock", desc: I18n.tr("заблокировать экран (Super+Alt+L)"), run: () => Ochre.ipc("lock", "lock") },
            { label: "suspend", desc: I18n.tr("заблокировать и уснуть"), run: () => root.spawn(["sh", "-c", '"$@"; sleep 0.5; systemctl suspend', "sh", ...Ochre.ipcArgv(["lock", "lock"])]) },
            { label: "logout", desc: I18n.tr("выйти из niri"), confirm: true, run: () => root.spawn(["niri", "msg", "action", "quit", "--skip-confirmation"]) },
            { label: "reboot", desc: I18n.tr("перезагрузка"), confirm: true, run: () => root.spawn(["systemctl", "reboot"]) },
            { label: "poweroff", desc: I18n.tr("выключение"), confirm: true, run: () => root.spawn(["systemctl", "poweroff"]) }
        ] }
    ]

    readonly property var items: (stack.length ? stack[stack.length - 1].children : menu).filter(n => n.ok !== false)
    readonly property int labelWidth: Math.max(...items.map(n => n.label.length + (n.children ? 1 : 0)))

    onCurChanged: armed = ""

    function activate(n) {
        if (!n) return;
        if (n.children) {
            stack = stack.concat([n]);
            cur = 0;
        } else if (n.confirm && armed !== n.label) {
            armed = n.label;
        } else if (n.stay) {
            n.run();
        } else {
            open = false;
            n.run();
        }
    }

    function back() {
        if (!stack.length) { open = false; return; }
        const up = stack[stack.length - 1];
        stack = stack.slice(0, -1);
        cur = Math.max(0, items.indexOf(up));
    }

    function key(event) {
        const n = items.length;
        const k = event.key;
        if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) cur = (cur + 1) % n;
        else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) cur = (cur - 1 + n) % n;
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Right || k === Qt.Key_L) activate(items[cur]);
        else if (k === Qt.Key_Escape || k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backspace || k === Qt.Key_Q) back();
        else return;
        event.accepted = true;
    }

    PanelWindow {
        screen: root.screen
        visible: Settings.get("shell.desktop.menu")
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ochre-desktop"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => root.openAt(mouse.x, mouse.y)
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-desktop-menu"

            TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) root.openAt(mouse.x, mouse.y);
                    else root.open = false;
                }
            }

            Rectangle {
                id: box

                x: root.atX + width <= win.width ? root.atX : Math.max(0, root.atX - width)
                y: root.atY + height <= win.height ? Math.max(titleBox.height / 2, root.atY) : Math.max(titleBox.height / 2, root.atY - height)
                width: inner.implicitWidth + Theme.pad * 2
                height: inner.implicitHeight + Theme.pad * 2 + titleBox.height / 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2
                focus: true

                Keys.onPressed: event => root.key(event)

                MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

                ColumnLayout {
                    id: inner

                    x: Theme.pad
                    y: Theme.pad + titleBox.height / 2
                    spacing: 2

                    T {
                        visible: root.stack.length > 0
                        text: "‹ .."
                        color: Theme.blue

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.back()
                        }
                    }

                    Repeater {
                        model: root.items

                        Rectangle {
                            id: line

                            required property var modelData
                            required property int index
                            readonly property var n: modelData
                            readonly property bool active: root.cur === index
                            readonly property bool armed: root.armed === n.label

                            Layout.fillWidth: true
                            implicitWidth: row.implicitWidth
                            implicitHeight: row.implicitHeight
                            color: active ? Theme.bg1 : "transparent"

                            RowLayout {
                                id: row

                                spacing: 0

                                T {
                                    text: line.active ? "▌ " : "  "
                                    color: Theme.accent
                                }
                                T {
                                    Layout.preferredWidth: cell.advanceWidth * (root.labelWidth + 2)
                                    text: line.n.label + (line.n.children ? "/" : "")
                                    color: line.n.children ? Theme.blue : line.active ? Theme.fg : Theme.fgDim
                                    font.bold: line.active
                                }
                                T {
                                    text: line.armed ? I18n.tr("точно? ↵") : line.n.desc
                                    color: line.armed ? Theme.red : Theme.gray
                                }
                                T {
                                    visible: !line.armed && !!line.n.value
                                    text: "  [" + (line.n.value ? line.n.value() : "") + "]"
                                    color: Theme.accent
                                }
                            }

                            HoverHandler {
                                onHoveredChanged: if (hovered) root.cur = line.index
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activate(line.n)
                            }
                        }
                    }
                }

                Rectangle {
                    id: titleBox

                    x: Theme.pad
                    y: -height / 2
                    width: titleText.implicitWidth
                    height: titleText.implicitHeight
                    color: Theme.bg

                    T {
                        id: titleText
                        text: "[ ~/desktop/" + root.stack.map(n => n.label + "/").join("") + " ]"
                        color: Theme.accent
                        font.bold: true
                    }
                }
            }
        }
    }
}
