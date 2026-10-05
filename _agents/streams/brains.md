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

_Last updated 2026-10-04 (brains worker). Every number: commit, machine, workload, sample._

### Plan (order taken)

1. **B1** — scenario first (red on `x5p` for the right reason), rule A as a feature switch (`no_loaded_peek`) in a new
   variant `x18a` = `x5p` + the switch, made the champion; evidence (a)–(e) on one commit.
2. **B2 = CP1** — squash into ONE commit (champion, scenario, count line, `ai-parity` reference, baseline line), green on
   builder0, message the orchestrator. Merges alone.
3. **B3** — reading (drills, `TacticsFormation`, `SlotGround`) + a bare-plate fixture scenario (line / wedge / column, 150 m).
4. **B4/B5** — after CP2 (maps' candidate 1) is on `main` and the orchestrator says merge.
5. Stretch (c) → (a) → (b).

### Pre-registered for CP1 (written BEFORE the builder0 runs; C18.1)

- **sim-baseline (foundry): MOVED.** Measured, not assumed: the baseline's own match (`SIM_HASH_READ`'s flags + census,
  laptop glibc 2.39, `cc236ba4`) runs COVER_FIRE on the rust side (x5p: 3 peeks, 135 cover unit-ticks; x18a: 1 peek, 90)
  and its hash differs between the arms (`5f81684d9c38cb45` x5p, `e95a523239b48e60` x18a; laptop line only, builder0's
  is the record). The census flag itself leaves the hash identical (x5p with and without: `5f81684d9c38cb45`).
- **determinism: MOVED** (same match family). **ai-parity: MOVED** (the champion changes on yard and terminus).
- **ai-scenarios count:** `43,1,3,0` → `45,0,3,0` expected (the long-red reload scenario is replaced by TWO scenarios that
  pass; nothing else should move — to be confirmed by the check).

### Merged so far, and what is next (2026-10-04, late)

- **A = "his squads on a task arrive" (D4 + D5) is on `main` as `5e9e6317`** (merged alone by the orchestrator, 23:10
  PDT). Green at `a6564bc6` (= `f4daada0` + the 3-re-seat cap, on `f6c6a282`): builder0, 23 targets ALL JUDGED, 2036/0,
  engine 0/0, all seven lines and determinism unmoved as pre-registered. `f4daada0` alone was green the same way.
- **First after B (the orchestrator's order):** D5's re-seat fires unneeded on the Sumps for the Law two-scout squad
  (19.9 s with D4 alone → 37.0 s with D5, 7 re-seats over 4 runs; scenario to write: that squad, 150 m, arrives in
  ~20 s with 0 re-seats), with the Cut's seed 3 beside it (re-seats capped at 3; stops 105.1 m short at (−4.1, 44.9),
  one crew 18.5 m off its slot beside a block's west face in open ground — maps: 111 m of drivable width there).
- **maps' candidate table** (laptop, `f4daada0`, his attack-move 150 m forward from the Green spawn, 180 s, seeds 1–4;
  arrived k of 4, median s, re-seats): parade tanks 4/4 14.1 s 0, IFV mix 4/4 18.5 0; yard_open 4/4 13.8 0, 4/4 15.9 0;
  archipelago 4/4 15.3 0, 4/4 20.7 4; docks 4/4 21.1 0, 4/4 18.3 0; gorge 4/4 35.0 5, 4/4 33.0 4; cut 3/4 46.1 25, 4/4
  29.1 2; sumps 4/4 39.8 5, 4/4 38.6 4. Parade and yard_open are open ground for a tasked squad (no file forms).

### D5b (`55fd368f`, after CP1; declared, pre-registered UNMOVED on the seven lines, determinism, ai-parity)

The orchestrator's first item after B: D5's re-seat cost the Law two-scout squad on the Sumps ~17 s (19.9 s with D4
alone → 37.0 s). **Trace (seed 1):** the crew not closing was a wheeled scout pinned on a wall — its velocity read
~14 m/s while it stood still — with NO squadmate in its way; the re-seat swapped two OTHER crews. **By removal:**
without issued-slot closing-up the scout mix is 18.8–21.4 s but the four tanks never arrive; with it alone, the tanks
arrive and the scouts wait. **Fix:** a re-seat only when a squadmate stands within 14 m ahead on the crew's line to
its slot (±4 m); a crew is closed up at the nearer of its nominal and grounded slot. Laptop, Sumps, 150 m, 120 s,
seeds 1–4: scouts 18.8–20.5 s, 0 re-seats (was 34.8–40.0 s, 1–2 each); tanks 36.5–47.3 s, 1–2 re-seats. Scenario
`test_a_two_scout_squad_across_the_sumps_arrives_without_needless_re_seats` (red on `a6564bc6`: 34.8 s, 1 re-seat).
The full 80-run table and the Cut's seed 3 are being re-read on it.

### CP1 = B (x18m), adopted (2026-10-04 23:06–23:58 PDT, builder0, on A at `a6564bc6`)

