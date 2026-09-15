# Bringing a 3D model into Tank Squad

This folder is the art pipeline: how a model you downloaded, generated with AI, or built in code ends up
driving around the arena. You don't need to know Godot well. Each step is one `make` command, and the tools
tell you what's wrong.

## The big idea: slots

The game never uses a model directly. A tank has **slots**, like empty sockets labeled `tank.hull`,
`tank.turret`, and `weapon.cannon`. The arena has `prop.crate` and `prop.wall`. A **theme** decides what model
plugs into each socket. So you can swap every tank's look without touching how tanks drive or shoot.

Every slot has a **contract**, a set of rules the model must follow so it lines up with the game:

```bash
make assets-slots
```

For example, `tank.hull` must be 2.4 m wide and 3.6 m long, sit on the ground, face **−Z** (Godot's "forward"), and use at
most 15,000 triangles (phones draw ten of them at once, with automatic LODs at a distance).

Downloaded models almost never follow these rules. That's fine: the pipeline fixes them.

## Step by step: a model from the internet

**1. Find a model with a license that allows games.** CC0 ("public domain") is easiest. Kenney (kenney.nl),
Quaternius (quaternius.com), and Poly Pizza (poly.pizza, filter by CC0) are good places to look. Download the
**.glb** version into `assets/incoming/`. That folder isn't saved in git, so big downloads are fine.

**2. Look at what you got.**

```bash
make assets-inspect IN=assets/incoming/my_tank.glb SLOT=tank.hull
```

You'll see its size in meters, its triangle count, and its material names, plus a list of broken rules, for example:

```
CONTRACT: size 14.87 × 6.76 × 10.54 exceeds the slot's 2.40 × 1.60 × 3.60
CONTRACT: wider (x 14.87) than long (z 10.54): forward axis is probably wrong
```

**3. Fix it into the slot.**

```bash
make assets-normalize IN=assets/incoming/my_tank.glb SLOT=tank.hull THEME=mytheme \
     ARGS="--forward=-x --exclude=turret,gun --tint=Main --license='CC0' --source='https://…'"
```

What those extra settings mean:

| setting | what it does |
|---|---|
| `--forward=-x` | which way the model's front points. Try `+z`, `-z`, `+x`, `-x` until the gallery shows the gun pointing the right way |
| `--exclude=turret,gun` | leave out parts by name (the turret is its own slot) |
| `--include=turret` | keep *only* parts with that name |
| `--scale-from=tank.hull` | give the turret the same scale the hull got, so they match |
| `--tint=Main` | the material that turns into team color |
| `--emissive=Light:4` | make a material glow (neon!) at brightness 4 |
| `--repeat=4x1x1` | line up 4 copies side by side (a long wall from short pieces) |
| `--license`, `--source`, `--credit` | where it came from. **Required.** Also add a row to `assets/CREDITS.md` |

This writes `game/theme/mytheme/generated/tank_hull.glb` plus a small scene that knows how to paint it in team colors.

**4. Look at it.** (These open a window for a few seconds and save a picture.)

```bash
make assets-gallery THEME=mytheme      # your models next to the default boxes, with the slot outline
make assets-preview THEME=mytheme FLAGS=--skirmish     # a screenshot of the real game using your models
```

Pictures land in `build/screenshots/`. In the gallery, the **red dot** is where shells come out. It should
sit at the tip of your cannon.

To *play* with your theme instead of taking a screenshot:

```bash
.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . res://assets/pipeline/theme_preview.tscn -- --theme=mytheme --skirmish
```

**5. Check everything, then commit.**

```bash
make assets-check     # every generated theme follows every rule
make check            # the whole game still works
```

## Other ways to make models

- **Build them in code:** `assets/pipeline/procedural_kit.gd` makes neon containers, barriers, and billboards from
  boxes and cylinders. Copy one function, change the numbers, and run `make assets-procedural`.
- **AI generation with Meshy** (paid account; key in `MESHY_API_KEY`). This is how the prison dozer was made; the full flow and
  exact commands are in `_agents/streams/references/asset_prompts.md`, and the style rules in `_agents/art_direction.md`:
  1. make a photoreal concept image, then look at it (`tools/assets/generate.py --concept-only --prompt "…"`);
  2. turn the one you like into 3D (`--image-task <concept id> --smart-topology`);
  3. split and fit it with a recipe like `tools/assets/build_prison_dozer.sh`, then look at it with `make assets-unit THEME=…`.

  Extra settings for whole generated vehicles:

  | setting | what it does |
  |---|---|
  | `--split=tank` | the generator gives one big mesh; this cuts it into hull, turret, and cannon pieces |
  | `--deck-from=tank.hull` | lifts the turret and gun onto a tall hull's roof |
  | `--attach-to=tank.turret` | keeps the gun exactly where it was on the turret, stretched to where shells come out |
  | `--emission-energy=4` | makes generated neon bright enough for the night arena |
  | `--tint-strength=0.2` | how much team color shows through the dirt (0 = none, 1 = fully painted) |

  If an agent can't see your key, see *Proposed orientation trip-ups* 5 in `_agents/streams/archive/round1/assets.md`.

## The lead reviews every concept before 3D (round 2)

3D models cost real credits; concept images are cheap. So every new model waits at the concept stage until the
lead has looked at it ([`_agents/workstreams.md`](../_agents/workstreams.md), *Lead gates*):

```bash
make art-concept NAME=scout_a GROUP="X4 roster" TARGET_SLOT=unit.scout TITLE="Scout A: …" PROMPT="…"  # ≈9 credits
make art-review            # build/review/index.html: every concept, its prompt, slot, and estimated 3D credits
make art-review-status     # the same list in the terminal, plus the credits spent
make art-decide ID=scout_a DECISION=approved WORDS="the lead's own words"   # or rejected / superseded
tools/assets/generate.py --provider meshy --slot unit.tank --review-item scout_a --smart-topology --name meshy/scout
```

- `assets/review/review.json` holds the items and decisions; `assets/review/images/` the pictures the lead saw.
- `generate.py` refuses a 3D request without an approved `--review-item`, and refuses a second 3D request for the
  same concept (unless `--retry-reason` says why). It sends the approved concept, not whatever image you name.
- Every Meshy request, concept or 3D, is appended to [`meshy_ledger.md`](meshy_ledger.md) with the credits it
  cost and the balance left.
- Scenes and mood pictures (not models) need `KEEP_BG=1`: background removal erases a whole scene.

## Round 2 recipes and tools (art stream)

| command | what it does |
|---|---|
| `make assets-view IN=assets/incoming/meshy/x.glb [SPLIT=1 FORWARD=+x]` | turnaround of a raw download (and how it would split) before normalizing |
| `make assets-unit THEME=roster UNIT=ifv` | close-up of one unit assembled at its own turret pivot, with the muzzle marked |
| `make assets-roster` / `make assets-arena-kit` / `make assets-prison-dozer` | rebuild the generated themes from the Meshy sources in `assets/incoming/meshy/` |
| `make assets-ground` / `make sfx` | rebuild the arena floor textures (CC0 ambientCG) / the synthesized sounds |

Extra normalize settings for units and props:
- `--split=regions --turret-box=… --cannon-box=…`: label parts by position, for when the tank heuristic can't read
  them.
- `--place-from=unit.<id>.hull [--center] [--shift-from=…] [--stretch]`: keep a turret or gun where the generator
  put it.
- `--textures-from=<slot>`: one texture set per unit.
- `--texture-caps=normal_texture:512,…`: smaller maps for the web download. Extracted ORM and normal maps also
  import at most 512 px.

## When something looks wrong

| you see | try |
|---|---|
| the tank drives sideways or backwards | a different `--forward` |
| the tank is lying on its side | `--up=+z` (some tools export Z-up) |
| team color paints the wrong parts | `make assets-inspect` to see material names, then change `--tint` |
| it's tiny or huge | it's probably including something extra (a ground plane?); use `--exclude` |
| "over the budget" | the pipeline already simplified it; pick a simpler model if it still looks bad |
| a wall looks see-through | shells still hit the invisible collision box, which confuses players; use solid-looking pieces |

## Where things live

| path | what |
|---|---|
| `assets/incoming/` | raw downloads (not in git) |
| `assets/pipeline/` | the tools (Godot scripts): contracts, inspector, normalizer, checker, gallery, procedural kit |
| `assets/runtime/generated_visual.gd` | the script that paints team colors and makes things glow in the game |
| `assets/CREDITS.md` | who made every model and its license |
| `game/theme/<theme>/generated/` | finished models + `manifest.json` (where each came from) |
| `tools/assets/` | AI generator clients (Python) and a fake server to test them |
