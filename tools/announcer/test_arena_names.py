"""Every arena the game can build is named by the booth, with a recording for every line that names it."""

import json
import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ArenaNamesTest(unittest.TestCase):
    def test_every_arena_has_a_spoken_name_and_its_clips(self):
        lines = json.loads((ROOT / "assets" / "announcer" / "lines.json").read_text())
        clips = json.loads((ROOT / "assets" / "announcer" / "clips" / "manifest.json").read_text())["clips"]
        spoken = lines["vocabulary"]["arena"]
        naming = [line["id"] for line in lines["lines"] if "{arena}" in line["text"]]
        self.assertTrue(naming, "some lines name the arena")
        for layout in sorted((ROOT / "arenas").glob("*.json")):
            data = json.loads(layout.read_text())
            # A test fixture (arenas/maze.json) is loadable with --arena= but is never offered to a player, so the
            # booth has no recording of its name and should not get one. Edited by the arena stream, round 6, when
            # the maze landed and broke this test: the fix is for the test to tell a fixture from an arena, not to
            # spend an ElevenLabs recording on a map nobody plays.
            if data.get("fixture", False):
                continue
            name = data.get("name", layout.stem)
            self.assertIn(name, spoken, "%s has no spoken name: the booth would never name it" % name)
            for line_id in naming:
                self.assertIn("%s@%s" % (line_id, name), clips,
                              "%s is not recorded for %s (make announcer-generate ONLY=%s)" % (line_id, name, line_id))


if __name__ == "__main__":
    unittest.main()
