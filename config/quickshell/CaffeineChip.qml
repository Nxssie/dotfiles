import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property bool active: false
    property bool hovered: false
    signal toggled()

    width: row.implicitWidth + 12
    height: 18
    radius: 0
    color: root.active ? Theme.yellow : Theme.muted
    opacity: root.active ? 1 : (root.hovered ? 0.7 : 0)
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
            text: root.active ? "ON" : "OFF"
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
