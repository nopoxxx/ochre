import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services

// Что показать в демонстрации экрана (Discord, браузер, OBS): запрос приходит от бэкенда портала (services/Cast.qml).
//   ┌[ ~/cast/ ]────────────────────────────────┐
//   │ vesktop хочет показать экран                │
//   │ ── мониторы ──────                          │
//   │ ▌ DP-1        3440×1440  фокус              │
//   │ ── окна ──────                              │
//   │   kitty       ~/claude                      │
// ↑↓ / j k — выбор, ↵ / двойной клик — показать, Esc — отказать.
// Превью нет намеренно: ScreencopyView чужого монитора и ToplevelManager в этом окне роняли Quickshell 0.3.2 (SIGSEGV в
// QPlatformScreen::screen() из обработчика Wayland) — см. AGENTS.md §9. Список фиксируется при открытии.
Scope {
    id: root

    readonly property var req: Cast.request
    property var held: null           // запрос, который показывает окно (после ответа — до уничтожения)
    property bool open: false

    onReqChanged: {
        if (req) { held = req; open = true; linger.stop(); }
        else if (open) { open = false; linger.restart(); }
    }
    Timer { id: linger; interval: 1000 }

    LazyLoader {
        active: root.open || linger.running

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#99000000"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-cast"
            visible: root.open

            TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

            // приложение портал обычно не называет (не flatpak) — тогда то, по которому только что кликнули
            property string app: ""
            property int types: 1
            // строки — снимок на момент открытия: заголовки групп и пункты {kind, key, label, info}
            property var rows: []
            property int cur: -1
            readonly property var sel: rows[cur] ?? null

            Component.onCompleted: snapshot()
            // новый запрос, пока прошлое окно ещё не уничтожено (linger), — список заново
            Connections { target: root; function onHeldChanged() { win.snapshot(); } }

            function snapshot() {
                const r = root.held ?? {};
                // приложение портал обычно не называет (не flatpak) — тогда то, по которому только что кликнули
                app = r.app || Niri.focusedWindow?.app_id || I18n.tr("приложение");
                types = r.types || 1;
                const outs = (types & 1) ? Quickshell.screens.map(s => ({
                    kind: "monitor", key: "m:" + s.name, name: s.name, label: s.name,
                    info: Math.round(s.width * s.devicePixelRatio) + "×" + Math.round(s.height * s.devicePixelRatio)
                        + (s.name === Niri.focusedWorkspace?.output ? I18n.tr("  фокус") : "")
                })) : [];
                const wins = (types & 2) ? Object.values(Niri.windows)
                    .sort((a, b) => (b.is_focused - a.is_focused) || a.id - b.id)
                    .map(w => ({ kind: "window", key: "w:" + w.id, id: w.id, label: w.app_id || "?", info: w.title || "" })) : [];
                rows = (outs.length ? [{ header: I18n.tr("мониторы") }].concat(outs) : [])
                    .concat(wins.length ? [{ header: I18n.tr("окна") }].concat(wins) : []);
                cur = rows.findIndex(x => !x.header);
            }

            function step(d) {
                let i = cur + d;
                while (rows[i]?.header) i += d;
                if (i >= 0 && i < rows.length) cur = i;
            }
            function choose() {
                if (!sel || !root.open) return;
                Cast.answer(sel.kind === "monitor" ? { type: "monitor", name: sel.name } : { type: "window", id: sel.id });
            }

            Item {
                focus: true
                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) win.step(1);
                    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) win.step(-1);
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.choose();
                    else if (k === Qt.Key_Escape || k === Qt.Key_Q) { if (root.open) Cast.answer(null); }
                    else return;
                    event.accepted = true;
                }
            }

            MouseArea { anchors.fill: parent; onClicked: if (root.open) Cast.answer(null) }

            Rectangle {
                id: box
                anchors.centerIn: parent
                width: cell.advanceWidth * 72 + Theme.pad * 2
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
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: I18n.tr(win.types === 2 ? "%1 хочет показать окно" : win.types === 1 ? "%1 хочет показать экран" : "%1 хочет показать экран или окно",
                            `<font color="${Theme.accent}"><b>${win.app.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</b></font>`)
                    }

                    Repeater {
                        model: win.rows
                        Rectangle {
                            id: line
                            required property var modelData
                            required property int index
                            readonly property bool current: index === win.cur
                            Layout.fillWidth: true
                            implicitHeight: rowText.implicitHeight
                            color: current ? Theme.bg1 : "transparent"

                            T {
                                id: rowText
                                width: parent.width
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                text: line.modelData.header
                                    ? `<font color="${Theme.gray}">── ${line.modelData.header} ${"─".repeat(60)}</font>`
                                    : `<font color="${Theme.accent}">${line.current ? "▌" : "&nbsp;"}</font>&nbsp;`
                                      + `<font color="${line.modelData.kind === "monitor" ? Theme.blue : Theme.aqua}">${(line.modelData.label + " ".repeat(14)).slice(0, Math.max(14, line.modelData.label.length + 1)).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/ /g, "&nbsp;")}</font>`
                                      + `<font color="${line.current ? Theme.fg : Theme.gray}">${line.modelData.info.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</font>`
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !line.modelData.header
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.cur = line.index
                                onDoubleClicked: { win.cur = line.index; win.choose(); }
                            }
                        }
                    }

                    T {
                        Layout.topMargin: Theme.pad / 2
                        textFormat: Text.StyledText
                        color: Theme.gray
                        text: [["↵", I18n.tr("показать")], ["↑↓", I18n.tr("выбор")], ["esc", I18n.tr("отказать")]]
                            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                    }
                }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: titleT.implicitWidth + cell.advanceWidth
                    height: titleT.implicitHeight
                    color: Theme.bg
                    T { id: titleT; anchors.centerIn: parent; text: "[ ~/cast/ ]"; color: Theme.accent; font.bold: true }
                }
            }
        }
    }
}
