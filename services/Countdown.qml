pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Таймер обратного отсчёта: модуль панели timer (bar/Countdown.qml), запуск из меню «timer 25m чай» и по IPC.
// Конец отсчёта хранится временем (endsAt), а не остатком — переживает перезапуск shell и сон: состояние в
// ~/.local/state/ochre/timer.json. Время вышло, пока shell не работал, — уведомление при запуске.
//   qs ipc call timer start "25m чай" | pause | stop | get
Singleton {
    id: root

    property double endsAt: 0       // мс, когда закончится; 0 — не идёт (или на паузе)
    property int pausedLeft: 0      // секунд осталось на паузе; 0 — не на паузе
    property int total: 0
    property string label: ""
    property int left: 0            // секунд до конца — обновляется раз в секунду

    readonly property bool paused: pausedLeft > 0
    readonly property bool active: endsAt > 0 || paused
    readonly property string path: Quickshell.env("HOME") + "/.local/state/ochre/timer.json"

    // «25m», «1h30m», «90s», «5:00», «1.5h», «25» (минуты) → секунды; не разобрали — 0
    function parse(spec) {
        const s = String(spec).trim().toLowerCase().replace(",", ".");
        let m = s.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
        if (m) return m[3] !== undefined ? (+m[1] * 3600 + +m[2] * 60 + +m[3]) : (+m[1] * 60 + +m[2]);
        if (/^\d+(\.\d+)?$/.test(s)) return Math.round(parseFloat(s) * 60);
        const units = { h: 3600, ч: 3600, m: 60, м: 60, min: 60, мин: 60, s: 1, с: 1, sec: 1, сек: 1 };
        let sec = 0, rest = s;
        const re = /^(\d+(?:\.\d+)?)\s*(h|ч|min|мин|m|м|sec|сек|s|с)/;
        while (rest) {
            m = rest.match(re);
            if (!m) return 0;
            sec += parseFloat(m[1]) * units[m[2]];
            rest = rest.slice(m[0].length).trim();
        }
        return Math.round(sec);
    }

    // «25m чай» → {sec, label}: длительность — первое слово (или «1h 30m» — несколько)
    function parseSpec(text) {
        const words = String(text).trim().split(/\s+/).filter(w => w);
        for (let n = words.length; n > 0; n--) {
            const sec = parse(words.slice(0, n).join(" "));
            if (sec > 0) return { sec: Math.min(sec, 99 * 3600), label: words.slice(n).join(" ") };
        }
        return null;
    }

    function fmt(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        const two = x => String(x).padStart(2, "0");
        return (h ? h + ":" + two(m) : two(m)) + ":" + two(s);
    }

    function start(sec, text) {
        if (!(sec > 0)) return;
        total = sec;
        label = text ?? "";
        pausedLeft = 0;
        endsAt = Date.now() + sec * 1000;
        update();
        save();
    }

    function toggle() {
        if (!active) return;
        if (paused) { endsAt = Date.now() + pausedLeft * 1000; pausedLeft = 0; }
        else { pausedLeft = Math.max(1, left); endsAt = 0; }
        update();
        save();
    }

    // ±секунды к остатку (колёсико на панели)
    function add(sec) {
        if (!active) return;
        if (paused) pausedLeft = Math.max(1, pausedLeft + sec);
        else endsAt = Math.max(Date.now() + 1000, endsAt + sec * 1000);
        total = Math.max(total, paused ? pausedLeft : Math.ceil((endsAt - Date.now()) / 1000));
        update();
        save();
    }

    function stop() {
        endsAt = 0;
        pausedLeft = 0;
        left = 0;
        save();
    }

    function finish(late) {
        const what = label || "таймер";
        stop();
        Quickshell.execDetached(["sh", "-c", `
            notify-send -a ochre -u critical -i alarm-symbolic "⏱ $1" "$2"
            f=/usr/share/sounds/freedesktop/stereo/complete.oga
            [ -f "$f" ] && command -v pw-play >/dev/null && pw-play "$f"`,
            "sh", what, late ? "время вышло, пока shell не работал" : "прошло " + fmt(total)]);
    }

    function update() {
        left = paused ? pausedLeft : endsAt > 0 ? Math.max(0, Math.ceil((endsAt - Date.now()) / 1000)) : 0;
        if (endsAt > 0 && left === 0) finish(false);
    }

    Timer {
        running: root.endsAt > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }

    // ── состояние ──
    property bool loaded: false

    function save() {
        if (!loaded || Settings.greeterMode) return;
        file.setText(JSON.stringify({ endsAt, pausedLeft, total, label }));
    }

    FileView {
        id: file
        path: root.path
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.total = d.total ?? 0;
                root.label = d.label ?? "";
                root.pausedLeft = d.pausedLeft ?? 0;
                root.endsAt = d.endsAt ?? 0;
            } catch (e) {}
            root.loaded = true;
            if (root.endsAt > 0 && root.endsAt <= Date.now()) root.finish(true);
            else root.update();
        }
        onLoadFailed: root.loaded = true
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/ochre"])

    IpcHandler {
        target: "timer"
        function start(spec: string): string {
            const p = root.parseSpec(spec);
            if (!p) return "не понял длительность: 25m, 1h30m, 90s, 5:00";
            root.start(p.sec, p.label);
            return root.fmt(p.sec) + (p.label ? " " + p.label : "");
        }
        function pause(): void { root.toggle(); }
        function stop(): void { root.stop(); }
        function get(): string { return root.active ? root.fmt(root.left) + (root.paused ? " (пауза)" : "") + (root.label ? " " + root.label : "") : "нет"; }
    }
}
