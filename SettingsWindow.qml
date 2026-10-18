import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/settings.js" as S

// Настройки: разделы слева, справа — карточки групп, у каждой строки свой элемент (как в DankMaterialShell, но в стиле ochre).
// Мышь меняет сразу: тумблер, кнопки вариантов, ползунок, поле, кнопки действий, зоны модулей; ↺ — по умолчанию.
// Клавиатура — как в menuconfig, через черновик:
//   ↑↓ выбор, ←→ изменить, ↵ применить/открыть, r сброс, / поиск, tab раздел, esc выход
//   qs ipc call settings toggle
//   qs ipc call settings open <раздел>   — look, windows, input, bar, notify, lock, system; "" — последний
//   qs ipc call settings set <ключ> <значение> — для скриптов: shell.accent blue, shell.fontSize 18, niri.shadow true;
//                                              значение — JSON, иначе строка; "" — вернуть по умолчанию
//   qs ipc call settings get <ключ>      — значение в JSON
Scope {
    id: root

    IpcHandler {
        target: "settings"
        function toggle(): void { Settings.open = !Settings.open; }
        function open(section: string): void { Settings.show(section); }
        function set(key: string, value: string): string {
            // только ключи из схемы — опечатка не должна оседать в settings.json мусором
            if (S.defaultOf(key, Settings.outputs) === undefined) return "неизвестный ключ: " + key;
            if (value === "") { Settings.reset(key); return "по умолчанию: " + JSON.stringify(Settings.get(key)); }
            let v = value;
            try { v = JSON.parse(value); } catch (e) {}
            const row = S.find(key, Settings.outputs);
            if (row?.options && !row.options.includes(v)) return "допустимо: " + row.options.join(", ");
            Settings.set(key, v);
            return JSON.stringify(Settings.get(key));
        }
        function get(key: string): string { return JSON.stringify(Settings.get(key)) ?? "неизвестный ключ: " + key; }
    }

    LazyLoader {
        active: Settings.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-settings"

            readonly property var sections: S.sections(Settings.outputs, Settings.get("shell.bar.layout"), Settings.get("shell.home.layout"))
            property int section: 0
            readonly property string query: search.text.trim()
            readonly property var rows: query ? S.searchRows(sections, query) : sections[section].rows
            property int cur: 1
            property bool editing: false
            property bool capturing: false   // строка combo ждёт нажатия сочетания
            // черновик: ←→, Space, клик и r меняют только его, применяет ↵, Esc или уход со строки — отменяют
            property var draft: null         // { key, value }
            readonly property var row: rows[cur] ?? null

            Component.onCompleted: {
                Settings.refreshOutputs();
                selectSection(Math.max(0, sections.findIndex(s => s.id === Settings.page)));
            }

            onQueryChanged: {
                cur = 0;
                move(1);
            }

            function isItem(i) { return i >= 0 && i < rows.length && !rows[i].header; }

            function move(d) {
                let i = cur + d;
                while (i >= 0 && i < rows.length && !isItem(i)) i += d;
                if (isItem(i)) cur = i;
            }

            function selectSection(i) {
                search.text = "";
                section = (i + sections.length) % sections.length;
                Settings.page = sections[section].id;
                cur = 0;
                move(1);
            }

            // ── действия (строки type: "action") ──

            function runAction(name) {
                Settings.open = false;
                // из этих окон Esc возвращает сюда же
                Settings.returnHere = ["picker", "wallhaven", "binds", "displays", "lockPreview"].includes(name);
                const ipc = (...args) => Ochre.ipc(...args);
                switch (name) {
                case "picker": Wallpaper.pickerSource = "local"; Wallpaper.pickerOpen = true; break;
                case "wallhaven": Wallpaper.pickerSource = "wallhaven"; Wallpaper.pickerOpen = true; break;
                case "binds": ipc("binds", "toggle"); break;
                case "hotkeys": Niri.action("show-hotkey-overlay"); break;
                case "displays": ipc("displays", "toggle"); break;
                case "lock": ipc("lock", "lock"); break;
                case "lockPreview": ipc("lock", "preview"); break;
                case "home": ipc("home", "open"); break;
                case "record": ipc("record", "toggle"); break;
                case "notifyTest": Quickshell.execDetached(["notify-send", "-a", "ochre", "Проверка уведомления", "так выглядит анимация " + Settings.get("shell.notify.anim")]); break;
                case "wifi": Term.float(["nmtui"]); break;
                case "audio": Quickshell.execDetached(["pavucontrol"]); break;
                case "editNiri": Term.edit(Quickshell.env("HOME") + "/.config/niri/config.kdl"); break;
                case "editShell": Term.edit(Quickshell.shellDir); break;
                case "editTerminal": Term.edit(Term.configPath); break;
                case "shellUpdate":
                    if (Ochre.system)
                        Quickshell.execDetached(["notify-send", "-a", "ochre", "ochre поставлен пакетом",
                            "Обновляется вместе с системой; после обновления придёт уведомление с перезапуском shell."]);
                    else if (ShellUpdate.behind > 0) ShellUpdate.update();
                    else ShellUpdate.check(true);
                    break;
                case "restartShell": ShellUpdate.restartShell(); break;
                case "greeterUpdate": ShellUpdate.updateGreeter(); break;
                default: console.warn("settings: неизвестное действие", name);
                }
            }

            // ── значения ──

            // обои хранят заполнение сами, остальное — в Settings; у строки раскладки значение — её зона
            function value(r) {
                if (r.type === "module") return r.zone;
                return r.key === "wallpaper.fill" ? Wallpaper.fill : Settings.get(r.key);
            }
            function changed(r) {
                if (r.type === "module") return S.zoneOf(null, r.id, r.key) !== r.zone;
                if (r.type === "action") return false;
                return r.key === "wallpaper.fill" ? Wallpaper.fill !== r.def : !Settings.isDefault(r.key);
            }

            // строки модулей панели и секций home пересоздаются при каждом изменении раскладки — выделение идёт за ними
            function selectModule(id, key) {
                const i = rows.findIndex(x => x.type === "module" && x.id === id && x.key === key);
                if (i >= 0) cur = i;
            }

            function reorderModule(r, d) {
                const l = S.reorderModule(Settings.get(r.key), r.id, d, r.key);
                if (!l) return;
                Settings.set(r.key, l);
                selectModule(r.id, r.key);
            }

            function setValue(r, v) {
                if (r.key === "wallpaper.fill") Wallpaper.setFill(v);
                else Settings.set(r.key, v);
            }

            // ── черновик ──
            // у строк раскладки ключ общий (shell.bar.layout) — черновик ещё и по id
            function drafted(r) { return !!draft && !!r && draft.key === r.key && (r.type !== "module" || draft.id === r.id); }
            function shown(r) { return drafted(r) ? draft.value : value(r); }

            function propose(r, v) {
                // вернулись к текущему значению — черновика нет
                draft = v === value(r) ? null : { key: r.key, id: r.id, value: v };
            }

            function apply() {
                if (!drafted(row)) return;
                const r = row, v = draft.value;
                draft = null;
                if (r.type === "module") {
                    Settings.set(r.key, S.setZone(Settings.get(r.key), r.id, v, r.key));
                    selectModule(r.id, r.key);   // строки раскладки пересоздались — выделение идёт за элементом
                } else {
                    setValue(r, v);
                }
            }

            function reset(r) {
                if (r.type === "action") return;
                if (r.type === "module") {
                    propose(r, S.zoneOf(null, r.id, r.key));   // зона по умолчанию — черновиком, ↵ применит
                } else if (r.type === "combo" || r.type === "text") {
                    Settings.reset(r.key);
                } else {
                    propose(r, r.def);   // по умолчанию — тоже через ↵
                }
            }

            function adjust(r, d) {
                const v = shown(r);
                if (r.type === "module") {
                    const z = S.layoutZones(r.key);
                    propose(r, z[(z.indexOf(v) + d + z.length) % z.length]);
                } else if (r.type === "bool") {
                    propose(r, !v);
                } else if (r.type === "enum") {
                    const o = r.options;
                    propose(r, o[(o.indexOf(v) + d + o.length) % o.length]);
                } else if (r.type === "int" || r.type === "float") {
                    const n = Math.min(r.max, Math.max(r.min, v + d * r.step));
                    propose(r, r.type === "int" ? Math.round(n) : Number(n.toFixed(2)));
                }
            }

            function activate(r) {
                if (drafted(r)) {
                    apply();
                } else if (r.type === "combo") {
                    capturing = true;
                } else if (r.type === "text") {
                    editing = true;   // поле в строке само возьмёт фокус
                } else if (r.type === "action") {
                    runAction(r.action);
                }
                // значения (bool/enum/int/float/module) без черновика: ↵ ничего не меняет — выбирают ←→, Space или клик
            }

            // ⇥ в захвате: сочетание, занятое niri (Mod+D и т.п.), не нажать — niri перехватит его раньше окна
            function editComboAsText(r) {
                capturing = false;
                editing = true;
            }

            function finishEdit(commit, text) {
                if (commit && row) setValue(row, row.type === "combo" ? text.trim().replace(/\s+/g, "") : text.trim());
                editing = false;
                keys.forceActiveFocus();
            }

            // ── мышь: меняет сразу, без черновика ──
            function pick(i, v) {
                const r = rows[i];
                if (!r) return;
                cur = i;
                draft = null;
                editing = false;
                keys.forceActiveFocus();
                if (r.type === "module") {
                    Settings.set(r.key, S.setZone(Settings.get(r.key), r.id, v, r.key));
                    selectModule(r.id, r.key);
                } else {
                    setValue(r, v);
                }
            }
            function nudge(i, d) {
                const r = rows[i];
                const n = Math.min(r.max, Math.max(r.min, value(r) + d * r.step));
                pick(i, r.type === "int" ? Math.round(n) : Number(n.toFixed(2)));
            }
            function resetNow(i) {
                const r = rows[i];
                cur = i;
                if (r.key === "wallpaper.fill") setValue(r, r.def);
                else Settings.reset(r.key);
            }
            function focusRow(i) {
                if (i !== cur) cur = i;
                if (!editing) keys.forceActiveFocus();
            }

            // выпадающий список для перечислений, которым не хватает места на кнопки
            property int drop: -1
            property point dropAt: Qt.point(0, 0)
            function openDrop(i, item) {
                focusRow(i);
                dropAt = item.mapToItem(box, 0, item.height);
                drop = i;
            }

            function startSearch() {
                search.forceActiveFocus();
                search.selectAll();
            }

            function endSearch(keep) {
                if (!keep) search.text = "";
                keys.forceActiveFocus();
            }

            function fmt(r, v) {
                if (v === undefined) v = shown(r);
                if (r.type === "module") return "‹ " + S.zoneLabel(r.key, v) + " ›";
                if (r.type === "bool") return v ? "[x]" : "[ ]";
                if (r.type === "text") return JSON.stringify(v);
                if (r.type === "combo") return capturing && r === row ? "нажмите сочетание…" : v ? "[" + v + "]" : "—";
                if (r.type === "action") return "↵";
                if (r.type === "float") {
                    const decimals = String(r.step).split(".")[1]?.length ?? 0;
                    return "‹ " + Number(v).toFixed(decimals) + " ›";
                }
                // значения с пробелами по краям (разделители) — в кавычках, иначе их не видно
                if (typeof v === "string" && v !== v.trim()) return "‹ " + JSON.stringify(v) + " ›";
                return "‹ " + v + " ›";
            }

            function valueColor(r) {
                if (drafted(r)) return Theme.accent;
                if (r.type === "module") return r.zone === "off" ? Theme.gray : Theme.blue;
                if (r.type === "bool") return value(r) ? Theme.accent : Theme.gray;
                if (r.type === "text") return Theme.aqua;
                if (r.type === "action") return Theme.accent;
                if (r.type === "combo") return capturing && r === row ? Theme.accent : value(r) ? Theme.blue : Theme.gray;
                if (r.key === "shell.accent") return Theme.accent;
                return Theme.fg;
            }

            function hint(r) {
                if (!r) return "";
                if (r.type === "module") return r.hint;
                const file = S.niriFileOf(r.key);
                // файл первым: подсказка длинная и обрезается справа
                const parts = [file ? "niri/ochre/" + file : "", r.hint ?? ""];
                if (r.type === "combo" && value(r)) {
                    if (!S.COMBO_RE.test(value(r))) parts.unshift("не похоже на сочетание (Mod+Shift+M) — бинд не создан");
                    const other = Binds.conflict(value(r), r.action);
                    if (other) parts.unshift("занято: " + other.action + " — конфликт");
                }
                if (r.type !== "action") parts.push(r.key + "  ·  по умолчанию " + JSON.stringify(r.def));
                return parts.filter(x => x).join("  ·  ");
            }

            onCurChanged: {
                capturing = false;
                draft = null;   // ушли со строки — не подтверждено, значит не применяем
                drop = -1;
            }

            // карточки: группы строк под своими заголовками; index — номер строки в rows (для клавиатуры)
            readonly property var groups: {
                const out = [];
                let g = null;
                rows.forEach((r, i) => {
                    // у карточек раскладки (bar/, home/) — их зона: туда можно бросить модуль, даже если карточка пуста
                    if (r.header) { g = { header: r.header, items: [], zone: zoneOfHeader(r.header) }; out.push(g); return; }
                    if (!g) { g = { header: "", items: [], zone: "" }; out.push(g); }
                    g.items.push({ row: r, index: i });
                });
                return out;
            }

            // ── перетаскивание модулей панели и секций home ──
            readonly property string layoutKey: query ? "" : (({ bar: "shell.bar.layout", home: "shell.home.layout" })[sections[section].id] ?? "")
            property var dragRow: null          // строка модуля, которую тянут
            property var dropTarget: null       // {key, zone, before} — before: id, перед которым встанет; null — в конец зоны
            function zoneOfHeader(header) {
                return layoutKey ? (S.layoutZones(layoutKey).find(z => S.zoneLabel(layoutKey, z) === header) ?? "") : "";
            }
            function nextInZone(i) {
                for (let j = i + 1; j < rows.length; j++) {
                    if (rows[j].header) return null;
                    if (rows[j].type === "module") return rows[j].id;
                }
                return null;
            }
            function dropOver(i, upper) {
                const r = rows[i];
                if (!dragRow || r?.type !== "module") return;
                dropTarget = { key: r.key, zone: r.zone, before: upper ? r.id : nextInZone(i) };
            }
            function dropInto(zone, before) {
                if (dragRow && zone) dropTarget = { key: layoutKey, zone, before };
            }
            function isDropBefore(r) {
                return !!dropTarget && !!dragRow && dropTarget.key === r.key && dropTarget.zone === r.zone && dropTarget.before === r.id
                    && r.id !== dragRow.id;
            }
            function finishDrag() {
                const d = dragRow, t = dropTarget;
                dragRow = null;
                dropTarget = null;
                if (!d || !t || t.key !== d.key || t.before === d.id) return;
                Settings.set(d.key, S.placeModule(Settings.get(d.key), d.id, t.zone, t.before, d.key));
                selectModule(d.id, d.key);
            }

            // текущая строка — на экране (клавиатура уводит выделение за край)
            function scrollTo(item) {
                const y = item.mapToItem(flick.contentItem, 0, 0).y;
                if (y < flick.contentY) flick.contentY = Math.max(0, y - Theme.pad * 2);
                else if (y + item.height > flick.contentY + flick.height)
                    flick.contentY = Math.min(flick.contentHeight - flick.height, y + item.height - flick.height + Theme.pad * 2);
            }

            readonly property var icons: ({
                look: 0xF03D8, windows: 0xF05B2, input: 0xF030C, bar: 0xF06FC, home: 0xF02DC,
                notify: 0xF009A, lock: 0xF033E, system: 0xF0493
            })
            function icon(id) { return icons[id] ? String.fromCodePoint(icons[id]) : "•"; }

            // подписи вариантов: зоны раскладки — коротко
            function optionLabel(r, o) {
                if (r.type === "module") return ({ off: "выкл", on: "вкл" })[o] ?? S.zoneLabel(r.key, o);
                return String(o);
            }
            function optionsOf(r) { return r.type === "module" ? S.layoutZones(r.key) : (r.options ?? []); }
            // кнопками — если помещаются; иначе — выпадающий список
            function fitsSegments(r) {
                const o = optionsOf(r);
                return o.length <= 6 && o.reduce((n, x) => n + optionLabel(r, x).length + 2, 0) <= 40;
            }
            readonly property var swatchKeys: ["shell.accent", "shell.shot.color"]
            readonly property var opens: ["picker", "wallhaven", "binds", "displays", "home", "wifi", "audio", "editNiri",
                "editShell", "editTerminal", "lockPreview", "hotkeys"]

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }


            readonly property real lineH: cell.height * 1.3
            readonly property real cw: cell.advanceWidth

            MouseArea {
                anchors.fill: parent
                onClicked: Settings.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: Math.min(win.width - 80, win.cw * 150 + Theme.pad * 2)
                height: Math.min(win.height - 100, Math.max(win.lineH * 30, win.height * 0.82))
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent; onClicked: win.drop = -1 }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth + win.cw
                    height: title.implicitHeight
                    color: Theme.bg
                    T {
                        id: title
                        anchors.centerIn: parent
                        text: win.query ? "[ ~/settings/?" + win.query + " ]" : "[ ~/settings/" + win.sections[win.section].id + "/ ]"
                        color: Theme.accent
                        font.bold: true
                    }
                }

                // невидимый приёмник клавиш, пока не редактируем текст и не ищем
                Item {
                    id: keys
                    focus: true

                    Keys.onPressed: event => {
                        const r = win.row;
                        const k = event.key;
                        // захват сочетания: Esc — отмена, ⌫/Delete — убрать бинд, ⇥ — ввести текстом
                        if (win.capturing) {
                            event.accepted = true;
                            const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier));
                            if (plain && k === Qt.Key_Escape) win.capturing = false;
                            else if (plain && (k === Qt.Key_Backspace || k === Qt.Key_Delete)) { win.reset(r); win.capturing = false; }
                            else if (plain && k === Qt.Key_Tab) win.editComboAsText(r);
                            else {
                                const combo = Binds.comboOf(event);
                                if (!combo) return;   // пока зажат только модификатор
                                win.setValue(r, combo);
                                win.capturing = false;
                            }
                            return;
                        }
                        if (win.drop >= 0 && k === Qt.Key_Escape) { win.drop = -1; event.accepted = true; return; }
                        if (win.draft && (k === Qt.Key_Escape || k === Qt.Key_Q)) {
                            win.draft = null;
                            event.accepted = true;
                            return;
                        }
                        const shift = event.modifiers & Qt.ShiftModifier;
                        const isModule = r && r.type === "module";
                        if (isModule && ((shift && k === Qt.Key_Up) || (shift && k === Qt.Key_K))) {
                            win.reorderModule(r, -1);
                        } else if (isModule && ((shift && k === Qt.Key_Down) || (shift && k === Qt.Key_J))) {
                            win.reorderModule(r, 1);
                        } else if (k === Qt.Key_Slash) {
                            win.startSearch();
                        } else if (k === Qt.Key_Escape && win.query) {
                            win.endSearch(false);
                        } else if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                            Settings.open = false;
                        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                            win.move(1);
                        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                            win.move(-1);
                        } else if (k === Qt.Key_Tab) {
                            win.selectSection(win.query ? win.section : win.section + 1);
                        } else if (k === Qt.Key_Backtab) {
                            win.selectSection(win.query ? win.section : win.section - 1);
                        } else if (k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < win.sections.length) {
                            win.selectSection(k - Qt.Key_1);
                        } else if (r && (k === Qt.Key_Right || k === Qt.Key_L)) {
                            win.adjust(r, 1);
                        } else if (r && (k === Qt.Key_Left || k === Qt.Key_H)) {
                            win.adjust(r, -1);
                        } else if (r && (k === Qt.Key_Return || k === Qt.Key_Enter)) {
                            win.activate(r);
                        } else if (r && k === Qt.Key_Space) {
                            // Space — следующее значение в черновик; у текста, сочетаний и действий — как ↵
                            if (["bool", "enum", "int", "float"].includes(r.type)) win.adjust(r, 1);
                            else win.activate(r);
                        } else if (r && k === Qt.Key_R) {
                            win.reset(r);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    anchors { fill: parent; margins: Theme.pad; topMargin: Theme.pad * 1.5 }
                    spacing: Theme.pad

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.pad

                        // ── разделы ──
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: win.cw * 24
                            color: "transparent"
                            border.color: Theme.bg2
                            border.width: 1

                            ColumnLayout {
                                anchors { fill: parent; margins: 4 }
                                spacing: 2

                                // поиск — над разделами, как в DMS
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: win.lineH * 1.2
                                    color: search.activeFocus ? Theme.bg1 : "transparent"
                                    border.color: search.activeFocus ? Theme.accent : Theme.bg2
                                    border.width: 1

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: win.cw * 0.6; rightMargin: win.cw * 0.6 }
                                        spacing: win.cw * 0.6
                                        T { font.family: Theme.iconFont; text: String.fromCodePoint(0xF0349); color: search.activeFocus ? Theme.accent : Theme.gray }
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: search.implicitHeight
                                            TextInput {
                                                id: search
                                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize
                                                color: Theme.fg
                                                selectionColor: Theme.bg2
                                                renderType: Text.NativeRendering
                                                clip: true
                                                Keys.onPressed: event => {
                                                    const k = event.key;
                                                    if (k === Qt.Key_Escape) win.endSearch(false);
                                                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.endSearch(true);
                                                    else if (k === Qt.Key_Down) win.move(1);
                                                    else if (k === Qt.Key_Up) win.move(-1);
                                                    else return;
                                                    event.accepted = true;
                                                }
                                            }
                                            T { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "поиск  /"; color: Theme.bg2 }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: win.startSearch() }
                                        }
                                        T {
                                            visible: search.text !== ""
                                            font.family: Theme.iconFont
                                            text: String.fromCodePoint(0xF0156)
                                            color: clr.containsMouse ? Theme.red : Theme.gray
                                            MouseArea { id: clr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.endSearch(false) }
                                        }
                                    }
                                }

                                Item { implicitHeight: 4 }

                                Repeater {
                                    model: win.sections

                                    Rectangle {
                                        id: sec
                                        required property var modelData
                                        required property int index
                                        readonly property bool current: index === win.section && !win.query

                                        Layout.fillWidth: true
                                        implicitHeight: win.lineH * 1.35
                                        color: current ? Theme.bg1 : secHover.containsMouse ? Qt.darker(Theme.bg1, 1.35) : "transparent"

                                        Rectangle { visible: sec.current; width: 3; height: parent.height; color: Theme.accent }
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: win.cw * 1.2; rightMargin: win.cw }
                                            spacing: win.cw
                                            T {
                                                font.family: Theme.iconFont
                                                text: win.icon(sec.modelData.id)
                                                color: sec.current ? Theme.accent : Theme.gray
                                            }
                                            T {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: sec.modelData.title
                                                color: sec.current ? Theme.accent : secHover.containsMouse ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                                font.bold: sec.current
                                            }
                                            T { text: String(sec.index + 1); color: Theme.bg2 }
                                        }
                                        MouseArea {
                                            id: secHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { win.selectSection(sec.index); win.endSearch(false); flick.contentY = 0; }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // ── параметры: карточки групп ──
                        Flickable {
                            id: flick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: cards.implicitHeight + Theme.pad
                            boundsBehavior: Flickable.StopAtBounds

                            T {
                                anchors.centerIn: parent
                                visible: win.query !== "" && win.rows.length === 0
                                text: "ничего не найдено"
                                color: Theme.gray
                            }

                            ColumnLayout {
                                id: cards
                                width: flick.width - win.cw
                                y: win.lineH * 0.5
                                spacing: win.lineH * 0.9

                                Repeater {
                                    model: win.groups

                                    Rectangle {
                                        id: card
                                        required property var modelData
                                        readonly property bool active: modelData.items.some(it => it.index === win.cur)
                                        Layout.fillWidth: true
                                        implicitHeight: Math.max(win.lineH * 1.6, cardCol.implicitHeight + Theme.pad * 1.6)
                                        color: "transparent"
                                        border.color: active ? Qt.darker(Theme.accent, 1.6) : Theme.bg2
                                        border.width: 1

                                        // бросили на карточку мимо строк: выше первой — в начало зоны, иначе — в конец
                                        DropArea {
                                            anchors.fill: parent
                                            enabled: card.modelData.zone !== ""
                                            function at(y) {
                                                const first = card.modelData.items[0]?.row;
                                                win.dropInto(card.modelData.zone, first && y < cardCol.y + 6 ? first.id : null);
                                            }
                                            onEntered: drag => at(drag.y)
                                            onPositionChanged: drag => at(drag.y)
                                        }
                                        // в конец зоны — линия под последней строкой (у пустой карточки — посередине)
                                        Rectangle {
                                            visible: !!win.dropTarget && win.dropTarget.before === null && win.dropTarget.zone === card.modelData.zone
                                                && win.dropTarget.key === win.layoutKey && card.modelData.zone !== ""
                                            x: Theme.pad
                                            width: parent.width - Theme.pad * 2
                                            height: 2
                                            y: card.modelData.items.length ? cardCol.y + cardCol.height - 1 : parent.height / 2
                                            color: Theme.accent
                                            z: 5
                                        }

                                        Rectangle {
                                            visible: card.modelData.header !== ""
                                            x: Theme.pad
                                            y: -height / 2
                                            width: cardTitle.implicitWidth + win.cw * 2
                                            height: cardTitle.implicitHeight
                                            color: Theme.bg
                                            T {
                                                id: cardTitle
                                                anchors.centerIn: parent
                                                text: card.modelData.header
                                                color: card.active ? Theme.accent : Theme.gray
                                                font.bold: true
                                            }
                                        }

                                        ColumnLayout {
                                            id: cardCol
                                            x: 2
                                            y: Theme.pad
                                            width: parent.width - 4
                                            spacing: 0

                                            Repeater {
                                                model: card.modelData.items
                                                delegate: settingRow
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // подсказка к текущей строке: файл niri, ключ, значение по умолчанию
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.pad
                        T {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            color: Theme.gray
                            text: win.hint(win.row)
                        }
                        T {
                            textFormat: Text.StyledText
                            color: Theme.gray
                            text: (win.draft
                                ? [["↵", "применить"], ["esc", "отмена"], ["←→", "значение"]]
                                : win.capturing
                                ? [["…", "нажмите сочетание"], ["⇥", "текстом"], ["⌫", "убрать"], ["esc", "отмена"]]
                                : win.editing
                                ? [["↵", "сохранить"], ["esc", "отмена"]]
                                : [["↑↓", "выбор"], ["←→", "изменить"], ["↵", "открыть"], ["r", "сброс"], ["/", "поиск"], ["esc", win.query ? "сбросить поиск" : "выход"]])
                                .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                        }
                    }
                }

                // ── «призрак» перетаскиваемого модуля ──
                Rectangle {
                    id: ghost
                    property string text: ""
                    visible: win.dragRow !== null
                    z: 20
                    height: win.lineH * 1.4
                    color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.92)
                    border.color: Theme.accent
                    border.width: 1
                    Drag.active: win.dragRow !== null
                    T {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: win.cw * 1.5 }
                        textFormat: Text.StyledText
                        text: `<font face="${Theme.iconFont}">${String.fromCodePoint(0xF01DD)}</font>&nbsp;&nbsp;<b>${ghost.text}</b>`
                        color: Theme.accent
                    }
                }
                // у края списка — прокрутить
                Timer {
                    running: win.dragRow !== null
                    interval: 30
                    repeat: true
                    onTriggered: {
                        const y = ghost.mapToItem(flick, 0, ghost.height / 2).y;
                        const edge = win.lineH * 1.5;
                        if (y < edge) flick.contentY = Math.max(0, flick.contentY - 14);
                        else if (y > flick.height - edge) flick.contentY = Math.min(flick.contentHeight - flick.height, flick.contentY + 14);
                    }
                }

                // ── выпадающий список вариантов ──
                Rectangle {
                    id: dropBox
                    readonly property var r: win.rows[win.drop] ?? null
                    visible: win.drop >= 0 && r !== null
                    z: 10
                    x: Math.min(box.width - width - Theme.pad, win.dropAt.x)
                    y: Math.min(box.height - height - Theme.pad, win.dropAt.y + 2)
                    width: Math.max(win.cw * 22, dropCol.implicitWidth + win.cw * 2)
                    height: dropCol.implicitHeight + 8
                    color: Theme.bg
                    border.color: Theme.accent
                    border.width: 1

                    Column {
                        id: dropCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        Repeater {
                            model: dropBox.r ? win.optionsOf(dropBox.r) : []
                            Rectangle {
                                required property var modelData
                                readonly property bool sel: dropBox.r && modelData === win.shown(dropBox.r)
                                width: dropCol.width
                                height: win.lineH
                                color: optHover.containsMouse ? Theme.bg1 : "transparent"
                                T {
                                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: win.cw }
                                    text: (parent.sel ? "● " : "  ") + win.optionLabel(dropBox.r, parent.modelData)
                                    color: parent.sel ? Theme.accent : Theme.fg
                                }
                                MouseArea {
                                    id: optHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { const i = win.drop; win.drop = -1; win.pick(i, parent.modelData); }
                                }
                            }
                        }
                    }
                }
            }

            // ── строка настройки: подпись и описание слева, элемент справа ──
            Component {
                id: settingRow

                Rectangle {
                    id: line
                    required property var modelData
                    readonly property var r: modelData.row
                    readonly property int idx: modelData.index
                    readonly property bool current: idx === win.cur

                    Layout.fillWidth: true
                    implicitHeight: Math.max(texts.implicitHeight, control.implicitHeight) + win.cw * 1.4
                    color: current ? Theme.bg1 : rowHover.containsMouse ? Qt.darker(Theme.bg1, 1.35) : "transparent"

                    onCurrentChanged: if (current) Qt.callLater(() => { if (win) win.scrollTo(line); })   // окно могли закрыть

                    readonly property bool canDrag: line.r.type === "module" && win.layoutKey !== ""
                    opacity: win.dragRow && win.dragRow.id === line.r.id && win.dragRow.key === line.r.key ? 0.35 : 1

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: line.canDrag ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                        // строку модуля можно тащить: за мышью едет «призрак», строки и карточки ловят его DropArea
                        drag.target: line.canDrag ? ghost : null
                        drag.threshold: 6
                        preventStealing: line.canDrag
                        onPressed: mouse => {
                            if (!line.canDrag) return;
                            const p = line.mapToItem(box, 0, 0);
                            ghost.x = p.x;
                            ghost.y = p.y;
                            ghost.width = line.width;
                            ghost.text = line.r.label ?? line.r.id;
                            ghost.Drag.hotSpot = Qt.point(mouse.x, mouse.y);
                        }
                        onClicked: win.focusRow(line.idx)
                        onDoubleClicked: if (line.r.type === "action") win.runAction(line.r.action)
                    }
                    Connections {
                        target: rowHover.drag
                        function onActiveChanged() {
                            if (rowHover.drag.active) { win.focusRow(line.idx); win.dragRow = line.r; }
                            else win.finishDrag();
                        }
                    }
                    DropArea {
                        anchors.fill: parent
                        enabled: line.r.type === "module"
                        onEntered: drag => win.dropOver(line.idx, drag.y < height / 2)
                        onPositionChanged: drag => win.dropOver(line.idx, drag.y < height / 2)
                    }
                    // сюда встанет перетаскиваемый модуль
                    Rectangle {
                        visible: win.isDropBefore(line.r)
                        x: Theme.pad
                        width: parent.width - Theme.pad * 2
                        height: 2
                        color: Theme.accent
                        z: 5
                    }

                    Rectangle { visible: line.current; width: 3; height: parent.height; color: Theme.accent }

                    RowLayout {
                        anchors { fill: parent; leftMargin: win.cw * 1.5; rightMargin: win.cw * 1.2 }
                        spacing: win.cw * 2

                        // ⠿ — за это (и за всю строку) модуль можно перетащить
                        T {
                            visible: line.canDrag
                            font.family: Theme.iconFont
                            text: String.fromCodePoint(0xF01DD)
                            color: rowHover.containsMouse || line.current ? Theme.gray : Theme.bg2
                        }
                        ColumnLayout {
                            id: texts
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1
                            T {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                text: (line.r.label ?? "") + (win.changed(line.r) ? ` <font color="${Theme.accent}">*</font>` : "")
                                color: line.r.type === "action" ? Theme.blue : line.current ? Theme.fg : Qt.darker(Theme.fg, 1.08)
                                font.bold: line.current
                            }
                            T {
                                // у модулей подсказка общая — описание модуля до «·»
                                readonly property string h: line.r.type === "module" ? String(line.r.hint ?? "").split("  ·  ")[0] : (line.r.hint ?? "")
                                visible: h !== ""
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: h
                                color: Theme.gray
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }
                        }

                        Loader {
                            id: control
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                            readonly property var r: line.r
                            readonly property int idx: line.idx
                            readonly property bool current: line.current
                            sourceComponent: {
                                const t = line.r.type;
                                if (t === "bool") return toggleC;
                                if (t === "int" || t === "float") return sliderC;
                                if (t === "text") return textC;
                                if (t === "combo") return comboC;
                                if (t === "action") return actionC;
                                if (win.swatchKeys.includes(line.r.key)) return swatchC;
                                return win.fitsSegments(line.r) ? segmentsC : dropC;
                            }
                        }

                        // черновик с клавиатуры — применить мышкой
                        T {
                            visible: win.drafted(line.r)
                            text: "[↵]"
                            color: Theme.accent
                            font.bold: true
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.cur = line.idx; win.apply(); } }
                        }
                        // ↺ — по умолчанию (у раскладки — r на строке)
                        T {
                            readonly property bool can: !["action", "module"].includes(line.r.type) && win.changed(line.r)
                            opacity: can ? 1 : 0
                            font.family: Theme.iconFont
                            text: "↺"
                            color: resetHover.containsMouse ? Theme.accent : Theme.gray
                            MouseArea {
                                id: resetHover
                                anchors.fill: parent
                                enabled: parent.can
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.resetNow(line.idx)
                            }
                        }
                    }
                }
            }

            // ── элементы ──
            // тумблер: █ слева — выкл., справа акцентом — вкл.
            Component {
                id: toggleC
                Rectangle {
                    readonly property bool on: win.shown(parent.r) === true
                    readonly property int idx: parent.idx
                    implicitWidth: win.cw * 5
                    implicitHeight: Math.round(cell.height * 0.95)
                    color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
                    border.color: on ? Theme.accent : Theme.bg2
                    border.width: 1
                    Rectangle {
                        y: 3
                        x: parent.on ? parent.width - width - 3 : 3
                        width: parent.width / 2 - 3
                        height: parent.height - 6
                        color: parent.on ? Theme.accent : Theme.gray
                        Behavior on x { NumberAnimation { duration: 90 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pick(parent.idx, !win.value(win.rows[parent.idx]))
                    }
                }
            }

            // кнопки вариантов: [fill] [fit] [stretch]; у строк раскладки — зоны и порядок ↑↓
            Component {
                id: segmentsC
                Row {
                    id: seg
                    readonly property var r: parent.r
                    readonly property int idx: parent.idx
                    spacing: win.cw * 0.5
                    Repeater {
                        model: win.optionsOf(seg.r)
                        Rectangle {
                            required property var modelData
                            readonly property bool sel: modelData === win.shown(seg.r)
                            width: segT.implicitWidth + win.cw * 1.6
                            height: segT.implicitHeight + 4
                            color: sel ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : segHover.containsMouse ? Theme.bg1 : "transparent"
                            border.color: sel ? Theme.accent : Theme.bg2
                            border.width: 1
                            T {
                                id: segT
                                anchors.centerIn: parent
                                text: win.optionLabel(seg.r, parent.modelData)
                                color: parent.sel ? Theme.accent : segHover.containsMouse ? Theme.fg : Theme.gray
                                font.bold: parent.sel
                            }
                            MouseArea {
                                id: segHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.pick(seg.idx, parent.modelData)
                            }
                        }
                    }
                    // порядок модуля в зоне
                    Repeater {
                        model: seg.r.type === "module" ? [[-1, 0xF005D], [1, 0xF0045]] : []
                        T {
                            required property var modelData
                            // у выключенных порядка нет — место остаётся, чтобы кнопки зон стояли ровно
                            opacity: seg.r.zone !== "off" ? 1 : 0
                            font.family: Theme.iconFont
                            text: " " + String.fromCodePoint(modelData[1])
                            color: ordHover.containsMouse ? Theme.accent : Theme.gray
                            MouseArea {
                                id: ordHover
                                anchors.fill: parent
                                enabled: seg.r.zone !== "off"
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { win.focusRow(seg.idx); win.reorderModule(win.rows[seg.idx], parent.modelData[0]); }
                            }
                        }
                    }
                }
            }

            // много вариантов: ‹ значение ▾ › и список
            Component {
                id: dropC
                Rectangle {
                    id: dc
                    readonly property var r: parent.r
                    readonly property int idx: parent.idx
                    implicitWidth: Math.max(win.cw * 16, dcT.implicitWidth + win.cw * 4)
                    implicitHeight: dcT.implicitHeight + 4
                    color: dcHover.containsMouse ? Theme.bg1 : "transparent"
                    border.color: win.drop === idx ? Theme.accent : Theme.bg2
                    border.width: 1
                    T {
                        id: dcT
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: win.cw }
                        text: win.optionLabel(dc.r, win.shown(dc.r))
                        color: win.drafted(dc.r) ? Theme.accent : Theme.fg
                    }
                    T {
                        anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: win.cw * 0.6 }
                        font.family: Theme.iconFont
                        text: String.fromCodePoint(0xF0140)
                        color: Theme.gray
                    }
                    MouseArea {
                        id: dcHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.drop === dc.idx ? win.drop = -1 : win.openDrop(dc.idx, dc)
                    }
                }
            }

            // цвета: квадраты, выбранный — в рамке, название рядом
            Component {
                id: swatchC
                Row {
                    id: sw
                    readonly property var r: parent.r
                    readonly property int idx: parent.idx
                    spacing: win.cw * 0.5
                    Repeater {
                        model: sw.r.options
                        Rectangle {
                            required property var modelData
                            readonly property bool sel: modelData === win.shown(sw.r)
                            width: Math.round(cell.height * 1.1)
                            height: width
                            color: "transparent"
                            border.color: sel ? Theme.fg : swHover.containsMouse ? Theme.bg2 : "transparent"
                            border.width: 2
                            Rectangle { anchors { fill: parent; margins: 3 } color: Theme.named(parent.modelData); border.color: Theme.bg2; border.width: parent.modelData === "black" ? 1 : 0 }
                            MouseArea {
                                id: swHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.pick(sw.idx, parent.modelData)
                            }
                        }
                    }
                    T { anchors.verticalCenter: parent.verticalCenter; text: " " + win.shown(sw.r); color: Theme.gray }
                }
            }

            // число: [−] ▕████░░░░▏ [+] значение; полосу можно тянуть
            Component {
                id: sliderC
                Row {
                    id: sl
                    readonly property var r: parent.r
                    readonly property int idx: parent.idx
                    readonly property real v: win.shown(r)
                    readonly property int cells: 18
                    readonly property int filled: Math.round(Math.max(0, Math.min(1, (v - r.min) / (r.max - r.min))) * cells)
                    readonly property int decimals: r.type === "float" ? (String(r.step).split(".")[1]?.length ?? 0) : 0
                    spacing: 0
                    function at(x) {
                        const f = Math.max(0, Math.min(1, x / (cells * win.cw)));
                        const n = r.min + Math.round(f * (r.max - r.min) / r.step) * r.step;
                        return r.type === "int" ? Math.round(n) : Number(n.toFixed(2));
                    }
                    T {
                        font.family: Theme.iconFont
                        text: String.fromCodePoint(0xF0374) + " "
                        color: minus.containsMouse ? Theme.accent : Theme.gray
                        MouseArea { id: minus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.nudge(sl.idx, -1) }
                    }
                    T {
                        text: "█".repeat(sl.filled) + "░".repeat(sl.cells - sl.filled)
                        color: win.drafted(sl.r) ? Theme.accent : Qt.darker(Theme.accent, sl.parent.current ? 1 : 1.25)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPressed: mouse => win.pick(sl.idx, sl.at(mouse.x))
                            onPositionChanged: mouse => { if (pressed) { const v = sl.at(mouse.x); if (v !== win.value(win.rows[sl.idx])) win.pick(sl.idx, v); } }
                        }
                    }
                    T {
                        font.family: Theme.iconFont
                        text: " " + String.fromCodePoint(0xF0415)
                        color: plus.containsMouse ? Theme.accent : Theme.gray
                        MouseArea { id: plus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.nudge(sl.idx, 1) }
                    }
                    T {
                        text: " " + Number(sl.v).toFixed(sl.decimals).padStart(5)
                        color: win.drafted(sl.r) ? Theme.accent : Theme.fg
                        font.bold: true
                    }
                }
            }

            // текст: поле прямо в строке, клик — редактировать
            Component {
                id: textC
                Rectangle {
                    id: tf
                    readonly property var r: parent.r
                    readonly property int idx: parent.idx
                    readonly property bool edit: win.editing && parent.current
                    implicitWidth: win.cw * 32
                    implicitHeight: tfT.implicitHeight + 6
                    color: edit ? Theme.bg : "transparent"
                    border.color: edit ? Theme.accent : tfHover.containsMouse ? Theme.gray : Theme.bg2
                    border.width: 1
                    T {
                        id: tfT
                        visible: !tf.edit
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: win.cw * 0.6; rightMargin: win.cw * 0.6 }
                        elide: Text.ElideRight
                        text: String(win.value(tf.r)) || "пусто"
                        color: String(win.value(tf.r)) ? Theme.aqua : Theme.bg2
                    }
                    TextInput {
                        visible: tf.edit
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: win.cw * 0.6; rightMargin: win.cw * 0.6 }
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                        selectionColor: Theme.bg2
                        renderType: Text.NativeRendering
                        clip: true
                        onVisibleChanged: if (visible) { text = String(win.value(tf.r)); selectAll(); forceActiveFocus(); }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.finishEdit(true, text);
                            else if (event.key === Qt.Key_Escape) win.finishEdit(false, "");
                            else return;
                            event.accepted = true;
                        }
                        onActiveFocusChanged: if (!activeFocus && visible) win.finishEdit(true, text)
                    }
                    MouseArea {
                        id: tfHover
                        anchors.fill: parent
                        visible: !tf.edit
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: { win.focusRow(tf.idx); win.editing = true; }
                    }
                }
            }

            // сочетание: [Mod+Shift+M] — клик и нажать; ⌫ в строке или ✕ — убрать
            Component {
                id: comboC
                Row {
                    id: cb
                    readonly property var r: parent.r
                    readonly property int idx: parent.idx
                    readonly property bool cap: win.capturing && parent.current
                    readonly property bool edit: win.editing && parent.current
                    spacing: win.cw
                    Rectangle {
                        width: Math.max(win.cw * 18, cbT.implicitWidth + win.cw * 2)
                        height: cbT.implicitHeight + 6
                        color: cb.cap || cb.edit ? Theme.bg : cbHover.containsMouse ? Theme.bg1 : "transparent"
                        border.color: cb.cap || cb.edit ? Theme.accent : Theme.bg2
                        border.width: 1
                        T {
                            id: cbT
                            visible: !cb.edit
                            anchors.centerIn: parent
                            text: cb.cap ? "нажмите сочетание…" : win.value(cb.r) || "не задано"
                            color: cb.cap ? Theme.accent : win.value(cb.r) ? Theme.blue : Theme.bg2
                        }
                        TextInput {
                            visible: cb.edit
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: win.cw * 0.6; rightMargin: win.cw * 0.6 }
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            renderType: Text.NativeRendering
                            onVisibleChanged: if (visible) { text = String(win.value(cb.r)); selectAll(); forceActiveFocus(); }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.finishEdit(true, text);
                                else if (event.key === Qt.Key_Escape) win.finishEdit(false, "");
                                else return;
                                event.accepted = true;
                            }
                        }
                        MouseArea {
                            id: cbHover
                            anchors.fill: parent
                            visible: !cb.edit
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.focusRow(cb.idx); win.capturing = true; }
                        }
                    }
                    T {
                        visible: !!win.value(cb.r) && !cb.cap
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.iconFont
                        text: String.fromCodePoint(0xF0156)
                        color: cbx.containsMouse ? Theme.red : Theme.gray
                        MouseArea { id: cbx; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.focusRow(cb.idx); win.reset(win.rows[cb.idx]); } }
                    }
                }
            }

            // действие — кнопка
            Component {
                id: actionC
                Rectangle {
                    id: ac
                    readonly property var r: parent.r
                    implicitWidth: acT.implicitWidth + win.cw * 3
                    implicitHeight: acT.implicitHeight + 6
                    color: acHover.pressed ? Theme.accent : acHover.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
                    border.color: acHover.containsMouse || parent.current ? Theme.accent : Theme.bg2
                    border.width: 1
                    T {
                        id: acT
                        anchors.centerIn: parent
                        text: win.opens.includes(ac.r.action) ? "открыть" : "выполнить"
                        color: acHover.pressed ? Theme.bg : Theme.accent
                    }
                    MouseArea {
                        id: acHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.runAction(ac.r.action)
                    }
                }
            }
        }
    }
}
