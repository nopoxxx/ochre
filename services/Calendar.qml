pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// События календарей: extras/calendar/ochre-cal.py читает ~/.config/ochre/calendars.conf (.ics, Google и Outlook
// по секретному адресу iCal, CalDAV) и пишет ~/.cache/ochre/calendar.json, сервис его читает. Обновление — раз в
// shell.calendar.refresh минут, при правке calendars.conf и по IPC. Напоминания — за shell.calendar.remind минут.
//   qs ipc call calendar refresh | get
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/extras/calendar/ochre-cal.py"
    readonly property string conf: Quickshell.env("HOME") + "/.config/ochre/calendars.conf"
    readonly property string cache: Quickshell.env("HOME") + "/.cache/ochre/calendar.json"
    readonly property int days: Settings.get("shell.calendar.days")
    readonly property int remind: Settings.get("shell.calendar.remind")

    property var events: []         // [{ id, src, cal, title, start: Date, end: Date, allDay, location, link }]
    property var sources: []        // [{ name, error, count }]
    property var byDay: ({})        // "y-m-d" → число событий
    property string error: ""
    property bool loading: false
    property date updated
    property date now: new Date()
    property var reminded: ({})

    readonly property bool configured: sources.length > 0
    readonly property var failed: sources.filter(s => s.error)
    readonly property var upcoming: events.filter(e => e.end > now && e.start < new Date(now.getTime() + days * 86400000))
    readonly property var next: upcoming.find(e => !e.allDay && e.start - now < 12 * 3600000) ?? null

    // «2026-10-23» — местная дата (new Date() прочла бы её как UTC), «2026-10-23T10:00:00» — местное время
    function parse(s) {
        const m = s.match(/^(\d+)-(\d+)-(\d+)(?:T(\d+):(\d+):(\d+))?$/);
        return m ? new Date(+m[1], +m[2] - 1, +m[3], +(m[4] ?? 0), +(m[5] ?? 0), +(m[6] ?? 0)) : new Date(s);
    }

    function dayKey(d) { return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate(); }
    function count(y, m, d) { return byDay[y + "-" + m + "-" + d] ?? 0; }

    function on(day) {
        const a = new Date(day.getFullYear(), day.getMonth(), day.getDate()), b = new Date(a.getTime() + 86400000);
        return events.filter(e => e.start < b && e.end > a || e.start >= a && e.start < b);
    }

    function sameDay(a, b) { return dayKey(a) === dayKey(b); }

    // «10:30–11:00», «весь день»; с днём — «пн 21 10:30» для событий не сегодня
    function when(e, withDay) {
        const loc = I18n.locale;
        const day = withDay && !sameDay(e.start, now) ? loc.toString(e.start, "ddd d") + " " : "";
        if (e.allDay) return day + I18n.tr("весь день");
        const t = loc.toString(e.start, "HH:mm");
        return day + t + (e.end > e.start && sameDay(e.start, e.end) ? "–" + loc.toString(e.end, "HH:mm") : "");
    }

    // «через 15м», «через 2ч 5м», «идёт»
    function until(e) {
        const min = Math.ceil((e.start - now) / 60000);
        if (min <= 0) return I18n.tr("идёт");
        if (min < 60) return I18n.tr("через %1м", min);
        return I18n.tr("через %1ч %2м", Math.floor(min / 60), min % 60);
    }

    function errorText() {
        if (error === "deps") return I18n.tr("нужны python-icalendar и python-dateutil");
        if (error) return error;
        return failed.map(s => s.name + ": " + s.error).join(" · ");
    }

    function open(e) {
        if (e.link) Quickshell.execDetached(["xdg-open", e.link]);
    }

    // init создаёт calendars.conf с примерами — после этого FileView начинает следить за ним
    function edit() {
        initProc.running = true;
    }

    function login() {
        Term.float(["python3", script, "login"]);
    }

    function refresh() {
        if (sync.running) return;
        loading = true;
        sync.running = true;
    }

    function load(text) {
        let r;
        try { r = JSON.parse(text); } catch (e) { return; }
        const list = (r.events ?? []).map(e => Object.assign({}, e, { start: parse(e.start), end: parse(e.end) }));
        const map = {};
        for (const e of list) {
            const last = e.end > e.start ? new Date(e.end.getTime() - 1) : e.start;
            const d = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate());
            for (let i = 0; i < 62 && d <= last; i++, d.setDate(d.getDate() + 1)) {
                const k = dayKey(d);
                map[k] = (map[k] ?? 0) + 1;
            }
        }
        events = list;
        byDay = map;
        sources = r.sources ?? [];
        error = r.error ?? "";
        updated = parse(r.updated ?? "");
    }

    function check() {
        now = new Date();
        if (remind <= 0) return;
        const seen = Object.assign({}, reminded);
        let changed = false;
        for (const e of events) {
            const left = e.start - now;
            if (e.allDay || left <= 0 || left > remind * 60000 || seen[e.id]) continue;
            seen[e.id] = true;
            changed = true;
            const body = [when(e, false), e.location].filter(x => x).join(" · ");
            Quickshell.execDetached(["sh", "-c",
                'if [ -n "$3" ]; then a=$(notify-send -a ochre -i x-office-calendar -A open="$4" "$1" "$2"); [ "$a" = open ] && xdg-open "$3";'
                + ' else notify-send -a ochre -i x-office-calendar "$1" "$2"; fi',
                "sh", until(e) + " · " + (e.title || I18n.tr("без названия")), body, e.link, I18n.tr("открыть")]);
        }
        if (changed) reminded = seen;
    }

    Process {
        id: sync
        command: ["python3", root.script, "sync", "--days", "31"]
        stderr: StdioCollector { id: err }
        onExited: code => {
            root.loading = false;
            if (code !== 0) root.error = err.text.trim().split("\n").pop() || "ochre-cal: " + code;
            cacheFile.reload();
        }
    }

    FileView {
        id: cacheFile
        path: root.cache
        printErrors: false
        onLoaded: root.load(text())
    }

    // правка calendars.conf — обновить, когда редактор допишет файл
    Process {
        id: initProc
        command: ["python3", root.script, "init"]
        onExited: {
            confFile.reload();
            Term.edit(root.conf);
        }
    }

    FileView {
        id: confFile
        path: root.conf
        watchChanges: true
        printErrors: false
        onFileChanged: retry.restart()
    }

    Timer { id: retry; interval: 1500; onTriggered: root.refresh() }

    Timer {
        interval: Settings.get("shell.calendar.refresh") * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    IpcHandler {
        target: "calendar"
        function refresh(): void { root.refresh(); }
        function get(): string {
            if (!root.configured) return I18n.tr("календари не подключены: %1", root.conf);
            const lines = root.upcoming.map(e => root.when(e, true) + "  " + e.title + "  [" + e.cal + "]");
            const err = root.errorText();
            return (lines.length ? lines.join("\n") : I18n.tr("ближайших событий нет")) + (err ? "\n" + err : "");
        }
    }
}
