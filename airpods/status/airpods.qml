// The AirPods extension's panel item: a pair of AirPods while they're
// connected. Its menu is laid out the way OS X 10.9's own menus were: grey
// lines ending in a colon head each part, one line per value. It has the
// loudness, each part's charge with the theme's battery gauge, the output
// devices, the noise control mode and Conversation Awareness.
//
// What it shows is kept by the extension's running part (../Background.qml).

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

StatusItem {
    id: item

    readonly property var extension: panel.extensions?.info("airpods") ?? null
    readonly property var airpods: panel.extensions?.running("airpods") ?? null
    readonly property var words: extension?.manifest.words ?? ({})
    // The sound settings entry is the volume item's, so both say the same.
    readonly property var volumeWords: (panel.settings.config.status ?? ({})).volume ?? ({})

    shown: airpods !== null && airpods.connected

    // No icon theme has AirPods; the drawing is painted in the panel's
    // colour like every status item.
    pictureSource: extension !== null ? "file://" + extension.directory + "/images/airpods.svg" : ""
    pictureHeight: statusLooks.icon_size ?? 16

    readonly property var outputs:
        (Pipewire.nodes?.values ?? []).filter(node => !node.isStream && node.audio !== null && node.isSink)
    function nameOf(node) {
        return node.description !== "" ? node.description : (node.nickname !== "" ? node.nickname : node.name)
    }

    // Noise control modes in the order the menu lists them.
    readonly property var modes: ["off", "transparency", "adaptive", "noise_cancellation"]

    // Entry ids: fixed ones, and the rest counted from a base.
    readonly property int sliderId: 1
    readonly property int awarenessId: 2
    readonly property int disconnectId: 3
    readonly property int settingsId: 4
    readonly property int modeBaseId: 100
    readonly property int outputBaseId: 1000

    function entry(id, label, enabled, checked) {
        return { id: id, label: label, enabled: enabled, separator: false,
                 checkable: checked !== undefined, checked: checked ?? false, shortcut: [], children: [] }
    }
    readonly property var separator: ({ id: 0, label: "", enabled: false, separator: true,
                                        checkable: false, checked: false, shortcut: [], children: [] })

    // "Left: 87%", with the theme's battery gauge at the end of the line.
    function chargeLine(label, part) {
        const line = entry(0, label + ": " + part.level + "%", false)
        const gauge = picture(part.charging ? "battery-good-charging"
                                            : "battery-level-" + Math.round(part.level / 10) * 10)
        line.pictures = gauge !== "" ? [gauge] : []
        return line
    }

    // The menu is built from the loudness at opening, so it doesn't
    // rebuild while its slider is dragged.
    property real loudnessAtOpening: 0
    onOpening: loudnessAtOpening = panel.outputVolume.loudness

    menuItems: {
        if (airpods === null) {
            return []
        }
        const items = [entry(0, airpods.name + ": " + (words.connected ?? "Connected"), false)]

        if (panel.outputVolume.available) {
            const slider = entry(sliderId, "", false)
            slider.slider = loudnessAtOpening
            items.push(slider)
        }

        const parts = [[words.left ?? "Left", airpods.left],
                       [words.right ?? "Right", airpods.right],
                       [words.case ?? "Case", airpods.chargingCase]].filter(pair => pair[1] !== null)
        if (parts.length > 0) {
            items.push(separator)
            items.push(entry(0, words.battery ?? "Battery Level:", false))
            for (const [label, part] of parts) {
                items.push(chargeLine(label, part))
            }
        }

        if (outputs.length > 0) {
            items.push(separator)
            items.push(entry(0, volumeWords.output_label ?? "Output Device:", false))
            for (let index = 0; index < outputs.length; index++) {
                items.push(entry(outputBaseId + index, nameOf(outputs[index]), true,
                                 outputs[index] === Pipewire.defaultAudioSink))
            }
        }

        // Once the AirPods have told their mode. Adaptive only for those
        // that have Conversation Awareness too: the older ones have neither.
        if (airpods.mode !== "") {
            items.push(separator)
            items.push(entry(0, words.noise_control ?? "Noise Control:", false))
            for (let index = 0; index < modes.length; index++) {
                if (modes[index] === "adaptive" && airpods.awareness === null) {
                    continue
                }
                items.push(entry(modeBaseId + index, words[modes[index]] ?? modes[index], true,
                                 airpods.mode === modes[index]))
            }
        }
        if (airpods.awareness !== null) {
            items.push(separator)
            items.push(entry(awarenessId, words.awareness ?? "Conversation Awareness", true, airpods.awareness))
        }

        items.push(separator)
        if (!airpods.pretends) {
            items.push(entry(disconnectId, words.disconnect ?? "Disconnect", true))
        }
        if ((volumeWords.settings_command ?? []).length > 0) {
            items.push(entry(settingsId, volumeWords.settings_label ?? "Sound Settings…", true))
        }
        return items
    }

    onSlid: (id, value) => panel.outputVolume.setTo(value)

    onChosen: id => {
        if (airpods === null) {
            return
        }
        if (id === awarenessId) {
            airpods.setAwareness(!airpods.awareness)
        } else if (id === disconnectId) {
            airpods.disconnect()
        } else if (id === settingsId) {
            Quickshell.execDetached(volumeWords.settings_command)
        } else if (id >= outputBaseId) {
            Pipewire.preferredDefaultAudioSink = outputs[id - outputBaseId]
        } else if (id >= modeBaseId) {
            airpods.setMode(modes[id - modeBaseId])
        }
    }
}
