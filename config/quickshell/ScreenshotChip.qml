import QtQuick
import Quickshell

// Region screenshot: slurp a selection, save it under ~/Pictures/Screenshots
// and copy it to the clipboard. Cancelling the slurp aborts the pipeline.
Rectangle {
    id: root
    property bool hovered: false

    width: icon.implicitWidth + 12
    height: 18
    radius: 0
    color: Theme.muted
    opacity: root.hovered ? 0.7 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Text {
        id: icon
        anchors.centerIn: parent
        text: String.fromCharCode(0xF030) // nf-fa-camera
        font.family: "Symbols Nerd Font"
        font.pixelSize: 12
        color: Theme.fg
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["sh", "-c",
            'dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"; ' +
            'grim -g "$(slurp)" - | tee "$dir/$(date +%Y%m%d-%H%M%S).png" | wl-copy'])
    }
}
