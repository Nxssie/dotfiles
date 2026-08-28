import QtQuick

Text {
    id: root
    property bool hovered: false

    // nf-fa-moon_o (U+F186) / nf-fa-sun_o (U+F185) — via fromCharCode
    // to keep the exact PUA codepoint unambiguous in source.
    text: Theme.dark ? String.fromCharCode(0xF186) : String.fromCharCode(0xF185)
    font.family: "Symbols Nerd Font"
    font.pixelSize: 13
    color: Theme.fg
    opacity: root.hovered ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: Theme.toggle()
    }
}
