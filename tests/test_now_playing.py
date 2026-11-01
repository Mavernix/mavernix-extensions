"""Checks that the Now Playing extension is whole: what its manifest names is
there, its looks can be read, and the release holds it as the App Store
reads it.

    python3 -m unittest discover tests
"""

import pathlib
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import unittest

ROOT = pathlib.Path(__file__).parent.parent
FOLDER = ROOT / "now-playing"


class Folder(unittest.TestCase):
    def setUp(self):
        self.manifest = tomllib.loads((FOLDER / "extension.toml").read_text())

    def test_what_the_manifest_names_is_there(self):
        self.assertTrue((FOLDER / self.manifest["icon"]).is_file())
        self.assertTrue((FOLDER / self.manifest["background"]).is_file())
        for item in self.manifest["panel_items"]["right"]:
            self.assertTrue((FOLDER / "status" / f"{item}.qml").is_file())
        for part in ("NowPlayingPopover", "NowPlayingPanel", "TrackDisplay", "TransportButton", "VolumeSlider"):
            self.assertTrue((FOLDER / "status" / f"{part}.qml").is_file(), part)

    def test_the_pictures_the_panel_uses_are_there(self):
        for name in ("play", "pause", "previous", "next", "note", "speaker-quiet", "speaker-loud"):
            self.assertTrue((FOLDER / "images" / f"{name}.svg").is_file(), name)

    def test_looks_can_be_read(self):
        looks = tomllib.loads((FOLDER / "looks" / "default.toml").read_text())
        self.assertGreater(looks["art_size"], 0)
        self.assertEqual(looks["icon_name"], "media-playback-start")


class Release(unittest.TestCase):
    def test_what_the_store_reads_is_made(self):
        with tempfile.TemporaryDirectory() as output:
            subprocess.run([sys.executable, str(ROOT / "packaging" / "make-release"), output], check=True)
            entry = tomllib.loads((pathlib.Path(output) / "extensions.toml").read_text())["now-playing"]
            self.assertEqual(entry["title"], "Now Playing")
            self.assertEqual(entry["version"], "0.1.1")
            self.assertEqual(entry["icon"], "now-playing-icon.svg")
            self.assertTrue((pathlib.Path(output) / entry["icon"]).is_file())
            with tarfile.open(pathlib.Path(output) / "now-playing.tar.gz") as archive:
                names = archive.getnames()
            self.assertIn("now-playing/extension.toml", names)
            self.assertIn("now-playing/status/now-playing.qml", names)


if __name__ == "__main__":
    unittest.main()
