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
    def test_every_line_is_recorded_as_whole_sentences(self):
        """Nothing is assembled at playback any more: each recording is a complete utterance with no slots left."""
        the_plan = recording_plan.plan(LINES)
        planned = set(the_plan["lines"]) | {r["id"] for r in the_plan["too_many"]}
        self.assertEqual(planned, {line["id"] for line in LINES["lines"]}, "every line is accounted for")
        for request in the_plan["requests"]:
            self.assertNotRegex(request["text"], r"\{[a-z_]+\}", "%s still has a slot in it" % request["id"])
            self.assertEqual(len(request["slices"]), 1, "%s is one piece" % request["id"])
            self.assertEqual(request["slices"][0]["kind"], "line")
            self.assertEqual(request["slices"][0]["text"], request["text"], "the slice is the whole sentence")

    def test_a_line_is_recorded_once_per_thing_it_can_say(self):
        the_plan = recording_plan.plan(LINES)
        for line in LINES["lines"]:
            info = the_plan["lines"].get(line["id"])
            if info is None:
                continue  # over the cap; covered below
            bases = recording_plan.line_bases(line["text"])
            if not bases:
                self.assertEqual(list(info["variants"]), [""], "%s has no slots, so one recording" % line["id"])
            else:
                self.assertGreater(len(info["variants"]), 1, "%s varies" % line["id"])
            for key, clip in info["variants"].items():
                self.assertEqual(clip, recording_plan.variant_clip(line["id"], key))

    def test_clip_ids_are_unique_across_the_whole_library(self):
        the_plan = recording_plan.plan(LINES)
        ids = [s["clip"] for r in the_plan["requests"] for s in r["slices"]]
        self.assertEqual(len(ids), len(set(ids)), "two recordings would overwrite each other")

    def test_a_line_naming_two_variable_things_is_refused_not_ordered(self):
        """676 recordings for one sentence is a writing bug. plan() reports it instead of spending the budget."""
        greedy = {"vocabulary": LINES["vocabulary"], "speakers": LINES["speakers"], "lines": [
            {"id": "caller.greedy.01", "speaker": "caller", "act": "call", "tags": ["kill"],
             "text": "{faction} takes out {other_faction} with the {killer_unit} and the {victim_unit}!"}]}
        the_plan = recording_plan.plan(greedy)
        self.assertEqual(the_plan["requests"], [], "nothing is ordered")
        self.assertEqual(len(the_plan["too_many"]), 1)
        self.assertGreater(the_plan["too_many"][0]["combinations"], recording_plan.MAX_COMBINATIONS)

    def test_a_match_is_never_a_faction_against_itself(self):
        """The lead, 2026-09-16: opponents are always different factions. Recording "the Law beats the Law" would
        be three quarters of the combinations of every line that names both sides."""
        pairs = {"vocabulary": LINES["vocabulary"], "speakers": LINES["speakers"], "lines": [
            {"id": "caller.pair.01", "speaker": "caller", "act": "call", "tags": ["kill"],
             "text": "{faction} beats {other_faction}!"}]}
        the_plan = recording_plan.plan(pairs)
        self.assertEqual(len(the_plan["requests"]), 4 * 3, "four factions against the other three")
        for request in the_plan["requests"]:
            mine, theirs = request["id"].split("@")[1].split(".")
            self.assertNotEqual(mine, theirs, request["id"])

    def test_the_variant_key_is_the_slot_values_in_a_fixed_order(self):
        """AnnouncerLibrary.variant_key in GDScript must agree with this exactly, or the game asks for clips that
        were never recorded. Sorted base-slot order is the contract."""
        self.assertEqual(recording_plan.variant_key({"faction": "law", "victim_unit": "tank"},
                                                    ["faction", "victim_unit"]), "law.tank")
        self.assertEqual(recording_plan.line_bases("{faction_s} {unit} and {faction_attr}"), ["faction", "unit"],
                         "possessive and attributive forms read the same underlying slot")
        self.assertEqual(recording_plan.variant_key({"count_over": 20}, ["count_over"]), "20",
                         "numbers are integers on both sides of the wire")

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
        self.assertNotIn("skipped until the voice exists", text, "all three voices exist (JR1, veteran, corporate2)")
        without_voice = {name: (dict(speaker, voice="") if name == "color" else speaker)
                         for name, speaker in LINES["speakers"].items()}
        with tempfile.TemporaryDirectory() as folder:
            missing = generate.dry_run(recording_plan.plan(LINES), without_voice, Path(folder), voice_client.MODEL_ID)
        self.assertIn("skipped until the voice exists", missing, "a speaker whose voice isn't made yet is called out")

    def test_the_real_client_needs_the_key_from_the_environment(self):
        with mock.patch.dict(os.environ, {name: "" for name in voice_client.KEY_ENVS}):
            with self.assertRaisesRegex(RuntimeError, voice_client.KEY_ENV):
                voice_client.RealClient()

    def test_either_environment_name_carries_the_key(self):
        for name in voice_client.KEY_ENVS:
            keys = {other: "" for other in voice_client.KEY_ENVS}
            keys[name] = "sk_example"
            with mock.patch.dict(os.environ, keys):
                self.assertEqual(voice_client.environment_key(), "sk_example", name)

    def test_a_key_id_is_refused_before_anything_is_sent(self):
        """The lead's ELEVENLABS_KEY_ID holds a key *id*; the API answers 'API key ID used as API key' (2026-09-16)."""
        keys = {name: "" for name in voice_client.KEY_ENVS}
        keys[voice_client.KEY_ENVS[1]] = "2a05" + "0" * 60
        with mock.patch.dict(os.environ, keys):
            with self.assertRaisesRegex(RuntimeError, "key .?id"):
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

    def test_every_recording_comes_out_at_the_same_level(self):
        """Clips play back to back, so a quiet one is audible as a dip. They are levelled to their own sentence,
        which for a whole sentence means they all land together."""
        ids = ["caller.kill.08", "caller.close.04", "color.army.07"]
        self.run_pipeline(sample_plan(ids), mock_client())
        manifest = json.loads((self.out / "manifest.json").read_text())
        levels = [generate.mean_volume_db(self.out / c["file"]) for c in manifest["clips"].values()]
        self.assertGreater(len(levels), 3, "several clips to compare")
        self.assertLess(max(levels) - min(levels), 3.0, "levels agree within 3 dB")

    def test_a_misheard_whole_line_still_fails_the_run(self):
        """A whole sentence is a complete utterance, so the recogniser can be trusted on it: a mispronunciation or
        a dropped word there is a real defect and must stop the run."""
        whole = [line for line in LINES["lines"] if line["id"] == "color.lore.01"] or LINES["lines"][:1]
        the_plan = sample_plan([whole[0]["id"]])
        clip_ids = [piece["clip"] for request in the_plan["requests"] for piece in request["slices"]
                    if piece["kind"] == "line"]
        self.assertTrue(clip_ids, "the sample plan has a whole-line clip to mishear")
        report = self.run_pipeline(the_plan, mock_client(mishear={clip_ids[0].replace("#", "-")}))
        self.assertIn(clip_ids[0], report["stt_failed"], "a misheard whole line is a hard failure")

    def test_a_dropped_connection_is_retried_not_fatal(self):
        """A read timeout killed a real run at 712 of 2,225 recordings. An hour-and-a-half paid run must survive
        the network hiccuping once."""
        self.assertTrue(voice_client.worth_retrying(RuntimeError("The read operation timed out")))
        self.assertTrue(voice_client.worth_retrying(type("E", (Exception,), {"status_code": 503})()))
        self.assertFalse(voice_client.worth_retrying(type("E", (Exception,), {"status_code": 400})()),
                         "a refusal cannot be fixed by asking again")
        self.assertFalse(voice_client.worth_retrying(RuntimeError("invalid_api_key")))
        calls = []

        def flaky():
            calls.append(1)
            if len(calls) < 3:
                raise RuntimeError("connection reset by peer")
            return "recorded"
        self.assertEqual(voice_client.with_retries(flaky, "clip", delays=(0.001, 0.001, 0.001)), "recorded")
        self.assertEqual(len(calls), 3, "it kept trying")

    def test_a_run_stops_before_it_passes_its_character_budget(self):
        """Round 10 generates in paid batches against a stop line (half the balance): a run is given a budget and
        records nothing that would take it past it, whatever the plan asks for."""
        the_plan = sample_plan(["caller.kill.08", "caller.close.04"])
        first = len(the_plan["requests"][0]["text"])
        report = generate.generate(the_plan, SPEAKERS, mock_client(), self.masters, self.out, voice_client.MODEL_ID,
                                   log=lambda *_: None, max_characters=first)
        self.assertEqual(report["requests_sent"], 1)
        self.assertEqual(report["characters"], first)
        self.assertEqual(report["over_budget"], len(the_plan["requests"]) - 1, "the rest are counted, not sent")

    def test_one_recording_that_never_comes_does_not_lose_the_others(self):
        """The run's job is to get audio recorded. Anything that is not recording must not be able to stop it —
        and every master already written stays written, so re-running costs nothing for them."""
        client = mock_client()
        real_speak = client.speak
        doomed = "the Burner"  # one realization the service never manages to return

        def sometimes(voice_id, text, previous_text=None, next_text=None):
            if doomed in text:
                raise RuntimeError("the read operation timed out")
            return real_speak(voice_id, text, previous_text, next_text)
        client.speak = sometimes
        with mock.patch.object(voice_client, "RETRY_DELAYS_S", (0.001,)):
            report = self.run_pipeline(sample_plan(["caller.kill.01", "color.flat.03"]), client)
        self.assertTrue(report["failed_requests"], "the ones that never came are reported by name")
        self.assertTrue(all(doomed in f["id"] or "burner" in f["id"] for f in report["failed_requests"]),
                        "and only those: %s" % [f["id"] for f in report["failed_requests"]])
        self.assertGreater(report["clips"], len(report["failed_requests"]),
                           "every other recording still landed")
        manifest = json.loads((self.out / "manifest.json").read_text())
        self.assertTrue(manifest["clips"], "and the manifest was still written")

    def test_a_refused_transcription_does_not_abandon_a_paid_run(self):
        """The recogniser rejects very short audio outright ("audio_too_short"). That killed a real run at 277 of
        581 clips - after the audio was recorded and paid for. A failing *check* must never throw away generation."""
        class Refusing:
            body = {"detail": {"status": "audio_too_short", "message": "Audio is too short."}}

        def refuse(_path):
            raise type("ApiError", (Exception,), {"body": Refusing.body})()

        client = mock_client()
        client.transcribe = refuse
        report = self.run_pipeline(sample_plan(["caller.kill.52"]), client)
        self.assertEqual(report["stt_failed"], [], "a refusal is not a failed clip")
        self.assertTrue(report["stt_unverifiable"], "it is reported as unverifiable instead")
        self.assertGreater(report["clips"], 0, "and the clips it recorded are still written")
        manifest = json.loads((self.out / "manifest.json").read_text())
        self.assertTrue(manifest["clips"], "the manifest is complete enough to play")


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

    def test_mixdown_places_one_whole_sentence_per_cue(self):
        ids = ["caller.kill.08"]
        self.run_pipeline(sample_plan(ids), mock_client())
        manifest = json.loads((self.out / "manifest.json").read_text())
        line = manifest["lines"]["caller.kill.08"]
        key = sorted(line["variants"])[0]
        match = {"cues": [
            {"t": 1.0, "end": 3.0, "line_id": "caller.kill.08", "variant_key": key, "cut": False},
            {"t": 5.0, "end": 5.2, "line_id": "caller.kill.08", "variant_key": key, "cut": True}]}
        self.assertEqual(mixdown.cue_clips(match["cues"][0], manifest), [line["variants"][key]],
                         "a cue is one recording, not a list of pieces to join")
        placed = mixdown.schedule(match, manifest)
        self.assertEqual([p["t"] for p in placed], [1.0, 5.0], "each cue starts at its own time")
        self.assertIsNone(placed[0]["max_s"], "an uncut cue plays whole")
        self.assertAlmostEqual(placed[1]["max_s"], 0.2, places=2, msg="a cut cue stops when it was cut")
        out = Path(self.folder.name) / "match.ogg"
        mixdown.render(placed, self.out, out, 7.0)
        self.assertTrue(out.exists() and out.stat().st_size > 0, "the mix was written")
        with self.assertRaisesRegex(KeyError, "no recording for"):
            mixdown.cue_clips(dict(match["cues"][0], variant_key="not.a.real.key"), manifest)

    def test_a_short_mix_is_reported_instead_of_shipped(self):
        """A mix that ends with its last clip plays out of sync with the transcript, so it must never pass quietly."""
        self.run_pipeline(sample_plan(["caller.kill.08"]), mock_client())
        manifest = json.loads((self.out / "manifest.json").read_text())
        key = sorted(manifest["lines"]["caller.kill.08"]["variants"])[0]
        match = {"cues": [{"t": 0.0, "end": 2.0, "line_id": "caller.kill.08", "variant_key": key, "cut": False}]}
        placed = mixdown.schedule(match, manifest)
        out = Path(self.folder.name) / "short.ogg"
        mixdown.render(placed, self.out, out, 6.0)
        self.assertAlmostEqual(mixdown.check_length(out, 6.0), 6.0,
                               msg="generated silence makes the mix the length the match asked for",
                               delta=mixdown.LENGTH_TOLERANCE_S)
        with self.assertRaisesRegex(RuntimeError, "out of sync"):
            mixdown.check_length(out, 30.0)


if __name__ == "__main__":
    unittest.main()
