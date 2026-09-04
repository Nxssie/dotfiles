import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Clipboard history panel over cliphist (Win+V / Klipper style). Entries come
// from `cliphist list` ("<id>\t<preview>"); selecting one decodes it back into
// the clipboard. Del removes the selected entry from the history.
PanelWindow {
    id: root
    screen: Quickshell.screens[0]

    property bool active: false
    visible: active

    function show() {
        active = true
        listProc.running = true
    }
    function hide() {
        active = false
        searchField.text = ""
        selectedIndex = 0
    }
    function toggle() {
        active ? hide() : show()
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:clipboard"
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    implicitWidth: 560
    implicitHeight: 420
    color: "transparent"

    HyprlandFocusGrab {
        active: root.active
        windows: [root]
        onCleared: root.hide()
    }

    // ---------------- cliphist plumbing ----------------
    property var entries: [] // [{ id, preview }]

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n")
                    .filter(l => l.length > 0)
                    .map(l => {
                        const tab = l.indexOf("\t")
                        return { id: l.substring(0, tab), preview: l.substring(tab + 1) }
                    })
            }
        }
    }

    function copyEntry(entry) {
        if (!entry)
            return
        // ids are numeric, safe to interpolate
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"])
        root.hide()
    }

    function deleteEntry(entry) {
        if (!entry)
            return
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + entry.id + " | cliphist delete"])
        // cliphist has no delete-by-id; re-list after the delete settles
        relistTimer.restart()
    }

    Timer {
        id: relistTimer
        interval: 150
        onTriggered: listProc.running = true
    }

    // ---------------- Filtering ----------------
    property string query: ""
    property var filtered: {
        if (root.query.length === 0)
            return root.entries
        const q = root.query.toLowerCase()
        return root.entries.filter(e => e.preview.toLowerCase().includes(q))
    }

    property int selectedIndex: 0
    onFilteredChanged: selectedIndex = 0
    onSelectedIndexChanged: list.positionViewAtIndex(selectedIndex, ListView.Contain)

    onActiveChanged: if (active) searchField.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: 1
        border.color: Theme.muted

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: String.fromCharCode(0xF0EA) // nf-fa-clipboard
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                    color: Theme.fgDim
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: searchField.implicitHeight

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        color: Theme.fgBright
                        font.family: "monospace"
                        font.pixelSize: 15
                        focus: true
                        clip: true

                        onTextChanged: root.query = text

                        Keys.onEscapePressed: root.hide()
                        Keys.onDownPressed: root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1)
                        Keys.onUpPressed: root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                        Keys.onReturnPressed: root.copyEntry(root.filtered[root.selectedIndex])
                        Keys.onEnterPressed: root.copyEntry(root.filtered[root.selectedIndex])
                        Keys.onDeletePressed: root.deleteEntry(root.filtered[root.selectedIndex])
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0
                        text: "Search clipboard history…"
                        color: Theme.fgDim
                        font.family: "monospace"
                        font.pixelSize: 15
                    }
                }

                Text {
                    text: "Del: remove"
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.muted
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filtered
                currentIndex: root.selectedIndex
                highlightMoveDuration: 80

                delegate: Rectangle {
                    id: delegateRoot
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 34
                    color: index === root.selectedIndex ? Theme.muted : "transparent"

                    readonly property bool isImage: delegateRoot.modelData.preview.startsWith("[[ binary data")

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        Text {
                            // nf-fa-picture_o for binary/image entries, nf-fa-file_text_o otherwise
                            text: String.fromCharCode(delegateRoot.isImage ? 0xF03E : 0xF0F6)
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgDim
                        }

                        Text {
                            Layout.fillWidth: true
                            text: delegateRoot.modelData.preview
                            color: delegateRoot.isImage ? Theme.fgDim : Theme.fgBright
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.italic: delegateRoot.isImage
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: root.selectedIndex = delegateRoot.index
                        onClicked: root.copyEntry(delegateRoot.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: root.entries.length === 0 ? "Clipboard history is empty" : "No results"
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 12
                }
            }
        }
    }
}
