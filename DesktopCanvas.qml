import Quickshell
import QtQuick
import qs.services
// виджеты грузятся через Loader по URL — импорт нужен, чтобы quickshell просканировал desktop/
import qs.desktop
import "services/settings.js" as S

// Виджеты одного монитора (DesktopWidgets.qml): на нижнем слое под окнами и в режиме правки поверх всего.
// Виджет — desktop/<file>.qml (S.WIDGETS) в рамке с заголовком на линии; рамка и фон — у каждого свои (frame, bg).
// В режиме правки: клик — выбрать, перетаскивание — сдвинуть, уголок ◢ — размер, двойной клик — писать (стикер, картинка);
// всё по сетке символа. Клавиши — у окна правки, оно зовёт move / resize / write.
Item {
    id: canvas

    property string output: ""
    property bool editing: false
    property string selected: ""
    property bool writing: false      // стикер или картинка: печатается текст, клавиши — полю
    readonly property real cw: cell.advanceWidth
    readonly property real ch: cell.height

    // области ввода нижнего слоя: только сами виджеты, мимо них клик уходит столу
    property int rev: 0
    readonly property var regions: {
        rev;
        const out = [];
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it) out.push(it.rgn);
        }
        return out;
    }

    readonly property var screens: Quickshell.screens.map(s => s.name)
    readonly property var list: S.widgetsOn(Desktop.widgets, output, screens)
    // делегаты пересоздаются, только когда меняется состав: правка положения или текста их не трогает
    readonly property string idKey: list.map(w => w.id).sort().join(",")

    function snap(v, step) { return Math.round(v / step) * step; }

    function item(id) {
        for (let i = 0; i < rep.count; i++)
            if (rep.itemAt(i)?.wid === id) return rep.itemAt(i);
        return null;
    }

    // сдвиг и размер выбранного — в клетках символа
    function move(dx, dy) {
        const it = item(selected);
        if (it) it.commit(it.x + dx * cw, it.y + dy * ch, it.width, it.height);
    }

    function resize(dw, dh) {
        const it = item(selected);
        if (it) it.commit(it.x, it.y, it.width + dw * cw, it.height + dh * ch);
    }

    function write() {
        const it = item(selected);
        if (it && it.canWrite) writing = true;
    }

    onSelectedChanged: writing = false
    onEditingChanged: writing = false

    TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

    // картинку можно бросить на стол: на выбранную картинку — заменить, иначе — новая там, где отпустили
    DropArea {
        anchors.fill: parent
        enabled: canvas.editing
        keys: ["text/uri-list"]
        onDropped: drop => {
            const url = (drop.urls ?? [])[0];
            const path = url ? decodeURIComponent(String(url).replace(/^file:\/\//, "")) : "";
            if (!/\.(png|jpe?g|webp|gif|bmp|svg|avif)$/i.test(path)) return;
            const cur = Desktop.widgets.find(w => w.id === canvas.selected);
            if (cur?.type === "image") { Desktop.update(cur.id, { path }); return; }
            const w = S.newWidget("image", canvas.output, canvas.cw / canvas.width, canvas.ch / canvas.height, Date.now());
            w.path = path;
            w.x = Math.max(0, Math.min(1 - w.w, drop.x / canvas.width - w.w / 2));
            w.y = Math.max(0, Math.min(1 - w.h, drop.y / canvas.height - w.h / 2));
            Desktop.add(w);
            canvas.selected = w.id;
        }
    }

    Repeater {
        id: rep

        model: canvas.idKey ? canvas.idKey.split(",") : []

        Item {
            id: card

            required property string modelData
            readonly property string wid: modelData
            readonly property var cfg: Desktop.widgets.find(w => w.id === wid) ?? null
            readonly property var info: S.widgetById(cfg?.type)
            readonly property bool chosen: canvas.editing && canvas.selected === wid
            readonly property bool canWrite: cfg?.type === "sticker" || cfg?.type === "image"
            readonly property real minW: (info?.min[0] ?? 4) * canvas.cw
            readonly property real minH: (info?.min[1] ?? 2) * canvas.ch

            // пока тянут мышью — свои координаты, отпустили — в настройки
            property bool live: false
            property real lx: 0
            property real ly: 0
            property real lw: 0
            property real lh: 0

            readonly property Region rgn: Region { item: card }

            x: live ? lx : canvas.snap((cfg?.x ?? 0) * canvas.width, canvas.cw)
            y: live ? ly : canvas.snap((cfg?.y ?? 0) * canvas.height, canvas.ch)
            width: live ? lw : canvas.snap((cfg?.w ?? 0.1) * canvas.width, canvas.cw)
            height: live ? lh : canvas.snap((cfg?.h ?? 0.1) * canvas.height, canvas.ch)
            z: Desktop.widgets.findIndex(w => w.id === wid)

            Component.onCompleted: canvas.rev++
            Component.onDestruction: canvas.rev++

            function clampBox(x, y, w, h) {
                const ww = Math.min(canvas.width, Math.max(minW, canvas.snap(w, canvas.cw)));
                const hh = Math.min(canvas.height, Math.max(minH, canvas.snap(h, canvas.ch)));
                return {
                    x: Math.max(0, Math.min(canvas.width - ww, canvas.snap(x, canvas.cw))),
                    y: Math.max(0, Math.min(canvas.height - hh, canvas.snap(y, canvas.ch))),
                    w: ww, h: hh
                };
            }

            function hold(x, y, w, h) {
                const b = clampBox(x, y, w, h);
                lx = b.x; ly = b.y; lw = b.w; lh = b.h;
                live = true;
            }

            function commit(x, y, w, h) {
                const b = clampBox(x, y, w, h);
                Desktop.update(wid, { x: b.x / canvas.width, y: b.y / canvas.height, w: b.w / canvas.width, h: b.h / canvas.height });
                live = false;
            }

            Rectangle {
                id: box
                anchors.fill: parent
                color: card.cfg?.bg === "solid" ? Theme.bg
                    : card.cfg?.bg === "dim" ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
                    : "transparent"
                border.width: card.chosen ? 2 : card.cfg?.frame || canvas.editing ? 1 : 0
                border.color: card.chosen ? Theme.accent : canvas.editing && !card.cfg?.frame ? Theme.bg3 : Theme.bg2
            }

            // заголовок на линии рамки
            Rectangle {
                visible: card.cfg?.frame || canvas.editing
                x: canvas.cw
                y: -height / 2
                width: title.implicitWidth
                height: title.implicitHeight
                color: card.cfg?.bg === "none" ? "transparent" : Theme.bg
                T {
                    id: title
                    text: " " + I18n.tr(card.info?.label ?? "") + " "
                    color: card.chosen ? Theme.accent : Theme.gray
                    font.bold: card.chosen
                }
            }

            Loader {
                id: body
                anchors { fill: parent; leftMargin: canvas.cw; rightMargin: canvas.cw; topMargin: canvas.ch * 0.75; bottomMargin: canvas.ch * 0.5 }
                clip: true
                source: card.info ? Qt.resolvedUrl("desktop/" + card.info.file + ".qml") : ""
                onLoaded: {
                    item.cfg = Qt.binding(() => card.cfg);
                    item.cw = Qt.binding(() => canvas.cw);
                    item.ch = Qt.binding(() => canvas.ch);
                    item.editing = Qt.binding(() => canvas.editing);
                }
            }
            Binding {
                target: body.item
                property: "writing"
                value: card.chosen && canvas.writing
                when: body.item !== null && card.canWrite
            }

            // режим правки: выбрать и тащить; поверх содержимого, кроме поля, в которое пишут
            MouseArea {
                anchors.fill: parent
                enabled: canvas.editing && !(card.chosen && canvas.writing)
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property point origin
                onPressed: mouse => {
                    canvas.selected = card.wid;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    start = Qt.point(p.x, p.y);
                    origin = Qt.point(card.x, card.y);
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    card.hold(origin.x + p.x - start.x, origin.y + p.y - start.y, card.width, card.height);
                }
                onReleased: if (card.live) card.commit(card.lx, card.ly, card.lw, card.lh)
                onDoubleClicked: canvas.write()
            }

            // уголок размера
            T {
                visible: card.chosen
                anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
                text: "◢"
                color: Theme.accent
                MouseArea {
                    anchors { fill: parent; margins: -6 }
                    cursorShape: Qt.SizeFDiagCursor
                    preventStealing: true
                    property point start
                    property size origin
                    onPressed: mouse => {
                        const p = mapToItem(canvas, mouse.x, mouse.y);
                        start = Qt.point(p.x, p.y);
                        origin = Qt.size(card.width, card.height);
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const p = mapToItem(canvas, mouse.x, mouse.y);
                        card.hold(card.x, card.y, origin.width + p.x - start.x, origin.height + p.y - start.y);
                    }
                    onReleased: if (card.live) card.commit(card.lx, card.ly, card.lw, card.lh)
                }
            }
        }
    }
}
