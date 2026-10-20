import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.settings
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
            if (S.defaultOf(key, Settings.outputs) === undefined) return I18n.tr("неизвестный ключ: %1", key);
            if (value === "") { Settings.reset(key); return I18n.tr("по умолчанию: %1", JSON.stringify(Settings.get(key))); }
            let v = value;
            try { v = JSON.parse(value); } catch (e) {}
            const row = S.find(key, Settings.outputs);
            if (row?.options && !row.options.includes(v)) return I18n.tr("допустимо: %1", row.options.join(", "));
            Settings.set(key, v);
            return JSON.stringify(Settings.get(key));
        }
        function get(key: string): string { return JSON.stringify(Settings.get(key)) ?? I18n.tr("неизвестный ключ: %1", key); }
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
            readonly property string query: sidebar.search.text.trim()
            readonly property var rows: query ? S.searchRows(sections, query, s => I18n.tr(s)) : sections[section].rows
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
                sidebar.search.text = "";
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
                case "notifyTest": Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Проверка уведомления"), I18n.tr("так выглядит анимация %1", Settings.get("shell.notify.anim"))]); break;
                case "wifi": Term.float(["nmtui"]); break;
                case "audio": Quickshell.execDetached(["pavucontrol"]); break;
                case "editNiri": Term.edit(Quickshell.env("HOME") + "/.config/niri/config.kdl"); break;
                case "editShell": Term.edit(Quickshell.shellDir); break;
                case "editTerminal": Term.edit(Term.configPath); break;
                case "shellUpdate":
                    if (Ochre.system)
                        Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("ochre поставлен пакетом"),
                            I18n.tr("Обновляется вместе с системой; после обновления придёт уведомление с перезапуском shell.")]);
                    else if (ShellUpdate.behind > 0) ShellUpdate.update();
                    else ShellUpdate.check(true);
                    break;
                case "shellRollback": ShellUpdate.rollback(); break;
                case "restartShell": ShellUpdate.restartShell(); break;
                case "report": Errors.report(); break;
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
            property var dropItem: null   // кнопка списка: по ней dropBox считает своё место
            function openDrop(i, item) {
                focusRow(i);
                dropItem = item;
                drop = i;
            }

            function startSearch() {
                sidebar.search.forceActiveFocus();
                sidebar.search.selectAll();
            }

            function endSearch(keep) {
                if (!keep) sidebar.search.text = "";
                keys.forceActiveFocus();
            }

            function fmt(r, v) {
                if (v === undefined) v = shown(r);
                if (r.type === "module") return "‹ " + S.zoneLabel(r.key, v) + " ›";
                if (r.type === "bool") return v ? "[x]" : "[ ]";
                if (r.type === "text") return JSON.stringify(v);
                if (r.type === "combo") return capturing && r === row ? I18n.tr("нажмите сочетание…") : v ? "[" + v + "]" : "—";
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
                if (r.type === "module") return I18n.tr(r.hint);
                const file = S.niriFileOf(r.key);
                // файл первым: подсказка длинная и обрезается справа
                const parts = [file ? "niri/ochre/" + file : "", I18n.tr(r.hint ?? "")];
                if (r.type === "combo" && value(r)) {
                    if (!S.COMBO_RE.test(value(r))) parts.unshift(I18n.tr("не похоже на сочетание (Mod+Shift+M) — бинд не создан"));
                    const other = Binds.conflict(value(r), r.action);
                    if (other) parts.unshift(I18n.tr("занято: %1 — конфликт", other.action));
                }
                if (r.type !== "action") parts.push(r.key + "  ·  " + I18n.tr("по умолчанию %1", JSON.stringify(r.def)));
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
                if (r.type === "module") return ({ off: I18n.tr("выкл"), on: I18n.tr("вкл") })[o] ?? I18n.tr(S.zoneLabel(r.key, o));
                return r.labels?.[o] ?? String(o);
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
            readonly property real cellH: cell.height

            // ссылки для компонентов settings/: у них свои свойства win/box/ghost, и `win: win` в них указал бы
            // на само свойство, а не на id окна
            QtObject {
                id: refs
                readonly property var w: win
                readonly property Item b: box
                readonly property Item g: ghost
                readonly property Item f: flick
            }

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
                        Sidebar {
                            id: sidebar
                            Layout.fillHeight: true
                            Layout.preferredWidth: win.cw * 24
                            win: refs.w
                            flick: refs.f
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
                                text: I18n.tr("ничего не найдено")
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
                                                text: win.query ? card.modelData.header : I18n.tr(card.modelData.header)
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
                                                delegate: SettingRow { win: refs.w; box: refs.b; ghost: refs.g }
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
                                ? [["↵", I18n.tr("применить")], ["esc", I18n.tr("отмена")], ["←→", I18n.tr("значение")]]
                                : win.capturing
                                ? [["…", I18n.tr("нажмите сочетание")], ["⇥", I18n.tr("текстом")], ["⌫", I18n.tr("убрать")], ["esc", I18n.tr("отмена")]]
                                : win.editing
                                ? [["↵", I18n.tr("сохранить")], ["esc", I18n.tr("отмена")]]
                                : [["↑↓", I18n.tr("выбор")], ["←→", I18n.tr("изменить")], ["↵", I18n.tr("открыть")], ["r", I18n.tr("сброс")], ["/", I18n.tr("поиск")], ["esc", win.query ? I18n.tr("сбросить поиск") : I18n.tr("выход")]])
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
                DropList { win: refs.w; flick: refs.f; box: refs.b }
            }
        }
    }
}
