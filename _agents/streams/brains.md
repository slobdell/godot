# Stream: brains (every unit stops showing itself to a loaded gun; then the CPU's doctrine in open ground, measured for the first time)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (*His pick* is
> your first item's authority), `_agents/unit_ai.md` (*pricing a decision lever* is the method for any A/B),
> `_agents/tank_brain.md`, `_agents/doctrine.md`, `_agents/navigation.md` (rounds 7–15: what was tuned in streets),
> `_agents/streams/archive/round17/brains.md` (your predecessor: *Stretch 1* is B1's diagnosis, *THE VERDICT* is what
> not to re-measure), `_agents/workstreams.md` *Round 18*. You own `game/ai/**`, `game/tactics/**`,
> `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
> `tests/test_nav*.gd`, `mk/ai.mk` minus the perf targets (ship's), `mk/nav.mk`, `mk/tactics.mk`, `_agents/unit_ai.md`,
> `_agents/tank_brain.md`, and at CP1 only the `sim_state_hash.txt` line (C18.1).

## The lead's direction (2026-10-04, in chat; verbatim)

Asked whether units should stop peeking out of cover at a loaded gun, given that the fix makes the CPU harder to beat:

> *"1. Yes make the CPU smarter, this would apply to all units. We want to make the computer opponents hard, but kind
> of like in Gears of War, our friendly players are just as smart, so it just makes the game better."*

**Read plainly, and standing from now on (C18.4):** a decision improvement that applies to every unit on both sides
ships on our evidence; it does not wait for him. Hard opponents are wanted. What stays his: anything that makes the
two sides unequal (a CPU-only advantage or handicap, a difficulty setting's meaning), and balance values (C12.6).

On open ground he has said nothing to you directly; it comes from his map item (`game_design.md` *Round 18 direction*
B): *"with the narrow corridors that exist on all the maps currently I never get to just have vehicles move line
abreast"*, and a centre where *"a line abreast formation could get ambushed by another formation that was
orthogonal"*. The maps stream builds that ground. Your job is that the CPU and his own squads behave in it.

## Where things stand

- **B1's diagnosis (your predecessor, laptop, `ec31e419`, a tick trace, not committed):**
  `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` (`tests/ai_scenarios/scenario_cover.gd:122`)
  has been red since round 15 because the BEHAVIOUR is wrong. x3 and x4 both take 4 hits from the gun's 4 shots in
  30 s. x4's bait goes `out` while the gun is LOADED (`sync_reload` 1.00); the gun turns onto it and fires ~35 ticks
  later; x4 switches to `back` on that tick; the shell lands **14 ticks** later with x4 still in sight; x4 is out of
  sight only ~60 ticks after the shot. Every bait is a hit, and x4 never shoots inside the window it baited for.
  **Why it broke:** round 15's N5 made a gunner lay before firing (up to ~1.6 s), so the bait was changed to "stay
  out until the round is on its way, then duck" (`TankBrain._act` COVER_FIRE, `shot_at`); at duel range a cannon shell
  lands ~14 ticks after leaving and a hull needs ~60 to break sight.
- **It is in his skirmish, on both sides:** the bait applies to any visible contact and the champion `x5p`
  (`game/ai/brain_variants.gd:70`) carries `reload_windows`, so CPU units hand his units free hits and his own units
  do the same from cover.
- **The two rules, ready to try** (predecessor's Status, in full): **Rule A (first):** no bait; peek only while the
  enemy gun is reloading (`contact.gun_ready_in`, `AiTickCache`, `game/ai/ai_tick_cache.gd:257,317`; the peek test is
  at `tank_brain.gd:2269`) or after it fired at someone else. **Rule B (if A loses a ladder):** bait only when the
  shell's flight time exceeds the time to break line of sight (flight = distance / `Shell.speed`, break = the hide
  spot's distance / PEEK_SPEED); at 45 m against a cannon it reduces to A; it keeps the bait against slow or arcing
  guns at range.
- **The scenario as written would still fail under rule A** (this lone gun only fires at x4, so its window opens only
  after it has hit x4): it should assert "no more hits than x3, and every peek starts inside a window", plus a second
  stage with TWO targets (a teammate draws the shot), where rule A should show fewer hits.
- **The launch baseline is `05df1d55ba49cde1`** (glibc 2.43, builder0), determinism `762a0576f944f5b7`. `sim-baseline`
  runs on `foundry` with `sim_baseline_{green,rust}` doctrines; whether that match exercises COVER_FIRE's bait is not
  known: measure it, do not assume the baseline moves or stays.
- **Where the brains assume corridors (your predecessor, from reading, not measured):** (i) the far-unit think rates
  key on `LOD_RADIUS` = 130 m (`tank_brain.gd:30`) and weapon reach, so in open ground more units see each other;
  (ii) movement's planned-reverse / k-turn, chord and guard logic and avoidance's 14 m neighbour radius were tuned in
  12–30 m streets and mostly go idle in the open; (iii) `TacticsFormation.DEFAULT_SPACING` is 12 m and a slot's
  leash is the element's pitch (14 m for tanks), so a line of four needs ~36–48 m, **which has never been played**:
  line-abreast seating and `SlotGround.standable_for` have only run squeezed into lanes; (iv) doctrine's drills fire
  on contact geometry and nobody has checked whether any assumes a wall on one side: read `game/tactics/drills.gd`
  first.
- **Do not re-measure the levers.** None is worth turning on; all ship OFF (`HANDOFF.md`, *the verdict*). What would
  reopen it is exactly B4's ground (long live stretches with the CPU far from any fight), measured on the laptop at
  equal vehicle counts with a bracketed champion: that is a stretch item, last.

## Backlog (in order)

- **B1. No unit shows itself to a loaded gun.** Test first: rewrite the scenario to what the behaviour should be
  (above) and add the two-target stage; both red on today's champion for the right reason. Then rule A in the
  champion. Evidence, all on one tree, both sides running the same brain unless the row says otherwise:
  (a) the scenario pair green, mutation-checked (it fails with the bait back); (b) `make ai-scenarios` and
  `make tactics-drills` counts against `tests/baselines/ai_scenarios_count.txt` (a red scenario becoming green
  updates the count line, declared); (c) `make ai-ladder` new champion against `x5p`, mirror armies, enough games
  for the interval to exclude a loss (state N and the interval; if A does not beat or tie `x5p`, try B, and say so);
  (d) **his frame:** 16 seeds of his skirmish setup, the fixed brain on both sides against today's on both sides:
  hits taken from cover per unit-minute, kills, match length, who wins. He should see fewer cheap hits both ways,
  not a different game; (e) an arm assertion that reads the state the code consults: of all peeks in those matches,
  the share that started with the enemy gun loaded (today: most; fixed: none).
- **B2 = CP1. The declared move.** One commit: the champion's change, the scenario, the count line, `ai-parity`'s new
  reference and, if it moved, the baseline line adopted with `make sim-baseline-adopt` (read twice on builder0). It
  merges ALONE (C18.1). **Name the green hash; say plainly whether the foundry baseline and determinism moved and to
  what.** Ship's per-map lines are re-recorded by the orchestrator on the merged tree.
- **B3. Read the drills and the seating for walls** (reading and scenarios, no map needed): `game/tactics/drills.gd`,
  `TacticsFormation`, `SlotGround.standable_for`, the doctrine tables' terrain class (`make tactics-terrain` prints
  open / lanes / dense). A scenario on a bare 200 m plate (a fixture layout of yours under `tests/tactics/`, or the
  maps stream's first candidate once CP2 lands): a squad of four ordered line abreast 150 m; a wedge; a column. Do
  they form at their own spacing, hold it, arrive together, and keep their guns on the arcs the formation implies?
  Each failure is a named defect with its witness.
- **B4. The CPU in his open centre** (after the orchestrator says CP2 is on `main` and you have merged it): the first
  time doctrine has been measured in open ground. On the maps stream's first candidate, CPU v CPU over paired seeds
  and his skirmish setup: what formation the CPU's elements choose and whether they hold it across the centre; time
  to first contact and its range; whether anyone uses the flanking cover the map was built round (an ambush that
  fires from the flank of a line, counted from `drills.gd`'s events); hits by facing (front / flank / rear); idle in
  contact, drill flip-flops, order thrash (`make squad-coherence`); wall contacts and k-turns (they should fall
  towards zero: `make container-contacts`' probe). Send the maps stream what its map did and did not make the CPU do
  (through the orchestrator): that is its M5.
- **B5. Make the open ground play.** From B3–B4, in order of what he would notice: the CPU crosses the centre in a
  formation that fits it (line or wedge at spacing, not a column by habit); a defender uses the flank cover (the
  ambush task exists for his squads: `ElementTask`; does the CPU's commander ever pick it?); a line that is hit from
  the flank reacts as a formation (the contact drill for a flank), not unit by unit. Each is a decision change for
  every unit on both sides (C18.4): scenario first, ladder or paired series as evidence, declared in merge notes with
  the baseline's and `ai-parity`'s before and after. Changes that only act on candidate maps leave the dealt maps'
  hashes identical: show it (`make container-hashes`).
- **Stretch.** (a) The Sumps' routes for long hulls (`roadmap.md` candidate 3: 449 → 583 scrapes a minute at strength
  B, attributed to routes, not boxes): where, by `make contact-shot`, and a route-cost fix as a declared change.
  (b) The lever verdict's reopening condition on the open candidate, laptop, equal vehicle counts, bracketed champion
  (the orchestrator's quiet-window runs; `make ai-lever-perfplay`). (c) The two other long-red or pending scenarios
  in `ai_scenarios_count.txt`: diagnose each the way B1 was.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe). **Every commit pre-registers MOVED or UNMOVED for the baseline, determinism and
`ai-parity`, before the run** (C18.1): B2 is the one planned mover; B5's items are declared one at a time. One tree
per comparison (C18.5): no ladder, parity or series compares arms across a merge of `main`. A cost or an effect is
attributed only by removal inside one setup, with an arm assertion (lessons 247, and `unit_ai.md`). Every number: its
commit, machine, load, workload, sample.

## Don't touch

`arenas/**`, `game/arena/**`, `tools/make_arenas.py` (maps: a map that breaks the CPU gets a witness sent, not an
edit) · `game/ui/**`, `game/control/**` (picker) · `game/theme/fx/**` (finale) · `mk/core.mk`, the `perf` targets of
`mk/ai.mk`, `tests/baselines/**` other than your CP1 line (ship) · `game/units/units.gd` balance values (C12.6) · the
brain levers' defaults (OFF, his verdict's subject).

## Waiting on the lead

- Nothing. B1's authority is his words above. If rule A or B changes who wins his usual skirmish by more than the
  seeds' spread, say so in Status and to the orchestrator: he should hear it before he plays it.

## Status

_Not started. The worker keeps this section current: plan, done (with measurements), decisions, questions for the
lead, requests to other streams, known issues, what to playtest (exact commands), merge notes, and the green hash._
