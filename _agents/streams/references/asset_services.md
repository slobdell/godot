# A0: AI 3D generation services and open models

Desk research for the assets stream (brief: `_agents/streams/assets.md`, task A0).
**All URLs accessed 2026-09-14.** Budgets we care about: hull ≤8k tris, turret ≤4k, props ≤2–3k,
textures ≤1024², GLB, and **emissive** for neon strips.

Legend: **V** = read on the vendor's own page. **3P** = only third-party sources or search-result
snippets. **unverified** = the page couldn't be fetched (403, JS-only, DNS failure) or said nothing
on the point. Page text came through a summarizing fetcher, so re-check exact field names against
the live docs before shipping the real client (the mock server can use this file as-is).

---

## 1. Hosted services

### 1.1 Meshy (meshy.ai): recommended first
- **Status:** active. Models `meshy-6`, `meshy-7` (released 2026-08-12/13), `meshy-t2` "Smart
  Topology" (2026-07-13), `meshy-6-lite`; `meshy-5` deprecated 2026-09-11 (V, changelog).
- **Pricing (V + 3P):** Free has 100 credits/mo, **no API**. Pro costs **$20/mo** ($240/yr) for 1,000 credits/mo, with API
  access and 10 concurrent tasks (V pricing page lists credits/API; the $20 figure is 3P, because the pricing
  cards didn't render). Studio and Enterprise tiers exist. So Pro ≈ **$0.02/credit**.
- **API credit costs (V, docs.meshy.ai/en/api/pricing):**
  - Text-to-3D preview (mesh only): 20 credits on meshy-6/7/low-poly (+5 for `ultra_mode`), **5 on Smart
    Topology (T2)**.
  - Text-to-3D refine (texture): 10 credits at 2k/4k, 15 at 8k.
  - Image-to-3D, meshy-6/7: 20 credits untextured, 30 textured, 35 with 8K texture.
  - Image-to-3D, T2: 5 credits untextured, **15 textured**.
  - Remesh, UV unwrap, and rig: 5 credits each. Convert/resize: 1 credit. Retexture: 10 credits.
  - **Cost per textured model:** T2 text-to-3D = 5+10 = 15 credits ≈ **$0.30**; meshy-6 = 30 credits ≈ **$0.60**;
    T2 image-to-3D ≈ **$0.30**. Add $0.10 if we remesh afterwards.
- **API:** REST at `https://api.meshy.ai`, header `Authorization: Bearer msy_...`. Async flow: create task
  → poll `GET .../:id` or SSE `/stream` → download `model_urls.glb`. Signed, time-limited URLs;
  files are kept for **3 days** on non-Enterprise plans (V quick-start). Rate limit: 20 req/s, 10 queued
  tasks on Pro (V). No test-mode key found on the auth page. **Env var: `MESHY_API_KEY`** (the docs use it).
- **Formats:** glb, fbx, obj(+mtl), usdz, stl, 3mf (and blend from remesh).
- **Poly control (V), the strongest of any vendor:**
  - `model_type`: `standard` | `smart-topology` | `lowpoly`. `lowpoly` is deprecated but still served.
  - `target_polycount`: 100–300,000 on standard/remesh, **100–15,000 on smart-topology (default 4,000)**.
  - `topology`: `triangle` | `quad`. `decimation_mode`: 1–4.
  - A standalone **Remesh API** accepts any GLB/FBX/OBJ URL.
- **Textures:** `texture_resolution` 2k/4k/8k. **Minimum is 2k**, so our normalize tool downsizes to 1024.
  `enable_pbr` adds metallic, roughness, and normal maps.
- **Emissive: yes, partially (V changelog 2026-04-20).** `texture_urls[].emission` comes back when
  `enable_pbr=true` **and `ai_model=meshy-6`** (also Text-to-3D refine and Retexture). There's no emission map at 8k,
  and **none on meshy-7/latest** (3P snippet of the same changelog). Emission on T2 is unverified. The map is
  AI-inferred, so don't count on it for designed neon strips (see §4).
- **Modes:** text-to-3D (preview → refine), image-to-3D, multi-image-to-3D, retexture, remesh, rig.
- **License (V, meshy.ai/terms-of-use §3.2):**
  - **Free:** Meshy owns the output, and users get it under "the Creative Commons Attribution 4.0
    International License (CC BY 4.0)", which allows commercial use "as long as Free Customer provides
    appropriate credit to Provider".
  - **Paid:** the customer owns the output, and Meshy gets a "non-exclusive, royalty-free, worldwide license to
    reproduce, distribute, and otherwise use and display" it.
  - §2.6(xi) bans using outputs "to train … AI models that are competitive with Meshy".
- **Quality (3P, general):** good hard-surface blockouts. Standard triangle meshes run dense until
  remeshed. Smart Topology is the mode to try for hulls and turrets, since it separates parts natively and gives a settable
  face count.

### 1.2 Tripo (Tripo3D / VAST): solid second
- **Status:** active. API **v3** at `https://openapi.tripo3d.ai/v3`. **v2 (`api.tripo3d.ai/v2/openapi/task`)
  ends maintenance 2026-10-01 and is disabled 2026-11-01** (3P, search snippets citing Tripo). Only build against v3.
- **API pricing (V, developers.tripo3d.ai/en/pricing):** pay-as-you-go, **1 credit = $0.01**, no subscription
  needed. Failed tasks aren't charged.
  - Text-to-3D: 10 credits untextured, 20 with standard texture. Image-to-3D: 20 / 30.
  - Add-ons: HD texture +10, HD geometry +20, quad +5, **smart low-poly +10**.
  - Retopology: 10 (basic) / 30 (smart). Convert: 5 / 10.
  - **Cost per textured low-poly model:** ≈ 20+10 = **$0.30**; without low-poly, $0.20.
  - No free API trial credits are stated.
- **Web plans (3P; tripo3d.ai/pricing returned 403):** Basic is free with 300 credits/mo, public models, and "no
  commercial use" per some 3P sources (others say CC BY 4.0). Pro is ~$19.90/mo for 3,000 credits with private models and
  commercial rights. Web plans are separate from API billing.
- **API flow (V):** `POST /v3/generation/text-to-model` (or `/image-to-model`, `/multiview-to-model`) returns
  `{"code":0,"data":{"task_id":...}}`. Then poll `GET /v3/tasks/{task_id}` every 1–2 s (batch: `POST /v3/tasks/list`)
  and download `data.output.model_url`. Webhooks exist. Header `Authorization: Bearer <key>`. **Env var `TRIPO_API_KEY`**
  (V quick-start and SDK). **Model URLs expire after 5 minutes**, so download right away (V quick-start).
  Concurrency: H-series 10, P-series 5 (V).
- **Formats:** GLB by default. `POST /v3/models/convert` makes GLTF/FBX/USDZ/OBJ/STL/3MF with `face_limit`, `quad`,
  `texture_size` (default 4096), `texture_format`, `pivot_to_center_bottom`, `scale_factor`, and `bake` (V).
- **Poly control (V):**
  - `face_limit` is adaptive if unset and defaults to 10,000 when `quad=true`.
  - The **`tripo-p1` low-poly model** ("rapid low-poly generation for game assets and mobile-ready 3D") is auto-selected when
    the face budget is ≤20,000 (V CLI doc).
  - The legacy/H3 docs list `smart_low_poly` (face_limit 1,000–20,000; 500–10,000 with quad), `quad`, `texture_quality`,
    `geometry_quality`, `pbr`, and `generate_parts` (V docs.tripo3d.ai H3 page).
- **Textures:** PBR by default (`pbr: true`). `texture_size` can be set on convert, so we can request 1024 directly.
  **Emissive: not documented anywhere** (V models page is silent). Assume none.
- **License:** **unverified**, because the Terms page returned 403. Tripo's own blog posts (also 403) reportedly say paid plans
  have private models with full commercial rights. Before using Tripo output commercially, get the API ToS in
  writing.
- **Quality (3P):** strong on clean, stylized, game-style props; P1 aims squarely at mobile budgets.

### 1.3 Rodin / Hyper3D (Deemos): best topology, pricier API entry
- **Pricing (V, hyper3d.ai/pricing):**
  - Free: pay per download at **$1.50/credit**.
  - Creator: $30/mo (~60 models).
  - **Business: $120/mo (~416 models), "Full API access"**, so API use effectively needs Business (~$0.29/model).
  - Gen-2.5 API: 0.5 credits base, +0.5 for Extreme-High tier, +2.0 for extreme-high texture (V API spec), which comes to about $0.75 per
    model on direct credits.
- **API flow (V, docs.hyper3d.ai):**
  1. `POST https://api.hyper3d.com/api/v2/rodin` (multipart; `images` 1–5 and/or `prompt`, `tier`,
     `mesh_mode`, `quality`, `texture_mode`, `addons`) returns `{uuid, jobs:{uuids, subscription_key}, consumed}`.
  2. `POST /api/v2/status {"subscription_key"}` until every job is `Done` (or `Failed`).
  3. `POST /api/v2/download {"task_uuid"}` returns a file list (name, url).
  Header `Authorization: Bearer`; **env var `RODIN_API_KEY`**. Honor `Retry-After` on 429.
- **Formats (3P via fal/wavespeed listings):** glb, usdz, fbx, obj, stl.
- **Poly control (3P):**
  - `mesh_mode=Quad` gives **4k / 8k / 18k / 50k** faces (extra-low/low/medium/high).
  - `Raw` triangles give 2k / 20k / 150k / 500k.
  - Quad extra-low (4k) or low (8k) fits turret/hull budgets directly. `bbox_condition` sets proportions.
- **Textures:** `material` PBR (base color, metallic, normal, roughness) or Shaded (baked). 1K default in the
  legacy tiers; Gen-2.5 runs 2K–12K (V). **Emissive: not offered** (not in any map list).
- **License (V, hyper3d.ai/legal/terms §5.1b):** for Rodin Output, "we will not limit your use of such Output,
  subject to any restrictions set forth in these Agreements". There's no free/paid split for Rodin (the split applies only to
  ChatAvatar). §6.3 bans using the service to train competing models. Outputs can be set private.
