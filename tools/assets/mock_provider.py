#!/usr/bin/env python3
"""Local mock of the Meshy and Tripo APIs, for testing tools/assets/generate.py with no network or key.

    python3 tools/assets/mock_provider.py 8799      # then: generate.py --base-url http://127.0.0.1:8799 ...
    MESHY_API_KEY=anything tools/assets/generate.py --provider meshy --base-url http://127.0.0.1:8799 --slot prop.crate --prompt crate

Follows the request/response shapes in _agents/streams/references/asset_services.md (Appendix A/B).
Tasks advance one status per poll (PENDING → IN_PROGRESS → SUCCEEDED) and serve a small box GLB.
Scripted failures, for tests:
    API key "bad-key"          → 401            API key "broke" → 402 (out of credits)
    prompt containing "FAIL"   → task FAILED     prompt containing "RATELIMIT" → one 429 before accepting
Meshy lives under /openapi/..., Tripo under /v3/... on the same server.
"""

import itertools
import json
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from glb_fixture import box_glb  # noqa: E402

PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000d49444154789c6360f8cf00000301010018dd8db40000000049454e44ae426082")


class MockState:
    def __init__(self):
        self.tasks = {}
        self.ids = itertools.count(1)
        self.rate_limited = set()
        self.requests = []  # (method, path, body) for assertions
        self.lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    state: MockState = None  # set by serve()

    def log_message(self, *args):
        pass

    # ---- plumbing ----
    def _send(self, code, payload=None, content_type="application/json", headers=None):
        body = payload if isinstance(payload, bytes) else json.dumps(payload or {}).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def _auth(self) -> bool:
        header = self.headers.get("Authorization", "")
        if not header.startswith("Bearer ") or header == "Bearer bad-key":
            self._send(401, {"message": "Invalid API key"})
            return False
        if header == "Bearer broke":
            self._send(402, {"message": "Insufficient credits"})
            return False
        return True

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(length) or b"{}") if length else {}

    def _base(self) -> str:
        return f"http://{self.headers.get('Host')}"

    # ---- routes ----
    def do_GET(self):
        if self.path.startswith("/files/"):
            name = self.path.rsplit("/", 1)[1]
            if name.endswith(".glb"):
                return self._send(200, box_glb(size=(20.0, 9.0, 30.0), material_name="Main", emissive=(0.0, 0.8, 1.0)),
                                  "model/gltf-binary")
            return self._send(200, PNG_1PX, "image/png")
        if not self._auth():
            return
        self.state.requests.append(("GET", self.path, None))
        meshy = re.fullmatch(r"/openapi/v[12]/(text-to-3d|image-to-3d|remesh|text-to-image|image-to-image|multi-image-to-3d)/([\w-]+)", self.path)
        tripo = re.fullmatch(r"/v3/tasks/([\w-]+)", self.path)
        task_id = meshy.group(2) if meshy else tripo.group(1) if tripo else None
        with self.state.lock:
            task = self.state.tasks.get(task_id)
            if task is None:
                return self._send(404, {"message": "Task not found"})
            self._advance(task)
            view = dict(task["view"])
        if task["api"] == "tripo":
            return self._send(200, {"code": 0, "data": view})
        return self._send(200, view)

    def do_POST(self):
        if not self._auth():
            return
        body = self._body()
        self.state.requests.append(("POST", self.path, body))
        prompt = str(body.get("prompt", "") or body.get("texture_prompt", "") or "")
        if "RATELIMIT" in prompt and prompt not in self.state.rate_limited:
            self.state.rate_limited.add(prompt)
            return self._send(429, {"message": "RateLimitExceeded"}, headers={"Retry-After": "0"})
        if self.path in ("/openapi/v2/text-to-3d", "/openapi/v1/image-to-3d", "/openapi/v1/remesh", "/openapi/v1/text-to-image",
                         "/openapi/v1/image-to-image", "/openapi/v1/multi-image-to-3d"):
            return self._create_meshy(body, prompt)
        if self.path == "/v3/generation/text-to-model":
            if not prompt:
                return self._send(400, {"code": 2002, "message": "prompt is required"})
            return self._create_tripo(prompt)
        self._send(404, {"message": "no such endpoint"})

    def _create_meshy(self, body: dict, prompt: str):
        family = self.path.rsplit("/", 1)[1]
        if family == "text-to-3d":
            mode = body.get("mode")
            if mode == "preview" and not prompt:
                return self._send(400, {"message": "prompt is required"})
            if mode == "refine":
                preview = self.state.tasks.get(body.get("preview_task_id"))
                if preview is None or preview["view"]["status"] != "SUCCEEDED":
                    return self._send(400, {"message": "preview_task_id must be a SUCCEEDED preview task"})
                prompt = preview["prompt"]
            elif mode != "preview":
                return self._send(400, {"message": "mode must be preview or refine"})
        elif family == "image-to-3d":
            source = self.state.tasks.get(body.get("input_task_id", ""))
            if not body.get("image_url") and (source is None or source["view"]["status"] != "SUCCEEDED"):
                return self._send(400, {"message": "image_url or a SUCCEEDED input_task_id is required"})
            if body.get("model_type") == "smart-topology" and body.get("target_polycount", 0) > 15000:
                return self._send(400, {"message": "target_polycount must be 100-15000 for smart-topology"})
        elif family in ("text-to-image", "image-to-image") and (not prompt or not body.get("ai_model")):
            return self._send(400, {"message": "ai_model and prompt are required"})
        elif family == "image-to-image" and not 1 <= len(body.get("reference_image_urls") or []) <= 5:
            return self._send(400, {"message": "reference_image_urls must have 1-5 images"})
        elif family == "multi-image-to-3d":
            source = self.state.tasks.get(body.get("input_task_id", ""))
            if not 1 <= len(body.get("image_urls") or []) <= 4 and (source is None or source["view"]["status"] != "SUCCEEDED"):
                return self._send(400, {"message": "image_urls (1-4) or a SUCCEEDED input_task_id is required"})
        if body.get("generate_multi_view") and body.get("aspect_ratio"):
            return self._send(400, {"message": "generate_multi_view is incompatible with aspect_ratio"})
        with self.state.lock:
            task_id = f"mock-{next(self.state.ids):04d}"
            kind = f"text-to-3d-{body.get('mode')}" if family == "text-to-3d" else family
            image_like = family in ("text-to-image", "image-to-image")
            views = 3 if body.get("generate_multi_view") else 1
            refine_like = kind in ("text-to-3d-refine", "image-to-3d", "multi-image-to-3d")
            self.state.tasks[task_id] = {"api": "meshy", "prompt": prompt, "polls": 0, "pbr": body.get("enable_pbr"),
                                         "refine_like": refine_like, "image_like": image_like, "views": views, "view": {
                "id": task_id, "type": kind, "status": "PENDING", "progress": 0, "prompt": prompt,
                "model_urls": {}, "texture_urls": [], "task_error": None, "created_at": 1}}
        self._send(200, {"result": task_id})

    def _create_tripo(self, prompt: str):
        with self.state.lock:
            task_id = f"tripo-{next(self.state.ids):04d}"
            self.state.tasks[task_id] = {"api": "tripo", "prompt": prompt, "polls": 0, "view": {
                "task_id": task_id, "type": "text_to_model", "status": "queued", "progress": 0, "output": {}}}
        self._send(200, {"code": 0, "data": {"task_id": task_id}})

    def _advance(self, task: dict):
        """One status step per poll; the third poll finishes (or fails, for FAIL prompts)."""
        task["polls"] += 1
        view = task["view"]
        failing = "FAIL" in task["prompt"]
        base = self._base()
        if task["api"] == "meshy":
            if view["status"] in ("SUCCEEDED", "FAILED"):
                return
            if task["polls"] == 1:
                view.update(status="IN_PROGRESS", progress=50)
            elif failing:
                view.update(status="FAILED", progress=0, task_error={"message": "mock generation failed"})
            elif task.get("image_like"):
                view.update(status="SUCCEEDED", progress=100,
                            image_urls=[f"{base}/files/{view['id']}_concept{i}.png" for i in range(task["views"])])
            else:
                view.update(status="SUCCEEDED", progress=100, model_urls={"glb": f"{base}/files/{view['id']}.glb"})
                if task["refine_like"] and task["pbr"]:
                    view["texture_urls"] = [{key: f"{base}/files/{view['id']}_{key}.png"
                                             for key in ("base_color", "metallic", "normal", "roughness", "emission")}]
        else:
            if view["status"] in ("success", "failed"):
                return
            if task["polls"] == 1:
                view.update(status="running", progress=50)
            elif failing:
                view.update(status="failed", error_message="mock generation failed")
            else:
                view.update(status="success", progress=100, output={"model_url": f"{base}/files/{view['task_id']}.glb"})


def serve(port: int = 0):
    """Starts the mock in a background thread. Returns (server, state); server.server_address has the port."""
    state = MockState()
    handler = type("BoundHandler", (Handler,), {"state": state})
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, state


if __name__ == "__main__":
    server, _ = serve(int(sys.argv[1]) if len(sys.argv) > 1 else 8799)
    print(f"mock provider on http://127.0.0.1:{server.server_address[1]} (Ctrl+C to stop)")
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        server.shutdown()
