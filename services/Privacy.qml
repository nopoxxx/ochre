pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Кто сейчас слушает микрофон и кто показывает экран — для модуля панели privacy (bar/Privacy.qml).
// Микрофон — из PipeWire без опроса: поток записи (Stream/Input/Audio), подключённый к микрофону (Audio/Source),
// который не выключен. Запись звука системы (монитор приёмника) и индикаторы уровня (pavucontrol) не в счёт.
// Экран — из niri (`Niri.casts`): кто смотрит — узел PipeWire, подключённый к потоку демонстрации,
// у wlr-screencopy — окно с тем же pid, иначе имя процесса (/proc/<pid>/comm).
// IPC: `privacy get` — текущее состояние, `privacy dump` — все потоки (отладка).
Singleton {
    id: root

    // без трекера у узлов нет audio.muted, а свойства могут прийти позже узла
    PwObjectTracker { objects: Pipewire.nodes.values }

    function prop(node, key) {
        const v = node?.properties?.[key];
        return v === undefined || v === null ? "" : String(v);
    }

    function appName(node) {
        return prop(node, "application.name") || prop(node, "application.process.binary")
            || node?.description || node?.nickname || node?.name || "?";
    }

    function isMeter(node) {
        return prop(node, "stream.monitor") === "true" || prop(node, "node.passive") === "true"
            || /pavucontrol|peak detect|wireplumber|plasma-pa/i.test(appName(node) + " " + prop(node, "media.name"));
    }

    function unique(list) {
        return list.filter((x, i) => list.indexOf(x) === i);
    }

    readonly property var micApps: {
        const names = [];
        for (const g of Pipewire.linkGroups.values) {
            const src = g.source, dst = g.target;
            if (prop(dst, "media.class") !== "Stream/Input/Audio" || prop(src, "media.class") !== "Audio/Source") continue;
            if (src.audio?.muted || isMeter(dst)) continue;
            names.push(appName(dst));
        }
        return unique(names);
    }

    readonly property var screenApps: {
        const names = [];
        for (const c of Niri.casts) {
            let found = false;
            if (c.pw_node_id !== null && c.pw_node_id !== undefined)
                for (const g of Pipewire.linkGroups.values)
                    if (g.source?.id === c.pw_node_id) { names.push(appName(g.target)); found = true; }
            if (!found && c.pid) {
                const w = Object.values(Niri.windows).find(w => w.pid === c.pid);
                const n = w?.app_id || comms[c.pid];
                if (n) { names.push(n); found = true; }
            }
            if (!found) names.push("?");
        }
        return unique(names);
    }

    // pid → имя процесса для демонстраций без окна (wf-recorder, wl-screenrec)
    property var comms: ({})

    Connections {
        target: Niri
        function onCastsChanged() {
            const pids = Niri.casts.map(c => c.pid).filter(p => p && !(p in root.comms));
            if (!pids.length || comm.running) return;
            comm.command = ["sh", "-c", 'for p; do printf "%s %s\\n" "$p" "$(cat /proc/$p/comm 2>/dev/null)"; done', "sh"].concat(pids.map(String));
            comm.running = true;
        }
    }

    Process {
        id: comm
        stdout: SplitParser {
            onRead: line => {
                const [pid, name] = line.split(" ");
                if (name) root.comms = Object.assign({}, root.comms, { [pid]: name });
            }
        }
    }

    readonly property bool active: micApps.length > 0 || screenApps.length > 0

    IpcHandler {
        target: "privacy"

        function get(): string {
            return "mic: " + root.micApps.join(", ") + "\ncast: " + root.screenApps.join(", ");
        }

        function dump(): string {
            const lines = [];
            for (const n of Pipewire.nodes.values) {
                const mc = root.prop(n, "media.class");
                if (mc.indexOf("Stream/") !== 0 && mc.indexOf("Video") < 0) continue;
                lines.push(`#${n.id} ${mc} | ${n.name} | app=${root.appName(n)}${root.isMeter(n) ? " | meter" : ""}`);
            }
            for (const g of Pipewire.linkGroups.values)
                lines.push(`link #${g.source?.id} ${g.source?.name} → #${g.target?.id} ${g.target?.name}`);
            lines.push("casts: " + JSON.stringify(Niri.casts));
            return lines.join("\n");
        }
    }
}
