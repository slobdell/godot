"""Round 5 X1: the sound-effect pipeline against the mock client (no API calls, no credits)."""

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
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
        # A sound is either synthesised (the layer goes under that transient) or new with no synth original, in which
        # case SfxSystem.ALIAS must name what it stands in for until its takes exist.
        alias = (ROOT / "game" / "theme" / "audio" / "sfx_system.gd").read_text()
        alias = alias[alias.index("const ALIAS := {"):]
        alias = set(re.findall(r'"([a-z_]+)":', alias[: alias.index("}")]))
        for source in data["sources"]:
            synth = (audio / ("%s.wav" % source["sound"])).exists()
            self.assertTrue(synth or source["sound"] in alias,
                            "%s layers under %s, which is neither synthesised nor aliased" % (source["id"], source["sound"]))
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

    def test_a_near_silent_master_is_refused_not_levelled_into_noise(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            data = recipe(takes=1)
            source = data["sources"][0]
            path = sfx_generate.master_path(tmp, source, 1)
            quiet = np.random.default_rng(1).standard_normal(sfx_layer.RATE) * 0.01  # peaks near -30 dBFS
            wav = tmp / "quiet.wav"
            sfx_layer.write_wav(wav, quiet)
            import subprocess
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), str(path)], check=True)
            with self.assertRaises(ValueError):
                sfx_layer.build_take(path, source, 1)

    def test_a_loop_is_a_wav_with_a_quiet_seam(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            data = recipe(id="loop", sound="mg_loop", takes=1, loop=True, duration_s=1.0)
            sfx_generate.generate(sfx_generate.plan(data, tmp), sfx_generate.MockClient(), log=lambda *_: None)
            source = data["sources"][0]
            mixed, report = sfx_layer.build_take(sfx_generate.master_path(tmp, source, 1), source, 1)
            self.assertLess(report["seam_jump"], 2.0, "no click at the loop point")
            self.assertEqual(sfx_layer.write_take(mixed, "mg_loop", 1, True, tmp).suffix, ".wav")

    def _loop_master(self, tmp, signal):
        data = recipe(id="loop", sound="mg_loop", takes=1, loop=True, duration_s=4.0)
        source = data["sources"][0]
        path = sfx_generate.master_path(tmp, source, 1)
        wav = tmp / "loop.wav"
        sfx_layer.write_wav(wav, signal)
        import subprocess
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), str(path)], check=True)
        return path, source

    def test_a_loop_starts_on_its_sound_not_on_the_generators_lead_in(self):
        # Round 6: loops were never onset-trimmed, so a take's quiet lead-in became a silence on every repeat.
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            rng = np.random.default_rng(2)
            burst = rng.standard_normal(sfx_layer.RATE * 3) * 0.3
            signal = np.concatenate([np.zeros(sfx_layer.RATE // 2), burst])
            path, source = self._loop_master(tmp, signal)
            mixed, _ = sfx_layer.build_take(path, source, 1)
            self.assertLess(sfx_layer.longest_dip(mixed), 0.05, "the half-second lead-in is gone")

    def test_a_loop_never_ships_a_hole(self):
        # Round 6: the Syndicate's plasma loop shipped with a 750 ms silence every 2.2 s: the gun stutters. A take with
        # a hole loops its longest unbroken stretch, and is refused when none is long enough.
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            rng = np.random.default_rng(3)
            long_run = rng.standard_normal(int(sfx_layer.RATE * 2.0)) * 0.3
            short_run = rng.standard_normal(int(sfx_layer.RATE * 0.8)) * 0.3
            gap = np.zeros(int(sfx_layer.RATE * 0.6))
            path, source = self._loop_master(tmp, np.concatenate([short_run, gap, long_run]))
            mixed, _ = sfx_layer.build_take(path, source, 1)
            self.assertLess(sfx_layer.longest_dip(mixed), sfx_layer.MAX_LOOP_DIP_S, "no hole in what ships")
            self.assertGreater(len(mixed) / sfx_layer.RATE, 1.8, "the long unbroken stretch is the loop")
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            rng = np.random.default_rng(4)
            bits = [rng.standard_normal(int(sfx_layer.RATE * 0.5)) * 0.3, np.zeros(int(sfx_layer.RATE * 0.6))] * 4
            path, source = self._loop_master(tmp, np.concatenate(bits))
            with self.assertRaises(ValueError):
                sfx_layer.build_take(path, source, 1)

    def test_loops_are_forced_to_import_uncompressed(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            for name in ("mg_loop_1.wav", "tank_boom_1.wav"):
                (tmp / name).write_bytes(b"")
                (tmp / (name + ".import")).write_text("[params]\ncompress/mode=2\n")
            self.assertEqual(len(sfx_layer.keep_loops_uncompressed(tmp)), 1)
            self.assertIn("compress/mode=0", (tmp / "mg_loop_1.wav.import").read_text())
            self.assertIn("compress/mode=2", (tmp / "tank_boom_1.wav.import").read_text(), "one-shots stay QOA")

    def test_a_loop_named_after_its_sound_still_imports_uncompressed(self):
        # Round 7: the crowd's bed is a loop called crowd_murmur, not *loop*: the recipe says which sounds loop.
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            for name in ("crowd_murmur_1.wav", "crowd_cheer_1.wav"):
                (tmp / name).write_bytes(b"")
                (tmp / (name + ".import")).write_text("[params]\ncompress/mode=2\n")
            self.assertEqual(len(sfx_layer.keep_loops_uncompressed(tmp, {"crowd_murmur"})), 1)
            self.assertIn("compress/mode=0", (tmp / "crowd_murmur_1.wav.import").read_text())
            self.assertIn("compress/mode=2", (tmp / "crowd_cheer_1.wav.import").read_text())
            self.assertEqual(sfx_layer.loop_sounds({"sources": [{"sound": "crowd_murmur", "loop": True},
                                                                 {"sound": "crowd_cheer"}]}), {"crowd_murmur"})

    def test_a_bed_can_be_ridden_to_a_steady_level(self):
        # Round 7: the generated crowd bed swelled 8 dB over 19 s though the prompt asked for a constant level, and
        # CrowdVoice already sets the murmur's level from the match: a bed's own swell fights it. layer.level_s rides
        # the gain over that window (the slow drift goes, anything faster stays).
        rng = np.random.default_rng(6)
        rate = sfx_layer.RATE
        t = np.arange(rate * 16) / rate
        swell = 10 ** ((-4 + 4 * np.sin(2 * np.pi * t / 16)) / 20)
        chatter = 1 + 0.5 * (np.sin(2 * np.pi * 3 * t) > 0.9)  # a fast shout every third of a second
        x = rng.standard_normal(len(t)) * 0.1 * swell * chatter

        def spread(y, window_s):
            n = int(rate * window_s)
            levels = [20 * np.log10(np.sqrt((y[i:i + n] ** 2).mean())) for i in range(0, len(y) - n + 1, n)]
            return max(levels) - min(levels)

        ridden = sfx_layer.ride_level(x, 2.0)
        self.assertGreater(spread(x, 1.0), 7.0)
        self.assertLess(spread(ridden, 1.0), 2.0, "the slow swell is gone")
        self.assertGreater(spread(ridden, 0.05), 3.0, "the fast shouts are still there")

    def test_a_bed_takes_a_long_seam(self):
        # A crowd bed's texture changes over seconds: a 30 ms splice is audible as a jump in the room, so a source may
        # ask for a longer crossfade (layer.seam_s). The loop is shorter by exactly the overlap.
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            rng = np.random.default_rng(5)
            path, source = self._loop_master(tmp, rng.standard_normal(sfx_layer.RATE * 4) * 0.3)
            short, _ = sfx_layer.build_take(path, source, 1)
            source = dict(source, layer={"seam_s": 0.5})
            long, _ = sfx_layer.build_take(path, source, 1)
            self.assertEqual(len(short) - len(long), int(0.5 * sfx_layer.RATE) - int(0.03 * sfx_layer.RATE))

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
