import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
// секции грузятся через Loader по URL — импорт нужен, чтобы quickshell просканировал home/
import qs.home
import "services/settings.js" as S

// Меню home: переключатели, звук, медиа, погода, календарь, todo, уведомления, система, питание, Wi-Fi, bluetooth, действия.
// Состав и порядок секций — в настройках (Mod+S → home/), сами секции — home/<Name>.qml на базе home/Section.qml.
// Вид — shell.home.style, секции одни и те же, меняется только раскладка:
//   control   — центр управления под панелью (как в DMS): карточки, wi-fi и bluetooth — страницами по › на плитке
//   column    — колонка у края во всю высоту, секции карточками
//   dashboard — широкое окно посередине, три колонки карточек (колонка секции — dash в HOME_SECTIONS)
//   classic   — колонка у края, секции строками «── title ──»
// В карточных видах заголовок карточки сворачивает её (shell.home.collapsed).
// Открывают клик по user@host, Mod+A, `qs ipc call home toggle` (services/Home.qml).
// Клавиши: ↑↓ / j k — элементы и секции, ←→ / h l — внутри строки, ↵ / Space — действие,
// Tab / ⇧Tab — следующая / предыдущая секция, o — страница плитки (control), Esc / q — назад со страницы, закрыть.
Scope {
    id: root

    readonly property string style: Settings.get("shell.home.style")
    readonly property bool edgeStyle: style === "column" || style === "classic"

    // окно живёт, пока доигрывает закрытие (Reveal.qml); slide — от края (у дашборда — сверху)
    Reveal {
        id: reveal
        open: Home.open
        style: Settings.get("shell.home.anim")
        duration: 180
        edge: root.style === "dashboard" ? "top" : Settings.get("shell.home.side")
    }

    LazyLoader {
        active: reveal.loaded

        PanelWindow {
            id: win

            readonly property string style: root.style
            readonly property bool cards: style !== "classic"
            readonly property bool right: Settings.get("shell.home.side") === "right"
            readonly property var ids: S.normalizeLayout(Settings.get("shell.home.layout"), "shell.home.layout").on
            readonly property var collapsed: Settings.get("shell.home.collapsed") ?? []

            // панель остаётся доступной: окно начинается под ней (или кончается над ней)
            readonly property bool barHere: !Settings.get("shell.bar.autohide")
                && (Settings.get("shell.bar.monitors") === "all" || screen === Quickshell.screens[0])
            readonly property bool barTop: Settings.get("shell.bar.position") === "top"
            readonly property int barSpace: !barHere ? 0
                : Theme.barHeight + (Settings.get("shell.bar.style") === "floating" ? 4 + 8 : 0)

            screen: Quickshell.screens.find(s => s.name === Home.screenName) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            margins { top: barTop ? barSpace : 0; bottom: barTop ? 0 : barSpace }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: Home.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "ochre-home"

            function close() { Home.open = false; }

            // ── что где: главная колонка, колонки дашборда, страница ──
            // страница (control): wi-fi и bluetooth открываются по › на плитке, если плитки есть
            property string page: ""
            readonly property bool paged: style === "control" && ids.includes("quick")
            function canPage(id) { return paged && ids.includes(id); }
            function openPage(id) { if (canPage(id)) { page = id; sec = -1; } }
            function closePage() { page = ""; sec = -1; keys.forceActiveFocus(); }
            onStyleChanged: { page = ""; sec = -1; }
            Connections { target: Home; function onPageRequested(id) { win.openPage(id); } }

            readonly property var mainIds: style === "dashboard" ? []
                : paged ? ids.filter(id => id !== "wifi" && id !== "bluetooth") : ids
            function dashIds(c) {
                return style === "dashboard" ? ids.filter(id => (S.moduleById(id, "shell.home.layout")?.dash ?? 0) === c) : [];
            }

            function toggleCollapsed(id) {
                const c = collapsed.includes(id) ? collapsed.filter(x => x !== id) : collapsed.concat([id]);
                Settings.set("shell.home.collapsed", c);
            }

            // ── фокус: какая секция, какой элемент в ней ──
            // слоты в порядке обхода: страница — только она, дашборд — по колонкам слева направо
            function slots() {
                const reps = page ? [repPage] : style === "dashboard" ? [rep0, rep1, rep2] : [repMain];
                const out = [];
                for (const r of reps)
                    for (let i = 0; i < r.count; i++) {
                        const it = r.itemAt(i);
                        if (it) out.push(it);
                    }
                return out;
            }

            property int sec: -1

            function sectionAt(i) {
                const sl = slots()[i];
                const it = sl?.item;
                return sl && sl.shown && !sl.folded && it && it.count > 0 ? it : null;
            }

            function indexOf(s) {
                return slots().findIndex(sl => sl.item === s);
            }

            function setSection(i, fromEnd) {
                for (const sl of slots()) if (sl.item && sl.item !== sectionAt(i)) sl.item.focused = false;
                sec = i;
                const s = sectionAt(i);
                if (!s) return;
                if (fromEnd !== undefined) s.cur = fromEnd ? s.count - 1 : 0;
                s.cur = Math.max(0, Math.min(s.count - 1, s.cur));
                s.focused = true;
                ensureVisible(s);
            }

            function focusSection(s) {
                const i = indexOf(s);
                if (i >= 0) setSection(i);
                keys.forceActiveFocus();
            }

            // следующая (d = 1) или предыдущая секция с элементами; null — дальше некуда
            function neighbour(d) {
                const n = slots().length;
                for (let i = sec + d; i >= 0 && i < n; i += d)
                    if (sectionAt(i)) return i;
                return null;
            }

            function move(d) {
                const s = sectionAt(sec);
                if (s && s.cur + d >= 0 && s.cur + d < s.count) {
                    s.cur += d;
                    ensureVisible(s);
                    return;
                }
                const n = neighbour(d);
                if (n !== null) setSection(n, d < 0);
            }

            function jump(d) {
                const n = neighbour(d);
                if (n !== null) setSection(n, false);
            }

            // секция целиком в видимой области, если влезает; иначе — её начало
            function ensureVisible(s) {
                const y = s.mapToItem(content, 0, 0).y;
                const h = s.height;
                if (y < flick.contentY) flick.contentY = y;
                else if (y + h > flick.contentY + flick.height)
                    flick.contentY = Math.min(y, y + h - flick.height);
            }

            // секции грузятся не сразу — фокус на первую, как только она появится
            Timer {
                interval: 50
                running: win.sec < 0
                repeat: true
                onTriggered: { const n = win.neighbour(1) ?? null; if (n !== null) win.setSection(n, false); }
            }

            // ширина символа — секциям для отступов и полосок
            readonly property alias cell: cellM

            TextMetrics {
                id: cellM
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            readonly property real colW: cellM.advanceWidth * Settings.get("shell.home.width")
            readonly property real gap: Theme.pad
            // высота «по содержимому» у control и dashboard, во всю высоту — у колонок
            readonly property real chrome: title.implicitHeight + hints.implicitHeight + Theme.pad * 3
            readonly property real fitH: Math.min(height - gap * 2, content.implicitHeight + chrome)

            // клик мимо панели закрывает её
            MouseArea {
                anchors.fill: parent
                onClicked: win.close()
            }

            Rectangle {
                id: box

                width: win.style === "dashboard"
                    ? Math.min(win.width - win.gap * 4, win.colW * 3 + Theme.pad * 4 + Theme.pad * 2)
                    : win.colW + Theme.pad * 2
                height: root.edgeStyle ? win.height : win.fitH
                x: win.style === "dashboard" ? (win.width - width) / 2
                    : win.style === "control" ? (win.right ? win.width - width - win.gap : win.gap)
                    : (win.right ? win.width - width : 0)
                y: win.style === "dashboard" ? Math.max(win.gap, (win.height - height) / 3)
                    : win.style === "control" ? (win.barTop ? win.gap : win.height - height - win.gap)
                    : 0
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                opacity: reveal.alpha
                scale: reveal.zoom
                transform: [
                    Translate { x: reveal.dx; y: reveal.dy },
                    Scale { yScale: reveal.ys }
                ]

                Binding { target: reveal; property: "distance"; value: root.style === "dashboard" ? 40 : box.width }

                MouseArea { anchors.fill: parent }

                Rectangle {
                    x: Theme.pad
                    y: root.edgeStyle ? 0 : -height / 2
                    z: 1
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T { id: title; text: "[ ~/home/" + Sys.user + "/" + (win.page ? win.page + "/" : "") + " ]"; color: Theme.accent; font.bold: true }
                }

                Item {
                    id: keys
                    focus: true

                    Keys.onPressed: event => {
                        const k = event.key;
                        const s = win.sectionAt(win.sec);
                        if (s && s.key(event)) {
                            // секция обработала сама
                        } else if ((k === Qt.Key_Escape || k === Qt.Key_Q || k === Qt.Key_Backspace) && win.page) {
                            win.closePage();
                        } else if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                            win.close();
                        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                            win.move(1);
                        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                            win.move(-1);
                        } else if (k === Qt.Key_Tab) {
                            win.jump(1);
                        } else if (k === Qt.Key_Backtab) {
                            win.jump(-1);
                        } else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && s) {
                            s.activate(s.cur);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                Flickable {
                    id: flick

                    anchors {
                        fill: parent; margins: Theme.pad
                        topMargin: title.implicitHeight + (win.cards ? Theme.pad / 2 : 0)
                        bottomMargin: hints.implicitHeight + Theme.pad
                    }
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Behavior on contentY { NumberAnimation { duration: 80 } }

                    Item {
                        id: content
                        width: flick.width
                        implicitHeight: win.page ? pageCol.implicitHeight
                            : win.style === "dashboard" ? dashRow.implicitHeight : mainCol.implicitHeight

                        // главная колонка: control, column, classic
                        ColumnLayout {
                            id: mainCol
                            visible: !win.page && win.style !== "dashboard"
                            width: parent.width
                            spacing: win.cards ? Theme.pad : 6
                            Repeater { id: repMain; model: win.mainIds; delegate: slot }
                        }

                        // дашборд: три колонки
                        RowLayout {
                            id: dashRow
                            visible: !win.page && win.style === "dashboard"
                            width: parent.width
                            spacing: Theme.pad * 2
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: Theme.pad
                                Repeater { id: rep0; model: win.dashIds(0); delegate: slot }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: Theme.pad
                                Repeater { id: rep1; model: win.dashIds(1); delegate: slot }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: Theme.pad
                                Repeater { id: rep2; model: win.dashIds(2); delegate: slot }
                            }
                        }

                        // страница: ‹ назад и одна секция целиком
                        ColumnLayout {
                            id: pageCol
                            visible: win.page !== ""
                            width: parent.width
                            spacing: Theme.pad
                            T {
                                font.family: Theme.iconFont
                                text: String.fromCodePoint(0xF0141) + " назад"
                                color: backHover.containsMouse ? Theme.accent : Theme.gray
                                MouseArea { id: backHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.closePage() }
                            }
                            Repeater { id: repPage; model: win.page ? [win.page] : []; delegate: slot }
                            // секция страницы недоступна (нет адаптера) — сказать об этом, а не показывать пустоту
                            T {
                                visible: win.page !== "" && !(repPage.itemAt(0)?.shown ?? false)
                                text: win.page === "wifi" ? "нет Wi-Fi-адаптера" : "нет bluetooth-адаптера"
                                color: Theme.gray
                            }
                        }
                    }
                }

                T {
                    id: hints
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.pad }
                    textFormat: Text.StyledText
                    color: Theme.gray
                    elide: Text.ElideRight
                    text: (win.page ? [["↑↓", "выбор"], ["↵", "действие"], ["esc", "назад"]]
                        : [["↑↓", "выбор"], ["←→", "изменить"], ["↵", "действие"], ["⇥", "секция"], ["esc", "закрыть"]])
                        .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("  ")
                }
            }

            // слот секции: в карточных видах — рамка с заголовком на линии, клик по нему сворачивает
            Component {
                id: slot

                Item {
                    id: sl
                    required property string modelData
                    readonly property var info: S.moduleById(modelData, "shell.home.layout")
                    readonly property var item: loader.item
                    readonly property bool shown: item !== null && item.available !== false
                    readonly property bool folded: win.cards && win.collapsed.includes(modelData) && !win.page
                    // заголовок карточки стоит на верхней линии рамки — рамка начинается с его середины
                    readonly property real head: win.cards ? cardTitle.implicitHeight : 0

                    Layout.fillWidth: true
                    visible: shown
                    implicitHeight: !shown ? 0 : !win.cards ? loader.implicitHeight
                        : folded ? head + Theme.pad / 2 : head + loader.implicitHeight + Theme.pad

                    Rectangle {
                        visible: win.cards
                        y: sl.head / 2
                        width: parent.width
                        height: parent.height - sl.head / 2
                        color: "transparent"
                        border.color: sl.item?.focused ? Qt.darker(Theme.accent, 1.5) : Theme.bg2
                        border.width: 1
                    }

                    // заголовок: ▾ погода · Витязево — клик сворачивает карточку
                    Rectangle {
                        visible: win.cards
                        x: Theme.pad
                        z: 2
                        width: cardTitle.implicitWidth + cellM.advanceWidth
                        height: cardTitle.implicitHeight
                        color: Theme.bg
                        T {
                            id: cardTitle
                            anchors.centerIn: parent
                            textFormat: Text.StyledText
                            text: `<font face="${Theme.iconFont}">${String.fromCodePoint(sl.folded ? 0xF0142 : 0xF0140)}</font> ${sl.item?.title ?? sl.info?.label ?? ""}`
                            color: sl.item?.focused ? Theme.accent : titleHover.containsMouse ? Theme.fg : Theme.gray
                            font.bold: true
                        }
                        MouseArea {
                            id: titleHover
                            anchors.fill: parent
                            enabled: !win.page
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.toggleCollapsed(sl.modelData); win.sec = -1; }
                        }
                    }

                    Loader {
                        id: loader
                        x: win.cards ? Theme.pad : 0
                        y: win.cards ? sl.head + Theme.pad / 4 : 0
                        width: parent.width - (win.cards ? Theme.pad * 2 : 0)
                        visible: !sl.folded
                        Component.onCompleted: setSource(Qt.resolvedUrl("home/" + sl.info.file + ".qml"), { panel: win, bare: win.cards })
                    }
                    Binding { target: loader.item; property: "bare"; value: win.cards; when: loader.item !== null }
                }
            }

            // колонка во всю высоту: построчно печать шла бы сверху вниз и почти не видна — все строки сразу, слева направо
            TypeOn {
                anchors.fill: parent
                source: box
                direction: root.edgeStyle ? "columns" : "rows"
                p: reveal.p
                active: reveal.printing
            }
        }
    }
}
