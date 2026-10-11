# Stream: traffic (friendly vehicles deconflict: keep right head-on, a rule at every crossing, never against enemies)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (his words and
> readings (1)–(6)), `_agents/navigation.md` (the give-way of rounds 13–14, ORCA, the wedge/unstick counters),
> `_agents/unit_ai.md`, `_agents/workstreams.md` *Round 26* (C26.1, C26.2, C26.4, C26.5 are yours), and round 25's
> brains report (`streams/archive/round25/brains.md` Status: the give-way priced by removal, the deck funnel). You own
> `game/ai/avoidance.gd`, `game/ai/steering.gd`, in `game/ai/movement.gd` the give-way block (`right_of_way` through
> `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`; new `game/ai/traffic*.gd`; new
> `tests/test_traffic*.gd`, `tests/test_avoidance.gd`, new `tests/ai_scenarios/scenario_traffic*.gd`; `mk/traffic.mk`
> (new). **C26.2 matters most:** `_avoid` is mirrored inside `native/src/drive_native.cpp` and `Avoidance.solve` is
> `native/src/avoidance.cpp`, both ON by default; perf ports your diff. Decide in GDScript the native drive calls back
> (`_negotiate`, `_blocker`) or in your own new file wherever you can.

## The lead's direction (2026-10-10, playing round 25's checkpoint)

> *"if I take 2 squads and have theme move in opposing directions such that they have to cross each other (i.e. south
> army goes north, north army goes south), there's clearly a problem: vehicles will get stuck bumping into each other
> and figuring out where to go. THis is likely a symptom of a bigger problem across the board with at least teammates
> cooperating with each other. For example, in a real world scenario, people would just generally each turn to the
> right in order to deconflict. The same case might not be said if we're charging toward an enemy (i.e. maybe it is the
> vehicle's intention to block the opponent's movement). If I was able to induce such conestion on a simple case,
> there's likely congestion problems when armies get clumped together"*

> *"Also on my earlier note about congestion, the same behavior applies when one vehicle is making a 90 degree angle
> with another vehicle's path. In the same way it probably makes sense for friendly units to agree on how to
> deconflict"*

The readings (not his words): his reproduction becomes a scenario with a pass line FIRST; friendlies meeting head-on keep
right (both turn the same way); the convention covers ANY crossing angle (his 90° case is a second scenario), with a rule
for who yields; it does NOT apply against enemies; and because he expects the same root cause in every friendly clump,
the round measures congestion in big fights too, before and after.

## Where things stand (VERIFY at main)

- Avoidance is ORCA (`avoidance.gd`, native `avoidance.cpp`, `native_avoid` ON), plus round 13–14's give-way: a crew
  blocked by a friend asks it to yield (`right_of_way`, `ask`, `_begin_yield`, `_yield_fits`…), with counters in
  `Movement.route_arms()` and the switches `yield`, `yieldclear`, `yieldfit`, `yieldhold`, `yieldshort`
  (`--nav-off=…`). Round 25 priced the give-way by removal at ~0 on arrival time.
- `make nav-orders` (5 player squads ordered across each other at once, yard, NAV_ORDERS t50/t90/t100,
  never_completed), `make nav-yield-buckets`, `make nav-yield-clip`, `make two-squads-playtest` (orders' probe of two
  squads given ONE point), `make bridge-pooled` (his bridge drill; must not get worse).
- Nothing today encodes "keep right" or a crossing rule; ORCA's reciprocal split is symmetric per pair, so two hulls
  head-on can each sidestep the same way, or dither.

## Backlog (in order)

