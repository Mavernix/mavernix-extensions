// The Now Playing extension's panel item: a play symbol while a media
// player is around. Pressing it opens the panel under it
// (NowPlayingPanel.qml) with the track and its controls: in the shell's
// menu box, as the item's `popover`, where the desktop has that; else in a
// window of its own (NowPlayingPopover.qml).
//
// Which player it shows is up to the extension's running part
// (../Background.qml).

pragma ComponentBehavior: Bound

import QtQuick
import qs

StatusItem {
    id: item

    readonly property var extension: panel.extensions?.info("now-playing") ?? null
    readonly property var nowPlaying: panel.extensions?.running("now-playing") ?? null
    readonly property var player: nowPlaying?.player ?? null
    readonly property var looks: extension?.looks ?? ({})

    shown: player !== null
    onShownChanged: {
        if (!shown) {
            if (popover.hostedByShell && open) {
                panel.closeMenu()
            }
            popover.close()
        }
    }

    // Older desktops have no `popover`; setting it here, not as a binding,
    // keeps the item loading there.
    Component.onCompleted: {
        if ("popover" in item) {
            popover.hostedByShell = true
            item.popover = panelComponent
        }
    }
    Component {
        id: panelComponent
        NowPlayingPanel {
            view: popover
        }
    }

    // The symbol is asked for by name like every status item's: the theme's
    // picture for it ([panel.status.icons], shown at its own size), else the
    // icon theme's. Without either, the extension's own drawing, so the item
    // never ends up empty. (Setting pictureSource here replaces StatusItem's
    // lookup, which would only warn.)
    iconName: looks.icon_name ?? "media-playback-start"
    pictureSource: {
        const found = picture(iconName)
        if (found !== "") {
            return found
        }
        return extension !== null ? "file://" + extension.directory + "/images/play.svg" : ""
    }

    // Lit like an open menu while its own window is open, and while it fades;
    // the shell lights it when it holds the panel.
    held: !popover.hostedByShell && (popover.open || popover.fading)

    // Only without the shell's `popover`: with it, a press opens the panel as a menu.
    onActivated: {
        if (popover.open) {
            popover.close()
        } else {
            popover.show()
        }
    }

    NowPlayingPopover {
        id: popover
        owner: item
        panel: item.panel
        player: item.player
        extension: item.extension
        source: item.nowPlaying
    }
}
