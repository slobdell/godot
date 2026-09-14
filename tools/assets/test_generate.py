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

    def tearDown(self):
        self.out.cleanup()

    def run_cli(self, *args, key="test-key", env_name="MESHY_API_KEY"):
        env = {k: v for k, v in os.environ.items() if not k.endswith("_API_KEY")}
        if key is not None:
            env[env_name] = key
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(stdout), \
                contextlib.redirect_stderr(stderr):
            code = generate.main(["--out-dir", self.out.name, "--poll-interval", "0", "--timeout", "10", *args])
        return code, stdout.getvalue(), stderr.getvalue()

    def test_meshy_text_to_3d_previews_refines_and_downloads_the_glb_and_emission_map(self):
        code, out, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "tank.hull",
                                      "--prompt", "scrap tank hull", "--name", "hull")
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
                                    "--image", "https://example.com/crate.png", "--name", "crate")
        self.assertEqual(code, 0, err)
        paths = [path for method, path, _ in self.state.requests if method == "POST"]
        self.assertEqual(paths, ["/openapi/v1/image-to-3d"])
        self.assertTrue(Path(self.out.name, "crate.glb").exists())

    def test_missing_key_explains_how_to_turn_the_provider_on(self):
        code, _, err = self.run_cli("--provider", "meshy", "--slot", "tank.hull", "--prompt", "x", key=None)
        self.assertEqual(code, 3)
        self.assertIn("export MESHY_API_KEY", err)

    def test_failed_task_reports_the_provider_message(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--prompt", "please FAIL")
        self.assertEqual(code, 1)
        self.assertIn("FAILED: mock generation failed", err)
        self.assertEqual(list(Path(self.out.name).iterdir()), [], "nothing half-written is left behind")

    def test_rejected_key_and_no_credits_are_explained(self):
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--prompt", "crate", key="bad-key")
        self.assertEqual(code, 1)
        self.assertIn("API key was rejected", err)
        code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                    "--prompt", "crate", key="broke")
        self.assertIn("out of credits", err)

    def test_rate_limits_are_retried(self):
        with mock.patch.object(generate.time, "sleep"):
            code, _, err = self.run_cli("--provider", "meshy", "--base-url", self.base, "--slot", "prop.crate",
                                        "--prompt", "RATELIMIT crate", "--name", "retry")
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
                             "prop.wall": 3000, "arena.dressing": 50000, "kit.container": 1500}.items():
            self.assertEqual(generate.slot_budget(slot), budget, slot)


if __name__ == "__main__":
    unittest.main()