- **Quality (3P):** widely rated top for hard-surface geometry and quad topology. The downside is the higher API entry cost.

### 1.4 Other hosted options
| Service | Status / API | Price | Notes |
|---|---|---|---|
| **Luma Genie** | **Retired 2026-01-01** per 3P reports; Luma's changelog has no entry (V, lumalabs.ai/changelog) and lists no 3D API | n/a | Drop from consideration. |
| **CSM (Common Sense Machines)** | **Cube shut down 2026-01-05; acquired by Alphabet/DeepMind 2026-01-24** (3P: 3dprintingindustry, The Information). `csm.ai` and `docs.csm.ai` fail DNS today (V) | n/a | Drop. |
| **Stability AI API** | Stable Fast 3D (and likely SPAR3D) as a hosted endpoint; platform pages are JS-only, so **unverified** | 3P: SF3D 10 credits ≈ **$0.10** | Fast but low fidelity; single image. Same weights as §2. |
| **3D AI Studio** | Public REST API since 2026-03-09, base `https://api.3daistudio.com/v1/`, Bearer, async poll (V docs) | Prepaid credits from $10, 365-day expiry (3P); Prism 3.1 costs 35 credits | Aggregator: resells **Hunyuan 3.0/3.5, TRELLIS 2**, and its own Prism. Rate limit 3 req/min (3P). Output license unverified. |
| **Hunyuan3D cloud (Tencent)** | Tencent Cloud "Hunyuan 3D" 3.0/3.1: up to 1.5M faces, 8K PBR (metal/rough/normal); **LowPoly** mode 30 credits (V tencentcloud techpedia) | Credit-based; international console is China-centric (3P) | Easiest route abroad is via 3D AI Studio or other aggregators. No emissive map mentioned. |
| **Sloyd** | Procedural generators, not diffusion. API **not accepting new clients** (3P) | Plus $15/mo, Pro $50/mo (3P) | Clean game-ready topology with LODs, but a limited catalog. Worth a look for props. |
| **Kaedim** | Human-in-the-loop, enterprise-leaning | ~$50–150+/mo, no free tier (3P) | Too expensive and slow for batch generation. |
| **Masterpiece X** | GenAI REST API (docs returned HTTP 402, **unverified**) | Consumer $10.99–36.99/mo; API pay-per-call (3P) | Low priority. |

