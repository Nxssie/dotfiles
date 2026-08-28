import QtQuick

Rectangle {
    id: root
    signal activated()

    width: row.implicitWidth + 12
    height: 18
    radius: 0
    color: Theme.muted
    visible: Audio.sink !== null

    readonly property string icon: {
        // nf-fa volume_off / volume_down / volume_up
        if (Audio.muted || Audio.volume === 0) return String.fromCharCode(0xF026)
        if (Audio.volume < 0.5) return String.fromCharCode(0xF027)
        return String.fromCharCode(0xF028)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) Audio.toggleMute(Audio.sink)
            else root.activated()
        }
        onWheel: (wheel) => Audio.nudgeVolume(Audio.sink, wheel.angleDelta.y > 0 ? 0.05 : -0.05)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: Audio.muted ? Theme.fgDim : Theme.fg
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Audio.volume * 100) + "%"
            color: Audio.muted ? Theme.fgDim : Theme.fg
            font.family: "monospace"
            font.pixelSize: 11
            font.bold: true
        }
    }
}
