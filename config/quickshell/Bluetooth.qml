pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Talks to BlueZ directly over D-Bus (org.bluez) via busctl — same approach
// Network.qml uses with iwd. Only pairing goes through bluetoothctl, since
// that requires registering a D-Bus agent to confirm, which busctl alone
// can't do.
Singleton {
    id: root

    readonly property string busName: "org.bluez"

    property string adapterPath: ""
    property bool hasAdapter: false
    property bool adapterPowered: false
    property bool discovering: false

    property var devices: []
    property bool busy: false
    property string lastError: ""

    // While the popover is visible: poll faster, since discovery results
    // only appear on refresh and a slow tick makes new devices feel sluggish.
    property bool polling: false

    Timer {
        id: refreshTimer
        interval: root.polling ? 1500 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function setPolling(active) {
        if (root.polling === active) return
        root.polling = active
        refreshTimer.restart()
    }

    // Never restart an in-flight query: killing it mid-read hands the
    // collector truncated JSON, which wipes adapter state for one cycle
    // and makes the chip/popup flicker.
    function refresh() {
        if (managedProc.running) return
        managedProc.running = true
    }

    function clearError() {
        root.lastError = ""
    }

    Process {
        id: managedProc
        command: ["busctl", "--system", "--json=short", "call", root.busName, "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: root._handleManaged(text)
        }
    }

    function _handleManaged(text) {
        let parsed
        try {
            parsed = JSON.parse(text)
        } catch (e) {
            // org.bluez unreachable (bluetoothd off or bluez missing)
            root.hasAdapter = false
            root.adapterPath = ""
            root.adapterPowered = false
            root.discovering = false
            root.devices = []
            return
        }
        const objects = (parsed.data && parsed.data[0]) || {}

        let foundAdapter = ""
        let foundPowered = false
        let foundDiscovering = false
        const list = []

        for (const path in objects) {
            const ifaces = objects[path]

            const adapter = ifaces["org.bluez.Adapter1"]
            if (adapter) {
                foundAdapter = path
                foundPowered = adapter.Powered ? adapter.Powered.data : false
                foundDiscovering = adapter.Discovering ? adapter.Discovering.data : false
            }

            const dev = ifaces["org.bluez.Device1"]
            if (dev) {
                const battery = ifaces["org.bluez.Battery1"]
                list.push({
                    path: path,
                    address: dev.Address ? dev.Address.data : "",
                    name: (dev.Alias ? dev.Alias.data : "") || (dev.Name ? dev.Name.data : "") || (dev.Address ? dev.Address.data : ""),
                    paired: dev.Paired ? dev.Paired.data : false,
                    trusted: dev.Trusted ? dev.Trusted.data : false,
                    connected: dev.Connected ? dev.Connected.data : false,
                    rssi: dev.RSSI !== undefined ? dev.RSSI.data : null,
                    battery: battery && battery.Percentage ? battery.Percentage.data : null
                })
            }
        }

        root.hasAdapter = foundAdapter !== ""
        root.adapterPath = foundAdapter
        root.adapterPowered = foundPowered
        root.discovering = foundDiscovering

        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            const ra = a.rssi === null ? -999 : a.rssi
            const rb = b.rssi === null ? -999 : b.rssi
            if (ra !== rb) return rb - ra
            return a.name.localeCompare(b.name)
        })
        root.devices = list
        root._autoConnect()
    }

    // BlueZ never initiates connections from the host side — trusted devices
    // only reconnect when THEY reach out (e.g. earbuds taken out of the case).
    // If a device was already on before this shell started (boot, or it was
    // paired to another host), nobody connects. Cover that with one
    // fire-and-forget Connect attempt per trusted device on startup;
    // devices that are off just time out silently on the bluez side.
    property bool _autoConnectDone: false
    function _autoConnect() {
        if (root._autoConnectDone || !root.adapterPowered) return
        root._autoConnectDone = true
        for (const dev of root.devices) {
            if (dev.trusted && dev.paired && !dev.connected)
                Quickshell.execDetached(["busctl", "--system", "call", root.busName, dev.path, "org.bluez.Device1", "Connect"])
        }
    }

    readonly property int connectedCount: devices.filter(d => d.connected).length

    Process {
        id: actionProc
        property var onDone: null
        command: ["true"]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: actionStderr
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            root.lastError = exitCode !== 0 ? (actionStderr.text.trim() || "Operation failed") : ""
            if (actionProc.onDone) actionProc.onDone(exitCode === 0)
            root.refresh()
        }
    }

    function _run(cmd, onDone) {
        root.busy = true
        actionProc.onDone = onDone || null
        actionProc.command = cmd
        actionProc.running = false
        actionProc.running = true
    }

    function togglePower() {
        if (!root.adapterPath || root.busy) return
        root._run(["busctl", "--system", "set-property", root.busName, root.adapterPath, "org.bluez.Adapter1", "Powered", "b", root.adapterPowered ? "false" : "true"])
    }

    // BlueZ cancels discovery as soon as the D-Bus client that requested it
    // disconnects, so a one-shot busctl StartDiscovery is a no-op in practice
    // — keep a bluetoothctl process alive for the whole scan instead.
    Process {
        id: scanProc
        command: ["bluetoothctl", "scan", "on"]
        stdout: StdioCollector {}
        onExited: root.discovering = false
    }

    function setDiscovery(active) {
        if (!root.adapterPath) return
        scanProc.running = active
        // optimistic; the next refresh reads the real adapter state
        root.discovering = active
    }

    function connectDevice(dev) {
        if (!dev.path || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, dev.path, "org.bluez.Device1", "Connect"])
    }

    function disconnectDevice(dev) {
        if (!dev.path || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, dev.path, "org.bluez.Device1", "Disconnect"])
    }

    function pairDevice(dev) {
        if (!dev.address || root.busy) return
        // Trust right after pairing so the device auto-reconnects on boot,
        // then connect for the first time.
        root._run(["bluetoothctl", "pair", dev.address], ok => {
            if (!ok) return
            root._run(["busctl", "--system", "set-property", root.busName, dev.path, "org.bluez.Device1", "Trusted", "b", "true"], ok2 => {
                if (ok2) root.connectDevice(dev)
            })
        })
    }

    function removeDevice(dev) {
        if (!dev.path || !root.adapterPath || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, root.adapterPath, "org.bluez.Adapter1", "RemoveDevice", "objpath", dev.path])
    }
}
