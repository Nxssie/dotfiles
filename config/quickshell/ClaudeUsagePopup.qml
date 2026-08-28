import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property var anchorWindow
    // rect (in anchorWindow coords) of the chip that opened this popup — see AudioPopup.
    property rect anchorRect: Qt.rect(0, 0, 0, 0)

    signal dismissed()

    anchor.window: anchorWindow
    anchor.rect.x: anchorRect.x + anchorRect.width - width
    anchor.rect.y: anchorWindow ? anchorWindow.height : 0
    implicitWidth: 260
    implicitHeight: content.implicitHeight + 24
    color: Theme.surface
    grabFocus: true

    onVisibleChanged: if (!root.visible) root.dismissed()

    function barColor(pct) {
        if (pct >= 95)
            return Theme.red
        if (pct >= 80)
            return Theme.yellow
        return Theme.accent
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        Text {
            text: ClaudeUsage.hasData && ClaudeUsage.model ? ClaudeUsage.model : "Claude Code"
            color: Theme.fgBright
            font.family: "monospace"
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            visible: !ClaudeUsage.hasData
            width: parent.width
            text: "No usage data yet — open a Claude Code session to start tracking"
            color: Theme.fgDim
            font.family: "monospace"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Column {
            visible: ClaudeUsage.hasData
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 3

                RowLayout {
                    width: parent.width
                    Text { text: "5h window"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
                    Text {
                        text: Math.round(ClaudeUsage.fiveHourPct) + "%"
                        color: root.barColor(ClaudeUsage.fiveHourPct)
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 4
                    color: Theme.muted
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, ClaudeUsage.fiveHourPct)) / 100
                        height: parent.height
                        color: root.barColor(ClaudeUsage.fiveHourPct)
                    }
                }
                Text {
                    text: "resets in " + ClaudeUsage.fmtResetIn(ClaudeUsage.fiveHourResetsAt)
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 9
                }
            }

            Column {
                width: parent.width
                spacing: 3

                RowLayout {
                    width: parent.width
                    Text { text: "7d window"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
                    Text {
                        text: Math.round(ClaudeUsage.sevenDayPct) + "%"
                        color: root.barColor(ClaudeUsage.sevenDayPct)
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 4
                    color: Theme.muted
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, ClaudeUsage.sevenDayPct)) / 100
                        height: parent.height
                        color: root.barColor(ClaudeUsage.sevenDayPct)
                    }
                }
                Text {
                    text: "resets in " + ClaudeUsage.fmtResetIn(ClaudeUsage.sevenDayResetsAt)
                    color: Theme.fgDim
                    font.family: "monospace"
                    font.pixelSize: 9
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.muted }

            RowLayout {
                width: parent.width
                Text { text: "Context"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
                Text { text: Math.round(ClaudeUsage.contextPct) + "%"; color: Theme.fg; font.family: "monospace"; font.pixelSize: 11 }
            }

            RowLayout {
                width: parent.width
                visible: ClaudeUsage.costUsd > 0
                Text { text: "Session cost"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
                Text { text: "$" + ClaudeUsage.costUsd.toFixed(2); color: Theme.fg; font.family: "monospace"; font.pixelSize: 11 }
            }

            RowLayout {
                width: parent.width
                Text { text: "Updated"; color: Theme.fgDim; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
                Text {
                    text: ClaudeUsage.fmtAgo(ClaudeUsage.updatedAt)
                    color: ClaudeUsage.stale ? Theme.yellow : Theme.fg
                    font.family: "monospace"
                    font.pixelSize: 11
                }
            }
        }
    }
}
