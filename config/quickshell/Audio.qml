pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Wraps Quickshell's native Pipewire service — no wpctl/pactl processes.
// Node audio properties (volume/muted) are only live while a PwObjectTracker
// holds the node, so every node this singleton exposes is tracked below.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    // Convenience mirrors of the default sink, for the bar chip
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true

    function displayName(node) {
        if (!node) return ""
        return node.nickname || node.description || node.name
    }

    function setVolume(node, v) {
        if (!node || !node.audio) return
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, v))
    }

    function nudgeVolume(node, delta) {
        if (!node || !node.audio) return
        setVolume(node, node.audio.volume + delta)
    }

    function toggleMute(node) {
        if (!node || !node.audio) return
        node.audio.muted = !node.audio.muted
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node
    }
}