---

## 2. Open models (later, for local GPU use)

| Model | Input | VRAM | License (weights/code) | Output / controls | Caveats |
|---|---|---|---|---|---|
| **TRELLIS** (Microsoft) | image (best); text base/large/xlarge (weaker, V) | **≥16 GB**, Linux (V) | Code MIT (V) | GLB via `to_glb(simplify=, texture_size=1024)` (V) | Deps diffoctreerast and FlexiCubes carry their own licenses. |
| **TRELLIS.2-4B** | image only (V) | **≥24 GB**, tested A100/H100, Linux (V) | **MIT** code and weights (V, HF card) | GLB with WebP textures; **Base Color, Roughness, Metallic, Opacity** (V); user-set decimation target | **nvdiffrast / nvdiffrec are NVIDIA Source Code License: "only may be used … non-commercially"** (V, nvdiffrast LICENSE §3.3). Before commercial use, check which pipeline stage needs them or swap in a replacement. No emissive. |
| **Stable Fast 3D (SF3D)** | image | **~6 GB** (V); CUDA/MPS/CPU | **Stability AI Community License** (V) | GLB; `--texture-resolution`; remesh `none/triangle/quad`; rough target vertex count (V) | Sub-second. Low detail; good for filler props. |
| **SPAR3D** | image (+ point-cloud edit) | **10.5 GB** default, ~7 GB low-VRAM (V) | Stability AI Community License (V) | Same controls as SF3D (V) | Better back sides than SF3D. |
| **Hunyuan3D 2.1** (Tencent) | image | shape **10 GB**, texture **21 GB**, both **29 GB** (V) | **Tencent Hunyuan 3D 2.1 Community License** (V) | Mesh + PBR (map list not enumerated; no emissive mentioned) | Territory **excludes EU, UK, South Korea** (V); >1M MAU needs Tencent approval; outputs can't improve other AI models. Tencent "claims no rights in Outputs". 3.x appears cloud-only (weights **unverified**). |
| **Step1X-3D** (StepFun) | image | **27–29 GB** geo+texture (V) | **Apache 2.0** (V) | GLB, `reduce_face` step (V) | PBR map set not documented. |
| **TripoSG / TripoSR** (VAST) | image | unverified | **MIT** (3P) | Shape only (SG); fast low-fi (SR) | TripoSG gives geometry without texture; texture it elsewhere. |