`make sim-baseline-adopt` at `2d80c4c0`, every dealt map read twice, agreeing: **foundry `05df1d55ba49cde1` →
`5d8191d5aacc4027`, yard `797dc49109a452d8` → `e0393e53918debc1`, pit `098f7d5cb3795e7f` → `e03377eab0ab0389`;
terminus `8b0309ee85e497dc`, crossing `efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks `db5512352146803e` UNMOVED**
(measured cause: those maps' 40 s baseline matches take no bait, so x5p and x18m decide them identically).
ai-scenarios **43,1,3,0 → 45,0,3,0** (the recorder wrote 44,0 because `scenario_perf` was not judged on a busy
builder0 and the record path, unlike the check path, does not count a not-judged scenario: reported to ship; the line
is the one the check computes). ai-parity's new reference: digest `be19105bbe16d10100e09f698c4027b1` (16 matches, yard
and terminus, seeds 1–8), `references/round18/brains/parity-x18m-2d80c4c0-builder0.jsonl`.

### CP1 pre-registration on the MERGED tree (written before the run; champion x18m; `b3464e32` = main-checked 23941d90 + B1)

Every dealt map's fights are cover fights between slow guns, and x18m changes COVER_FIRE's bait, patience peek, duck
and timeout. **Expected MOVED: all seven per-map lines** (foundry — already measured moving on the launch tree — plus
yard, pit, terminus, crossing, sumps, locks); **determinism MOVED** on both of its maps (foundry, crossing); **ai-parity
MOVED** (yard, terminus). A line that stays unmoved is reported as a finding about that map (no bait/peek decision in
its 40 s), not as a failure. Candidates (parade, gorge, archipelago, cut) have no lines (C18.2).

**Read (builder0, `24b52c8a` = `b3464e32` + Status, 2026-10-04 18:01–18:27 PDT, `make check exited 2`):** only the two
pre-registered movers failed; 2016 tests passed, 0 failed; SHARD-ENGINE 0 errors 0 warnings in all five shards.
sim-baseline: **foundry `05df1d55ba49cde1` → `5d8191d5aacc4027`, yard `797dc49109a452d8` → `e0393e53918debc1`, pit
`098f7d5cb3795e7f` → `e03377eab0ab0389` MOVED; terminus `8b0309ee85e497dc`, crossing `efc8449e97b18eb1`, sumps
`bf0bdb98568700db`, locks `db5512352146803e` UNMOVED** — four of the seven predictions were wrong: the 40 s baseline
match on those maps takes no COVER_FIRE bait or peek decision that x18m changes (a finding about the instrument's
reach, not a failure; the Sumps ladder shows x18m does change his fights there). Determinism printed `762a0576f944f5b7`
(unmoved). **The cause, measured** (laptop, glibc 2.39, `7319dded`, each map's own baseline match — sim_baseline doctrines,
40 s, seed 3 — with `--brains-census`, both sides x5p then both x18m): terminus, crossing, sumps and locks run
IDENTICAL matches under the two brains (same laptop hash each) and their census holds no bait at all (peeks: terminus
1, crossing 0, sumps 3, locks 2, every one an ordinary window peek); foundry, yard and pit each hold a bait under x5p
(1, 2, 2) and their hashes differ. **And a limit of x18m it showed:** on locks both brains begin one peek at a loaded
gun ACTUALLY laid on the spot (`at_laid` 1 under each): the decision reads the team's last-known turret
(`contact.turret_forward`, intel), which had gone stale while the gun turned unseen. x18m's "never into a laid gun"
is "never into a gun KNOWN to be laid". ai-scenarios: **43,1 → 45,0** (3 pending), as pre-registered. Not yet adopted: CP1 is named only after
both gates read and the adopted lines are checked.

**Gate tallies (x18m v x5p; a draw is half; 95 % Wilson):** mirrors — individuals 53–43 (96; laptop, seeds 1–8 +
101–116; 55.2 %, 45.3–64.8), armor 30.5–33.5 (64; builder0; 47.7 %, 35.9–59.7), balanced 33–31 (64; builder0; 51.6 %),
swarm 32–32 (64; builder0, merged tree; 50.0 %); **pooled 148.5 of 288 = 51.6 %, 45.8–57.3 %: the mirror gate passes
(lower bound > 45 %, lowest army 47.7 % ≥ 45 %)**. Read as what it is: a TIE with x5p, not a stronger brain. His army — seeds 201–208 **12–20** (re-run on the merged tree
reproduces the pre-merge total exactly; per way, x18m as green normal 5–3, green swapped 1–7, rust normal 2–6, rust
swapped 4–4) and seeds 209–216 **20–11–1**: **32.5 of 64 = 50.8 %, gate (≥ 45 %) passes**; the seed set matters more
than the brain here (one set 38 %, the other 64 %).

**Evidence (d)+(e), his frame** (builder0, merged tree `9cdab90f`, `ai-lever-behaviour PRICE_ARMS=x5p,x18m
PRICE_SEEDS=1801-1816 PRICE_TIME=300`: the Sumps, Law (green) v Condemned (rust) at 4600, both sides on one brain,
16 seeds a brain, 2026-10-04 18:55–19:26 PDT):

| | x5p Law | x5p Condemned | x18m Law | x18m Condemned |
|---|---|---|---|---|
| peeks + baits begun | 160 | 361 | 113 | 297 |
| …at a loaded slow gun LAID on the peek spot (truth) | 20 | 23 | 3 | 4 |
| baits (hit) | 51 (26) | 99 (57) | 22 (13) | 51 (28) |
| hits taken on a real peek | 6 | 23 | **20** | 14 |
| hits within 3 s of showing itself, per unit-minute | 0.148 | 0.279 | **0.259** | 0.167 |
| hits while fighting from cover, per unit-minute of it | 11.5 | 14.7 | **17.3** | 11.9 |

Same game: kills median 28.0 both; length median 116.8 / 116.4 s; Condemned wins 12 of 16 (x5p) / 14 of 16 (x18m).
**Read:** the thing he would see — a unit showing itself to a gun already aimed at its spot — falls from 43 to 7 in 16
matches (2.7 → 0.4 a match; not 0 because the decision reads last-known turrets). Free hits overall 0.227 → 0.202 a
unit-minute, but NOT both ways: Condemned's fall, **Law's rise** (and Law's hits on real peeks 6 → 20). Suspected
cause: a peek's window is its TARGET's reload, and a second loaded gun watching the corner shoots anyway (Law fights
the Condemned's many guns). **x18w** (`9db8c0ee`) = x18m + `all_guns_window` (every known slow gun watching me, in
reach, must be reloading); its his-frame series is running with x5p in the same series as the digest control. A
two-gun wall stage could not be built in `scenario_cover` (against two guns the durable subject fights in the open,
ENGAGE, and never takes COVER_FIRE: 39 hits, 0 peeks, identical for both brains): removed, not committed.

**The x18w rule (the orchestrator's call, written before its series reads; x18w is the last variant this round):**
x18m is NOT named CP1 with Law's cost. x18w ships if, per side, hits within 3 s of showing per unit-minute as PAIRED
per-seed differences against x5p on the same 16 seeds have a mean whose 95 % interval is NOT wholly above zero, AND
the pooled rate is down, AND laid-gun showings stay near x18m's 0.4 a match, AND both ladder gates re-read for x18w
pass (mirror pool and his army, same rule as before). Otherwise B1 is HELD with its write-up, the red scenario stays
red with its diagnosis updated, and the round's one planned hash move passes to D4.

**The rule REVISED (the orchestrator, after x18m's paired intervals; written before any of the new seeds run):** the
16-seed series cannot tell +75 % from zero (x18m − x5p, hits within 3 s of showing per unit-minute: Law +0.107
[−0.109, +0.322], Condemned −0.122 [−0.269, +0.025], pooled −0.048 [−0.182, +0.087]; laid showings 2.69 → 0.44 a match),
so x18m is back in and the series grows to 48 seeds (1801–1848) for x5p, x18m and x18w, the same seeds for all three,
paired against x5p. **A variant ships if** no side's paired interval is wholly above zero, AND laid-gun showings stay
under 1 a match, AND its ladder gates pass (x18m's have; x18w needs its own). "Pooled down" is dropped (a coin at this
power). The claim, if it ships: "stops showing itself to an aimed gun, at no measured cost in hits or wins". **If both
pass, x18m ships** (simpler, ladders done); x18w replaces it only if its paired difference against x18m is below zero
with an interval excluding zero on some side. If x18m's Law interval is wholly above zero and x18w's is not, x18w ships
after its ladders. If both fail, B1 is held. **Cost:** 96 matches ≈ 93 builder0 slot-minutes (the 16-seed series:
32 matches in 31 min), run as three holds of ≤ 33 matches (seeds 1817–1826, 1827–1837, 1838–1848), each all three brains.

**x18w, seeds 1801–1816** (builder0, `9db8c0ee` tree, x5p re-run in the same series as the control: digest
`77bb566d…` identical to the x18m series, so the tree change left x5p's fights untouched): laid showings 2.69 → 0.38 a
match; hits within 3 s of showing per unit-minute Law 0.148 → 0.136, Condemned 0.279 → 0.133; paired x18w − x5p: Law
−0.010 [−0.118, +0.099], Condemned −0.141 [−0.312, +0.031], pooled −0.102 [−0.229, +0.026]; Law's hits on real peeks
6 → 6 (x18m: 20). Kills 28.0 median, Condemned wins 14 of 16. The 48-seed holds decide (the rule above).

**THE 48-SEED RESULT (decides B1; builder0; seeds 1801–1816 from the two 16-seed series, 1817–1848 in three holds
with all three brains each, 2026-10-04 19:57–21:34 PDT; his frame, both sides on one brain; paired per seed against
x5p; hits within 3 s of showing itself per unit-minute, mean and 95 % t interval):**

| | Law | Condemned | pooled | laid-gun showings a match |
|---|---|---|---|---|
| x18m − x5p | −0.019 [−0.108, +0.071] | −0.118 [−0.207, −0.030] | −0.084 [−0.141, −0.027] | 2.88 → 0.60 |
| x18w − x5p | −0.075 [−0.161, +0.011] | −0.151 [−0.216, −0.086] | −0.124 [−0.180, −0.068] | 2.88 → 0.46 |
| x18w − x18m | −0.056 [−0.141, +0.028] | −0.033 [−0.098, +0.032] | −0.040 [−0.090, +0.010] | |

By the rule written before the seeds ran: x18m passes (no side's interval wholly above zero; laid showings under 1 a
match; its ladder gates passed) and so does x18w, whose difference from x18m excludes zero on no side — **x18m ships**.
Law's 16-seed rise (+0.107) was the seeds' spread. **Claim:** "stops showing itself to an aimed gun (2.9 → 0.6 a
match), at no measured cost in hits or wins". **Said plainly:** with both sides on one brain, Law (his faction in this
setup) won 16 of 48 under x5p and 11 of 48 under x18m; the ladders call x18m a tie with x5p; read it as within the
seeds' spread, not as proven equal.

### B1 — what was built (`cc236ba4`, WIP; squashed into CP1)

- **`x18a`** (`game/ai/brain_variants.gd`) = `x5p` + `no_loaded_peek`. In `TankBrain._act` COVER_FIRE, under the switch:
  no bait; patience (`PEEK_PATIENCE_TICKS`) no longer opens the window (`_window_open`); a committed peek ducks once the
  watched gun would be loaded before the hull is out of its sight (`_loaded_on_me_within`, distance / PEEK_SPEED +
  `DUCK_MARGIN_S` 1.0 s: the trace showed ~5 m of backing take ~2.6 s); waiting in cover while a loaded gun watches the
  corner is not a stall (`_timed_out` restarts COVER_FIRE's clock from `_cover_denied_tick`; without it COVER_FIRE timed
  out after 10 s and ENGAGE drove the unit out at that loaded gun); the COVER_FIRE target stays in the fight as long as
  the team remembers it (`COVER_DENIED_MEMORY_TICKS` = `Match.CONTACT_MEMORY_TICKS`, 12 s, was 8: at 8 s it fell out
  and ADVANCE drove out at the same gun).
- **Decided, with the reason:** "a loaded gun" means a SLOW gun (reload ≥ 1.5 s, `SLOW_GUN_RELOAD`) that is loaded AND
  watching me (turret within ~20°). A loaded gun pointed elsewhere is a window (it must traverse and lay); fast guns are
  not timed (unchanged). A unit whose team has FORGOTTEN the gun (12 s, `Match`'s intel, not ours) goes and looks: that
  is ADVANCE, a separate decision, counted apart in the scenario (`other_at_loaded`), not a peek. A first try kept the
  gun in the brain's own memory for 20 s: it only delayed the re-look and cost `fights_from_cover` its second exchange,
  so it was removed.
- **The scenario** (`tests/ai_scenarios/scenario_cover.gd`): the old `test_peeking_while_the_enemy_reloads_takes_fewer_hits`
  is replaced by `test_peeking_never_shows_itself_to_a_loaded_gun` (lone gun, 30 s: the champion never peeks into a
  loaded watching gun, no more hits than x3) and `test_a_teammate_drawing_the_shot_gives_a_window_that_costs_fewer_hits`
  (a durable teammate in the open draws the gun's fire, three spots × 40 s summed: fewer hits than x3, ≥ 3 shots a run,
  no loaded peek). A peek = coming into the gun's sight after ≥ 10 ticks out of it while the brain is in COVER_FIRE.
- **Evidence (a), laptop, `cc236ba4`, `make ai-scenarios FILTER=scenario_cover`:** x18a — lone gun: 1 hit, 2 shots,
  0 peeks at a loaded gun (x3: 4 hits, 4 shots); teammate stage: 4 hits, 12 shots, 14 peeks, 0 at a loaded gun (x3:
  6 hits, 16 shots). **Mutation (champion set back to x5p): both RED** — lone gun 3 of 3 peeks at a loaded gun; teammate
  stage 13 hits vs x3's 6. The two older cover scenarios pass on x18a (hidden 81 %, 2 shots, 2 returns).
- **Instrument:** `--brains-census` now also prints `BRAINS_PEEK green {...}; rust {...}` (peeks begun, at a loaded slow
  gun, at one watching me, unit-ticks in COVER_FIRE, hits taken there); `tools/ai_lever_price.py` prints `AI_PEEK`,
  `AI_LEVER_LENGTH` from it. First reading, laptop, `cc236ba4`, Sumps Law v Condemned 4600, seed 1801, 60 s, x5p both
  sides: 53 peeks, 11 at a loaded slow gun, 5 of them at one watching (so "most" in the brief is not what this match
  shows: ~1 in 5, ~1 in 10 watching).
- **x18a's first builder0 check** (`cc236ba4`, 2026-10-04 15:22–16:04 PDT, exit 2): sim-baseline MOVED as
  pre-registered (`05df1d55ba49cde1` → `5d8191d5aacc4027`), determinism moved (`762a0576f944f5b7` → `7e36eebddd2642ac`),
  engine 0 errors; three failures, two of them real defects of mine, fixed in `c0c52888`: `_timed_out`'s guard read the
  `-1` sentinel as a tick (`scenario_orders::test_no_option_is_kept_forever`; harmless in play, where a choice's
  `since` is never negative), and `test_ai_levers` compared the round-17 levers with CHAMPION (they are x5p plus one
  lever, priced on x5p; the test now names that base).
- **Evidence (c), first ladder — rule A LOSES:** builder0, `ai-ladder AI_VARIANTS=x18a,x5p AI_RUNS=8
  LADDER_DOCTRINE=individuals` (tree `c0c52888`), 32 games: **x18a 7–25 against x5p**; x18a 353 shots / 84 kills,
  x5p 434 / 141. The games last ~26 s (five cannons a side) and x18a fires half as often early: waiting for a reload
  window is too passive when the enemy's guns are nearly always loaded. Next: rule A in parts (`da085ed4`: `no_bait`,
  `no_patience_peek`, `duck_early`, `denied_wait`, each defaulting to `no_loaded_peek`; x18a unchanged, the cover
  scenarios read identically) — x18n (no bait only), x18p (+ no patience peek), x18d (+ the early duck) on the same
  ladder; then rule B if no part ties.
- **The parts, and where the bait's value is** (laptop, individuals mirror, 32 games each, 2026-10-04 16:44–16:55 PDT):
  x18n (no bait, nothing else) **9–23** against x5p (`da085ed4`): the bait itself is worth games. Census, four x5p
  mirror games (seeds 1–4, 240 s): **11 of 57 baits were hit (~19 %)** — in a brawl the watching gun is usually busy
  or must traverse, and the drawn reloads are the squad's windows; the lone-gun stage (a gun with nothing else to do,
  laid on the corner) is the case where every bait is hit. x18a on the armor mirror (builder0): **16–16**.
- **The rule that targets the sure hit:** `no_laid_bait` — no bait into a gun already LAID on the peek spot (its turret
  within ~12° of it: no traverse, barely a lay, a duck cannot beat the shell). x18l = x5p + that: **15–16–1** (laptop,
  `4b3bc128`). It alone still peeks into the lone gun (3 of 3). **x18m = rule A with the bait kept except into a laid
  gun** (`no_loaded_peek` + `no_bait: false` + `no_laid_bait`): lone gun 0 loaded peeks, 2 hits (x3 4); teammate stage
  6 hits vs x3's 6 (the "fewer" assertion fails: a tie); ladder **14–18** (32 games, share 0.44, 95 % ≈ 0.28–0.61:
  not enough to exclude a loss). Bigger runs below.
- **More games, fresh seeds 101–116** (laptop, `4b3bc128`, individuals, 64 games a pairing): **x18m 39–25 against
  x5p**, x18l 38–26, x18m–x18l 32–32; kills x18m 471, x18l 478, x5p 409. x18m over both individuals runs: **53–43**
  (96 games). Armor (builder0, seeds 101–116): **x18m 30–33–1**. x18a over three armies: 7–25, 16–16, 14–18.
- **The teammate stage, corrected** (`5c24cfc9`): the (-19,-3) teammate's line from the gun ran 3.5 m from the hide
  spot, so shells aimed at it hit the subject behind its wall (x3 and the champion alike); moved to (-10,-3) (line ≥ 6 m
  clear). With clean geometry every careful brain takes **3 hits** over the three spots (x3, x18a, x18m) and **the bait
  brain x5p takes 9**: x3 has no reload windows but never baits either, so "fewer than x3" was the wrong bar. The stage
  now asserts: no more hits than x3, fewer than x5p, no peek into a loaded watching gun, ≥ 3 shots a spot. x18m: all
  four cover scenarios green; with x5p as champion both B1 scenarios are red (mutation).
- **The candidate is x18m, and it departs from the brief's letter — said plainly:** it never takes a REAL peek into a
  loaded slow gun watching it (no patience peek, an early duck, a denied wait is not a stall), and it never baits a gun
  already laid on its peek spot; but it still BAITS a loaded gun that would have to traverse (8–20° off) to shoot it,
  because taking that away loses the squad fight (x18n 9–23, x18a 7–25) and ~4 in 5 such baits are not hit. So the arm
  assertion (e) will not read "none at a loaded gun": it should read none at a gun laid on the peek, and fewer hits.
- **ACCEPTANCE RULE for x18m as champion, written 2026-10-04 17:40:54 PDT (from `date`) BEFORE the balanced and swarm ladders reported; the his-army ladder had finished at 17:40:52, unread, when it was saved
  report** (lesson 247; the orchestrator's frame): pool x18m v x5p over the four mirror armies (individuals seeds 1–8
  and 101–116; armor, balanced, swarm seeds 101–116; a draw is half a game), N stated. **Ships if** the pooled win
  share's 95 % Wilson lower bound is above 45 % AND no single army's point estimate is below 45 %. **If one army lands
  under 45 %:** 64 more games on that army (seeds 201–216); if it stays under 45 % pooled, x18m does not ship as is and
  x18l (only the laid-gun bait removed) is measured the same way and reported. His army size (cpu:balanced, 4600, the
  Sumps, laptop) was first written as reported-not-gated. **AMENDED (the orchestrator, before any further his-army
  game ran): GATED** — after 64 his-army games in total (seeds 201–208 pre-merge, 209–216 post-merge, laptop, load
  stated) the point estimate is at least 45 %, or x18m does not ship and x18l is measured the same way. Pooling across
  the merge is allowed only because 23941d90 moves no fight (all seven per-map lines unmoved, Sumps
  `bf0bdb98568700db`). The ladder plays each seed four ways (each brain as Green and as Rust, normal and swapped
  bases), so "x18m v x5p" is never one side attacking only; per-way splits are reported. First 32 (pre-merge, seeds
  201–208): **x18m 12–20** (a TOTAL only: its json was overwritten by a builder0 copy-back, no per-way split survives).
  Post-merge 32 (seeds 209–216, laptop, `b3464e32`, load 2.26 → 2.13): **x18m 20–11–1**; per way (x18m's side, bases):
  green normal 4–3–1, green swapped 7–1, rust normal 6–2, rust swapped 3–5. The two halves disagree sharply, so seeds
  201–208 are being re-run on the merged tree instead of pooling an uninspectable total. Builder0 mirrors: balanced
  **x18m 33–31** (64). Win rate is not the only gate: (d)/(e) in his frame must
  show fewer free hits both ways (at a laid gun: x18m zero; hits within 3 s of leaving cover per unit-minute lower)
  with the same game (kills, length, who wins within the seeds' spread). Known so far: individuals 53–43 (55 %, 95 %
  ≈ 45–65 %), armor 30–33–1 (48 %).
- **Running (builder0, one at a time):** `make remote T=check` on x18a; `ai-ladder` x18a v x5p, AI_RUNS=8 on four mirror
  armies (individuals, armor, balanced, swarm: 128 games); `ai-lever-behaviour PRICE_ARMS=x5p,x18a PRICE_SEEDS=1801-1816
  PRICE_TIME=300` (his frame: Sumps, Law v Condemned, 4600, both sides on each arm; seeds named before the run).

### Launch tree (C18.5's reference)

`cbda2c6a`, builder0, `make remote T=check` 2026-10-04 14:43–15:21 PDT: exited 0, 23 targets, all passed, ALL JUDGED;
sim-baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`; ai-scenarios 42 passed, 1 failed (the reload
scenario), 3 pending, scenario_perf judged by perf-judge; SHARD-ENGINE 0 errors 0 warnings in all five shards.

