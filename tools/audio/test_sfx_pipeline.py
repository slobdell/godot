"""Round 5 X1: the sound-effect pipeline against the mock client (no API calls, no credits)."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sfx_generate  # noqa: E402
import sfx_layer  # noqa: E402


def recipe(**overrides):
    source = {"id": "test_boom", "sound": "tank_boom", "prompt": "a boom", "duration_s": 1.0, "takes": 2}
    source.update(overrides)
    return {"sources": [source]}


class RecipeTest(unittest.TestCase):
    def test_the_shipped_recipes_are_valid(self):
        data = sfx_generate.load_sources()
        self.assertTrue(any(s.get("pilot") for s in data["sources"]), "a pilot is marked")
        audio = sfx_layer.AUDIO
        for source in data["sources"]:
            self.assertTrue((audio / ("%s.wav" % source["sound"])).exists(),
                            "%s layers under %s, a sound that exists" % (source["id"], source["sound"]))
            unknown = set(source.get("layer", {})) - set(sfx_layer.DEFAULTS)
            self.assertFalse(unknown, "%s has no misspelt layer settings" % source["id"])

    def test_bad_recipes_are_refused_before_anything_is_sent(self):
        self.assertTrue(sfx_generate.validate(recipe(duration_s=45.0)), "the API's 30 s ceiling")
        self.assertTrue(sfx_generate.validate(recipe(takes=0)))
        twice = recipe()
        twice["sources"].append(dict(twice["sources"][0]))
        self.assertTrue(sfx_generate.validate(twice), "a duplicated id")
        self.assertEqual(sfx_generate.validate(recipe()), [])

    def test_an_edited_prompt_is_a_new_master_and_an_unchanged_one_is_not(self):
        source = recipe()["sources"][0]
        same = sfx_generate.master_path(Path("m"), source, 1)
        self.assertEqual(same, sfx_generate.master_path(Path("m"), dict(source), 1))
        self.assertNotEqual(same, sfx_generate.master_path(Path("m"), dict(source, prompt="a bigger boom"), 1))
        self.assertNotEqual(same, sfx_generate.master_path(Path("m"), source, 2), "each take is its own request")

    def test_the_pilot_and_only_filters(self):
        data = {"sources": [dict(recipe()["sources"][0], pilot=True),
                            dict(recipe()["sources"][0], id="other", sound="mg_loop", takes=1)]}
        self.assertEqual(len(sfx_generate.requests(data, pilot=True)), 2)
        self.assertEqual(len(sfx_generate.requests(data, only={"mg_loop"})), 1, "--only takes an SfxSystem sound")


class GenerateAndLayerTest(unittest.TestCase):
    def test_mock_generation_skips_what_exists_and_layers_into_a_mastered_take(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            data = recipe(layer={"tail_lift_db": 8.0})
            client = sfx_generate.MockClient()
            first = sfx_generate.generate(sfx_generate.plan(data, tmp / "masters"), client, log=lambda *_: None)
            self.assertEqual(first["requests"], 2)
            again = sfx_generate.plan(data, tmp / "masters")
            self.assertEqual(len(again["todo"]), 0, "a finished take is never paid for twice")

            source = data["sources"][0]
            mixed, report = sfx_layer.build_take(sfx_generate.master_path(tmp / "masters", source, 1), source, 1)
            self.assertLessEqual(report["peak_db"], sfx_layer.CEILING_DB + 0.05, "limited")
            self.assertLess(abs(report["loudness_db"] - report["target_db"]), 1.5, "as loud as the sound it replaces")
            onset = np.argmax(np.abs(mixed) > np.abs(mixed).max() * 0.1) / sfx_layer.RATE
            self.assertLess(onset, 0.02, "starts on the muzzle flash, not 30 ms after it (%.3f s)" % onset)
            self.assertLess(abs(mixed[-50:]).max(), 0.01, "the tail fades out rather than stopping dead")
            path = sfx_layer.write_take(mixed, "tank_boom", 1, False, tmp / "layered")
            self.assertEqual(path.suffix, ".wav", "WAV, not Ogg: an Ogg one-shot costs a decoder per shot")

    def test_a_loop_is_a_wav_with_a_quiet_seam(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            data = recipe(id="loop", sound="mg_loop", takes=1, loop=True, duration_s=1.0)
            sfx_generate.generate(sfx_generate.plan(data, tmp), sfx_generate.MockClient(), log=lambda *_: None)
            source = data["sources"][0]
            mixed, report = sfx_layer.build_take(sfx_generate.master_path(tmp, source, 1), source, 1)
            self.assertLess(report["seam_jump"], 2.0, "no click at the loop point")
            self.assertEqual(sfx_layer.write_take(mixed, "mg_loop", 1, True, tmp).suffix, ".wav")

    def test_loops_are_forced_to_import_uncompressed(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            for name in ("mg_loop_1.wav", "tank_boom_1.wav"):
                (tmp / name).write_bytes(b"")
                (tmp / (name + ".import")).write_text("[params]\ncompress/mode=2\n")
            self.assertEqual(len(sfx_layer.keep_loops_uncompressed(tmp)), 1)
            self.assertIn("compress/mode=0", (tmp / "mg_loop_1.wav.import").read_text())
            self.assertIn("compress/mode=2", (tmp / "tank_boom_1.wav.import").read_text(), "one-shots stay QOA")

    def test_the_tail_lift_raises_the_decay_and_not_the_hit(self):
        rate = sfx_layer.RATE
        t = np.arange(rate * 2) / rate
        boom = np.sin(2 * np.pi * 300 * t) * np.exp(-t * 8)
        lifted = sfx_layer.lift_tail(boom, 12.0)
        self.assertAlmostEqual(np.abs(lifted[: rate // 20]).max(), np.abs(boom[: rate // 20]).max(), places=3)
        self.assertGreater(np.abs(lifted[rate:]).max(), np.abs(boom[rate:]).max() * 3.0)

    def test_the_manifest_lists_takes_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            for name in ("a_2.ogg", "a_1.ogg", "a_10.ogg", "b_loop_1.wav", "a_1.ogg.import"):
                (tmp / name).write_bytes(b"")
            pools = sfx_layer.existing_pools(tmp)
            self.assertEqual([Path(p).name for p in pools["a"]], ["a_1.ogg", "a_2.ogg", "a_10.ogg"])
            self.assertIn("b_loop", pools)
            sfx_layer.write_manifest(pools, tmp / "m.gd")
            self.assertIn('"res://assets/audio/layered/a_1.ogg"', (tmp / "m.gd").read_text())


if __name__ == "__main__":
    unittest.main()
