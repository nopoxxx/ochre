import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Сети Wi-Fi: подключённая сверху, дальше по силе сигнала. ↵ / клик: подключённая — отключить,
// известная или открытая — подключиться, новая с паролем — поле пароля (↵ — подключиться, Esc — отмена).
// Пока меню открыто, адаптер ищет сети. Нет Wi-Fi — секции не видно; выключен — переключатель в «быстро».
Section {
    id: sec

    title: "wi-fi"

    readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var nets: (dev?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
        .slice(0, 8)
    property string asking: ""        // имя сети, для которой вводят пароль
    property string pskText: ""
    property string failed: ""

    available: dev !== null
    count: Networking.wifiEnabled ? nets.length : 0

    Component.onCompleted: if (dev) dev.scannerEnabled = true
    Component.onDestruction: if (dev) dev.scannerEnabled = false

    function pct(s) { return Math.round(s <= 1 ? s * 100 : s); }
    function strength(s) {
        const p = pct(s);
        return G.g(p > 75 ? "wifi4" : p > 50 ? "wifi3" : p > 25 ? "wifi2" : "wifi1");
    }
    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown; }

    function activate(i) {
        const n = nets[i];
        if (!n) return;
        failed = "";
        if (n.connected) n.disconnect();
        else if (n.known || !secured(n)) n.connect();
        else {
            asking = n.name;   // поле пароля под сетью появится и возьмёт фокус само
        }
    }

    function submit() {
        const n = nets.find(x => x.name === asking);
        if (n && pskText) n.connectWithPsk(pskText);
        asking = "";
        sec.panel.focusSection(sec);
    }

    T {
        visible: !Networking.wifiEnabled
        text: I18n.tr("Wi-Fi выключен — включить в «быстро»")
        color: Theme.gray
    }

    Repeater {
        model: Networking.wifiEnabled ? sec.nets : []

        ColumnLayout {
            id: item
            required property var modelData
            required property int index
            readonly property var n: modelData

            Layout.fillWidth: true
            spacing: 0

            Connections {
                target: item.n
                function onConnectionFailed(reason) { sec.failed = item.n.name + ": " + ConnectionFailReason.toString(reason); }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: row.implicitHeight
                color: sec.isCur(item.index) ? Theme.bg1 : hover.hovered ? Theme.hover : "transparent"

                RowLayout {
                    id: row
                    width: parent.width
                    spacing: 0
                    T { text: sec.isCur(item.index) ? "▌" : " "; color: Theme.accent }
                    T { font.family: Theme.iconFont; text: sec.strength(item.n.signalStrength) + " "; color: item.n.connected ? Theme.accent : Theme.gray }
                    T {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: item.n.name
                        color: item.n.connected ? Theme.accent : Theme.fg
                        font.bold: item.n.connected || sec.isCur(item.index)
                    }
                    T {
                        color: Theme.gray
                        text: (item.n.stateChanging ? "… " : item.n.connected ? I18n.tr("подключено ") : item.n.known ? I18n.tr("известна ") : "")
                            + sec.pct(item.n.signalStrength) + "%"
                    }
                    T { font.family: Theme.iconFont; text: sec.secured(item.n) ? " " + G.g("lock") : "  "; color: Theme.gray }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { sec.pick(item.index); sec.activate(item.index); } }
            }

            // пароль для новой сети — прямо под ней
            RowLayout {
                visible: sec.asking === item.n.name
                Layout.fillWidth: true
                spacing: 0
                T { text: I18n.tr("  пароль: "); color: Theme.gray }
                TextInput {
                    id: psk
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    renderType: Text.NativeRendering
                    cursorDelegate: BlinkCursor {}
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onTextChanged: sec.pskText = text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) sec.submit();
                        else if (event.key === Qt.Key_Escape) { sec.asking = ""; sec.panel.focusSection(sec); }
                        else return;
                        event.accepted = true;
                    }
                }
            }
        }
    }

    T {
        visible: sec.failed !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: I18n.tr("не удалось: %1", sec.failed)
        color: Theme.red
    }
}
