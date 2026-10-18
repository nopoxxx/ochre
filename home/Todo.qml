import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Список дел из ~/.config/ochre/todo.txt (формат todo.txt: сделанное начинается с «x »; файл можно править руками).
//   [ ] купить молоко
//   [x] позвонить
// ↵ / Space / клик — сделано / нет, a — добавить (последняя строка [+] — тоже), del — удалить, c — убрать сделанное,
// e — открыть файл в редакторе.
Section {
    id: sec

    readonly property string path: Quickshell.env("HOME") + "/.config/ochre/todo.txt"
    property var lines: []          // строки файла как есть (пустые убраны)
    property bool adding: false
    readonly property int max: 12
    readonly property var shown: lines.slice(0, max)
    readonly property int pending: lines.filter(l => !done(l)).length

    title: "todo" + (lines.length ? " · " + pending + "/" + lines.length : "")
    count: shown.length + 1

    function done(l) { return /^x\s/.test(l); }
    function textOf(l) { return l.replace(/^x\s+/, ""); }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    function write(list) {
        lines = list;
        file.setText(list.length ? list.join("\n") + "\n" : "");
    }

    function toggle(i) {
        const l = lines[i];
        write(lines.map((x, j) => j !== i ? x : done(l) ? textOf(l) : "x " + l));
    }

    function add(text) {
        const t = text.trim();
        adding = false;
        if (t) write(lines.concat([t]));
        sec.panel.focusSection(sec);
    }

    function key(event) {
        const k = event.key;
        if (k === Qt.Key_A || k === Qt.Key_N) adding = true;
        else if (k === Qt.Key_Delete && cur < shown.length) {
            write(lines.filter((x, j) => j !== cur));
            cur = Math.min(cur, shown.length);   // последний элемент — [+ добавить]
        }
        else if (k === Qt.Key_C) write(lines.filter(l => !done(l)));
        else if (k === Qt.Key_E) { Term.edit(path); sec.panel.close(); }
        else return false;
        return true;
    }

    function activate(i) {
        if (i < shown.length) toggle(i);
        else adding = true;
    }

    FileView {
        id: file
        path: sec.path
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: sec.lines = text().split("\n").map(l => l.replace(/\s+$/, "")).filter(l => l.trim())
        onLoadFailed: sec.lines = []
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/ochre"])

    Repeater {
        model: sec.shown

        Rectangle {
            id: line
            required property string modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: lineText.implicitHeight
            color: sec.isCur(index) ? Theme.bg1 : hover.hovered ? Qt.darker(Theme.bg1, 1.3) : "transparent"

            T {
                id: lineText
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.StyledText
                readonly property bool isDone: sec.done(line.modelData)
                text: (isDone ? `<font color="${Theme.green}">[x]</font> ` : `<font color="${Theme.gray}">[ ]</font> `)
                    + `<font color="${isDone ? Theme.gray : Theme.fg}">${sec.esc(sec.textOf(line.modelData))}</font>`
                font.strikeout: isDone
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { sec.pick(line.index); sec.activate(line.index); } }
        }
    }

    T {
        visible: sec.lines.length > sec.max
        text: "… ещё " + (sec.lines.length - sec.max) + " — e: открыть файл"
        color: Theme.gray
    }

    // новая задача — поле прямо в списке
    RowLayout {
        visible: sec.adding
        Layout.fillWidth: true
        spacing: 0
        T { text: "[ ] "; color: Theme.accent }
        TextInput {
            id: input
            Layout.fillWidth: true
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            renderType: Text.NativeRendering
            cursorDelegate: BlinkCursor {}
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) sec.add(text);
                else if (event.key === Qt.Key_Escape) { sec.adding = false; sec.panel.focusSection(sec); }
                else return;
                event.accepted = true;
            }
        }
    }

    Btn {
        visible: !sec.adding
        text: "+ добавить"
        current: sec.isCur(sec.shown.length)
        onClicked: { sec.pick(sec.shown.length); sec.activate(sec.shown.length); }
    }

    T {
        visible: sec.focused && !sec.adding
        text: "↵ готово  a добавить  del удалить  c убрать сделанное  e редактор"
        color: Theme.gray
        font.pixelSize: Theme.fontSize - 2
    }
}
