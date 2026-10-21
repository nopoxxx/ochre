import Quickshell
import QtQuick
import qs
import qs.services

// Картинка на столе: файл с диска. Путь — в режиме правки (↵) или перетащить файл на стол.
Item {
    id: root

    property var cfg
    property real cw
    property real ch
    property bool editing
    property bool writing: false

    readonly property string path: String(cfg?.path ?? "").replace(/^~(?=\/|$)/, Quickshell.env("HOME"))

    onWritingChanged: {
        if (writing) {
            input.text = cfg?.path ?? "";
            input.forceActiveFocus();
            input.selectAll();
        } else if (input.text.trim() !== (cfg?.path ?? "")) Desktop.update(cfg.id, { path: input.text.trim() });
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.path ? "file://" + encodeURI(root.path) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: Math.ceil(width)
        sourceSize.height: Math.ceil(height)
    }

    T {
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: img.status !== Image.Ready && !root.writing
        text: root.path && img.status === Image.Error ? I18n.tr("нет файла %1", root.cfg.path)
            : root.path ? "" : root.editing ? I18n.tr("↵ — путь к картинке, или перетащите файл") : ""
        color: Theme.gray
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: root.writing
        height: root.ch * 1.4
        color: Theme.bg1
        border.color: Theme.accent
        border.width: 1

        TextInput {
            id: input
            anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
            clip: true
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            selectionColor: Theme.bg2
            renderType: Text.NativeRendering
        }
    }
}