**Stability Community License (V, stability.ai/community-license-agreement):**
- If you "generate more than USD $1,000,000 in annual revenue … regardless of whether that revenue is
  generated directly or indirectly from the Stability AI Materials", the "licenses granted … shall terminate".
- "You own any outputs generated from the Models."
- Fine for us, but it's a revenue cap.

**Local takeaway:** a single 24 GB card (a 4090 or similar) runs everything except Hunyuan 2.1 shape+texture in one
pass. The cleanest licenses are TRELLIS.2 (if the nvdiffrast issue is solved), Step1X-3D, and TripoSG. None of these models produces emissive maps.

---

## 3. Comparison and recommendation

| | Meshy | Tripo | Rodin | Stability API | 3D AI Studio |
|---|---|---|---|---|---|
| REST async API | **Yes, well documented, SSE too** | Yes (v3; v2 retiring Nov 2026) | Yes (3-call flow) | Yes (unverified) | Yes |
| Text→3D / Image→3D | Both | Both | Both | Image only | Both |
| Poly target param | **`target_polycount` 100–300k; T2 100–15k; remesh endpoint** | `face_limit`, P1 low-poly, smart low-poly | Quad 4k/8k/18k/50k presets | Rough vertex count | Retopo endpoint |
| Quad topology | Yes | Yes (+5) | Yes | Yes | Yes |
| Min texture / 1024 | 2k min (downscale) | `texture_size` settable | 1K default (legacy) | Settable | Varies |
| PBR maps | BC/metal/rough/normal | PBR (yes) | BC/metal/rough/normal | Partial | Model-dependent |
| **Emissive map** | **Yes, meshy-6 + PBR only** | No (undocumented) | No | No | No (unverified) |
| Commercial output, modest tier | **Paid: customer owns (V)**; free CC BY | Unverified (ToS 403) | Unrestricted all tiers (V) | Owns outputs | Unverified |
| API entry cost | $20/mo Pro | Pay-as-you-go | $120/mo Business | Pay-as-you-go | Prepaid $10+ |
| ≈ $ per textured low-poly model | **$0.30** (T2) – $0.60 (m6) | **$0.20–0.30** | ~$0.29 (Business) – $0.75 | ~$0.10 | ~$0.35+ |
| Env var we'd use | `MESHY_API_KEY` | `TRIPO_API_KEY` | `RODIN_API_KEY` | `STABILITY_API_KEY` | `THREEDAI_API_KEY` |

