import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property var anchorWindow
    // rect (in anchorWindow coordinates) of the chip that opened this popup —
    // set by Bar.togglePopup() via anchorWindow.itemRect(chip). Without this,
    // every right-side popup fell back to the same hardcoded top-right corner
    // and they all stacked on top of each other regardless of which chip was clicked.
    property rect anchorRect: Qt.rect(0, 0, 0, 0)

    signal dismissed()

    anchor.window: anchorWindow
    // centered under the chip, clamped so it never overhangs the bar's edges
    anchor.rect.x: anchorWindow ? Math.max(8, Math.min(anchorRect.x + anchorRect.width / 2 - width / 2, anchorWindow.width - width - 8)) : 0
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24
    color: Theme.surface
    grabFocus: true

    onVisibleChanged: if (!visible) root.dismissed()

    // One section per direction: default-device slider + mute, then the
    // device list to pick a new default. The slider tracks the mouse while
    // dragging, mapped against the bar itself so click position and fill
    // always line up.
    component VolumeSlider: Item {
        id: slider
        property var node
        width: parent.width
        height: 18

        readonly property var audio: node ? node.audio : null
        readonly property real ratio: audio ? Math.min(1, audio.volume) : 0

        Text {
            id: muteBtn
            anchors.verticalCenter: parent.verticalCenter
            // nf-fa volume_off / volume_up
            text: String.fromCharCode(slider.audio && slider.audio.muted ? 0xF026 : 0xF028)
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: slider.audio && slider.audio.muted ? Theme.fgDim : Theme.fg

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute(slider.node)
            }
        }

        Text {
            id: pctLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (slider.audio ? Math.round(slider.audio.volume * 100) : 0) + "%"
            color: Theme.fgDim
            font.family: "monospace"
            font.pixelSize: 10
        }

        Rectangle {
            id: track
            anchors.left: muteBtn.right
            anchors.leftMargin: 10
            anchors.right: pctLabel.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            color: Theme.muted

            Rectangle {
                width: parent.width * slider.ratio
                height: parent.height
                color: slider.audio && slider.audio.muted ? Theme.fgDim : Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -7
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => Audio.setVolume(slider.node, (mouse.x - 7) / track.width)
                onPositionChanged: (mouse) => {
                    if (pressed) Audio.setVolume(slider.node, (mouse.x - 7) / track.width)
                }
                onWheel: (wheel) => Audio.nudgeVolume(slider.node, wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row
        property var node
        property bool isDefault: false
        signal picked()

        width: parent.width
        height: 26
        color: rowHover.containsMouse ? Theme.muted : "transparent"

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 8

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: row.isDefault ? Theme.accent : Theme.fgDim
            }

            Text {
                Layout.fillWidth: true
                text: Audio.displayName(row.node)
                elide: Text.ElideRight
                color: row.isDefault ? Theme.accent : Theme.fgBright
                font.family: "monospace"
                font.pixelSize: 11
                font.bold: row.isDefault
            }
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        // ---------------- Output ----------------
        Text {
            text: "Output"
            color: Theme.fgBright
            font.family: "monospace"
            font.pixelSize: 13
            font.bold: true
        }

        Rectangle { width: parent.width; height: 1; color: Theme.muted }

        Text {
            visible: Audio.sink === null
            text: "No output device"
            color: Theme.fgDim
            font.family: "monospace"
            font.pixelSize: 11
        }

        VolumeSlider {
            visible: Audio.sink !== null
            node: Audio.sink
        }

        Repeater {
            model: Audio.sinks
            delegate: DeviceRow {
                required property var modelData
                node: modelData
                isDefault: Audio.sink === modelData
                onPicked: Audio.setDefaultSink(modelData)
            }
        }

        Item { width: 1; height: 6 }

        // ---------------- Input ----------------
        Text {
            text: "Input"
            color: Theme.fgBright
            font.family: "monospace"
            font.pixelSize: 13
            font.bold: true
        }

        Rectangle { width: parent.width; height: 1; color: Theme.muted }

        Text {
            visible: Audio.source === null
            text: "No input device"
            color: Theme.fgDim
            font.family: "monospace"
            font.pixelSize: 11
        }

        VolumeSlider {
            visible: Audio.source !== null
            node: Audio.source
        }

        Repeater {
            model: Audio.sources
            delegate: DeviceRow {
                required property var modelData
                node: modelData
                isDefault: Audio.source === modelData
                onPicked: Audio.setDefaultSource(modelData)
            }
        }
    }
}
