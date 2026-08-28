import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property var anchorWindow
    // rect (in anchorWindow coords) of the chip that opened this popup — see AudioPopup.
    property rect anchorRect: Qt.rect(0, 0, 0, 0)

    signal dismissed()

    anchor.window: anchorWindow
    anchor.rect.x: anchorRect.x + anchorRect.width - width
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 300
    implicitHeight: 400
    color: Theme.surface
    grabFocus: true

    onVisibleChanged: {
        Bluetooth.setPolling(visible)
        if (visible) {
            Bluetooth.clearError()
            Bluetooth.refresh()
        } else {
            // never leave the radio scanning in the background
            if (Bluetooth.discovering) Bluetooth.setDiscovery(false)
            root.dismissed()
        }
    }

    function statusLabel(dev) {
        if (dev.connected) return "Connected"
        if (!dev.paired) return "Available"
        return "Paired"
    }

    function statusColor(dev) {
        if (dev.connected) return Theme.accent
        return Theme.fgDim
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Column {
            id: topSection
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            // ---------------- Header ----------------
            RowLayout {
                width: parent.width

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!Bluetooth.hasAdapter) return "No adapter"
                        if (!Bluetooth.adapterPowered) return "Bluetooth off"
                        if (Bluetooth.connectedCount > 0) return "Connected (" + Bluetooth.connectedCount + ")"
                        return "On"
                    }
                    color: Theme.fgBright
                    font.family: "monospace"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    visible: Bluetooth.hasAdapter && Bluetooth.adapterPowered
                    text: Bluetooth.discovering ? "Stop scan" : "Scan"
                    color: Theme.accent
                    font.family: "monospace"
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: !Bluetooth.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bluetooth.setDiscovery(!Bluetooth.discovering)
                    }
                }

                Rectangle {
                    visible: Bluetooth.hasAdapter
                    width: 30
                    height: 16
                    radius: 8
                    color: Bluetooth.adapterPowered ? Theme.accent : Theme.muted

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.surface
                        anchors.verticalCenter: parent.verticalCenter
                        x: Bluetooth.adapterPowered ? parent.width - width - 2 : 2

                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !Bluetooth.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bluetooth.togglePower()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.muted }

            // ---------------- No adapter / powered off ----------------
            Text {
                visible: !Bluetooth.hasAdapter
                text: "No Bluetooth adapter found\n(is bluetoothd running?)"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 11
            }

            Text {
                visible: Bluetooth.hasAdapter && !Bluetooth.adapterPowered
                text: "Turn on Bluetooth to see devices"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 11
            }

            Text {
                visible: Bluetooth.hasAdapter && Bluetooth.adapterPowered && Bluetooth.devices.length === 0
                text: Bluetooth.discovering ? "Searching for devices…" : "No devices found — press Scan"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        // ---------------- Error ----------------
        Text {
            id: errorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: Bluetooth.lastError.length > 0
            text: Bluetooth.lastError
            color: Theme.red
            font.family: "monospace"
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        // ---------------- Device list ----------------
        Flickable {
            anchors.top: topSection.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: errorText.visible ? errorText.top : parent.bottom
            anchors.bottomMargin: errorText.visible ? 4 : 0
            visible: Bluetooth.hasAdapter && Bluetooth.adapterPowered && Bluetooth.devices.length > 0
            contentHeight: devicesCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: devicesCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: Bluetooth.devices

                    delegate: Column {
                        id: rowRoot
                        required property var modelData
                        width: devicesCol.width

                        readonly property var dev: modelData

                        Rectangle {
                            width: parent.width
                            height: 34
                            color: rowHover.containsMouse ? Theme.muted : "transparent"
                            opacity: Bluetooth.busy ? 0.55 : 1

                            // full-row click target, declared before the action
                            // buttons so those stack on top of it
                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !Bluetooth.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const dev = rowRoot.dev
                                    if (dev.connected) {
                                        Bluetooth.disconnectDevice(dev)
                                    } else if (dev.paired) {
                                        Bluetooth.connectDevice(dev)
                                    } else {
                                        Bluetooth.pairDevice(dev)
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 8

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: rowRoot.dev.connected ? Theme.accent : (rowRoot.dev.paired ? Theme.fgBright : Theme.fgDim)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: rowRoot.dev.name
                                        elide: Text.ElideRight
                                        color: rowRoot.dev.connected ? Theme.accent : Theme.fgBright
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                        font.bold: rowRoot.dev.connected
                                    }
                                    Text {
                                        text: root.statusLabel(rowRoot.dev) + (rowRoot.dev.trusted && !rowRoot.dev.connected ? " · trusted" : "")
                                        color: root.statusColor(rowRoot.dev)
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    visible: rowRoot.dev.battery !== null
                                    text: rowRoot.dev.battery + "%"
                                    color: Theme.fgDim
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                }

                                Text {
                                    visible: rowRoot.dev.paired
                                    text: "Remove"
                                    color: Theme.red
                                    font.family: "monospace"
                                    font.pixelSize: 10

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: !Bluetooth.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Bluetooth.removeDevice(rowRoot.dev)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
