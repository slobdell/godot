"""The Arena Booth Monitor page embeds the director's output safely and links mixdowns that exist."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import demo_page  # noqa: E402
import events  # noqa: E402


class DemoPageTest(unittest.TestCase):
    def test_builds_one_page_with_every_match_and_its_audio(self):
        timeline = events.load_timeline(HERE.parent.parent / "tests" / "announcer" / "fixtures" / "blowout.jsonl")
        cue = {"t": 0.0, "end": 2.0, "speaker": "caller", "line_id": "caller.x", "text": "Nasty </script> stuff",
               "act": "call", "moment": "intro", "reason": "why", "cut": False, "slots": {"team": "green"}}
        with tempfile.TemporaryDirectory() as folder:
            for seed in (1, 2):
                (Path(folder) / ("blowout_seed%d.json" % seed)).write_text(json.dumps(
                    {"fixture": "blowout", "seed": seed, "events": timeline, "cues": [cue],
                     "decisions": [{"t": 1.0, "text": "skip kill: stale"}, {"t": 1.0, "text": "merge 2 kills"}]}))
            (Path(folder) / "blowout_seed2.ogg").write_bytes(b"OggS")
            matches = demo_page.load_matches(Path(folder))
            page = demo_page.build(matches)
        self.assertEqual([(m["seed"], "audio" in m) for m in matches], [(1, False), (2, True)])
        self.assertNotIn("slots", matches[0]["cues"][0], "only what the page shows is embedded")
        self.assertEqual(matches[0]["decisions"], [{"t": 1.0, "text": "skip kill: stale"}])
        self.assertIn("<title>Arena Booth Monitor</title>", page)
        self.assertNotIn("Nasty </script>", page, "line text can't close the data script early")
        self.assertIn("Nasty <\\/script>", page)

    def test_refuses_an_empty_folder(self):
        with self.assertRaises(ValueError):
            demo_page.build([])


if __name__ == "__main__":
    unittest.main()