### B3 — open ground on a bare plate (in progress; laptop, `cc236ba4` + the probe, uncommitted until CP1 is cut)

**Fixture:** `tests/tactics/plate.json` (240 m, no obstacles; loaded by path, `--arena=res://tests/tactics/plate.json`,
so it is never in `layout_names()` and never dealt). **Instrument:** `squad-settle` (`tests/tactics/settle_probe.gd`)
now also reports, before arrival: `formations_moving`, `transit_frontage_m` beside `station_frontage_m` (the crews'
spread across the heading against their own stations'), `transit_nearest_m`, `guns_on_arc` (share of crew-ticks with
the turret within 45° of its formation sector, `TacticsFormation.sectors`), `arrival_spread_s`.

**Four tanks, 150 m forward, seed 3** (`--drills=off` = his right-click; `on` = a task with drills, the CPU's path):

| path | shape | arrived s | frontage m (stations) | nearest m | guns on arc | off slot at end m |
|---|---|---|---|---|---|---|
| plain | line | 18.7 | 35.2 (36.0) | 11.3 | 1.00 | 2.8–2.9 |
| plain | wedge (= AUTO) | 18.6 | 31.8 (32.4) | 11.4 | **0.50** | 2.8–2.9 |
| plain | column | 18.9 | 9.1 (0.0) | 7.6 | **0.25** | 2.8–2.9 |
| drills | line | 21.2 | 34.0 (36.0) | **7.8** | 0.98 | **6.6 / 8.5 / 8.6** / 2.8 |
| drills | wedge (= AUTO) | 17.8 | 28.3 (32.4) | 12.5 | 0.75 | **7.9 / 5.8 / 7.3 / 7.3** |
| drills | column | 18.2 | 6.4 (0.0) | 9.8 | **0.25** | **7.9 / 5.7** / 2.1 / **5.8** |

What holds: AUTO picks a wedge on open ground on both paths (not a column by habit); a line forms at its own spacing
(36 m) and holds it on his path; arrival is within a second. **Named defects (witness = the row and command above):**
- **D1. Flank watchers do not watch their flanks on the move.** A wedge's wingmen (sectors ±45°) and a column's
  middle crews (±90°) and tail (180°) keep their guns forward until the halt; only the line, whose sectors are all
  forward, is on its arcs. In the open that is the flank the lead's ambush comes from.
- **D2. On the CPU's path a crew can declare arrival 6–9 m off its slot.** Trace (`--drills=on --trace=on`): the
  wedge's lead, at 8.6 m/s, passes its slot, re-seats at arrival (0312 → 0321) and holds 8.8 m from the new one;
  the plain move ends every crew within 3 m.
- **D3. A line on the CPU's path closes up in transit** (nearest pair 7.8 m against 11.3 on his path and a 12 m pitch).

- **D4. A mixed squad on a task with drills halts after one leg and never arrives** — NOT open-ground-specific.
  `scout:scout:ifv:tank`, 150 m forward, `--drills=on`: every crew stops at t≈7 s within 3 m of its slot ("arrived")
  with the element's centre 107 m short, and stays there for the rest of 90 s; reproduces on the yard (seeds 3 and 4)
  and the plate (3 and 4); four tanks on the same path do arrive. Witness: `settle_probe.gd --arena=yard --dir=forward
  --metres=150 --seed=3 --units=scout:scout:ifv:tank --seconds=60 --drills=on --trace=on`. **Cause (read, and the trace agrees):** the
  technique is `traveling` and the centre is 2.5 m from the anchor, so `_advance`'s arrival test passes; the gate is
  `ElementPlan._cohesive`, which re-seats the members with a FRESH `TacticsFormation.place` (no `leader`, no
  `previous`), while `_group` seated them with the pinned leader and the previous seating. With mixed roles the fresh
  seating puts the tank in front (`ROLE_RANK`), so the tank waiting in its real slot at the back reads as "not closed
  up" on every update and the next leg never comes. Four tanks share a rank, so their seatings agree. **Fix (B5,
  declared, after CP1):** `_cohesive` judges against the seats the element gave. Whether a
  real CPU element (re-tasked by `ElementCommander`) shows it in a match is B4's to count.

