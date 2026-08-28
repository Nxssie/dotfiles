import QtQuick

Rectangle {
    id: root
    signal activated()

    readonly property var connectedNetwork: {
        for (const n of Network.networks) {
            if (n.connected) return n
        }
        return null
    }

    function signalBars(signal) {
        if (signal === null || signal === undefined) return 0
        if (signal >= -55) return 4
        if (signal >= -65) return 3
        if (signal >= -75) return 2
        return 1
    }

    readonly property string kind: Network.ethernetConnected ? "ethernet" : "wifi"
    readonly property color iconColor: {
        if (Network.ethernetConnected) return Theme.fg
        if (!Network.devicePowered) return Theme.muted
        if (!root.connectedNetwork) return Theme.fgDim
        return root.signalBars(root.connectedNetwork.signal) <= 2 ? Theme.yellow : Theme.fg
    }

    width: icon.implicitWidth + 12
    height: 18
    radius: 0
    color: Theme.muted

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Text {
        id: icon
        anchors.centerIn: parent
        // nf-fa-ethernet (U+EF44) / nf-fa-wifi (U+F1EB) — via fromCharCode
        // to keep the exact PUA codepoint unambiguous in source.
        text: String.fromCharCode(root.kind === "ethernet" ? 0xEF44 : 0xF1EB)
        font.family: "Symbols Nerd Font"
        font.pixelSize: 13
        color: root.iconColor
    }
}
