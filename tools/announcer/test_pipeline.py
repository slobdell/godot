"""Announcer N4: the audio pipeline, proven against the mock voice client (no API calls, no credits)."""

import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import generate  # noqa: E402
import mixdown  # noqa: E402
import recording_plan  # noqa: E402
import voice_client  # noqa: E402

LINES = json.loads(generate.LINES.read_text())
SPEAKERS = {name: dict(s, voice=s.get("voice") or "mock-" + name) for name, s in LINES["speakers"].items()}
SAMPLE_IDS = ["caller.kill.08", "caller.close.04", "color.army.07", "color.banter.01", "pa.welcome.05"]


def sample_plan(ids=SAMPLE_IDS):
    return recording_plan.plan(LINES, only=set(ids))


def mock_client(**kwargs):
    return voice_client.MockClient(voices={s["voice"]: "id-" + s["voice"] for s in SPEAKERS.values()}, **kwargs)


class PlanTest(unittest.TestCase):
    def test_every_line_rebuilds_from_its_parts(self):
        the_plan = recording_plan.plan(LINES)
        slices = {s["clip"]: s["text"] for r in the_plan["requests"] for s in r["slices"]}
        for line in LINES["lines"]:
            parts = the_plan["lines"][line["id"]]["parts"]
            spoken = []
            for part in parts:
                if "clip" in part:
                    self.assertIn(part["clip"], slices)
                    self.assertNotRegex(slices[part["clip"]], r"^[ ,.!?;:]", "%s starts with punctuation" % part["clip"])
                    spoken.append(slices[part["clip"]])
                else:
                    self.assertIn(part["intonation"], ("mid", "final", "rising"))
                    spoken.append("{%s}" % part["slot"])
            words = lambda text: re.findall(r"\{[a-z_]+\}|[A-Za-z']+", text)
            self.assertEqual(words(" ".join(spoken)), words(line["text"]), line["id"])

    def test_fillers_cover_every_slot_value_and_intonation_used(self):
        the_plan = recording_plan.plan(LINES)
        for line_id, line in the_plan["lines"].items():
            for part in line["parts"]:
                if "slot" not in part:
                    continue
                values = recording_plan.vocabulary_values(LINES["vocabulary"], part["vocab"])
                for value in values:
                    clip = recording_plan.filler_clip(line["speaker"], part["vocab"], value, part["intonation"])
                    self.assertIn(clip, the_plan["fillers"], "%s needs %s" % (line_id, clip))

    def test_intonation_and_request_stitching(self):
        self.assertEqual(recording_plan.intonation_after("Is that {team}?", len("Is that {team}")), "rising")
        self.assertEqual(recording_plan.intonation_after("First blood goes to {team}!", len("First blood goes to {team}")), "final")
        self.assertEqual(recording_plan.intonation_after("{team} takes it", len("{team}")), "mid")
        answer = next(r for r in sample_plan()["requests"] if r["id"] == "color.banter.01")
        self.assertEqual(answer["previous_text"], "What's going through a driver's head right now?")

    def test_slices_pad_into_silence_but_never_into_the_next_word(self):
        client = mock_client()
        _, alignment = client.speak("id", "Rust takes the tank away!")
        start, end = len("Rust "), len("Rust takes the")
        t0, t1 = generate.slice_times(alignment, start, end)
        self.assertGreater(t0, alignment["character_end_times_seconds"][start - 2], "not into Rust")
        self.assertLess(t1, alignment["character_start_times_seconds"][end + 1], "not into tank")


class DryRunTest(unittest.TestCase):
    def test_dry_run_counts_and_sends_nothing(self):
        with mock.patch.object(voice_client, "RealClient", side_effect=AssertionError("no client in a dry run")):
            with tempfile.TemporaryDirectory() as folder:
                text = generate.dry_run(recording_plan.plan(LINES), LINES["speakers"], Path(folder), voice_client.MODEL_ID)
        self.assertIn("DRY RUN: nothing is sent", text)
        total = re.search(r"^total\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)", text, re.M)
        characters = sum(len(r["text"]) for r in recording_plan.plan(LINES)["requests"])
        self.assertEqual(int(total.group(3)), characters)
        self.assertIn("skipped until the voice exists", text, "the Veteran has no voice yet")

    def test_the_real_client_needs_the_key_from_the_environment(self):
        with mock.patch.dict(os.environ, {voice_client.KEY_ENV: ""}):
            with self.assertRaisesRegex(RuntimeError, voice_client.KEY_ENV):
                voice_client.RealClient()


class MockPipelineTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.out = Path(self.folder.name) / "clips"
        self.masters = Path(self.folder.name) / "masters"

    def tearDown(self):
        self.folder.cleanup()

    def run_pipeline(self, the_plan, client):
        return generate.generate(the_plan, SPEAKERS, client, self.masters, self.out, voice_client.MODEL_ID, log=lambda *_: None)

    def test_records_slices_checks_and_writes_a_manifest(self):
        the_plan = sample_plan(["caller.kill.08", "caller.close.04"])
        client = mock_client()
        report = self.run_pipeline(the_plan, client)
        manifest = json.loads((self.out / "manifest.json").read_text())
        self.assertEqual(report["stt_failed"], [])
        self.assertEqual(report["characters"], sum(len(r["text"]) for r in the_plan["requests"]))
        self.assertEqual(set(manifest["clips"]), {s["clip"] for r in the_plan["requests"] for s in r["slices"]})
        for clip, info in manifest["clips"].items():
            path = self.out / info["file"]
            self.assertTrue(path.exists(), clip)
            self.assertGreater(info["duration_s"], 0.05, clip)
            probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_name,channels", "-of", "csv=p=0", str(path)],
                                   capture_output=True, text=True).stdout.strip()
            self.assertEqual(probe, "vorbis,1", "%s is mono Ogg Vorbis" % clip)
        self.assertEqual(manifest["lines"]["caller.kill.08"], the_plan["lines"]["caller.kill.08"])
        # Idempotent: a second run sends nothing; a changed line re-records only itself.
        again = self.run_pipeline(the_plan, client)
        self.assertEqual((again["requests_sent"], again["skipped_existing"]), (0, len(the_plan["requests"])))
        edited = json.loads(json.dumps(the_plan))
        edited["requests"][0]["text"] = edited["requests"][0]["text"].replace("away", "away now")
        self.assertEqual(self.run_pipeline(edited, client)["requests_sent"], 1)

    def test_fillers_come_out_as_loud_as_the_sentences_around_them(self):
        self.run_pipeline(sample_plan(["caller.kill.52", "caller.kill.31"]), mock_client())
        manifest = json.loads((self.out / "manifest.json").read_text())

        def mean_volume(clip):
            log = subprocess.run(["ffmpeg", "-i", str(self.out / manifest["clips"][clip]["file"]), "-af", "volumedetect", "-f", "null", "-"],
                                 capture_output=True, text=True).stderr
            return float(re.search(r"mean_volume: (-?[\d.]+) dB", log).group(1))

        sentence = mean_volume("caller.kill.31")
        for clip in ["fill.caller.team.rust.mid", "fill.caller.number.2.final", "caller.kill.52#0"]:
            self.assertLess(abs(mean_volume(clip) - sentence), 3.0, "%s vs a whole sentence" % clip)

    def test_speech_to_text_flags_mishearing_and_bad_slices(self):
        the_plan = sample_plan(["pa.welcome.05"])
        self.assertEqual(self.run_pipeline(the_plan, mock_client(mishear={"pa.welcome.05-0"}))["stt_failed"], ["pa.welcome.05#0"])
        with mock.patch.object(generate, "slice_times", lambda alignment, start, end: (0.0, alignment["character_end_times_seconds"][-1] + 0.3)):
            the_plan = sample_plan(["caller.kill.08"])
            failed = self.run_pipeline(the_plan, mock_client())["stt_failed"]
        self.assertIn("caller.kill.08#0", failed, "a slice that swallows the neighboring words is caught")

    def test_missing_voices_are_skipped_not_guessed(self):
        client = voice_client.MockClient(voices={"JR1": "id"})
        report = self.run_pipeline(sample_plan(["caller.kill.08", "color.army.07"]), client)
        self.assertEqual(sorted(report["missing_voices"]), ["color"])

    def test_ledger_records_paid_runs_only(self):
        ledger = Path(self.folder.name) / "ledger.md"
        report = {"requests_sent": 0, "characters": 0, "credits_before": 10, "credits_after": 10}
        generate.append_ledger(ledger, report, "ElevenLabs", voice_client.MODEL_ID)
        self.assertFalse(ledger.exists(), "nothing sent, nothing logged")
        report.update(requests_sent=3, characters=120, credits_after=-110)
        generate.append_ledger(ledger, report, "ElevenLabs", voice_client.MODEL_ID, "pilot")
        self.assertIn("| ElevenLabs | eleven_multilingual_v2 | 3 | 120 | 120 | 10 → -110 | pilot |", ledger.read_text())

    def test_mixdown_places_parts_fillers_and_cuts(self):
        ids = ["caller.kill.52"]
        the_plan = sample_plan(ids)
        self.run_pipeline(the_plan, mock_client())
        manifest = json.loads((self.out / "manifest.json").read_text())
        match = {"cues": [
            {"t": 1.0, "end": 3.0, "line_id": "caller.kill.52", "slots": {"other_team": "rust", "count": 3.0}, "cut": False},
            {"t": 5.0, "end": 5.2, "line_id": "caller.kill.52", "slots": {"other_team": "green", "count": 2.0}, "cut": True}]}
        self.assertEqual(mixdown.cue_clips(match["cues"][0], manifest),
                         ["fill.caller.team.rust.mid", "caller.kill.52#0", "fill.caller.number.3.final"])
        placed = mixdown.schedule(match, manifest)
        cut = [p for p in placed if p["t"] >= 5.0]
        self.assertEqual(len(cut), 1, "a cut cue plays only what fits before its end")
        self.assertAlmostEqual(cut[0]["max_s"], 0.2, places=2)
        out = Path(self.folder.name) / "match.ogg"
        mixdown.render(placed, self.out, out, 7.0)
        self.assertAlmostEqual(voice_client.probe_duration(out), 7.0, delta=0.3)
        with self.assertRaisesRegex(KeyError, "fill.caller.number.9.final|needs clip"):
            broken = dict(match["cues"][0], slots={"other_team": "rust", "count": 99})
            mixdown.cue_clips(broken, manifest)


if __name__ == "__main__":
    unittest.main()
