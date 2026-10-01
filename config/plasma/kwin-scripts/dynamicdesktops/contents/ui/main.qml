import QtQuick
import QtQml.Models
import org.kde.kwin

// Dynamic workspaces, like Hyprland's: a workspace exists only while it is needed.
//
//  - Meta+N (1..9, 0 = 10)        go to workspace N, creating it (and any lower
//                                 missing one) if it does not exist yet
//  - Meta+Shift+N                 send the active window to workspace N, same rule
//  - empty workspaces after the last occupied (or current) one are removed
//
// Workspaces stay contiguous (KWin has no sparse list), so 1..max(occupied, current).
Item {
    id: root

    readonly property int maxDesktops: 10
    // Pruning waits this long after login so session restore can put windows back
    // on their workspaces before empty ones are removed
    readonly property int startupGraceMs: 20000

    property bool ready: false

    function desktopIndex(desktop) {
        const list = Workspace.desktops
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === desktop.id) return i
        }
        return -1
    }

    function ensure(n) {
        while (Workspace.desktops.length < n) {
            const count = Workspace.desktops.length
            Workspace.createDesktop(count, "Desktop " + (count + 1))
        }
    }

    function goTo(n) {
        ensure(n)
        Workspace.currentDesktop = Workspace.desktops[n - 1]
    }

    function moveTo(n) {
        const win = Workspace.activeWindow
        if (!win || !win.normalWindow) return
        ensure(n)
        win.desktops = [Workspace.desktops[n - 1]]
    }

    function prune() {
        let keep = desktopIndex(Workspace.currentDesktop) + 1
        for (const win of Workspace.stackingOrder) {
            // windows pinned to every workspace say nothing about where work happens
            if (!win.normalWindow || win.onAllDesktops) continue
            for (const desktop of win.desktops) {
                keep = Math.max(keep, desktopIndex(desktop) + 1)
            }
        }
        keep = Math.max(keep, 1)
        const list = Workspace.desktops
        for (let i = list.length - 1; i >= keep; i--) {
            Workspace.removeDesktop(list[i])
        }
    }

    function schedulePrune() {
        if (ready) debounce.restart()
    }

    function watch(win) {
        win.desktopsChanged.connect(schedulePrune)
    }

    Timer {
        id: startup
        interval: root.startupGraceMs
        running: true
        onTriggered: {
            root.ready = true
            root.prune()
        }
    }

    // Coalesces bursts (closing several windows, dragging between workspaces...)
    Timer {
        id: debounce
        interval: 300
        onTriggered: root.prune()
    }

    Connections {
        target: Workspace
        function onWindowAdded(win) { root.watch(win); root.schedulePrune() }
        function onWindowRemoved(win) { root.schedulePrune() }
        function onCurrentDesktopChanged() { root.schedulePrune() }
    }

    Component.onCompleted: {
        for (const win of Workspace.stackingOrder) watch(win)
    }

    Instantiator {
        model: root.maxDesktops
        delegate: ShortcutHandler {
            required property int index
            name: "DynamicDesktopsGo" + (index + 1)
            text: "Dynamic Desktops: Go to workspace " + (index + 1)
            sequence: "Meta+" + ((index + 1) % 10)
            onActivated: root.goTo(index + 1)
        }
    }

    Instantiator {
        model: root.maxDesktops
        delegate: ShortcutHandler {
            required property int index
            name: "DynamicDesktopsMove" + (index + 1)
            text: "Dynamic Desktops: Move window to workspace " + (index + 1)
            sequence: "Meta+Shift+" + ((index + 1) % 10)
            onActivated: root.moveTo(index + 1)
        }
    }
}
