import Quickshell
import QtQuick
import qs.services
import qs.bar
import "services/settings.js" as S

// Модульная панель: три зоны — left, center, right.
// Состав и порядок модулей — в настройках (Mod+S → bar/), сами модули — в bar/
PanelWindow {
    id: bar

    readonly property bool onTop: Settings.get("shell.bar.position") === "top"
    readonly property bool floating: Settings.get("shell.bar.style") === "floating"
    readonly property bool autohide: Settings.get("shell.bar.autohide")
    readonly property string separator: Settings.get("shell.bar.separator")
    readonly property var layout: S.normalizeLayout(Settings.get("shell.bar.layout"))
    readonly property real opacityPct: Settings.get("shell.bar.opacity") / 100
    readonly property int gap: floating ? 8 : 0
    readonly property int fullHeight: Theme.barHeight + (floating ? 4 : 0)

    // открытые попапы держат панель видимой при автоскрытии
    property int openPopups: 0
    readonly property bool revealed: !autohide || hover.hovered || openPopups > 0

    anchors { top: onTop; bottom: !onTop; left: true; right: true }
    margins { top: onTop ? gap : 0; bottom: onTop ? 0 : gap; left: gap; right: gap }
    // при автоскрытии остаётся полоска в 4px, наведение на неё показывает панель
    implicitHeight: revealed ? fullHeight : 4
    exclusionMode: autohide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"

    HoverHandler { id: hover }

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

    Rectangle {
        anchors.fill: parent
        visible: bar.revealed
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bar.opacityPct)
        border.width: bar.floating ? 2 : 0
        border.color: Theme.accent

        // под зонами: модули без своей прокрутки пропускают колёсико сюда
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => bar.scroll(wheel.angleDelta.y)
        }

        // Зоны не налезают друг на друга: правая (статус) всегда целиком; центральная по центру, а упёрлась
        // в правую — сдвигается влево; левой (приглашение с заголовком окна) — что осталось, обрезается с «…»
        TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }
        readonly property real gapW: cell.advanceWidth * 2
        readonly property real centerX: {
            const w = centerZone.implicitWidth;
            const ideal = (width - w) / 2;
            return Math.max(Theme.pad, Math.min(ideal, rightZone.x - gapW - w));
        }
        readonly property real leftMax: (centerZone.implicitWidth > 0 ? centerX : rightZone.x) - gapW - Theme.pad
        readonly property bool leftCut: leftZone.implicitWidth > leftMax

        Item {
            id: leftBox
            anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }
            width: Math.max(0, parent.leftCut ? parent.leftMax - cell.advanceWidth : leftZone.implicitWidth)
            height: leftZone.implicitHeight
            clip: parent.leftCut

            BarZone {
                id: leftZone
                bar: bar
                ids: bar.layout.left
            }
        }
        BarText {
            visible: parent.leftCut && leftBox.width > 0
            anchors { left: leftBox.right; verticalCenter: parent.verticalCenter }
            text: "…"
            color: Theme.gray
        }

        BarZone {
            id: centerZone
            bar: bar
            ids: bar.layout.center
            x: parent.centerX
            anchors.verticalCenter: parent.verticalCenter
        }

        BarZone {
            id: rightZone
            bar: bar
            ids: bar.layout.right
            anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
        }
    }
}
