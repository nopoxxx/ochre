import Quickshell
import QtQuick
import qs.services
import qs.bar
import "services/settings.js" as S

// Модульная панель: три зоны — left, center, right.
// Состав и порядок модулей — в настройках (Mod+S → bar/), сами модули — в bar/
PanelWindow {
    id: bar

    readonly property string edge: Theme.barEdge
    readonly property bool vertical: Theme.barVertical
    readonly property string style: Theme.barStyle
    readonly property bool autohide: Settings.get("shell.bar.autohide")
    readonly property string separator: Settings.get("shell.bar.separator")
    readonly property var layout: S.normalizeLayout(Settings.get("shell.bar.layout"))
    readonly property real opacityPct: Settings.get("shell.bar.opacity") / 100
    readonly property int gap: Theme.barGap
    readonly property int thickness: Theme.barThickness

    // открытые попапы держат панель видимой при автоскрытии
    property int openPopups: 0
    readonly property bool revealed: !autohide || hover.hovered || openPopups > 0

    anchors { top: edge !== "bottom"; bottom: edge !== "top"; left: edge !== "right"; right: edge !== "left" }
    margins {
        top: edge === "bottom" ? 0 : gap
        bottom: edge === "top" ? 0 : gap
        left: edge === "right" ? 0 : gap
        right: edge === "left" ? 0 : gap
    }
    // при автоскрытии остаётся полоска в 4px, наведение на неё показывает панель
    implicitHeight: vertical ? 0 : revealed ? thickness : 4
    implicitWidth: vertical ? revealed ? thickness : 4 : 0
    exclusionMode: autohide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"

    mask: Region {
        Region { item: !bar.revealed || (bar.style !== "island" && bar.style !== "capsules") ? hit : null }
        Region { item: boxAll }
        Region { item: boxL }
        Region { item: boxC }
        Region { item: boxR }
    }

    HoverHandler { id: hover }

    Item { id: hit; anchors.fill: parent }

    // колёсико по панели — соседний рабочий стол этого монитора. Модули со своей прокруткой (vol, kbd)
    // забирают событие сами. Тачпад шлёт много мелких событий — копим до шага колёсика (120)
    property real _wheel: 0

    function scroll(dy) {
        if (!Settings.get("shell.bar.wheelWorkspaces") || dy === 0) return;
        _wheel = Math.sign(dy) === Math.sign(_wheel) ? _wheel + dy : dy;
        if (Math.abs(_wheel) < 120) return;
        Niri.scrollWorkspace(screen?.name, _wheel > 0 ? "up" : "down");
        _wheel = 0;
    }

    Item {
        id: content

        anchors.fill: parent
        visible: bar.revealed
        clip: v

        readonly property bool v: bar.vertical
        readonly property bool island: bar.style === "island"
        readonly property bool capsules: bar.style === "capsules"
        readonly property color fill: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bar.opacityPct)

        // Зоны не налезают друг на друга: правая (статус) всегда целиком; центральная по центру, а упёрлась
        // в правую — сдвигается влево; левой (приглашение с заголовком окна) — что осталось, обрезается с «…»
        TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }
        readonly property real mainLen: v ? height : width
        readonly property real cellM: v ? cell.height : cell.advanceWidth
        readonly property real padM: Theme.pad
        readonly property real gapM: (v ? cell.height : cell.advanceWidth * 2) + (capsules ? padM * 2 : 0)
        readonly property real lenL: v ? leftZone.implicitHeight : leftZone.implicitWidth
        readonly property real lenC: v ? centerZone.implicitHeight : centerZone.implicitWidth
        readonly property real lenR: v ? rightZone.implicitHeight : rightZone.implicitWidth

        readonly property real rightEnd: mainLen - padM - lenR
        readonly property real spreadC: Math.max(padM, Math.min((mainLen - lenC) / 2, rightEnd - gapM - lenC))
        readonly property real restLen: lenC + lenR + (lenC > 0 && lenR > 0 ? gapM : 0)
        readonly property real leftMax: island ? mainLen - padM * 2 - restLen - (restLen > 0 ? gapM : 0)
            : (lenC > 0 ? spreadC : rightEnd) - gapM - padM
        readonly property bool leftCut: lenL > leftMax
        readonly property real leftShown: leftCut ? Math.max(0, leftMax - cellM) : lenL
        readonly property real leftBlock: leftCut && leftShown > 0 ? leftShown + cellM : leftShown

        readonly property real islandLen: leftBlock + (leftBlock > 0 && restLen > 0 ? gapM : 0) + restLen
        readonly property real posL: island ? (mainLen - islandLen) / 2 : padM
        readonly property real posC: island ? posL + leftBlock + (leftBlock > 0 && lenC > 0 ? gapM : 0) : spreadC
        readonly property real posR: {
            if (!island) return rightEnd;
            const end = lenC > 0 ? posC + lenC : posL + leftBlock;
            return end + (end > posL && lenR > 0 ? gapM : 0);
        }

        function crossOf(it) { return ((v ? width : height) - (v ? it.implicitWidth : it.implicitHeight)) / 2; }

        Rectangle {
            id: boxAll
            readonly property bool used: bar.style === "full" || bar.style === "floating" || content.island
            readonly property real from: content.island ? content.posL - content.padM : 0
            readonly property real len: !used ? 0 : content.island ? content.islandLen + content.padM * 2 : content.mainLen
            x: content.v ? 0 : from
            y: content.v ? from : 0
            width: content.v ? (used ? content.width : 0) : len
            height: content.v ? len : (used ? content.height : 0)
            visible: used
            color: content.fill
            border.width: Theme.barBoxed ? 2 : 0
            border.color: Theme.accent
        }

        Rectangle {
            id: boxL
            readonly property bool used: content.capsules && content.leftBlock > 0
            readonly property real len: used ? content.leftBlock + content.padM * 2 : 0
            x: content.v ? 0 : content.posL - content.padM
            y: content.v ? content.posL - content.padM : 0
            width: content.v ? (used ? content.width : 0) : len
            height: content.v ? len : (used ? content.height : 0)
            visible: used
            color: content.fill
            border.width: 2
            border.color: Theme.accent
        }

        Rectangle {
            id: boxC
            readonly property bool used: content.capsules && content.lenC > 0
            readonly property real len: used ? content.lenC + content.padM * 2 : 0
            x: content.v ? 0 : content.posC - content.padM
            y: content.v ? content.posC - content.padM : 0
            width: content.v ? (used ? content.width : 0) : len
            height: content.v ? len : (used ? content.height : 0)
            visible: used
            color: content.fill
            border.width: 2
            border.color: Theme.accent
        }

        Rectangle {
            id: boxR
            readonly property bool used: content.capsules && content.lenR > 0
            readonly property real len: used ? content.lenR + content.padM * 2 : 0
            x: content.v ? 0 : content.posR - content.padM
            y: content.v ? content.posR - content.padM : 0
            width: content.v ? (used ? content.width : 0) : len
            height: content.v ? len : (used ? content.height : 0)
            visible: used
            color: content.fill
            border.width: 2
            border.color: Theme.accent
        }

        // под зонами: модули без своей прокрутки пропускают колёсико сюда
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => bar.scroll(wheel.angleDelta.y)
        }

        Item {
            id: leftBox
            x: content.v ? content.crossOf(leftZone) : content.posL
            y: content.v ? content.posL : content.crossOf(leftZone)
            width: content.v ? leftZone.implicitWidth : content.leftShown
            height: content.v ? content.leftShown : leftZone.implicitHeight
            clip: content.leftCut

            BarZone {
                id: leftZone
                bar: bar
                ids: bar.layout.left
            }
        }
        Item {
            id: ell
            visible: content.leftCut && content.leftShown > 0
            x: content.v ? content.crossOf(ell) : content.posL + content.leftShown
            y: content.v ? content.posL + content.leftShown : content.crossOf(ell)
            implicitWidth: dots.implicitWidth
            implicitHeight: dots.height

            BarText { id: dots; text: "…"; color: Theme.gray }
        }

        BarZone {
            id: centerZone
            bar: bar
            ids: bar.layout.center
            x: content.v ? content.crossOf(centerZone) : content.posC
            y: content.v ? content.posC : content.crossOf(centerZone)
        }

        BarZone {
            id: rightZone
            bar: bar
            ids: bar.layout.right
            x: content.v ? content.crossOf(rightZone) : content.posR
            y: content.v ? content.posR : content.crossOf(rightZone)
        }
    }
}
