import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property var anchorWindow

    signal dismissed()

    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow ? anchorWindow.width - width - 10 : 0
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 300
    implicitHeight: 400
    color: Theme.surface
    grabFocus: true

    // path of the row whose password field is expanded ("" if none)
    property string expandedPath: ""
    property string passwordText: ""

    // Opening a password prompt also starts background WPS push-button
    // listening (see Network.startWpsListen), so pressing the router's
    // physical button connects without needing the password at all.
    onExpandedPathChanged: {
        if (expandedPath !== "") {
            Network.startWpsListen()
        } else {
            Network.stopWpsListen()
        }
    }

    Connections {
        target: Network
        function onConnectedNetworkPathChanged() {
            if (Network.connectedNetworkPath !== "" && root.expandedPath !== "") {
                root.expandedPath = ""
            }
        }
    }

    onVisibleChanged: {
        Network.setSpeedPolling(visible)
        if (visible) {
            Network.clearError()
            Network.refresh()
        } else {
            expandedPath = ""
            passwordText = ""
            root.dismissed()
        }
    }

    function signalBars(signal) {
        if (signal === null) return 0
        if (signal >= -55) return 4
        if (signal >= -65) return 3
        if (signal >= -75) return 2
        return 1
    }

    function statusLabel(net) {
        if (net.connected) return "Connected"
        if (!net.inRange) return "Saved · out of range"
        if (net.known) return "Saved"
        return net.type === "open" ? "Open" : "Secured"
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
                        if (Network.ethernetConnected) return "Connected (wired)"
                        if (!Network.devicePowered) return "Wi-Fi off"
                        return Network.stationState === "connected" ? "Connected" : "Disconnected"
                    }
                    color: Theme.fgBright
                    font.family: "monospace"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    visible: Network.devicePowered
                    text: Network.stationScanning ? "Scanning…" : "Scan"
                    color: Theme.accent
                    font.family: "monospace"
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: !Network.busy && !Network.stationScanning
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Network.scan()
                    }
                }

                Rectangle {
                    width: 30
                    height: 16
                    radius: 8
                    color: Network.devicePowered ? Theme.accent : Theme.muted

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.surface
                        anchors.verticalCenter: parent.verticalCenter
                        x: Network.devicePowered ? parent.width - width - 2 : 2

                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !Network.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Network.togglePower()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.muted }

            // ---------------- Connection info ----------------
            Column {
                width: parent.width
                spacing: 3
                readonly property bool wifiUp: Network.stationState === "connected" && Network.ipAddress !== ""
                visible: wifiUp || Network.ethernetConnected

                RowLayout {
                    width: parent.width
                    Text { text: "IP"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 10; Layout.fillWidth: true }
                    Text {
                        text: parent.parent.wifiUp ? Network.ipAddress : Network.ethernetIp
                        color: Theme.fg
                        font.family: "monospace"
                        font.pixelSize: 10
                    }
                }
                RowLayout {
                    width: parent.width
                    visible: parent.wifiUp && Network.gateway !== ""
                    Text { text: "Gateway"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: Network.gateway; color: Theme.fg; font.family: "monospace"; font.pixelSize: 10 }
                }
                RowLayout {
                    width: parent.width
                    visible: Network.dnsServers.length > 0
                    Text { text: "DNS"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 10; Layout.fillWidth: true }
                    Text {
                        text: Network.dnsServers.join(", ")
                        color: Theme.fg
                        font.family: "monospace"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.maximumWidth: 170
                    }
                }
                RowLayout {
                    width: parent.width
                    Text { text: "Speed"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 10; Layout.fillWidth: true }
                    Text {
                        text: "▼ " + Network.formatRate(Network.rxRate) + "   ▲ " + Network.formatRate(Network.txRate)
                        color: Theme.fg
                        font.family: "monospace"
                        font.pixelSize: 10
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.muted }
            }

            // ---------------- No networks / powered off ----------------
            Text {
                visible: !Network.devicePowered
                text: "Turn on Wi-Fi to see networks"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 11
            }

            Text {
                visible: Network.devicePowered && Network.networks.length === 0
                text: "No networks visible"
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
            visible: Network.lastError.length > 0
            text: Network.lastError
            color: Theme.red
            font.family: "monospace"
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        // ---------------- Network list ----------------
        Flickable {
            anchors.top: topSection.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: errorText.visible ? errorText.top : parent.bottom
            anchors.bottomMargin: errorText.visible ? 4 : 0
            visible: Network.devicePowered && Network.networks.length > 0
            contentHeight: networksCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: networksCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: Network.networks

                    delegate: Column {
                        id: rowRoot
                        required property var modelData
                        width: networksCol.width

                        readonly property var net: modelData
                        readonly property bool expanded: root.expandedPath === net.path && net.path !== ""

                        Rectangle {
                            width: parent.width
                            height: 34
                            color: rowHover.containsMouse ? Theme.muted : "transparent"
                            opacity: Network.busy ? 0.55 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 8

                                // mini signal indicator, 4 bars
                                Row {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1
                                    visible: rowRoot.net.signal !== null

                                    Repeater {
                                        model: 4
                                        delegate: Rectangle {
                                            required property int index
                                            width: 3
                                            height: 4 + index * 3
                                            anchors.bottom: parent.bottom
                                            color: index < root.signalBars(rowRoot.net.signal) ? Theme.accent : Theme.muted
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: rowRoot.net.signal === null
                                    Layout.alignment: Qt.AlignVCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.fgDim
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: rowRoot.net.name + (rowRoot.net.type !== "open" ? " " : "")
                                        elide: Text.ElideRight
                                        color: rowRoot.net.connected ? Theme.accent : Theme.fgBright
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                        font.bold: rowRoot.net.connected
                                    }
                                    Text {
                                        text: root.statusLabel(rowRoot.net)
                                        color: Theme.fgDim
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    visible: rowRoot.net.known
                                    text: "Forget"
                                    color: Theme.red
                                    font.family: "monospace"
                                    font.pixelSize: 10

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: !Network.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Network.forgetNetwork(rowRoot.net)
                                    }
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !Network.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const net = rowRoot.net
                                    if (net.connected) {
                                        Network.disconnectNetwork()
                                    } else if (!net.inRange) {
                                        // saved but out of range: can only be forgotten
                                        return
                                    } else if (net.known || net.type === "open") {
                                        Network.connectNetwork(net)
                                    } else {
                                        root.passwordText = ""
                                        root.expandedPath = rowRoot.expanded ? "" : net.path
                                    }
                                }
                            }
                        }

                        // ---------------- Password (new secured network) ----------------
                        Column {
                            visible: rowRoot.expanded
                            width: parent.width
                            height: visible ? implicitHeight : 0
                            spacing: 2

                            Item {
                                width: parent.width
                                height: 36

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 24
                                        color: Theme.muted

                                        TextInput {
                                            id: pwField
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            color: Theme.fgBright
                                            font.family: "monospace"
                                            font.pixelSize: 11
                                            echoMode: TextInput.Password
                                            clip: true
                                            focus: rowRoot.expanded
                                            text: root.passwordText
                                            onTextChanged: root.passwordText = text

                                            Keys.onReturnPressed: {
                                                if (root.passwordText.length > 0) {
                                                    Network.connectWithPassword(rowRoot.net, root.passwordText)
                                                    root.expandedPath = ""
                                                }
                                            }
                                            Keys.onEscapePressed: root.expandedPath = ""
                                        }
                                    }

                                    Text {
                                        text: "Connect"
                                        color: root.passwordText.length > 0 ? Theme.accent : Theme.fgDim
                                        font.family: "monospace"
                                        font.pixelSize: 11

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            enabled: !Network.busy && root.passwordText.length > 0
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Network.connectWithPassword(rowRoot.net, root.passwordText)
                                                root.expandedPath = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: Network.wpsListening
                                text: "Waiting for WPS button press…"
                                color: Theme.fgDim
                                font.family: "monospace"
                                font.pixelSize: 9
                                font.italic: true
                                leftPadding: 4
                            }
                        }
                    }
                }
            }
        }
    }
}
