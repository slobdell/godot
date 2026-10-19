# Stream: traffic (a crew under fire doesn't step aside into a killing zone when the one behind can go round)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.8;
> R34.9, R34.13, R34.15, R34.17, R34.20 in *Round 34*), and your round-34 brief `streams/archive/round34/traffic.md` (its Status is the
> close-out). Evidence: `references/round34/traffic/` (T5 census, x6/x6b series, parkedroom v4/v4b).
> **You own:** the give-way block (`_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`, `_negotiate`, ask, `_begin_yield`,
> `right_of_way`), `game/ai/traffic.gd`, `tests/traffic/**`, `tests/test_traffic*.gd`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His answer at round 34's close: **a firing mortar truck keeps
its spot** ("Keep the truck firing"; his round-31 T1c-b2 rule stands).

What he will notice: fewer crews dying while stepping aside for a squadmate in a lane under fire, without the crew behind
stalling there instead.

## Where things stand

- **Shipped in round 34:** O4 (routes are the squad's) and o4b (gates for squads that have the waypoint queued).
- **Parked, each judged twice or more:** parkedroom (v4/v4b: hold-post loops −74 %, the far-loop total is the firing batteries he
  keeps); T4 the ghost (the gain is spent by later rules); **T6/T6b under fire, no give-way** (R34.17, R34.20): refusing every ask
  under fire cut yielding deaths 53–69 % but moved the dying to stuck/blocked/parked one for one; dropping the mid-step abort (c)
  fixed the collision harm. `underfire` is DEFAULT_OFF on stream branches only (not on main); native's mirror `badfdb978` unmerged.
- **T5's census:** jammed-by-friendly deaths 5.6 %, 83 % giving way, 77 % under fire, median jam 1.5 s, lanes 74 %.

## Backlog (in order)

1. **T7 Refuse under fire only when the asker has another way (C35.8).** Design note first, to the orchestrator: how "another way"
   is read (parkedroom's room/route test, a navmesh detour bound, or the asker's own route options), what the asker does when it has
   none (the give-way proceeds as today), and the interactions (the battery rule, the gate, O4 routes). Then tests, then a bar before
   any number: deciding gain jam-under-fire deaths; guards stuck deaths, open deaths, far loops, kills, hit rate, contacts after a
   give-way, crossings (as T6b's); fresh fixed arenas, no twins. Base it on `round34/traffic` (T6b's code) on current main; native
   mirrors from `badfdb978` with the new gate.
2. **T8 (R35.7, after T7's series; its own bar filed first):** a held crew that is being hit leaves the take-turns hold. From
   manoeuvre's W1 (builder0, native, main a0ae0aafd, Locks/Terminus × 3500–3511, 24 fights): 33 of 81 stuck:wedged deaths were HELD
   by the T1 street-mouth hold under fire, a median 5.4 s in; the 3 longest wedged episodes (18 s) are all holds. Not folded into T7.
3. **(D) (R35.7, after T7's series reads):** jam_census adds `jam:held` as a REPORTED sub-cause (a death while held by the hold);
   T5's definition (T7's G) unchanged until then.
4. **After T7's series, once native's N2 is on main (the orchestrator says when):** every traffic series reader that pools a folder
   that could hold random-arena fights (far_ab, far_kills, jam_ab, jam_table) calls `seed_twins.filter_logs` first (small commit).
5. **Stretch:** the measurement notes for judging.md (random-seed twins are now dropped by `seed_twins.py`; the fresh-folder import
   segfault is intermittent and a relaunch cures it).

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n.

## Don't touch

Manoeuvre's drive and unstick, brains' and orders' paths, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-19 (traffic, Opus).** No numbers yet.

**Plan (ordered).** T7.0 design note (DONE, `321e752f1`, sent to the orchestrator) → T7.1 base: T6/T6b + jam tooling cherry-picked
onto main without parkedroom (DONE) → T7.2 tests + code (built; iterating on builder0) → T7.3 native's mirror spec → T7.4 pair +
`make native check` + switch-off inertness → T7.5 the judged series (below) → stretch: judging.md measurement notes.

**T7's bar, FILED before any number (also in workstreams *Bars (round 35)*).** Pair = current main + T7 (`--traffic-on=underfire`,
DEFAULT_OFF) + native's mirror + the ON flip; base arm `--traffic-off=underfire`; switch-OFF sim-baseline inertness beside the C31.1
full check. Native, builder0 start to end, pinned, 180 s showmatch, FRESH fixed arenas `{terminus, locks, sumps, gorge, parade} ×
1600–1627` (n 140, no random arena, no twins). k = 1.645, paired se (`tests/traffic/jam_ab.py`).
- **G (deciding gain):** jam-under-fire deaths (T5's definition) arm < base AND (base − arm) − k·se > 0.
- **Guards (T6b's):** (1) open deaths ± k·se; (2) stuck deaths ≤ base + k·se; (3) far loops ≤ base + k·se; (4) kills ± k·se, hit rate
  ≥ base − k·se; (5) contacts in the 3 s after a hit-ended give-way ≤ base + k·se; (6) crossing arrivals 44–46 × 6 ≥ base − k·se a case;
  **(7, new) all friendly hull contacts a fight ≤ base + k·se** (a pass must not buy bumps).
- **Reported:** contacts with a crew passing, standoffs with durations, all/jam deaths, deaths by cause, `underfire_refusals/gives/
  holds`, `passes/passes_done/passes_timeout`. A fail is traced (worst fight first); no re-read of a line.

**Decisions.** "Another way" = a pass lane beside the refuser swept for the asker's hull (design note: parkedroom's room test answers
the refuser's question, a navmesh detour cannot see hulls, a lane change is brains' and B9 showed it is not the lever). The refused
asker steers by the lane (ORCA alone follows a slow mover: T6b's doubled far loops). (b) is gated by the same test, roles swapped.

**Questions for the lead.** None.
**Requests to other streams.** native: the T7 mirror (spec to follow with the first green commit).
