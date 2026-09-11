import QtQuick

Rectangle {
    id: root
    signal activated()

    implicitWidth: icon.implicitWidth + 12
    implicitHeight: 18
    radius: 0
    color: Theme.muted
    visible: Media.player !== null

    Text {
        id: icon
        anchors.centerIn: parent
        text: String.fromCharCode(0xF001) // nf-fa-music
        font.family: "Symbols Nerd Font"
        font.pixelSize: 12
        color: Media.playing ? Theme.accent : Theme.fg
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
