import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Строка настройки: подпись и описание слева, элемент справа; строку модуля (bar/, home/) можно тащить.
// win — окно настроек (состояние, черновик, действия); box — его рамка (координаты «призрака»); ghost — «призрак».
Rectangle {
    id: line
    required property var modelData
    property var win
    property Item box
    property Item ghost

    readonly property var r: modelData.row
    readonly property int idx: modelData.index
    readonly property bool current: idx === win.cur

    Layout.fillWidth: true
    implicitHeight: Math.max(texts.implicitHeight, control.implicitHeight) + win.cw * 1.4
    color: current ? Theme.bg1 : rowHover.containsMouse ? Theme.hover : "transparent"

    onCurrentChanged: if (current) Qt.callLater(() => { if (line.win) line.win.scrollTo(line); })   // окно могли закрыть

    readonly property bool canDrag: line.r.type === "module" && win.layoutKey !== ""
    opacity: win.dragRow && win.dragRow.id === line.r.id && win.dragRow.key === line.r.key ? 0.35 : 1

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: line.canDrag ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
        // строку модуля можно тащить: за мышью едет «призрак», строки и карточки ловят его DropArea
        drag.target: line.canDrag ? line.ghost : null
        drag.threshold: 6
        preventStealing: line.canDrag
        onPressed: mouse => {
            if (!line.canDrag) return;
            const p = line.mapToItem(line.box, 0, 0);
            line.ghost.x = p.x;
            line.ghost.y = p.y;
            line.ghost.width = line.width;
            line.ghost.text = line.r.label ?? line.r.id;
            line.ghost.Drag.hotSpot = Qt.point(mouse.x, mouse.y);
        }
        onClicked: line.win.focusRow(line.idx)
        onDoubleClicked: if (line.r.type === "action") line.win.runAction(line.r.action)
    }
    Connections {
        target: rowHover.drag
        function onActiveChanged() {
            if (rowHover.drag.active) { line.win.focusRow(line.idx); line.win.dragRow = line.r; }
            else line.win.finishDrag();
        }
    }
    DropArea {
        anchors.fill: parent
        enabled: line.r.type === "module"
        onEntered: drag => line.win.dropOver(line.idx, drag.y < height / 2)
        onPositionChanged: drag => line.win.dropOver(line.idx, drag.y < height / 2)
    }
    // сюда встанет перетаскиваемый модуль
    Rectangle {
        visible: line.win.isDropBefore(line.r)
        x: Theme.pad
        width: parent.width - Theme.pad * 2
        height: 2
        color: Theme.accent
        z: 5
    }

    Rectangle { visible: line.current; width: 3; height: parent.height; color: Theme.accent }

    RowLayout {
        anchors { fill: parent; leftMargin: line.win.cw * 1.5; rightMargin: line.win.cw * 1.2 }
        spacing: line.win.cw * 2

        // ⠿ — за это (и за всю строку) модуль можно перетащить
        T {
            visible: line.canDrag
            font.family: Theme.iconFont
            text: String.fromCodePoint(0xF01DD)
            color: rowHover.containsMouse || line.current ? Theme.gray : Theme.bg2
        }
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            T {
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: I18n.tr(line.r.label ?? "") + (line.win.changed(line.r) ? ` <font color="${Theme.accent}">*</font>` : "")
                color: line.r.type === "action" ? Theme.blue : line.current ? Theme.fg : Theme.fgDim
                font.bold: line.current
            }
            T {
                // у модулей подсказка общая — описание модуля до «·»
                readonly property string h: I18n.tr(line.r.type === "module" ? String(line.r.hint ?? "").split("  ·  ")[0] : (line.r.hint ?? ""))
                visible: h !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: h
                color: Theme.gray
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
            }
        }

        // элемент по типу строки
        Loader {
            id: control
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            sourceComponent: {
                const t = line.r.type;
                if (t === "bool") return toggleC;
                if (t === "int" || t === "float") return sliderC;
                if (t === "text") return textC;
                if (t === "combo") return comboC;
                if (t === "action") return actionC;
                if (line.win.swatchKeys.includes(line.r.key)) return swatchC;
                return line.win.fitsSegments(line.r) ? segmentsC : dropC;
            }
        }
        Component { id: toggleC; Toggle { win: line.win; r: line.r; idx: line.idx } }
        Component { id: sliderC; Slider { win: line.win; r: line.r; idx: line.idx; current: line.current } }
        Component { id: textC; TextValue { win: line.win; r: line.r; idx: line.idx; current: line.current } }
        Component { id: comboC; ComboKey { win: line.win; r: line.r; idx: line.idx; current: line.current } }
        Component { id: actionC; ActionButton { win: line.win; r: line.r; current: line.current } }
        Component { id: swatchC; Swatches { win: line.win; r: line.r; idx: line.idx } }
        Component { id: segmentsC; Segments { win: line.win; r: line.r; idx: line.idx } }
        Component { id: dropC; DropButton { win: line.win; r: line.r; idx: line.idx } }

        // черновик с клавиатуры — применить мышкой
        T {
            visible: line.win.drafted(line.r)
            text: "[↵]"
            color: Theme.accent
            font.bold: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { line.win.cur = line.idx; line.win.apply(); } }
        }
        // ↺ — по умолчанию (у раскладки — r на строке)
        T {
            readonly property bool can: !["action", "module"].includes(line.r.type) && line.win.changed(line.r)
            opacity: can ? 1 : 0
            font.family: Theme.iconFont
            text: "↺"
            color: resetHover.containsMouse ? Theme.accent : Theme.gray
            MouseArea {
                id: resetHover
                anchors.fill: parent
                enabled: parent.can
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: line.win.resetNow(line.idx)
            }
        }
    }
}
