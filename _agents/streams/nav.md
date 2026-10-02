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

_(the worker keeps this current)_