**T0 — his two cases, counted, with pass lines first (before any fix).** Two scenarios (TacticsLab or `ai_scenarios`,
your files): (a) **head-on**: two of his squads (5 each, mixed hulls as `make skirmish` deals) ~120 m apart on open
ground, ordered through each other's start; (b) **crossing**: the same at 90°, timed so the squads reach the middle
together. Both also on a street map (Terminus) where the road is ~2 hulls wide. Per run: every crew's arrival time,
stuck crew-seconds against a FRIENDLY (speed < 0.5 m/s with a friendly hull in its way, C26.5's label), friendly
contacts, k-turns started with a friendly as the obstacle, the ratio of the crossing's last arrival to each squad's
solo time. Pool over the pre-registered start ticks (C26.6) and 3 seeds. Pre-register the pass line in Status before the
fix (suggested: every crew arrives; friendly-stuck crew-seconds cut by ≥ 75 %; the crossing's last arrival ≤ 1.2× the
solo time; zero friendly contacts at > 2 m/s). Record what a player would see at main (a his-pose clip at the meeting,
`make` target in `mk/traffic.mk`; look at the frames).

**T1 — the census in big fights.** The same friendly-stuck crew-seconds, friendly contacts and friendly-obstacle k-turns
over Sumps 25 a side (both CPU) and the army series, at main, 3 seeds. This is the "before" of his clump hypothesis;
report what share of all stuck time is friendly.

**T2 — the convention (DECLARED, C26.1; CP1).** Design first, in `navigation.md`, before code (lesson 278: the rule
written before the number): head-on → both keep right (a lateral bias toward each crew's own right, started early
enough to be smooth, not a last-metre swerve); a crossing at any angle → one crew yields by a rule both compute
identically (C26.4: suggestions — the crew with the other on its right yields, as a road "priority to the right"; or the
one arriving later at the conflict point slows; pick by T0's numbers and say why). It is friendlies only (team check at
the source); a crew already yielding or in a k-turn is an input. The CPU uses the same rule. Prefer ORCA's preferred
velocity (a bias) and the callback layer over rewriting the solver; send perf the diff for anything in `_avoid` or
`Avoidance.solve` (C26.2). Pass: T0's pre-registered line on both cases and both maps; `make nav-orders` not worse;
`make bridge-pooled` not worse; the arrive series and the thirteen lines read as declared; a his-pose clip of each case
looked at. Merged alone with perf's port.

**T3 — the census again (after CP1).** Re-run T1; report the friendly share before/after, with manoeuvre's C26.5 labels
once CP3 lands.

**T4 — stretch: the clumps T3 still shows.** The top remaining friendly-jam pattern from T3's traces (a queue at a gap,
a squad overtaking another, a crew backing into a friend), each a scenario first, each its own declared change.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`), your scenarios pooled over
start ticks and seeds on builder0, the his-pose clips on the laptop through the orchestrator (C26.7). Every number
carries commit, machine, workload and n.

## Don't touch

Manoeuvre's `movement.gd` block (`drive()`'s body, `unstick`, the k-turn / planned-reverse / circle block),
`game/tactics/**` (brains'), `native/**` (perf's), `game/control/**` (orders'). A hook you need in `drive()`'s body is a
request to manoeuvre through the orchestrator.

## Waiting on the lead

Nothing. Questions go in Status; take the most reversible option.

## Status

_Updated 2026-10-10 night (traffic worker). Every number names commit, machine, workload and n._

### The plan (ordered)

1. **T0 instrument** (`tests/traffic/traffic_stage.gd`, `traffic_probe.gd`, `traffic_table.py`, `mk/traffic.mk`:
   `make remote T=traffic-series`). His two cases on yard_open (the band: open ground) and Terminus (18 m streets),
   two friendly squads of five mixed Law hulls each (`law_tank, law_ifv, law_scout, law_suppressor, law_tank`, the same
   in both squads so neither is faster), his right-click (a plain element move), plus each squad alone (the solo time),
   pooled over start ticks {1,3,6,8,11,16} x seeds {1,2,3}. Stuck is measured from DISPLACEMENT over 1 s, never
   `estimated_velocity` (a hull pressed nose to nose keeps ~6.7 m/s of slide velocity while it does not move).
2. **CP1a (C26.8, granted by the orchestrator 2026-10-10 night): the element-feed slot slide.** Found in T0's first
   trace (below). DECLARED, its own commit, merged ALONE before the convention.
3. **T0 baseline** = CP1a's commit with `--traffic-off=slide` (the old key exactly: the off path is the pre-CP1a code),
   then the same with it on.
4. **T1** census in big fights at main (Sumps 25 a side, army series).
5. **T2** the convention (design in `navigation.md` first), CP1b, with perf's port.
6. **T3** census again; **T4** stretch.

### T0's first finding (2026-10-10 night): THE ROOT CAUSE IS THE ELEMENT FEED, NOT AVOIDANCE

His head-on case, traced (laptop, uncommitted probe on `b57838ed`, yard_open, seed 1, n = 1; a lead, not a result):
4 of 10 crews pinned nose to nose in the middle for the whole 60 s, phase `driving`, never `blocked`, no ask, no
give-way, no sidestep. `Movement._order_ticks` cycled 8, 5, 2, 8, 5, 2… and `stalled_s` never passed 0.27 s. Why:
`ElementFeed.context`'s `key` carried the crew's slot as a float string; the element slides that slot by millimetres
every update (~9 ticks), so `ElementFeed.changed()` read true, `TankBrain._poll_element` called `interrupt()` →
`Movement.reset()`, zeroing `stalled_ticks` and `_order_ticks` every ~0.3 s. So `_avoid`'s start-of-order grace
(`AVOID_GRACE_TICKS` 10) never ended — ORCA only ever SLOWED a crew, never steered it aside — and the stall that starts
ask/yield (1 s / 2 s) and `held_back` never fired. Every element move, both sides. A prototype that ignores a slide
under 2 m: 10/10 arrived by 24 s, 0 friendly-stuck crew-s (same run). Sent to the orchestrator; granted as C26.8.

**CP1a** (`game/ai/element_feed.gd` the key + `changed()`, `game/ai/traffic.gd` `SLOT_SLIDE_M` and the switch
`--traffic-off=slide`, `tests/test_traffic_feed.gd`): the slot leaves the key; `changed()` is true when the key
changes OR the slot jumps more than 2 m between two reads OR a slot is given or taken away. 2 m = Movement's own
goal-jump distance (`_track_progress`) and a quarter of the tightest doctrine spacing (8 m), so a re-seat always
interrupts. No native port: nothing in `native/` reads the key.

### Pass lines, PRE-REGISTERED before any series ran (C26.6)

**CP1a (declared, alone):** pooled over {1,3,6,8,11,16} x seeds {1,2,3}, builder0, the two arms on one commit:
(a) his four cases (2 maps x head/cross): crews arrived not fewer in any case, friendly-stuck crew-seconds lower in
total; (b) `make nav-orders`: never_completed not more, t100 not more than +10 %; (c) `make bridge-pooled`: not fewer
runs passing than main; (d) the arrive series and element digest MOVE (declared) and are reported, not judged; the
thirteen lines read as declared; `make check` green.

**CP1b, the convention (T2's line, suggested by the brief, adopted):** on his four cases, measured against T0's
baseline arm: every crew arrives in every run; friendly-stuck crew-seconds cut by >= 75 %; the crossing's last arrival
<= 1.2x the same squad's solo time (median over runs; worst reported); zero friendly contacts at > 2 m/s closing.
`make nav-orders` and `make bridge-pooled` not worse. If CP1a alone already meets a part of this, the convention is
judged on what is left (contacts, the ratio), against CP1a's arm.
**CP1b's cost (the orchestrator's line, 2026-10-11, pre-registered before it was measured):** <= 0.5 ms a tick on the
GDScript path — `sz.tr.shape_gd` + `sz.tr.refresh_gd` ms_per_tick from `tools/remote.sh --light native-tp-headless
NATIVE_TPH_SIZE=25 PROF_ARENA=sumps NATIVE_TPH_FLAGS=--brains-off=native_drive` (perf's instrument, seeds 92721 31337
5988, window 8-20 s, leaders on), builder0, with the whole tick beside it against `--traffic-off=keepright,crossing` in
the same session. The first draft (5b881905) priced ~2.8 + 0.75 ms (perf, native callback path, builder0 load ~18).

### T0's baseline and CP1a's arm (builder0, `5c31c58f`, `make traffic-series`, n = 18 per case = start ticks {1,3,6,8,11,16} x seeds {1,2,3}; main = `--traffic-off=slide`, which is main's path: the two arms' hashes are being proved)

His two cases, two friendly squads of five mixed Law hulls. fstuck = friendly-stuck crew-seconds (displacement < 0.5 m
in 1 s, a friend's box within 3 m ahead), totals over the 18 runs. ratio = a squad's last arrival over its solo time,
same seed and tick (median / worst; "never" = squads that did not all arrive while they did alone).

| case | arm | all crews in (runs) | crews arrived | fstuck total | contacts / run | fast (> 2 m/s) | ratio med / worst | never |
|---|---|---|---|---|---|---|---|---|
| Terminus head-on | main | 0 / 18 | 100 / 180 | 7422 | 159 | 1422 | — | 19 |
| | CP1a | 9 / 18 | 171 / 180 | 408 (-94 %) | 62 | 654 | 1.33 / 2.43 | 3 |
| yard_open head-on | main | 9 / 18 | 156 / 180 | 4293 | 10.2 | 112 | 1.84 / 4.24 | 16 |
| | CP1a | 18 / 18 | 180 / 180 | 2.0 | 9.1 | 76 | 1.09 / 2.11 | 0 |
| Terminus crossing | main | 7 / 18 | 165 / 180 | 223 | 32.7 | 388 | 1.14 / 2.6 | 8 |
| | CP1a | 11 / 18 | 170 / 180 | 89 (-60 %) | 32.6 | 280 | **1.34 / 3.53** | 7 |
| yard_open crossing | main | 6 / 18 | 165 / 180 | 308 | 27.4 | 290 | 1.09 / 1.75 | 7 |
| | CP1a | 11 / 18 | 171 / 180 | 231 (-25 %) | 22.7 | 207 | 1.01 / 1.68 | 4 |

**Worse with CP1a:** the Terminus crossing's ratio (squads that never arrived at main now arrive, late); the solo arms
lost a few arrivals on yard_open (crossing solo 172 -> 169 of 180, head-on solo 180 -> 178) and gained friendly-stuck
time inside one squad (crossing solo 126 -> 145 crew-s). **What a player sees at main:** in his head-on case on the
Terminus street not one run in 18 got every crew through; on open ground half did. What is left after CP1a is the
convention's job: fast friendly contacts (654 / 76 / 280 / 207) and the crossings' stuck time.

**His bridge drill (brains' evidence, builder0, `aa5defa1` = stream/brains + `5c31c58f`, 108 runs paired at one
commit):** `--traffic-off=slide` reproduces round 25 exactly (his side 45/54 across, CPU 42/54, squads arriving 37/40,
deck jam 1013 / 754 crew-s); CP1a on: 53/54 and 53/54, squads arriving 54/54, deck jam 135 / 92 (-87 %). No run got
worse; the one miss a side is a crew the lancers kill, which misses with the switch off too.

Solo arms do not always "arrive" either (Terminus head-on solo_b crew 5 in 16 of 18 runs; Terminus crossing crew 4):
the probe now reports each crew's final distance to its slot (`82ce362f`) to tell a slot it cannot reach from a stall.

### CP1a merged (main `e9f9e946` = `db019850`, 2026-10-11) — the yard_open crossing rows above are VOID

The yard_open crossing stage started and sent squad B behind the container walls at x = +-50, to slots with no path
(even its solo runs did not settle); fixed (`f04bb850` / `12cecbe8`: 76 m each way inside the walls) and every arm is
re-measured on it. nav-orders: identical in both arms on seeds 1-3 (the probe ignored `--seed` until brains' 668c54c4:
n = 1). Element digest (64 runs): main `ad323da8…` -> CP1a `3ffc27b4…` (32 of 64 moved, declared). Arrive series
(`db019850`, 5 maps x 5 squads x 4 seeds): main 100/100, CP1a 99/100 (the Sumps law_scout:law_ifv:law_tank:law_tank
squad), medians mixed (Sumps and the Cut faster, the yard slower).

### CP1a2: a crew a PARKED friend refused does not give way to it (`50144846` on branch `traffic-cp1a2`)

**Why** (CP1a's trace, builder0, Terminus crossing, squad A alone, seed 3, tick 8, the convention off): with the stall
clock running, crew 5 (a wheeled law_tank, its slot 25 m behind it) asked crew 3, parked on its slot, to give way;
crew 3 had no room and refused; `_negotiate`'s old rule then made crew 5 give way ITSELF to a crew going nowhere — it
drove to a yield spot, read blocked/no_path and ended 15.2 m from its slot. Before CP1a the path was unreachable.
**The rule now:** a refused ask to a parked friend ends the negotiation; the crew keeps its route (ORCA gives it all the
avoiding against a still hull, unstick remains). `--traffic-off=parked`; counter `Movement.parked_refusals`. No port
(the native drive calls `_negotiate` back). Cost: one branch on an ask that was already refused (~0).

**The seed-3 line is RE-ASSIGNED, not met** (C26.6, the orchestrator's ruling 2026-10-11): squad A seed 3 alone, 6
start ticks — main 16.8 s x6; old rule never x3 / 18.1 / 29.3 / 43.0; new rule never x3 / 18.1 / 23.5 / 43.0; the fix
fires (1-31 parked refusals a run). The second cause, traced (tick 8, new rule): CP1a's seating by nearest put crew 3
at (10.6, -7.7) (main: (10.7, -15.9)), across crew 5's way back to its slot; crew 5 shuffles at full lock against it
and crew 3 refuses every ask (10, no give-way spot fits near the plaza). A seat parked across a squadmate's route:
brains' make-room (its missing falsifier) and manoeuvre's turn planner, by the orchestrator. Terminus crossing solo
arrivals over all seeds: main 164 / CP1a 165 of 180 (seed 3's seating, not a systematic slowdown).

**The falsifier** (`make traffic-parked`: a friend parked in the maze's 8 m lane, the only way through; builder0,
`516774d1`): no deadlock in either arm, identical outcomes — the parked crew leads the way out when asked (gang_tank
9.9 m, law_tank 12.1 m) and the asker ends 5.1 / 4.3 m from its goal, inside a wheeled hull's settle radius (the
probe's 4 m bar is stricter than the game's arrival). Seeds identical (the probe places the hulls exactly): n = 1 a hull.

### Next items (assigned 2026-10-11 by the orchestrator, after CP1a2)

1. **The CP1a arrive-series regression:** Sumps, law_scout:law_ifv:law_tank:law_tank, seed 1 — main arrives 22.6 s,
   CP1a ends 87.6 m short at 120 s (the whole squad, not a crew). `make traffic-settle-trace` traces that cell per arm.
   Fix as its own declared change, or hand it to brains if it is another seat-across-the-route case.
2. **The creep shuffle (manoeuvre's C26.5 relay):** avoidance's pace puts a wheeled hull at full lock under the plant's
   creep threshold (throttle < 0.5 x |turn|), so it shuffles in 0.5 s legs beside a friend instead of driving round it:
   149 long-turn episodes in manoeuvre's census on main+CP2, 81 against a FRIEND. Seed 3's crew 5 is one (thr 0.47,
   turn -1.0). Rule to build with the convention: a friend-yield or avoidance slow-down of a wheeled hull at full lock
   either holds still or keeps enough throttle to turn — never the shuffle. Manoeuvre's census labels the episodes.

### Merge notes

- New directory `tests/traffic/` (traffic's, new this round), `mk/traffic.mk` (picked up by `include mk/*.mk`: no
  Makefile edit), `game/ai/traffic.gd`.
- `game/ai/element_feed.gd` the key + `changed()` hunk: C26.8's grant.

### Questions for the lead

None yet.

### Requests to other streams

None yet (the feed-key hunk became a grant instead of a request to brains).
