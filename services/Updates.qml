pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Число доступных обновлений: репозитории (checkupdates) + AUR (paru -Qua), раз в час
Singleton {
    id: root

    property int count: 0
    readonly property bool running: upgrade.running

    function check() {
        if (!checker.running) checker.running = true;
    }

    // обновление в отдельном окне терминала; после закрытия окна — перепроверить
    function run() {
        if (!upgrade.running) upgrade.running = true;
    }

    Process {
        id: checker
        command: ["sh", "-c", "{ checkupdates 2>/dev/null; paru -Qua 2>/dev/null; } | grep -c ."]
        stdout: StdioCollector {
            onStreamFinished: root.count = parseInt(this.text) || 0
        }
    }

    Process {
        id: upgrade
        command: Term.cmd(["bash", "-c", 'paru -Syu; echo; read -n1 -rsp "$1"', "bash", I18n.tr("готово, нажмите любую клавишу")], { cls: "ochre-term" })
        onExited: root.check()
    }

    Timer {
        interval: 3600 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }
}
