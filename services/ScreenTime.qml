pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "screentime.js" as ST

// Время за экраном: сколько окно каждого app_id было в фокусе. Считается по смене фокуса niri (Niri.focusedWindow),
// без опроса; не идёт на блокировке (locked ставит LockScreen) и после 5 мин бездействия (минуты простоя не в счёт).
// ~/.local/state/ochre/screentime.json — {дата: {app_id: секунды}}, последние 7 дней.
//   qs ipc call screentime get
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/ochre/screentime.json"
    readonly property int idleSec: 300
    readonly property int keepDays: 7

    property var days: ({})
    property bool loaded: false
    property bool locked: false
    property string app: ""
    property double since: 0
    property bool active: false
    property var recent: []          // отрезки последних idleSec: при простое снимаются
    property string todayKey: ST.dayKey(Date.now())

    readonly property bool counting: loaded && !locked && !idle.isIdle && app !== ""
    readonly property string focusedApp: Niri.focusedWindow?.app_id ?? ""
    readonly property var today: days[todayKey] ?? ({})
    readonly property int todayTotal: ST.total(today)

    function top(n) { return ST.top(today, n); }
    function fmt(sec) { return ST.fmt(sec); }

    function flush(until) {
        const now = Date.now();
        if (until === undefined && now - since > 180000) until = since;
        const end = Math.min(until ?? now, now);
        if (active && end > since) {
            days = ST.add(days, app, since, end);
            recent = recent.filter(r => r.to > now - idleSec * 1000).concat([{ app, from: since, to: end }]);
        }
        since = now;
        active = counting;
        todayKey = ST.dayKey(now);
        save.restart();
    }

    function update() {
        flush();
        app = focusedApp;
    }

    onFocusedAppChanged: update()
    onCountingChanged: {
        flush();
        if (idle.isIdle) days = ST.undo(days, recent, Date.now() - idleSec * 1000);
        recent = [];
    }

    IdleMonitor {
        id: idle
        timeout: root.idleSec
        respectInhibitors: true
    }

    // раз в минуту — в файл; разрыв больше трёх минут без отметки — был сон, его не считаем (flush)
    Timer {
        interval: 60000
        running: root.counting
        repeat: true
        onTriggered: root.flush()
    }

    Timer {
        id: save
        interval: 2000
        onTriggered: {
            if (!root.loaded || Settings.greeterMode) return;
            root.days = ST.prune(root.days, root.keepDays, Date.now());
            file.setText(JSON.stringify(root.days));
        }
    }

    FileView {
        id: file
        path: root.path
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { root.days = JSON.parse(text()) ?? {}; } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/ochre"]);
        app = focusedApp;
    }
    Component.onDestruction: {
        flush();
        if (loaded && !Settings.greeterMode) file.setText(JSON.stringify(days));
    }

    IpcHandler {
        target: "screentime"
        function get(): string {
            root.flush();
            return [I18n.tr("сегодня") + " " + root.fmt(root.todayTotal)]
                .concat(root.top(100).map(e => root.fmt(e.sec).padStart(6) + "  " + e.app)).join("\n");
        }
    }
}
