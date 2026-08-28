import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

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

    // "" | "clock" | "battery" | "network" | "claude" | "bluetooth" | "media" | "audio"
    property string activePopup: ""
    function togglePopup(name) {
        activePopup = (activePopup === name) ? "" : name
        audioPopup.visible = activePopup === "audio"
        clockPopup.visible = activePopup === "clock"
        batteryPopup.visible = activePopup === "battery"
        networkPopup.visible = activePopup === "network"
        claudeUsagePopup.visible = activePopup === "claude"
        bluetoothPopup.visible = activePopup === "bluetooth"
        mediaPopup.visible = activePopup === "media"

        // Right-side popups drop from the chip that opened them, not a fixed
        // corner — recompute against the actual chip each time one opens.
        if (audioPopup.visible) audioPopup.anchorRect = bar.itemRect(audioChip)
        if (batteryPopup.visible) batteryPopup.anchorRect = bar.itemRect(batteryChip)
        if (networkPopup.visible) networkPopup.anchorRect = bar.itemRect(networkChip)
        if (claudeUsagePopup.visible) claudeUsagePopup.anchorRect = bar.itemRect(claudeChip)
        if (bluetoothPopup.visible) bluetoothPopup.anchorRect = bar.itemRect(bluetoothChip)
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

    BluetoothPopup {
        id: bluetoothPopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "bluetooth") bar.activePopup = ""
    }

    ClaudeUsagePopup {
        id: claudeUsagePopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "claude") bar.activePopup = ""
    }

    MediaPopup {
        id: mediaPopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "media") bar.activePopup = ""
    }

    AudioPopup {
        id: audioPopup
        anchorWindow: bar
        onDismissed: if (bar.activePopup === "audio") bar.activePopup = ""
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

    // ---------------- Center cluster: media + caffeine + clock + theme ----------------
    // The clock's own anchors.centerIn never moves; media/caffeine/theme sit either
    // side and stay hidden unless hovered, except caffeine which stays visible
    // while active so an inhibited screen is never silently hidden.
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

        MediaChip {
            id: mediaChip
            anchors.right: caffeineChip.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            onActivated: bar.togglePopup("media")
        }

        CaffeineChip {
            id: caffeineChip
            anchors.right: clockText.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            active: bar.caffeineActive
            hovered: centerHover.hovered
            onToggled: bar.caffeineActive = !bar.caffeineActive
        }

        ThemeToggle {
            anchors.left: clockText.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            hovered: centerHover.hovered
        }
    }

    // ---------------- Right side: audio + bluetooth + network + claude + battery ----------------
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        AudioChip {
            id: audioChip
            onActivated: bar.togglePopup("audio")
        }

        BluetoothChip {
            id: bluetoothChip
            onActivated: bar.togglePopup("bluetooth")
        }

        NetworkChip {
            id: networkChip
            onActivated: bar.togglePopup("network")
        }

        ClaudeChip {
            id: claudeChip
            onActivated: bar.togglePopup("claude")
        }

        BatteryChip {
            id: batteryChip
            onActivated: bar.togglePopup("battery")
        }
    }
}
