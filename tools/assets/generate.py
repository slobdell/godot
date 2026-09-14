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

Meshy requests are logged with their credits in assets/meshy_ledger.md, and a 3D request must name a concept the
lead approved (`--review-item`, tools/assets/review.py): the lead gate in _agents/workstreams.md.

Standard library only. `--base-url` points a provider at the local mock server (tools/assets/mock_provider.py),
which is how the tests exercise the whole flow without a network or a key.
"""

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import review  # noqa: E402
CONTRACTS = ROOT / "assets" / "pipeline" / "asset_contracts.gd"

# Generators overshoot; ask for ~85% of the slot budget so normalize rarely has to decimate.
POLY_HEADROOM = 0.85


class ProviderError(Exception):
    pass


# Whole units generated as one model, then split into their slots by the normalizer.
UNITS = {"unit.tank": ["tank.hull", "tank.turret", "weapon.cannon"]}
SMART_TOPOLOGY_MAX = 15000


def slot_budget(slot: str) -> int:
    """Triangle budget for a slot (or the sum for a unit), read from the GDScript contract table."""
    if slot in UNITS:
        return sum(slot_budget(part) for part in UNITS[slot])
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
        self.on_finished = None  # callable(family, task): the spend ledger

    def balance(self):
        """Credits left, or "" if the endpoint can't be read (the mock has none)."""
        try:
            return self.http.request("GET", "/openapi/v1/balance").get("balance", "")
        except ProviderError:
            return ""

    def concept(self, prompt: str, image_model: str, references: list = (), multi_view: bool = False,
                keep_background: bool = False) -> dict:
        """Concept art before paying for 3D (Meshy runs Google's nano-banana models; 3–9 credits).
        With references it's image-to-image (e.g. a consistent multi-view turnaround of a chosen design)."""
        # Objects headed for 3D want the background removed; a whole scene (mood art) must keep it.
        body = {"ai_model": image_model, "prompt": prompt, "remove_background": not keep_background}
        body.update({"generate_multi_view": True} if multi_view else {"aspect_ratio": "1:1"})
        family = "/openapi/v1/text-to-image"
        if references:
            family = "/openapi/v1/image-to-image"
            body["reference_image_urls"] = list(references)
        task_id = self.http.request("POST", family, body)["result"]
        print(f"  concept task {task_id}")
        return self._wait(family, task_id)

    def multi_image(self, prompt: str, images: list, image_task: str, polycount: int, ai_model: str, ultra: bool,
                    texture_resolution: str) -> dict:
        """Multi-image-to-3D (meshy-6/7): 1–4 views of one design, first = front. Fused mesh; split later."""
        body = {"ai_model": ai_model, "target_formats": ["glb"], "should_texture": True, "enable_pbr": True,
                "texture_resolution": texture_resolution, "should_remesh": True, "topology": "triangle",
                "target_polycount": polycount}
        body.update({"input_task_id": image_task} if image_task else {"image_urls": list(images)})
        if ultra:
            body["ultra_mode"] = True
        if prompt:
            body["texture_prompt"] = prompt[:800]
        task_id = self.http.request("POST", "/openapi/v1/multi-image-to-3d", body)["result"]
        print(f"  multi-image-to-3d task {task_id}")
        return self._wait("/openapi/v1/multi-image-to-3d", task_id)

    def generate(self, prompt: str, image: str, polycount: int, image_task: str = "", smart_topology: bool = False,
                 ai_model: str = "meshy-6", texture_resolution: str = "2k") -> dict:
        common = {"ai_model": ai_model, "target_formats": ["glb"]}
        if image or image_task:
            source = {"input_task_id": image_task} if image_task else {"image_url": image}
            if smart_topology:  # natively separated parts (hull / turret / gun); topology+remesh are ignored
                shape = {"model_type": "smart-topology", "ai_model": "meshy-t2",
                         "target_polycount": min(polycount, SMART_TOPOLOGY_MAX)}
            else:
                shape = {**common, "should_remesh": True, "topology": "triangle", "target_polycount": polycount}
            body = {"target_formats": ["glb"], **shape, **source, "should_texture": True, "enable_pbr": True,
                    "texture_resolution": texture_resolution}
            if prompt:
                body["texture_prompt"] = prompt[:800]
            task_id = self.http.request("POST", "/openapi/v1/image-to-3d", body)["result"]
            print(f"  image-to-3d task {task_id}")
            return self._wait("/openapi/v1/image-to-3d", task_id)
        shape = {"model_type": "smart-topology", "target_polycount": min(polycount, SMART_TOPOLOGY_MAX)} if smart_topology \
            else {**common, "should_remesh": True, "topology": "triangle", "target_polycount": polycount}
        preview_id = self.http.request("POST", "/openapi/v2/text-to-3d", {
            "target_formats": ["glb"], **shape, "mode": "preview", "prompt": prompt})["result"]
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
                if self.on_finished is not None:
                    self.on_finished(family, task)
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

    def generate(self, prompt: str, image: str, polycount: int, image_task: str = "", smart_topology: bool = False,
                 ai_model: str = "", texture_resolution: str = "") -> dict:
        if image or image_task:
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


