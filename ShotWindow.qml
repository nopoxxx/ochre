import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.services
import "services/settings.js" as S

// Скриншот с разметкой (по мотивам rishot, github.com/ryoku-dev/ryoshot, MIT).
// Экраны замирают (ScreencopyView, live: false): тянешь область, клик или Space — весь экран, w — окно
// (niri pick-window → screenshot-window: окно целиком, и тайловое тоже). Дальше — разметка поверх и экспорт:
// ↵ — действие из настроек (system/ → скриншоты), ^C — копировать, ^S — сохранить, ^O — текст (tesseract) в буфер.
// i — пипетка (niri pick-color: цвет под курсором в буфер как #rrggbb).
// Разметка хранится в координатах экрана, область только обрезает — её можно менять ручками, не сдвигая нарисованное.
// Экспорт — grabToImage обрезки (замороженный кадр + эффекты + разметка) в родном разрешении экрана.
//   qs ipc call shot region   — область / экран (Mod+Shift+S, Print)
//   qs ipc call shot window   — сразу выбор окна
//   qs ipc call shot edit <путь> — разметить готовую картинку
//   qs ipc call shot ocr      — выбрать область и сразу распознать текст (Mod+Shift+T)
//   qs ipc call shot pick     — пипетка (Mod+Shift+C)
Scope {
    id: root

    property bool open: false
    property string phase: "select"     // select — выбор области, edit — разметка
    property string mode: "screen"      // screen — замороженный экран, window — снимок окна
    property string target: ""          // экран, на котором идёт работа
    property var sel: null              // область в координатах экрана target: {x, y, w, h}
    property var bounds: null           // куда можно растянуть область: экран или снимок окна
    property bool dragging: false
    property var anns: []               // разметка: {tool, color, width, fill, pts | x/y/w/h, text, n}
    property var redoStack: []
    property var draft: null            // фигура, которую рисуют сейчас
    property var textAt: null           // {x, y} — вводится текст
    property string windowPng: ""
    property var cropRef: null          // обрезка на экране target — её и снимаем
    property real factor: 1             // пикселей экрана на логический пиксель
    property string message: ""
    property double textClosedAt: 0     // Enter, закончивший ввод текста, не должен запускать экспорт
    property string then: ""            // действие сразу после выбора области (shot ocr), без разметки

    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ochre-shot"

    // ── инструменты и палитра ──
    readonly property var tools: [
        { id: "rect", key: "r", label: "rect" }, { id: "ellipse", key: "e", label: "ellipse" },
        { id: "line", key: "l", label: "line" }, { id: "arrow", key: "a", label: "arrow" },
        { id: "pen", key: "p", label: "pen" }, { id: "marker", key: "m", label: "marker" },
        { id: "text", key: "t", label: "text" }, { id: "step", key: "n", label: "step" },
        { id: "blur", key: "b", label: "blur" }, { id: "pixel", key: "x", label: "pixel" }
    ]
    readonly property var colors: [Theme.red, Theme.orange, Theme.yellow, Theme.green, Theme.aqua,
        Theme.blue, Theme.purple, Theme.fg, Theme.bg]
    readonly property string tool: Settings.get("shell.shot.tool")
    readonly property int colorIdx: Math.max(0, S.SHOT_COLORS.indexOf(Settings.get("shell.shot.color")))
    readonly property color color: colors[colorIdx]
    readonly property int strokeW: Settings.get("shell.shot.width")
    property bool fill: false
    readonly property var effects: anns.concat(draft ? [draft] : []).filter(a => a.tool === "blur" || a.tool === "pixel")
    readonly property var marks: anns.filter(a => a.tool === "step" || a.tool === "text")

    function textSize(w) { return 12 + w * 4; }

    IpcHandler {
        target: "shot"
        function region(): void { root.start("screen"); }
        function window(): void { root.start("window"); }
        function edit(path: string): void { root.openImage(path); }
        function ocr(): void { root.start("screen", "ocr"); }
        function pick(): void { root.pickColor(); }
    }

    function reset() {
        sel = null;
        bounds = null;
        anns = [];
        redoStack = [];
        draft = null;
        textAt = null;
        dragging = false;
        message = "";
        fill = false;
    }

    function start(m, then) {
        if (open || picker.running || winShot.running) { close(); return; }
        reset();
        root.then = then ?? "";
        // папка для shot.png — заранее: saveToFile в несуществующую папку молча падает
        Quickshell.execDetached(["mkdir", "-p", tmp]);
        target = Niri.focusedWorkspace?.output ?? Quickshell.screens[0]?.name ?? "";
        if (m === "window") pickWindow();
        else {
            mode = "screen";
            phase = "select";
            open = true;
        }
    }

    function close() {
        open = false;
        reset();
    }

    // область выбрана, а действие уже задано (shot ocr) — выполнить сразу; таймер — чтобы обрезка успела встать
    onPhaseChanged: if (phase === "edit" && then) thenTimer.start()
    Timer { id: thenTimer; interval: 50; onTriggered: root.exportShot(root.then) }

    // ── пипетка: niri сам ждёт клика и печатает «Hex: #rrggbb» ──
    function pickColor() {
        close();
        if (!colorPicker.running) colorPicker.running = true;
    }

    Process {
        id: colorPicker
        command: ["niri", "msg", "pick-color"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = (text.match(/#[0-9a-fA-F]{6}/) ?? [""])[0];
                if (!hex) return;   // Esc
                const rgb = (text.match(/rgb\([^)]*\)/) ?? [""])[0];
                Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy; notify-send -a ochre "$3" "$1  $2"',
                    "sh", hex, rgb, I18n.tr("Цвет скопирован")]);
            }
        }
    }

    // ── окно: niri сам ждёт клика по окну, потом снимает его целиком ──
    function pickWindow() {
        open = false;
        picker.running = true;
    }

    Process {
        id: picker
        command: ["niri", "msg", "--json", "pick-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                let w = null;
                try { w = JSON.parse(text); } catch (e) {}
                if (!w || w.id === undefined) return;   // Esc в pick-window
                winShot.command = ["sh", "-c", `
                    mkdir -p "$1"; rm -f "$1/window.png"
                    niri msg action screenshot-window --id "$2" --path "$1/window.png" --write-to-disk true || exit 1
                    # niri пишет файл в фоне — ждём его
                    for i in $(seq 60); do [ -s "$1/window.png" ] && exit 0; sleep 0.05; done; exit 1`,
                    "sh", root.tmp, String(w.id)];
                winShot.running = true;
            }
        }
    }

    Process {
        id: winShot
        onExited: code => {
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "ochre", I18n.tr("Скриншот"), I18n.tr("niri не отдал снимок окна")]);
                return;
            }
            root.openImage(root.tmp + "/window.png");
        }
    }

    // картинка вместо замороженного экрана: снимок окна или любой файл
    function openImage(path) {
        if (open) close();
        reset();
        Quickshell.execDetached(["mkdir", "-p", tmp]);
        target = Niri.focusedWorkspace?.output ?? Quickshell.screens[0]?.name ?? "";
        windowPng = "file://" + encodeURI(path) + "?" + Date.now();   // ?… — без кэша: файл тот же, снимок новый
        mode = "window";
        phase = "edit";
        open = true;
    }

    // ── разметка ──
    function norm(a, b) {
        return { x: Math.min(a.x, b.x), y: Math.min(a.y, b.y), w: Math.abs(b.x - a.x), h: Math.abs(b.y - a.y) };
    }

    function begin(p) {
        if (tool === "text") { textAt = p; return; }
        if (tool === "step") {
            push({ tool: "step", color: String(color), width: strokeW, x: p.x, y: p.y, n: anns.filter(a => a.tool === "step").length + 1 });
            return;
        }
        draft = { tool, color: String(color), width: strokeW, fill, a: p, b: p, pts: [p] };
    }

    function extend(p) {
        if (!draft) return;
        const d = Object.assign({}, draft);
        d.b = p;
        if (d.tool === "pen" || d.tool === "marker") d.pts = d.pts.concat([p]);
        draft = d;
    }

    function finishDraft() {
        if (!draft) return;
        const d = draft;
        draft = null;
        const r = norm(d.a, d.b);
        const tiny = (d.tool === "pen" || d.tool === "marker") ? d.pts.length < 2 : Math.max(r.w, r.h) < 3;
        if (tiny) return;
        if (d.tool === "blur" || d.tool === "pixel" || d.tool === "rect" || d.tool === "ellipse")
            Object.assign(d, r);
        push(d);
    }

    function commitText(s) {
        if (textAt && s.trim()) push({ tool: "text", color: String(color), width: strokeW, x: textAt.x, y: textAt.y, text: s });
        if (textAt) textClosedAt = Date.now();
        textAt = null;
    }

    function push(a) {
        anns = anns.concat([a]);
        redoStack = [];
    }

    function undo() {
        if (!anns.length) return;
        redoStack = redoStack.concat([anns[anns.length - 1]]);
        anns = anns.slice(0, -1);
    }

    function redo() {
        if (!redoStack.length) return;
        anns = anns.concat([redoStack[redoStack.length - 1]]);
        redoStack = redoStack.slice(0, -1);
    }

    function setTool(id) { Settings.set("shell.shot.tool", id); }
    function setColor(i) { Settings.set("shell.shot.color", S.SHOT_COLORS[i]); }
    function setWidth(w) { Settings.set("shell.shot.width", Math.max(1, Math.min(12, w))); }

    function paintAnn(ctx, a) {
        if (["blur", "pixel", "step", "text"].includes(a.tool)) return;
        ctx.save();
        ctx.strokeStyle = a.color;
        ctx.fillStyle = a.color;
        ctx.lineWidth = a.width;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        const r = a.w !== undefined ? a : norm(a.a, a.b);
        switch (a.tool) {
        case "rect":
            if (a.fill) ctx.fillRect(r.x, r.y, r.w, r.h);
            else ctx.strokeRect(r.x, r.y, r.w, r.h);
            break;
        case "ellipse":
            ctx.beginPath();
            ctx.ellipse(r.x, r.y, r.w, r.h);
            if (a.fill) ctx.fill(); else ctx.stroke();
            break;
        case "line":
        case "arrow": {
            ctx.beginPath();
            ctx.moveTo(a.a.x, a.a.y);
            ctx.lineTo(a.b.x, a.b.y);
            ctx.stroke();
            if (a.tool === "arrow") {
                const ang = Math.atan2(a.b.y - a.a.y, a.b.x - a.a.x), s = a.width * 3 + 10;
                ctx.beginPath();
                ctx.moveTo(a.b.x, a.b.y);
                ctx.lineTo(a.b.x - s * Math.cos(ang - 0.45), a.b.y - s * Math.sin(ang - 0.45));
                ctx.lineTo(a.b.x - s * Math.cos(ang + 0.45), a.b.y - s * Math.sin(ang + 0.45));
                ctx.closePath();
                ctx.fill();
            }
            break;
        }
        case "pen":
        case "marker":
            if (a.tool === "marker") {
                ctx.globalAlpha = 0.35;
                ctx.lineWidth = a.width * 4 + 6;
                ctx.lineCap = "butt";
            }
            ctx.beginPath();
            ctx.moveTo(a.pts[0].x, a.pts[0].y);
            for (const p of a.pts.slice(1)) ctx.lineTo(p.x, p.y);
            ctx.stroke();
            break;
        }
        ctx.restore();
    }

    // ── экспорт ──
    function exportShot(action) {
        if (!sel || !cropRef) return;
        finishDraft();
        const size = Qt.size(Math.round(sel.w * factor), Math.round(sel.h * factor));
        const label = size.width + "×" + size.height;
        cropRef.grabToImage(res => {
            const src = tmp + "/shot.png";
            if (!res.saveToFile(src)) {
                message = I18n.tr("не удалось записать %1", src);
                return;
            }
            const home = Quickshell.env("HOME");
            const dir = String(Settings.get("shell.shot.dir")).replace(/^~(?=\/|$)/, home);
            const name = "Screenshot from " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") + ".png";
            if (action === "ocr") { ocr(src); close(); return; }
            Quickshell.execDetached(["sh", "-c", `
                src=$1 act=$2 dest="$3/$4"
                case $act in copy|both) wl-copy --type image/png < "$src" ;; esac
                case $act in save|both) mkdir -p "$3" && cp "$src" "$dest" || dest="" ;; esac
                [ "$5" = true ] || exit 0
                case $act in
                    copy) notify-send -a ochre -i "$src" "$7" "$6" ;;
                    *) [ -n "$dest" ] && notify-send -a ochre -i "$dest" "$([ $act = both ] && echo "$9" || echo "$8")" "$dest ($6)" \\
                           || notify-send -a ochre -u critical "\${10}" "$3" ;;
                esac`, "sh", src, action, dir, name, String(Settings.get("shell.shot.notify")), label,
                I18n.tr("Скриншот скопирован"), I18n.tr("Скриншот сохранён"), I18n.tr("Скриншот сохранён и скопирован"), I18n.tr("Скриншот не сохранён")]);
            close();
        }, size);
    }

    // текст с картинки в буфер: языки — какие из eng, rus стоят (tesseract-data-*)
    function ocr(src) {
        Quickshell.execDetached(["sh", "-c", `
            if ! command -v tesseract >/dev/null; then
                notify-send -a ochre -u critical "$3" "sudo pacman -S tesseract tesseract-data-eng tesseract-data-rus"; exit 1
            fi
            langs=$(tesseract --list-langs 2>/dev/null | grep -xE 'eng|rus' | paste -sd+)
            # $(…) сама срезает пустые строки в конце
            text=$(tesseract "$1" - -l "\${langs:-eng}" 2>/dev/null)
            if [ -z "$(printf %s "$text" | tr -d '[:space:]')" ]; then
                notify-send -a ochre "$4" "$5"; exit 0
            fi
            printf %s "$text" | wl-copy
            [ "$2" = true ] && notify-send -a ochre "$6" "$(printf %s "$text" | head -n 6)"
            exit 0`, "sh", src, String(Settings.get("shell.shot.notify")), I18n.tr("Нужен tesseract"), I18n.tr("Текст не найден"),
            I18n.tr("на снимке нечего распознать"), I18n.tr("Текст скопирован")]);
    }

    // латинская буква клавиши независимо от раскладки: при ru event.key для R — «К».
    // Буквы — по скан-коду (xkb = evdev + 8), остальное — как есть
    readonly property var scan: ({
        24: "q", 25: "w", 26: "e", 27: "r", 28: "t", 29: "y", 30: "u", 31: "i", 32: "o", 33: "p",
        38: "a", 39: "s", 40: "d", 41: "f", 42: "g", 43: "h", 44: "j", 45: "k", 46: "l",
        52: "z", 53: "x", 54: "c", 55: "v", 56: "b", 57: "n", 58: "m"
    })
    function letter(event) {
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) return String.fromCharCode(event.key).toLowerCase();
        return scan[event.nativeScanCode] ?? "";
    }

    // ── клавиши (их получает окно экрана target) ──
    function key(event) {
        const k = event.key, m = event.modifiers, ch = letter(event);
        const ctrl = m & Qt.ControlModifier, shift = m & Qt.ShiftModifier;
        if (phase === "select") {
            if (k === Qt.Key_Escape) close();
            else if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) wholeScreen(target);
            else if (ch === "w") pickWindow();
            else if (ch === "i") pickColor();
            else return;
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Escape) { if (draft) draft = null; else close(); }
        else if (ctrl && ch === "z") shift ? redo() : undo();
        else if (ctrl && ch === "y") redo();
        else if (ctrl && ch === "c") exportShot("copy");
        else if (ctrl && ch === "s") exportShot("save");
        else if (ctrl && ch === "o") exportShot("ocr");
        else if (ch === "i" && !ctrl) pickColor();
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (Date.now() - textClosedAt > 300) exportShot(shift ? "both" : Settings.get("shell.shot.enter"));
        }
        else if (k === Qt.Key_Backspace || k === Qt.Key_Delete) undo();
        else if (k === Qt.Key_BracketLeft || k === Qt.Key_Minus) setWidth(strokeW - 1);
        else if (k === Qt.Key_BracketRight || k === Qt.Key_Equal || k === Qt.Key_Plus) setWidth(strokeW + 1);
        else if (ch === "f" && !ctrl) fill = !fill;
        else if (k >= Qt.Key_1 && k <= Qt.Key_9 && !ctrl) setColor(k - Qt.Key_1);
        else {
            const t = tools.find(t => t.key === ch);
            if (!t || ctrl) return;
            setTool(t.id);
        }
        event.accepted = true;
    }

    function wholeScreen(name) {
        const s = Quickshell.screens.find(x => x.name === name);
        if (!s) return;
        target = name;
        sel = { x: 0, y: 0, w: s.width, h: s.height };
        bounds = sel;
        phase = "edit";
    }

    LazyLoader {
        active: root.open

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property var modelData
                screen: modelData
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: isTarget ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                WlrLayershell.namespace: "ochre-shot"

                readonly property bool isTarget: modelData.name === root.target
                // экран: пока ScreencopyView не поймал кадр, не рисуем ничего своего — иначе попадёт в снимок
                readonly property bool ready: root.mode === "window" || frozen.hasContent
                readonly property var r: isTarget ? root.sel : null
                readonly property real factor: root.mode === "window"
                    ? (winImg.paintedWidth > 0 ? winImg.sourceSize.width / winImg.paintedWidth : 1)
                    : (frozen.sourceSize.width > 0 ? frozen.sourceSize.width / width : modelData.devicePixelRatio)

                Binding { when: win.isTarget; target: root; property: "cropRef"; value: crop }
                Binding { when: win.isTarget; target: root; property: "factor"; value: win.factor }

                TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

                // ── замороженный экран или снимок окна ──
                Item {
                    id: base
                    anchors.fill: parent

                    ScreencopyView {
                        id: frozen
                        anchors.fill: parent
                        captureSource: root.mode === "screen" ? win.modelData : null
                        live: false
                        paintCursor: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: root.mode === "window"
                        color: Theme.bg
                    }

                    Image {
                        id: winImg
                        visible: root.mode === "window" && win.isTarget
                        source: visible ? root.windowPng : ""
                        cache: false
                        fillMode: Image.PreserveAspectFit
                        // не больше 90% экрана и не больше родного размера
                        readonly property real k: Math.min(1, win.width * 0.9 / Math.max(1, sourceSize.width), win.height * 0.85 / Math.max(1, sourceSize.height))
                        width: Math.round(sourceSize.width * k)
                        height: Math.round(sourceSize.height * k)
                        x: Math.round((win.width - width) / 2)
                        y: Math.round((win.height - height) / 2)
                        // область = картинка; Ready приходит раньше, чем посчитан размер, — ловим всё.
                        // Геометрия картинки меняется только при загрузке, ручки её не трогают
                        function place() {
                            if (status !== Image.Ready || !win.isTarget || width <= 0) return;
                            root.sel = { x: x, y: y, w: width, h: height };
                            root.bounds = root.sel;
                        }
                        onStatusChanged: place()
                        onWidthChanged: place()
                        onXChanged: place()
                        onVisibleChanged: place()
                    }
                }

                // ── затемнение вокруг области ──
                Repeater {
                    model: !win.ready ? [] : !win.r ? [{ x: 0, y: 0, w: win.width, h: win.height }] : [
                        { x: 0, y: 0, w: win.width, h: win.r.y },
                        { x: 0, y: win.r.y + win.r.h, w: win.width, h: win.height - win.r.y - win.r.h },
                        { x: 0, y: win.r.y, w: win.r.x, h: win.r.h },
                        { x: win.r.x + win.r.w, y: win.r.y, w: win.width - win.r.x - win.r.w, h: win.r.h }
                    ]
                    Rectangle {
                        required property var modelData
                        x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
                        color: "#000000"
                        opacity: root.phase === "edit" && !win.isTarget ? 0.6 : 0.45
                    }
                }

                // ── обрезка: то, что уйдёт в файл ──
                Item {
                    id: crop
                    visible: !!win.r && win.ready && win.r.w > 0 && win.r.h > 0
                    x: win.r ? win.r.x : 0
                    y: win.r ? win.r.y : 0
                    width: win.r ? win.r.w : 0
                    height: win.r ? win.r.h : 0
                    clip: true

                    Item {
                        id: stage
                        x: -crop.x
                        y: -crop.y
                        width: win.width
                        height: win.height

                        // сам кадр — копией base (base под затемнением, а снимать нужно чистый)
                        ShaderEffectSource {
                            x: crop.x; y: crop.y; width: crop.width; height: crop.height
                            sourceItem: base
                            sourceRect: Qt.rect(crop.x, crop.y, crop.width, crop.height)
                            textureSize: Qt.size(Math.max(1, crop.width * win.factor), Math.max(1, crop.height * win.factor))
                        }

                        // размытие и пиксели — по кадру под ними
                        Repeater {
                            model: win.isTarget ? root.effects : []
                            Item {
                                id: fx
                                required property var modelData
                                readonly property var rr: modelData.w !== undefined ? modelData : root.norm(modelData.a, modelData.b)
                                readonly property bool pixel: modelData.tool === "pixel"
                                readonly property int cellPx: 6 + modelData.width * 2
                                x: rr.x; y: rr.y; width: Math.max(1, rr.w); height: Math.max(1, rr.h)

                                ShaderEffectSource {
                                    id: fxSrc
                                    anchors.fill: parent
                                    visible: fx.pixel
                                    sourceItem: base
                                    sourceRect: Qt.rect(fx.x, fx.y, fx.width, fx.height)
                                    smooth: false
                                    // пиксели: крошечная текстура, растянутая без сглаживания
                                    textureSize: fx.pixel
                                        ? Qt.size(Math.max(1, Math.round(fx.width / fx.cellPx)), Math.max(1, Math.round(fx.height / fx.cellPx)))
                                        : Qt.size(fx.width, fx.height)
                                }
                                MultiEffect {
                                    anchors.fill: parent
                                    visible: !fx.pixel
                                    source: fxSrc
                                    autoPaddingEnabled: false
                                    blurEnabled: true
                                    blur: 1.0
                                    blurMax: Math.min(64, 16 + fx.modelData.width * 4)
                                }
                            }
                        }

                        Canvas {
                            id: canvas
                            visible: win.isTarget
                            x: crop.x; y: crop.y; width: crop.width; height: crop.height
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.translate(-x, -y);
                                for (const a of root.anns) root.paintAnn(ctx, a);
                                if (root.draft) root.paintAnn(ctx, root.draft);
                            }
                            Connections {
                                target: root
                                function onAnnsChanged() { canvas.requestPaint(); }
                                function onDraftChanged() { canvas.requestPaint(); }
                                function onSelChanged() { canvas.requestPaint(); }
                            }
                        }

                        // шаги и текст — обычными элементами
                        Repeater {
                            model: win.isTarget ? root.marks : []
                            Item {
                                id: mk
                                required property var modelData
                                readonly property int d: 20 + modelData.width * 3
                                x: modelData.tool === "step" ? modelData.x - d / 2 : modelData.x
                                y: modelData.tool === "step" ? modelData.y - d / 2 : modelData.y
                                width: modelData.tool === "step" ? d : label.implicitWidth
                                height: modelData.tool === "step" ? d : label.implicitHeight

                                Rectangle {
                                    anchors.fill: parent
                                    visible: mk.modelData.tool === "step"
                                    radius: width / 2
                                    color: mk.modelData.color
                                    border.color: Theme.bg
                                    border.width: 2
                                }
                                Text {
                                    id: label
                                    anchors.centerIn: mk.modelData.tool === "step" ? parent : undefined
                                    text: mk.modelData.tool === "step" ? mk.modelData.n : mk.modelData.text
                                    color: mk.modelData.tool === "step"
                                        ? (mk.modelData.color === String(Theme.bg) ? Theme.fg : Theme.bg)
                                        : mk.modelData.color
                                    font.family: Theme.font
                                    font.bold: true
                                    font.pixelSize: mk.modelData.tool === "step" ? mk.d * 0.6 : root.textSize(mk.modelData.width)
                                    style: mk.modelData.tool === "text" ? Text.Outline : Text.Normal
                                    styleColor: mk.modelData.color === String(Theme.bg) ? Theme.fg : Theme.bg
                                }
                            }
                        }
                    }
                }

                // рамка области
                Rectangle {
                    visible: crop.visible
                    x: crop.x - 1; y: crop.y - 1; width: crop.width + 2; height: crop.height + 2
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 1
                }

                FocusScope {
                    id: keyScope
                    anchors.fill: parent
                    focus: true
                    Keys.onPressed: event => root.key(event)

                    // ── выбор области: тянуть или кликнуть (весь экран) ──
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.phase === "select" && win.ready
                        hoverEnabled: true
                        cursorShape: Qt.CrossCursor
                        property point p0
                        onPressed: mouse => {
                            root.target = win.modelData.name;
                            p0 = Qt.point(mouse.x, mouse.y);
                            root.dragging = true;
                            root.sel = { x: mouse.x, y: mouse.y, w: 0, h: 0 };
                        }
                        onPositionChanged: mouse => {
                            if (root.dragging) root.sel = root.norm(p0, Qt.point(Math.max(0, Math.min(win.width, mouse.x)), Math.max(0, Math.min(win.height, mouse.y))));
                        }
                        onReleased: {
                            root.dragging = false;
                            if (!root.sel || root.sel.w < 4 || root.sel.h < 4) root.wholeScreen(win.modelData.name);
                            else {
                                root.bounds = { x: 0, y: 0, w: win.width, h: win.height };
                                root.phase = "edit";
                            }
                        }
                    }

                    // ── рисование внутри области ──
                    MouseArea {
                        visible: root.phase === "edit" && crop.visible && !root.textAt
                        x: crop.x; y: crop.y; width: crop.width; height: crop.height
                        cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                        preventStealing: true
                        onPressed: mouse => root.begin({ x: mouse.x + crop.x, y: mouse.y + crop.y })
                        onPositionChanged: mouse => root.extend({ x: mouse.x + crop.x, y: mouse.y + crop.y })
                        onReleased: root.finishDraft()
                        onWheel: wheel => root.setWidth(root.strokeW + (wheel.angleDelta.y > 0 ? 1 : -1))
                    }

                    // ── ручки: изменить область, нарисованное остаётся на месте ──
                    Repeater {
                        model: root.phase === "edit" && crop.visible ? ["tl", "t", "tr", "r", "br", "b", "bl", "l"] : []
                        Rectangle {
                            id: handle
                            required property string modelData
                            readonly property real hx: modelData.includes("l") ? crop.x : modelData.includes("r") ? crop.x + crop.width : crop.x + crop.width / 2
                            readonly property real hy: modelData.includes("t") ? crop.y : modelData.includes("b") ? crop.y + crop.height : crop.y + crop.height / 2
                            x: hx - 5; y: hy - 5; width: 10; height: 10
                            color: Theme.bg
                            border.color: Theme.accent
                            border.width: 2
                            MouseArea {
                                anchors { fill: parent; margins: -6 }
                                preventStealing: true
                                cursorShape: handle.modelData === "t" || handle.modelData === "b" ? Qt.SizeVerCursor
                                    : handle.modelData === "l" || handle.modelData === "r" ? Qt.SizeHorCursor
                                    : handle.modelData === "tl" || handle.modelData === "br" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                                onPositionChanged: mouse => {
                                    const p = mapToItem(win.contentItem, mouse.x, mouse.y), s = root.sel, b = root.bounds, h = handle.modelData;
                                    let x0 = s.x, y0 = s.y, x1 = s.x + s.w, y1 = s.y + s.h;
                                    if (h.includes("l")) x0 = Math.max(b.x, Math.min(p.x, x1 - 8));
                                    if (h.includes("r")) x1 = Math.min(b.x + b.w, Math.max(p.x, x0 + 8));
                                    if (h.includes("t")) y0 = Math.max(b.y, Math.min(p.y, y1 - 8));
                                    if (h.includes("b")) y1 = Math.min(b.y + b.h, Math.max(p.y, y0 + 8));
                                    root.sel = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
                                }
                            }
                        }
                    }

                    // ── ввод текста ──
                    TextInput {
                        id: textIn
                        visible: !!root.textAt && win.isTarget
                        x: root.textAt ? root.textAt.x : 0
                        y: root.textAt ? root.textAt.y : 0
                        width: Math.max(cell.advanceWidth * 4, contentWidth + 4)
                        color: root.color
                        font.family: Theme.font
                        font.bold: true
                        font.pixelSize: root.textSize(root.strokeW)
                        cursorDelegate: Rectangle { width: 2; color: Theme.accent }
                        // после ввода фокус — обратно окну, иначе перестанут работать клавиши инструментов
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); } else keyScope.forceActiveFocus()
                        onAccepted: root.commitText(text)
                        Keys.onEscapePressed: root.textAt = null
                        onActiveFocusChanged: if (!activeFocus && visible) root.commitText(text)
                    }
                }

                // ── размер при выделении ──
                Rectangle {
                    visible: root.phase === "select" && root.dragging && win.isTarget && !!root.sel
                    x: root.sel ? Math.min(win.width - width - 4, root.sel.x + root.sel.w + 8) : 0
                    y: root.sel ? Math.min(win.height - height - 4, root.sel.y + root.sel.h + 8) : 0
                    width: sizeT.implicitWidth + 12; height: sizeT.implicitHeight + 4
                    color: Theme.bg
                    T { id: sizeT; anchors.centerIn: parent; color: Theme.accent; text: root.sel ? Math.round(root.sel.w * win.factor) + "×" + Math.round(root.sel.h * win.factor) : "" }
                }

                // ── подсказка выбора ──
                Box {
                    visible: root.phase === "select" && win.ready && win.isTarget && !root.dragging
                    title: "~/shot/"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(win.height * 0.08)
                    T {
                        textFormat: Text.StyledText
                        text: root.then === "ocr" ? root.keys([[I18n.tr("тяни"), I18n.tr("область с текстом")], [I18n.tr("клик"), I18n.tr("весь экран")], ["esc", I18n.tr("выход")]])
                            : root.keys([[I18n.tr("тяни"), I18n.tr("область")], [I18n.tr("клик"), I18n.tr("весь экран")], ["w", I18n.tr("окно")], ["i", I18n.tr("пипетка")], ["esc", I18n.tr("выход")]])
                    }
                }

                // ── панель разметки ──
                Box {
                    id: bar
                    visible: root.phase === "edit" && crop.visible && win.isTarget
                    title: "~/shot/ " + Math.round(crop.width * win.factor) + "×" + Math.round(crop.height * win.factor)
                    x: Math.max(8, Math.min(win.width - width - 8, crop.x))
                    y: crop.y + crop.height + height + 24 <= win.height ? crop.y + crop.height + 18
                        : crop.y - height - 18 >= 0 ? crop.y - height - 18
                        : crop.y + crop.height - height - 12

                    Row {
                        Repeater {
                            model: root.tools
                            T {
                                required property var modelData
                                readonly property bool on: root.tool === modelData.id
                                textFormat: Text.StyledText
                                // StyledText — HTML: обычные пробелы подряд схлопываются
                                text: `<font color="${Theme.accent}">${modelData.key}</font>&nbsp;${modelData.label}&nbsp;&nbsp;`
                                color: on ? Theme.fg : Theme.gray
                                font.bold: on
                                Rectangle { anchors.fill: parent; z: -1; color: Theme.bg1; visible: parent.on }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setTool(parent.modelData.id) }
                            }
                        }
                    }
                    Row {
                        spacing: 0
                        T { text: I18n.tr("цвет "); color: Theme.gray }
                        Repeater {
                            model: root.colors.length
                            T {
                                required property int index
                                text: index === root.colorIdx ? "[█]" : " █ "
                                color: root.colors[index]
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setColor(parent.index) }
                            }
                        }
                        T {
                            textFormat: Text.StyledText
                            text: `&nbsp;&nbsp;&nbsp;<font color="${Theme.gray}">${I18n.tr("толщина")}</font> ‹ ${root.strokeW} ›&nbsp;&nbsp;&nbsp;<font color="${Theme.gray}">${I18n.tr("заливка")}</font> ${root.fill ? "[x]" : "[&nbsp;]"}`
                                + `&nbsp;&nbsp;&nbsp;<font color="${Theme.gray}">${I18n.tr("фигур")}</font> ${root.anns.length}`
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => root.setWidth(root.strokeW + (wheel.angleDelta.y > 0 ? 1 : -1))
                            }
                        }
                    }
                    Row {
                        spacing: 0
                        Repeater {
                            model: [["↵", Settings.get("shell.shot.enter"), Settings.get("shell.shot.enter")], ["^C", "copy", "copy"], ["^S", "save", "save"], ["⇧↵", "both", "both"], ["^O", "ocr", "ocr"]]
                            T {
                                required property var modelData
                                textFormat: Text.StyledText
                                text: `<font color="${Theme.gray}">[</font>${modelData[1]}<font color="${Theme.gray}">]</font>&nbsp;<font color="${Theme.accent}">${modelData[0]}</font>&nbsp;&nbsp;&nbsp;`
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.exportShot(parent.modelData[2]) }
                            }
                        }
                        T {
                            textFormat: Text.StyledText
                            color: Theme.gray
                            text: root.message ? `<font color="${Theme.red}">${root.message}</font>`
                                : root.keys([["1-9", I18n.tr("цвет")], ["[ ]", I18n.tr("толщина")], ["f", I18n.tr("заливка")], ["i", I18n.tr("пипетка")], ["^Z", I18n.tr("отмена")], ["esc", I18n.tr("выход")]])
                        }
                    }
                }
            }
        }
    }

    function keys(list) {
        return list.map(([k, v]) => `<font color="${Theme.accent}">${k}</font>&nbsp;${v}`).join("&nbsp;&nbsp;&nbsp;");
    }

    // TUI-рамка с заголовком на линии рамки — как у остальных окон shell
    component Box: Rectangle {
        id: box
        property string title
        default property alias content: col.data
        width: col.implicitWidth + Theme.fontSize * 2
        height: col.implicitHeight + Theme.fontSize * 1.6
        color: Theme.bg
        border.color: Theme.accent
        border.width: 2

        Column {
            id: col
            x: Theme.fontSize
            y: Theme.fontSize * 0.9
            spacing: 4
        }
        MouseArea { anchors.fill: parent; z: -1 }   // клики по панели не рисуют под ней

        Rectangle {
            x: Theme.fontSize
            y: -height / 2
            width: titleT.implicitWidth + 8
            height: titleT.implicitHeight
            color: Theme.bg
            T { id: titleT; x: 4; text: "[ " + box.title + " ]"; color: Theme.accent; font.bold: true }
        }
    }
}
