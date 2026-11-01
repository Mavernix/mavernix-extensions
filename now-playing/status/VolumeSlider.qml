// The player's own loudness in the Now Playing panel, between a quiet and
// a loud speaker, as iTunes has it beside its buttons. Only for a player
// that tells its volume over MPRIS and can be controlled; the system's
// loudness is the panel's volume item's.
//
// With a theme that has iTunes' slider ([music.top_bar].volume_slider:
// track, fill, thumb, thumb_pressed), its pictures; without, a slim drawn
// one in the menu's colours. Dragging and the wheel set it. While it is
// dragged, and for a moment after, it shows where it was put, not what the
// player says back, so the two don't fight.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
    id: slider

    // NowPlayingPopover.qml, for the player, the looks and the colours.
    required property var view
    readonly property var looks: view.looks
    readonly property var player: view.player
    // { track, track_slice, fill, fill_slice, thumb, thumb_pressed }, or null.
    readonly property var pictures: view.theme.music?.top_bar?.volume_slider ?? null
    readonly property bool themed: pictures !== null && pictures.track !== undefined && pictures.thumb !== undefined

    // Read again on the panel's recheck, as Quickshell doesn't always tell
    // when volumeSupported changes (NowPlayingPopover.qml).
    readonly property bool usable:
        view.recheck >= 0 && player !== null && player.volumeSupported && player.canControl

    // Where the user put it, while that should show instead of the player's; else -1.
    property real held: -1
    readonly property real value: held >= 0 ? held : Math.max(0, Math.min(1, player?.volume ?? 0))

    // A drag sends at most one change per sending interval, the last one
    // always.
    function setTo(volume) {
        held = Math.max(0, Math.min(1, volume))
        if (sending.running) {
            pending = true
        } else {
            send()
            sending.start()
        }
        settling.restart()
    }
    property bool pending: false
    function send() {
        pending = false
        if (usable && held >= 0) {
            player.volume = held
        }
    }
    Timer {
        id: sending
        interval: slider.looks.volume_send_ms ?? 50
        onTriggered: {
            if (slider.pending) {
                slider.send()
            }
        }
    }
    // What the player says back right after a change can be an older value.
    Timer {
        id: settling
        interval: slider.looks.volume_settle_ms ?? 400
        onTriggered: {
            if (!area.pressed) {
                slider.held = -1
            }
        }
    }
    onPlayerChanged: {
        sending.stop()
        settling.stop()
        pending = false
        held = -1
    }

    readonly property real speakerSide: looks.speaker_size ?? 12
    readonly property real speakerGap: looks.speaker_gap ?? 5
    implicitWidth: 2 * (speakerSide + speakerGap) + (looks.volume_width ?? 90)
    implicitHeight: Math.max(speakerSide, themed ? thumb.implicitHeight : (looks.volume_knob_size ?? 11))

    component Speaker: Image {
        property string picture
        anchors.verticalCenter: parent.verticalCenter
        width: slider.speakerSide
        height: slider.speakerSide
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        source: slider.view.ownPicture(picture)
        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: slider.view.secondaryColor
        }
    }
    Speaker {
        picture: "speaker-quiet"
    }
    Speaker {
        x: slider.width - width
        picture: "speaker-loud"
    }

    Item {
        id: line
        x: slider.speakerSide + slider.speakerGap
        width: slider.width - 2 * x
        height: parent.height

        // The theme's pictures.
        BorderImage {
            visible: slider.themed
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            source: visible ? "file://" + slider.view.themeDirectory + "/" + slider.pictures.track : ""
            readonly property var slice: slider.pictures?.track_slice ?? [0, 0, 0, 0]
            border.top: slice[0]
            border.right: slice[1]
            border.bottom: slice[2]
            border.left: slice[3]
        }
        // The part up to the knob, if the theme has a picture for it.
        BorderImage {
            visible: slider.themed && slider.pictures.fill !== undefined
            anchors.verticalCenter: parent.verticalCenter
            width: thumb.x + thumb.width / 2
            source: visible ? "file://" + slider.view.themeDirectory + "/" + slider.pictures.fill : ""
            readonly property var slice: slider.pictures?.fill_slice ?? slider.pictures?.track_slice ?? [0, 0, 0, 0]
            border.top: slice[0]
            border.right: slice[1]
            border.bottom: slice[2]
            border.left: slice[3]
        }
        Image {
            id: thumb
            visible: slider.themed
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - width) * slider.value
            source: visible ? "file://" + slider.view.themeDirectory + "/"
                + (area.pressed ? (slider.pictures.thumb_pressed ?? slider.pictures.thumb) : slider.pictures.thumb) : ""
        }

        // Drawn: a groove, its filled part and a round knob.
        Rectangle {
            visible: !slider.themed
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: slider.looks.volume_line_height ?? 3
            radius: height / 2
            color: slider.view.trackColor
        }
        Rectangle {
            visible: !slider.themed
            anchors.verticalCenter: parent.verticalCenter
            width: knob.x + knob.width / 2
            height: slider.looks.volume_line_height ?? 3
            radius: height / 2
            color: slider.view.elapsedColor
        }
        Rectangle {
            id: knob
            visible: !slider.themed
            anchors.verticalCenter: parent.verticalCenter
            readonly property real side: slider.looks.volume_knob_size ?? 11
            x: (parent.width - width) * slider.value
            width: side
            height: side
            radius: side / 2
            color: slider.view.colour(slider.view.menuLooks.background)
            border.width: 1
            border.color: area.pressed ? slider.view.textColor : slider.view.secondaryColor
        }

        MouseArea {
            id: area
            // A little beyond the line, so it's easy to grab.
            anchors.fill: parent
            anchors.margins: -4
            enabled: slider.usable
            preventStealing: true
            function volumeAt(x) {
                return (x - 4 - slider.knobHalf) / Math.max(1, line.width - 2 * slider.knobHalf)
            }
            // The player pressed for; a drag stops counting if another takes its place.
            property var pressedFor: null
            onPressed: mouse => {
                pressedFor = slider.player
                slider.setTo(volumeAt(mouse.x))
            }
            onPositionChanged: mouse => {
                if (pressed && pressedFor === slider.player) {
                    slider.setTo(volumeAt(mouse.x))
                }
            }
            onReleased: settling.restart()
            onWheel: wheel => slider.setTo(slider.value + wheel.angleDelta.y / 120 * (slider.looks.volume_step ?? 0.05))
        }
    }
    readonly property real knobHalf: (themed ? thumb.width : knob.width) / 2
}
