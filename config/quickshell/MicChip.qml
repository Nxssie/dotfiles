import QtQuick

// Default-source mute toggle. Hover-revealed like the other center chips,
// but stays visible while muted so a dead mic is never silently hidden.
Rectangle {
    id: root
    property bool hovered: false

    readonly property var mic: Audio.source
    readonly property bool muted: mic && mic.audio ? mic.audio.muted : false

    implicitWidth: icon.implicitWidth + 12
    implicitHeight: 18
    radius: 0
    color: root.muted ? Theme.red : Theme.muted
    opacity: root.muted ? 1 : (root.hovered ? 0.7 : 0)
    visible: mic !== null && opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Text {
        id: icon
        anchors.centerIn: parent
        // nf-fa microphone / microphone_slash
        text: root.muted ? String.fromCharCode(0xF131) : String.fromCharCode(0xF130)
        font.family: "Symbols Nerd Font"
        font.pixelSize: 12
        color: root.muted ? Theme.bg : Theme.fg
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Audio.toggleMute(root.mic)
    }
}
