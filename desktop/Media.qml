import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs
import qs.home
import qs.services
import "../services/glyphs.js" as G

// Плеер на столе: обложка, трек, прогресс (клик — перемотка) и кнопки ⏮ ⏯ ⏭. Нет плеера — «тишина».
Item {
    id: root

    property var cfg
    property real cw
    property real ch
    property bool editing

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    function fmt(s) {
        if (!(s >= 0) || !isFinite(s)) return "-:--";
        s = Math.floor(s);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {
        interval: 1000
        running: root.player?.isPlaying ?? false
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    T {
        anchors.centerIn: parent
        visible: root.player === null
        text: G.g("music") + " " + I18n.tr("тишина")
        font.family: Theme.iconFont
        color: Theme.gray
    }

    RowLayout {
        anchors.fill: parent
        visible: root.player !== null
        spacing: root.cw

        Rectangle {
            visible: art.status === Image.Ready
            Layout.fillHeight: true
            Layout.preferredWidth: height
            color: Theme.bg1
            Image {
                id: art
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
                sourceSize.height: 256
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            T {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
                text: root.player?.trackTitle || root.player?.identity || ""
            }
            T {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Theme.gray
                text: [root.player?.trackArtist, root.player?.trackAlbum].filter(x => x).join(" — ") || root.player?.identity || ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: (root.player?.lengthSupported ?? false) && root.player.length > 0

                T { text: root.fmt(root.player?.position) + " "; color: Theme.gray }
                T {
                    Layout.fillWidth: true
                    readonly property int n: Math.max(4, Math.floor(width / root.cw))
                    readonly property int done: Math.round(Math.min(1, (root.player?.position ?? 0) / (root.player?.length || 1)) * n)
                    text: "━".repeat(done) + "─".repeat(Math.max(0, n - done))
                    color: Theme.accent
                    clip: true
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.editing && (root.player?.canSeek ?? false)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => root.player.position = root.player.length * mouse.x / width
                    }
                }
                T { text: " " + root.fmt(root.player?.length); color: Theme.gray }
            }

            RowLayout {
                spacing: root.cw
                Repeater {
                    model: [
                        { icon: G.g("prev"), ok: root.player?.canGoPrevious ?? false, run: () => root.player.previous() },
                        { icon: G.g(root.player?.isPlaying ? "pause" : "play"), ok: root.player?.canTogglePlaying ?? false, run: () => root.player.togglePlaying() },
                        { icon: G.g("next"), ok: root.player?.canGoNext ?? false, run: () => root.player.next() }
                    ]
                    Btn {
                        required property var modelData
                        icon: modelData.icon
                        active: modelData.ok
                        onClicked: if (modelData.ok && !root.editing) modelData.run()
                    }
                }
            }
        }
    }
}
