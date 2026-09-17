"""X5 (round 5): stem sets, from placeholder to import to the contract check."""

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_music  # noqa: E402
import import_music  # noqa: E402
import make_music_placeholders  # noqa: E402

MUSIC = HERE.parents[1] / "assets" / "music"


class StemTest(unittest.TestCase):
    def test_the_shipped_fight_track_is_a_stem_set_that_passes_the_contract(self):
        manifest = json.loads((MUSIC / "manifest.json").read_text())
        fight = manifest["tracks"]["fight"]
        self.assertGreaterEqual(len(fight["stems"]), 3)
        froms = [s["from"] for s in fight["stems"] if "from" in s]
        self.assertEqual(froms, sorted(froms), "quietest layer first")
        self.assertEqual(froms[0], 0.0, "something always plays")
        self.assertEqual(check_music.check_stems(MUSIC, "fight", fight, -16.0), [])

    def test_a_folder_of_suno_stems_imports_into_a_passing_stem_set(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "suno").mkdir()
            (tmp / "out").mkdir()
            stems = make_music_placeholders._fight_stems()
            for name, samples in stems.items():
                make_music_placeholders._write_np_wav(samples, tmp / "suno" / ("Arena (%s).wav" % name), 0.2)
            layers = import_music.parse_layers("pad=0 pulse=0.2 bass=0.45 drums=0.65 alarm=last_stand")
            self.assertEqual(layers[-1], ("alarm", {"states": ["last_stand"]}))
            track = import_music.import_stems(tmp / "suno", "fight", layers, 120, 4, tmp / "out", "test", ["battle"])
            self.assertEqual(check_music.check_stems(tmp / "out", "fight", track, -16.0), [],
                             "one shared gain brings a quiet export up to the target without clipping the sum")

    def test_stems_that_do_not_line_up_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            manifest = json.loads((MUSIC / "manifest.json").read_text())
            fight = manifest["tracks"]["fight"]
            for stem in fight["stems"]:
                shutil.copy(MUSIC / stem["file"], tmp / stem["file"])
            short = tmp / fight["stems"][1]["file"]
            import subprocess
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(MUSIC / fight["stems"][1]["file"]), "-t", "4",
                            str(short)], check=True)
            problems = check_music.check_stems(tmp, "fight", fight, -16.0)
            self.assertTrue(any("differ in length" in p for p in problems), problems)


if __name__ == "__main__":
    unittest.main()
