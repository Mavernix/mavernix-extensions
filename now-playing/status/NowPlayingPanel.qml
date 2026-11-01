// What the Now Playing panel shows, inside its box: with more than one
// player, a line naming the one shown, which opens a menu of them all; the
// track (TrackDisplay.qml); and the buttons (TransportButton.qml) with the
// player's loudness beside them (VolumeSlider.qml). It sets its own size,
// padding included, so the shell can hold it in its menu box (a
// StatusItem's `popover`), or NowPlayingPopover.qml in its own window.

pragma ComponentBehavior: Bound

import QtQuick
import qs

Item {
    id: contentsBox

    // NowPlayingPopover.qml: the player, the looks, the colours.
    required property var view

    readonly property real padding: view.looks.padding ?? 12
    // As wide as the title wants, within the looks' bounds.
    implicitWidth: Math.round(Math.max(view.looks.min_width ?? 340,
                                       Math.min(view.looks.max_width ?? 400,
                                                Math.max(display.wantedWidth,
                                                         view.players.length > 1 ? sourceLine.width : 0)
                                                + 2 * padding)))
    implicitHeight: contents.implicitHeight + 2 * padding
    width: implicitWidth
    height: implicitHeight

    // Keys, for the panel's own window: true if it took the key.
    function keyPressed(event) {
        if (view.pickerOpen) {
            if (event.key === Qt.Key_Escape) {
                view.pickerOpen = false
            } else if (event.key === Qt.Key_Down) {
                picker.moveMark(1)
            } else if (event.key === Qt.Key_Up) {
                picker.moveMark(-1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                picker.chooseMarked()
            } else {
                return false
            }
            return true
        }
        if (event.key === Qt.Key_Space && view.canPlayPause) {
            view.playPause()
            return true
        }
        return false
    }

    // While the menu of players is open, a press beside it closes only the menu.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: contentsBox.view.pickerOpen = false
    }

    Column {
        id: contents
        x: contentsBox.padding
        y: contentsBox.padding
        width: contentsBox.width - 2 * contentsBox.padding
        spacing: contentsBox.view.looks.row_gap ?? 8

        // "Firefox ▾": which player this is, with a menu of the others.
        Item {
            id: sourceLine
            visible: contentsBox.view.players.length > 1
            width: sourceText.implicitWidth
            height: contentsBox.view.looks.source_height ?? 16

            Text {
                id: sourceText
                anchors.verticalCenter: parent.verticalCenter
                text: (contentsBox.view.player !== null ? contentsBox.view.nameOf(contentsBox.view.player) : "")
                    + " " + (contentsBox.view.looks.source_arrow ?? "▾")
                color: sourceArea.pressed || contentsBox.view.pickerOpen
                    ? contentsBox.view.textColor : contentsBox.view.secondaryColor
                font.family: contentsBox.view.font.family
                font.pixelSize: contentsBox.view.font.size + (contentsBox.view.looks.source_size_change ?? -2)
            }
            MouseArea {
                id: sourceArea
                anchors.fill: parent
                onClicked: contentsBox.view.pickerOpen = !contentsBox.view.pickerOpen
            }
        }

        TrackDisplay {
            id: display
            view: contentsBox.view
            width: parent.width
        }

        // Back, play or pause, and forward; beside them the player's
        // loudness, if it has one, as iTunes has it. The buttons stand in
        // the middle when there is no slider.
        Item {
            width: parent.width
            height: Math.max(transport.height, volume.usable ? volume.implicitHeight : 0)

            Row {
                id: transport
                x: volume.usable ? (contentsBox.view.looks.transport_inset ?? 0) : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: contentsBox.view.buttonPictures !== null
                    ? (contentsBox.view.theme.music?.top_bar?.transport_spacing ?? 11)
                    : (contentsBox.view.looks.glyph_spacing ?? 24)

                TransportButton {
                    view: contentsBox.view
                    name: "previous"
                    enabled: contentsBox.view.player?.canGoPrevious ?? false
                    onClicked: contentsBox.view.player.previous()
                }
                TransportButton {
                    view: contentsBox.view
                    name: (contentsBox.view.player?.isPlaying ?? false) ? "pause" : "play"
                    side: contentsBox.view.looks.play_glyph_size ?? 22
                    enabled: contentsBox.view.canPlayPause
                    onClicked: contentsBox.view.playPause()
                }
                TransportButton {
                    view: contentsBox.view
                    name: "next"
                    enabled: contentsBox.view.player?.canGoNext ?? false
                    onClicked: contentsBox.view.player.next()
                }
            }

            VolumeSlider {
                id: volume
                view: contentsBox.view
                visible: usable
                anchors.right: parent.right
                anchors.rightMargin: contentsBox.view.looks.volume_end_inset ?? 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(implicitWidth,
                                            parent.width - transport.width - (contentsBox.view.looks.volume_gap ?? 16)))
            }
        }
    }

    // The menu of players: each with what it plays, the one shown ticked.
    // The shell's own menu box. (A play symbol after those playing read as
    // a submenu's arrow.)
    MenuBox {
        id: picker
        visible: contentsBox.view.pickerOpen
        settings: contentsBox.view.panel.settings
        // Under the line, its text level with the line's.
        x: contentsBox.padding - (contentsBox.view.menuLooks.text_inset ?? 0)
        y: contentsBox.padding + sourceLine.height
        z: 1
        items: !contentsBox.view.pickerOpen ? [] : contentsBox.view.players.map((candidate, index) => ({
            id: index,
            label: contentsBox.view.nameOf(candidate)
                + (candidate.trackTitle !== "" ? " – " + candidate.trackTitle : ""),
            enabled: true, separator: false, checkable: true,
            checked: candidate === contentsBox.view.player,
            shortcut: [], children: []
        }))
        onChosen: id => {
            const candidate = contentsBox.view.players[id]
            if (candidate !== undefined) {
                contentsBox.view.source?.choose(candidate)
            }
            contentsBox.view.pickerOpen = false
        }
    }
}
