import QtQuick

// Поле формы события в рамке: серая подсказка, пока пусто; ↵ — accepted, Esc — canceled,
// колёсико — wheeled(±1) (время и дата листаются им без клавиатуры).
Rectangle {
    id: f

    property alias text: inp.text
    property alias input: inp
    property string hint
    property real chars: 20
    property bool wheel: false
    signal accepted()
    signal canceled()
    signal wheeled(int dir)
    signal edited()

    TextMetrics { id: cm; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

    implicitWidth: cm.advanceWidth * chars + 12
    implicitHeight: inp.implicitHeight + 6
    color: Theme.bg1
    border.color: inp.activeFocus ? Theme.accent : area.containsMouse ? Theme.gray : Theme.bg2
    border.width: 1

    TextInput {
        id: inp
        anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
        clip: true
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        selectionColor: Theme.bg2
        selectByMouse: true
        renderType: Text.NativeRendering
        cursorDelegate: BlinkCursor {}
        onTextEdited: f.edited()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) f.accepted();
            else if (event.key === Qt.Key_Escape) f.canceled();
            else if (f.wheel && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) f.wheeled(event.key === Qt.Key_Up ? 1 : -1);
            else return;
            event.accepted = true;
        }
    }

    T {
        anchors { left: parent.left; leftMargin: 6 + (inp.activeFocus ? cm.advanceWidth : 0); verticalCenter: parent.verticalCenter }
        visible: inp.text === ""
        text: f.hint
        color: Theme.gray
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (!f.wheel) { wheel.accepted = false; return; }
            f.wheeled(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
