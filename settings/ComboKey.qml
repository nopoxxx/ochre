import QtQuick
import qs
import qs.services

// сочетание: [Mod+Shift+M] — клик и нажать; ⌫ в строке или ✕ — убрать
Row {
    id: cb
    property var win
    property var r
    property int idx
    property bool current

    readonly property bool cap: win.capturing && current
    readonly property bool edit: win.editing && current
    spacing: win.cw
    Rectangle {
        width: Math.max(cb.win.cw * 18, cbT.implicitWidth + cb.win.cw * 2)
        height: cbT.implicitHeight + 6
        color: cb.cap || cb.edit ? Theme.bg : cbHover.containsMouse ? Theme.bg1 : "transparent"
        border.color: cb.cap || cb.edit ? Theme.accent : Theme.bg2
        border.width: 1
        T {
            id: cbT
            visible: !cb.edit
            anchors.centerIn: parent
            text: cb.cap ? I18n.tr("нажмите сочетание…") : cb.win.value(cb.r) || I18n.tr("не задано")
            color: cb.cap ? Theme.accent : cb.win.value(cb.r) ? Theme.blue : Theme.bg2
        }
        TextInput {
            visible: cb.edit
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: cb.win.cw * 0.6; rightMargin: cb.win.cw * 0.6 }
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            renderType: Text.NativeRendering
            onVisibleChanged: if (visible) { text = String(cb.win.value(cb.r)); selectAll(); forceActiveFocus(); }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) cb.win.finishEdit(true, text);
                else if (event.key === Qt.Key_Escape) cb.win.finishEdit(false, "");
                else return;
                event.accepted = true;
            }
        }
        MouseArea {
            id: cbHover
            anchors.fill: parent
            visible: !cb.edit
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { cb.win.focusRow(cb.idx); cb.win.capturing = true; }
        }
    }
    T {
        visible: !!cb.win.value(cb.r) && !cb.cap
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.iconFont
        text: String.fromCodePoint(0xF0156)
        color: cbx.containsMouse ? Theme.red : Theme.gray
        MouseArea { id: cbx; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { cb.win.focusRow(cb.idx); cb.win.reset(cb.win.rows[cb.idx]); } }
    }
}
