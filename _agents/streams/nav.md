# Stream: nav, round 15 (one exit test cannot serve the rig and the scout; then the planner that looks earlier)

> Read [`navigation.md`](../navigation.md), the archived round-14 brief `archive/round14/nav.md` and its **Status**
> (N1's buckets, N3's result and why it is opt-in, N3b, *Next steps* 0–1 — this brief is those two items), and
> `references/round14/nav/` (buckets, the acceptance tables, the k-turn clip sheets). **You own** what nav owned in
> rounds 12–14: `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`,
> `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md`.

## The lead's direction (2026-10-01)

> *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for the night."*

No nav complaint from his play. Standing: the rig stays 14 m; *"a 4s slower march for a tidier traversal is better,
yes."* An overnight round: never wait for an answer; decide, record the reason, keep going.

## Where things stand (round 14's Status; verify on main)

- **N3 (`--nav-off=kturnbrake` turns it ON; default OFF):** a planned leg ends within its stopping distance and counts
  from where the hull moves in its gear. Rigs on fresh seeds 9–16: all contacts −19 %, leg time −13 %, arrivals equal.
  **But** `scenario_cp2`'s engine-deck scout goes 41/43 deck hits → 3/13 with it on: the scout's orbit works because
  its planned reverse legs were brake taps (the forward roll counted as the leg's distance). N3b (count-from-rest only
  on later legs) did not rescue it. `make nav-scenario-arms SCEN_ARMS="none kturnbrake"` is the instrument.
- **N5's count:** on the merged tree, 25 of 80 first k-turn legs (190 reverse contacts, rigs, seeds 1–8) are planned
  when the forward arc's hit is 1–3 m away and the rig needs 3.5 m to stop; and the circle rule's reverses
  (`route/reverse` 588–791 per 8 seeds) never consult a wall. `_rollout` (the roll-out model) and `_dense_run_ok` (the
  dense-outline sweep) are written and tested; N2's gate on the circle rule was falsified ×3 and is opt-in (`circlefit`).
- Seeds 1–16 are SPENT (designed on). Acceptance this round: **seeds 17–24**, named here before the first variant.
- Tools: `nav-drive-arms`, `nav-reverse-buckets`, `nav-scenario-arms`, `nav-fight-maps`, `nav-sim-arms`,
  `nav-rig-clip RIG_CLIP_OFF=…`, `queue_table.py`.

## Backlog (in order)

