import QtQuick

Rectangle {
    id: root
    signal activated()

    readonly property color iconColor: {
        if (!Bluetooth.hasAdapter || !Bluetooth.adapterPowered) return Theme.fgDim
        if (Bluetooth.connectedCount > 0) return Theme.fg
        return Theme.fgDim
    }

    visible: Bluetooth.hasAdapter
    implicitWidth: icon.implicitWidth + 12
    implicitHeight: 18
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
        // nf-fa-bluetooth_b (U+F294) — via fromCharCode
        // to keep the exact PUA codepoint unambiguous in source.
        text: String.fromCharCode(0xF294)
        font.family: "Symbols Nerd Font"
        font.pixelSize: 13
        color: root.iconColor
    }
}
