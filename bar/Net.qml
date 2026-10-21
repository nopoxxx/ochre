import Quickshell
import Quickshell.Networking
import QtQuick
import qs
import qs.bar
import qs.services

// net eth / net home 74% / net offline — клик: nmtui
Seg {
    id: root

    readonly property var dev: Networking.devices.values.find(d => d.connected) ?? null
    readonly property bool isWifi: dev !== null && dev.type === DeviceType.Wifi
    readonly property var wifi: isWifi ? dev.networks.values.find(n => n.connected) ?? null : null
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited
        || Networking.connectivity === NetworkConnectivity.Portal

    function pct(s) { return Math.round(s <= 1 ? s * 100 : s) + "%"; }

    label: "net"
    value: !dev ? "offline"
        : isWifi ? (wifi ? wifi.name + " " + pct(wifi.signalStrength) : "wifi")
        : "eth"
    compact: !dev ? "off" : isWifi ? (wifi ? pct(wifi.signalStrength) : "wifi") : "eth"
    valueColor: !dev ? Theme.red : limited ? Theme.yellow : Theme.fg
    onLeftClicked: Term.float(["nmtui"])
}
