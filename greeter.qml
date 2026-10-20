import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import qs.services
import "services/settings.js" as S

// Точка входа greeter: qs -p <shell>/greeter.qml (с OCHRE_GREETER=1); <shell> — /usr/share/ochre у пакета,
// /usr/local/share/ochre — копия git-установки (extras/install-greeter.sh).
// Работает внутри отдельного niri под пользователем greeter — см. extras/greeter/.
// Вид берётся из настроек пользователя, которые синхронизирует GreeterSync из его сессии.
ShellRoot {
    id: root

    readonly property string libDir: "/var/lib/ochre-greeter"
    readonly property string stateDir: libDir + "/.greeter"

    // файлы greeter меняет pacman или install-greeter.sh — без перезагрузки посреди замены
    Component.onCompleted: Quickshell.watchFiles = false

    property string user: ""
    property string password: ""
    property string message: ""
    property bool messageIsError: false
    property bool busy: false
    property int failures: 0
    property int attempt: 0
    property var sessions: []
    property string lastSession: ""

    function choose(name) {
        user = name;
        Settings.profile = name;
    }

    function login(name, pw) {
        choose(name);
        password = pw;
        message = "";
        busy = true;
        Greetd.createSession(name);
    }

    function fail(msg) {
        password = "";
        busy = false;
        failures++;
        message = msg;
        messageIsError = true;
        attempt++;
    }

    // ── последний пользователь и сессия ─────────────────────────────

    FileView {
        id: lastFile
        path: root.stateDir + "/last"
        onLoaded: {
            const [u, s] = text().trim().split("\n");
            root.lastSession = s ?? "";
            if (u) root.choose(u);
            else usersProc.running = true;
        }
        onLoadFailed: usersProc.running = true
    }

    // первый обычный пользователь, если greeter запускается впервые
    Process {
        id: usersProc
        command: ["sh", "-c", "getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: if (this.text.trim()) root.choose(this.text.trim())
        }
    }

    Process {
        running: true
        command: ["sh", "-c", `for f in /usr/share/wayland-sessions/*.desktop; do
            n=$(grep -m1 '^Name=' "$f" | cut -d= -f2-); e=$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)
            [ -n "$e" ] && printf '%s\\t%s\\n' "\${n:-$e}" "$e"
        done`]
        stdout: StdioCollector {
            onStreamFinished: root.sessions = this.text.trim().split("\n").filter(l => l).map(l => {
                const [name, exec] = l.split("\t");
                return { name, exec };
            })
        }
    }

    FileView {
        id: niriBg
        path: root.stateDir + "/niri.kdl"
        printErrors: false
        readonly property string want: Settings.loaded ? S.greeterNiri(k => Settings.get(k)) : ""
        function sync() { if (want && text() !== want) setText(want); }
        onWantChanged: if (loaded) sync()
        onLoaded: sync()
    }

    // ── greetd ─────────────────────────────────────────────────────

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.password);
                root.password = "";
            } else if (message) {
                root.message = message;
                root.messageIsError = error;
            }
        }

        function onAuthFailure(message) {
            root.fail("Login incorrect");
        }

        function onError(error) {
            // после authFailure greetd закрывает соединение, и следом приходит ещё и error
            // («Connection refused») — он не про новую попытку: не затираем «Login incorrect»
            if (!root.busy) {
                console.warn("greetd:", error);
                return;
            }
            root.fail("greetd: " + error);
        }

        function onReadyToLaunch() {
            const s = root.sessions[prompt.sessionIndex] ?? { name: "Niri", exec: "niri-session" };
            lastFile.setText(root.user + "\n" + s.name + "\n");
            // quit: quickshell выходит сам, обёртка в niri.kdl закрывает niri — greetd запускает сессию
            Greetd.launch(s.exec.split(/\s+/), [], true);
        }
    }

    // ── окно ───────────────────────────────────────────────────────

    PanelWindow {
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "ochre-greeter"
        color: Theme.bg

        Image {
            anchors.fill: parent
            visible: Settings.get("shell.lock.wallpaper") && status === Image.Ready
            source: root.user ? "file://" + root.libDir + "/" + root.user + "/wallpaper" : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.15
        }

        LoginPrompt {
            id: prompt

            anchors.fill: parent
            askUser: true
            user: root.user
            sessions: root.sessions
            message: root.message
            messageIsError: root.messageIsError
            busy: root.busy
            failures: root.failures
            attempt: root.attempt

            onUserChanged: preset(user)
            onUserChosen: name => root.choose(name)
            onSubmit: pw => root.login(prompt.user, pw)
            onPower: action => Quickshell.execDetached(["systemctl", action])
        }
    }

    // вернуть сессию, выбранную в прошлый раз
    onSessionsChanged: {
        const i = sessions.findIndex(s => s.name === lastSession);
        if (i >= 0) prompt.sessionIndex = i;
    }
    onLastSessionChanged: sessionsChanged()
}
