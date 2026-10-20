import QtQuick
import qs

// Выпадающий список вариантов перечисления (кнопка — DropButton): стоит у кнопки, едет с ней при прокрутке,
// снизу не помещается — открывается вверх. Открыт, пока win.drop >= 0; win.dropItem — кнопка.
Rectangle {
    id: dropBox
    property var win
    property Item flick   // список параметров: при его прокрутке список едет за кнопкой
    property Item box     // рамка окна: в её координатах dropBox и стоит

    readonly property var r: dropBox.win.rows[dropBox.win.drop] ?? null
    readonly property var opts: r ? dropBox.win.optionsOf(r) : []
    // ширина — по самому длинному варианту (сетка моноширинная), а не от dropCol:
    // его дети тянутся по его же ширине — список раздувался в polish-петле
    readonly property int maxLen: opts.reduce((n, o) => Math.max(n, Array.from(dropBox.win.optionLabel(r, o)).length), 0)
    // где кнопка сейчас: список едет вместе с ней при прокрутке (contentY — чтобы привязка пересчитывалась)
    readonly property rect anchor: {
        dropBox.flick.contentY;
        dropBox.flick.height;
        const it = dropBox.win.dropItem;
        if (!it) return Qt.rect(0, 0, 0, 0);
        const p = it.mapToItem(dropBox.box, 0, 0);
        return Qt.rect(p.x, p.y, it.width, it.height);
    }
    // кнопка ушла за край прокрутки — список прячем, а не вешаем в воздухе
    readonly property bool inView: {
        const f = dropBox.flick.mapToItem(dropBox.box, 0, 0);
        return anchor.y + anchor.height > f.y && anchor.y < f.y + dropBox.flick.height;
    }
    // снизу не помещается — открываем вверх от кнопки
    readonly property bool below: anchor.y + anchor.height + 2 + height <= dropBox.box.height - Theme.pad
    visible: dropBox.win.drop >= 0 && r !== null && !!dropBox.win.dropItem && inView
    z: 10
    x: Math.max(Theme.pad, Math.min(dropBox.box.width - width - Theme.pad, anchor.x))
    y: below ? anchor.y + anchor.height + 2 : Math.max(Theme.pad, anchor.y - height - 2)
    readonly property bool themes: r?.key === "shell.theme.name"
    width: Math.max(dropBox.win.cw * 22, dropBox.win.cw * (maxLen + 4) + 8) + (themes ? dropBox.win.cw * 12 : 0)
    height: dropCol.implicitHeight + 8
    color: Theme.bg
    border.color: Theme.accent
    border.width: 1

    // клики по рамке и колёсико не проваливаются в строки под списком
    MouseArea {
        anchors.fill: parent
        onWheel: wheel => wheel.accepted = true
    }

    Column {
        id: dropCol
        x: 4
        y: 4
        width: parent.width - 8
        Repeater {
            model: dropBox.opts
            Rectangle {
                required property var modelData
                readonly property bool sel: dropBox.r && modelData === dropBox.win.shown(dropBox.r)
                width: dropCol.width
                height: dropBox.win.lineH
                color: optHover.containsMouse ? Theme.bg1 : "transparent"
                T {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: dropBox.win.cw }
                    text: (parent.sel ? "● " : "  ") + dropBox.win.optionLabel(dropBox.r, parent.modelData)
                    color: parent.sel ? Theme.accent : Theme.fg
                }
                ThemeStrip {
                    visible: dropBox.themes
                    anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: dropBox.win.cw }
                    name: visible ? parent.modelData : ""
                    size: Math.round(dropBox.win.cw)
                }
                MouseArea {
                    id: optHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // drop = -1 сразу уничтожает строки списка вместе с этим обработчиком:
                    // всё нужное — в локальные переменные до закрытия
                    onClicked: {
                        const w = dropBox.win, i = w.drop, v = parent.modelData;
                        w.drop = -1;
                        w.pick(i, v);
                    }
                }
            }
        }
    }
}
