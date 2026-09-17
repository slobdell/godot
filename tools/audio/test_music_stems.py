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
    def test_the_shipped_fight_tracks_are_stem_sets_that_pass_the_contract(self):
        manifest = json.loads((MUSIC / "manifest.json").read_text())
        sets = {name: track for name, track in manifest["tracks"].items() if "stems" in track}
        self.assertTrue(sets, "the fight plays from stems")
        for name, fight in sets.items():
            self.assertGreaterEqual(len(fight["stems"]), 3, name)
            froms = [s["from"] for s in fight["stems"] if "from" in s]
            self.assertEqual(froms, sorted(froms), "%s: quietest layer first" % name)
            self.assertEqual(froms[0], 0.0, "%s: something always plays" % name)
            self.assertEqual(check_music.check_stems(MUSIC, name, fight, -16.0), [])

    def test_the_states_a_match_can_be_in_all_have_music(self):
        manifest = json.loads((MUSIC / "manifest.json").read_text())
        covered = {state for track in manifest["tracks"].values() for state in track.get("states", [])}
        self.assertEqual(covered, {"garage", "pre_match", "lull", "skirmish", "battle", "last_stand", "victory", "defeat"})

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

    def test_from_and_to_cut_a_section_and_refuse_nonsense(self):
        self.assertEqual(import_music.seconds("1:32"), 92.0)
        self.assertEqual(import_music.seconds("12.5"), 12.5)
        self.assertEqual(import_music.section(0.2, 130.0, 30.0, 110.0), (30.0, 110.0))
        self.assertEqual(import_music.section(0.2, 130.0, 0.0, 0.0), (0.2, 130.0), "no FROM/TO: the whole audible track")
        with self.assertRaises(SystemExit):
            import_music.section(0.2, 130.0, 100.0, 100.5)

    def test_a_real_track_retires_the_placeholders_it_replaces(self):
        manifest = {"tracks": {
            "fight": {"stems": [], "states": ["lull", "skirmish", "battle", "last_stand"], "placeholder": True},
            "garage": {"file": "g.ogg", "states": ["garage"], "placeholder": True},
            "treadmill": {"stems": [], "states": ["skirmish", "battle"]},
        }}
        self.assertEqual(import_music.retire_placeholders(manifest, "treadmill", ["skirmish", "battle"]), [])
        self.assertEqual(manifest["tracks"]["fight"]["states"], ["lull", "last_stand"], "the placeholder keeps the rest")
        self.assertEqual(import_music.retire_placeholders(manifest, "lull", ["lull"]), [])
        self.assertEqual(import_music.retire_placeholders(manifest, "last_stand", ["last_stand"]), ["fight"],
                         "and goes once a real track covers everything it did")
        self.assertIn("treadmill", manifest["tracks"], "a real track is never retired")

    def test_stems_that_do_not_line_up_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            manifest = json.loads((MUSIC / "manifest.json").read_text())
            name, fight = next((n, t) for n, t in manifest["tracks"].items() if "stems" in t)
            for stem in fight["stems"]:
                shutil.copy(MUSIC / stem["file"], tmp / stem["file"])
            short = tmp / fight["stems"][1]["file"]
            import subprocess
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(MUSIC / fight["stems"][1]["file"]), "-t", "4",
                            str(short)], check=True)
            problems = check_music.check_stems(tmp, name, fight, -16.0)
            self.assertTrue(any("differ in length" in p for p in problems), problems)


if __name__ == "__main__":
    unittest.main()
