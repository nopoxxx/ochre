import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/settings.js" as S

// Виджеты на рабочем столе (services/Desktop.qml). На каждом мониторе — нижний слой layer-shell над обоями и под окнами
// (ochre-desktop): клики ловят только сами виджеты (mask), мимо них — стол. Режим правки — окно поверх всего на мониторе
// с фокусом (ochre-desktop-edit), нижний слой этого монитора на это время не строится.
//   Mod+Shift+D, qs ipc call desktop edit; Mod+S → look/ → виджеты на столе
// Клавиши правки: a — добавить, Tab — следующий, ←→↑↓ / hjkl — сдвинуть, ⇧ — размер, ↵ — писать (стикер, картинка),
// f — рамка, b — фон, m — на другой монитор, Del — убрать, Esc — готово.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: layer

            required property var modelData
            readonly property bool shown: Desktop.shownOn(modelData.name) && S.widgetsOn(Desktop.widgets, modelData.name, Quickshell.screens.map(s => s.name)).length > 0

            screen: modelData
            visible: shown
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "ochre-desktop"
            mask: Region { regions: canvas.item?.regions ?? [] }

            Loader {
                id: canvas
                anchors.fill: parent
                active: layer.shown
                sourceComponent: DesktopCanvas { output: layer.modelData.name }
            }
        }
    }

    LazyLoader {
        active: Desktop.editing

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Desktop.screenName) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.35)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-desktop-edit"

            readonly property string output: screen?.name ?? ""
            property bool adding: false
            property int pick: 0

            readonly property var cur: Desktop.widgets.find(w => w.id === edit.selected) ?? null

            function next(d) {
                const l = edit.list;
                if (!l.length) return;
                const i = l.findIndex(w => w.id === edit.selected);
                edit.selected = l[(i + d + l.length) % l.length].id;
            }

            function add(type) {
                const w = S.newWidget(type, output, edit.cw / width, edit.ch / height, Date.now());
                Desktop.add(w);
                edit.selected = w.id;
                adding = false;
            }

            function remove() {
                if (!cur) return;
                const id = cur.id;
                next(1);
                if (edit.selected === id) edit.selected = "";
                Desktop.remove(id);
            }

            // на следующий монитор — с теми же долями экрана
            function toScreen() {
                const names = Quickshell.screens.map(s => s.name);
                if (!cur || names.length < 2) return;
                Desktop.update(cur.id, { screen: names[(names.indexOf(output) + 1) % names.length] });
                edit.selected = "";
            }

            function key(event) {
                const k = event.key, shift = event.modifiers & Qt.ShiftModifier;
                if (edit.writing) {
                    if (k === Qt.Key_Escape || (cur?.type === "image" && (k === Qt.Key_Return || k === Qt.Key_Enter))) edit.writing = false;
                    else return;
                } else if (adding) {
                    if (k === Qt.Key_Escape || k === Qt.Key_A) adding = false;
                    else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) pick = (pick + 1) % S.WIDGETS.length;
                    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) pick = (pick + S.WIDGETS.length - 1) % S.WIDGETS.length;
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) add(S.WIDGETS[pick].id);
                    else return;
                } else if (k === Qt.Key_Escape || k === Qt.Key_Q) Desktop.editing = false;
                else if (k === Qt.Key_A || k === Qt.Key_Insert) { pick = 0; adding = true; }
                else if (k === Qt.Key_Tab) next(1);
                else if (k === Qt.Key_Backtab) next(-1);
                else if (k === Qt.Key_Left || k === Qt.Key_H) shift ? edit.resize(-1, 0) : edit.move(-1, 0);
                else if (k === Qt.Key_Right || k === Qt.Key_L) shift ? edit.resize(1, 0) : edit.move(1, 0);
                else if (k === Qt.Key_Up || k === Qt.Key_K) shift ? edit.resize(0, -1) : edit.move(0, -1);
                else if (k === Qt.Key_Down || k === Qt.Key_J) shift ? edit.resize(0, 1) : edit.move(0, 1);
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) edit.write();
                else if (k === Qt.Key_Delete || k === Qt.Key_X) remove();
                else if (k === Qt.Key_F && cur) Desktop.update(cur.id, { frame: !cur.frame });
                else if (k === Qt.Key_B && cur) Desktop.update(cur.id, { bg: S.WIDGET_BGS[(S.WIDGET_BGS.indexOf(cur.bg) + 1) % S.WIDGET_BGS.length] });
                else if (k === Qt.Key_M) toScreen();
                else return;
                event.accepted = true;
            }

            TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

            // клик мимо виджетов снимает выбор
            MouseArea {
                anchors.fill: parent
                onClicked: { edit.selected = ""; win.adding = false; }
            }

            // клавиши — здесь: из полей стикера и картинки сюда всплывают Esc и ↵
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => win.key(event)

                DesktopCanvas {
                    id: edit
                    anchors.fill: parent
                    output: win.output
                    editing: true
                    onWritingChanged: if (!writing) parent.forceActiveFocus()
                }
            }

            // ── подсказки внизу ──
            Rectangle {
                id: box

                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: cell.height * 3 }
                width: hints.implicitWidth + Theme.pad * 2
                height: hints.implicitHeight + Theme.pad * 2
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
                    T { id: title; text: "[ ~/desktop/ ]"; color: Theme.accent; font.bold: true }
                }

                T {
                    id: hints
                    anchors.centerIn: parent
                    textFormat: Text.StyledText
                    color: Theme.gray
                    text: (edit.writing
                        ? [["esc", I18n.tr("готово")]].concat(win.cur?.type === "image" ? [["↵", I18n.tr("готово")]] : [])
                        : [["a", I18n.tr("добавить")], ["tab", I18n.tr("выбрать")], ["←→↑↓", I18n.tr("сдвинуть")], ["⇧", I18n.tr("размер")]]
                            .concat(win.cur?.type === "sticker" || win.cur?.type === "image" ? [["↵", I18n.tr("писать")]] : [])
                            .concat(win.cur ? [["f", I18n.tr("рамка")], ["b", I18n.tr("фон")]] : [])
                            .concat(win.cur && Quickshell.screens.length > 1 ? [["m", I18n.tr("на другой монитор")]] : [])
                            .concat(win.cur ? [["del", I18n.tr("убрать")]] : [])
                            .concat([["esc", I18n.tr("готово")]]))
                        .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                }
            }

            T {
                anchors.centerIn: parent
                visible: !edit.list.length && !win.adding
                text: I18n.tr("на столе пусто — a, чтобы добавить виджет")
                color: Theme.fgDim
            }

            // ── что добавить ──
            Rectangle {
                id: menu

                visible: win.adding
                anchors.centerIn: parent
                width: cell.advanceWidth * 64 + Theme.pad * 2
                height: menuCol.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: menuTitle.implicitWidth
                    height: menuTitle.implicitHeight
                    color: Theme.bg
                    T { id: menuTitle; text: "[ ~/desktop/add/ ]"; color: Theme.accent; font.bold: true }
                }

                ColumnLayout {
                    id: menuCol
                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 0

                    Repeater {
                        model: S.WIDGETS

                        Rectangle {
                            id: opt

                            required property var modelData
                            required property int index
                            readonly property bool on: win.pick === index

                            Layout.fillWidth: true
                            implicitHeight: line.implicitHeight + 4
                            color: on ? Theme.bg1 : "transparent"

                            RowLayout {
                                id: line
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 0
                                T { text: opt.on ? "▌ " : "  "; color: Theme.accent }
                                T {
                                    Layout.preferredWidth: cell.advanceWidth * 16
                                    text: I18n.tr(opt.modelData.label)
                                    color: opt.on ? Theme.fg : Theme.fgDim
                                    font.bold: opt.on
                                }
                                T {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: I18n.tr(opt.modelData.desc)
                                    color: Theme.gray
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: win.pick = opt.index
                                onClicked: win.add(opt.modelData.id)
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 1; color: Theme.bg2 }

                    T {
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 6
                        textFormat: Text.StyledText
                        color: Theme.gray
                        text: [["↑↓", I18n.tr("выбрать")], ["↵", I18n.tr("добавить")], ["esc", I18n.tr("назад")]]
                            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                    }
                }
            }
        }
    }
}
