#!/usr/bin/env python3
"""Tests for tools/assets/review_page.py: the lead's pick-one-per-slot review page and applying what they tapped.

    make assets-test        (or: python3 -m unittest discover -s tools/assets -p 'test_*.py')
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review  # noqa: E402
import review_page  # noqa: E402


def item(item_id, group, status="waiting", est=15, notes="a tradeoff"):
    return {"id": item_id, "group": group, "target": f"unit.{group.lower()}", "title": f"{group}: option {item_id}",
            "prompt": "Photorealistic <concept>", "concept_task": f"task-{item_id}", "concept_credits": 9,
            "image": f"assets/review/images/{item_id}.jpg", "est_3d_credits": est, "mode_3d": "t2", "notes": notes,
            "status": status, "lead_words": "", "decided": "", "model_task": "", "references": []}


class ReviewPage(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.manifest = {"schema": 1, "group_notes": {"Scout": "Fast, fixed hood gun."}, "items": [
            item("scout_a", "Scout"), item("scout_b", "Scout"), item("ifv_a", "IFV"),
            item("mood", "Arena mood", est=0), item("old", "Scout", status="superseded"), item("done", "IFV", status="approved")]}

    def tearDown(self):
        self.tmp.cleanup()

    def test_the_page_groups_waiting_options_per_slot_with_approve_and_reject(self):
        index = review_page.build(self.manifest, self.dir / "page", "Concept review #2", ledger=self.dir / "ledger.md")
        page = index.read_text()
        self.assertEqual(page.count('<article class="card"'), 4, "every waiting concept is a card; decided and superseded ones aren't")
        self.assertLess(page.index("<h2>Scout</h2>"), page.index("<h2>IFV</h2>"), "groups keep the manifest's order")
        self.assertIn("2 options", page, "the options that compete for one slot sit together")
        self.assertIn("Fast, fixed hood gun.", page, "a group note explains the slot")
        self.assertIn("Photorealistic &lt;concept&gt;", page, "prompts are escaped")
        self.assertIn('data-decision="approved"', page)
        self.assertIn('db.doc("decisions/" + card.dataset.id)', page, "each tap is saved to the Artifact database")
        self.assertIn("Looks right", page, "a mood picture is judged, not approved for 3D")
        self.assertIn("2 if one per group", page, "the sheet states the 3D cost of one pick per slot")
        self.assertEqual(review_page.build(self.manifest, self.dir / "all", "x", include_decided=True,
                                           ledger=self.dir / "ledger.md").read_text().count('<article class="card"'), 5)

    def test_tapped_decisions_are_recorded_with_the_leads_words(self):
        saved = self.dir / "dump" / "decisions"
        saved.mkdir(parents=True)
        (saved / "scout_b.json").write_text(json.dumps({"decision": "approved", "words": "love the cage", "at": "2026-09-20T10:00:00Z"}))
        (saved / "scout_a.json").write_text(json.dumps({"decision": "rejected", "words": "", "at": "2026-09-20T10:01:00Z"}))
        (saved / "nobody.json").write_text(json.dumps({"decision": "approved", "words": "", "at": ""}))
        changed = review_page.apply(self.manifest, review_page.read_decisions(self.dir / "dump"), "https://example/page")
        self.assertEqual(sorted(c[0] for c in changed), ["scout_a", "scout_b"], "unknown ids are skipped")
        approved = review.find(self.manifest, "scout_b")
        self.assertEqual(approved["status"], "approved")
        self.assertIn("love the cage", approved["lead_words"], "the lead's own words are quoted")
        self.assertIn("https://example/page", approved["lead_words"], "and where they said it")
        self.assertEqual(review.gate_3d(self.manifest, "scout_b")["concept_task"], "task-scout_b",
                         "an approval from the page opens the 3D gate for that concept")
        with self.assertRaises(review.ReviewError):
            review.gate_3d(self.manifest, "scout_a")
        self.assertEqual(review_page.apply(self.manifest, review_page.read_decisions(self.dir / "dump"), "https://example/page"), [],
                         "applying the same taps twice changes nothing")


if __name__ == "__main__":
    unittest.main()
