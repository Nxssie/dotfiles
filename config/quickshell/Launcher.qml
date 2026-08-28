import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

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
        searchField.text = ""
        selectedIndex = 0
    }
    function toggle() {
        active ? hide() : show()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:launcher"
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

    // Curated hide-list: .desktop entries installed as a side effect of some
    // package's dependencies (Avahi service-discovery, Qt dev tools, hwloc)
    // rather than apps launched directly. Add exact display names here as
    // more sidecar entries turn up.
    property var hiddenNames: [
        "Avahi SSH Server Browser",
        "Avahi VNC Server Browser",
        "Avahi Zeroconf Browser",
        "Qt Assistant",
        "Qt Widgets Designer",
        "Qt Linguist",
        "Qt D-Bus Viewer",
        "Qt V4L2 test Utility",
        "Qt V4L2 video capture utility",
        "Hardware Locality lstopo",
    ]

    property var allApps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .filter(e => !root.hiddenNames.includes(e.name))
        .sort((a, b) => a.name.localeCompare(b.name))

    // Fuzzy match: every char of `query` must appear in `text`, in order (not
    // necessarily contiguous). Returns -1 on no match, otherwise a score where
    // higher is a better match (consecutive runs, word starts and matches near
    // the beginning of the string score higher).
    function fuzzyScore(query, text) {
        if (!text)
            return -1
        const q = query.toLowerCase()
        const t = text.toLowerCase()
        let qi = 0
        let score = 0
        let consecutive = 0
        let prevMatchIndex = -1
        for (let ti = 0; ti < t.length && qi < q.length; ti++) {
            if (t[ti] !== q[qi])
                continue
            let charScore = 1
            if (ti === 0)
                charScore += 3
            else if (" -_./".includes(t[ti - 1]))
                charScore += 2
            if (prevMatchIndex === ti - 1) {
                consecutive++
                charScore += consecutive
            } else {
                consecutive = 0
            }
            score += charScore
            prevMatchIndex = ti
            qi++
        }
        if (qi < q.length)
            return -1
        return score - t.length * 0.05
    }

    property string query: ""
    property var filtered: {
        if (root.query.length === 0)
            return root.allApps

        const scored = []
        for (const e of root.allApps) {
            let best = root.fuzzyScore(root.query, e.name)
            best = Math.max(best, root.fuzzyScore(root.query, e.genericName))
            if (e.keywords)
                for (const k of e.keywords)
                    best = Math.max(best, root.fuzzyScore(root.query, k))
            if (best >= 0)
                scored.push({ entry: e, score: best })
        }
        scored.sort((a, b) => b.score - a.score)
        return scored.map(s => s.entry)
    }

    property int selectedIndex: 0
    onFilteredChanged: selectedIndex = 0
    onSelectedIndexChanged: list.positionViewAtIndex(selectedIndex, ListView.Contain)

    function launch(entry) {
        if (!entry)
            return
        entry.execute()
        root.hide()
    }

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
                    text: "" // nf-fa-search
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
                        Keys.onReturnPressed: root.launch(root.filtered[root.selectedIndex])
                        Keys.onEnterPressed: root.launch(root.filtered[root.selectedIndex])
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0
                        text: "Search applications…"
                        color: Theme.fgDim
                        font.family: "monospace"
                        font.pixelSize: 15
                    }
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
                    height: 40
                    color: index === root.selectedIndex ? Theme.muted : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            IconImage {
                                anchors.fill: parent
                                visible: !!delegateRoot.modelData.icon
                                source: delegateRoot.modelData.icon ? Quickshell.iconPath(delegateRoot.modelData.icon, true) : ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !delegateRoot.modelData.icon
                                text: "" // nf-fa-window_restore (fallback app glyph)
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: Theme.fgDim
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: delegateRoot.modelData.name
                                color: Theme.fgBright
                                font.family: "monospace"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: !!delegateRoot.modelData.genericName && delegateRoot.modelData.genericName !== delegateRoot.modelData.name
                                text: delegateRoot.modelData.genericName
                                color: Theme.fgDim
                                font.family: "monospace"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: root.selectedIndex = delegateRoot.index
                        onClicked: root.launch(delegateRoot.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No results"
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 12
                }
            }
        }
    }
}
