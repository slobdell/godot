# Concept review: the lead picks before anything is built in 3D

> Art stream, 2026-09-14. The lead, after review #1: *"whatever you did to give me the 3 choices of assets to choose
> from per item - that was amazing"*, and wants the same for every new unit. This is that process, step by step.
> It implements the Meshy lead gate in [../../workstreams.md](../../workstreams.md). The style rules are in
> [../../art_direction.md](../../art_direction.md) and the prompt structure in [asset_prompts.md](asset_prompts.md).

## Why it works

- **Choices, not a yes/no.** Each slot (a unit, a prop, a piece of the arena) gets 2–3 genuinely different
  directions side by side. Picking is fast and fun; judging one image in isolation is not.
- **Cheap before expensive.** A concept image costs ~9 credits; a textured 3D model ~15, plus an hour of pipeline
  work. Nothing goes to 3D without a tap from the lead, and nothing goes twice (`generate.py` enforces both).
- **Tap-to-approve on a phone.** The lead reviews on a private web page (a Claude Artifact) wherever they are.
  Their taps are saved, and the agent reads them back. Nobody has to relay messages.
- **Everything is recorded:** prompts, images, decisions with the lead's words, and every credit spent.

## The process

### 1. Plan the slots and directions

For each new model, write down the slot it fills (e.g. `unit.burner`, `prop.scrap`) and 2–3 directions:
- **3 directions** for headline units (the ones players buy and recognize), **2** for supporting units, and **1** for
  props and arena pieces unless the look is uncertain.
- **Each direction is a different recognizable real vehicle or object**, brutally converted (art_direction.md). For
  the round-1 scout: a desert trophy truck, a caged dune buggy, a police muscle car. Don't make three variations of
  one idea.
- **Keep the weapon and the gameplay facts fixed** across directions (fixed hood gun, fast 30 mm turret…). Only the
  base vehicle and its character change.
- **Give each option a one-line tradeoff note**: what reads well from the RTS camera, what's risky. E.g. *"Closest
  to the Death Race films"* or *"Risk: close to the dozer's prison-bus silhouette."* The note shows on the card and
  is what the lead actually decides with.
- Optionally add one **mood picture** (a whole scene, `EST_3D=0`) when a new area or lighting direction needs
  agreement. It's never sent to 3D.

### 2. Generate the concepts

Use the art-direction prompt skeleton: keep everything, swap the base vehicle and weapon (asset_prompts.md), and
always end with the full-vehicle / studio-background / photoreal tail.

```bash
make art-concept NAME=burner_a GROUP="Burner" TARGET_SLOT=unit.burner EST_3D=15 \
     TITLE="Burner A: armored fuel tanker with a flame cannon" \
     NOTES="Huge tank on the back reads as 'explodes nicely'; slow silhouette." \
     PROMPT="Photorealistic concept art of an arena death-race flamethrower vehicle, ... (asset_prompts.md tail)"
```

- **`GROUP` is the slot the options compete for** ("Burner", "Scrap pile"), not the round. The page shows one
  group per slot, and "approve at most one per group" relies on it.
- **Mood pictures and whole scenes need `KEEP_BG=1`.** Background removal erased the first arena scene.
- **Many at once:** run `tools/assets/generate.py --concept-only` calls in parallel (Meshy allows 10 concurrent tasks),
  then register each with `tools/assets/review.py add …` one at a time. The manifest isn't safe for parallel `add`s.
- Every request lands in `assets/meshy_ledger.md` with its cost.
- Group descriptions: add `"group_notes": {"Burner": "one line about the slot's job"}` to `assets/review/review.json`.

### 3. Look at every image before the lead does

- Open them, or make a contact sheet.
- **Regenerate failures** under a new id and mark the bad one superseded
  (`make art-decide ID=… DECISION=superseded`). Failures include: cartoon or toy look, garbled text, the weapon
  missing or doubled, a cropped vehicle, or a scene erased by background removal.
- The lead should only see good options.

### 4. Build and publish the review page

```bash
make art-review-page TITLE="Concept review #2"      # build/review_page/index.html + images/ (waiting concepts only)
```

Publish it as a **private Artifact with a database**, so the lead's taps are saved. From a Claude Code session, use
the Artifact tool with:
- `file_path`: `build/review_page/index.html`
- `files`: every `images/<id>.jpg` the page references (`"images/burner_a.jpg": "build/review_page/images/burner_a.jpg"`, …)
- `capabilities`: `{"db": {}}`, which saves each tap to the collection `decisions/<item id>` = `{decision, words, at}`
- `favicon`: `🚧` (review #1's), `description`: one sentence naming the round

Use a new page for each review round. Then:
- **Tell the lead in one message:** the link, what's on it, "tap Approve on at most one option per group, add words
  if you like", and the estimated 3D spend.
- **Write the round under *Waiting on the lead*** in your stream brief: the URL, the ids per group, the estimated
  credits.
- **Stop those items and keep working** on ungated work. Never wait on the lead (workstreams.md, *Unattended runs*).

Without the Artifact runtime (a plain browser opening the file), the page still renders read-only and asks for picks
in chat. `make art-review` builds the older static sheet (`build/review/index.html`) for the same purpose.

### 5. Read the lead's taps back and record them

When the lead says they're done, or whenever you check in, save the decisions and apply them:
- Artifact tool: `action: "read_db"`, `url: <page>`, `db_op: "list"`, `collection: "decisions"`,
  `out_dir: <scratch folder>`
- then run:

```bash
make art-apply-decisions DIR=<that scratch folder> URL=<page url>
make art-review-status          # the approved / rejected table
```

- `apply` quotes the lead's words and the page URL into `assets/review/review.json`. A tap with no words is
  recorded as "Approved on the review page … (tapped Approve, no comment)".
- Decisions given in chat instead: `make art-decide ID=… DECISION=approved WORDS="their words"`.
- **Copy the decisions into the brief** (approved and rejected ids, with the lead's words) and commit
  `assets/review/`.

### 6. Build only what was approved

```bash
tools/assets/generate.py --provider meshy --slot unit.tank --review-item burner_a --smart-topology \
    --polycount 15000 --name meshy/burner_a_t2          # image-to-3D meshy-t2, textured (~15 credits)
```

- `generate.py` refuses unapproved items, refuses a second 3D request per concept (`--retry-reason` if a task
  failed), and sends the approved concept itself.
- Meshy concept tasks expire ~3 days after creation. For a later approval, pass the committed image instead:
  `--image assets/review/images/<id>.jpg`.
- Then the pipeline:
  - `make assets-view IN=… SPLIT=1` to look at the raw model.
  - A recipe like `tools/assets/build_roster.sh` to split and fit it into slots.
  - `make assets-unit UNIT=<id> THEME=roster` to look at the result.
  - `make assets-check`.
- The whole round-1 path, concept to in-game, is in `streams/archive/round2/art.md` (Status).

## Round 1 for reference (2026-09-14)

- **Page:** https://claude.ai/artifact/Hg4RfJSgmP1xeJvfokkJk1
- **What was on it:** 17 concepts, 162 credits (3 directions for scout and IFV, 2 for artillery and Lancer, 1 each
  for arena pieces and props, plus one mood picture).
- **Timing:** the lead decided all 17 in ten minutes on the page.
- **Outcome:** 10 approved and built (150 credits), 6 rejected.
- **Records:** `assets/review/review.json` and `assets/meshy_ledger.md`. `make art-review-page ALL=1` rebuilds the
  page with the decisions.
