#!/usr/bin/env python3
"""Tests for tools/assets/concept_batch.py: many concepts from one committed spec, generated in parallel, registered once.

    make assets-test        (or: python3 -m unittest discover -s tools/assets -p 'test_*.py')
"""

import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import concept_batch  # noqa: E402
import review  # noqa: E402

SPEC = {
    "name": "test batch",
    "tail": "Full vehicle in frame, isolated on a plain dark grey studio background, no ground, no people, no text, no logos.",
    "est_3d": 15,
    "factions": {
        "gangs": {
            "label": "Road gangs",
            "lead": "Photorealistic concept art of an arena {role}, built by a road gang.",
            "look": "Rusted but loved: chrome engines.",
            "roles": {"scout": "fast scout buggy", "tank": "heavy war rig"},
            "role_notes": {"tank": "The fuel-truck war rig."},
            "concepts": [
                {"id": "gangs_scout_a", "role": "scout", "title": "stripped dune buggy", "subject": "A stripped buggy.",
                 "notes": "Tiny and fast."},
                {"id": "gangs_tank_a", "role": "tank", "title": "semi tanker", "subject": "A semi tanker.", "notes": "Long.",
                 "tail": "Custom tail, no text."},
            ],
        },
        "law": {
            "label": "The Law",
            "lead": "Photorealistic concept art of a police {role}.",
            "look": "Neglected.",
            "roles": {"scout": "pursuit cruiser"},
            "concepts": [{"id": "law_scout_a", "role": "scout", "title": "sedan", "subject": "A sedan.", "notes": "n"}],
        },
    },
}


class ConceptBatch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.incoming = self.dir / "incoming"
        self.manifest_path = self.dir / "review" / "review.json"

    def tearDown(self):
        self.tmp.cleanup()

    def fake_generate(self, calls):
        lock = threading.Lock()

        def run(concept):
            with lock:
                calls.append(concept["id"])
            base = self.incoming / "meshy"
            base.mkdir(parents=True, exist_ok=True)
            from PIL import Image
            Image.new("RGBA", (64, 64), (200, 10, 10, 255)).save(base / f"{concept['id']}.concept.png")
            (base / f"{concept['id']}.concept.json").write_text(json.dumps(
                {"prompt": concept["prompt"], "task": {"id": "task-" + concept["id"], "type": "text-to-image", "consumed_credits": 9}}))
            return 0
        return run

    def test_prompts_follow_the_faction_skeleton_and_every_one_ends_with_the_no_text_tail(self):
        concepts = concept_batch.expand(SPEC)
        self.assertEqual([c["id"] for c in concepts], ["gangs_scout_a", "gangs_tank_a", "law_scout_a"])
        scout = concepts[0]
        self.assertTrue(scout["prompt"].startswith("Photorealistic concept art of an arena fast scout buggy, built by a road gang."),
                        "the faction's lead sentence names the role")
        self.assertIn("A stripped buggy. Rusted but loved: chrome engines.", scout["prompt"], "subject, then the faction's look")
        self.assertTrue(scout["prompt"].endswith("no text, no logos."), "the shared tail keeps text out of generated images")
        self.assertTrue(concepts[1]["prompt"].endswith("Custom tail, no text."), "a concept may override the tail")
        self.assertEqual(scout["group"], "Road gangs · Scout", "options compete per faction and role")
        self.assertEqual(scout["target"], "unit.gangs.scout", "K4 slot ids")
        self.assertEqual(scout["title"], "Scout A: stripped dune buggy")
        self.assertEqual(concept_batch.group_notes(SPEC), {"Road gangs · Tank": "The fuel-truck war rig."})

    def test_ids_must_be_unique_and_roles_known(self):
        bad = json.loads(json.dumps(SPEC))
        bad["factions"]["law"]["concepts"].append(dict(bad["factions"]["law"]["concepts"][0]))
        with self.assertRaises(concept_batch.BatchError):
            concept_batch.expand(bad)
        bad = json.loads(json.dumps(SPEC))
        bad["factions"]["law"]["concepts"][0]["role"] = "boat"
        with self.assertRaises(concept_batch.BatchError):
            concept_batch.expand(bad)

    def test_a_run_generates_only_missing_concepts_and_registers_each_once(self):
        calls = []
        done = concept_batch.run(SPEC, self.manifest_path, self.incoming, generate=self.fake_generate(calls), jobs=3,
                                 only={"gangs"})
        self.assertEqual(sorted(calls), ["gangs_scout_a", "gangs_tank_a"], "--only limits the run to a faction")
        manifest = review.load(self.manifest_path)
        self.assertEqual([i["id"] for i in manifest["items"]], ["gangs_scout_a", "gangs_tank_a"], "registered in spec order")
        self.assertEqual(manifest["items"][0]["group"], "Road gangs · Scout")
        self.assertEqual(manifest["group_notes"]["Road gangs · Tank"], "The fuel-truck war rig.")
        self.assertEqual(done, ["gangs_scout_a", "gangs_tank_a"])
        calls.clear()
        again = concept_batch.run(SPEC, self.manifest_path, self.incoming, generate=self.fake_generate(calls), jobs=3)
        self.assertEqual(calls, ["law_scout_a"], "a concept already registered is never paid for twice")
        self.assertEqual(again, ["law_scout_a"])

    def test_a_downloaded_but_unregistered_concept_is_registered_without_regenerating(self):
        calls = []
        concept_batch.run(SPEC, self.manifest_path, self.incoming, generate=self.fake_generate(calls), jobs=1, only={"law"})
        manifest = review.load(self.manifest_path)
        manifest["items"] = []
        review.save(manifest, self.manifest_path)
        calls.clear()
        concept_batch.run(SPEC, self.manifest_path, self.incoming, generate=self.fake_generate(calls), jobs=1, only={"law"})
        self.assertEqual(calls, [], "the image on disk is reused (a crash between download and register costs nothing)")
        self.assertEqual(len(review.load(self.manifest_path)["items"]), 1)

    def test_a_failed_generation_is_reported_and_not_registered(self):
        def failing(concept):
            return 1
        done = concept_batch.run(SPEC, self.manifest_path, self.incoming, generate=failing, jobs=2, only={"law"})
        self.assertEqual(done, [])
        self.assertEqual(review.load(self.manifest_path)["items"], [])


if __name__ == "__main__":
    unittest.main()
