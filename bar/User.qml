import QtQuick
import qs
import qs.services

// user@host — стиль задаётся в настройках (shell.bar.prompt); клик — меню home (HomePanel.qml)
Item {
    id: root

    property var bar
    property bool available: true
    readonly property string style: Settings.get("shell.bar.prompt")
    readonly property bool vertical: bar?.vertical ?? false

    function c(color, s) { return `<font color="${color}">${s}</font>`; }

    implicitWidth: t.implicitWidth
    implicitHeight: t.height

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Home.toggle(root.bar?.screen?.name)
    }

    BarText {
        id: t
        textFormat: Text.StyledText
        text: {
            const n = !root.vertical ? undefined : root.style === "user" || root.style === "host" ? 6 : 1;
            const u = root.c(Theme.green, "<b>" + Sys.user.slice(0, n) + "</b>");
            const h = root.c(Theme.aqua, "<b>" + Sys.host.slice(0, n) + "</b>");
            const at = root.c(Theme.gray, "@");
            switch (root.style) {
            case "[user@host]": return root.c(Theme.gray, "[") + u + at + h + root.c(Theme.gray, "]");
            case "user": return u;
            case "host": return h;
            default: return u + at + h;
            }
        }
    }
}
