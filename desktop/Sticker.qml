import QtQuick
import qs
import qs.services

// Стикер на столе: заметка текстом. Правится в режиме правки: ↵ или двойной клик — писать, Esc — готово.
Item {
    id: root

    property var cfg
    property real cw
    property real ch
    property bool editing
    property bool writing: false     // ставит DesktopCanvas; false — текст уходит в настройки

    onWritingChanged: {
        if (writing) {
            edit.forceActiveFocus();
            edit.cursorPosition = edit.length;
        } else if (edit.text !== (cfg?.text ?? "")) Desktop.update(cfg.id, { text: edit.text });
    }

    T {
        anchors.fill: parent
        visible: edit.text === "" && !root.writing
        text: root.editing ? I18n.tr("↵ — написать") : ""
        color: Theme.bg3
    }

    TextEdit {
        id: edit

        anchors.fill: parent
        text: root.cfg?.text ?? ""
        readOnly: !root.writing
        wrapMode: TextEdit.Wrap
        clip: true
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        selectionColor: Theme.bg2
        renderType: Text.NativeRendering
        cursorVisible: root.writing
        cursorDelegate: Rectangle { width: root.cw; color: Theme.accent; visible: root.writing; opacity: 0.8 }
    }
}
