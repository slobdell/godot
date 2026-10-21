> **ARCHIVED (round 36 closed 2026-10-21).** The branch is `round36/traffic`; its unmerged references stay on that branch. Round 37's brief is `streams/traffic.md` where one exists.

# Stream: traffic (a crew being shot while it waits its turn in a street mouth drives on)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1,
> CP36.1, C36.2) and in *Round 35*: the T8 bar in *Bars (round 35)*, R35.69 (the seed swap), R35.78 (X1b: why T8). Then your round-35
> brief `streams/archive/round35/traffic.md`: its Status is the close-out and holds T8's whole plan (code, tooling, driver, reader).
> **You own:** the give-way block in `game/ai/movement.gd` (`_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`, `_negotiate`,
> ask, `_begin_yield`, `right_of_way`), `game/ai/traffic.gd`, `tests/traffic/**`, `tests/test_traffic*.gd`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder2 for T8's check and series (C36.1); light runs on either builder.

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking (memory: *smart AI on both sides*). For round 36 he chose "use the
agents' list" (2026-10-20): no new playtest words. His standing rule: a firing mortar truck keeps its spot.

What he will notice: a crew that is being shot while it waits its turn at a street mouth stops waiting and drives on, instead of
sitting there until it dies.

## Where things stand

- **Shipped in round 35:** T7 (a crew under fire doesn't step aside into a killing zone when the one behind can go round). **T9**
  (a give-way that ends with the asker not past is not recorded, so the next ask is honoured) ships inside the joint W1c + T9 at
  **CP36.1** (the orchestrator merges it; you are told when).
- **Why T8 is the answer (R35.78, X1b):** a held, still wheeled hull takes ~2x the hits per exposed second (builder0 native, Locks x
  4300–4323, n 24 paired: 0.117 -> 0.249/s); manoeuvre's alternative (W1b, the wheeled halt) is dropped. From W1: 33 of 81
  stuck:wedged deaths were HELD by the T1 street-mouth hold under fire, a median 5.4 s in.
- **T8 is coded and its bar is filed** (round 35 Status): `1a1bd58bf` (`--traffic-on=holdfire`, DEFAULT_OFF; `Traffic.hold_of`
  releases a held crew hit within `Movement.UNDER_FIRE_S`, counter `released_fire`), `tests/test_traffic_holdfire.gd` (+ .uid
  `41f637d8e`), jam_census's `held_deaths` / `held_3s`, `jam_ab.py --bar t8` (`06144d171`), `tests/traffic/t8_series.sh`. All on
  `round35/traffic`, none on main.

## Backlog (in order)

1. **Carry over (C36.1), after CP36.1 lands on main and the orchestrator tells you:** `git merge main`, then bring `round35/traffic`'s
   T8 code and tooling across. Read `git diff main...round35/traffic` first: T9's commits arrive through the joint, so take the rest
   (T8 OFF, the jam tooling, t8_series.sh, test_jam_ab, the judging.md measurement notes). `make quick-remote`.
2. **T8 judged (C36.2).** Cut `pair/holdfire-r36` from that commit + the ON flip (holdfire out of `DEFAULT_OFF`); base arm
   `--traffic-off=holdfire`. Driver `tests/traffic/t8_series.sh` on **builder2** under systemd-run: wait for builder2's checks → `make
   native check` (stop if red beyond sim-baseline) → switch-OFF `sim-variants --traffic-off=holdfire` → the series → `jam_ab --bar t8`.
   The bar is exactly as filed (fresh fixed arenas {terminus, locks, crossing, gorge, parade} x 1800–1827, locks 1801–1828, n 140).
   Counter first. Report every line with commit, machine, n. **A pass:** name the green hash of the hand-over (the ON flip on current
   main) and send it to the orchestrator; it ships ON. **A fail:** trace the worst fight first, write it up, no re-read on the same
   seeds.
3. **Perf-judge for T8 before the ship:** ask the orchestrator for a quiet slot (it is owed alone on a quiet builder).
4. **The seed_twins call in every series reader** that pools a folder that could hold random-arena fights (far_ab, far_kills,
   jam_ab, jam_table), if `round35/traffic` didn't already carry it (small commit, test).
5. **Stretch: the next held-crew loss.** With T8's series in hand, read `jam:held` and the held deaths that T8 did NOT release
   (hit before the hold, or held without being hit while its neighbour was): a design note to the orchestrator, no code before it.

## How to verify

Tests first; `make quick-remote`; one full check at a time a builder; the series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n. Smoke: `make skirmish ARENA=terminus` on the T8 hand-over; a held crew that's hit should drive on.

## Don't touch

Manoeuvre's drive and unstick, orders' paths, brains' paths (no owner this round, C36.6), `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

## ROUND 36 REPORT (traffic, Opus, 2026-10-20 ~18:40 PDT). Every number carries its commit, machine, workload, n.

**Done criterion: MET.** Every backlog item is complete; stream/traffic **`362848e6a` is green**: builder2 `make native check` exited 0,
25 passed + 2 NOT JUDGED (perf-judge, scenario_perf: load), tests 2969/0, no sim-baseline map moved. Later commits (`5cba5a946`+) are
Status only. Game code = main's (T8 and yieldgap arrived through main); stream/traffic adds tooling and docs only.

**T10 (added after the report, 2026-10-21 ~00:40 PDT): FAILS as filed (R36.23), parked OFF.**
- **Gate check GREEN** on the pair + native stack `0ca19d829` (pair/native-t10b). builder2 `make native check` exited 0: 25
  passed + 2 NOT JUDGED (load); tests 2988/0; sim-baseline 13/13 unmoved. The clock's inertness run (`sim-variants
  --traffic-on=clearclock`) exited 0.
- **Deciding line FAILS:** orders' native probe, builder2, `0ca19d829`, seeds 3641–3664, 12 street cells, 1152 paired
  squads.
  - D (restricted, n 940): away_m 4129.8 → 3551.4; drop 578; se 546; drop − k·se = −320.
  - The guards passed.
  - One Terminus pair (479 → 6 m) carries most of the drop.
  - Locks click rose: 351 → 410 (3 squads) and 306 → 376 (5 squads).
  - The fights step was stopped on R36.23's word; builder2 is idle.
- **Traced** (`references/round36/traffic/t10_locks_trace.md`):
  - The Locks rises are **G's** (G-only = both; H-only = base) on s3652 and s3664.
  - The crews did not drive farther. The rise is **orders' away_m counting goal flips**: Bravo_2's order alternates each
    second between its seat and a point ~15 m off after it returns from its own ADVANCE. G changed the timing so it met
    6 flips rather than 0 (s3652) and 4 rather than 2 (s3664). The real drive away went 9.2 → 9.8 m and 13.7 → 6.2 m.
  - Round 37: fix away_m (orders), find the flip's writer (orders/brains), and give G a "not farther than standing" test if
    it is retried.
- **Switches:** `seatyield`, `seathold` and `clearclock` stay in `DEFAULT_OFF`. stream/traffic carries T10's code dark (the
  pair's T10 commits are the ones checked green at `0ca19d829`).
- **R36.24 (orchestrator):** the goal flicker is a real looks-dumb bug and goes first on round 37's list. No check of stream/traffic's HEAD is needed (T10 is dark; its pair commits are the green ones). **Traffic is DONE for round 36.**
- **Cleanup owed:**
  - worktrees `../godot-traffic-t10` and `../godot-traffic-t10n`;
  - builder2's copies of them.

**What he will notice (shipped, main `3d46b2884`, R36.12):** a crew being shot while it waits its turn at a street mouth stops
waiting and drives on. Judged on pair `a2de32420` (builder2, native, fixed arenas {terminus, locks, crossing, gorge, parade} x
1800–1827 / locks 1801–1828, n 140 paired): crews killed while held, or within 3 s of leaving a hold, **253 -> 109 (−57 %, 6.8 se)**,
618 releases for fire, and nothing else worse (stuck deaths 871 -> 812, all deaths per team down, contacts +2.1 % inside the line,
the hold still taken 3147 -> 3245, crossing arrivals 180/180). Hand-over `bcda4cd29` (builder2: tests 2969/0; one net-smoke load flake,
green alone; ruled PASS R36.12). **On the scoreboard** (native's rows, builder2, 40 fights a main): "jammed AND under fire" 1.48 -> 1.20
a fight, inside its noise (± 0.76 re-sized), as predicted before the row: the crews T8 releases die later in the open fight. **Native
added the line T8 moves** (stream/native `0285bfe5f`, "killed while held at a street mouth", JAM_CENSUS held_deaths, back-filled from
each row's own logs): **1.65 a fight at e45bb6632 -> 0.42 at 3d46b2884, noise ± 0.40.** T8 is the one move on the board past its noise.

**Also done:** R36.4 **yieldgap** (T9 read a long-hull pair pinned nose-on as "passed": a tank + artillery touch at 8.95 m, YIELD_CLEAR is
9 m centre to centre): `76aea1185`, quick 105/0; merged OFF on main in manoeuvre's S2a pair (`32ba4ca99` green, 2967/0), judged in
S2a's series. **Stretch 5:** the held-crew loss is closed (31 of T8's 32 remaining held deaths were killed by their first hit; a group
release is recommended against). **jam:yielding read + two-fight trace:** 9 of 11 are a CPU element HOLDING a screen /
support_by_fire seat in a one-hull street that another element drives through. That is seating, not routing and not traffic (R36.11:
round-37 candidate for brains' seating). **R36.11 observer hazard:** `_pass_lane` (and any drive query) called from a physics_frame
probe builds the frame's avoidance snapshot early. It is not a game bug; a judging.md note was added, and `--yield-trace` is inert by default.

**Tooling added:** t8_series.sh survives Spot preemption (verdict line only, retries, series loops to completion); `make traffic-t8-clip`
(`traffic_clip.gd --hit-held`); jam_census `--yield-trace`.

**Questions for the lead:** none. **Requests to other streams:** none open.
**Known issues:** builder2's checks run loaded (perf-judge NOT JUDGED on every check this round), so the main perf-judge (T8 + joint + D5 +
S1/S2a) is the orchestrator's, in a quiet builder0 window.
**What to playtest:** `make skirmish ARENA=terminus` or `ARENA=locks`: when two of your squads meet in a street and one waits its turn,
shoot the waiting crew. It should drive on instead of sitting until it dies. `make traffic-t8-clip` shows it (counters: ON 5 holds
released for fire after 5 hold ticks; OFF 1712 hold ticks).
**Next steps (round 37):** CPU seating out of other elements' paths (R36.11's ruling); yieldgap's result from manoeuvre's S2a series.
**Merge notes:** stream/traffic is not a merge candidate itself (tooling and docs only; everything game-side is on main). Branches kept:
`pair/holdfire-r36` (judged), `pair/holdfire-r36-ho` (merged), `lab/yieldgap` (merged via S2a), `lab/t8-yieldtrace` (measurement only,
do not merge). Side worktrees and builder2 folders removed.

### NOW (traffic, 2026-10-20 ~15:25 PDT)

| item | state |
|---|---|
| 1 carry-over (C36.1) | **DONE.** On stream/traffic, quick GREEN `c9b2fab03` (builder0, 83/0). |
| 2 T8 judged (C36.2) | **PASSES AS FILED.** Pair `a2de32420`, builder2, native, fixed arenas {terminus, locks, crossing, gorge, parade} x 1800–1827 (locks 1801–1828), n 140 paired, none missing, no twins; JOBS 10; load 4.7 at the start. Counter: released_fire base 0, arm 618. **G held deaths 253 -> 109 (−144, −57 %), se 21.3, drop − k·se = +108.9: PASS (6.8 se).** Guards, all PASS: stuck 871 -> 812; jam (T5) 267 -> 278 (line ≤ 295.5); open 4731 -> 4728; far loops 168 -> 126; kills 5812 -> 5752 (band ± 86); hit rate 0.725 -> 0.729; all friendly contacts 93916 -> 95881 (+2.1 %, line ≤ 96925); deaths team 0 2682 -> 2640, team 1 3187 -> 3178; tr_holds 3147 -> 3245 (≥ half); line 7 crossing arrivals 180/180 in all 4 cases both arms. Reported: hold crew-seconds 22275 -> 20229; all deaths 5869 -> 5818; standoffs 0/0. Raw: `references/round36/traffic/t8_series_a2de32420/`. Next: the ON hand-over on current main + its check, then the perf-judge window. **Hand-over `pair/holdfire-r36-ho` `bcda4cd29`** (main b917ba234 + T8 ON), builder2 `make native check` exited 2: 23 passed, 1 FAILED (net-smoke: one client tanks_seen=1/2, the load flake), 1 NOT RUN (combat-smoke), 2 NOT JUDGED (load); tests 2969/0; sim-baseline 13 unmoved. Alone re-runs on the same hash: net-smoke exit 0 (2/2 PASS), combat-smoke exit 0. T8's game diff = traffic.gd only; the branch needs a take-turns wait (two squads), which net-smoke's 2-player match never forms. **Waiting on the orchestrator's ruling.** |
| 3 perf-judge | **Ruled (R36.8): T8 ships on its hand-over check** (a per-hit release, no per-tick search); ONE perf-judge on main later covers T8 + the joint + D5 + S1/S2a, run by the orchestrator in the first quiet builder0 window. Nothing owed by traffic. |
| 4 seed twins | **DONE** (nothing to code; see below). |
| 5 stretch: held deaths T8 doesn't release | **DONE (note, no code).** `references/round36/traffic/held_after_t8.md`. Arm: 32 dead while held, 31 of them on the first hit (out of any hold rule's reach; a group release caps at 0.22 a fight: recommend no); 77 within 3 s after a hold, the same as base 75 (mostly shot driving at speed in the fight). The held-crew loss is closed. Next traffic loss: jam:yielding 215 (97 to the other squad in lanes): a round-37 trace proposed. |
| R36.4 yieldgap (orchestrator's go) | **Quick GREEN** `lab/yieldgap` `76aea1185` (builder0, 105/0, both long-hull tests PASS); merged here `5cb41002c`. Native's mirror + S2a stack: `pair/native-s2a-yg` `8e6a52fc9` (native's). Rides in manoeuvre's S2a series. Native twin GREEN `32ba4ca99` (builder0 quick, test_native_yield 13/0; nose-on ON 1 twinned 0 mismatches not recorded, OFF recorded); S2a+yieldgap pair `32ba4ca99` full check GREEN (builder0, exit 0, 2967/0, 25 + 2 NOT JUDGED, sim-baseline 13/13 unmoved); manoeuvre names it and runs the S2a series. |
| jam:yielding read (orchestrator's ask) | **DONE (note, no code, no new runs):** `references/round36/traffic/jam_yielding_read.md`. Arm (a2de32420, n 140): 151 of 215 to another squad's crew, median 1.4 s giving way at the death (42 % ≤ 1 s, 0.6 m/s); 27 under fire when it began (T7's no-lane residue), 47 killed by the first hit while giving way. Base = arm. Recommendation: no traffic bar; the lever is upstream (routing two squads head-on into a one-hull street); the asker's lane needs a 2-fight trace if wanted. |
| Stretch: T8 on the scoreboard (orchestrator's ask) | **Prediction filed before the row:** T8 will NOT show on "jammed AND under fire". Its series moved held deaths (253 -> 109 = −1.0 a fight), which the scoreboard has no line for; T5 jam deaths did not move (267 -> 278 / 140 = +0.08 a fight v the line's ± 1.11 on 40 fights); stuck −0.42 a fight v ± 1.91. Released crews die later as open:driving. To be read when native scores `3d46b2884`. |
| T10 (GO, orchestrator 2026-10-20 ~20:40) | **Design note + Bar T10 filed** (`references/round36/traffic/t10_design.md`, no runs). Read of manoeuvre's c947c62e3 table (n 172 give-ways): 124 within 10 m of the seat, 44 of them sent >= 10 m from it (+379 m seat-to-spot), 40 of the 44 askers another squad; 18 to along-only lead-outs. Rules, one arm, two switches DEFAULT_OFF: **G `seatyield`** (seat <= 10 m: of the spots legal today, take the nearest the seat; never adds or refuses a give-way) and **H `seathold`** (behind the mouth, seat <= 10 m: hold where it stands, then at its seat, if today's `_fits` incl. the passer's runs passes; no runs known, declines). Locks Bravo_1 stood 2.5/9.5/16.5 m behind the mouth's centre (back 29/36/43); whether it clears the passer's run the trace can't say: H's lab stage builds both. Terminus Bravo_4 (13 m from seat) is outside G; its f 799 give-way is inside. Bar: deciding = LOOP squads' give-way+hold metres away from seat down (orders' probe, 12 street cells x 6 fresh seeds); guards contacts, jam, standoffs, all-in, asker-clear seconds, T8's fight guards. **Question to the orchestrator:** G on native needs a mirror (as yieldgap); judge on native after native's mirror, or on the GDScript arm (S4's convention)? Next: lab tests first. **Built (2026-10-20 late):** G `seatyield` + H `seathold` + the asker-clear clock (`clearclock`, measurement, DEFAULT_OFF, both arms) on stream/traffic `d6d13c656` `839fae524` `82dcb4a31`; test_traffic_seat 8/8 (builder0 quick `82dcb4a31`, exit 0); quick `839fae524` 221/3 (the 3 = the old G stage, a wheeled law_tank takes no side spot: fixed). Ruled (orchestrator): judged on NATIVE; native mirrors G + the clock. **Pair `pair/t10-r36` `29b31ff26`** (main 41aefad16 + T10, picks clean); native's top `79ce37acc` (pair/native-t10b; laptop twins 0 mismatches; its builder0 quick queued). Series tooling `dd856f10b`: `tests/traffic/t10_series.sh` (check on the mirror top, builder2; clock inertness; orders' probe 12 street cells x 3641-3646 deciding; fights 5 arenas x 1900-1927 + crossings), `t10_probe.py`, `jam_ab --bar t10`. **Asked the orchestrator:** the deciding line read as orders' native away_m (all drivers) since the by-driver split is a GDScript-only probe. **R36.19 (main f5dffb29c):** deciding = orders' native away_m restricted to squads with `seat_near` > 0 in either arm, 24 fresh seeds 3641-3664 (sizing in t10_design.md: 6 seeds cannot pass). `seat_near` stream `53923a45e`; the granted probe field on the pair only. **Pair `pair/t10-r36` `1f0b4706c` quick GREEN** (builder0, 116/0, exit 0). Native: mirror of the seat_near count requested; series after native's top is green + the full check on builder2. |
| T8 smoke | `make traffic-t8-clip` (laptop): ON 5 held / 5 released for fire / 5 hold ticks; OFF 5 held / 1712 hold ticks. Sheets in `references/round36/traffic/t8_clip/`. |

**Lessons this session (in remote_builds.md via the orchestrator):** a Spot run that lost its host is not a result (the driver now
reads only the check's own verdict line); a green check prints "N passed, M NOT JUDGED" with no FAILED/NOT RUN field.
**Cleanup owed after the series:** `git worktree remove ../godot-traffic-t8` and builder2's `~/tank_squad/godot-traffic-t8`.
**Questions for the lead:** none. **Requests:** none open.

### Log

**Switch-OFF inertness: `a2de32420`, builder2, `sim-variants --traffic-off=holdfire`: base40 = the ON check's sim-baseline on 13 of 13 maps (T8 is inert off, and moves no sim-baseline map on). Series started ~14:53.** **T8 PAIR GREEN for the series: `pair/holdfire-r36` `a2de32420`, builder2, `make native check` exited 0, 2963 passed 0 failed, 25 targets passed + 2 NOT JUDGED (perf-judge, scenario_perf: load), sim-baseline 13 of 13 unmoved with T8 ON. Driver resumed 14:44:45 as unit `t8-series-r36d` (the stream copy of t8_series.sh, `7da1ab88e`: its NOT RUN guard had misread the green line; run with cwd = the pair tree, so h stays `a2de32420`).** **Quick of the merged carry-over GREEN: `c9b2fab03`, builder0, `make quick-remote` QUICK_BASE=main, 83 passed 0 failed (16 traffic/native/manoeuvre test files + lint, 1279 s).** **2026-10-20 ~14:10 PDT (traffic). Builder2 was preempted at 14:07:35, 4 min into the first check (void); the driver read the exit 255 as done, so it was fixed (`ee30b2194`: verdict line only, 3 tries, NOT RUN stops, series loops to completion) and the pair re-cut as `pair/holdfire-r36` `a2de32420` (same game code), unit `t8-series-r36c`, check from 14:10:30.** Earlier, ~14:00: CP36.1 landed (main `a318a2cd3`, adoption `e45bb6632`); merged into stream/traffic
(`4a2a0d349`, DEFAULT_OFF `["holdfire"]`). **Pair cut: `pair/holdfire-r36` `46e6ba8a9`** = `4a2a0d349` + the ON flip, worktree
`../godot-traffic-t8` (remove it and builder2's `~/tank_squad/godot-traffic-t8` after the series). **Driver** `t8_series.sh` running
as systemd unit `t8-series-r36b` (needs `--setenv=PATH` for gcloud: the first unit died on `gcloud: command not found`), out
`~/overnight-traffic/r36/t8series/`; its check started 14:00:43 on builder2 (the only full check there). Light quick of
`4a2a0d349`'s carry-over on builder0 running (`~/overnight-traffic/r36/quick1.log`).

**2026-10-20 (traffic, Opus).** Oriented. **Waiting on CP36.1** (main still `582650b36` at my start; the joint not merged).
**Done meanwhile:** item 1's carry-over STAGED as `6a564673a` on current main (not checked yet): T8's traffic.gd hunk with
`DEFAULT_OFF := ["holdfire"]` (T9's yieldfit2 comes through the joint, so not in my list), test_traffic_holdfire (+uid), the jam
tooling (jam_census `held_deaths`/`holdfire_on`, jam_ab `--bar t8` + seed twins, jam_table, test_jam_ab: OK locally, python),
t8_series.sh (OUT now `~/overnight-traffic/r36/t8series`), t7_clip + `make traffic-t7-clip`, round-35 references, judging.md's
notes. round35/traffic's judging.md ended in a stray `||||||| c55471a5e` merge marker: left behind. movement.gd is identical to
the joint's. When CP36.1 lands: `git merge main` (one expected conflict, the DEFAULT_OFF line: keep `["holdfire"]`) ->
`make quick-remote`.
**Item 4 (seed twins), read:** jam_ab and jam_table carry `seed_twins.filter_logs` (in the carry-over); far_table already has it on
main; "far_ab"/"far_kills" don't exist as files (far_table is the far census reader). seq_hook reads runner rows of scenario cases,
never a random arena: not applicable. Nothing more to code; closed with the carry-over.

**Plan (ordered).** 1 carry-over (staged) -> merge main at CP36.1 + quick -> 2 cut `pair/holdfire-r36` + ON flip, t8_series.sh on
builder2 under systemd-run -> 3 ask for a quiet perf-judge slot -> 5 stretch: the held deaths T8 did not release (design note).

**2026-10-20 (orchestrator, at launch).** Not started. CP36.1 (the joint ship) was checking on builder0 at launch.
