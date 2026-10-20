import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/settings.js" as S

// Мониторы: карта расположения и параметры выбранного выхода.
// Изменения применяются сразу (через ochre/displays.kdl), но 15 секунд ждут подтверждения —
// без него откатываются, даже если окно закрыто. Как в GNOME: защита от чёрного экрана.
//   qs ipc call displays toggle
Scope {
    id: root

    property bool open: false

    // ── ожидание подтверждения ──
    property var snapshot: null       // niri.out.* до первого неподтверждённого изменения
    property int remaining: 0
    readonly property bool pending: snapshot !== null

    function begin() {
        if (!pending) snapshot = Settings.snapshotPrefix("niri.out.");
        remaining = 15;
        countdown.restart();
    }

    function confirm() {
        snapshot = null;
        countdown.stop();
    }

    function revert() {
        if (!pending) return;
        Settings.replacePrefix("niri.out.", snapshot);
        snapshot = null;
        countdown.stop();
        Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Мониторы"), I18n.tr("Изменения не подтверждены — вернул как было")]);
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0) root.revert();
        }
    }

    // ── значения: заданное вручную или текущее состояние niri ──

    function key(o, prop) { return "niri.out." + o.name + "." + prop; }

    function val(o, prop) {
        const k = key(o, prop);
        if (k in Settings.values) return Settings.values[k];
        switch (prop) {
        case "enabled": return o.enabled;
        case "mode": return o.mode;
        case "scale": return o.scale;
        case "transform": return o.transform;
        case "vrr": return o.vrr;
        case "x": return o.x;
        case "y": return o.y;
        case "place": return "auto";
        case "primary": return false;
        }
        return undefined;
    }

    function rect(o) {
        if (!val(o, "enabled")) return null;
        const s = S.logicalSize(val(o, "mode"), val(o, "scale"), val(o, "transform"));
        return { x: val(o, "x"), y: val(o, "y"), w: s.w, h: s.h };
    }

    function byName(n) { return Settings.outputs.find(o => o.name === n) ?? null; }

    // записать координату явно, даже если она совпадает с текущей: в displays.kdl попадает только заданное
    function pin(o, prop, v) {
        if (!(key(o, prop) in Settings.values) || Settings.values[key(o, prop)] !== v) Settings.set(key(o, prop), v);
    }

    // «right:DP-1» → координаты рядом с DP-1; повторяем, чтобы цепочки отношений сошлись.
    // Опора тоже получает явные координаты (текущие) — иначе её положение решает niri и сосед уезжает.
    function recomputePlacements() {
        for (let pass = 0; pass < 3; pass++) {
            for (const o of Settings.outputs) {
                const place = val(o, "place");
                if (place === "auto") continue;
                const [rel, name] = place.split(":");
                const t = byName(name), tr = t ? rect(t) : null, r = rect(o);
                if (!tr || !r) continue;
                if (val(t, "place") === "auto") {
                    pin(t, "x", tr.x);
                    pin(t, "y", tr.y);
                }
                const pos = rel === "right" ? [tr.x + tr.w, tr.y]
                    : rel === "left" ? [tr.x - r.w, tr.y]
                    : rel === "above" ? [tr.x, tr.y - r.h]
                    : [tr.x, tr.y + tr.h];
                pin(o, "x", pos[0]);
                pin(o, "y", pos[1]);
            }
        }
    }

    function setVal(o, prop, v) {
        // последний работающий монитор не выключаем — иначе вернуть всё будет нечем
        if (prop === "enabled" && !v && Settings.outputs.filter(x => x !== o && val(x, "enabled")).length === 0) {
            message = I18n.tr("нельзя выключить единственный монитор");
            return;
        }
        message = "";
        begin();
        if (prop === "primary" && v)
            for (const x of Settings.outputs)
                if (x !== o) Settings.reset(key(x, "primary"));
        if (prop === "place" && v === "auto") {
            Settings.reset(key(o, "x"));
            Settings.reset(key(o, "y"));
        }
        // «A слева от B» при «B справа от A» — встречная ссылка: B становится опорой (place сбрасываем,
        // координаты он получит в recomputePlacements)
        if (prop === "place" && v !== "auto") {
            const t = byName(v.split(":")[1]);
            if (t && val(t, "place").split(":")[1] === o.name) Settings.reset(key(t, "place"));
        }
        Settings.set(key(o, prop), v);
        recomputePlacements();
    }

    function resetOutput(o) {
        begin();
        const prefix = "niri.out." + o.name + ".";
        const keep = {};
        for (const k in Settings.values)
            if (k.startsWith("niri.out.") && !k.startsWith(prefix)) keep[k] = Settings.values[k];
        Settings.replacePrefix("niri.out.", keep);
    }

    property string message: ""

    // как обновится состояние niri — перечитать выходы (фактический режим, позиции)
    Connections {
        target: Settings
        function onValuesChanged() { refresh.restart(); }
    }

    Timer {
        id: refresh
        interval: 800
        onTriggered: Settings.refreshOutputs()
    }

    onOpenChanged: if (!open) Settings.back()

    IpcHandler {
        target: "displays"
        function toggle(): void { root.open = !root.open; }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-displays"

            property int sel: 0
            readonly property var outputs: Settings.outputs
            readonly property var out: outputs[sel] ?? null
            property int cur: 0

            Component.onCompleted: Settings.refreshOutputs()

            // строки параметров выбранного монитора
            readonly property var rows: {
                const o = out;
                if (!o) return [];
                const others = outputs.filter(x => x !== o).map(x => x.name);
                const places = ["auto"].concat(...others.map(n => ["right:" + n, "left:" + n, "above:" + n, "below:" + n]));
                const r = [
                    { prop: "enabled", label: I18n.tr("включён"), type: "bool" },
                    { prop: "primary", label: I18n.tr("основной"), type: "bool", hint: I18n.tr("сюда фокус при запуске niri") },
                    { prop: "mode", label: I18n.tr("режим"), type: "enum", options: o.modes, hint: o.preferred ? I18n.tr("рекомендуемый: %1", o.preferred) : "" },
                    { prop: "scale", label: I18n.tr("масштаб"), type: "float", min: 0.5, max: 4, step: 0.25 },
                    { prop: "transform", label: I18n.tr("поворот"), type: "enum", options: S.TRANSFORMS },
                    { prop: "place", label: I18n.tr("расположение"), type: "enum", options: places, hint: others.length ? I18n.tr("относительно другого монитора; auto — как решит niri") : I18n.tr("один монитор — располагать не относительно чего") }
                ];
                if (o.vrrSupported) r.push({ prop: "vrr", label: "VRR (FreeSync)", type: "bool" });
                return r;
            }

            function placeLabel(p) {
                if (p === "auto") return "auto";
                const [rel, n] = p.split(":");
                return I18n.tr(({ right: "справа от %1", left: "слева от %1", above: "над %1", below: "под %1" })[rel], n);
            }

            function fmt(r) {
                const v = root.val(out, r.prop);
                if (r.type === "bool") return v ? "[x]" : "[ ]";
                if (r.prop === "place") return "‹ " + placeLabel(v) + " ›";
                if (r.type === "float") return "‹ " + Number(v).toFixed(2) + " ›";
                return "‹ " + v + " ›";
            }

            function adjust(r, d) {
                const o = out, v = root.val(o, r.prop);
                if (r.type === "bool") {
                    root.setVal(o, r.prop, !v);
                } else if (r.type === "enum") {
                    const i = r.options.indexOf(v);
                    root.setVal(o, r.prop, r.options[((i < 0 ? 0 : i) + d + r.options.length) % r.options.length]);
                } else {
                    root.setVal(o, r.prop, Number(Math.min(r.max, Math.max(r.min, v + d * r.step)).toFixed(2)));
                }
            }

            function changed(r) { return (root.key(out, r.prop)) in Settings.values; }

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            readonly property real lineH: cell.height * 1.3

            MouseArea {
                anchors.fill: parent
                onClicked: if (!root.pending) root.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: cell.advanceWidth * 78 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: root.pending ? Theme.yellow : Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T { id: title; text: "[ ~/settings/system/displays/ ]"; color: box.border.color; font.bold: true }
                }

                Item {
                    id: keys
                    focus: true

                    Keys.onPressed: event => {
                        const k = event.key;
                        const r = win.rows[win.cur];
                        if (root.pending && k === Qt.Key_Y) {
                            root.confirm();
                        } else if (root.pending && (k === Qt.Key_N || k === Qt.Key_Escape)) {
                            root.revert();
                        } else if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                            root.open = false;
                        } else if (k === Qt.Key_Tab) {
                            win.sel = (win.sel + 1) % Math.max(1, win.outputs.length);
                        } else if (k === Qt.Key_Backtab) {
                            win.sel = (win.sel - 1 + win.outputs.length) % Math.max(1, win.outputs.length);
                        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                            win.cur = Math.min(win.rows.length - 1, win.cur + 1);
                        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                            win.cur = Math.max(0, win.cur - 1);
                        } else if (r && (k === Qt.Key_Right || k === Qt.Key_L)) {
                            win.adjust(r, 1);
                        } else if (r && (k === Qt.Key_Left || k === Qt.Key_H)) {
                            win.adjust(r, -1);
                        } else if (r && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
                            win.adjust(r, 1);
                        } else if (k === Qt.Key_R && win.out) {
                            root.resetOutput(win.out);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: col

                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 6

                    // ── карта расположения ──
                    Item {
                        id: map

                        Layout.fillWidth: true
                        implicitHeight: win.lineH * 8

                        readonly property var rects: win.outputs.map(o => ({ o, r: root.rect(o) })).filter(x => x.r)
                        readonly property var bounds: {
                            if (!rects.length) return { x: 0, y: 0, w: 1, h: 1 };
                            const x0 = Math.min(...rects.map(x => x.r.x)), y0 = Math.min(...rects.map(x => x.r.y));
                            const x1 = Math.max(...rects.map(x => x.r.x + x.r.w)), y1 = Math.max(...rects.map(x => x.r.y + x.r.h));
                            return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) };
                        }
                        readonly property real k: Math.min((width - 4) / bounds.w, (height - 4) / bounds.h)

                        Repeater {
                            model: map.rects

                            Rectangle {
                                id: mon

                                required property var modelData
                                // по имени: Repeater отдаёт копию объекта, === с исходным не совпадёт
                                readonly property bool selected: modelData.o.name === win.out?.name

                                x: (map.width - map.bounds.w * map.k) / 2 + (modelData.r.x - map.bounds.x) * map.k
                                y: (map.height - map.bounds.h * map.k) / 2 + (modelData.r.y - map.bounds.y) * map.k
                                width: modelData.r.w * map.k - 2
                                height: modelData.r.h * map.k - 2
                                color: selected ? Theme.bg1 : "transparent"
                                border.color: selected ? Theme.accent : Theme.bg2
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    T {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: mon.modelData.o.name + (root.val(mon.modelData.o, "primary") ? I18n.tr(" (основной)") : "")
                                        color: mon.selected ? Theme.accent : Theme.fg
                                        font.bold: mon.selected
                                    }
                                    T {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.val(mon.modelData.o, "mode").replace(/\.\d+$/, "")
                                        color: Theme.gray
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: win.sel = win.outputs.findIndex(o => o.name === mon.modelData.o.name)
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }

                    // ── выбранный монитор ──
                    T {
                        textFormat: Text.StyledText
                        text: !win.out ? I18n.tr("мониторы не найдены") :
                            `<font color="${Theme.accent}"><b>▌ ${win.out.name}</b></font>`
                            + `<font color="${Theme.gray}">  ${[win.out.make, win.out.model].filter(x => x).join(" ")}`
                            + (win.out.physical[0] ? "  ·  " + I18n.tr("%1×%2 мм", win.out.physical[0], win.out.physical[1]) : "")
                            + (win.outputs.length > 1 ? `  ·  ${win.sel + 1}/${win.outputs.length}` : "") + "</font>"
                    }

                    Repeater {
                        model: win.rows

                        Rectangle {
                            id: line

                            required property var modelData
                            required property int index
                            readonly property bool current: index === win.cur

                            Layout.fillWidth: true
                            implicitHeight: win.lineH
                            color: current ? Theme.bg1 : "transparent"

                            RowLayout {
                                anchors { fill: parent; rightMargin: Theme.pad }
                                spacing: 0

                                T { text: line.current ? "▌ " : "  "; color: Theme.accent }
                                T {
                                    text: line.modelData.label
                                    color: line.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                    font.bold: line.current
                                }
                                T { text: win.changed(line.modelData) ? " *" : ""; color: Theme.accent }
                                Item { Layout.fillWidth: true }
                                T {
                                    text: win.fmt(line.modelData)
                                    color: line.modelData.type === "bool" && !root.val(win.out, line.modelData.prop) ? Theme.gray : Theme.fg
                                    font.bold: line.current
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    win.cur = line.index;
                                    win.adjust(line.modelData, mouse.button === Qt.RightButton ? -1 : 1);
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }

                    // подсказка или ожидание подтверждения
                    T {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: root.pending
                            ? `<font color="${Theme.yellow}"><b>${I18n.tr("применено — оставить?")}</b></font>  `
                                + `<font color="${Theme.accent}">y</font> ${I18n.tr("да")}   <font color="${Theme.accent}">n</font> ${I18n.tr("вернуть")}   `
                                + `<font color="${Theme.gray}">${I18n.tr("(откат через %1 с)", root.remaining)}</font>`
                            : root.message
                                ? `<font color="${Theme.red}">${root.message}</font>`
                                : `<font color="${Theme.gray}">${win.rows[win.cur]?.hint ?? ""}</font>`
                    }

                    T {
                        Layout.alignment: Qt.AlignRight
                        textFormat: Text.StyledText
                        color: Theme.gray
                        text: [["↑↓", I18n.tr("выбор")], ["←→", I18n.tr("изменить")], ["⇥", I18n.tr("монитор")], ["r", I18n.tr("сброс монитора")], ["esc", I18n.tr("выход")]]
                            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                    }
                }
            }
        }
    }
}
