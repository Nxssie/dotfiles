pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Rolling battery history + stats that UPower's own D-Bus interface has
// (charge cycles, absolute Wh capacities) but Quickshell's UPower service
// doesn't surface in QML, so those are read straight from sysfs instead.
Singleton {
    id: root

    readonly property int sampleInterval: 15000 // ms
    readonly property int maxSamples: 240 // 1h of history at sampleInterval

    // [{ t: epochMs, pct: number, charging: bool }], oldest first
    property var history: []

    property int cycleCount: -1
    property real energyFullWh: 0
    property real energyFullDesignWh: 0

    // UPower.displayDevice is a synthetic aggregate (upower's "DisplayDevice"):
    // great for percentage/state/rate, but it carries no native-path, model or
    // capacity data. Health and sysfs-derived stats need the real battery
    // device instead, found among UPower.devices.
    readonly property var device: UPower.displayDevice
    readonly property var realBatteryDevice: {
        const list = UPower.devices ? UPower.devices.values : []
        for (const d of list) {
            if (d && d.isLaptopBattery)
                return d
        }
        return null
    }
    readonly property bool healthSupported: !!(realBatteryDevice && realBatteryDevice.healthSupported)
    readonly property real healthPercentage: realBatteryDevice ? realBatteryDevice.healthPercentage : 0

    function _sample() {
        if (!device || !device.ready || !device.isPresent || !device.isLaptopBattery)
            return
        const charging = device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.PendingCharge
        const next = root.history.concat([{ t: Date.now(), pct: device.percentage * 100, charging: charging }])
        if (next.length > root.maxSamples)
            next.splice(0, next.length - root.maxSamples)
        root.history = next
    }

    Timer {
        interval: root.sampleInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._sample()
    }

    // Cycle count and design capacity are effectively static per boot, so
    // a slow poll (plus a kick once the device data actually arrives) is
    // enough — no need to chase these in real time.
    Timer {
        interval: 5 * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refreshSysfs()
    }

    Connections {
        target: UPower.devices
        function onValuesChanged() { root._refreshSysfs() }
    }

    function _refreshSysfs() {
        const native = root.realBatteryDevice ? root.realBatteryDevice.nativePath : ""
        if (!native)
            return
        const base = "/sys/class/power_supply/" + native + "/"
        sysfsProc.command = ["bash", "-c",
            "cat '" + base + "cycle_count' 2>/dev/null; " +
            "cat '" + base + "energy_full' 2>/dev/null; " +
            "cat '" + base + "energy_full_design' 2>/dev/null"]
        sysfsProc.running = false
        sysfsProc.running = true
    }

    Process {
        id: sysfsProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                const cycles = lines.length >= 1 ? parseInt(lines[0], 10) : NaN
                root.cycleCount = isNaN(cycles) ? -1 : cycles

                const full = lines.length >= 2 ? parseInt(lines[1], 10) : NaN
                const design = lines.length >= 3 ? parseInt(lines[2], 10) : NaN
                root.energyFullWh = isNaN(full) ? 0 : full / 1e6
                root.energyFullDesignWh = isNaN(design) ? 0 : design / 1e6
            }
        }
    }
}
