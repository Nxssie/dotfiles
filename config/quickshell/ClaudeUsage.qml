pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Subscription rate-limit percentages (5h/7d rolling windows) have no
// external API — Claude Code only exposes them through its statusLine
// stdin payload while a session is open. ~/.claude/statusline.ts mirrors
// that payload to this cache file on every render, so this singleton just
// shows the last known snapshot (and how stale it is when no session is
// currently running).
Singleton {
    id: root

    readonly property int staleAfterSeconds: 900 // 15 min

    readonly property bool hasData: state.updatedAt > 0
    readonly property bool stale: !hasData || (Date.now() / 1000 - state.updatedAt) > root.staleAfterSeconds

    readonly property string model: state.model
    readonly property real contextPct: state.contextPct
    readonly property real fiveHourPct: state.fiveHourPct
    readonly property int fiveHourResetsAt: state.fiveHourResetsAt
    readonly property real sevenDayPct: state.sevenDayPct
    readonly property int sevenDayResetsAt: state.sevenDayResetsAt
    readonly property real costUsd: state.costUsd
    readonly property int updatedAt: state.updatedAt

    function fmtResetIn(epochSeconds) {
        if (!epochSeconds || epochSeconds <= 0)
            return "—"
        const secs = epochSeconds - Date.now() / 1000
        if (secs <= 0)
            return "now"
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    function fmtAgo(epochSeconds) {
        if (!epochSeconds || epochSeconds <= 0)
            return "never"
        const secs = Date.now() / 1000 - epochSeconds
        if (secs < 60)
            return "just now"
        const m = Math.floor(secs / 60)
        if (m < 60)
            return m + "m ago"
        const h = Math.floor(m / 60)
        return h + "h ago"
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/claude-usage.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false

        adapter: JsonAdapter {
            id: state
            property string model: ""
            property real contextPct: 0
            property real fiveHourPct: -1
            property int fiveHourResetsAt: 0
            property real sevenDayPct: -1
            property int sevenDayResetsAt: 0
            property real costUsd: 0
            property int updatedAt: 0
        }
    }
}
