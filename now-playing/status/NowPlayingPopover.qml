// The Now Playing panel's state, for the panel item (now-playing.qml): the
// player, its track, the looks and colours, and whether it's open. What it
// shows is NowPlayingPanel.qml.
//
// A desktop that can hold an item's own panel (StatusItem's `popover`)
// shows it in its menu box, like a menu: hovering between it and the menus
// switches. An older one hasn't that, and then this shows the panel in a
// full-screen, transparent window of its own, as MenuOverlay.qml does
// menus: a press outside closes it, and the panel stays reachable.
//
// It is drawn like the theme's menus: their box, font and colours. A theme
// that has iTunes' pieces ([music.display] and [music.top_bar], as Sea
// Lion's) gets its LCD, scrubber, buttons and slider; see ../README.md.
// Sizes come from the extension's looks (../looks/).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: popover

    // The panel item it hangs from, and that item's panel.
    required property var owner
    required property var panel
    // An MprisPlayer, or null.
    property var player: null
    property var extension: null
    // The extension's running part (../Background.qml): the players, and choose().
    property var source: null
    readonly property var players: source?.players ?? []

    // Whether the shell holds the panel (in its menu box), or this does.
    property bool hostedByShell: false

    readonly property bool open: hostedByShell ? owner.open : ownOpen
    onOpenChanged: {
        if (!open) {
            pickerOpen = false
        }
    }

    // --- In a window of its own ----------------------------------------------------

    property bool ownOpen: false
    function show() {
        // One thing open from the panel at a time.
        panel.closeMenu()
        anchorX = owner.mapToItem(null, 0, 0).x - owner.boxOverhang
        made = true
        ownOpen = true
    }
    function close() {
        ownOpen = false
    }

    // Whether the menu of players is open.
    property bool pickerOpen: false
    onPlayersChanged: {
        if (players.length < 2) {
            pickerOpen = false
        }
    }

    // Opening a menu on the panel closes this.
    Connections {
        target: popover.panel
        enabled: !popover.hostedByShell
        function onOpenTitleChanged() {
            if (popover.panel.openTitle !== null) {
                popover.close()
            }
        }
    }

    // Where the item's box starts, in the panel's coordinates.
    property real anchorX: 0

    // The window is made when it first opens, and then kept, hidden while
    // closed, so the art needn't load again each time.
    property bool made: false

    // --- Looks ---------------------------------------------------------------------

    readonly property var theme: panel.settings.theme
    readonly property var menuLooks: theme.menu
    readonly property var font: theme.fonts.menu
    readonly property var looks: extension?.looks ?? ({})
    readonly property var words: extension?.manifest.words ?? ({})
    readonly property string themeDirectory: panel.settings.theme_directory

    // The theme's music display (an LCD fill, its colours, the scrubber
    // pieces), if it has one; null otherwise.
    readonly property var lcd: {
        const display = theme.music?.display
        return display !== undefined && display.fill !== undefined ? display : null
    }
    // The theme's transport buttons, if it has all four; null otherwise.
    readonly property var buttonPictures: {
        const pictures = theme.music?.top_bar?.pictures
        if (pictures === undefined) {
            return null
        }
        const whole = ["previous", "play", "pause", "next"].every(name => pictures[name]?.normal !== undefined)
        return whole ? pictures : null
    }
    // One of the extension's drawings (images/NAME.svg).
    function ownPicture(name) {
        return extension !== null ? "file://" + extension.directory + "/images/" + name + ".svg" : ""
    }

    // A theme's "#rrggbb" or "#rrggbbaa" as a colour, and its curve names as
    // easings, as the shell's ThemeValues.js reads them; that file can't be
    // imported from an extension (`import qs` has no JavaScript files).
    function colour(text) {
        if (typeof text !== "string" || !text.startsWith("#")) {
            return "transparent"
        }
        const channel = start => parseInt(text.substr(start, 2), 16) / 255
        return Qt.rgba(channel(1), channel(3), channel(5), text.length === 9 ? channel(7) : 1)
    }
    function easing(curve) {
        return { "linear": Easing.Linear, "ease-in": Easing.InQuad, "ease-out": Easing.OutQuad }[curve]
            ?? Easing.InOutQuad
    }

    // The menu's colours, unless the looks give their own.
    readonly property color textColor: colour(looks.text_color ?? menuLooks.text_color)
    readonly property color secondaryColor:
        colour(looks.secondary_text_color ?? menuLooks.disabled_text_color)
    readonly property color trackColor: colour(looks.seek_track_color ?? menuLooks.separator_color)
    readonly property color elapsedColor:
        colour(looks.seek_fill_color ?? menuLooks.disabled_text_color)
    readonly property color placeholderColor:
        colour(looks.placeholder_color ?? menuLooks.separator_color)

    // How its own window goes away: as the theme's menus do, a fade or at once.
    readonly property var closeMotion: (theme.animation ?? ({})).menu_close ?? ({ kind: "none" })
    readonly property bool fades: closeMotion.kind === "fade"
    // True while it fades out after closing.
    property bool fading: false
    onOwnOpenChanged: fading = !ownOpen && fades

    // --- The track -----------------------------------------------------------------

    readonly property string title: {
        if (player === null) {
            return ""
        }
        if (player.trackTitle !== "") {
            return player.trackTitle
        }
        return player.identity !== "" ? player.identity : (words.not_playing ?? "Not Playing")
    }
    readonly property string subtitle:
        player === null ? "" : [player.trackArtist, player.trackAlbum].filter(part => part !== "").join(" – ")

    // A player's name, as it calls itself ("Firefox", "Bandstand").
    function nameOf(candidate) {
        if (candidate.identity !== "") {
            return candidate.identity
        }
        return candidate.dbusName.replace("org.mpris.MediaPlayer2.", "")
    }

    // A plain path is taken for a file; file://, http(s):// and data: addresses are used as they are.
    readonly property string artSource: {
        const address = player?.trackArtUrl ?? ""
        return address.startsWith("/") ? "file://" + address : address
    }

    // Counts up when the panel opens and every second while it's open.
    // Quickshell 0.3.2 doesn't tell when a player's volumeSupported turns
    // true (Firefox adds its Volume after it has appeared), so what depends
    // on it reads it again then.
    property int recheck: 0
    Timer {
        interval: popover.looks.recheck_ms ?? 1000
        repeat: true
        running: popover.open
        triggeredOnStart: true
        onTriggered: popover.recheck += 1
    }

    // Play or pause. Quickshell refuses both for a player that leaves out
    // CanPlay and CanPause (Firefox does), though MPRIS says every player
    // has them; such a player that can be controlled is asked over D-Bus.
    readonly property bool lacksPlayAndPause: player !== null && player.canControl && !player.canPlay && !player.canPause
    readonly property bool canPlayPause: player !== null && (player.canTogglePlaying || lacksPlayAndPause)
    function playPause() {
        if (player === null) {
            return
        }
        if (player.canTogglePlaying) {
            player.togglePlaying()
        } else if (lacksPlayAndPause) {
            Quickshell.execDetached(["gdbus", "call", "--session", "--dest", player.dbusName,
                                     "--object-path", "/org/mpris/MediaPlayer2",
                                     "--method", "org.mpris.MediaPlayer2.Player.PlayPause"])
        }
    }

    // In seconds. A length of 0 is one the player doesn't know.
    readonly property real length: player !== null && player.lengthSupported ? Math.max(0, player.length) : 0
    readonly property bool knowsLength: length > 0 && player.positionSupported
    readonly property real position: knowsLength ? Math.max(0, Math.min(player.position, length)) : 0
    readonly property bool canSeek: knowsLength && player.canSeek

    // The player tells the position only when it jumps; while it plays, it
    // is worked out from the time that has passed, read when this asks.
    // Only while the panel is open and something plays.
    Timer {
        interval: popover.looks.position_update_ms ?? 500
        repeat: true
        running: popover.open && popover.knowsLength && (popover.player?.isPlaying ?? false)
        // At once too, as the time read when it last showed is old.
        triggeredOnStart: true
        onTriggered: popover.player.positionChanged()
    }

    function clock(seconds) {
        const whole = Math.floor(seconds)
        const hours = Math.floor(whole / 3600)
        const minutes = Math.floor(whole / 60) % 60
        const rest = String(whole % 60).padStart(2, "0")
        return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + rest : minutes + ":" + rest
    }

    // --- Its own window, on a desktop that can't hold it -------------------------

    LazyLoader {
        active: popover.made && !popover.hostedByShell

        PanelWindow {
            id: window

            screen: popover.panel.screen
            WlrLayershell.namespace: "now-playing"
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            // Covers the panel too, so that window positions are screen positions.
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: popover.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            visible: (popover.open || popover.fading) && keepShown.canShow
            KeepShown {
                id: keepShown
                target: window
            }

            readonly property bool atBottom: popover.panel.atBottom
            readonly property real panelHeight: popover.panel.height

            // Nothing while it fades, so a press goes straight through; never
            // the panel, so its item can close this and its menus can open.
            mask: Region {
                item: popover.open ? everything : null

                Region {
                    x: 0
                    y: window.atBottom ? window.height - window.panelHeight : 0
                    width: window.width
                    height: window.panelHeight
                    intersection: Intersection.Subtract
                }
            }

            MouseArea {
                id: everything
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: popover.close()
            }

            Item {
                id: keys
                focus: true
                Keys.onPressed: event => {
                    if (contents.keyPressed(event)) {
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        popover.close()
                        event.accepted = true
                    }
                }
            }

            Connections {
                target: popover
                function onOwnOpenChanged() {
                    if (popover.ownOpen) {
                        fadeOut.stop()
                        box.opacity = 1
                        keys.forceActiveFocus()
                    }
                }
                function onFadingChanged() {
                    if (popover.fading) {
                        fadeOut.restart()
                    }
                }
            }
            NumberAnimation {
                id: fadeOut
                target: box
                property: "opacity"
                to: 0
                duration: popover.closeMotion.duration_ms ?? 150
                easing.type: popover.easing(popover.closeMotion.curve ?? "linear")
                onFinished: popover.fading = false
            }

            Item {
                id: box
                width: contents.width
                height: contents.height
                // Hangs from the panel's inner edge, aligned with the item's box.
                x: Math.max(0, Math.min(popover.anchorX, window.width - width))
                y: window.atBottom ? window.height - window.panelHeight - height : window.panelHeight

                BoxFrame {
                    looks: popover.menuLooks
                    squareTopLeft: !window.atBottom
                    squareTopRight: !window.atBottom
                }

                NowPlayingPanel {
                    id: contents
                    view: popover
                }
            }
        }
    }
}
