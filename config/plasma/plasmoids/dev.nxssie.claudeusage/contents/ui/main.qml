import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

// Subscription rate-limit percentages (5h/7d rolling windows) have no external
// API — Claude Code only exposes them through its statusLine stdin payload while
// a session is open. ~/.claude/statusline.ts mirrors that payload to
// ~/.cache/claude-usage.json on every render, so this widget just shows the last
// known snapshot (and how stale it is when no session is currently running).
PlasmoidItem {
    id: root

    readonly property int staleAfterSeconds: 900 // 15 min

    property var usage: ({})
    property double now: Date.now() / 1000

    readonly property bool hasData: (usage.updatedAt || 0) > 0
    readonly property bool stale: !hasData || (now - usage.updatedAt) > staleAfterSeconds
    readonly property real fiveHourPct: usage.fiveHourPct !== undefined ? usage.fiveHourPct : -1
    readonly property real sevenDayPct: usage.sevenDayPct !== undefined ? usage.sevenDayPct : -1

    function pctColor(pct) {
        if (pct >= 95) return Kirigami.Theme.negativeTextColor
        if (pct >= 80) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.highlightColor
    }

    function fmtResetIn(epochSeconds) {
        if (!epochSeconds || epochSeconds <= 0) return "—"
        const secs = epochSeconds - now
        if (secs <= 0) return "now"
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    function fmtAgo(epochSeconds) {
        if (!epochSeconds || epochSeconds <= 0) return "never"
        const secs = now - epochSeconds
        if (secs < 60) return "just now"
        const m = Math.floor(secs / 60)
        if (m < 60) return m + "m ago"
        return Math.floor(m / 60) + "h ago"
    }

    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["cat \"$HOME/.cache/claude-usage.json\" 2>/dev/null"]
        interval: 5000
        onNewData: (source, data) => {
            try {
                root.usage = JSON.parse(data.stdout)
            } catch (e) {
                root.usage = ({})
            }
            root.now = Date.now() / 1000
        }
    }

    toolTipMainText: "Claude Code"
    toolTipSubText: hasData ? Math.round(fiveHourPct) + "% of the 5h window · " + Math.round(sevenDayPct) + "% of the 7d window" : "No usage data yet"

    // ---- Panel chip -------------------------------------------------------------
    compactRepresentation: MouseArea {
        id: chip

        readonly property color statusColor: root.stale ? Kirigami.Theme.disabledTextColor : root.pctColor(root.fiveHourPct)

        // Collapses to nothing until the first snapshot exists (same as the old bar chip)
        visible: root.hasData
        Layout.minimumWidth: root.hasData ? row.implicitWidth + Kirigami.Units.largeSpacing : 0
        Layout.preferredWidth: Layout.minimumWidth

        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // Claude wordmark glyph (simple-icons path data), drawn rather than font-based
            Item {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small

                Shape {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    scale: parent.width / 24
                    transformOrigin: Item.Center
                    antialiasing: true

                    ShapePath {
                        fillColor: chip.statusColor
                        strokeWidth: -1

                        PathSvg {
                            path: "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                text: Math.max(0, Math.round(root.fiveHourPct)) + "%"
                color: chip.statusColor
                font.family: "monospace"
                font.bold: true
            }
        }
    }

    // ---- Popup ------------------------------------------------------------------
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 4
            text: root.hasData && root.usage.model ? root.usage.model : "Claude Code"
        }

        PlasmaComponents3.Label {
            visible: !root.hasData
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "No usage data yet — open a Claude Code session to start tracking"
        }

        Repeater {
            model: root.hasData ? [
                { label: "5h window", pct: root.fiveHourPct, resetsAt: root.usage.fiveHourResetsAt },
                { label: "7d window", pct: root.sevenDayPct, resetsAt: root.usage.sevenDayResetsAt }
            ] : []

            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: modelData.label; opacity: 0.7; Layout.fillWidth: true }
                    PlasmaComponents3.Label {
                        text: Math.round(modelData.pct) + "%"
                        color: root.pctColor(modelData.pct)
                        font.bold: true
                    }
                }
                PlasmaComponents3.ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: Math.max(0, Math.min(100, modelData.pct))
                }
                PlasmaComponents3.Label {
                    text: "resets in " + root.fmtResetIn(modelData.resetsAt)
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }
        }

        Kirigami.Separator { visible: root.hasData; Layout.fillWidth: true }

        RowLayout {
            visible: root.hasData
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: "Context"; opacity: 0.7; Layout.fillWidth: true }
            PlasmaComponents3.Label { text: Math.round(root.usage.contextPct || 0) + "%" }
        }

        RowLayout {
            visible: root.hasData && (root.usage.costUsd || 0) > 0
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: "Session cost"; opacity: 0.7; Layout.fillWidth: true }
            PlasmaComponents3.Label { text: "$" + (root.usage.costUsd || 0).toFixed(2) }
        }

        RowLayout {
            visible: root.hasData
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: "Updated"; opacity: 0.7; Layout.fillWidth: true }
            PlasmaComponents3.Label {
                text: root.fmtAgo(root.usage.updatedAt)
                color: root.stale ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
            }
        }
    }
}
