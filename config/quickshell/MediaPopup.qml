import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property var anchorWindow

    signal dismissed()

    // MPRIS position is static while playing; advance it locally with a timer
    // and resync whenever the player pushes a real position update.
    property real displayPosition: Media.player ? Media.player.position : 0
    property bool artError: false

    function fmtTime(secs) {
        secs = Math.max(0, Math.floor(secs))
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        const s = secs % 60
        const mm = (h > 0 && m < 10) ? "0" + m : "" + m
        const ss = s < 10 ? "0" + s : "" + s
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
    }

    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow ? anchorWindow.width / 2 - width / 2 : 0
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 300
    implicitHeight: Media.player ? 202 : 80
    color: Theme.surface
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            displayPosition = Media.player ? Media.player.position : 0
            artError = false
        } else {
            root.dismissed()
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.visible && Media.playing
        onTriggered: {
            const p = Media.player
            if (p && p.length > 0)
                root.displayPosition = Math.min(root.displayPosition + interval / 1000, p.length)
            else if (p)
                root.displayPosition += interval / 1000
        }
    }

    Connections {
        target: Media.player
        function onPositionChanged() { root.displayPosition = Media.player.position }
        function onTrackTitleChanged() {
            root.displayPosition = Media.player.position
            root.artError = false
        }
    }

    // ---------------- Empty state ----------------
    Text {
        anchors.centerIn: parent
        visible: Media.player === null
        text: "No media players running"
        color: Theme.fgDim
        font.family: "monospace"
        font.pixelSize: 11
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: Media.player !== null

        // ---------------- Header: app + state ----------------
        RowLayout {
            width: parent.width

            Text {
                Layout.fillWidth: true
                text: Media.player ? Media.player.identity : ""
                elide: Text.ElideRight
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 11
            }

            Text {
                text: Media.playing ? "Playing" : "Paused"
                color: Media.playing ? Theme.accent : Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 11
                font.bold: true
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.muted }

        // ---------------- Art + track info ----------------
        Item {
            width: parent.width
            height: 72

            Rectangle {
                id: artBox
                width: 72
                height: 72
                color: Theme.muted

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: Media.player && Media.player.trackArtUrl !== "" && !root.artError
                            ? Media.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    onStatusChanged: if (status === Image.Error) root.artError = true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !artImage.visible
                    text: String.fromCharCode(0xF001) // nf-fa-music
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 24
                    color: Theme.fgDim
                }
            }

            ColumnLayout {
                anchors.left: artBox.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: Media.player ? Media.player.trackTitle : ""
                    elide: Text.ElideRight
                    color: Theme.fgBright
                    font.family: "monospace"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (!Media.player) return ""
                        const artist = Media.player.trackArtist
                        const album = Media.player.trackAlbum
                        if (artist !== "" && album !== "") return artist + " — " + album
                        return artist !== "" ? artist : album
                    }
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: "monospace"
                    font.pixelSize: 11
                }

                Text {
                    Layout.fillWidth: true
                    visible: Media.player && !Media.player.lengthSupported
                    text: "Live stream"
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.italic: true
                }
            }
        }

        // ---------------- Progress ----------------
        Item {
            width: parent.width
            height: 18

            readonly property bool seekable: Media.player
                && Media.player.canSeek && Media.player.positionSupported
                && Media.player.length > 0
            readonly property real ratio: (Media.player && Media.player.length > 0)
                ? Math.min(1, root.displayPosition / Media.player.length) : 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmtTime(root.displayPosition)
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 9
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Media.player ? root.fmtTime(Media.player.length) : "0:00"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 9
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64
                height: 4
                color: Theme.muted

                Rectangle {
                    width: parent.width * parent.parent.ratio
                    height: parent.height
                    color: Theme.accent
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: parent.seekable
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    const p = Media.player
                    const ratio = Math.min(1, Math.max(0, (mouse.x + 6) / width))
                    const target = ratio * p.length
                    p.seek(target - p.position)
                    root.displayPosition = target
                }
            }
        }

        // ---------------- Transport buttons ----------------
        Item {
            width: parent.width
            height: 30

            Row {
                anchors.centerIn: parent
                spacing: 28

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCharCode(0xF048) // nf-fa-step_backward
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: Media.player && Media.player.canGoPrevious ? Theme.fg : Theme.fgDim
                    opacity: Media.player && Media.player.canGoPrevious ? 1 : 0.4

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: Media.player && Media.player.canGoPrevious
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.player.previous()
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 0
                    color: Media.player && Media.player.canTogglePlaying ? Theme.accent : Theme.muted

                    Text {
                        anchors.centerIn: parent
                        // nf-fa-play (U+F04B) / nf-fa-pause (U+F04C)
                        text: String.fromCharCode(Media.playing ? 0xF04C : 0xF04B)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 13
                        color: Media.player && Media.player.canTogglePlaying ? Theme.surface : Theme.fgDim
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: Media.player && Media.player.canTogglePlaying
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.player.togglePlaying()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCharCode(0xF049) // nf-fa-step_forward
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: Media.player && Media.player.canGoNext ? Theme.fg : Theme.fgDim
                    opacity: Media.player && Media.player.canGoNext ? 1 : 0.4

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: Media.player && Media.player.canGoNext
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.player.next()
                    }
                }
            }
        }
    }
}
