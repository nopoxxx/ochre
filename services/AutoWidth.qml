pragma Singleton
import Quickshell
import QtQuick
import "autowidth.js" as AW

Singleton {
    id: root

    readonly property bool enabled: Settings.get("shell.autoWidth")
    property var sets: null
    property var dirty: []

    Connections {
        target: Niri
        function onWindowsChanged() { root.track(); }
    }

    function track() {
        const next = AW.tiledSets(Niri.windows);
        if (sets !== null && enabled)
            dirty = dirty.concat(AW.changed(sets, next).filter(id => dirty.indexOf(id) < 0));
        sets = next;
        if (dirty.length) apply.restart();
    }

    Timer {
        id: apply
        interval: 120
        onTriggered: {
            for (const ws of root.dirty)
                for (const [id, width] of AW.plan(Niri.windowsOn(ws)))
                    Niri.action("set-window-width", "--id", String(id), width);
            root.dirty = [];
        }
    }
}
