#!/usr/bin/env python3
"""Talks to a pair of AirPods and reports what they say, one JSON object a line.

    airpods.py ADDRESS     talk to the AirPods with this Bluetooth address
    airpods.py --pretend   no AirPods: made-up ones, for trying the extension

AirPods tell their charge, their noise control mode and when their wearer
starts or stops talking, and take a new mode, over a channel of their own
beside the sound: the L2CAP channel 0x1001, in Apple's accessory protocol.
Apple doesn't document it; the messages here are the ones the LibrePods
project has written down (docs/ there), which CAPod and podctl agree with.

What is printed, each on a line:

    {"event": "connected"}
    {"event": "battery", "left": {"level": 85, "charging": false}, "right": {...}, "case": null}
    {"event": "mode", "mode": "off" | "noise_cancellation" | "transparency" | "adaptive"}
    {"event": "awareness", "on": true}           Conversation Awareness switched on or off
    {"event": "speaking", "now": true}           the wearer started (or stopped) talking
    {"event": "failed", "reason": "..."}         and the program ends

What is taken, each on a line of the input:

    mode transparency          (or off, noise_cancellation, adaptive)
    awareness on               (or off)

Only Python's own library, and no more rights than any program has.
"""

import json
import select
import socket
import sys
import time

# --- The messages ---------------------------------------------------------------

CHANNEL = 0x1001

# Sent first; until then the AirPods ignore everything.
HANDSHAKE = bytes.fromhex("00 00 04 00 01 00 02 00 00 00 00 00 00 00 00 00")
# Turns on what the AirPods otherwise keep to Apple's own devices: the
# Adaptive mode, and Conversation Awareness while something plays. What
# each bit means isn't known; this is the value LibrePods and CAPod send.
UNLOCK_FEATURES = bytes.fromhex("04 00 04 00 4d 00 d7 00 00 00 00 00 00 00")
# Asks the AirPods to tell of every change from now on. They answer with
# their charge and settings straight away.
REQUEST_NOTIFICATIONS = bytes.fromhex("04 00 04 00 0f 00 ff ff ff ff")

# Every message after the handshake starts with these four bytes; the next
# one says what kind of message it is.
HEADER = bytes.fromhex("04 00 04 00")
KIND_BATTERY = 0x04
KIND_SETTING = 0x09
KIND_SPEAKING = 0x4B

# A battery message has, after its count, five bytes for each part: the
# part, 0x01, the level in percent, the state, 0x01.
BATTERY_PARTS = {0x02: "right", 0x04: "left", 0x08: "case"}
BATTERY_ENTRY_BYTES = 5
BATTERY_CHARGING = 0x01
# The case with its lid shut and both earbuds out, for one.
BATTERY_NOT_THERE = 0x04

# The settings this program reads and writes. On and off are 0x01 and 0x02.
SETTING_MODE = 0x0D
SETTING_AWARENESS = 0x28
# Whether "off" is among the modes the AirPods take; it isn't, out of the box.
SETTING_ALLOW_OFF = 0x34
ON, OFF = 0x01, 0x02

MODES = {0x01: "off", 0x02: "noise_cancellation", 0x03: "transparency", 0x04: "adaptive"}

# What a speaking message says, by its last byte. LibrePods' reading
# lowers and restores the sound too early; this is CAPod's, which was
# worked out from recordings. The values left out are the AirPods winding
# down, which changes nothing.
STARTED_SPEAKING = {0x01, 0x02}
STOPPED_SPEAKING = {0x05, 0x06, 0x08, 0x09}


