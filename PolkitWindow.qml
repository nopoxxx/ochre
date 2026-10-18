import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services

// polkit-агент ochre: запрос пароля для pkexec, systemctl, монтирования и т.п. — как sudo в терминале:
//   ┌[ ~/polkit/ ]──────────────────────────────────────────┐
//   │ Для управления службами требуется аутентификация.      │
//   │ action org.freedesktop.systemd1.manage-units           │
//   │ [sudo] password for nopox: ****█                       │
// Агент в сессии может быть только один: при shell.polkit (system/ → ochre) shell гасит polkit-gnome (его запускает
// config.kdl) и регистрирует свой, не вышло — повторяет; выключено — запускает polkit-gnome сам.
// ↵ — отправить, Esc — отменить, Tab — другой пользователь (если polkit предлагает нескольких).
Scope {
    id: root

    readonly property bool enabled: Settings.get("shell.polkit") && !Settings.greeterMode
    readonly property string gnomeAgent: "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    property bool agentOn: false
    property int attempts: 0
    readonly property var agentObj: agent.item
    readonly property var flow: agentObj?.flow ?? null
    property string error: ""

    onEnabledChanged: setup()
    Component.onCompleted: setup()

    function setup() {
        if (Settings.greeterMode) return;
        if (enabled) {
            attempts = 0;
            takeOver.running = true;
        } else {
            agentOn = false;
            // свой агент выключен — нужен чужой, иначе pkexec и systemctl не смогут спросить пароль
            Quickshell.execDetached(["sh", "-c", 'pgrep -u "$(id -u)" -f "$1" >/dev/null || [ ! -x "$1" ] || exec setsid "$1"',
                "sh", gnomeAgent]);
        }
    }

    // polkit-gnome держит место агента — освободить, потом создать свой
    Process {
        id: takeOver
        command: ["sh", "-c", 'pkill -u "$(id -u)" -f "$1"; sleep 0.3; exit 0', "sh", root.gnomeAgent]
        onExited: {
            root.agentOn = false;
            root.agentOn = root.enabled;
            check.restart();
        }
    }

    // polkit-gnome мог запуститься после нас (оба — spawn-at-startup) и занять место: тогда ещё раз
    Timer {
        id: check
        interval: 2000
        onTriggered: {
            if (!root.enabled || root.agentObj?.isRegistered) return;
            if (++root.attempts < 4) takeOver.running = true;
            else Quickshell.execDetached(["notify-send", "-a", "ochre", "-u", "critical", "polkit-агент ochre не зарегистрировался",
                "Запросы пароля обработает другой агент, если он есть. system/ → ochre → polkit-агент"]);
        }
    }

    LazyLoader {
        id: agent
        active: root.agentOn
        PolkitAgent {}
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() { root.error = "Sorry, try again."; }
    }
    onFlowChanged: error = ""

    LazyLoader {
        active: root.flow !== null && root.agentObj?.isActive === true

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#99000000"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ochre-polkit"

            readonly property var flow: root.flow
            readonly property var ids: flow?.identities ?? []
            readonly property string who: flow?.selectedIdentity?.displayName || flow?.selectedIdentity?.name || Sys.user
            readonly property string echo: Settings.get("shell.lock.echo")

            TextMetrics { id: cell; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "M" }

            // настоящий ввод невидим — на экране своё «эхо», как в LoginPrompt
            TextInput {
                id: input
                opacity: 0
                width: 1
                focus: true
                echoMode: TextInput.Password
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    const k = event.key, f = root.flow;
                    if (!f) return;
                    if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        if (f.isResponseRequired) { root.error = ""; f.submit(input.text); input.text = ""; }
                    } else if (k === Qt.Key_Escape) {
                        f.cancelAuthenticationRequest();
                    } else if (k === Qt.Key_Tab && win.ids.length > 1) {
                        const i = win.ids.indexOf(f.selectedIdentity);
                        f.selectedIdentity = win.ids[(i + 1) % win.ids.length];
                    } else return;
                    event.accepted = true;
                }
            }

            MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

            Rectangle {
                id: box
                anchors.centerIn: parent
                width: cell.advanceWidth * 64 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                ColumnLayout {
                    id: col
                    x: Theme.pad
                    y: Theme.pad
                    width: parent.width - Theme.pad * 2
                    spacing: 4

                    T { Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.flow?.message ?? "" }
                    T {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: "<font color='" + Theme.gray + "'>action</font> " + (root.flow?.actionId ?? "")
                        color: Theme.aqua
                    }
                    T {
                        visible: win.ids.length > 1
                        textFormat: Text.StyledText
                        text: "<font color='" + Theme.gray + "'>user</font> ‹ " + win.who + " ›  <font color='"
                            + Theme.gray + "'>tab — сменить</font>"
                    }
                    Row {
                        Layout.topMargin: Theme.pad / 2
                        T {
                            // «Password:» от PAM — как sudo: [sudo] password for user:
                            text: (root.flow?.inputPrompt || "Password:").replace(/^password:?\s*$/i, "[sudo] password for " + win.who + ":") + " "
                            color: Theme.fg
                        }
                        T {
                            text: root.flow?.responseVisible ? input.text
                                : win.echo === "none" ? "" : win.echo.repeat(input.text.length)
                            color: Theme.accent
                        }
                        BlinkCursor {}
                    }
                    T {
                        visible: text !== ""
                        text: root.error || (root.flow?.supplementaryMessage ?? "")
                        color: root.error || root.flow?.supplementaryIsError ? Theme.red : Theme.gray
                    }
                    T {
                        Layout.topMargin: Theme.pad / 2
                        textFormat: Text.StyledText
                        color: Theme.gray
                        text: "<font color='" + Theme.accent + "'>↵</font> ок   <font color='" + Theme.accent + "'>esc</font> отмена"
                    }
                }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: titleT.implicitWidth + cell.advanceWidth
                    height: titleT.implicitHeight
                    color: Theme.bg
                    T { id: titleT; anchors.centerIn: parent; text: "[ ~/polkit/ ]"; color: Theme.accent; font.bold: true }
                }
            }
        }
    }
}
