// The Input Source extension's panel item displays the current keyboard
// layout and allows users to switch layouts via its menu.
//
// It uses keyboard layout IPC methods and events introduced in Wayfire 0.10,
// eliminating the need for polling.

import QtQuick
import Quickshell
import Quickshell.Io
import qs

StatusItem {
    id: item

    readonly property var extension: panel.extensions?.info("inputsource") ?? null
    readonly property var words: extension?.manifest.words ?? ({})
    readonly property bool connected: socket.connected

    property int layoutIndex: -1
    property var possibleLayouts: []

    // A number big enough just to not intersect with keyboard layout IDs
    readonly property int settingsId: 1000

    text: {
        if (!connected)
            return "Wayfire IPC unavailable";

        const layout = possibleLayouts[layoutIndex];

        if (layout === undefined)
            return "Loading...";

        return findPair(words.layout_map ?? [], layout)?.[1] ?? layout;
    }

    function entry(id, label, enabled, checkable, checked, children) {
        return {
            id: id,
            label: label,
            enabled: enabled,
            separator: false,
            checkable: checkable ?? false,
            checked: checked ?? false,
            shortcut: [],
            children: children ?? []
        };
    }

    readonly property var separator: ({
            id: 0,
            label: "",
            enabled: false,
            separator: true,
            checkable: false,
            checked: false,
            shortcut: [],
            children: []
        })

    function changeLayout(index) {
        if (socket.connected)
            socket.request("wayfire/set-keyboard-state", {
                "layout-index": index
            });
    }

    function updateLayout(state) {
        possibleLayouts = state["possible-layouts"] ?? [];
        layoutIndex = state["layout-index"] ?? -1;
    }

    function findPair(pairs, key) {
        for (const pair of pairs) {
            if (pair[0] === key)
                return pair;
        }
        return null;
    }

    menuItems: {
        const items = [];

        for (let index = 0; index < possibleLayouts.length; index++) {
            items.push(entry(index, possibleLayouts[index], true, true, index === layoutIndex));
        }

        items.push(separator);
        items.push(entry(settingsId, words?.show_keyboard_preferences ?? "Show Keyboard preferences...", true));

        return items;
    }

    // Refresh the keyboard state when the menu opens.
    // Wayfire may not emit an event after its keymap is reconfigured.
    onOpening: {
        if (socket.connected)
            socket.request("wayfire/get-keyboard-state", {});
    }

    onChosen: id => {
        if (id === settingsId) {
            Quickshell.execDetached(["mavernix-settings", "keyboard"]);
        } else {
            changeLayout(id);
        }
    }

    Socket {
        id: socket

        path: Quickshell.env("WAYFIRE_SOCKET") || ""
        connected: path !== ""

        function request(method, data) {
            if (!socket.connected)
                return;

            const json = JSON.stringify({
                method,
                data
            });

            // Wayfire IPC messages use a 4-byte little-endian
            // length prefix followed by a JSON payload.
            //
            // All requests used here are ASCII and shorter than
            // 128 bytes, allowing a simple UTF-8-compatible prefix.
            if (json.length > 127)
                console.error("Input Source error: IPC request too large");

            socket.write(String.fromCharCode(json.length, 0, 0, 0) + json);
            socket.flush();
        }

        onConnectedChanged: {
            if (!connected)
                return;

            request("window-rules/events/watch", {
                events: ["keyboard-modifier-state-changed"]
            });

            request("wayfire/get-keyboard-state", {});
        }

        parser: SplitParser {
            splitMarker: ""

            property string pending: ""
            property int depth: 0
            property bool inString: false
            property bool escaped: false

            onRead: chunk => {
                for (const c of chunk) {
                    if (depth === 0) {
                        // Ignore Wayfire's binary header.
                        if (c !== "{")
                            continue;

                        pending = "{";
                        depth = 1;
                        inString = false;
                        escaped = false;
                        continue;
                    }

                    pending += c;

                    if (inString) {
                        if (escaped)
                            escaped = false;
                        else if (c === "\\")
                            escaped = true;
                        else if (c === '"')
                            inString = false;
                    } else {
                        if (c === '"')
                            inString = true;
                        else if (c === "{")
                            depth++;
                        else if (c === "}")
                            depth--;
                    }

                    if (depth === 0) {
                        try {
                            const message = JSON.parse(pending);

                            if (message.event === "keyboard-modifier-state-changed")
                                item.updateLayout(message.state);
                            else if (typeof message.layout === "string")
                                item.updateLayout(message);
                        } catch (e) {
                            console.error("Input Source error: invalid Wayfire message:", e);
                        }
                        pending = "";
                        depth = 0;
                        inString = false;
                        escaped = false;
                    }
                }
            }
        }
    }
}

