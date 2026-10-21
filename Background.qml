import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.services
import "services/wallpaper.js" as Wl

// Обои на нижнем слое layer-shell (картинка, gif, видео или шейдер — WallLayer); новые появляются поверх старых
// переходом shell.wallpaper.transition:
//   type   — печатается строками слева направо, во главе строки курсор █ цвета акцента
//   blocks — проступает случайными клетками, как на старом терминале
//   scan   — развёртка сверху вниз со светящейся строкой
//   fade   — проявляется; none — сразу; random — каждый раз другой
// Маска — прямоугольники в ShaderEffectSource, сам переход — MultiEffect (свои шейдеры не нужны).
// Первая картинка при запуске shell — всегда fade. Живые обои стоят на паузе по Wallpaper.livePlaying.
PanelWindow {
    id: bg

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ochre-wallpaper"
    color: Theme.bg0   // виден по краям в режиме fit

    readonly property string ws: Wallpaper.activeWs(screen?.name ?? "")
    property string shownWs: ws
    onWsChanged: Qt.callLater(() => shownWs = ws)
    readonly property string src: Wallpaper.imageFor(screen?.name ?? "", ws)
    readonly property int mode: Wallpaper.fill === "fit" ? Image.PreserveAspectFit
        : Wallpaper.fill === "stretch" ? Image.Stretch
        : Image.PreserveAspectCrop

    readonly property var styles: ["type", "blocks", "scan"]
    property string style: "fade"     // переход, который играет сейчас
    property real p: 1                 // 0 — старая картинка, 1 — новая
    property bool first: true
    property bool quick: false
    readonly property bool masked: p < 1 && style !== "fade"

    // два слоя по очереди: новые обои грузятся в свободный, старый остаётся как был (видео не начинается заново)
    property bool flip: false
    readonly property Item cur: flip ? lb : la
    readonly property Item prev: flip ? la : lb
    readonly property bool playing: Wallpaper.livePlaying(screen?.name ?? "")

    onSrcChanged: {
        const want = Settings.get("shell.wallpaper.transition");
        quick = !first && ws !== shownWs;
        style = quick || first || !cur.path ? "fade"
            : want === "random" ? styles[Math.floor(Math.random() * styles.length)] : want;
        first = false;
        anim.stop();
        p = 0;
        flip = !flip;
        if (cur.path === src && cur.ready) start();
        else cur.path = src;
    }

    function start() {
        if (style === "none") done();
        else anim.restart();
    }

    function done() {
        p = 1;
        prev.path = "";
        // постер шейдера для greeter, хуков и окна обоев — снимок кадра, когда слой уже виден целиком
        const path = cur.path;
        if (Wl.kindOf(path) === "shader" && !Wallpaper.posters[path])
            cur.grabToImage(r => { if (r.saveToFile(Wallpaper.posterOf(path))) Wallpaper.posterSaved(path); });
    }

    WallLayer {
        id: la
        anchors.fill: parent
        z: bg.cur === la ? 1 : 0
        fillMode: bg.mode
        fps: Settings.get("shell.wallpaper.live.fps")
        playing: bg.cur === la && bg.playing
        opacity: bg.cur === la && bg.style === "fade" ? bg.p : 1
        visible: bg.cur === la ? !bg.masked : path !== ""
        onShown: if (bg.cur === la) bg.start()
    }

    WallLayer {
        id: lb
        anchors.fill: parent
        z: bg.cur === lb ? 1 : 0
        fillMode: bg.mode
        fps: Settings.get("shell.wallpaper.live.fps")
        playing: bg.cur === lb && bg.playing
        opacity: bg.cur === lb && bg.style === "fade" ? bg.p : 1
        visible: bg.cur === lb ? !bg.masked : path !== ""
        onShown: if (bg.cur === lb) bg.start()
    }

    NumberAnimation {
        id: anim
        target: bg
        property: "p"
        from: 0
        to: 1
        duration: (bg.quick ? 150 : bg.style === "fade" ? 450 : bg.style === "blocks" ? 700 : 900) / Settings.get("shell.anim.speed")
        easing.type: bg.style === "fade" ? Easing.OutCubic : Easing.Linear
        // иначе в режиме fit старая картинка торчала бы из-под новой по краям
        onFinished: bg.done()
    }

    // новая картинка сквозь маску
    MultiEffect {
        anchors.fill: parent
        z: 2
        visible: bg.masked
        source: bg.cur
        maskEnabled: true
        maskSource: maskSrc
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0
    }

    ShaderEffectSource {
        id: maskSrc
        z: 2
        anchors.fill: parent
        sourceItem: mask
        hideSource: true
        visible: false
        live: bg.masked
    }

    // ── маска: белое — видна новая картинка ──
    Item {
        id: mask
        anchors.fill: parent

        // строка — высота символа в масштабе обоев: ~40 строк на экран
        readonly property int rows: 40
        readonly property real rowH: height / rows
        readonly property real cellW: rowH * 0.55

        // type: строки печатаются по очереди, каждая — за 1/8 времени, следующая стартует раньше, чем допечатана предыдущая
        Repeater {
            model: bg.style === "type" ? mask.rows : 0
            Rectangle {
                required property int index
                readonly property real k: 8
                readonly property real t: Math.max(0, Math.min(1, bg.p * (mask.rows / k + 1) - index / k))
                y: index * mask.rowH
                height: Math.ceil(mask.rowH)
                width: Math.round(t * mask.width / mask.cellW) * mask.cellW
                color: "white"
            }
        }

        // blocks: клетки 24×14 открываются в случайном порядке
        Repeater {
            id: blocks
            readonly property int cols: 24
            readonly property int rws: 14
            model: bg.style === "blocks" ? cols * rws : 0
            Rectangle {
                required property int index
                readonly property real at: { const v = Math.sin(index * 12.9898 + 78.233) * 43758.5453; return v - Math.floor(v); }   // свой порядок у каждой клетки
                x: index % blocks.cols * Math.ceil(mask.width / blocks.cols)
                y: Math.floor(index / blocks.cols) * Math.ceil(mask.height / blocks.rws)
                width: Math.ceil(mask.width / blocks.cols)
                height: Math.ceil(mask.height / blocks.rws)
                color: "white"
                visible: bg.p >= at
            }
        }

        // scan: всё выше развёртки
        Rectangle {
            visible: bg.style === "scan"
            width: parent.width
            height: Math.round(bg.p * parent.height)
            color: "white"
        }
    }

    // ── поверх перехода: курсоры type и строка развёртки ──
    Repeater {
        z: 3
        model: bg.masked && bg.style === "type" ? mask.rows : 0
        Rectangle {
            required property int index
            readonly property real k: 8
            readonly property real t: Math.max(0, Math.min(1, bg.p * (mask.rows / k + 1) - index / k))
            visible: t > 0 && t < 1
            x: Math.round(t * mask.width / mask.cellW) * mask.cellW
            y: index * mask.rowH
            width: mask.cellW
            height: Math.ceil(mask.rowH)
            color: Theme.accent
        }
    }

    Rectangle {
        z: 3
        visible: bg.masked && bg.style === "scan"
        y: Math.round(bg.p * parent.height) - height / 2
        width: parent.width
        height: Math.max(3, Math.round(parent.height / 240))
        color: Theme.accent
        opacity: 0.9
    }

    MouseArea {
        z: 10
        anchors.fill: parent
        enabled: Settings.get("shell.desktop.menu")
        acceptedButtons: Qt.RightButton
        onClicked: mouse => desktopMenu.openAt(mouse.x, mouse.y)
    }

    DesktopMenu {
        id: desktopMenu
        screen: bg.screen
    }
}
