import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy

// Выбор обоев: локальная коллекция (картинки, gif, видео, шейдеры .frag) и wallhaven.cc.
// Enter применяет и оставляет окно открытым — удобно перебирать.
//   qs ipc call wallpaper picker      — открыть/закрыть
//   qs ipc call wallpaper set <path>  — поставить файл на все экраны
//   qs ipc call wallpaper assign <path> <all|output|ws> <day|night> — в сфокусированный экран или стол; "" — сбросить
//   qs ipc call wallpaper next        — следующая картинка слайдшоу
Scope {
    id: root

    Connections {
        target: Wallpaper
        function onPickerOpenChanged() { if (!Wallpaper.pickerOpen) Settings.back(); }
    }

    IpcHandler {
        target: "wallpaper"
        function picker(): void { Wallpaper.pickerOpen = !Wallpaper.pickerOpen; }
        function set(path: string): void { Wallpaper.set(path); }
        function fill(mode: string): void { Wallpaper.setFill(mode); }
        function assign(path: string, level: string, time: string): void { Wallpaper.assign(level, time, path); }
        function next(): void { Wallpaper.next(); }
    }

    LazyLoader {
        active: Wallpaper.pickerOpen

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-wallpicker"

            readonly property int cols: 4
            readonly property int visibleRows: 3
            readonly property int thumbW: 300
            readonly property int thumbH: 169   // 16:9

            readonly property string source: Wallpaper.pickerSource

            readonly property var targets: ["all", "output", "ws"]
            property string target: "all"
            property string time: "day"
            readonly property string assigned: Wallpaper.slotPath(target, time)

            // wallhaven
            property var remote: []
            property int page: 0
            property int lastPage: 1
            property bool loading: false
            property int gen: 0                 // ответы на устаревшие запросы отбрасываются
            property string error: ""
            property string status: ""

            // превью: у видео — постер (пока его нет — имя), у шейдера — он сам (WallLayer в плитке)
            function thumbFor(p) {
                const k = Wallpaper.kindOf(p);
                const f = k === "video" ? Wallpaper.stillOf(p) : k === "shader" ? "" : p;
                return f ? "file://" + encodeURI(f) : "";
            }

            function infoFor(p) {
                return ({ anim: "gif", video: "video", shader: "live" })[Wallpaper.kindOf(p)] ?? "";
            }

            readonly property var items: {
                const q = input.text.trim();
                if (source === "local")
                    // фирменные — первыми, в варианте текущего акцента, за ними живые
                    return Wallpaper.brand
                        .map((p, i) => ({ path: p, thumb: "file://" + encodeURI(p), name: "ochre/" + Wallpaper.brandNames[i], info: "" }))
                        .concat(Wallpaper.brandLive.map((p, i) => ({ path: p, thumb: "", name: "ochre/" + Wallpaper.brandLiveNames[i], info: "live" })))
                        .concat([[Wallpaper.dir, Wallpaper.local[0] ?? ""]].concat(Wallpaper.folders)
                        .map(([p, first]) => ({ path: p, thumb: first ? thumbFor(first) : "",
                            name: "▸" + (p === Wallpaper.dir ? I18n.tr("все") : p.slice(p.lastIndexOf("/") + 1)) + "/", info: "" })))
                        .concat(Wallpaper.local
                        .map(p => ({ path: p, thumb: thumbFor(p), name: p.slice(p.lastIndexOf("/") + 1), info: infoFor(p) })))
                        .filter(it => !q || Fuzzy.match(q, it.name));
                return remote.map(w => ({ w, path: Wallpaper.localPathFor(w), thumb: w.thumbs.small, name: w.id, info: w.resolution }));
            }

            function fetch(reset) {
                if (reset) {
                    remote = [];
                    page = 0;
                    lastPage = 1;
                    loading = false;
                }
                if (loading || page >= lastPage) return;
                loading = true;
                error = "";
                const g = ++gen;
                Wallpaper.search(input.text.trim(), page + 1, res => {
                    if (g !== gen) return;
                    loading = false;
                    if (res.error) { error = res.error; return; }
                    page += 1;
                    lastPage = res.lastPage;
                    remote = remote.concat(res.items);
                });
            }

            function apply(it) {
                if (!it) return;
                if (source === "local") {
                    Wallpaper.assign(target, time, it.path);
                    status = "✓ " + it.name;
                } else {
                    Wallpaper.download(it.w, target, time);
                    status = "↓ " + it.name;
                }
            }

            function cycleTarget() {
                target = targets[(targets.indexOf(target) + 1) % targets.length];
            }

            function targetLabel(t) {
                const ws = Niri.focusedWorkspace;
                return t === "all" ? I18n.tr("все")
                    : t === "output" ? I18n.tr("экран %1", Wallpaper.focusedOutput)
                    : I18n.tr("стол %1", ws ? ws.name || ws.idx : "?");
            }

            function clearTarget() {
                Wallpaper.assign(target, time, "");
                status = "✓ " + I18n.tr("сброшено: %1", targetLabel(target));
            }

            function switchSource() {
                Wallpaper.pickerSource = source === "local" ? "wallhaven" : "local";
            }

            onSourceChanged: {
                input.text = "";
                grid.currentIndex = 0;
                if (source === "wallhaven" && remote.length === 0) fetch(true);
            }

            Component.onCompleted: {
                Wallpaper.refresh();
                if (source === "wallhaven") fetch(true);
            }

            Connections {
                target: Wallpaper
                function onDownloadingChanged() {
                    if (!Wallpaper.downloading && win.status.startsWith("↓")) win.status = "✓" + win.status.slice(1);
                }
            }

            // поиск на wallhaven — после паузы в наборе
            Timer {
                id: debounce
                interval: 500
                onTriggered: win.fetch(true)
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
                onClicked: Wallpaper.pickerOpen = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: grid.cellWidth * win.cols + Theme.pad * 2
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
                    T { id: title; text: "[ ~/wallpaper/" + win.source + "/ ]"; color: Theme.accent; font.bold: true }
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

                            onTextChanged: if (win.source === "wallhaven") debounce.restart()

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
                                if (event.key === Qt.Key_Escape) {
                                    Wallpaper.pickerOpen = false;
                                } else if (ctrl && event.key === Qt.Key_F) {
                                    Wallpaper.cycleFill();
                                } else if (ctrl && event.key === Qt.Key_T) {
                                    win.cycleTarget();
                                } else if (ctrl && event.key === Qt.Key_N) {
                                    win.time = win.time === "day" ? "night" : "day";
                                } else if (ctrl && event.key === Qt.Key_Delete) {
                                    win.clearTarget();
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    win.switchSource();
                                } else if (event.key === Qt.Key_Left || (ctrl && event.key === Qt.Key_H)) {
                                    grid.moveCurrentIndexLeft();
                                } else if (event.key === Qt.Key_Right || (ctrl && event.key === Qt.Key_L)) {
                                    grid.moveCurrentIndexRight();
                                } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) {
                                    grid.moveCurrentIndexUp();
                                } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) {
                                    grid.moveCurrentIndexDown();
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    win.apply(win.items[grid.currentIndex]);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        // вкладки: [local] wallhaven
                        T {
                            textFormat: Text.StyledText
                            text: ["local", "wallhaven"].map(s => s === win.source
                                ? `<font color="${Theme.accent}"><b>[${s}]</b></font>`
                                : `<font color="${Theme.gray}"> ${s} </font>`).join(" ")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T { text: I18n.tr("куда: "); color: Theme.gray }
                        Repeater {
                            model: win.targets
                            T {
                                required property string modelData
                                textFormat: Text.StyledText
                                text: modelData === win.target
                                    ? `<font color="${Theme.accent}"><b>[${win.targetLabel(modelData)}]</b></font>`
                                    : ` ${win.targetLabel(modelData)} `
                                color: Theme.gray
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: win.target = parent.modelData
                                }
                            }
                        }
                        T { text: " · "; color: Theme.gray }
                        Repeater {
                            model: ["day", "night"]
                            T {
                                required property string modelData
                                readonly property string label: modelData === "day" ? I18n.tr("день") : I18n.tr("ночь")
                                textFormat: Text.StyledText
                                text: modelData === win.time
                                    ? `<font color="${Theme.accent}"><b>[${label}]</b></font>`
                                    : ` ${label} `
                                color: Theme.gray
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: win.time = parent.modelData
                                }
                            }
                        }
                        T {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: win.assigned ? "   " + win.assigned.replace(Quickshell.env("HOME"), "~") : "   " + I18n.tr("наследует")
                            color: Theme.gray
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    GridView {
                        id: grid

                        Layout.fillWidth: true
                        implicitHeight: cellHeight * win.visibleRows
                        cellWidth: win.thumbW + 16
                        cellHeight: win.thumbH + cell.height * 1.4 + 16
                        clip: true
                        model: win.items
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds

                        // бесконечная прокрутка wallhaven
                        onCurrentIndexChanged: if (win.source === "wallhaven" && currentIndex >= count - win.cols * 2) win.fetch(false)
                        onAtYEndChanged: if (atYEnd && win.source === "wallhaven") win.fetch(false)

                        delegate: Item {
                            id: tile

                            required property var modelData
                            required property int index
                            readonly property bool sel: GridView.isCurrentItem
                            readonly property bool applied: win.assigned === modelData.path
                            readonly property bool saved: Wallpaper.local.includes(modelData.path)

                            width: grid.cellWidth
                            height: grid.cellHeight

                            Rectangle {
                                id: frame

                                x: 8
                                y: 8
                                width: win.thumbW
                                height: win.thumbH
                                color: Theme.bg1
                                border.width: 2
                                border.color: tile.sel ? Theme.accent : tile.applied ? Theme.green : Theme.bg2

                                Image {
                                    id: img
                                    anchors { fill: parent; margins: 2 }
                                    source: tile.modelData.thumb
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: win.thumbW
                                }

                                // шейдер — живьём, пока плитка выбрана
                                WallLayer {
                                    id: live
                                    anchors { fill: parent; margins: 2 }
                                    path: Wallpaper.kindOf(tile.modelData.path) === "shader" ? tile.modelData.path : ""
                                    playing: tile.sel
                                    fps: 30
                                }

                                T {
                                    anchors.centerIn: parent
                                    visible: img.status !== Image.Ready && !live.ready
                                    text: !tile.modelData.thumb ? tile.modelData.name : img.status === Image.Error ? I18n.tr("ошибка") : "…"
                                    color: Theme.gray
                                }
                            }

                            RowLayout {
                                x: 8
                                width: win.thumbW
                                anchors.top: frame.bottom
                                anchors.topMargin: 4
                                spacing: 0

                                T {
                                    text: tile.applied ? "● " : tile.saved ? "↓ " : "  "
                                    color: tile.applied ? Theme.green : Theme.gray
                                }
                                T {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: tile.modelData.name
                                    color: tile.sel ? Theme.fg : Theme.gray
                                    font.bold: tile.sel
                                    elide: Text.ElideMiddle
                                }
                                T {
                                    text: tile.modelData.info
                                    color: Theme.gray
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: mouse => {
                                    const p = mapToGlobal(mouse.x, mouse.y);
                                    if (win.lastMouseSet && (p.x !== win.lastMouse.x || p.y !== win.lastMouse.y))
                                        grid.currentIndex = tile.index;
                                    win.lastMouse = p;
                                    win.lastMouseSet = true;
                                }
                                onClicked: {
                                    grid.currentIndex = tile.index;
                                    win.apply(tile.modelData);
                                }
                            }
                        }

                        T {
                            anchors.centerIn: parent
                            visible: grid.count === 0
                            color: Theme.gray
                            text: win.loading ? I18n.tr("загрузка…")
                                : win.error ? win.error
                                : win.source === "local" ? I18n.tr("пусто: %1 — найдите обои на wallhaven (Tab)", Wallpaper.dir)
                                : I18n.tr("ничего не найдено")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    // строка состояния и подсказки клавиш, как у TUI-программ
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T {
                            text: (grid.count ? (grid.currentIndex + 1) + "/" + grid.count : "0/0")
                                + (win.loading && grid.count ? I18n.tr("  загрузка…") : "")
                            color: Theme.gray
                        }
                        // режим заполнения: fill [fit] stretch — Ctrl+F или клик
                        T {
                            textFormat: Text.StyledText
                            text: "   " + Wallpaper.fillModes.map(m => m === Wallpaper.fill
                                ? `<font color="${Theme.accent}"><b>[${m}]</b></font>`
                                : `<font color="${Theme.gray}"> ${m} </font>`).join("")
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Wallpaper.cycleFill()
                            }
                        }
                        T {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: win.status ? "  " + win.status : ""
                            color: win.status.startsWith("✓") ? Theme.green : Theme.accent
                            elide: Text.ElideRight
                        }
                        T {
                            textFormat: Text.StyledText
                            text: [["↵", I18n.tr("применить")], ["⇥", I18n.tr("источник")], ["^t", I18n.tr("куда")], ["^n", I18n.tr("день/ночь")], ["^del", I18n.tr("сброс")], ["^f", I18n.tr("заполнение")], ["←↑↓→", I18n.tr("выбор")], ["esc", I18n.tr("выход")]]
                                .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                            color: Theme.gray
                        }
                    }
                }
            }
        }
    }
}
