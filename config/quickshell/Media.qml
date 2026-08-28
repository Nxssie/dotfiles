pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // Preferred player: the one currently playing, else the first available.
    readonly property var player: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    readonly property bool playing: player !== null && player.isPlaying
}
