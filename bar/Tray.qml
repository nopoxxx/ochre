import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.bar
import qs.services
import "../services/settings.js" as S

// [‹ 󰙯 󰓓] — трей значками Nerd Font (S.TRAY_ICONS; неизвестные — первой буквой) или [‹ discord steam]
// названиями (shell.bar.trayStyle). Клик — открыть, правый клик — меню.
// ‹ сворачивает трей в [+2]; приложения, которые просят внимания, видны и в свёрнутом.
// Метки печатаются при разворачивании и стираются при сворачивании — как команда в Command.qml.
Item {
    id: root

    property var bar
    readonly property var items: SystemTray.items.values
    readonly property bool collapsed: Settings.get("shell.bar.trayCollapsed")
    property bool available: items.length > 0

    // сворачиваются только обычные значки; просящие внимания видны всегда
    readonly property var plain: items.filter(it => it.status !== Status.NeedsAttention)
    readonly property int hidden: collapsed ? plain.length : 0

    readonly property bool icons: Settings.get("shell.bar.trayStyle") === "icons"
    readonly property bool vertical: bar?.vertical ?? false

    function shortName(it) {
        return (it.title || it.id || "?").toLowerCase().split(/[\s._-]+/)[0].slice(0, 12);
    }

    // значок Nerd Font или "" (режим names или программа не из S.TRAY_ICONS)
    function glyph(it) {
        if (!icons) return "";
        // из иконки — только имя из темы: в URL pixmap-иконок путь DBus (/org/chromium/… у любого Electron)
        const icon = String(it.icon ?? "");
        const iconName = icon.startsWith("image://icon/") ? icon.slice(13).split("?")[0] : "";
        return S.trayGlyph(it.id, it.title, iconName);
    }

    // что видно на панели: значок, первая буква или короткое название
    function label(it) {
        return icons ? glyph(it) || shortName(it)[0] : shortName(it);
    }

    // длина в символах: глифы Nerd Font вне BMP — два UTF-16 знака, а печатаются одним
    function len(s) { return Array.from(s).length; }

    // ── анимация набора: typed — сколько символов обычных значков сейчас видно ──
    readonly property int totalLen: plain.reduce((n, it) => n + 1 + len(label(it)), 0)
    readonly property int target: collapsed ? 0 : totalLen
    property int typed: 0
    readonly property bool typing: typed !== target

    function offsetOf(it) {
        let n = 0;
        for (const p of plain) {
            if (p === it) return n;
            n += 1 + len(label(p));
        }
        return 0;
    }

    onTargetChanged: {
        if (Settings.get("shell.bar.trayTyping")) typer.start();
        else typed = target;
    }

    Component.onCompleted: typed = target

    Timer {
        id: typer
        interval: 14
        repeat: true
        onTriggered: {
            root.typed += root.typed < root.target ? 1 : -1;
            if (!root.typing) stop();
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Grid {
        id: row
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter

        // переключатель «[‹» / «[+N»: ‹ — свернуть, +N — развернуть.
        // Кликабельна и скобка, и немного вокруг — один символ слишком мелкая цель.
        BarText {
            textFormat: Text.StyledText
            text: (root.vertical ? "" : `<font color="${Theme.gray}">[</font>`)
                + `<font color="${root.collapsed ? Theme.accent : Theme.gray}">${root.collapsed ? "+" + root.hidden : "‹"}</font>`

            MouseArea {
                anchors { fill: parent; margins: -6 }
                cursorShape: Qt.PointingHandCursor
                onClicked: Settings.set("shell.bar.trayCollapsed", !root.collapsed)
            }
        }

        Repeater {
            model: root.items

            BarText {
                id: item

                required property var modelData
                readonly property bool attention: modelData.status === Status.NeedsAttention
                readonly property bool isGlyph: root.glyph(modelData) !== ""
                readonly property var full: root.vertical ? Array.from(root.label(modelData)).slice(0, 6) : Array.from(" " + root.label(modelData))
                readonly property int start: attention ? 0 : root.offsetOf(modelData)

                visible: text.length > 0
                text: (attention || root.vertical && !root.collapsed ? full : root.vertical ? [] : full.slice(0, Math.max(0, Math.min(full.length, root.typed - start)))).join("")
                color: attention ? Theme.accent : Theme.fg
                // в Mono глифы ужаты в одну клетку и почти не читаются — значки берём из обычного варианта
                font.family: isGlyph ? "Terminess Nerd Font" : Theme.font
                // глиф шире своей клетки и налезает на соседа
                rightPadding: isGlyph ? Math.round(Theme.fontSize * 0.2) : 0

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const it = item.modelData;
                        if (mouse.button === Qt.RightButton || it.onlyMenu) {
                            if (it.hasMenu) menu.openFor(item, it, root.shortName(it));
                        } else {
                            it.activate();
                        }
                    }
                }
            }
        }

        // курсор, пока названия печатаются или стираются
        BarText { visible: root.typing && !root.vertical; text: "█"; color: Theme.fg }

        BarText { visible: !root.vertical; text: "]"; color: Theme.gray }
    }

    // своё меню вместо it.display(): нативному QMenu нужен режим QApplication, и он не в стиле shell
    TrayMenu { id: menu; bar: root.bar; owner: root }
}
