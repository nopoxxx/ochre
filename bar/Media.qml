import Quickshell.Services.Mpris
import QtQuick
import qs
import qs.bar
import qs.services

// ♪ artist – title ▂▅▇▃ — клик: пауза, правый: следующий, средний: предыдущий; полоски — cava (shell.bar.viz)
Seg {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property string track: {
        if (!player) return "";
        const s = (player.trackArtist ? player.trackArtist + " – " : "") + (player.trackTitle || player.identity || "");
        return s.length > 40 ? s.slice(0, 39) + "…" : s;
    }

    available: player !== null && track !== ""
    label: player?.isPlaying ? "♪" : "‖"
    value: track + (player?.isPlaying && Cava.levels.length && Settings.get("shell.bar.viz") ? " " + Cava.bars(8) : "")
    valueColor: player?.isPlaying ? Theme.fg : Theme.gray

    onLeftClicked: if (player?.canTogglePlaying) player.togglePlaying()
    onRightClicked: if (player?.canGoNext) player.next()
    onMiddleClicked: if (player?.canGoPrevious) player.previous()
}
