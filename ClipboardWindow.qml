import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy

// История буфера обмена (cliphist): слева список с нечётким поиском, справа — запись целиком
// (текст или картинка). ↵ — положить в буфер, Del — удалить запись, ⇧Del — очистить историю.
//   qs ipc call clipboard toggle   (Mod+Shift+V)
Scope {
    id: root

    property bool open: false
    readonly property int rows: Settings.get("shell.launcher.rows")

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open = !root.open; }
    }

    onOpenChanged: if (open) Clipboard.refresh()

    readonly property string imageIcon: String.fromCodePoint(0xF02E9)   // md-image

    function label(e) {
        return e.image ? I18n.tr("изображение %1", e.image.kind + " " + e.image.dims + " · " + e.image.size) : e.text;
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
            WlrLayershell.namespace: "ochre-clipboard"

            property bool confirmWipe: false

            readonly property var results: {
                const q = input.text.trim();
                const all = Clipboard.entries;
                if (!q) return all.map(e => ({ e, pos: [] }));
                const out = [];
                for (const e of all) {
                    const m = Fuzzy.match(q, root.label(e));
                    if (m) out.push({ e, pos: e.image ? [] : m.pos, score: m.score });
                }
                // при равном счёте — более свежая запись выше (sort стабилен)
                return out.sort((a, b) => b.score - a.score);
            }
            readonly property var current: results[list.currentIndex]?.e ?? null

            onResultsChanged: list.currentIndex = 0
            onCurrentChanged: previewDelay.restart()

            function pick() {
                if (!current) return;
                Clipboard.copy(current);
                root.open = false;
            }

            function removeCurrent() {
                if (!current) return;
                const i = list.currentIndex;
                Clipboard.remove(current);
                list.currentIndex = Math.min(i, results.length - 1);
            }

            // ── предпросмотр: запись целиком, с задержкой — чтобы быстрый скролл не плодил процессы ──
            // На каждый запрос свой процесс: прерывать и перезапускать один нельзя — ответ старого пришёл бы
            // уже для новой записи. Ответ не для текущей записи отбрасывается. Картинка декодируется каждый раз
            // заново: id в cliphist после очистки истории начинаются сначала, старый файл показал бы чужое.

            property string previewText: ""
            property string previewImage: ""

            Timer {
                id: previewDelay
                interval: 60
                onTriggered: {
                    const e = win.current;
                    win.previewText = "";
                    win.previewImage = "";
                    if (!e) return;
                    const image = Clipboard.previewPath(e);
                    previewProc.createObject(win, {
                        entry: e,
                        image,
                        command: image
                            ? ["sh", "-c", 'mkdir -p "$3" && printf "%s" "$1" | cliphist decode > "$2"', "sh", e.line, image, Clipboard.cacheDir]
                            : ["sh", "-c", 'printf "%s" "$1" | cliphist decode | head -c 8000', "sh", e.line],
                        running: true
                    });
                }
            }

            Component {
                id: previewProc

                Process {
                    id: proc

                    property var entry
                    property string image
                    property int done: 0      // поток и процесс закончились — объект больше не нужен
                    readonly property bool fresh: !!entry && win.current?.id === entry.id

                    function finish() { if (++done === 2) proc.destroy(); }

                    stdout: StdioCollector {
                        onStreamFinished: {
                            if (!proc.image && proc.fresh) win.previewText = this.text;
                            proc.finish();
                        }
                    }
                    onExited: code => {
                        if (proc.image && code === 0 && proc.fresh) win.previewImage = proc.image;
                        proc.finish();
                    }
                }
            }

            property point lastMouse
            property bool lastMouseSet: false

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
                width: cell.advanceWidth * 100 + Theme.pad * 2
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
                    T { id: title; text: "[ ~/clipboard/ ]"; color: Theme.accent; font.bold: true }
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
                            id: input

                            Layout.fillWidth: true
                            focus: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            selectionColor: Theme.bg2
                            renderType: Text.NativeRendering

                            cursorDelegate: Rectangle {
                                id: caret
                                width: cell.advanceWidth
                                color: Theme.fg
                                Timer {
                                    interval: 530
                                    running: true
                                    repeat: true
                                    onTriggered: caret.opacity = caret.opacity > 0 ? 0 : 1
                                }
                            }

                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier;
                                const shift = event.modifiers & Qt.ShiftModifier;
                                if (win.confirmWipe) {
                                    // одиночный Shift/Ctrl… не ответ; y — по скан-коду: в ru-раскладке event.key у неё «Н»
                                    if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R].includes(event.key)) return;
                                    if (event.key === Qt.Key_Y || event.nativeScanCode === 29) Clipboard.wipe();
                                    win.confirmWipe = false;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.open = false;
                                } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                    list.incrementCurrentIndex();
                                } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                    list.decrementCurrentIndex();
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    win.pick();
                                } else if (event.key === Qt.Key_Delete && shift) {
                                    if (Clipboard.entries.length) win.confirmWipe = true;
                                } else if (event.key === Qt.Key_Delete || (ctrl && event.key === Qt.Key_D)) {
                                    win.removeCurrent();
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        T {
                            text: win.results.length + "/" + Clipboard.entries.length
                            color: Theme.gray
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            Layout.preferredWidth: cell.advanceWidth * 52
                            implicitHeight: cell.height * 1.25 * root.rows

                            ListView {
                                id: list

                                anchors.fill: parent
                                clip: true
                                model: win.results
                                highlightMoveDuration: 0
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Rectangle {
                                    id: row

                                    required property var modelData
                                    required property int index
                                    readonly property var e: modelData.e
                                    readonly property bool current: ListView.isCurrentItem

                                    width: list.width
                                    height: cell.height * 1.25
                                    color: current ? Theme.bg1 : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        T { text: row.current ? "▌ " : "  "; color: Theme.accent }
                                        T {
                                            visible: !!row.e.image
                                            text: root.imageIcon + " "
                                            color: Theme.purple
                                        }
                                        T {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            textFormat: Text.StyledText
                                            text: Fuzzy.highlight(root.label(row.e), row.modelData.pos, Theme.orange)
                                            color: row.e.image ? Theme.purple : row.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                            font.bold: row.current
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        // выделять только при реальном сдвиге мыши (hover приходит и при прокрутке)
                                        onPositionChanged: mouse => {
                                            const p = mapToGlobal(mouse.x, mouse.y);
                                            if (win.lastMouseSet && (p.x !== win.lastMouse.x || p.y !== win.lastMouse.y))
                                                list.currentIndex = row.index;
                                            win.lastMouse = p;
                                            win.lastMouseSet = true;
                                        }
                                        onClicked: { list.currentIndex = row.index; win.pick(); }
                                    }
                                }
                            }

                            T {
                                anchors.centerIn: parent
                                width: parent.width - Theme.pad * 2
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                visible: !win.results.length
                                color: Theme.gray
                                text: !Clipboard.checked ? ""
                                    : !Clipboard.available ? I18n.tr("cliphist не установлен:\nsudo pacman -S cliphist")
                                    : Clipboard.loading && !Clipboard.entries.length ? I18n.tr("загрузка…")
                                    : Clipboard.entries.length ? I18n.tr("ничего не найдено")
                                    : I18n.tr("история пуста — скопируйте что-нибудь")
                            }
                        }

                        // разделитель между списком и предпросмотром
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.leftMargin: cell.advanceWidth
                            Layout.rightMargin: cell.advanceWidth
                            implicitWidth: 1
                            color: Theme.bg2
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            T {
                                anchors.fill: parent
                                visible: !win.current?.image
                                text: win.previewText
                                textFormat: Text.PlainText
                                wrapMode: Text.WrapAnywhere
                                color: Theme.fg
                            }

                            Image {
                                anchors.fill: parent
                                visible: !!win.current?.image
                                source: win.previewImage ? "file://" + win.previewImage : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                sourceSize.width: width
                                sourceSize.height: height
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    T {
                        Layout.fillWidth: true
                        textFormat: Text.StyledText
                        color: win.confirmWipe ? Theme.red : Theme.gray
                        text: win.confirmWipe
                            ? I18n.tr("очистить всю историю буфера? %1 — да, любая клавиша — нет", `<font color="${Theme.accent}">y</font>`)
                            : [["↵", I18n.tr("в буфер")], ["del", I18n.tr("удалить")], ["⇧del", I18n.tr("очистить всё")], ["esc", I18n.tr("закрыть")]]
                                .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                    }
                }
            }
        }
    }
}
