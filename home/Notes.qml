import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Заметки: начало ~/.config/ochre/notes.md (как `head`); ↵ / клик — открыть файл в редакторе.
// Файл меняется снаружи — секция перечитывает его сама.
Section {
    id: sec

    readonly property string path: Quickshell.env("HOME") + "/.config/ochre/notes.md"
    readonly property int max: 8
    property var lines: []

    title: I18n.tr("заметки")
    count: 1

    function activate(i) {
        Term.edit(path);
        sec.panel.close();
    }

    FileView {
        id: file
        path: sec.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const all = text().split("\n");
            while (all.length && !all[all.length - 1].trim()) all.pop();
            sec.lines = all;
        }
        onLoadFailed: sec.lines = []
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight
        color: sec.isCur(0) ? Theme.bg1 : hover.hovered ? Theme.hover : "transparent"

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 0

            T {
                visible: sec.lines.length === 0
                text: I18n.tr("пусто — ↵ открыть notes.md в редакторе")
                color: Theme.gray
            }

            Repeater {
                model: sec.lines.slice(0, sec.max)
                T {
                    required property string modelData
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: modelData || " "
                    // заголовки markdown — акцентом
                    color: /^#/.test(modelData) ? Theme.accent : Theme.fg
                    font.bold: /^#/.test(modelData)
                }
            }

            T {
                visible: sec.lines.length > sec.max
                text: I18n.tr("… ещё %1 строк", sec.lines.length - sec.max)
                color: Theme.gray
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: { sec.pick(0); sec.activate(0); } }
    }
}
