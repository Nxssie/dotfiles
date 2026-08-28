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
        root.query = ""
    }
    function toggle() {
        active ? hide() : show()
    }

    IpcHandler {
        target: "bindings"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:bindings"
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    implicitWidth: 620
    implicitHeight: 560
    color: "transparent"

    HyprlandFocusGrab {
        active: root.active
        windows: [root]
        onCleared: root.hide()
    }

    onActiveChanged: if (active) searchField.forceActiveFocus()

    // Standard XKB modifier bits reported by `hyprctl binds -j`
    readonly property int modShift: 1
    readonly property int modCtrl: 4
    readonly property int modAlt: 8
    readonly property int modSuper: 64

    readonly property var keyLabels: ({
        "SPACE": "Space",
        "left": "←",
        "right": "→",
        "up": "↑",
        "down": "↓",
        "mouse_down": "Scroll ↓",
        "mouse_up": "Scroll ↑",
        "mouse:272": "Left click",
        "mouse:273": "Right click",
        "Print": "Print Screen",
        "XF86AudioRaiseVolume": "Vol +",
        "XF86AudioLowerVolume": "Vol -",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic Mute",
        "XF86MonBrightnessUp": "Bright +",
        "XF86MonBrightnessDown": "Bright -",
        "XF86AudioNext": "Next",
        "XF86AudioPrev": "Prev",
        "XF86AudioPlay": "Play/Pause",
        "XF86AudioPause": "Play/Pause"
    })

    function keyLabel(key) {
        return root.keyLabels[key] || key
    }

    function comboLabel(modmask, key) {
        const parts = []
        if (modmask & root.modSuper) parts.push("SUPER")
        if (modmask & root.modCtrl)  parts.push("CTRL")
        if (modmask & root.modAlt)   parts.push("ALT")
        if (modmask & root.modShift) parts.push("SHIFT")
        parts.push(root.keyLabel(key))
        return parts.join(" + ")
    }

    property var entries: []

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
            return root.entries

        const scored = []
        for (const e of root.entries) {
            let best = root.fuzzyScore(root.query, e.combo)
            best = Math.max(best, root.fuzzyScore(root.query, e.desc))
            if (best >= 0)
                scored.push({ entry: e, score: best })
        }
        scored.sort((a, b) => b.score - a.score)
        return scored.map(s => s.entry)
    }

    function parseBinds(text) {
        let data = []
        try {
            data = JSON.parse(text)
        } catch (e) {
            data = []
        }
        const out = []
        for (const b of data) {
            if (!b.has_description || !b.description)
                continue
            out.push({ combo: root.comboLabel(b.modmask, b.key), desc: b.description })
        }
        // The mainMod + [0-9] loop binds aren't individually described (would be 20 lines)
        out.push({ combo: "SUPER + [0-9]", desc: "Go to workspace" })
        out.push({ combo: "SUPER + SHIFT + [0-9]", desc: "Move window to workspace" })
        root.entries = out
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        running: root.active
        stdout: StdioCollector {
            onStreamFinished: root.parseBinds(text)
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        color: Theme.surface
        border.width: 1
        border.color: Theme.muted
        focus: root.active

        Keys.onEscapePressed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "Keyboard shortcuts"
                color: Theme.fgBright
                font.family: "monospace"
                font.pixelSize: 16
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.muted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "" // nf-fa-search
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
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
                        font.pixelSize: 13
                        clip: true

                        onTextChanged: root.query = text

                        Keys.onEscapePressed: root.hide()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0
                        text: "Search shortcuts…"
                        color: Theme.fgDim
                        font.family: "monospace"
                        font.pixelSize: 13
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filtered

                delegate: Rectangle {
                    id: delegateRoot
                    required property var modelData
                    width: ListView.view.width
                    height: 26
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: comboText.implicitWidth + 14
                            Layout.preferredHeight: 20
                            color: Theme.muted

                            Text {
                                id: comboText
                                anchors.centerIn: parent
                                text: delegateRoot.modelData.combo
                                color: Theme.accent
                                font.family: "monospace"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: delegateRoot.modelData.desc
                            color: Theme.fgBright
                            font.family: "monospace"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: root.filtered.length === 0
                text: "No results"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 10
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Type to filter · Esc to close"
                color: Theme.fgDim
                font.family: "monospace"
                font.pixelSize: 10
            }
        }
    }
}
