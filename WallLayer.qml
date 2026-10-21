import QtQuick
import qs.services
import "services/wallpaper.js" as Wl

// Один слой обоев по пути файла: картинка, gif/webp (AnimatedImage), видео (WallVideo.qml) или шейдер (ShaderEffect).
// ready — первый кадр на месте (по нему Background начинает переход); playing — двигаться (иначе стоит кадр).
// Шейдер получает униформы time (с), resolution (px), accent, bg, fg — контракт в extras/wallpapers/live/README.md.
Item {
    id: root

    property string path
    property int fillMode: Image.PreserveAspectCrop
    property bool playing: true
    property int fps: 30
    property real time: 0                  // время шейдера, на паузе стоит

    readonly property string kind: Wl.kindOf(path)
    readonly property string qsb: kind === "shader" ? Wallpaper.shaderOf(path) : ""
    readonly property bool videoBroken: kind === "video" && (video.status === Loader.Error || (video.item?.failed ?? false))
    readonly property bool ready: !path ? false
        : kind === "video" ? (videoBroken ? still.status === Image.Ready : video.item?.ready ?? false)
        : kind === "shader" ? qsb !== "" && media.item?.status === ShaderEffect.Compiled
        : media.item?.status === Image.Ready
    signal shown()

    // shown — раз на путь: шейдер после шейдера готов сразу (ready не мигает), его ловит смена qsb
    property string shownPath: ""
    function check() {
        if (ready && path && shownPath !== path) {
            shownPath = path;
            shown();
        }
    }
    onReadyChanged: check()
    onQsbChanged: Qt.callLater(check)
    onPathChanged: {
        time = 0;
        shownPath = "";
    }

    Loader {
        id: media
        anchors.fill: parent
        sourceComponent: root.kind === "image" ? imageC : root.kind === "anim" ? animC : root.kind === "shader" && root.qsb ? shaderC : null
    }

    Loader {
        id: video
        anchors.fill: parent
        active: root.kind === "video"
        source: "WallVideo.qml"
        onLoaded: {
            item.fillMode = Qt.binding(() => root.fillMode);
            item.playing = Qt.binding(() => root.playing);
            item.path = Qt.binding(() => root.path);
        }
    }

    // видео не играет (нет qt6-multimedia, кодека) — его постер
    Image {
        id: still
        anchors.fill: parent
        visible: root.videoBroken
        source: root.videoBroken && Wallpaper.stillOf(root.path) ? "file://" + encodeURI(Wallpaper.stillOf(root.path)) : ""
        fillMode: root.fillMode
        asynchronous: true
    }

    Component {
        id: imageC
        Image {
            source: "file://" + encodeURI(root.path)
            fillMode: root.fillMode
            asynchronous: true
        }
    }

    Component {
        id: animC
        AnimatedImage {
            source: "file://" + encodeURI(root.path)
            fillMode: root.fillMode
            asynchronous: true
            // playing сам становится true после загрузки — останавливаем через paused
            paused: !root.playing
        }
    }

    Component {
        id: shaderC
        ShaderEffect {
            readonly property real time: root.time
            readonly property vector2d resolution: Qt.vector2d(width, height)
            readonly property color accent: Theme.accent
            readonly property color bg: Theme.bg0
            readonly property color fg: Theme.fg
            fragmentShader: "file://" + encodeURI(root.qsb)
        }
    }

    Timer {
        interval: Math.round(1000 / Math.max(1, root.fps))
        running: root.kind === "shader" && root.playing && root.visible
        repeat: true
        onTriggered: root.time += interval / 1000
    }
}
