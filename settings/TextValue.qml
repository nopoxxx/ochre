import QtQuick
import qs
import qs.services

// текст: поле прямо в строке, клик — редактировать
Rectangle {
    id: tf
    property var win
    property var r
    property int idx
    property bool current

    readonly property bool edit: win.editing && current
    implicitWidth: win.cw * 32
    implicitHeight: tfT.implicitHeight + 6
    color: edit ? Theme.bg : "transparent"
    border.color: edit ? Theme.accent : tfHover.containsMouse ? Theme.gray : Theme.bg2
    border.width: 1
    T {
        id: tfT
        visible: !tf.edit
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: tf.win.cw * 0.6; rightMargin: tf.win.cw * 0.6 }
        elide: Text.ElideRight
        text: String(tf.win.value(tf.r)) || I18n.tr("пусто")
        color: String(tf.win.value(tf.r)) ? Theme.aqua : Theme.bg2
    }
    TextInput {
        visible: tf.edit
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: tf.win.cw * 0.6; rightMargin: tf.win.cw * 0.6 }
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        selectionColor: Theme.bg2
        renderType: Text.NativeRendering
        clip: true
        onVisibleChanged: if (visible) { text = String(tf.win.value(tf.r)); selectAll(); forceActiveFocus(); }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) tf.win.finishEdit(true, text);
            else if (event.key === Qt.Key_Escape) tf.win.finishEdit(false, "");
            else return;
            event.accepted = true;
        }
        onActiveFocusChanged: if (!activeFocus && visible) tf.win.finishEdit(true, text)
    }
    MouseArea {
        id: tfHover
        anchors.fill: parent
        visible: !tf.edit
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: { tf.win.focusRow(tf.idx); tf.win.editing = true; }
    }
}
