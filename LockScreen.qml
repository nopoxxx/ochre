import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import qs.services

// Блокировка экрана: ext-session-lock + PAM (/etc/pam.d/login).
// Если quickshell упадёт, сессия останется заблокированной — так задумано протоколом.
//   qs ipc call lock lock     — заблокировать
//   qs ipc call lock locked   — заблокирован ли сейчас
//   qs ipc call lock preview  — тот же экран обычным окном, без проверки пароля (Esc — закрыть)
// Хуки lock / unlock — services/Hooks.qml.
Scope {
    id: root

    property bool previewOpen: false
    property int previewAttempt: 0
    property string password: ""
    property string message: ""
    property bool messageIsError: false
    property int failures: 0
    property int attempt: 0

    function lock() {
        if (session.locked) return;
        message = "";
        failures = 0;
        session.locked = true;
    }

    function submit(pw) {
        if (pam.active) return;
        password = pw;
        message = "";
        pam.start();
    }

    PamContext {
        id: pam

        configDirectory: "/etc/pam.d"
        config: "login"
        user: Sys.user

        onPamMessage: {
            if (responseRequired) {
                respond(root.password);
                root.password = "";
            } else if (message) {
                root.message = message;
                root.messageIsError = messageIsError;
            }
        }

        onCompleted: result => {
            root.password = "";
            root.attempt++;
            if (result === PamResult.Success) {
                session.locked = false;
                root.failures = 0;
                root.message = "";
            } else {
                root.failures++;
                root.message = result === PamResult.MaxTries ? "Maximum number of tries exceeded" : "Login incorrect";
                root.messageIsError = true;
            }
        }

        onError: err => {
            root.password = "";
            root.attempt++;
            root.message = "pam: " + PamError.toString(err);
            root.messageIsError = true;
        }
    }

    WlSessionLock {
        id: session

        onLockedChanged: {
            Hooks.run(locked ? "lock" : "unlock");
            ScreenTime.locked = locked;
        }

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            readonly property string wall: Wallpaper.imageFor(screen?.name ?? "", Wallpaper.activeWs(screen?.name ?? ""))

            // приглушённые обои под приглашением
            Image {
                anchors.fill: parent
                visible: Settings.get("shell.lock.wallpaper") && surface.wall !== ""
                source: surface.wall ? "file://" + encodeURI(surface.wall) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.15
            }

            LoginPrompt {
                anchors.fill: parent
                message: root.message
                messageIsError: root.messageIsError
                busy: pam.active
                failures: root.failures
                attempt: root.attempt
                onSubmit: pw => root.submit(pw)
            }
        }
    }

    // предпросмотр: niri не даёт снимать заблокированный экран, а так вид можно настроить и сфотографировать
    LazyLoader {
        active: root.previewOpen

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-lock-preview"
            color: Theme.bg

            Image {
                anchors.fill: parent
                visible: Settings.get("shell.lock.wallpaper") && Wallpaper.current !== ""
                source: Wallpaper.current ? "file://" + encodeURI(Wallpaper.current) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.15
            }

            LoginPrompt {
                anchors.fill: parent
                message: I18n.tr("предпросмотр — пароль не проверяется, Esc — закрыть")
                messageIsError: false
                attempt: root.previewAttempt
                onSubmit: root.previewAttempt++
                onCancel: root.previewOpen = false
            }
        }
    }

    // блокировка после бездействия; видеоплееры и т.п. могут её запретить (inhibitors)
    IdleMonitor {
        enabled: Settings.get("shell.lock.idle") > 0
        timeout: Settings.get("shell.lock.idle") * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lock()
    }

    onPreviewOpenChanged: if (!previewOpen) Settings.back()

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function locked(): bool { return session.locked; }
        function preview(): void { root.previewOpen = !root.previewOpen; }
    }
}
