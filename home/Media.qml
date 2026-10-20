import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Плеер: обложка, трек, прогресс (клик — перемотка), кнопки ⏮ ⏯ ⏭. Плееров несколько — ‹ › переключают.
// ←→ — выбор кнопки, ↵ — нажать. Нет плееров — секции не видно.
Section {
    id: sec

    title: I18n.tr("сейчас играет")

    readonly property var players: Mpris.players.values
    property int chosen: -1        // -1 — тот, что играет
    readonly property var player: players[chosen] ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    available: player !== null
    count: buttons.length

    readonly property var buttons: [
        { icon: G.g("prev"), ok: player?.canGoPrevious ?? false, run: () => player.previous() },
        { icon: G.g(player?.isPlaying ? "pause" : "play"), ok: player?.canTogglePlaying ?? false, run: () => player.togglePlaying() },
        { icon: G.g("next"), ok: player?.canGoNext ?? false, run: () => player.next() },
        { icon: G.g("ear"), ok: true, on: SongRec.busy, run: () => SongRec.recognize(false) }
    ].concat(players.length > 1 ? [{ text: "‹ " + (players.indexOf(player) + 1) + "/" + players.length + " ›", ok: true, run: () => sec.cycle(1) }] : [])

    function cycle(d) {
        const i = players.indexOf(player);
        chosen = (i + d + players.length) % players.length;
    }

    function fmt(s) {
        if (!(s >= 0) || !isFinite(s)) return "-:--";
        s = Math.floor(s);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) cur = Math.max(0, cur - 1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) cur = Math.min(count - 1, cur + 1);
        else return false;
        return true;
    }

    function activate(i) {
        const b = buttons[i];
        if (b?.ok) b.run();
    }

    // позицию MPRIS не присылает сам — пока играет, просим обновить раз в секунду
    Timer {
        interval: 1000
        running: sec.player?.isPlaying ?? false
        repeat: true
        onTriggered: sec.player.positionChanged()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.pad

        Rectangle {
            visible: art.status === Image.Ready
            implicitWidth: implicitHeight
            implicitHeight: info.implicitHeight
            color: Theme.bg1
            Image {
                id: art
                anchors.fill: parent
                source: sec.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 128
            }
        }

        ColumnLayout {
            id: info
            Layout.fillWidth: true
            spacing: 0

            T {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
                text: sec.player?.trackTitle || sec.player?.identity || ""
            }
            T {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Theme.gray
                text: [sec.player?.trackArtist, sec.player?.trackAlbum].filter(x => x).join(" — ") || sec.player?.identity || ""
            }

            // 1:42 ━━━━━━━━──────── 5:37
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: (sec.player?.lengthSupported ?? false) && sec.player.length > 0

                T { text: sec.fmt(sec.player?.position) + " "; color: Theme.gray }
                T {
                    id: track
                    Layout.fillWidth: true
                    readonly property int n: Math.max(4, Math.floor(width / sec.panel.cell.advanceWidth))
                    readonly property int done: Math.round(Math.min(1, (sec.player?.position ?? 0) / (sec.player?.length || 1)) * n)
                    text: "━".repeat(done) + "─".repeat(Math.max(0, n - done))
                    color: Theme.accent
                    clip: true
                    MouseArea {
                        anchors.fill: parent
                        enabled: sec.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => sec.player.position = sec.player.length * mouse.x / width
                    }
                }
                T { text: " " + sec.fmt(sec.player?.length); color: Theme.gray }
            }

            // текст песни: текущая строка и следующая (services/Lyrics.qml)
            T {
                Layout.fillWidth: true
                visible: Settings.get("shell.home.lyrics") && Lyrics.key !== "" && sec.player === Lyrics.player && text !== ""
                elide: Text.ElideRight
                text: Lyrics.lines.length ? (Lyrics.current || "♪") : Lyrics.loading ? I18n.tr("♪ ищу текст…")
                    : Lyrics.instrumental ? I18n.tr("♪ инструментал") : Lyrics.plain ? I18n.tr("♪ текст без разметки времени") : ""
                color: Lyrics.lines.length ? Theme.accent : Theme.gray
                font.bold: Lyrics.lines.length > 0
            }
            T {
                Layout.fillWidth: true
                visible: Settings.get("shell.home.lyrics") && Lyrics.lines.length > 0 && Lyrics.next !== "" && sec.player === Lyrics.player
                elide: Text.ElideRight
                text: Lyrics.next
                color: Theme.gray
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: sec.panel.cell.advanceWidth
                Repeater {
                    model: sec.buttons
                    Btn {
                        required property var modelData
                        required property int index
                        icon: modelData.icon ?? ""
                        text: modelData.text ?? ""
                        active: modelData.ok
                        on: modelData.on ?? false
                        current: sec.isCur(index)
                        onClicked: { sec.pick(index); sec.activate(index); }
                    }
                }
                // ▁▃▅▇ на остаток строки — cava (shell.home.viz)
                T {
                    Layout.fillWidth: true
                    visible: Cava.levels.length > 0 && (sec.player?.isPlaying ?? false)
                    readonly property int n: Math.max(4, Math.floor(width / sec.panel.cell.advanceWidth))
                    text: Cava.bars(n)
                    color: Theme.accent
                    clip: true
                }
            }
        }
    }
}
