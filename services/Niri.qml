pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Состояние niri из `niri msg --json event-stream`
Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property var layoutNames: []
    property int layoutIdx: 0
    property bool overview: false
    property bool configFailed: false   // последняя загрузка конфига niri не удалась (ConfigLoaded.failed)
    property var casts: []          // демонстрации экрана (niri ≥ 26.04): {stream_id, kind, target, is_active, pid, pw_node_id}

    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null
    readonly property var focusedWindow: Object.values(windows).find(w => w.is_focused) ?? null
    readonly property string layout: (layoutNames[layoutIdx] ?? "").slice(0, 2).toLowerCase()
    readonly property bool urgent: workspaces.some(w => w.is_urgent) || Object.values(windows).some(w => w.is_urgent)

    function windowsOn(wsId) {
        return Object.values(windows).filter(w => w.workspace_id === wsId);
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    // Номер стола относится к монитору, поэтому для стола на другом мониторе сначала focus-monitor.
    // На своём мониторе — без него: focus-monitor переносит курсор в центр монитора, и он уходит
    // с панели (следующая прокрутка колёсиком попала бы уже в окно).
    function focusWorkspaceOn(output, idx) {
        if (!output || focusedWorkspace?.output === output)
            action("focus-workspace", String(idx));
        else
            Quickshell.execDetached(["sh", "-c", 'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"',
                "sh", output, String(idx)]);
    }

    function focusWorkspace(ws) { focusWorkspaceOn(ws.output, ws.idx); }

    // соседний стол (dir: up | down) на мониторе output — для колёсика по панели
    function scrollWorkspace(output, dir) {
        const list = workspaces.filter(w => w.output === output);
        if (!list.length) { action("focus-workspace-" + dir); return; }
        const next = list[list.findIndex(w => w.is_active) + (dir === "up" ? -1 : 1)];
        if (next) focusWorkspaceOn(output, next.idx);
    }

    function handle(ev) {
        if (ev.OverviewOpenedOrClosed) {
            overview = ev.OverviewOpenedOrClosed.is_open;
        } else if (ev.WorkspaceUrgencyChanged) {
            const { id, urgent } = ev.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(w => w.id === id ? Object.assign({}, w, { is_urgent: urgent }) : w);
        } else if (ev.WindowUrgencyChanged) {
            const { id, urgent } = ev.WindowUrgencyChanged;
            if (windows[id]) windows = Object.assign({}, windows, { [id]: Object.assign({}, windows[id], { is_urgent: urgent }) });
        } else if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces.sort((a, b) => a.idx - b.idx);
        } else if (ev.WorkspaceActivated) {
            const { id, focused } = ev.WorkspaceActivated;
            const output = workspaces.find(w => w.id === id)?.output;
            workspaces = workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === output ? w.id === id : w.is_active,
                is_focused: focused ? w.id === id : w.is_focused
            }));
        } else if (ev.WindowsChanged) {
            const map = {};
            for (const w of ev.WindowsChanged.windows) map[w.id] = w;
            windows = map;
        } else if (ev.WindowOpenedOrChanged) {
            const win = ev.WindowOpenedOrChanged.window;
            const map = Object.assign({}, windows);
            if (win.is_focused)
                for (const k in map) map[k] = Object.assign({}, map[k], { is_focused: false });
            map[win.id] = win;
            windows = map;
        } else if (ev.WindowClosed) {
            const map = Object.assign({}, windows);
            delete map[ev.WindowClosed.id];
            windows = map;
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            const map = {};
            for (const k in windows) map[k] = Object.assign({}, windows[k], { is_focused: windows[k].id === id });
            windows = map;
        } else if (ev.ConfigLoaded) {
            configFailed = ev.ConfigLoaded.failed;
        } else if (ev.CastsChanged) {
            casts = ev.CastsChanged.casts;
        } else if (ev.CastStartedOrChanged) {
            const cast = ev.CastStartedOrChanged.cast;
            casts = casts.filter(c => c.stream_id !== cast.stream_id).concat([cast]);
        } else if (ev.CastStopped) {
            casts = casts.filter(c => c.stream_id !== ev.CastStopped.stream_id);
        } else if (ev.KeyboardLayoutsChanged) {
            layoutNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
            layoutIdx = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIdx = ev.KeyboardLayoutSwitched.idx;
        }
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try { root.handle(JSON.parse(line)); } catch (e) { console.warn("niri:", e); }
            }
        }
        onExited: restart.start()
    }

    // если niri перезапустился или поток оборвался — переподключаемся
    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }
}