**Recommendation: implement Meshy first**, behind a provider interface, with Tripo as the second adapter.
1. **Automation:** the clearest verified API spec. One status enum, one download field, SSE streaming, and a 3-day
   file retention window that tolerates slow polls (Tripo's URLs die after 5 minutes).
2. **Poly control:** the only vendor with a numeric target in the exact range we need. Smart Topology does
   100–15k tris with separated parts, and the standalone Remesh endpoint can squeeze any GLB (even non-Meshy ones)
   to 8k/4k/2k.
3. **License:** a documented, unambiguous paid-tier ownership clause at $20/mo. Free-tier output is CC BY, which is
   usable but needs attribution, so keep CI and mock runs off the real API anyway.
4. **Emissive:** the only service returning an `emission` map at all (meshy-6).
5. **Cost:** ≈$0.30–0.60 per textured model, so 1,000 credits/mo ≈ 30–60 finished assets, enough for the slot list.

Tripo stays a strong, cheaper second: pay-as-you-go with no subscription, and P1 low-poly. Its API ToS must be
verified first. Save Rodin for hero hulls if Meshy's hard-surface quality falls short: its quad 4k/8k presets
are ideal, but API access starts at $120/mo. Look at local TRELLIS.2 / Step1X-3D only once a 24 GB GPU is available.

---

## 4. How we get emissive neon anyway

Generators won't reliably place neon where we want it, and Meshy's `emission` map is a guess that only
comes from meshy-6. Treat any vendor emission map as a *hint* and own emissive in our pipeline:
1. **Prompt for it:** "saturated cyan neon light strips along the hull edges, dark gunmetal body". This
   yields bright, saturated albedo regions that are easy to mask.
2. **Albedo color mask in the normalize tool (A1):** convert albedo to HSV and mask pixels with high S and high V
   inside a hue band (cyan ~180°, magenta ~300°) or a luminance above a threshold. Dilate by 1–2 px and write an
   `emissive` texture (albedo × mask) at ≤1024². Set glTF `emissiveFactor` (plus `KHR_materials_emissive_strength` >1
   so glow thresholds catch it) or, in the wrapper `.tscn`, `emission_enabled`, `emission_texture`, and
   `emission_energy_multiplier`. If Meshy supplies `emission`, OR it into the mask. Test this with a synthetic GLB
   whose albedo has a known stripe.
3. **Team color:** keep the mask as a separate channel/texture so `set_team_color` can tint emissive
   (cyan vs magenta) at runtime without re-texturing. It's one shader uniform, fine on the Compatibility renderer.
4. **Procedural strip meshes (most controllable):** add thin unshaded boxes/quads with HDR emissive color
   along named sockets or detected silhouette edges (top-of-hull perimeter, turret ring, barrel shroud). They cost
   ~12 tris each, look identical on web and phone, and are independent of generator quality. The A4 procedural kit
   already plans this.
5. **Separate material slot:** Smart Topology returns separated parts, so name one part "neon" and give it an
   emissive material in the wrapper scene.

---

## Appendix A: Meshy API (for the mock server)
Base `https://api.meshy.ai`. Header `Authorization: Bearer <MESHY_API_KEY>`, JSON bodies. Errors: 400 bad params,
401 auth, **402 insufficient credits**, 404 not found, 429 (`RateLimitExceeded` or `NoMoreConcurrentTasks`).
HTTP gets a 301 redirect to HTTPS.

**Every create call returns `{"result": "<task_id>"}`.** Every family also has `GET /…` (list; query `page_num`=1,
`page_size`=10 (max 100), `sort_by` `+created_at`|`-created_at`), `GET /…/:id` (retrieve), `GET /…/:id/stream`
(SSE progress events), and `DELETE /…/:id`.

**Text to 3D: `/openapi/v2/text-to-3d`**
- *Preview* `POST` fields:
  - Required: `mode:"preview"`, `prompt` (≤800 chars).
  - `model_type` `standard`|`smart-topology`|`lowpoly` (default standard).
  - `ai_model` `meshy-6-lite`|`meshy-6`|`meshy-7`|`latest`|`meshy-5` (default `latest`).
  - `ultra_mode` bool (meshy-7/latest only).
  - `should_remesh` bool; `topology` `triangle`|`quad` (default triangle); `decimation_mode` 1–4.
  - `target_polycount` int (100–300000 standard; 100–15000 smart-topology, default 4000).
  - `pose_mode` `""`|`a-pose`|`t-pose`; `moderation` bool.
  - `target_formats` [`glb`,`obj`,`fbx`,`stl`,`usdz`,`3mf`].
  - `alpha_thumbnail` bool; `auto_size` bool; `origin_at` `bottom`|`center`.
  - Deprecated: `symmetry_mode`, `art_style`, `is_a_t_pose`.
- *Refine* `POST` fields:
  - Required: `mode:"refine"`, `preview_task_id` (must be SUCCEEDED).
  - `enable_pbr` bool (default false); `texture_resolution` `2k`|`4k`|`8k` (default 2k).
  - `texture_prompt` (≤800); `texture_image_url` (URL or data URI).
  - `ai_model` (inherits from the preview); `remove_lighting` bool (default true, meshy-6).
  - `moderation`, `target_formats`, `alpha_thumbnail`, `auto_size`, `origin_at`.
- *Task object:*
  - `id`; `type` `text-to-3d-preview`|`text-to-3d-refine`.
  - `model_urls` {`glb`,`fbx`,`obj`,`mtl`,`usdz`,`stl`,`3mf`}.
  - `prompt`, `texture_prompt`, `texture_image_url`, `thumbnail_url`, `alpha_thumbnail_url`.
  - `progress` 0–100; `status`; `preceding_tasks` (queue position).
  - `created_at`/`started_at`/`finished_at` (ms epoch, 0 when unset).
  - **`texture_urls`: array of objects** {`base_color`, `metallic`, `normal`, `roughness`, `emission`}. The PBR keys
    appear only with `enable_pbr`; `emission` only on meshy-6 below 8k.
  - `task_error` {`message`}; `consumed_credits`; `ultra_mode`.

**Image to 3D: `/openapi/v1/image-to-3d`**
- `POST` fields:
  - Input: `image_url` (URL or base64 data URI; jpg/jpeg/png) **or** `input_task_id` (from a text-to-image task).
  - `model_type`, `ai_model` (adds `meshy-t2`), `ultra_mode`.
  - `should_texture` (default true), `enable_pbr`, `texture_resolution`, `texture_prompt`, `texture_image_url`.
  - `should_remesh` (default false for meshy-6/7), `topology`, `decimation_mode`, `target_polycount`,
    `save_pre_remeshed_model`.
  - `pose_mode`, `image_enhancement` (default true), `remove_lighting`, `moderation`, `target_formats`, `auto_size`,
    `origin_at`, `alpha_thumbnail`, `multi_view_thumbnails`.
- Task object: `type:"image-to-3d"`. `model_urls` adds `pre_remeshed_glb`. `thumbnail_urls` {`front`,`right`,`back`,`left`}.
  Also `expires_at`, plus the same `texture_urls`, `progress`, `status`, `task_error`, and `consumed_credits` as text-to-3D.

**Remesh: `/openapi/v1/remesh`**
- `POST` fields:
  - Input: `input_task_id` **or** `model_url` (.glb/.gltf/.obj/.fbx/.stl).
  - `target_formats` (default [`glb`]; also `blend`); `topology` (default triangle).
  - `target_polycount` (default 30000, range 100–300000); `decimation_mode` 1–4; `alpha_thumbnail`.
  - Deprecated: `resize_height`, `resize_longest_side`, `auto_size`, `origin_at`, `convert_format_only`.
- Task object: `type:"remesh"`, `model_urls`, `thumbnail_url`, `progress`, `status`, `preceding_tasks`, timestamps,
  `task_error`, and `consumed_credits` (0 on failure).

**Status values:** `PENDING` → `IN_PROGRESS` → `SUCCEEDED` | `FAILED` | `CANCELED`. The remesh docs omit
CANCELED; the mock should accept it anyway.

**Also present, fields unverified:** `/openapi/v1/multi-image-to-3d`, `/openapi/v1/retexture`, text-to-image.

**Client flow for a hull:**
1. `POST v2/text-to-3d` preview with `model_type:"smart-topology"`, `target_polycount:7000`, `target_formats:["glb"]`.
2. Poll every ~5 s until `SUCCEEDED`.
3. `POST` refine with `enable_pbr:true`, `ai_model:"meshy-6"` (for emission), `texture_resolution:"2k"`.
4. Poll until done.
5. Download `model_urls.glb` and each `texture_urls[0].*` immediately.
6. Normalize (tris check, then 1024 downscale and emissive mask).
Whether a meshy-6 refine can be chained onto a T2 preview is unverified; the mock should allow it and the real
client should fall back to meshy-6 for both steps.

## Appendix B: Tripo API v3 (brief)
Base `https://openapi.tripo3d.ai/v3`. Header `Authorization: Bearer <TRIPO_API_KEY>`.
Envelope: `{"code":0,"data":{...}}`, where code ≠ 0 means an error. 429 codes: **1007** for rate limit, **2000** for
concurrency (with `Retry-After`).
- `POST /files`: multipart field `file`; returns `data.file_token`. Images ≤20 MB, models ≤150 MB; large-file
  endpoint for >60 MB.
- `POST /generation/text-to-model`: `{"prompt", "model":"tripo-v3.1"|"tripo-p1"…, "face_limit"?, …}`.
  - The v2/H3 page lists these optional fields: `negative_prompt`, `texture`, `pbr`, `texture_quality`
    `standard|detailed`, `geometry_quality`, `smart_low_poly`, `quad`, `auto_size`, `generate_parts`, `compress`,
    `export_uv`.
  - Whether v3 keeps those exact names is **unverified**; v3 renamed `model_version` to `model`.
- `POST /generation/image-to-model`: `{"file_token", "model":"P1-20260311", "face_limit":5000}` (V example).
- `POST /models/convert`: `{"input": task_id|file_token|url, "format":"GLTF|FBX|USDZ|OBJ|STL|3MF", "face_limit",
  "quad", "texture_size":4096, "texture_format":"JPEG", "pivot_to_center_bottom", "scale_factor", "bake":true}`.
- `GET /tasks/{task_id}` returns `data`:
  - `task_id`, `type`, `status`, `progress`.
  - `output` {`model_url`, `rendered_image_url`}.
  - `credits_consumed`, `created_at`/`completed_at` (ISO 8601).
  - On failure: `error_code`, `error_message`.
- **Status:** `queued`, `running`, `success`, `failed`, `cancelled`. Also treat `banned` and `expired` as terminal
  (the SDK enum adds `unknown`, `banned`, `expired`).
- **Download `model_url` within 5 minutes** of success.
