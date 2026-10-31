// The AirPods extension's running part: finds connected AirPods, runs the
// helper that speaks their protocol (airpods.py) for as long as they stay
// connected, and keeps what they tell for the panel item
// (status/airpods.qml). While Conversation Awareness is on, it turns the
// sound down when the wearer starts talking; the AirPods only say so,
// lowering the sound is up to the computer.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: airpods

    // Handed over by the shell (src/shell/Extensions.qml in Mavernix).
    required property var extension
    property var settings: null
    property var extensions: null
    property var shell: null
    property var screen: null

    readonly property var wishes: extension.settings
    readonly property bool pretends: wishes.pretend ?? false

    // The first connected device whose name holds one of `names`. Other
    // headphones don't speak the protocol, and connecting to them on its
    // channel would only fail.
    readonly property var device: {
        const connected = (Bluetooth.devices?.values ?? []).filter(candidate => candidate.connected)
        return connected.find(candidate => (wishes.names ?? []).some(part => candidate.name.includes(part))) ?? null
    }
    readonly property bool connected: pretends || device !== null
    readonly property string name: pretends ? "AirPods Pro" : (device?.name ?? "")

    // --- What the AirPods tell ---------------------------------------------------------

    // Each part's charge as { level, charging }; null while a part isn't there.
    property var left: null
    property var right: null
    property var chargingCase: null
    // The noise control mode; "" until the AirPods have told it.
    property string mode: ""
    // Whether Conversation Awareness is on; null for AirPods that don't
    // have it. Those that have it also have the Adaptive mode.
    property var awareness: null

    function forget() {
        left = null
        right = null
        chargingCase = null
        mode = ""
        awareness = null
        speaking(false)
    }

    function take(line) {
        let said
        try {
            said = JSON.parse(line)
        } catch (error) {
            console.warn("airpods: the helper printed something that isn't JSON:", line)
            return
        }
        if (said.event === "battery") {
            left = said.left
            right = said.right
            chargingCase = said.case
        } else if (said.event === "mode") {
            mode = said.mode
        } else if (said.event === "awareness") {
            awareness = said.on
        } else if (said.event === "speaking") {
            console.info("airpods: the wearer", said.now ? "started" : "stopped", "talking;",
                         playingThroughThem ? "turning the sound down or up" : "the sound isn't theirs")
            speaking(said.now)
        } else if (said.event === "failed") {
            console.warn("airpods:", said.reason)
        }
    }

    function setMode(wanted) {
        helper.write("mode " + wanted + "\n")
    }
    function setAwareness(on) {
        helper.write("awareness " + (on ? "on" : "off") + "\n")
        // Unlike a new mode, a changed setting isn't always told back.
        awareness = on
    }
    function disconnect() {
        device?.disconnect()
    }

    // --- The helper ----------------------------------------------------------------------

    Process {
        id: helper
        command: ["python3", airpods.extension.directory + "/airpods.py",
                  airpods.pretends ? "--pretend" : (airpods.device?.address ?? "")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => airpods.take(line)
        }
        onExited: {
            airpods.forget()
            if (airpods.connected) {
                tryAgain.start()
            }
        }
    }

    // The channel can drop while the sound stays connected, after the
    // computer has slept, for one; then the helper starts over.
    Timer {
        id: tryAgain
        interval: 5000
        onTriggered: helper.running = airpods.connected
    }

    onConnectedChanged: {
        tryAgain.stop()
        helper.running = connected
    }
    Component.onCompleted: helper.running = connected
    // The helper would outlive the extension being switched off.
    Component.onDestruction: helper.running = false

    // --- Turning the sound down while the wearer talks ---------------------------------

    readonly property var output: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: airpods.output !== null ? [airpods.output] : []
    }

    // Only the AirPods' own sound is turned down; PipeWire names their
    // output after their address.
    readonly property bool playingThroughThem: device !== null && output !== null
        && output.name.includes(device.address.replace(/:/g, "_"))

    // The loudness before it was turned down; -1 while it isn't.
    property real loudnessBefore: -1

    function speaking(now) {
        if (now && loudnessBefore < 0 && playingThroughThem && output.audio !== null) {
            loudnessBefore = output.audio.volume
            output.audio.volume = loudnessBefore * (wishes.speaking_loudness ?? 0.2)
        } else if (!now && loudnessBefore >= 0) {
            if (output?.audio) {
                output.audio.volume = loudnessBefore
            }
            loudnessBefore = -1
        }
        if (now) {
            stillSpeaking.restart()
        } else {
            stillSpeaking.stop()
        }
    }

    // With one earbud in, the AirPods sometimes never say the talking has
    // stopped (CAPod found the same), so the sound comes back by itself.
    Timer {
        id: stillSpeaking
        interval: 15000
        onTriggered: airpods.speaking(false)
    }
}
