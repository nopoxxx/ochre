import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy
import "services/settings.js" as S

Scope {
    id: root

    property bool open: false

    onOpenChanged: if (!open) Settings.back()

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { root.open = !root.open; }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-cheatsheet"

            readonly property int comboChars: 18
            readonly property int labelChars: 30
            readonly property real colW: cell.advanceWidth * (comboChars + labelChars)
            readonly property real gap: cell.advanceWidth * 3
            readonly property int cols: Math.max(1, Math.min(3, Math.floor((width * 0.9 - Theme.pad * 2 + gap) / (colW + gap))))
            readonly property real lineH: cell.height * 1.3

            readonly property var shown: Binds.all.filter(b => !b.off && !b.hidden)

            readonly property var groups: {
                const q = search.text.trim();
                const list = q ? shown.filter(b => Fuzzy.match(q, b.combo + " " + (b.title || "") + " " + b.action)) : shown;
                const out = [];
                for (const r of S.groupBinds(list)) {
                    if (r.header) out.push({ name: r.header, binds: [] });
                    else out[out.length - 1].binds.push(r.b);
                }
                return out;
            }

            readonly property var columns: {
                const out = [];
                for (let i = 0; i < cols; i++) out.push({ h: 0, groups: [] });
                for (const g of groups) {
                    const c = out.reduce((m, x) => x.h < m.h ? x : m, out[0]);
                    c.groups.push(g);
                    c.h += g.binds.length + 2;
                }
                return out.filter(c => c.groups.length);
            }

            readonly property int found: groups.reduce((n, g) => n + g.binds.length, 0)

            function label(b, group) {
                const t = b.title || "";
                if (t && S.titleGroup(b) === group) return t.slice(t.indexOf(":") + 1).trim();
                return t || b.action.replace(/"/g, "");
            }

            function scroll(d) {
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + d));
            }

            function edit() {
                const back = Settings.returnHere;
                Settings.returnHere = false;
                root.open = false;
                Settings.returnHere = back;
                Ochre.ipc("binds", "toggle");
            }

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: win.cols * win.colW + (win.cols - 1) * win.gap + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T { id: title; text: "[ ~/keys/ ]"; color: Theme.accent; font.bold: true }
                }

                ColumnLayout {
                    id: col

                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T { text: "❯ "; color: Theme.accent; font.bold: true }

                        TextInput {
                            id: search

                            Layout.fillWidth: true
                            focus: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            renderType: Text.NativeRendering

                            Keys.onPressed: event => {
                                const k = event.key, ctrl = event.modifiers & Qt.ControlModifier;
                                if (k === Qt.Key_Escape) root.open = false;
                                else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_J)) win.scroll(win.lineH * 3);
                                else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_K)) win.scroll(-win.lineH * 3);
                                else if (k === Qt.Key_PageDown) win.scroll(flick.height * 0.9);
                                else if (k === Qt.Key_PageUp) win.scroll(-flick.height * 0.9);
                                else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.edit();
                                else return;
                                event.accepted = true;
                            }
                        }

                        T { text: win.found + "/" + win.shown.length; color: Theme.gray }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }

                    Flickable {
                        id: flick

                        Layout.fillWidth: true
                        implicitHeight: Math.min(grid.implicitHeight, win.height * 0.8 - win.lineH * 4)
                        contentHeight: grid.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: grid

                            width: flick.width
                            spacing: win.gap

                            Repeater {
                                model: win.columns

                                ColumnLayout {
                                    id: column

                                    required property var modelData

                                    Layout.preferredWidth: win.colW
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 0

                                    Repeater {
                                        model: column.modelData.groups

                                        ColumnLayout {
                                            id: group

                                            required property var modelData
                                            required property int index

                                            Layout.fillWidth: true
                                            Layout.topMargin: index ? win.lineH * 0.5 : 0
                                            spacing: 0

                                            T {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: win.lineH
                                                verticalAlignment: Text.AlignVCenter
                                                clip: true
                                                text: "── " + I18n.tr(group.modelData.name) + " " + "─".repeat(win.comboChars + win.labelChars)
                                                color: Theme.gray
                                            }

                                            Repeater {
                                                model: group.modelData.binds

                                                RowLayout {
                                                    id: line

                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: win.lineH
                                                    spacing: 0

                                                    T {
                                                        Layout.preferredWidth: cell.advanceWidth * win.comboChars
                                                        elide: Text.ElideRight
                                                        text: line.modelData.combo
                                                        color: Theme.accent
                                                        font.bold: true
                                                    }
                                                    T {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        elide: Text.ElideRight
                                                        text: win.label(line.modelData, group.modelData.name)
                                                        color: Theme.fgDim
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    T {
                        Layout.fillWidth: true
                        visible: win.found === 0
                        text: I18n.tr("ничего не найдено")
                        color: Theme.gray
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }

                    T {
                        Layout.alignment: Qt.AlignRight
                        textFormat: Text.StyledText
                        color: Theme.gray
                        text: [["↑↓", I18n.tr("листать")], ["↵", I18n.tr("изменить в окне биндов")], ["esc", I18n.tr("выход")]]
                            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                    }
                }
            }
        }
    }
}
