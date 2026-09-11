import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property bool active: false   // manual: user toggled it on
    property bool auto: false     // automatic: media playing / fullscreen window
    property bool hovered: false
    signal toggled()

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 18
    radius: 0
    // Manual is loud (yellow); automatic stays quiet but visible so an
    // inhibited screen is never a surprise
    color: root.active ? Theme.yellow : Theme.muted
    opacity: (root.active || root.auto) ? 1 : (root.hovered ? 0.7 : 0)
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: String.fromCharCode(0xF0F4) // nf-fa-coffee
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: root.active ? Theme.bg : Theme.fg
        }
        Text {
            text: root.active ? "ON" : (root.auto ? "AUTO" : "OFF")
            color: root.active ? Theme.bg : Theme.fg
            font.family: "monospace"
            font.pixelSize: 10
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