**V1. N3 keyed so both are served.** Two candidate keys, build the one the leg log supports and say why: (a) **hull
class** — the stopping-distance exit applies when the hull's stopping distance at leg speed is a large share of the
leg (long hulls: the rig, the bus; never the scout); (b) **plan purpose** — a k-turn / back-and-fill in a street
(real stops) vs a reverse leg issued inside an orbit or an attack run (a tap). Measure which key separates the two
populations in the leg log FIRST (`--reverse-log`: per leg, hull length, leg length, speed at start, the plan's
origin). Then: default ON for the population it helps; `--nav-off=kturnbrake` restores round 14. Gates, all three:
`nav-scenario-arms SCEN_ARMS="none kturnbrake"` identical (the scout's 41/43 kept); the drive on seeds 17–24 keeps
N3's gains for rigs (all contacts −15 % or better, leg time not up, arrivals within 3); the mixed squad a null control.
Pre-register these before the build; the sim baseline: **pre-register MOVED with the path** (a wheeled hull in the 40 s
baseline match drives a planned leg — N3's attribution read `784069348a1b5423` when ON for all; with the key, say which
units in the baseline match fall under it) or UNMOVED if none do; attribute with `nav-sim-arms`; **CP1** if it moves.

**V2. N5: the planner looks earlier from a moving hull.** First legs planned inside the stopping distance (25 of 80)
and the circle rule's reverses: plan from the roll-out state (`_rollout`), not from the pose at the tick, with the
dense-outline sweep; when the roll-out's arc is clear, no reverse at all. Behind `--nav-off=<name>`. Pre-register on
seeds 17–24: rigs' `kturn/reverse` first-leg contacts fall by most of the 190; `route/reverse` falls; arrivals, refusals,
press/unstick within round 14's bars; the scenario gate identical; mixed null.

**V3. The clips, looked at.** `nav-rig-clip` both arms for V1 and V2 on the Terminus street, a sheet each under
`references/round15/nav/`, and the frames read against the numbers (round 14's sheet showed N3 touching a container
on the way out in one episode: say whether V1/V2 still do).

**V4 (stretch).** `yieldhold` as the default if V1–V3 leave the holds the biggest queue cost (N4: +13 % queued time);
measure, don't assume.

## How to verify

`make remote T=check` green on every named commit; every number with commit, machine, seeds, arm; the scenario gate
quoted both arms; the clips. Only nav may move the baseline this round; declare it, attribute it, and the orchestrator
records it twice (CP1, merged alone).

## Don't touch

`game/tactics/**`, `game/ai/{squad,tank_brain,formations}.gd` (squad's); `game/units/units.gd`; `game/arena/**`;
`game/theme/**`; `tests/ai_scenarios/**` (squad's — if the scout's orbit should not plan reverse legs at all, that is a
REQUEST to squad via the orchestrator, not an edit).

## Waiting on the lead

Nothing. He is asleep; the clip sheets are for his morning.

## Status

_Worker: nav, round 15. Started 2026-10-01 from `85703220`. Every number names its commit and machine._

### Green hash

**V1: `03f8336c` is green, merge here** (builder0, 2026-10-02): `>> remote: make check exited 0`, **1824 passed, 0
failed**, `18 passed, 1 NOT JUDGED` (`scenario_perf`, loaded 1.89x; the isolated run is below when it lands),
sim-baseline **`6313a38d7ecd99bb` unmoved** (predicted, and read by `nav-sim-arms` on the same commit), determinism
`ca7e3cbe26cf708d`. **No CP1.** The War Rig's planned legs stop where they were planned, ON by default.

### Green start

`85703220`, builder0: `>> remote: make check exited 0`, 19 targets, **1821 passed, 0 failed**, sim-baseline
`6313a38d7ecd99bb` unmoved; `scenario_perf` NOT JUDGED (loaded, ref 1.75x: five streams checking at once).

### Plan (the brief's order)

| # | item | state |
|---|---|---|
| 0 | green start | **green** (above) |
| V1a | the instrument: `--leg-print` (any harness prints each k-turn leg with hull length, braking, remaining route, the brain's option), `nav-sim-legs`, `tests/nav/leg_key.py` | built `b14017fc` |
| V1b | measure which key separates the rig's legs from the scout's (scenarios + drive + baseline match, both arms) | **done**: hull length (below) |
| V1c | pre-register, build the key, the gates | 5.5 m key `1c6cf271`: two clauses failed (below); **narrowed to the rig, 10 m: `03f8336c` green**, baseline unmoved, scenario gate met |
| V2a | the looks instrument (what the planner saw before each first leg) | built `f70afa98`; drive on seeds 1-8 running |
| V2 | N5: plan from the roll-out | — |
| V3 | the clips, looked at | — |
| V4 | stretch: `yieldhold` | — |

### V1: which key (builder0, `b14017fc`, `--leg-print` / `--reverse-log`; design seeds 1-8; N3 on for all = `--nav-off=kturnbrake` at that commit)

`tests/nav/leg_key.py` over the leg rows:

| population | hulls | legs | hull m | median \|v0\| | median stop m | stop / hull | options |
|---|---|---|---|---|---|---|---|
| rigs, drive | gang_tank | 97 | 14.0 | 3.7 m/s | 0.87 | **0.06** | MOVE |
| mixed, drive | ifv 27, artillery 20, lancer 17, scout 4 | 68 | 3.0-8.2 (med 7.5) | 2.7 | 0.30 | 0.04 | MOVE |
| AI scenarios | scout 12, ifv 1 | 13 | 3.04 (scouts) | 6.4 | 0.93 | **0.31** | ORBIT 5, KEEP_SLOT 5 |
| sim-baseline match | law_tank | 1 | 7.30 | 3.4 | 0.47 | 0.06 | RECHARGE |

- **The scout's legs** (`scenario_cp2`, `Green_Scout_1`): five `single` back-ups planned mid-`ORBIT` at 7-10.5 m/s, legs
  2-3.5 m. In the control the leg is done in 10-39 ticks, driven 2-3.7 m: the forward roll counted as the leg — a brake
  tap. With N3 (count from rest, end within the stop) each is a real 1-1.5 s reverse, and the orbit breaks.
- **The brief's guess at key (a) is inverted:** "stopping distance a large share of the leg/hull" picks the SCOUT (0.31
  of its hull) and not the rig (0.06). What separates them is the hull itself: 3.04 m vs 14 m.
- **Key (b), plan purpose**, would read the brain's option (`ORBIT`) inside nav: squad's vocabulary in nav's exit test,
  and a scout k-turning in a street would still get N3 while a rig orbiting would not. Rejected for (a).
- **Mixed (mid hulls 6.5-8.2 m), control vs N3-for-all on seeds 1-8:** leg contacts by hull artillery 25 -> 0, ifv 29 -> 0,
  lancer 0 -> 11 (54 -> 11); squad totals: contacts 1729 -> 1670, press+unstick 105 -> 27, arrivals 178 -> 174, leg s 1139
  -> 1265 (round 14's acceptance 9-16 had it better on every column). The control reproduced round 14's tables exactly
  (rigs 6415 contacts, 111/128; N3 4900, 113/128).

**Decision: the key is hull LENGTH, `Movement.KTURN_BRAKE_HULL_M` = 5.5 m**, cut in the catalog's gap: below it every
scout (2.93-4.04), gang_ifv 3.44, law_artillery 4.95 keep their taps; at or above it law_ifv 6.26, lancer 6.46,
gang_support 6.58, law_suppressor 6.86, gang_artillery 6.89, law_tank 7.30, ifv / burner 7.54, artillery 8.20, gang_tank
14.0 stop where the leg was planned. (Tracked and hover hulls never plan legs.) Reason: the brief's "the rig, the bus"
(the troop bus is the 7.54 m ifv), and the mid hulls' leg contacts fell 54 -> 11. `--nav-off=kturnbrake` = round 14 (off
for all); `--nav-off=kturnbrakeall` = round 14's opt-in (on for all). Test: `test_nav_kturn_brake` 4/4 (laptop): the rig
stops at its planned end by default and overshoots under `kturnbrake`; a scout at 9.6 m/s handed a 1.5 m back-up is a
tap by default (backs < 0.5 m, done in <= 15 ticks) and reverses ~1 m under `kturnbrakeall` (the mutation: the tap test
fails there).

### V1 pre-registration (written 2026-10-02 ~01:20, BEFORE any acceptance run; the build at the commit after `b14017fc`)

Acceptance seeds **17-24** (never designed on). Control = the same build with `--nav-off=kturnbrake` (round 14's default).
1. **Scenario gate:** `nav-scenario-arms SCEN_ARMS="none kturnbrake"` gives the same pass/fail set in both arms, and
   `scenario_cp2`'s engine-deck scout passes in both (its `MEASURE ai_cp2_scout_engine_deck` line quoted both arms).
2. **Rigs (seeds 17-24):** all contacts -15 % or better against the control; leg time not up; arrivals within 3.
3. **Mixed (seeds 17-24):** NOT a null control under this key (ifv, artillery and lancer are keyed): arrivals within 3
   of the control, all contacts not up, leg time not up 10 %.
4. **Sim baseline: MOVED.** Path: the 40 s baseline match drives exactly one planned leg, a `law_tank` (7.30 m, keyed)
   `single` back-up during RECHARGE; no scout plans a leg there. Prediction: the default reads round 14's N3-for-all
   hash **`784069348a1b5423`** (the same leg treated the same way), the `kturnbrake` arm reads `6313a38d7ecd99bb`, by
   `nav-sim-arms SIM_ARMS="none kturnbrake kturnbrakeall"` (builder0, glibc 2.43). **CP1.**

### V1 acceptance (builder0, `1c6cf271` = the 5.5 m key, seeds 17-24, control `--nav-off=kturnbrake`, same build)

**A trap first:** `build/nav-drive-arms/` locally held round 14's seeds 9-16 logs (builder0's `build/` persists across
rounds in its folder, the first copy-back brought them, and copy-back never deletes local extras), and the first table
read 16 seeds. The table below is the 16 runs this command made (its own `done` lines), copied apart. Always `rm -rf`
the local output dir before a `make remote` you will read, or count the runs.

| squad | arm | arrived | leg s | contacts | press+unstick | reverse-gear | kturns | kturn_none |
|---|---|---|---|---|---|---|---|---|
| rigs | control | 113/128 | 1029 | 5739 | 244 | 1303 | 48 | 67 |
| rigs | keyed | 111 | 1106 | **3991** | 286 | 1117 | 54 | 69 |
| mixed | control | 172/192 | 1194 | 1430 | 26 | 392 | 44 | 10 |
| mixed | keyed (5.5 m) | 178 | 1237 | 1815 | 67 | 231 | 35 | 15 |

Per seed, contacts: rigs better on 6 of 8 (17: 939 -> 430 ... 22: 363 -> 858); mixed better on 5 of 8, the rise is two
seeds (17: 79 -> 418, 22: 134 -> 410, a lancer pressed on `Block_0` 285 ticks), and **none of it on planned legs**
(mixed leg contacts 25 -> 0).

**Against the pre-registration, honestly:**
1. Scenario gate: **met.** Same pass/fail set in both arms (the one failure, `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits`,
   is main's, in both arms as in round 14); `scenario_cp2`'s scout `deck 41 / hits 43` in BOTH arms. (`scenario_perf`
   passed in the default arm at 1.48x and was NOT JUDGED in the control at 1.91x: load, not nav.)
2. Rigs: contacts **-30 %** (bar -15 %: met); arrivals -2 (bar 3: met); leg time **+7.5 % (bar "not up": FAILED)** —
   +77 s over 32 legs, ~2.4 s a leg (round 14 read -6 % and -13 % on seeds 1-8 and 9-16).
3. Mixed: arrivals +6 (met); leg time +3.6 % (met); contacts **+27 % (bar "not up": FAILED)**.
4. Baseline: **met exactly** — `nav-sim-arms`: default `784069348a1b5423`, `kturnbrake` `6313a38d7ecd99bb`,
   `kturnbrakeall` `784069348a1b5423` (the law_tank's leg).

**Decision: the key is narrowed to the War Rig (`KTURN_BRAKE_HULL_M` = 10 m), and it ships ON.** This is a post-hoc
narrowing, labelled as one: the mid hulls' clause failed, so they keep round 14's legs (the most reversible option;
`kturnbrakeall` keeps the wide arm for whoever wants it). It needs no new run to read: the rig squad's rows above are the
same hulls under either key, and the mixed squad under a 10 m key IS the control (no wheeled hull >= 10 m in it). The
rigs' leg time failed my bar but sits inside the lead's standing trade (*"a 4s slower march for a tidier traversal is
better, yes"*): ~2.4 s a leg for 30 % fewer wall contacts. New prediction for the narrowed key, BEFORE its run: the
sim baseline is **UNMOVED** (`6313a38d7ecd99bb`; the baseline match's one leg is the 7.3 m law_tank's), so **no CP1**;
the scenario gate as above. Test: `test_nav_kturn_brake` 5/5 (laptop), incl. the key table (rig yes; ifv, scout no).

### V1 narrowed key: the gates on `03f8336c` (builder0)

- `nav-sim-arms SIM_ARMS="none kturnbrake kturnbrakeall"`: `6313a38d7ecd99bb` / `6313a38d7ecd99bb` / `784069348a1b5423` —
  **unmoved as predicted**; the wide arm still moves it (the law_tank's leg).
- `nav-scenario-arms SCEN_ARMS="none kturnbrake"`: the same pass/fail set (main's `scenario_cover` failure in both);
  `scenario_cp2` scout `deck 41 / hits 43` in both; `scenario_perf` NOT JUDGED at 1.54x in the default arm (load).
- The rigs' drive numbers are the 5.5 m build's rows above (the same hulls); the mixed squad's are the control's.