def data_uri(path: Path) -> str:
    """A local reference image as a base64 data URI (Meshy accepts these in place of a public URL)."""
    if not path.exists():
        raise ProviderError(f"image {path} not found")
    kind = "jpeg" if path.suffix.lower() in (".jpg", ".jpeg") else "png"
    return f"data:image/{kind};base64," + base64.b64encode(path.read_bytes()).decode()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--provider", default="meshy", choices=sorted(PROVIDERS))
    parser.add_argument("--slot", required=True, help="visual slot the model is for (sets the polygon target)")
    parser.add_argument("--prompt", default="", help="text prompt (see _agents/streams/references/asset_prompts.md)")
    parser.add_argument("--image", default="", help="reference image: URL, data URI, or local .png/.jpg path (image-to-3D)")
    parser.add_argument("--concept-only", action="store_true",
                        help="meshy: generate a concept image from --prompt and stop (cheap review before 3D)")
    parser.add_argument("--image-task", default="", help="meshy: build the 3D model from a finished text-to-image task id")
    parser.add_argument("--image-model", default="nano-banana-pro", help="meshy text-to-image model for --concept-only")
    parser.add_argument("--reference", action="append", default=[],
                        help="meshy --concept-only: reference image (path/URL) for image-to-image; repeatable")
    parser.add_argument("--multi-view", action="store_true", help="meshy --concept-only: generate a multi-view turnaround")
    parser.add_argument("--keep-background", action="store_true",
                        help="meshy --concept-only: don't remove the background (scenes and mood art, not models)")
    parser.add_argument("--multi-image", action="store_true",
                        help="meshy: multi-image-to-3D from --image-task (a multi-view concept) or repeated --view images")
    parser.add_argument("--view", action="append", default=[], help="meshy --multi-image: a view image (path/URL), front first")
    parser.add_argument("--ai-model", default="", help="meshy 3D model: meshy-6 / meshy-7 / latest (default meshy-6; meshy-7 for --multi-image)")
    parser.add_argument("--ultra", action="store_true", help="meshy-7 ultra mode (more geometric detail)")
    parser.add_argument("--polycount", type=int, default=0, help="override the polygon target (the normalizer decimates to the slot budget)")
    parser.add_argument("--texture-resolution", default="2k", choices=["2k", "4k", "8k"])
    parser.add_argument("--smart-topology", action="store_true",
                        help="meshy-t2: clean low-poly topology with natively separated parts (split a unit into slots)")
    parser.add_argument("--name", default="", help="output base name (default: <provider>_<slot>_<time>)")
    parser.add_argument("--review-item", default="",
                        help="meshy 3D: the approved review item this model is built from (tools/assets/review.py); "
                             "its concept task is the default --image-task")
    parser.add_argument("--retry-reason", default="", help="meshy 3D: allow a second 3D request for a review item, and why")
    parser.add_argument("--skip-review-gate", action="store_true", help="tests only: needs --base-url (the mock)")
    parser.add_argument("--review-file", default=str(review.REVIEW))
    parser.add_argument("--ledger", default=str(review.LEDGER))
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
    if not args.prompt and not args.image and not args.image_task and not args.view and not args.review_item:
        print("give --prompt, --image, or --image-task", file=sys.stderr)
        return 2
    try:
        polycount = max(100, int(slot_budget(args.slot) * POLY_HEADROOM))
        provider = provider_class(Http(args.base_url or provider_class.base_url, token), args.poll_interval, args.timeout)
        name = args.name or f"{args.provider}_{args.slot.replace('.', '_')}_{time.strftime('%Y%m%d_%H%M%S')}"
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        item = None
        if args.provider == "meshy":
            manifest_path, ledger_path = Path(args.review_file), Path(args.ledger)
            purpose = args.review_item or name

            def log(family, task):
                request = task.get("type") or family.rsplit("/", 1)[1]
                model = task.get("ai_model") or ("meshy-t2 smart-topology" if args.smart_topology and "3d" in request else "")
                review.ledger_append(f"{request} {model}".strip(), task, purpose, provider.balance(), ledger_path)
            provider.on_finished = log
            if not args.concept_only:
                if args.skip_review_gate:
                    if not args.base_url:
                        raise ProviderError("--skip-review-gate is for tests against the mock (--base-url) only")
                elif not args.review_item:
                    raise ProviderError("a Meshy 3D request needs --review-item: the lead approves every concept before "
                                        "3D (make art-review; _agents/workstreams.md Lead gates)")
                else:
                    manifest = review.load(manifest_path)
                    item = review.gate_3d(manifest, args.review_item, args.retry_reason)
                    allowed = {item["concept_task"], item.get("turnaround_task", "")} - {""}
                    if args.image_task and args.image_task not in allowed:
                        raise ProviderError(f"--image-task {args.image_task} is not review item {item['id']}'s approved concept "
                                            f"({', '.join(sorted(allowed))})")
                    if not args.image_task and not args.image and not args.view:
                        args.image_task = item["concept_task"]
        if args.concept_only:
            if args.provider != "meshy":
                raise ProviderError("--concept-only is meshy-only")
            references = [ref if ref.startswith(("http://", "https://", "data:")) else data_uri(Path(ref)) for ref in args.reference]
            task = provider.concept(args.prompt, args.image_model, references, args.multi_view, args.keep_background)
            urls = task.get("image_urls") or []
            if not urls:
                raise ProviderError("the concept task succeeded but returned no image")
            size = provider.http.download(urls[0], out_dir / f"{name}.concept.png")
            for view, url in enumerate(urls[1:], start=1):
                size += provider.http.download(url, out_dir / f"{name}.concept{view}.png")
            (out_dir / f"{name}.concept.json").write_text(json.dumps({"provider": args.provider, "slot": args.slot,
                "prompt": args.prompt, "image_model": args.image_model, "references": args.reference,
                "keep_background": args.keep_background,
                "multi_view": args.multi_view, "task": task}, indent=2) + "\n")
            print(f"  downloaded {out_dir / (name + '.concept.png')} ({size / 1024:.0f} KB)")
            print(f"next (after reviewing the image): --image-task {task['id']}")
            return 0
        image = args.image
        if image and not image.startswith(("http://", "https://", "data:")):
            image = data_uri(Path(image))
        if args.polycount:
            polycount = args.polycount
        print(f"{args.provider}: generating for {args.slot} (target {polycount} faces)")
        if args.multi_image:
            views = [v if v.startswith(("http://", "https://", "data:")) else data_uri(Path(v)) for v in args.view]
            if not views and not args.image_task:
                raise ProviderError("--multi-image needs --image-task or --view images")
            task = provider.multi_image(args.prompt, views, args.image_task, polycount, args.ai_model or "meshy-7",
                                        args.ultra, args.texture_resolution)
        else:
            task = provider.generate(args.prompt, image, polycount, args.image_task, args.smart_topology,
                                     args.ai_model or "meshy-6", args.texture_resolution)
        if item is not None:  # before downloading: a paid task must never be requested twice
            manifest = review.load(manifest_path)
            review.record_model_task(manifest, item["id"], task["id"])
            review.save(manifest, manifest_path)
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
            "provider": args.provider, "slot": args.slot, "prompt": args.prompt,
            "image": args.image if not args.image.startswith("data:") else "(data uri)", "image_task": args.image_task,
            "smart_topology": args.smart_topology, "multi_image": args.multi_image, "views": args.view,
            "ai_model": args.ai_model, "ultra": args.ultra, "texture_resolution": args.texture_resolution,
            "target_polycount": polycount, "files": downloaded, "license_note": provider.license_note,
            "review_item": args.review_item, "task": task, "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        }, indent=2) + "\n")
    except (ProviderError, review.ReviewError) as error:
        print(f"{args.provider}: {error}", file=sys.stderr)
        return 1
    print(f"next: make assets-inspect IN={out_dir / (name + '.glb')} SLOT={args.slot}")
    if "emission" in downloaded:
        print(f"      (emission map: {downloaded['emission']}; see asset_prompts.md for wiring it in)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
