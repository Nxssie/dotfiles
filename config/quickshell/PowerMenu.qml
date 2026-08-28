import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    screen: Quickshell.screens[0]

    property bool active: false
    visible: active

    function show() {
        active = true
    }
    function hide() {
        active = false
    }
    function toggle() {
        active ? hide() : show()
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:powermenu"
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    implicitWidth: 320
    implicitHeight: 288
    color: "transparent"

    HyprlandFocusGrab {
        active: root.active
        windows: [root]
        onCleared: root.hide()
    }

    onActiveChanged: if (active) content.forceActiveFocus()

    readonly property var actions: [
        { glyph: "", label: "Lock",          cmd: "pidof hyprlock || hyprlock",                              danger: false },
        { glyph: "", label: "Log out",       cmd: "hyprshutdown",                                            danger: false },
        { glyph: "", label: "Suspend",       cmd: "systemctl suspend",                                       danger: false },
        { glyph: "", label: "Restart",       cmd: "hyprshutdown --post-cmd \"systemctl reboot\"",            danger: true },
        { glyph: "", label: "Shut down",     cmd: "hyprshutdown --post-cmd \"systemctl poweroff\"",          danger: true }
    ]

    Process {
        id: runner
        command: ["bash", "-c", ""]
    }

    function run(cmd) {
        runner.command = ["bash", "-c", cmd]
        runner.running = true
        root.hide()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: 1
        border.color: Theme.muted

        Item {
            id: content
            anchors.fill: parent
            focus: root.active

            Keys.onEscapePressed: root.hide()
            Keys.onPressed: (event) => {
                const n = parseInt(event.text)
                if (n >= 1 && n <= root.actions.length) {
                    root.run(root.actions[n - 1].cmd)
                    event.accepted = true
                }
            }

            ColumnLayout {
                id: actionsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 6

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 40
                        color: hoverArea.containsMouse ? Theme.muted : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: delegateRoot.modelData.glyph
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: delegateRoot.modelData.danger ? Theme.red : Theme.accent
                            }

                            Text {
                                Layout.fillWidth: true
                                text: delegateRoot.modelData.label
                                color: Theme.fgBright
                                font.family: "monospace"
                                font.pixelSize: 13
                            }

                            Text {
                                text: delegateRoot.index + 1
                                color: Theme.fgDim
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run(delegateRoot.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
