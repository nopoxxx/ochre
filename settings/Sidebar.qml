import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Левая колонка окна настроек: поиск (/) и разделы со значками; клик — раздел, цифра справа — его клавиша.
Rectangle {
    id: side
    property var win
    property Item flick                      // список параметров: выбор раздела прокручивает его в начало
    readonly property alias search: search   // поле поиска: окно берёт из него запрос и ставит в него фокус

    color: "transparent"
    border.color: Theme.bg2
    border.width: 1

    ColumnLayout {
        anchors { fill: parent; margins: 4 }
        spacing: 2

        // поиск — над разделами, как в DMS
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: side.win.lineH * 1.2
            color: search.activeFocus ? Theme.bg1 : "transparent"
            border.color: search.activeFocus ? Theme.accent : Theme.bg2
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: side.win.cw * 0.6; rightMargin: side.win.cw * 0.6 }
                spacing: side.win.cw * 0.6
                T { font.family: Theme.iconFont; text: String.fromCodePoint(0xF0349); color: search.activeFocus ? Theme.accent : Theme.gray }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: search.implicitHeight
                    TextInput {
                        id: search
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                        selectionColor: Theme.bg2
                        renderType: Text.NativeRendering
                        clip: true
                        Keys.onPressed: event => {
                            const k = event.key;
                            if (k === Qt.Key_Escape) side.win.endSearch(false);
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) side.win.endSearch(true);
                            else if (k === Qt.Key_Down) side.win.move(1);
                            else if (k === Qt.Key_Up) side.win.move(-1);
                            else return;
                            event.accepted = true;
                        }
                    }
                    T { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("поиск  /"); color: Theme.bg2 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: side.win.startSearch() }
                }
                T {
                    visible: search.text !== ""
                    font.family: Theme.iconFont
                    text: String.fromCodePoint(0xF0156)
                    color: clr.containsMouse ? Theme.red : Theme.gray
                    MouseArea { id: clr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: side.win.endSearch(false) }
                }
            }
        }

        Item { implicitHeight: 4 }

        Repeater {
            model: side.win.sections

            Rectangle {
                id: sec
                required property var modelData
                required property int index
                readonly property bool current: index === side.win.section && !side.win.query

                Layout.fillWidth: true
                implicitHeight: side.win.lineH * 1.35
                color: current ? Theme.bg1 : secHover.containsMouse ? Qt.darker(Theme.bg1, 1.35) : "transparent"

                Rectangle { visible: sec.current; width: 3; height: parent.height; color: Theme.accent }
                RowLayout {
                    anchors { fill: parent; leftMargin: side.win.cw * 1.2; rightMargin: side.win.cw }
                    spacing: side.win.cw
                    T {
                        font.family: Theme.iconFont
                        text: side.win.icon(sec.modelData.id)
                        color: sec.current ? Theme.accent : Theme.gray
                    }
                    T {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: I18n.tr(sec.modelData.title)
                        color: sec.current ? Theme.accent : secHover.containsMouse ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                        font.bold: sec.current
                    }
                    T { text: String(sec.index + 1); color: Theme.bg2 }
                }
                MouseArea {
                    id: secHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { side.win.selectSection(sec.index); side.win.endSearch(false); side.flick.contentY = 0; }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
