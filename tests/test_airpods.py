"""Checks how airpods/airpods.py reads the AirPods' messages and writes its
own. The examples are put together from LibrePods' description of the
protocol (docs/ there).

    python3 -m unittest discover tests
"""

import importlib.util
import pathlib
import unittest

HELPER = pathlib.Path(__file__).parent.parent / "airpods" / "airpods.py"
spec = importlib.util.spec_from_file_location("airpods", HELPER)
airpods = importlib.util.module_from_spec(spec)
spec.loader.exec_module(airpods)


def read(text):
    return airpods.read_message(bytes.fromhex(text))


class Reading(unittest.TestCase):
    def test_battery_of_all_three_parts(self):
        self.assertEqual(
            read("04 00 04 00 04 00 03 02 01 5c 02 01 04 01 57 02 01 08 01 40 01 01"),
            {"event": "battery",
             "left": {"level": 87, "charging": False},
             "right": {"level": 92, "charging": False},
             "case": {"level": 64, "charging": True}})

    def test_battery_without_the_case(self):
        said = read("04 00 04 00 04 00 03 02 01 5c 02 01 04 01 57 02 01 08 01 00 04 01")
        self.assertIsNone(said["case"])
        self.assertEqual(said["left"]["level"], 87)

    def test_battery_cut_short(self):
        said = read("04 00 04 00 04 00 03 02 01 5c 02 01 04 01")
        self.assertEqual(said["right"]["level"], 92)
        self.assertIsNone(said["left"])

    def test_mode(self):
        self.assertEqual(read("04 00 04 00 09 00 0d 03 00 00 00"), {"event": "mode", "mode": "transparency"})
        self.assertEqual(read("04 00 04 00 09 00 0d 04 00 00 00"), {"event": "mode", "mode": "adaptive"})

    def test_awareness(self):
        self.assertEqual(read("04 00 04 00 09 00 28 01 00 00 00"), {"event": "awareness", "on": True})
        self.assertEqual(read("04 00 04 00 09 00 28 02 00 00 00"), {"event": "awareness", "on": False})

    def test_speaking(self):
        self.assertEqual(read("04 00 04 00 4b 00 02 00 01 01"), {"event": "speaking", "now": True})
        self.assertEqual(read("04 00 04 00 4b 00 02 00 01 09"), {"event": "speaking", "now": False})
        # Winding down: neither started nor stopped.
        self.assertIsNone(read("04 00 04 00 4b 00 02 00 01 03"))

    def test_what_it_does_not_report(self):
        self.assertIsNone(read("04 00 04 00 09 00 1a 01 00 00 00"))
        self.assertIsNone(read("04 00 04 00 06 00 00 02"))
        self.assertIsNone(read("04 00 04"))
        self.assertIsNone(read("01 00 04 00 00 00 00"))


class Writing(unittest.TestCase):
    def written(self, line):
        return [message.hex(" ") for message in airpods.messages_for(line)]

    def test_mode(self):
        self.assertEqual(self.written("mode noise_cancellation"), ["04 00 04 00 09 00 0d 02 00 00 00"])

    def test_off_is_allowed_first(self):
        self.assertEqual(self.written("mode off"),
                         ["04 00 04 00 09 00 34 01 00 00 00", "04 00 04 00 09 00 0d 01 00 00 00"])

    def test_awareness(self):
        self.assertEqual(self.written("awareness off"), ["04 00 04 00 09 00 28 02 00 00 00"])

    def test_nonsense_sends_nothing(self):
        self.assertEqual(self.written("mode loud"), [])
        self.assertEqual(self.written("awareness"), [])
        self.assertEqual(self.written(""), [])

    def test_what_it_writes_it_can_read(self):
        for line in ("mode transparency", "awareness on"):
            message = airpods.messages_for(line)[-1]
            self.assertIsNotNone(airpods.read_message(message), line)


class Input(unittest.TestCase):
    def test_two_lines_in_one_chunk_both_come_out(self):
        self.assertEqual(airpods.split_lines(b"", b"mode off\nawareness on\n"),
                         (["mode off", "awareness on"], b""))

    def test_a_line_cut_in_two_waits_for_its_end(self):
        lines, rest = airpods.split_lines(b"", b"mode tran")
        self.assertEqual((lines, rest), ([], b"mode tran"))
        self.assertEqual(airpods.split_lines(rest, b"sparency\n"), (["mode transparency"], b""))


if __name__ == "__main__":
    unittest.main()
