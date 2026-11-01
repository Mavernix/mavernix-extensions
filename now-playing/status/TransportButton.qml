// A transport button in the Now Playing panel: "previous", "play",
// "pause" or "next". With a theme that has iTunes' buttons
// ([music.top_bar.pictures]), their pictures, pressed and greyed ones
// included, at their own size. Without, the extension's own drawing
// (images/NAME.svg) in the menu's text colour: dimmer while pressed, dimmer
// still while the player can't do it.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
    id: button

    // NowPlayingPopover.qml, for the looks and the colours.
    required property var view
    property string name: ""
    // The drawn glyph's size, when the theme has no picture.
    property real side: view.looks.glyph_size ?? 16
    signal clicked()

    // { normal, pressed, disabled }, or null.
    readonly property var pictures: view.buttonPictures?.[name] ?? null

    width: pictures !== null ? themed.implicitWidth : Math.max(side + 8, height)
    height: pictures !== null ? themed.implicitHeight : (view.looks.transport_height ?? 22)

    Image {
        id: themed
        visible: button.pictures !== null
        anchors.centerIn: parent
        source: {
            if (button.pictures === null) {
                return ""
            }
            const picture = !button.enabled ? (button.pictures.disabled ?? button.pictures.normal)
                : area.pressed ? (button.pictures.pressed ?? button.pictures.normal)
                : button.pictures.normal
            return "file://" + button.view.themeDirectory + "/" + picture
        }
    }

    Image {
        visible: button.pictures === null
        anchors.centerIn: parent
        width: button.side
        height: button.side
        sourceSize: Qt.size(button.side * Screen.devicePixelRatio, button.side * Screen.devicePixelRatio)
        source: visible ? button.view.ownPicture(button.name) : ""
        opacity: button.enabled ? 1 : (button.view.looks.disabled_glyph_opacity ?? 0.35)
        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: area.pressed ? button.view.secondaryColor : button.view.textColor
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