def read_message(message):
    """What one message from the AirPods says, as the object to print;
    None for a message of a kind this program does not report."""
    if len(message) < 7 or message[:4] != HEADER:
        return None
    kind = message[4]
    body = message[6:]

    if kind == KIND_BATTERY:
        parts = {"left": None, "right": None, "case": None}
        for number in range(body[0]):
            start = 1 + number * BATTERY_ENTRY_BYTES
            entry = body[start:start + BATTERY_ENTRY_BYTES]
            if len(entry) < BATTERY_ENTRY_BYTES:
                break
            name = BATTERY_PARTS.get(entry[0])
            level, state = entry[2], entry[3]
            if name is None or state == BATTERY_NOT_THERE or level > 100:
                continue
            parts[name] = {"level": level, "charging": state == BATTERY_CHARGING}
        return {"event": "battery", **parts}

    if kind == KIND_SETTING and len(body) >= 2:
        setting, value = body[0], body[1]
        if setting == SETTING_MODE and value in MODES:
            return {"event": "mode", "mode": MODES[value]}
        if setting == SETTING_AWARENESS and value in (ON, OFF):
            return {"event": "awareness", "on": value == ON}
        return None

    if kind == KIND_SPEAKING and len(body) >= 4:
        if body[3] in STARTED_SPEAKING:
            return {"event": "speaking", "now": True}
        if body[3] in STOPPED_SPEAKING:
            return {"event": "speaking", "now": False}

    return None


def setting_message(setting, value):
    return HEADER + bytes([KIND_SETTING, 0x00, setting, value, 0x00, 0x00, 0x00])


def messages_for(line):
    """The messages a line of input asks to send; [] for a line that
    asks for nothing this program knows."""
    words = line.split()
    if len(words) != 2:
        return []
    what, value = words
    if what == "mode":
        for number, name in MODES.items():
            if name == value:
                messages = [setting_message(SETTING_MODE, number)]
                # The AirPods turn "off" down unless it is allowed first.
                if value == "off":
                    messages.insert(0, setting_message(SETTING_ALLOW_OFF, ON))
                return messages
    if what == "awareness" and value in ("on", "off"):
        return [setting_message(SETTING_AWARENESS, ON if value == "on" else OFF)]
    return []


# --- Talking ----------------------------------------------------------------------

def say(event):
    print(json.dumps(event), flush=True)


def talk(address):
    """Connects to the AirPods and passes messages both ways until either
    side ends. Only to be started while the AirPods are connected for
    sound: connecting to a pair that isn't can take it from the phone
    it is in use with."""
    link = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
    try:
        # The system waits far longer than this for a pair out of reach.
        link.settimeout(10)
        link.connect((address, CHANNEL))
        link.settimeout(None)
        # The AirPods miss a message that comes before they have taken
        # the one before it; LibrePods waits as long.
        for message in (HANDSHAKE, UNLOCK_FEATURES, REQUEST_NOTIFICATIONS):
            link.send(message)
            time.sleep(0.3)
    except OSError as error:
        say({"event": "failed", "reason": f"could not reach {address} on channel {CHANNEL:#x}: {error}"})
        return 1
    say({"event": "connected"})

    # Sometimes the first request goes unanswered; it is asked once more
    # if nothing has come after two seconds.
    asked_again = False
    while True:
        ready, _, _ = select.select([link, sys.stdin], [], [], None if asked_again else 2)
        if not ready and not asked_again:
            link.send(REQUEST_NOTIFICATIONS)
            asked_again = True
            continue
        if link in ready:
            asked_again = True
            try:
                message = link.recv(1024)
            except OSError as error:
                say({"event": "failed", "reason": f"the connection to {address} ended: {error}"})
                return 1
            if not message:
                say({"event": "failed", "reason": f"{address} closed the connection"})
                return 1
            event = read_message(message)
            if event is not None:
                say(event)
        if sys.stdin in ready:
            line = sys.stdin.readline()
            if not line:
                return 0
            for message in messages_for(line):
                link.send(message)


def pretend():
    """Made-up AirPods: says what a pair might, and takes what it's told."""
    say({"event": "connected"})
    say({"event": "battery", "left": {"level": 87, "charging": False},
         "right": {"level": 92, "charging": False}, "case": {"level": 64, "charging": True}})
    say({"event": "mode", "mode": "noise_cancellation"})
    say({"event": "awareness", "on": True})
    for line in sys.stdin:
        for message in messages_for(line):
            event = read_message(message)
            if event is not None:
                say(event)
    return 0


def main():
    if len(sys.argv) != 2:
        sys.exit("airpods.py: give a Bluetooth address, or --pretend (see the top of this file)")
    if sys.argv[1] == "--pretend":
        return pretend()
    return talk(sys.argv[1])


if __name__ == "__main__":
    sys.exit(main())
