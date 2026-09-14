#!/usr/bin/env python3
"""Generate a 3D model with a hosted AI service and drop it in assets/incoming/, ready for the pipeline.

    make assets-generate PROVIDER=meshy SLOT=tank.hull PROMPT="armored scrap tank hull, neon strips"
    tools/assets/generate.py --provider meshy --slot tank.hull --prompt "..." [--image URL] [--name NAME]

Providers read their API key from the environment and never from the repo:
    meshy  MESHY_API_KEY   (recommended; _agents/streams/references/asset_services.md)
    tripo  TRIPO_API_KEY   (v3 API; some optional field names unverified)

Output: assets/incoming/<name>.glb, <name>.<map>.png for any extra texture maps (Meshy's emission map),
and <name>.json with the provider task, prompt, and license note. Then normalize it into a slot:
    make assets-normalize IN=assets/incoming/<name>.glb SLOT=<slot> THEME=<theme> ARGS="--forward=+z ..."

Standard library only. `--base-url` points a provider at the local mock server (tools/assets/mock_provider.py),
which is how the tests exercise the whole flow without a network or a key.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / "assets" / "pipeline" / "asset_contracts.gd"

# Generators overshoot; ask for ~85% of the slot budget so normalize rarely has to decimate.
POLY_HEADROOM = 0.85


class ProviderError(Exception):
    pass


def slot_budget(slot: str) -> int:
    """Triangle budget for a slot, read from the GDScript contract table (single source of truth)."""
    text = CONTRACTS.read_text()
    match = re.search(r'"%s":\s*\{(.*?)\n\t\}' % re.escape(slot), text, re.S)
    if not match:
        match = re.search(r'"%s":\s*\{([^}]*)\}' % re.escape(slot), text)
    if not match:
        raise ProviderError(f"unknown slot {slot!r} (see make assets-slots)")
    tris = re.search(r'"tris":\s*(\d+)', match.group(1))
    return int(tris.group(1))


class Http:
    def __init__(self, base_url: str, token: str, retries: int = 4, backoff: float = 2.0):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.retries = retries
        self.backoff = backoff

    def request(self, method: str, path: str, body=None) -> dict:
        url = path if path.startswith("http") else self.base_url + path
        data = json.dumps(body).encode() if body is not None else None
        for attempt in range(self.retries + 1):
            req = urllib.request.Request(url, data=data, method=method, headers={
                "Authorization": f"Bearer {self.token}", "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=60) as response:
                    return json.loads(response.read() or b"{}")
            except urllib.error.HTTPError as error:
                detail = error.read().decode(errors="replace")[:300]
                if error.code == 429 and attempt < self.retries:
                    wait = float(error.headers.get("Retry-After") or self.backoff * (2 ** attempt))
                    print(f"  rate limited; retrying in {wait:.1f}s", file=sys.stderr)
                    time.sleep(wait)
                    continue
                hints = {401: "the API key was rejected", 402: "the account is out of credits",
                         403: "the plan doesn't include API access"}
                raise ProviderError(f"{method} {path}: HTTP {error.code} {hints.get(error.code, '')} {detail}".strip())
            except urllib.error.URLError as error:
                raise ProviderError(f"{method} {url}: {error.reason}")
        raise ProviderError(f"{method} {path}: still rate limited after {self.retries} retries")

    def download(self, url: str, dest: Path) -> int:
        with urllib.request.urlopen(url, timeout=120) as response:
            payload = response.read()
        dest.write_bytes(payload)
        return len(payload)


class Meshy:
    """Meshy text-to-3D (preview → refine) and image-to-3D. Docs: docs.meshy.ai (Appendix A of asset_services.md)."""
    name = "meshy"
    key_env = "MESHY_API_KEY"
    base_url = "https://api.meshy.ai"
    license_note = ("Meshy paid plans: the customer owns generated assets (terms §3.2). "
                    "Free plan outputs are CC BY 4.0 and need credit to Meshy. Verify the plan before shipping.")
    terminal = {"SUCCEEDED", "FAILED", "CANCELED"}

    def __init__(self, http: Http, poll_interval: float, timeout: float):
        self.http, self.poll_interval, self.timeout = http, poll_interval, timeout

    def generate(self, prompt: str, image: str, polycount: int) -> dict:
        common = {"ai_model": "meshy-6", "target_formats": ["glb"]}
        if image:
            task_id = self.http.request("POST", "/openapi/v1/image-to-3d", {
                **common, "image_url": image, "should_texture": True, "enable_pbr": True,
                "should_remesh": True, "topology": "triangle", "target_polycount": polycount,
                "texture_prompt": prompt or None})["result"]
            return self._wait("/openapi/v1/image-to-3d", task_id)
        preview_id = self.http.request("POST", "/openapi/v2/text-to-3d", {
            **common, "mode": "preview", "prompt": prompt, "should_remesh": True,
            "topology": "triangle", "target_polycount": polycount})["result"]
        print(f"  preview task {preview_id}")
        self._wait("/openapi/v2/text-to-3d", preview_id)
        # meshy-6 + enable_pbr is the only combination that returns an emission map (asset_services.md).
        refine_id = self.http.request("POST", "/openapi/v2/text-to-3d", {
            **common, "mode": "refine", "preview_task_id": preview_id, "enable_pbr": True,
            "texture_resolution": "2k"})["result"]
        print(f"  refine task {refine_id}")
        return self._wait("/openapi/v2/text-to-3d", refine_id)

    def _wait(self, family: str, task_id: str) -> dict:
        deadline = time.monotonic() + self.timeout
        while True:
            task = self.http.request("GET", f"{family}/{task_id}")
            status = task.get("status", "")
            if status in self.terminal:
                if status != "SUCCEEDED":
                    message = (task.get("task_error") or {}).get("message", "")
                    raise ProviderError(f"task {task_id} {status}: {message}")
                return task
            if time.monotonic() > deadline:
                raise ProviderError(f"task {task_id} still {status} after {self.timeout:.0f}s")
            print(f"  {status} {task.get('progress', 0)}%")
            time.sleep(self.poll_interval)

    @staticmethod
    def files(task: dict) -> dict:
        """{'model': url, '<map>': url} for the GLB and any PBR/emission maps."""
        found = {"model": (task.get("model_urls") or {}).get("glb")}
        textures = task.get("texture_urls") or []
        if textures:
            for key, url in textures[0].items():
                if url:
                    found[key] = url
        return found


class Tripo:
    """Tripo v3 text/image-to-model. Optional field names beyond prompt/model/face_limit are unverified."""
    name = "tripo"
    key_env = "TRIPO_API_KEY"
    base_url = "https://openapi.tripo3d.ai/v3"
    license_note = "Tripo license terms could not be verified on 2026-09-14 (terms page returned 403). Check before shipping."
    terminal = {"success", "failed", "cancelled", "banned", "expired"}

    def __init__(self, http: Http, poll_interval: float, timeout: float):
        self.http, self.poll_interval, self.timeout = http, poll_interval, timeout

    def generate(self, prompt: str, image: str, polycount: int) -> dict:
        if image:
            raise ProviderError("tripo image-to-model needs a file upload (POST /files); not implemented yet")
        created = self._data(self.http.request("POST", "/generation/text-to-model", {
            "prompt": prompt, "model": "tripo-p1", "face_limit": polycount, "pbr": True}))
        task_id = created["task_id"]
        print(f"  task {task_id}")
        deadline = time.monotonic() + self.timeout
        while True:
            task = self._data(self.http.request("GET", f"/tasks/{task_id}"))
            if task.get("status") in self.terminal:
                if task["status"] != "success":
                    raise ProviderError(f"task {task_id} {task['status']}: {task.get('error_message', '')}")
                return task
            if time.monotonic() > deadline:
                raise ProviderError(f"task {task_id} still {task.get('status')} after {self.timeout:.0f}s")
            print(f"  {task.get('status')} {task.get('progress', 0)}%")
            time.sleep(self.poll_interval)

    @staticmethod
    def _data(envelope: dict) -> dict:
        if envelope.get("code", 0) != 0:
            raise ProviderError(f"tripo error {envelope.get('code')}: {envelope.get('message', '')}")
        return envelope.get("data", {})

    @staticmethod
    def files(task: dict) -> dict:
        # Download within 5 minutes: Tripo's URLs expire quickly.
        return {"model": (task.get("output") or {}).get("model_url")}


PROVIDERS = {"meshy": Meshy, "tripo": Tripo}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--provider", default="meshy", choices=sorted(PROVIDERS))
    parser.add_argument("--slot", required=True, help="visual slot the model is for (sets the polygon target)")
    parser.add_argument("--prompt", default="", help="text prompt (see _agents/streams/references/asset_prompts.md)")
    parser.add_argument("--image", default="", help="reference image URL or data URI (image-to-3D)")
    parser.add_argument("--name", default="", help="output base name (default: <provider>_<slot>_<time>)")
    parser.add_argument("--out-dir", default=str(ROOT / "assets" / "incoming"))
    parser.add_argument("--base-url", default="", help="override the API base URL (the mock server in tests)")
    parser.add_argument("--poll-interval", type=float, default=5.0)
    parser.add_argument("--timeout", type=float, default=900.0)
    args = parser.parse_args(argv)

    provider_class = PROVIDERS[args.provider]
    token = os.environ.get(provider_class.key_env, "")
    if not token:
        print(f"{provider_class.key_env} is not set. To turn on {args.provider} generation:\n"
              f"  1. create an account and API key (see _agents/streams/references/asset_services.md for plans/cost)\n"
              f"  2. export {provider_class.key_env}=...   (in your shell profile, never in the repo)\n"
              f"  3. make assets-generate PROVIDER={args.provider} SLOT={args.slot} PROMPT=\"...\"", file=sys.stderr)
        return 3
    if not args.prompt and not args.image:
        print("give --prompt and/or --image", file=sys.stderr)
        return 2
    try:
        polycount = max(100, int(slot_budget(args.slot) * POLY_HEADROOM))
        provider = provider_class(Http(args.base_url or provider_class.base_url, token), args.poll_interval, args.timeout)
        print(f"{args.provider}: generating for {args.slot} (target {polycount} faces)")
        task = provider.generate(args.prompt, args.image, polycount)
        name = args.name or f"{args.provider}_{args.slot.replace('.', '_')}_{time.strftime('%Y%m%d_%H%M%S')}"
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        downloaded = {}
        for kind, url in provider.files(task).items():
            if not url:
                continue
            dest = out_dir / (f"{name}.glb" if kind == "model" else f"{name}.{kind}.png")
            size = provider.http.download(url, dest)
            downloaded[kind] = dest.name
            print(f"  downloaded {dest} ({size / 1024:.0f} KB)")
        if "model" not in downloaded:
            raise ProviderError("the task succeeded but returned no GLB url")
        (out_dir / f"{name}.json").write_text(json.dumps({
            "provider": args.provider, "slot": args.slot, "prompt": args.prompt, "image": args.image,
            "target_polycount": polycount, "files": downloaded, "license_note": provider.license_note,
            "task": task, "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        }, indent=2) + "\n")
    except ProviderError as error:
        print(f"{args.provider}: {error}", file=sys.stderr)
        return 1
    print(f"next: make assets-inspect IN={out_dir / (name + '.glb')} SLOT={args.slot}")
    if "emission" in downloaded:
        print(f"      (emission map: {downloaded['emission']}; see asset_prompts.md for wiring it in)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
