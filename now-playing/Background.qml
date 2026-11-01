// The Now Playing extension's running part: picks the media player the
// panel item (status/now-playing.qml) shows, as macOS does: the one that is
// playing, else the one that played last. With two playing, the one that
// started last. It keeps running while the panel item comes and goes, so
// it remembers which player was last active. The panel can also pick one
// (choose()), which then stays shown until it quits.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: nowPlaying

    // Handed over by the shell (src/shell/Extensions.qml in Mavernix).
    required property var extension
    property var settings: null
    property var extensions: null
    property var shell: null
    property var screen: null

    readonly property var ignored: {
        const wanted = extension.settings.ignored ?? []
        return Array.isArray(wanted) ? wanted : [wanted]
    }

    // The players on the session bus (MPRIS), without the ignored ones.
    readonly property var players: (Mpris.players?.values ?? []).filter(
        candidate => !ignored.some(part => candidate.dbusName.includes(part)))

    // When each player last started or stopped playing, by bus name: a
    // count that goes up, not a time.
    property var lastActive: ({})
    property int clock: 0
    function touch(player) {
        clock += 1
        const changed = Object.assign({}, lastActive)
        changed[player.dbusName] = clock
        lastActive = changed
    }
    function forget(name) {
        if (chosen === name) {
            chosen = ""
        }
        if (lastActive[name] !== undefined) {
            const changed = Object.assign({}, lastActive)
            delete changed[name]
            lastActive = changed
        }
    }

    // The bus name of the player the user picked in the panel, or "". The
    // pick holds until that player quits or another is picked.
    property string chosen: ""
    function choose(player) {
        chosen = player?.dbusName ?? ""
    }

    // The player to show, or null while there is none: the one picked, else
    // as macOS picks.
    readonly property var player: {
        if (players.length === 0) {
            return null
        }
        const picked = players.find(candidate => candidate.dbusName === chosen)
        if (picked !== undefined) {
            return picked
        }
        const playing = players.filter(candidate => candidate.isPlaying)
        const among = playing.length > 0 ? playing : players
        let latest = among[0]
        for (const candidate of among) {
            if ((lastActive[candidate.dbusName] ?? 0) > (lastActive[latest.dbusName] ?? 0)) {
                latest = candidate
            }
        }
        return latest
    }

    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            // Kept, as the player may be gone by the time this is.
            readonly property string name: modelData.dbusName
            target: modelData

            function onIsPlayingChanged() {
                nowPlaying.touch(modelData)
            }
            // A player that turns up playing has just become active.
            Component.onCompleted: {
                if (modelData.isPlaying) {
                    nowPlaying.touch(modelData)
                }
            }
            Component.onDestruction: nowPlaying.forget(name)
        }
    }
}
