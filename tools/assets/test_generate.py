#!/usr/bin/env python3
"""Tests for tools/assets/generate.py against the local mock provider (no network, no key).

    make assets-test        (or: python3 -m unittest discover -s tools/assets -p 'test_*.py')
"""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate  # noqa: E402
import mock_provider  # noqa: E402
import review  # noqa: E402


class GenerateAgainstMock(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server, cls.state = mock_provider.serve(0)
        cls.base = f"http://127.0.0.1:{cls.server.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        self.out = tempfile.TemporaryDirectory()
        self.state.requests.clear()
        self.ledger = Path(self.out.name, "review", "ledger.md")
        self.manifest = Path(self.out.name, "review", "review.json")

    def tearDown(self):
        self.out.cleanup()

    def run_cli(self, *args, key="test-key", env_name="MESHY_API_KEY"):
        env = {k: v for k, v in os.environ.items() if not k.endswith("_API_KEY")}
        if key is not None:
            env[env_name] = key
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(stdout), \
                contextlib.redirect_stderr(stderr):
            code = generate.main(["--out-dir", self.out.name, "--poll-interval", "0", "--timeout", "10",
                                  "--ledger", str(self.ledger), "--review-file", str(self.manifest), *args])
        return code, stdout.getvalue(), stderr.getvalue()

    def test_meshy_text_to_3d_previews_refines_and_downloads_the_glb_and_emission_map(self):
        code, out, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "tank.hull",
                                      "--prompt", "scrap tank hull", "--skip-review-gate", "--name", "hull")
        self.assertEqual(code, 0, err)
        glb = Path(self.out.name, "hull.glb").read_bytes()
        self.assertEqual(glb[:4], b"glTF", "the downloaded model is a binary glTF")
        self.assertTrue(Path(self.out.name, "hull.emission.png").exists(), "the emission map is kept for neon")
        posts = [body for method, path, body in self.state.requests if method == "POST"]
        self.assertEqual([p["mode"] for p in posts], ["preview", "refine"], "text-to-3D runs preview then refine")
        self.assertEqual(posts[0]["target_polycount"], int(8000 * generate.POLY_HEADROOM),
                         "the polygon target comes from the tank.hull budget in asset_contracts.gd")
        self.assertTrue(posts[1]["enable_pbr"] and posts[1]["ai_model"] == "meshy-6",
                        "refine asks for PBR on meshy-6, the only combination with an emission map")
        sidecar = json.loads(Path(self.out.name, "hull.json").read_text())
        self.assertEqual(sidecar["slot"], "tank.hull")
        self.assertIn("owns", sidecar["license_note"], "the sidecar records the output license terms")
        self.assertIn("make assets-inspect", out, "the CLI tells you the next pipeline step")

    def test_meshy_image_to_3d(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--image", "https://example.com/crate.png", "--skip-review-gate", "--name", "crate")
        self.assertEqual(code, 0, err)
        paths = [path for method, path, _ in self.state.requests if method == "POST"]
        self.assertEqual(paths, ["/openapi/v1/image-to-3d"])
        self.assertTrue(Path(self.out.name, "crate.glb").exists())

    def test_meshy_concept_then_smart_topology_unit_from_the_concept_task(self):
        code, out, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                      "--prompt", "scrap tank", "--concept-only", "--name", "tank")
        self.assertEqual(code, 0, err)
        self.assertTrue(Path(self.out.name, "tank.concept.png").exists(), "the concept image is saved for review")
        concept_id = json.loads(Path(self.out.name, "tank.concept.json").read_text())["task"]["id"]
        self.assertIn(f"--image-task {concept_id}", out, "the CLI prints how to continue from the concept")
        self.assertEqual([p for m, p, _ in self.state.requests if m == "POST"], ["/openapi/v1/text-to-image"],
                         "a concept costs one image task and no 3D task")
        self.assertTrue(self.state.requests[0][2]["remove_background"], "a model concept is cut out for 3D")
        self.state.requests.clear()
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--image-task", concept_id, "--smart-topology", "--skip-review-gate", "--name", "tank")
        self.assertEqual(code, 0, err)
        body = [b for m, p, b in self.state.requests if m == "POST"][0]
        self.assertEqual((body["input_task_id"], body["model_type"], body["ai_model"]), (concept_id, "smart-topology", "meshy-t2"))
        self.assertEqual(body["target_polycount"], int((8000 + 4000 + 2000) * generate.POLY_HEADROOM),
                         "a whole tank asks for the hull + turret + cannon budgets together")
        self.assertEqual(Path(self.out.name, "tank.glb").read_bytes()[:4], b"glTF")

    def test_meshy_turnaround_from_a_chosen_concept_then_multi_image_to_3d(self):
        chosen = Path(self.out.name, "chosen.png")
        chosen.write_bytes(mock_provider.PNG_1PX)
        code, out, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank", "--concept-only",
                                      "--reference", str(chosen), "--multi-view", "--prompt", "same tank, turnaround",
                                      "--name", "turn")
        self.assertEqual(code, 0, err)
        body = [b for m, p, b in self.state.requests if m == "POST"][0]
        self.assertTrue(body["reference_image_urls"][0].startswith("data:image/png"), "the chosen design is the reference")
        self.assertTrue(body["generate_multi_view"] and "aspect_ratio" not in body, "multi-view never sends aspect_ratio")
        views = sorted(p.name for p in Path(self.out.name).glob("turn.concept*.png"))
        self.assertEqual(views, ["turn.concept.png", "turn.concept1.png", "turn.concept2.png"], "every view is saved")
        turnaround = json.loads(Path(self.out.name, "turn.concept.json").read_text())["task"]["id"]
        self.state.requests.clear()
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank", "--multi-image",
                                    "--image-task", turnaround, "--ai-model", "meshy-7", "--ultra", "--polycount", "30000",
                                    "--skip-review-gate", "--name", "turn")
        self.assertEqual(code, 0, err)
        path, body = [(p, b) for m, p, b in self.state.requests if m == "POST"][0]
        self.assertEqual(path, "/openapi/v1/multi-image-to-3d")
        self.assertEqual((body["input_task_id"], body["ai_model"], body["ultra_mode"], body["target_polycount"]),
                         (turnaround, "meshy-7", True, 30000))
        self.assertTrue(Path(self.out.name, "turn.glb").exists())

    def test_local_reference_images_are_sent_as_data_uris(self):
        image = Path(self.out.name, "ref.png")
        image.write_bytes(mock_provider.PNG_1PX)
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--image", str(image), "--skip-review-gate", "--name", "crate2")
        self.assertEqual(code, 0, err)
        body = [b for m, p, b in self.state.requests if m == "POST"][0]
        self.assertTrue(body["image_url"].startswith("data:image/png;base64,"), "local files become data URIs")
        sidecar = json.loads(Path(self.out.name, "crate2.json").read_text())
        self.assertEqual(sidecar["image"], str(image), "the sidecar records the path, not megabytes of base64")

    def test_a_3d_request_needs_a_concept_the_lead_approved_and_is_never_sent_twice(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--prompt", "scrap tank", "--concept-only", "--name", "scout_a")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.posts(), ["/openapi/v1/text-to-image"])
        ledger = self.ledger.read_text()
        self.assertIn("text-to-image", ledger, "the concept request is in the spend ledger")
        manifest = review.load(self.manifest)
        review.add(manifest, "scout_a", Path(self.out.name, "scout_a.concept.json"), "X4", "unit.scout", "Scout A", 15,
                   "t2", image_dir=Path(self.out.name, "review", "images"))
        review.save(manifest, self.manifest)
        self.state.requests.clear()
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--smart-topology", "--image-task", "any", "--name", "scout")
        self.assertEqual((code, self.posts()), (1, []), "no review item: nothing is sent")
        self.assertIn("--review-item", err)
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--smart-topology", "--review-item", "scout_a", "--name", "scout")
        self.assertEqual((code, self.posts()), (1, []), "a concept still waiting for the lead is not sent to 3D")
        self.assertIn("waiting", err)
        with self.assertRaises(review.ReviewError, msg="an approval must quote the lead"):
            review.decide(manifest, "scout_a", "approved", "")
        review.decide(manifest, "scout_a", "approved", "love it")
        review.save(manifest, self.manifest)
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--smart-topology", "--review-item", "scout_a", "--name", "scout")
        self.assertEqual((code, self.posts()), (0, ["/openapi/v1/image-to-3d"]), err)
        body = [b for m, p, b in self.state.requests if m == "POST"][0]
        self.assertEqual(body["input_task_id"], review.find(manifest, "scout_a")["concept_task"],
                         "the approved concept is what goes to 3D")
        self.assertTrue(review.load(self.manifest)["items"][0]["model_task"], "the 3D task is recorded on the item")
        self.state.requests.clear()
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--smart-topology", "--review-item", "scout_a", "--name", "scout")
        self.assertEqual((code, self.posts()), (1, []), "the same concept is never sent to 3D twice")
        self.assertIn("already went to 3D", err)
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--smart-topology", "--review-item", "scout_a", "--image-task", "someone-else", "--name", "x",
                                    "--retry-reason", "test")
        self.assertEqual((code, self.posts()), (1, []), "an approval can't be borrowed for a different image")
        self.assertEqual(review.ledger_total(self.ledger), 0, "the mock reports no credits")
        self.assertEqual(self.ledger.read_text().count("| SUCCEEDED |"), 2, "one ledger row per finished task")

    def test_the_review_sheet_lists_waiting_concepts_with_prompts_and_estimates(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank",
                                    "--prompt", "armored <bus>", "--concept-only", "--name", "ifv_a")
        self.assertEqual(code, 0, err)
        manifest = review.load(self.manifest)
        review.add(manifest, "ifv_a", Path(self.out.name, "ifv_a.concept.json"), "X4 roster", "unit.ifv", "IFV A", 15,
                   "t2", image_dir=Path(self.out.name, "review", "images"))
        index = review.build(manifest, Path(self.out.name, "sheet"), self.ledger)
        page = index.read_text()
        self.assertIn("armored &lt;bus&gt;", page, "the prompt is shown, escaped")
        self.assertIn("≈15", page, "the sheet totals the 3D credits the waiting concepts would cost")
        self.assertTrue(Path(self.out.name, "sheet", "images", "ifv_a.jpg").exists() or
                        Path(self.out.name, "sheet", "images", "ifv_a.png").exists(), "the image travels with the sheet")

    def test_mood_art_keeps_its_background(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "unit.tank", "--concept-only",
                                    "--keep-background", "--prompt", "the whole arena at night", "--name", "arena")
        self.assertEqual(code, 0, err)
        self.assertFalse(self.state.requests[0][2]["remove_background"], "a scene would be erased by background removal")

    def posts(self):
        return [p for m, p, _ in self.state.requests if m == "POST"]

    def test_missing_key_explains_how_to_turn_the_provider_on(self):
        code, _, err = self.run_cli("--provider", "meshy", "--slot", "tank.hull", "--prompt", "x", key=None)
        self.assertEqual(code, 3)
        self.assertIn("export MESHY_API_KEY", err)

    def test_failed_task_reports_the_provider_message(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--prompt", "please FAIL", "--skip-review-gate")
        self.assertEqual(code, 1)
        self.assertIn("FAILED: mock generation failed", err)
        self.assertEqual(sorted(p.name for p in Path(self.out.name).iterdir()), ["review"], "nothing half-written is left behind")
        self.assertIn("| FAILED |", self.ledger.read_text(), "a failed task is still logged (at 0 credits)")

    def test_rejected_key_and_no_credits_are_explained(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--prompt", "crate", "--skip-review-gate", key="bad-key")
        self.assertEqual(code, 1)
        self.assertIn("API key was rejected", err)
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--prompt", "crate", "--skip-review-gate", key="broke")
        self.assertIn("out of credits", err)

    def test_rate_limits_are_retried(self):
        with mock.patch.object(generate.time, "sleep"):
            code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                        "--prompt", "RATELIMIT crate", "--skip-review-gate", "--name", "retry")
        self.assertEqual(code, 0, err)
        self.assertIn("rate limited", err)

    def test_tripo_text_to_model(self):
        code, _, err = self.run_cli("--provider", "tripo", "--base-url", self.base + "/v3", "--slot", "tank.turret",
                                    "--prompt", "turret", "--name", "turret", env_name="TRIPO_API_KEY")
        self.assertEqual(code, 0, err)
        posts = [body for method, path, body in self.state.requests if method == "POST"]
        self.assertEqual(posts[0]["face_limit"], int(4000 * generate.POLY_HEADROOM))
        self.assertEqual(Path(self.out.name, "turret.glb").read_bytes()[:4], b"glTF")

    def test_unknown_slot_is_rejected(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "tank.wings",
                                    "--prompt", "x")
        self.assertEqual(code, 1)
        self.assertIn("unknown slot", err)

    def test_every_contract_slot_has_a_readable_budget(self):
        for slot, budget in {"tank.hull": 8000, "tank.turret": 4000, "weapon.cannon": 2000, "fx.shell": 200,
                             "prop.wall": 3000, "arena.dressing": 50000, "kit.container": 1500, "unit.tank": 14000}.items():
            self.assertEqual(generate.slot_budget(slot), budget, slot)


if __name__ == "__main__":
    unittest.main()
