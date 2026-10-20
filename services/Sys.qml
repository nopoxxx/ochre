pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Метрики системы из /proc и /sys. Читаются, только пока их кто-то показывает: модуль ставит внутрь
// SysUse { metrics: ["cpu", "mem"] } — метрики cpu, mem, net, gpu, temp; никого нет — таймер стоит.
Singleton {
    id: root

    property int cpu: 0              // %
    property var cpuHistory: []      // последние значения cpu для графика
    property real memUsed: 0         // GiB
    property real memTotal: 0        // GiB
    property real rx: 0              // байт/с
    property real tx: 0
    property int gpu: -1             // %; -1 — датчика нет
    property int gpuTemp: -1         // °C
    property int cpuTemp: -1
    property string user: Quickshell.env("USER") ?? "user"
    property string host: hostFile.text().trim()
    property string kernel: kernelFile.text().trim()

    readonly property int interval: 2000
    property var _prevCpu: null
    property var _prevNet: null

    // подписчики по метрикам: { cpu: 2, net: 1 }; меняется только копией — иначе привязки не увидят
    property var _use: ({})
    readonly property bool active: Object.keys(_use).some(m => _use[m] > 0)
    function use(metrics, d) {
        const u = Object.assign({}, _use);
        for (const m of metrics) u[m] = Math.max(0, (u[m] ?? 0) + d);
        _use = u;
    }
    function wanted(m) { return (_use[m] ?? 0) > 0; }

    function fmtRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + "M";
        return Math.round(b / 1024) + "K";
    }

    FileView {
        id: hostFile
        path: "/etc/hostname"
    }

    FileView {
        id: kernelFile
        path: "/proc/sys/kernel/osrelease"
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._prevCpu) {
                const dt = total - root._prevCpu.total;
                if (dt > 0) {
                    root.cpu = Math.round(100 * (1 - (idle - root._prevCpu.idle) / dt));
                    root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-8);
                }
            }
            root._prevCpu = { idle, total };
        }
    }

    FileView {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const get = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]);
            const total = get("MemTotal"), avail = get("MemAvailable");
            root.memTotal = total / 1048576;
            root.memUsed = (total - avail) / 1048576;
        }
    }

    // сумма по всем интерфейсам, кроме lo
    FileView {
        id: net
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n").slice(2)) {
                const [iface, rest] = line.split(":");
                if (!rest || iface.trim() === "lo") continue;
                const f = rest.trim().split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now();
            if (root._prevNet) {
                const dt = (now - root._prevNet.t) / 1000;
                if (dt > 0) {
                    root.rx = Math.max(0, (rx - root._prevNet.rx) / dt);
                    root.tx = Math.max(0, (tx - root._prevNet.tx) / dt);
                }
            }
            root._prevNet = { rx, tx, t: now };
        }
    }

    // пути к датчикам ищем один раз при старте
    property string gpuBusyPath: ""
    property string gpuTempPath: ""
    property string cpuTempPath: ""

    Process {
        running: true
        command: ["sh", "-c", `
            for d in /sys/class/drm/card*/device; do
                [ -r "$d/gpu_busy_percent" ] && { echo "gpu $d/gpu_busy_percent"; break; }
            done
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in
                    k10temp|coretemp|zenpower) echo "cpu $h/temp1_input" ;;
                    amdgpu) echo "gputemp $h/temp1_input" ;;
                esac
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    const [kind, path] = line.split(" ");
                    if (kind === "gpu") root.gpuBusyPath = path;
                    else if (kind === "gputemp" && !root.gpuTempPath) root.gpuTempPath = path;
                    else if (kind === "cpu" && !root.cpuTempPath) root.cpuTempPath = path;
                }
            }
        }
    }

    FileView {
        id: gpuBusy
        path: root.gpuBusyPath
        onLoaded: root.gpu = parseInt(text())
    }

    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        onLoaded: root.gpuTemp = Math.round(parseInt(text()) / 1000)
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        onLoaded: root.cpuTemp = Math.round(parseInt(text()) / 1000)
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // прошлые отсчёты сбрасываются, пока метрику не смотрят: после паузы первая разница была бы средней за всё время
            if (root.wanted("cpu")) stat.reload(); else root._prevCpu = null;
            if (root.wanted("mem")) mem.reload();
            if (root.wanted("net")) net.reload(); else root._prevNet = null;
            if (root.wanted("gpu") && root.gpuBusyPath) gpuBusy.reload();
            if ((root.wanted("gpu") || root.wanted("temp")) && root.gpuTempPath) gpuTempFile.reload();
            if (root.wanted("temp") && root.cpuTempPath) cpuTempFile.reload();
        }
    }
    onActiveChanged: if (!active) { _prevCpu = null; _prevNet = null; }
}
