import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services

// Экран входа как getty в консоли:
//
//          ██████  ██████    ██████  ██  ██
//          ...                                    (tty-clock)
//               пятница, 16 октября 2026
//
//     ochre 7.2.9-arch1-1 (tty1)
//     идёт закат…                           (motd — слоган ochre, shell.lock.motd)
//     ochre login: user
//     Password: ****█
//     session: Niri
//     Login incorrect
//
// Общий для блокировки экрана (PAM) и greeter (greetd): сам ничего не проверяет,
// только отдаёт имя и пароль сигналами.
//   askUser: false — блокировка: имя известно, сразу пароль
//   askUser: true  — greeter: сначала имя (подставлено последнее), потом пароль; Tab — сессия, F11/F12 — питание
Item {
    id: root

    property string user: Sys.user
    property string host: Sys.host
    property string message: ""
    property bool messageIsError: false
    property bool busy: false
    property int failures: 0
    property int attempt: 0          // меняется после каждой проверки — поле очищается
    property bool askUser: false
    property var sessions: []        // [{ name, exec }]
    property int sessionIndex: 0

    // 0 — ввод имени (только askUser), 1 — ввод пароля
    property int stage: 1

    signal submit(string password)
    signal userChosen(string name)
    signal power(string action)      // reboot | poweroff
    signal cancel()                  // Esc на пустом поле пароля без askUser — для предпросмотра

    readonly property string echo: Settings.get("shell.lock.echo")
    readonly property string masked: echo === "none" ? "" : echo.repeat(input.text.length)

    function restart() {
        stage = askUser ? 0 : 1;
        input.text = askUser ? user : "";
        input.forceActiveFocus();
    }

    // подставить имя, пока пользователь его ещё не трогал
    function preset(name) {
        if (stage === 0) input.text = name;
    }

    onAttemptChanged: restart()
    Component.onCompleted: restart()

    function c(color, s) { return `<font color="${color}">${s}</font>`; }

    // слоганы ochre для входа и блокировки (BRAND.md) — каждый раз другой, как motd
    readonly property var motds: [
        I18n.tr("с возвращением."), I18n.tr("чайник уже поставлен."), I18n.tr("идёт закат…"), I18n.tr("сессия восстановлена. тепло: 100%"),
        I18n.tr("последний вход: как раз к закату"), I18n.tr("сохраняй тепло."), I18n.tr("солнце садится. курсор остаётся.")
    ]
    readonly property string motd: motds[Math.floor(Math.random() * motds.length)]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "M"
    }

    // настоящий ввод невидим — на экране своё «эхо»
    TextInput {
        id: input

        opacity: 0
        width: 1
        focus: true
        enabled: !root.busy

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                if (root.stage === 0) {
                    const name = input.text.trim();
                    if (!name) return;
                    root.user = name;
                    root.userChosen(name);
                    root.stage = 1;
                    input.text = "";
                } else if (input.text.length) {
                    root.submit(input.text);
                }
            } else if (k === Qt.Key_Escape) {
                if (input.text.length && root.stage === 1) input.text = "";
                else if (root.stage === 1 && root.askUser) root.restart();
                else if (root.stage === 1) root.cancel();
                else input.text = "";
            } else if (k === Qt.Key_Tab && root.sessions.length > 1) {
                root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length;
            } else if (root.askUser && k === Qt.Key_F11) {
                root.power("reboot");
            } else if (root.askUser && k === Qt.Key_F12) {
                root.power("poweroff");
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    // клик в любом месте возвращает фокус полю ввода
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.pad

        BigClock {
            Layout.alignment: Qt.AlignHCenter
            visible: Settings.get("shell.lock.clock")
            text: Qt.formatTime(clock.date, "HH:mm")
            px: Theme.fontSize * 0.9
        }

        T {
            Layout.alignment: Qt.AlignHCenter
            visible: Settings.get("shell.lock.clock")
            // I18n.locale, а не Qt.formatDate: тот игнорирует локаль и всегда пишет по-английски
            text: I18n.locale.toString(clock.date, "dddd, d MMMM yyyy")
            color: Theme.gray
        }

        Item { implicitHeight: Theme.pad * 3 }

        // приглашение — блок с выравниванием по левому краю, как в консоли
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: cell.advanceWidth * 44
            spacing: 2

            T {
                text: root.host + " " + Sys.kernel + " (tty1)"
                color: Theme.gray
            }

            T {
                visible: Settings.get("shell.lock.motd")
                text: root.motd
                color: Theme.accent
            }

            Item { implicitHeight: Theme.pad }

            Row {
                T {
                    textFormat: Text.StyledText
                    text: root.c(Theme.aqua, root.host) + root.c(Theme.fg, " login: ")
                }
                T {
                    text: root.stage === 0 ? input.text : root.user
                    color: Theme.green
                    font.bold: true
                }
                BlinkCursor { visible: root.stage === 0 && !root.busy }
            }

            Row {
                visible: root.stage === 1

                T { text: "Password: "; color: Theme.fg }
                T { text: root.masked; color: Theme.accent }
                BlinkCursor { visible: !root.busy }
            }

            T {
                visible: root.sessions.length > 0
                textFormat: Text.StyledText
                text: root.c(Theme.gray, "session: ")
                    + root.c(Theme.blue, root.sessions[root.sessionIndex]?.name ?? "")
                    + (root.sessions.length > 1 ? root.c(Theme.gray, I18n.tr("  (tab — сменить)")) : "")
            }

            Item { implicitHeight: Theme.pad }

            T {
                visible: root.busy || root.message !== ""
                text: root.busy ? I18n.tr("проверка…") : root.message
                color: root.busy ? Theme.gray : root.messageIsError ? Theme.red : Theme.yellow
            }

            T {
                visible: root.failures > 1 && !root.busy
                text: I18n.tr("неудачных попыток: %1", root.failures)
                color: Theme.gray
            }
        }
    }

    T {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.pad * 3 }
        textFormat: Text.StyledText
        color: Theme.gray
        text: (root.askUser
            ? [["↵", I18n.tr("далее")], ["esc", I18n.tr("назад")], ["tab", I18n.tr("сессия")], ["F11", I18n.tr("перезагрузка")], ["F12", I18n.tr("выключение")]]
            : [["↵", I18n.tr("войти")], ["esc", I18n.tr("очистить")]])
            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
    }

}
