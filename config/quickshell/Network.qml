pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Talks to iwd directly over D-Bus (net.connman.iwd) via busctl — no
// NetworkManager involved. Connecting to a brand new secured network goes
// through iwctl instead, since that requires acting as an iwd Agent to
// supply the passphrase, which busctl alone can't do.
Singleton {
    id: root

    readonly property string busName: "net.connman.iwd"

    property string devicePath: ""
    property string deviceName: ""
    property bool devicePowered: false
    property bool stationScanning: false
    property string stationState: ""
    property string connectedNetworkPath: ""
    property var networks: []
    property bool busy: false
    property string lastError: ""

    property string ipAddress: ""
    property string gateway: ""
    property var dnsServers: []

    property real rxRate: 0 // bytes/s
    property real txRate: 0 // bytes/s
    property real _lastRxBytes: -1
    property real _lastTxBytes: -1
    property real _lastSampleTime: 0

    property bool ethernetConnected: false
    property string ethernetName: ""
    property string ethernetIp: ""

    property var _pendingKnown: ({})
    property var _pendingInRange: []

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Only while the popover is visible: lightweight polling every second
    // of the interface's traffic counters for live speed.
    Timer {
        id: speedTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: root._sampleSpeed()
    }

    function setSpeedPolling(active) {
        if (active) {
            root._lastRxBytes = -1
            root._lastTxBytes = -1
        }
        speedTimer.running = active && root.deviceName !== ""
    }

    function refresh() {
        managedProc.running = false
        managedProc.running = true
        wirelessProc.running = false
        wirelessProc.running = true
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

    Process {
        id: orderedProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root._handleOrdered(text)
        }
    }

    Process {
        id: infoProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root._handleInfo(text)
        }
    }

    Process {
        id: speedProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root._handleSpeed(text)
        }
    }

    // Detects wired interfaces: any UP interface with IPv4 that lacks
    // the sysfs radio marker (/sys/class/net/<if>/wireless), so it
    // doesn't depend on iwd's wifi interface name (avoids a race
    // condition if that data hasn't arrived yet).
    Process {
        id: wirelessProc
        command: ["bash", "-c", 'shopt -s nullglob; for i in /sys/class/net/*/wireless; do basename "$(dirname "$i")"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const wireless = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                ethProc.command = ["ip", "-j", "addr", "show"]
                ethProc._wireless = wireless
                ethProc.running = false
                ethProc.running = true
            }
        }
    }

    Process {
        id: ethProc
        property var _wireless: []
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root._handleEthernet(text, ethProc._wireless)
        }
    }

    function _handleEthernet(text, wireless) {
        let parsed
        try {
            parsed = JSON.parse(text)
        } catch (e) {
            return
        }
        for (const iface of parsed) {
            if (iface.ifname === "lo" || wireless.indexOf(iface.ifname) !== -1) continue
            if (iface.operstate !== "UP") continue
            const addrs = iface.addr_info || []
            const inet = addrs.find(a => a.family === "inet")
            if (inet) {
                root.ethernetConnected = true
                root.ethernetName = iface.ifname
                root.ethernetIp = inet.local
                return
            }
        }
        root.ethernetConnected = false
        root.ethernetName = ""
        root.ethernetIp = ""
    }

    function _handleManaged(text) {
        let parsed
        try {
            parsed = JSON.parse(text)
        } catch (e) {
            return
        }
        const objects = (parsed.data && parsed.data[0]) || {}

        let foundDevicePath = ""
        let foundDeviceName = ""
        let foundPowered = false
        let foundState = ""
        let foundScanning = false
        let foundConnected = ""
        const known = {}
        const inRange = []

        for (const path in objects) {
            const ifaces = objects[path]

            const dev = ifaces["net.connman.iwd.Device"]
            if (dev && dev.Mode && dev.Mode.data === "station") {
                foundDevicePath = path
                foundDeviceName = dev.Name ? dev.Name.data : ""
                foundPowered = dev.Powered ? dev.Powered.data : false
            }

            const station = ifaces["net.connman.iwd.Station"]
            if (station) {
                foundState = station.State ? station.State.data : ""
                foundScanning = station.Scanning ? station.Scanning.data : false
                foundConnected = station.ConnectedNetwork ? station.ConnectedNetwork.data : ""
            }

            const kn = ifaces["net.connman.iwd.KnownNetwork"]
            if (kn) {
                known[path] = {
                    knownPath: path,
                    name: kn.Name ? kn.Name.data : "",
                    type: kn.Type ? kn.Type.data : "",
                    autoConnect: kn.AutoConnect ? kn.AutoConnect.data : false,
                    lastConnected: kn.LastConnectedTime ? kn.LastConnectedTime.data : ""
                }
            }

            const net = ifaces["net.connman.iwd.Network"]
            if (net) {
                inRange.push({
                    path: path,
                    name: net.Name ? net.Name.data : "",
                    type: net.Type ? net.Type.data : "",
                    connected: net.Connected ? net.Connected.data : false,
                    knownPath: net.KnownNetwork ? net.KnownNetwork.data : ""
                })
            }
        }

        root.devicePath = foundDevicePath
        root.deviceName = foundDeviceName
        root.devicePowered = foundPowered
        root.stationState = foundState
        root.stationScanning = foundScanning
        root.connectedNetworkPath = foundConnected
        root._pendingKnown = known
        root._pendingInRange = inRange

        if (foundDevicePath && foundPowered) {
            orderedProc.command = ["busctl", "--system", "--json=short", "call", root.busName, foundDevicePath, "net.connman.iwd.Station", "GetOrderedNetworks"]
            orderedProc.running = false
            orderedProc.running = true
        } else {
            root._merge({})
        }

        if (foundDeviceName && foundState === "connected") {
            infoProc.command = ["bash", "-c",
                'ip -4 -o addr show "$1" | awk \'{print $4}\' | cut -d/ -f1; ' +
                'ip route show default dev "$1" | awk \'{print $3}\'; ' +
                'resolvectl dns "$1" 2>/dev/null | cut -d: -f2',
                "bash", foundDeviceName]
            infoProc.running = false
            infoProc.running = true
        } else {
            root.ipAddress = ""
            root.gateway = ""
            root.dnsServers = []
        }

        speedTimer.running = speedTimer.running && foundDeviceName !== ""
    }

    function _handleInfo(text) {
        const lines = text.split("\n")
        root.ipAddress = (lines[0] || "").trim()
        root.gateway = (lines[1] || "").trim()
        root.dnsServers = (lines[2] || "").trim().split(/\s+/).filter(s => s.length > 0)
    }

    function _sampleSpeed() {
        if (!root.deviceName) return
        speedProc.command = ["bash", "-c",
            'cat "/sys/class/net/$1/statistics/rx_bytes" "/sys/class/net/$1/statistics/tx_bytes"',
            "bash", root.deviceName]
        speedProc.running = false
        speedProc.running = true
    }

    function _handleSpeed(text) {
        const lines = text.trim().split("\n")
        const rx = parseInt(lines[0], 10)
        const tx = parseInt(lines[1], 10)
        if (isNaN(rx) || isNaN(tx)) return

        const now = Date.now()
        if (root._lastSampleTime > 0) {
            const dt = (now - root._lastSampleTime) / 1000
            if (dt > 0 && root._lastRxBytes >= 0) {
                root.rxRate = Math.max(0, (rx - root._lastRxBytes) / dt)
                root.txRate = Math.max(0, (tx - root._lastTxBytes) / dt)
            }
        }
        root._lastRxBytes = rx
        root._lastTxBytes = tx
        root._lastSampleTime = now
    }

    function formatRate(bytesPerSec) {
        const bitsPerSec = bytesPerSec * 8
        if (bitsPerSec < 1000) return bitsPerSec.toFixed(0) + " b/s"
        if (bitsPerSec < 1000000) return (bitsPerSec / 1000).toFixed(1) + " Kb/s"
        return (bitsPerSec / 1000000).toFixed(1) + " Mb/s"
    }

    function _handleOrdered(text) {
        const signals = {}
        try {
            const parsed = JSON.parse(text)
            const pairs = (parsed.data && parsed.data[0]) || []
            for (const pair of pairs) {
                signals[pair[0]] = pair[1] / 100
            }
        } catch (e) {
            // no signal data, still show the list anyway
        }
        root._merge(signals)
    }

    function _merge(signals) {
        const known = root._pendingKnown
        const inRange = root._pendingInRange
        const seenKnownPaths = {}
        const list = []

        for (const net of inRange) {
            const knownEntry = net.knownPath ? known[net.knownPath] : null
            if (knownEntry) seenKnownPaths[net.knownPath] = true
            list.push({
                path: net.path,
                knownPath: net.knownPath || "",
                name: net.name,
                type: net.type,
                connected: net.connected,
                inRange: true,
                known: !!knownEntry,
                autoConnect: knownEntry ? knownEntry.autoConnect : false,
                signal: signals[net.path] !== undefined ? signals[net.path] : null
            })
        }

        for (const path in known) {
            if (seenKnownPaths[path]) continue
            const k = known[path]
            list.push({
                path: "",
                knownPath: path,
                name: k.name,
                type: k.type,
                connected: false,
                inRange: false,
                known: true,
                autoConnect: k.autoConnect,
                signal: null
            })
        }

        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.inRange !== b.inRange) return a.inRange ? -1 : 1
            const sa = a.signal === null ? -999 : a.signal
            const sb = b.signal === null ? -999 : b.signal
            if (sa !== sb) return sb - sa
            return a.name.localeCompare(b.name)
        })

        root.networks = list
    }

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

    function scan() {
        if (!root.devicePath || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, root.devicePath, "net.connman.iwd.Station", "Scan"])
    }

    function togglePower() {
        if (!root.devicePath || root.busy) return
        root._run(["busctl", "--system", "set-property", root.busName, root.devicePath, "net.connman.iwd.Device", "Powered", "b", root.devicePowered ? "false" : "true"])
    }

    function disconnectNetwork() {
        if (!root.devicePath || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, root.devicePath, "net.connman.iwd.Station", "Disconnect"])
    }

    function connectNetwork(net) {
        if (!net.path || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, net.path, "net.connman.iwd.Network", "Connect"])
    }

    function connectWithPassword(net, password) {
        if (!net.path || !root.deviceName || root.busy) return
        root._run(["iwctl", "--passphrase", password, "station", root.deviceName, "connect", net.name])
    }

    function forgetNetwork(net) {
        if (!net.knownPath || root.busy) return
        root._run(["busctl", "--system", "call", root.busName, net.knownPath, "net.connman.iwd.KnownNetwork", "Forget"])
    }

    // Background WPS push-button listening: while a password prompt is open,
    // repeatedly poll iwd's SimpleConfiguration.PushButton so that pressing
    // the router's physical WPS button connects immediately, without
    // blocking password entry (deliberately kept out of busy/actionProc).
    property bool wpsListening: false
    property bool _wpsCallInFlight: false

    Timer {
        id: wpsTimer
        interval: 4000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: root._wpsAttempt()
    }

    Process {
        id: wpsProc
        command: ["true"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._wpsCallInFlight = false
            if (exitCode === 0) {
                root.wpsListening = false
                wpsTimer.running = false
                root.refresh()
            }
            // non-zero (NotFound/timeout) just means no PBC session detected
            // yet; the timer will retry as long as wpsListening stays true.
        }
    }

    Process {
        id: wpsCancelProc
        command: ["true"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function _wpsAttempt() {
        if (!root.devicePath || root._wpsCallInFlight) return
        root._wpsCallInFlight = true
        wpsProc.command = ["busctl", "--system", "call", root.busName, root.devicePath, "net.connman.iwd.SimpleConfiguration", "PushButton"]
        wpsProc.running = false
        wpsProc.running = true
    }

    function startWpsListen() {
        if (root.wpsListening || !root.devicePath) return
        root.wpsListening = true
        wpsTimer.running = true
    }

    function stopWpsListen() {
        if (!root.wpsListening) return
        root.wpsListening = false
        wpsTimer.running = false
        if (root._wpsCallInFlight) {
            wpsCancelProc.command = ["busctl", "--system", "call", root.busName, root.devicePath, "net.connman.iwd.SimpleConfiguration", "Cancel"]
            wpsCancelProc.running = false
            wpsCancelProc.running = true
        }
    }
}
