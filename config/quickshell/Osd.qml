import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// On-screen display for volume / mic mute / brightness keys. Bottom-center pill
// with a glyph and a level bar, shown ~1.5 s after the last change. Audio comes
// reactively from Pipewire; brightness is pushed by the key binds over IPC
// (see Brightness.qml). Changes during the first second after (re)load are
// ignored so the OSD doesn't flash when the shell starts.
PanelWindow {
    id: root
    screen: Quickshell.screens[0]

    property bool active: false
    visible: active

    anchors.bottom: true
    margins.bottom: 80
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: 260
    implicitHeight: 44

    // What's being displayed
    property string glyph: ""
    property real level: 0
    property bool muted: false
    property string label: ""

    property bool ready: false
    Timer { interval: 1000; running: true; onTriggered: root.ready = true }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.active = false
    }

    function show(glyph, level, muted, label) {
        if (!ready) return
        root.glyph = glyph
        root.level = level
        root.muted = muted
        root.label = label
        root.active = true
        hideTimer.restart()
    }

    // ---------------- sources ----------------

    readonly property string volumeGlyph: {
        // nf-fa volume_off / volume_down / volume_up
        if (Audio.muted || Audio.volume === 0) return String.fromCharCode(0xF026)
        if (Audio.volume < 0.5) return String.fromCharCode(0xF027)
        return String.fromCharCode(0xF028)
    }

    function showVolume() {
        show(volumeGlyph, Audio.volume, Audio.muted, Math.round(Audio.volume * 100) + "%")
    }

    Connections {
        target: Audio
        function onVolumeChanged() { root.showVolume() }
        function onMutedChanged() { root.showVolume() }
    }

    readonly property bool micMuted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false
    onMicMutedChanged: {
        // nf-fa microphone_slash / microphone
        show(String.fromCharCode(micMuted ? 0xF131 : 0xF130), micMuted ? 0 : 1, micMuted, micMuted ? "mic off" : "mic on")
    }

    function showBrightness() {
        Brightness.reload()
        // nf-fa sun_o
        show(String.fromCharCode(0xF185), Brightness.level, false, Math.round(Brightness.level * 100) + "%")
    }

    IpcHandler {
        target: "osd"
        // qs ipc call osd brightness — from the XF86MonBrightness* binds
        function brightness(): void { root.showBrightness() }
        function volume(): void { root.showVolume() }
    }

    // ---------------- view ----------------

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: 1
        border.color: Theme.muted

        Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                horizontalAlignment: Text.AlignHCenter
                text: root.glyph
                color: root.muted ? Theme.red : Theme.accent
                font.family: "Symbols Nerd Font"
                font.pixelSize: 16
            }

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - 12 - 12 - percent.width
                height: 6
                color: Theme.muted

                Rectangle {
                    width: track.width * root.level
                    height: parent.height
                    color: root.muted ? Theme.fgDim : Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            Text {
                id: percent
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                horizontalAlignment: Text.AlignRight
                text: root.label
                color: Theme.fg
                font.family: "monospace"
                font.pixelSize: 12
            }
        }
    }
}
