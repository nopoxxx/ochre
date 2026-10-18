pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "settings.js" as S

// Текст песни для секции «сейчас играет» в home: LRCLIB (lrclib.net, без ключа) — синхронный LRC, иначе обычный текст.
// Ищет, только пока меню home открыто и секция видна (shell.home.lyrics): /api/get по артисту, названию и длительности,
// не нашёл — /api/search. Ответ — в ~/.cache/ochre/lyrics/<md5>.json (и «не найдено» тоже); ошибка сети не кэшируется.
// Текущая строка — по позиции плеера: опрашивается раз в полсекунды, пока играет.
Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string title: player?.trackTitle ?? ""
    readonly property string key: artist && title ? artist + "\n" + title : ""
    readonly property bool wanted: Settings.get("shell.home.lyrics") && Home.open && !Settings.greeterMode
        && S.zoneOf(Settings.get("shell.home.layout"), "media", "shell.home.layout") !== "off"
    readonly property string dir: Quickshell.env("HOME") + "/.cache/ochre/lyrics"

    property string loadedKey: ""
    property bool loading: false
    property var lines: []           // [{t: секунды, text}] — синхронный текст
    property string plain: ""        // если синхронного нет
    property bool instrumental: false
    property real position: 0

    readonly property int index: {
        let i = -1;
        for (let j = 0; j < lines.length && lines[j].t <= position + 0.3; j++) i = j;
        return i;
    }
    readonly property string current: index >= 0 ? lines[index].text : ""
    readonly property string next: lines[index + 1]?.text ?? ""

    // «[01:23.45] текст» → {t, text}; несколько меток в строке — по записи на каждую
    function parseLrc(lrc) {
        const out = [];
        for (const raw of String(lrc).split("\n")) {
            const tags = raw.match(/\[\d+:\d+(?:[.:]\d+)?\]/g);
            if (!tags) continue;
            const text = raw.replace(/\[\d+:\d+(?:[.:]\d+)?\]/g, "").trim();
            for (const tag of tags) {
                const m = tag.match(/\[(\d+):(\d+)(?:[.:](\d+))?\]/);
                out.push({ t: +m[1] * 60 + +m[2] + (m[3] ? +("0." + m[3]) : 0), text });
            }
        }
        return out.sort((a, b) => a.t - b.t);
    }

    function apply(json) {
        let r = null;
        try { r = JSON.parse(json); } catch (e) {}
        // /api/search отдаёт массив: синхронный текст, ближайший по длительности (там и концертные версии), иначе первый
        if (Array.isArray(r)) {
            const len = player?.lengthSupported ? player.length : 0;
            const synced = r.filter(x => x.syncedLyrics);
            r = synced.sort((a, b) => Math.abs((a.duration ?? 0) - len) - Math.abs((b.duration ?? 0) - len))[0] ?? r[0] ?? null;
        }
        lines = r?.syncedLyrics ? parseLrc(r.syncedLyrics) : [];
        plain = !lines.length && r?.plainLyrics ? r.plainLyrics : "";
        instrumental = r?.instrumental === true;
    }

    function fetch() {
        if (!wanted || !key || key === loadedKey || fetcher.running) return;
        loadedKey = key;
        lines = [];
        plain = "";
        instrumental = false;
        loading = true;
        const len = Math.round(player?.lengthSupported ? player.length : 0);
        fetcher.command = ["sh", "-c", `
            dir=$1 artist=$2 title=$3 album=$4 len=$5
            f="$dir/$(printf '%s\\n%s' "$artist" "$title" | md5sum | cut -c1-32).json"
            [ -s "$f" ] && exec cat "$f"
            mkdir -p "$dir"
            ua="ochre (https://github.com/nopoxxx/ochre)"
            set -- --data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title"
            [ -n "$album" ] && set -- "$@" --data-urlencode "album_name=$album"
            [ "$len" -gt 0 ] && set -- "$@" --data-urlencode "duration=$len"
            r=$(curl -sfG --max-time 8 -A "$ua" https://lrclib.net/api/get "$@"); code=$?
            if [ $code = 22 ]; then   # 404 — точного совпадения нет, ищем
                r=$(curl -sfG --max-time 8 -A "$ua" https://lrclib.net/api/search \\
                    --data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title"); code=$?
            fi
            [ $code = 0 ] || exit 1   # сеть — не кэшируем, попробуем в следующий раз
            printf '%s' "$r" > "$f"; printf '%s' "$r"`,
            "sh", dir, artist, title, player?.trackAlbum ?? "", String(len)];
        fetcher.running = true;
    }

    onKeyChanged: fetch()
    onWantedChanged: fetch()

    Process {
        id: fetcher
        stdout: StdioCollector { id: out }
        onExited: code => {
            root.loading = false;
            if (code === 0) root.apply(out.text);
            else root.loadedKey = "";      // повторить при следующем открытии
            // пока искали, сменился трек
            if (root.key !== root.loadedKey) Qt.callLater(root.fetch);
        }
    }

    Timer {
        running: root.wanted && root.lines.length > 0 && (root.player?.isPlaying ?? false)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.player.positionChanged();
            root.position = root.player.position;
        }
    }
}
