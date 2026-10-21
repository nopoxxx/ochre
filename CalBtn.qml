import QtQuick

// Кнопка календаря «[текст]» (bare — без скобок, для стрелок ‹ ›): подсвечивается под мышью; danger — красная, on — акцент.
T {
    id: b

    property bool on: false
    property bool danger: false
    property bool bare: false
    property string label
    signal clicked()

    text: bare ? " " + label + " " : "[" + label + "]"
    color: danger ? Theme.red : on || area.containsMouse ? Theme.accent : Theme.gray
    font.bold: area.containsMouse || on

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
