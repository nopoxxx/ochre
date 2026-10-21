import QtQuick
import QtMultimedia

// Видеообои для WallLayer: по кругу, без звука. Отдельным файлом — без qt6-multimedia не грузится только он,
// а WallLayer показывает вместо видео постер.
Item {
    id: root

    property string path
    property int fillMode: VideoOutput.PreserveAspectCrop
    property bool playing: true
    property bool ready: false
    readonly property bool failed: player.error !== MediaPlayer.NoError

    onPathChanged: ready = false
    onPlayingChanged: sync()

    function sync() {
        if (!path) return;
        if (playing || !ready) player.play();
        else player.pause();
    }

    MediaPlayer {
        id: player
        source: root.path ? "file://" + encodeURI(root.path) : ""
        loops: MediaPlayer.Infinite
        videoOutput: out
        onSourceChanged: root.sync()
        // на паузе первый кадр всё равно нужен: играем до него и останавливаемся
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.BufferingMedia) {
            if (!root.ready) frame.restart();
        }
    }

    // первый кадр доходит до VideoOutput чуть позже статуса — без паузы переход открыл бы пустоту
    Timer {
        id: frame
        interval: 80
        onTriggered: {
            root.ready = true;
            root.sync();
        }
    }

    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: root.fillMode
    }
}
