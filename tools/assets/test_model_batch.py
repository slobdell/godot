#!/usr/bin/env python3
"""Tests for tools/assets/model_batch.py: approved concepts, and only those, go to image-to-3D once each."""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import model_batch  # noqa: E402
import review  # noqa: E402


def item(item_id, group, status, model_task=""):
    return {"id": item_id, "group": group, "target": "unit.gangs.tank", "status": status, "model_task": model_task,
            "concept_task": "task-" + item_id, "source_png": f"assets/incoming/meshy/{item_id}.concept.png",
            "image": f"assets/review/images/{item_id}.jpg"}


class ModelBatch(unittest.TestCase):
    def setUp(self):
        self.manifest = {"schema": 1, "items": [
            item("gangs_tank_a", "Road gangs · Tank", "approved"),
            item("gangs_tank_b", "Road gangs · Tank", "rejected"),
            item("gangs_scout_a", "Road gangs · Scout", "waiting"),
            item("gangs_ifv_a", "Road gangs · IFV", "approved", model_task="done-1"),
            item("law_tank_a", "The Law · Tank", "approved"),
            item("wreck_a", "Arena kit · Wreck", "approved"),
            dict(item("arena_key_b", "Arena mood", "approved"), est_3d_credits=0)]}

    def test_only_approved_concepts_without_a_model_are_sent(self):
        todo = model_batch.pending(self.manifest)
        self.assertEqual([i["id"] for i in todo], ["gangs_tank_a", "law_tank_a", "wreck_a"],
                         "waiting and rejected concepts never go to 3D; one already built isn't paid for twice")
        self.assertEqual([i["id"] for i in model_batch.pending(self.manifest, "Road gangs")], ["gangs_tank_a"])
        self.assertEqual([i["id"] for i in model_batch.pending(self.manifest, skip={"wreck_a"})], ["gangs_tank_a", "law_tank_a"],
                         "an approved concept can be held back (a second wreck isn't worth the credits)")
        self.assertEqual([i["id"] for i in model_batch.pending(self.manifest, only={"wreck_a"})], ["wreck_a"])

    def test_the_command_names_the_review_item_and_prefers_the_cut_out_concept(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "assets/incoming/meshy").mkdir(parents=True)
            (root / "assets/incoming/meshy/gangs_tank_a.concept.png").write_bytes(b"png")
            cmd = model_batch.command(item("gangs_tank_a", "Road gangs · Tank", "approved"), root)
            self.assertIn("--review-item", cmd)
            self.assertEqual(cmd[cmd.index("--review-item") + 1], "gangs_tank_a")
            self.assertIn("--smart-topology", cmd)
            self.assertEqual(cmd[cmd.index("--image") + 1], str(root / "assets/incoming/meshy/gangs_tank_a.concept.png"),
                             "the background-removed concept (Meshy concept tasks expire after ~3 days)")
            other = model_batch.command(item("law_tank_a", "The Law · Tank", "approved"), root)
            self.assertEqual(other[other.index("--image") + 1], str(root / "assets/review/images/law_tank_a.jpg"),
                             "without the raw download, the committed review image")
            self.assertEqual(other[other.index("--name") + 1], "meshy/law_tank_a_t2")


if __name__ == "__main__":
    unittest.main()