- **D4 sized (his squads, not the CPU's):** in his skirmish the CPU does NOT run elements (`SkirmishMode.
  ELEMENT_CPU_DEFAULT = false`), so D4 is on HIS squads: `rts_controls` sends `drills: false` only for a plain move, so
  his attack-move (element task `move`, drills on) and the other tasks take the legged path. Laptop, the settle probe as
  his element, attack-move 150 m forward, 60 s, seeds 1–4, yard / terminus / sumps / pit, 2026-10-04 19:45–20:03 PDT
  (load 2.96 → 4.60): D4's signature (every crew within 3.5 m of its slot, the squad never arrives, sitting from ≈ 7 s
  to the end) in **21 of 80 runs**. Outside the Sumps: **two-scout mixes 14 of 24** (Law and Condemned `scout:scout:
  ifv:tank`; terminus 8/8, pit 4/8, yard 2/8), one-scout `law_scout:law_ifv:law_tank:law_tank` 2/12, `law_ifv:law_ifv:
  law_suppressor:law_tank` 0/12, four Law tanks 0/12. **The Sumps is another case (D5):** nothing arrives there,
  four tanks included; 15 of its 20 runs are not D4-shaped (crews off their slots), so the Sumps column is EXCLUDED
  from D4's counts above. Not the probe's window: the same runs at **180 s** (laptop, `6f9d43bc`, four Law tanks and
  `law_ifv:law_ifv:law_suppressor:law_tank`, seeds 1–4): 0 of 8 arrive, crews 5–20 m off their slots. Trace (four
  tanks, seed 1): one crew keeps driving at 7–8 m/s for 25 s without closing on its slot (16–20 m away) while the
  others hold in theirs and the element waits on it. **Cause (trace, slot coordinates and fit added
  to the probe):** both slots fit their hulls (`standable_for` moves them 0.3 m); the stuck crew is BEHIND a squadmate in
  the 14 m lane along the centre block yet holds the MORE FORWARD slot, and the squadmate parks in its own slot (24, 7)
  squarely in its path (it reports `yielding/Green_S_1` and does not leave the lane). The seating kept from the start
  (`0312`, stable by design: `TacticsFormation.seat`'s hysteresis) never re-seats a file whose order crossed. So it
  needs a lane narrow enough to make a file with crossed seats — any map — not water or bridges; the Sumps has the most
  such lanes on the way his squads go. Fix after D4: re-seat (or swap the two) when a crew's route to its slot runs
  through a squadmate already standing in its own.

- **D4's fix (written before its check):** `ElementPlan._cohesive` takes the seating `_group` gave (`_seating_given`:
  the pinned leader and the previous seats) at all three call sites (`_advance`, bounding's phase swap, the column
  withdrawal's swap). Scenario first: `tests/test_tactics_mixed_legs.gd` — a Law two-scout squad attack-moved 150 m on
  the Terminus arrives (red before the callers pass the seating: never arrived, 20.3 m short; green after: 18.5 s; four
  tanks 17.1 → 16.6 s, so every element's leg timing can shift). **Pre-registered:** all seven per-map sim lines
  UNMOVED, determinism UNMOVED, ai-parity UNMOVED — `--match` installs elements only under `--green/--rust-elements`
  (`TacticsFlags.ensure`), which neither the baseline, determinism nor parity pass, and his skirmish's CPU runs no
  elements; what moves is HIS squads on any task with drills, and `tactics-drills` / the squad tests that run elements
  (counts to be read).

- **D4 after** (laptop, `6f9d43bc`, the same 80 runs, 2026-10-04 20:09–20:26 PDT, load 2.14 → 2.25). Cells:
  stalled (D4-shaped) / other / arrived (median arrival s), before → after:

  | squad | yard | terminus | pit | sumps |
  |---|---|---|---|---|
  | Law scout,scout,ifv,tank | 0/0/4 (16.4) → 0/0/4 (16.4) | 4/0/0 → 0/0/4 (16.6) | 0/4/0 → 0/0/4 (14.1) | 0/4/0 → 0/0/4 (19.9) |
  | Condemned scout,scout,ifv,tank | 2/2/0 → 0/0/4 (17.8) | 4/0/0 → 0/0/4 (16.1) | 4/0/0 → 0/0/4 (16.6) | 4/0/0 → 0/0/4 (23.4) |
  | Law scout,ifv,tank,tank | 1/0/3 (18.4) → 0/0/4 (17.9) | 1/0/3 (19.5) → 0/0/4 (16.4) | 0/0/4 (17.6) → 0/0/4 (19.2) | 0/4/0 → 0/3/1 (22.5) |
  | Law ifv,ifv,suppressor,tank | 0/0/4 (18.8) → same | 0/0/4 (18.4) → same | 0/0/4 (19.9) → same | 1/3/0 → 1/3/0 |
  | Law tank ×4 | 0/0/4 (20.0) → same | 0/0/4 (17.9) → 0/0/4 (18.7) | 0/0/4 (19.4) → 0/0/4 (17.2) | 0/4/0 → 0/4/0 |

  **Stalls 21 → 1, arrivals 38 → 61 of 80.** Left: the Sumps' four-tank and IFV cells (D5). Unstalled cells' median
  arrival shifts within ±2 s either way (every element's tasked move changes a little).

- **D4 + D5 after** (laptop, `47981515`, the same 80 runs at 120 s, 2026-10-04 21:04–21:14 PDT, load 1.93 → 1.86;
  arrived k of 4 (median s), before → D4 alone → D4+D5, and D5's re-seats over the 4 runs):

  | squad | yard | terminus | pit | sumps |
  |---|---|---|---|---|
  | Law scout,scout,ifv,tank | 4 (16.4) → 4 (16.4) → 4 (15.9), 1 | 0 → 4 (16.6) → 4 (15.9), 0 | 0 → 4 (14.1) → 4 (14.1), 0 | 0 → 4 (19.9) → 4 (37.0), **7** |
  | Condemned scout,scout,ifv,tank | 0 → 4 (17.8) → 4 (17.8), 0 | 0 → 4 (16.1) → 4 (16.1), 0 | 0 → 4 (16.6) → 4 (16.6), 0 | 0 → 4 (23.4) → 4 (22.8), 0 |
  | Law scout,ifv,tank,tank | 3 (18.4) → 4 (17.9) → 4 (17.9), 0 | 3 (19.5) → 4 (16.4) → 4 (16.1), 0 | 4 (17.6) → 4 (19.2) → 4 (19.2), 0 | 0 → 1 (22.5) → 4 (33.7), 7 |
  | Law ifv,ifv,suppressor,tank | 4 (18.8) → same → same, 0 | 4 (18.4) → same → same, 0 | 4 (19.9) → same → same, 0 | 0 → 0 → 4 (38.5), 4 |
  | Law tank ×4 | 4 (20.0) → 4 (20.0) → 4 (19.8), 0 | 4 (17.9) → 4 (18.7) → 4 (17.4), 0 | 4 (19.4) → 4 (17.2) → 4 (17.2), 0 | 0 → 0 → 4 (39.8), 5 |

  **Arrived 38 → 61 → 80 of 80.** Off the Sumps: timings within D4's, 1 re-seat in 64 runs. **Open plate, forward 150
  m, the same four squads × seeds 1–4: 16 of 16 arrive, 0 re-seats** (the "side" runs are void: 150 m sideways leaves
  the 240 m plate). **Cost, said plainly:** on the Sumps the Law two-scout squad arrives in 37.0 s with 7 re-seats where
  D4 alone got it there in 19.9 s — the re-seat fires in the lanes while a file forms, not only when one is crossed.
  **What he sees when it fires:** two vehicles of the squad trade places once, mid-move (the rear one takes the front
  slot), and the squad's point is no longer its leader until the move ends. **The leader unpinned:** only after a
  re-seat (so never on the open plate in these runs, once in 64 off the Sumps); round 12's PIN arm (squad-settle
  series) is the instrument if he reports a squad's shape wandering on a tasked move in the lanes.
- First version of D5's timer (`deffde5b`) measured progress toward the PREVIOUS leg's slot, so every new leg read as
  "stuck": it re-seated in every scout-mix run and slowed them 3–6 s (pit 16.6 → 23.0 s); fixed in `47981515`.

Reading, not yet run: `Drills` (`game/tactics/drills.gd`) has no wall assumption — every trigger is a contact's
distance, age and visibility, or the element's strength — but nothing in it knows WHERE a contact is relative to the
element's heading: a near ambush from the flank is answered like one from the front ("turn into it and assault
through"). That is B5's third item (a line hit from the flank reacts as a formation).

### Questions for the lead

- None yet.

### Requests to other streams

- None yet.
