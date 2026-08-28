import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 26
    color: Theme.bg

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:bar"
    exclusiveZone: implicitHeight

    // keeps the screen awake while caffeineActive is true
    property bool caffeineActive: false
    IdleInhibitor {
        window: bar
        enabled: bar.caffeineActive
    }

    // "" | "clock" | "battery" | "network"
    property string activePopup: ""
    function togglePopup(name) {
        activePopup = (activePopup === name) ? "" : name
        clockPopup.visible = activePopup === "clock"
        batteryPopup.visible = activePopup === "battery"
        networkPopup.visible = activePopup === "network"
    }

    readonly property var connectedNetwork: {
        for (const n of Network.networks) {
            if (n.connected) return n
        }
        return null
    }

    function networkSignalBars(signal) {
        if (signal === null || signal === undefined) return 0
        if (signal >= -55) return 4
        if (signal >= -65) return 3
        if (signal >= -75) return 2
        return 1
    }

    // "" | "wifi" | "ethernet"
    readonly property string networkKind: {
        if (Network.ethernetConnected) return "ethernet"
        return "wifi"
    }

    readonly property color networkIconColor: {
        if (Network.ethernetConnected) return Theme.fg
        if (!Network.devicePowered) return Theme.muted
        if (!bar.connectedNetwork) return Theme.fgDim
        return bar.networkSignalBars(bar.connectedNetwork.signal) <= 2 ? Theme.yellow : Theme.fg
    }

    ClockPopup {
        id: clockPopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "clock") bar.activePopup = ""
    }

    BatteryPopup {
        id: batteryPopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "battery") bar.activePopup = ""
    }

    NetworkPopup {
        id: networkPopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "network") bar.activePopup = ""
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ---------------- Workspaces (left) ----------------
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: Hyprland.workspaces

            delegate: Item {
                required property var modelData
                width: wsLabel.implicitWidth + 8
                height: bar.implicitHeight

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.focused ? Theme.accent : Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: modelData.focused
                }

                Rectangle {
                    visible: modelData.focused
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: wsLabel.implicitWidth
                    height: 2
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + modelData.name)
                }
            }
        }
    }

    // ---------------- Center cluster: caffeine + clock + theme ----------------
    // The clock's own anchors.centerIn never moves; caffeine/theme sit either
    // side and stay hidden unless hovered, except caffeine which stays
    // visible while active so an inhibited screen is never silently hidden.
    Item {
        id: centerCluster
        anchors.centerIn: parent
        width: 260
        height: bar.implicitHeight

        HoverHandler {
            id: centerHover
        }

        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm:ss")
            color: Theme.fg
            font.family: "monospace"
            font.pixelSize: 12
            font.bold: true

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.togglePopup("clock")
            }
        }

        // Caffeine toggle
        Rectangle {
            id: caffeineChip
            anchors.right: clockText.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: caffeineRow.implicitWidth + 12
            height: 18
            radius: 0
            color: bar.caffeineActive ? Theme.yellow : Theme.muted
            opacity: bar.caffeineActive ? 1 : (centerHover.hovered ? 0.7 : 0)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            RowLayout {
                id: caffeineRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "" // nf-fa-coffee
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 12
                    color: bar.caffeineActive ? Theme.bg : Theme.fg
                }
                Text {
                    text: bar.caffeineActive ? "ON" : "OFF"
                    color: bar.caffeineActive ? Theme.bg : Theme.fg
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.caffeineActive = !bar.caffeineActive
            }
        }

        // Light/dark theme toggle
        Text {
            id: themeToggle
            anchors.left: clockText.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.dark ? "" : "" // nf-fa-moon_o / nf-fa-sun_o
            font.family: "Symbols Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
            opacity: centerHover.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Theme.toggle()
            }
        }
    }

    // ---------------- Right side: network + battery ----------------
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Network
        Rectangle {
            id: networkChip
            width: networkIcon.implicitWidth + 12
            height: 18
            radius: 0
            color: Theme.muted

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.togglePopup("network")
            }

            Text {
                id: networkIcon
                anchors.centerIn: parent
                // nf-fa-ethernet (U+EF44) / nf-fa-wifi (U+F1EB) — via fromCharCode
                // to keep the exact PUA codepoint unambiguous in source.
                text: String.fromCharCode(bar.networkKind === "ethernet" ? 0xEF44 : 0xF1EB)
                font.family: "Symbols Nerd Font"
                font.pixelSize: 13
                color: bar.networkIconColor
            }
        }

        // Battery
        Rectangle {
            id: batteryChip
            visible: UPower.displayDevice.isLaptopBattery
            width: batteryRow.implicitWidth + 12
            height: 18
            radius: 0
            color: Theme.muted

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.togglePopup("battery")
            }

            RowLayout {
                id: batteryRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: {
                        const s = UPower.displayDevice.state;
                        const pct = UPower.displayDevice.percentage * 100;
                        if (s === UPowerDeviceState.Charging || s === UPowerDeviceState.PendingCharge)
                            return ""; // nf-fa-bolt
                        if (s === UPowerDeviceState.FullyCharged)
                            return ""; // nf-fa-plug
                        if (pct >= 90)
                            return ""; // nf-fa-battery_full
                        if (pct >= 65)
                            return ""; // nf-fa-battery_three_quarters
                        if (pct >= 40)
                            return ""; // nf-fa-battery_half
                        if (pct >= 15)
                            return ""; // nf-fa-battery_quarter
                        return ""; // nf-fa-battery_empty
                    }
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 12
                    color: {
                        const pct = UPower.displayDevice.percentage * 100;
                        const charging = UPower.displayDevice.state === UPowerDeviceState.Charging;
                        if (charging)
                            return Theme.accent;
                        if (pct <= 15)
                            return Theme.red;
                        if (pct <= 30)
                            return Theme.yellow;
                        return Theme.fg;
                    }
                }

                Text {
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                    color: {
                        const pct = UPower.displayDevice.percentage * 100;
                        const charging = UPower.displayDevice.state === UPowerDeviceState.Charging;
                        if (!charging && pct <= 15)
                            return Theme.red;
                        if (!charging && pct <= 30)
                            return Theme.yellow;
                        return Theme.fg;
                    }
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
