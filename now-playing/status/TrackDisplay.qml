// The track in the Now Playing panel: the art, the title, "artist – album"
// and how far it has got, the time so far and the length either side of
// the bar. With a theme that has a music display ([music.display], as Sea
// Lion's Theme Installer cuts it from iTunes 11), it is drawn on that LCD
// with its colours, scrubber and knob, the text centred as iTunes has it.
// Without one, plainly on the menu, in the menu's colours.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs

Item {
    id: display

    // NowPlayingPopover.qml, for the player, the looks and the colours.
    required property var view
    readonly property var looks: view.looks
    // The theme's [music.display], or null.
    readonly property var lcd: view.lcd
    readonly property bool usesLcd: lcd !== null

    readonly property real inset: usesLcd ? (looks.lcd_inset ?? 5) : 0
    readonly property real textInset: usesLcd ? (looks.lcd_text_inset ?? 4) : 0
    readonly property real artSide: looks.art_size ?? 38
    readonly property real textLeft: inset + artSide + (looks.art_gap ?? 8)
    readonly property real textEnd: usesLcd ? (looks.lcd_text_end_inset ?? 8) : 0
    readonly property real textWidth: Math.max(0, width - textLeft - textEnd)

    // How wide it would like to be, to show the title and the line under it whole.
    readonly property real wantedWidth:
        textLeft + Math.ceil(Math.max(title.implicitWidth, subtitle.implicitWidth)) + textEnd

    implicitHeight: Math.max(artSide + 2 * inset, lines.implicitHeight + 2 * textInset)

    readonly property color titleColor: usesLcd && lcd.title_color !== undefined
        ? view.colour(lcd.title_color) : view.textColor
    readonly property color artistColor: usesLcd && lcd.artist_color !== undefined
        ? view.colour(lcd.artist_color) : view.secondaryColor
    readonly property color timeColor: usesLcd && lcd.time_color !== undefined
        ? view.colour(lcd.time_color) : view.secondaryColor
    readonly property int alignment:
        (usesLcd ? (looks.lcd_text_align ?? "center") : (looks.text_align ?? "left")) === "center"
            ? Text.AlignHCenter : Text.AlignLeft

    Fill {
        anchors.fill: parent
        visible: display.usesLcd
        fill: display.lcd?.fill ?? ({})
        themeDirectory: display.view.themeDirectory
    }

    // --- The art -----------------------------------------------------------------------

    Item {
        id: art
        readonly property real cornerRadius: display.looks.art_corner_radius ?? 2
        x: display.inset
        anchors.verticalCenter: parent.verticalCenter
        width: display.artSide
        height: display.artSide

        // Until the art has come, and for a track without any.
        Rectangle {
            anchors.fill: parent
            visible: artImage.status !== Image.Ready
            radius: art.cornerRadius
            color: display.view.placeholderColor

            Image {
                anchors.centerIn: parent
                readonly property real side: Math.round(art.width * 0.5)
                width: side
                height: side
                sourceSize: Qt.size(side * Screen.devicePixelRatio, side * Screen.devicePixelRatio)
                source: display.view.ownPicture("note")
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: display.artistColor
                }
            }
        }

        Image {
            id: artImage
            anchors.fill: parent
            visible: status === Image.Ready
            source: display.view.artSource
            asynchronous: true
            // A player may write new art over the same file; art from the web is kept.
            cache: !display.view.artSource.startsWith("file:")
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(art.width * Screen.devicePixelRatio, art.height * Screen.devicePixelRatio)
            layer.enabled: art.cornerRadius > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: artMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
        Rectangle {
            id: artMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            radius: art.cornerRadius
        }
    }

    // --- The lines ---------------------------------------------------------------------

    Column {
        id: lines
        x: display.textLeft
        width: display.textWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: display.looks.line_gap ?? 0

        Text {
            id: title
            width: parent.width
            horizontalAlignment: display.alignment
            text: display.view.title
            elide: Text.ElideRight
            color: display.titleColor
            font.family: display.view.font.family
            font.pixelSize: display.view.font.size + (display.looks.title_size_change ?? 0)
            font.bold: display.usesLcd ? (display.looks.lcd_title_bold ?? false) : (display.looks.title_bold ?? true)
        }
        Text {
            id: subtitle
            width: parent.width
            visible: text !== ""
            horizontalAlignment: display.alignment
            text: display.view.subtitle
            elide: Text.ElideRight
            color: display.artistColor
            font.family: display.view.font.family
            font.pixelSize: display.view.font.size + (display.looks.subtitle_size_change ?? -2)
        }

        // The time so far, the bar, the length; only for a track whose length is known.
        Item {
            id: scrubber
            width: parent.width
            visible: display.view.knowsLength
            height: display.usesLcd ? (display.looks.lcd_scrubber_height ?? 14) : (display.looks.scrubber_height ?? 12)

            // While the bar is dragged: the share it is dragged to, else -1.
            property real dragShare: -1
            readonly property real share: dragShare >= 0 ? dragShare
                : (display.view.length > 0 ? display.view.position / display.view.length : 0)
            readonly property bool active: display.view.canSeek && (seekArea.containsMouse || seekArea.pressed)

            // A drag is let go of when the track or the player changes under
            // it: its share was of the other track's length.
            Connections {
                target: display.view
                function onPlayerChanged() {
                    scrubber.dragShare = -1
                }
            }
            Connections {
                target: display.view.player
                ignoreUnknownSignals: true
                function onTrackChanged() {
                    scrubber.dragShare = -1
                }
            }

            component TimeText: Text {
                anchors.verticalCenter: parent.verticalCenter
                color: display.timeColor
                font.family: display.view.font.family
                font.pixelSize: display.view.font.size + (display.looks.time_size_change ?? -3)
                font.features: ({ "tnum": 1 })
            }
            TimeText {
                id: elapsed
                text: display.view.clock(scrubber.share * display.view.length)
            }
            TimeText {
                id: total
                anchors.right: parent.right
                text: display.view.clock(display.view.length)
            }

            Item {
                id: bar
                readonly property real gap: display.looks.time_gap ?? 5
                x: elapsed.width + gap
                width: Math.max(0, parent.width - elapsed.width - total.width - 2 * gap)
                height: parent.height

                // The theme's scrubber pieces when it has them, else a slim drawn bar.
                readonly property bool themed: display.usesLcd && display.lcd.line_fill !== undefined
                readonly property real lineHeight: display.lcd?.line_height ?? 21

                Fill {
                    visible: bar.themed
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: bar.lineHeight
                    fill: display.lcd?.line_fill ?? ({})
                    themeDirectory: display.view.themeDirectory
                }
                // With a knob, the played part runs to its middle, and is never
                // narrower than its left end, which the knob covers at the start
                // (as Bandstand draws it).
                Fill {
                    visible: bar.themed && display.lcd.line_played_fill !== undefined && width > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: knob.visible
                        ? Math.max(knob.x + knob.width / 2, display.lcd?.line_played_fill?.slice?.[3] ?? 0)
                        : parent.width * scrubber.share
                    height: bar.lineHeight
                    fill: display.lcd?.line_played_fill ?? ({})
                    themeDirectory: display.view.themeDirectory
                }
                Image {
                    id: knob
                    visible: bar.themed && display.lcd.knob !== undefined
                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width - width) * scrubber.share
                    source: visible ? "file://" + display.view.themeDirectory + "/" + display.lcd.knob : ""
                }

                Rectangle {
                    id: groove
                    visible: !bar.themed
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: scrubber.active ? (display.looks.seek_height_active ?? 5) : (display.looks.seek_height ?? 3)
                    radius: height / 2
                    color: display.view.trackColor
                }
                Rectangle {
                    visible: !bar.themed && scrubber.share > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(groove.height, groove.width * scrubber.share)
                    height: groove.height
                    radius: groove.radius
                    color: display.view.elapsedColor
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    enabled: display.view.canSeek
                    hoverEnabled: true
                    preventStealing: true
                    function shareAt(x) {
                        return Math.max(0, Math.min(1, x / Math.max(1, width)))
                    }
                    // The player and track pressed for; once another takes their
                    // place, the drag counts no more.
                    property var pressedFor: null
                    property real trackPressed: -1
                    readonly property bool sameTrack: pressedFor === display.view.player
                        && trackPressed === (display.view.player?.uniqueId ?? -1)
                    onPressed: mouse => {
                        pressedFor = display.view.player
                        trackPressed = display.view.player?.uniqueId ?? -1
                        scrubber.dragShare = shareAt(mouse.x)
                    }
                    onPositionChanged: mouse => {
                        if (pressed && sameTrack) {
                            scrubber.dragShare = shareAt(mouse.x)
                        }
                    }
                    onReleased: {
                        if (display.view.canSeek && sameTrack && scrubber.dragShare >= 0) {
                            display.view.player.position = scrubber.dragShare * display.view.length
                        }
                        scrubber.dragShare = -1
                    }
                    onCanceled: scrubber.dragShare = -1
                }
            }
        }
    }
}
