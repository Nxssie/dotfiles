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

    // Keeps the screen awake (pauses hypridle's whole dim/lock/suspend chain)
    // while caffeine is on manually, or automatically while something is playing
    // or a window is fullscreen (video, presentation...). Browsers only request
    // an inhibitor for <video> themselves, so this covers the rest.
    property bool caffeineActive: false
    // ToplevelManager.toplevels.values isn't a notifiable binding, so recompute on
    // the Hyprland events that can change fullscreen state
    property bool anyFullscreen: false
    function refreshFullscreen() {
        anyFullscreen = ToplevelManager.toplevels.values.some(t => t.fullscreen)
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "fullscreen": case "closewindow": case "workspace": case "activewindow":
                fullscreenDebounce.restart()
            }
        }
    }
    // Toplevel state updates a tick after the event
    Timer { id: fullscreenDebounce; interval: 50; onTriggered: bar.refreshFullscreen() }
    readonly property bool autoInhibit: Media.playing || anyFullscreen
    IdleInhibitor {
        window: bar
        enabled: bar.caffeineActive || bar.autoInhibit
    }

    // Single registry of popups: adding a chip with a popup means adding one
    // entry here. `chip` is only set for popups that drop from their chip
    // (right side); center popups anchor themselves under the clock.
    readonly property var popups: ({
        clock:     { popup: clockPopup },
        media:     { popup: mediaPopup },
        audio:     { popup: audioPopup,       chip: audioChip },
        battery:   { popup: batteryPopup,     chip: batteryChip },
        network:   { popup: networkPopup,     chip: networkChip },
        claude:    { popup: claudeUsagePopup, chip: claudeChip },
        bluetooth: { popup: bluetoothPopup,   chip: bluetoothChip },
    })

    property string activePopup: ""
    function togglePopup(name) {
        activePopup = (activePopup === name) ? "" : name
        for (const key in popups) {
            const entry = popups[key]
            entry.popup.visible = activePopup === key
            // Recompute against the actual chip each time one opens.
            if (entry.popup.visible && entry.chip)
                entry.popup.anchorRect = bar.itemRect(entry.chip)
        }
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

                // A window on this workspace demands attention (xdg-activation request
                // while unfocused). Highlighted in red until the workspace gets focus.
                readonly property bool urgent: !modelData.focused
                    && modelData.toplevels.values.some(t => t.urgent)

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.focused ? Theme.accent : (urgent ? Theme.red : Theme.fgDim)
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: modelData.focused || urgent
                }

                Rectangle {
                    visible: modelData.focused || urgent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: wsLabel.implicitWidth
                    height: 2
                    color: urgent ? Theme.red : Theme.accent
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
        // Wide enough that the hover area always covers both chip rows (the
        // clock stays centered, so the wider row decides the half-width) —
        // otherwise mousing toward an edge chip drops the hover that reveals it.
        width: clockText.implicitWidth + 2 * (14 + Math.max(leftChips.implicitWidth, rightChips.implicitWidth) + 20)
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

        // Chips left of the clock live in a layout instead of an anchor chain:
        // a hidden chip collapses and the visible ones pack toward the clock,
        // so no ghost gap is left when e.g. caffeine is inactive.
        RowLayout {
            id: leftChips
            anchors.right: clockText.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            CaffeineChip {
                id: caffeineChip
                active: bar.caffeineActive
                auto: bar.autoInhibit
                hovered: centerHover.hovered
                onToggled: bar.caffeineActive = !bar.caffeineActive
            }

            MediaChip {
                id: mediaChip
                onActivated: bar.togglePopup("media")
            }
        }

        // Mirror of the left-side layout: chips right of the clock pack toward
        // it and collapse when hidden, so new center widgets slot in here.
        RowLayout {
            id: rightChips
            anchors.left: clockText.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            ThemeToggle {
                hovered: centerHover.hovered
            }

            MicChip {
                hovered: centerHover.hovered
            }

            ScreenshotChip {
                hovered: centerHover.hovered
            }
        }
    }

    // ---------------- Right side: claude + bluetooth + network + audio + battery ----------------
    // Tray convention: app-specific chips furthest from the corner, connectivity
    // grouped together, and system vitals (audio, battery) nearest the edge.
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        ClaudeChip {
            id: claudeChip
            onActivated: bar.togglePopup("claude")
        }

        BluetoothChip {
            id: bluetoothChip
            onActivated: bar.togglePopup("bluetooth")
        }

        NetworkChip {
            id: networkChip
            onActivated: bar.togglePopup("network")
        }

        AudioChip {
            id: audioChip
            onActivated: bar.togglePopup("audio")
        }

        BatteryChip {
            id: batteryChip
            onActivated: bar.togglePopup("battery")
        }
    }
}
