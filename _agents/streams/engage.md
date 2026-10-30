# Stream: engage (his order to a crew wins: a lone scout he holds, stops or moves does exactly that until he gives another)

> Read `_agents/orchestration.md` (the worker contract; lesson 339), `_agents/judging.md`, `_agents/workstreams.md` **Round 45**
> (C45.1-C45.5). Your last brief: `streams/archive/round43/engage.md` (Status: the replay probe, trace rows, A7). `game_design.md` *His
> playtest after round 44*; the 2026-09-17 authority note quoted in `game/tactics/element.gd` (~line 1903). **You own:**
> `game/tactics/drills.gd`, `game/tactics/element.gd`'s player-authority code (`_detached`, the take-back, the `source == "player"` skip,
> `preempting`), `game/tactics/element_plan.gd`'s engagement functions (`_engage`, `_hold`'s in-range tests, the contact drill's moves;
> NOT settle, `grouped()` or converge), `game/tactics/element_situation.gd` (additive), `game/tactics/firing_position.gd`, GRANT
> `game/control/order_executor.gd`'s `stop` / `hold` / `move` / `attack_move` branches for a crew's own order, `game/ai/order_controller.gd`
> (trace lines; behaviour on the orchestrator's ruling), `tests/tactics/test_engage*.gd`, `tests/engage/**`, `tests/test_authority*.gd`,
> `mk/engage.mk`. **Model:** Opus. **Machine:** builder0 light lane (J<=4); builder2 for a series over 24 fights.
> **Seeds:** 11301-11348 (bar), 11349-11396 (reserve).

## The lead's direction (2026-10-29, verbatim)

"Then during gameplay, especially toward the end, I had a single scout I was trying to control (to not get it killed), and it routinely
kept going off and doing its own thing. I was trying to keep it out of combat, but it drew itself into an engagement I was explicitly
trying to avoid."

Standing (2026-09-17): *"if they get sucked into combat I have no control whatsoever"*. Memory: his direct order to a unit wins.

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **His case** (`references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl`; `make replay-match RECORDING=<that file>` is faithful
  20/20 for 30 s: extend `REPLAY_SECONDS` to 107 and say whether the scout's late game still reproduces). Green_Hunters_5 (gang_scout)
  is the last of its squad from 69 s; killed 105.3 s by Rust_Guns_2. From 83.7 s he gave it 9 moves, 3 stops and a hold in 20 s:
  - **HOLD at 99.2 s overridden within 1 s:** the element's task became `hold` "contact: return fire, take cover, report" (tick 2978,
    `drills.gd:168`), and the census shows `move` (src element) at 100 s then `attack_move` (src element) at 101 s, driving from
    (-45, 47) to (-47, 33) INTO the gap toward the enemy.
  - **After his STOP at 95.8 s** it was still driving at 97 s (z 55.5 -> 47, toward the enemy).
  - **His last move (102.6 s) to (-47.1, 31.1):** at 103 s it is at (-59, 8), 25 m past his click; blocked; dead 2 s later.
  - Short moves 1-11 m "never arrived" (83.7, 85.2, 87.0, 91.8 s).
  - The one-crew squad's formation read `swarm` / `coil`; whether its slot sits off his click is NOT measured.
- `element.gd` detaches a crew the player orders "until that order is finished, then quietly takes it back" (header ~line 20,
  `_detached` ~1440-1520). Unchecked suspicion: a hold or stop "finishes" at once, the element takes the crew back, and the contact
  drill re-orders it. Prove or kill by removal.

## Backlog (in order)

1. **E1 which layer moved the scout, by removal.** On his replay (and a scripted dev scene: one crew left in a squad, enemy 60 m off,
   he holds / stops / moves it), remove one layer at a time (the element's take-back, the contact drill, the one-crew formation slot,
   the drive's arrival) until his hold holds, his stop stops and his move lands within 3 m. A table in Status: per order of his, what
   issued the next row and why. Cause before rule (C43.3); message the orchestrator.
2. **E2 the authority rule, ON by default, `--player-authority=off` the escape (C45.2: the smallest change that removes what he saw).**
   A crew carrying his direct order (stop, hold, move, attack-move to a point) stays detached from its element until HE gives it or
   its squad another order; its element never re-tasks it, its squad's drill never moves it; it still turns and fires from where it
   stands under hold / stop (a held crew is not a dead crew). A squad task he gives later takes it back (R2, newest word wins). His
   move ends at his click (within the arrival radius), not past it. Tests first, from E1's cause.
3. **E3 Bar E1**, filed in `workstreams.md` *Bars (round 45)* BEFORE any number on 11301-11348, NARROW: deciding lines on an
   authority probe (crews of every kind, alone and in a squad, ordered hold / stop / move near contact: metres moved under hold /
   stop <= 2, element-sourced rows while his order stands = 0, move ends within the arrival radius); guards: fights (his kills /
   losses, the CPU's, within base +/- 1.645 se; does a held crew still shoot back), a squad order after a crew order takes the crew
   back (100 %), orders' G1 probe and manoeuvre's one-squad arrival unchanged (C45.3). The CPU has no player orders: say so (C45.5).
   Ships ON the minute it passes; message the orchestrator the green hash.
4. **E4 his acceptance read:** the shipped tree on his Gorge replay from 83.7 s; per order of his, what the scout did; shots looked at.
5. **Stretch:** the short moves 1-11 m that never arrived (whose arrival radius swallowed them); a one-crew squad's formation slot
   (does `swarm` / `coil` place a lone crew off the click).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make replay-match RECORDING=... REPLAY_SECONDS=107`; `mk/engage.mk`
targets; a scripted scene with screenshots of the held scout under fire, looked at. Every number with its commit and machine.

## Don't touch

`game/control/**` beyond the grant (orders), movement / traffic / formation / `grouped()` / converge (manoeuvre), `native/**` (ask
native for twins), the planner (trace lines only), `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If E1 shows two reasonable readings of "keep it out of combat" (e.g. a held crew retreats from fire v stands),
write both in player terms with one recommendation in Status and build the recommended one (stands and fires: what he ordered).

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### FINAL REPORT (round 45, 2026-10-29 ~23:30 PDT) — read this first

- **Shipped ON:** E2, his order to a crew wins (main 8ef4f584d, R45.19), and its bug fix R45.24 (`player`-only re-latch: fea4cfbec
  GREEN builder0 3459/0, on main as 2e3bc4620). What he notices: a crew he holds stands and shoots; one he stops brakes and stays; one
  he moves (alone or a squad of one) goes to his click and stays; his squad's hold sends nobody at the enemy.
- **Bars:** E1 FAIL as filed (D1 5.5 m, D3 one move, G3 a probe artifact), shipped ON by the orchestrator under C45.2; E2b FAIL as
  filed (G5: the cap reached GDScript-executed stops native runs itself), so **E6's stop cap stays OFF** (`--turn-in-cap=on`).
- **Causes found:** E1 (the hold ran the contact drill; the stop drove back to a point behind the scout); E5 (his short moves: the
  drive's three-point turn backs away ~1 s, manoeuvre's); E6 (a fixed-gun scout's turn-in under his stop); the replay parting above.
- **Replays of his pre-E2 matches** need `REPLAY_FLAGS="--player-authority=off"`.
- **Round 46:** E6's cap with the one-condition fix (fixed mount + wheels = native's hand-back case), a workload that stages a fixed-gun
  scout stopped with the enemy outside its arc, fresh seeds; E5 is manoeuvre's (a k-turn on a short move inside the turning circle).
- **Machines:** one check lost to the laptop crash, one to a builder0 OOM at 19:52 (exit 137 shards, several series beside a check).

### Report (2026-10-29, round 45)

**Shipped ON (main 8ef4f584d = engage 69bf864d2; the merge hash 60262534f GREEN builder0, 28 targets ALL JUDGED, 3451/0):** his
order to a crew wins (`--player-authority`, ON; `=off` the escape). In player terms: a crew he holds stands and shoots from where it
is; a crew he stops brakes and stays; a crew he moves (alone, or a squad of one) goes to his click and stays there; none of them is
sent anywhere by its squad until he gives it or its squad another order; his squad's hold no longer sends crews at the enemy.

| Item | State |
|---|---|
| E1 which layer moved the scout | DONE: the hold ran the squad's contact drill (30 m into the gap); the stop drove back to a point behind a 15 m/s scout, then the idle brain crept on; the last move was right, the drill had carried the scout past it (table below) |
| E2 the rule, ON | DONE, merged (R45.19). Code in drills.gd, element_plan.gd (`_hold_in_place`), element.gd (`_his_lone_order`), tank_brain.gd + order_feed.gd (granted R45.2) |
| E3 Bar E1 | **FAIL as filed** (D1 5.5 m v 3.0; D3 1 move off, the drive's in both arms; G3 35/38, a probe artifact: below); D2 798 -> 0 and every fight guard PASS; shipped ON by the orchestrator under C45.2 (R45.19) |
| E4 his acceptance read | DONE: his Gorge replay, rule ON from 83.3 s: hold holds, stop stays, moves land at his click, **scout alive at 108 s v killed at 105.3 s**; before / after shots below, looked at |
| Stretch: short moves / one-crew slot | READ: the one-crew slot sat ~5 m off his click; E2's squad-of-one path removes it; the 2-3 s a 15 m/s scout takes to reverse is the drive (manoeuvre's) |

**Before / after (his Gorge replay, builder0, 60262534f, native ON; both windowed runs checked against his census):**
`~/overnight-engage/r45/bar/shots/before-t*.png` (`--player-authority=off`, his game: 20/20 crews within 3 m for 105 s) v
`e4-t*.png` (rule ON from tick 2500: 19/20 within 3 m for 107 s, the one over the bar is the scout from 89 s, the rule acting).
Looked at, t3030 (101 s): BEFORE, his log "Rat Rod: hold position" while the card reads "Orders: Attack-moving – Arrives in 3 s"
and an ATTACK-MOVE marker sits 12 m into the gap ("react to contact – return fire, take cover"); AFTER, card "Orders: Holding", log
"stop -> hold position", the scout on his side of the gap, gun on the enemy across it. (The chain's `base-t*.png` were the rule ON
from the start, NOT his game: ignore them.)

**What to playtest:** `make skirmish ARENA=gorge` — give one crew (or a squad of one) a hold, a stop and a move near the enemy; it
should do exactly that until you order again. The old game: `make skirmish ARENA=gorge SKIRMISH_FLAGS="--player-authority=off"`

**Decisions:** a held crew under fire STANDS AND FIRES (the brief's recommendation), it does not back out; a crew he wants out of
combat he moves out, and it then stays. His squad-wide hold also holds every crew on its own spot (round 6's "a task does what its
name says"); the CPU's holds keep their drills (C45.5).

**Questions for the lead:** none blocking. Feel check for his next playtest: after his move, a crew now waits where it arrived
(turning and shooting) instead of fighting around the spot; if he wants crews to chase a little after a move, that is a new rule.

**Known issues:** D1: a held / stopped scout can still shuffle 3-5 m after first resting (11315 3.1 m, 11330 4.0 m while its stop
completed, 11344 artillery 5.5 m identical OFF); not isolated. D3: one IFV move ends 11 m short in both arms (the drive). The probe's
take-back metric fix (R45.19) is below.

**Merge notes (shared files):** `game/ai/tank_brain.gd` (switch-gated: `_his_order` / `_his_post`, the stop brake in MOVE, the
hold-at-rest in `_update_order_progress`) and `game/ai/order_feed.gd` normalize (additive `player`, `here`), both R45.2;
`tests/test_manoeuvre_turn_hull.gd` one-crew stage pins `--player-authority` off (R45.10).

**R45.19's take-back fix (the probe's, after the merge, its own commit):** take-back = a NEW order (a new order id) reached the crew
within 1 s of his squad task (it was "the goal is within 20 m of the probe's point", which an off-arena point grounded by Orders
fails). Re-read on 11301-11348, builder0, 60262534f's game code, n = 48/arm: **every other field on every seed byte-identical** to
the frozen bar's logs (0 differences either arm); take-back **OFF 40/40, ON 37/38** (was 38/40, 35/38): 11326 and 11345 now read
taken. The one ON miss, **11321**, traced: his move (id 2) still stands (the tank stuck 9 m short of its goal: the drive), and the
squad's take-back point (118.5, -86.6), off the arena, grounds to exactly that move's goal (92.4, -72.3), so Orders deduplicates it
("Already doing that"): no new id, but the crew is already on the squad's newest word. Not a missed order; he cannot click off the
map. No test was written for a probe metric; the byte-identical re-read is the proof R45.19 named.

**Closed (2026-10-29 ~16:00 PDT):** main 8ef4f584d GREEN builder0 (3453/0, 28 targets ALL JUDGED, `make check exited 0`, the
orchestrator's check) carries E2 ON; the probe fix 4b359f635 merged on top (tests/engage only). stream/engage fast-forwarded to main
6c4a3592a. Backlog done; idle until the orchestrator sends something.

### E5 / E6 (stretch, sent 2026-10-29 ~16:00 by the orchestrator)

**E5 cause (no fix of mine: manoeuvre's, relayed R45.22):** his short moves on Gorge were not swallowed by any arrival radius (with
E2: 87.0 and 91.8 s land at 3.1 / 3.4 m, inside the brain's 3.5). 83.7 and 85.2 s were replaced by his next click 1.5-1.8 s later
because the DRIVE backed away first: the scout was reversing at 7.4 m/s (the idle fight's stand-off) and his click lay ~56 deg off its
nose, 10.7 m, inside a wheeled scout's turning circle: the mover planned a three-point turn (`_kturn_left_m` 2.0 -> 0, throttle -0.7
for ~0.9 s, 3 m away from his click). The brain sends `reverse: false`; `Movement.reset()` clears the old k-turn and the drive plans a
new one at once. (Trace: `make engage-authority-trace AUTH_TAG=e5 AUTH_FLAGS="--player-authority=off --authority-on-at=2500"`, rows
`yaw`, `thr`, `kturn_m`, `behind`.)

**E6 cause:** under his stop the brain's move is `stop` from the first tick, but `OrderController._stop_turn_in` (C33.9,
`Manoeuvre.turn_in`) drives a hull-FIXED WHEELED crew round to bring its gun onto a live enemy (11330: throttle 0.87 for 21 ticks,
the turn-in counter (Manoeuvre.turn_in_stops) +1 every tick, 4 m). Under his hold the same idea is the face branch's wheeled creep (11315, throttle 0.35).
**Ruling R45.22: (b)**, measured from where the crew first comes to rest; grant: the cap in `_stop_turn_in` and the face branch.
**Built (7babd0390+):** `OrderController._his_cap` (`--turn-in-cap=off` the base arm): under HIS STOP no turn-in leg above 3 m/s, none
away from the rest spot past `TankBrain.TURN_IN_CAP_M` 2.5 m (braking distance counted), and the turn goes with the throttle (wheels
roll on a pure turn). **Decided against capping the hold's face creep too** (built and measured, dev 7003, builder0: a lone law_scout
he held moved 4.8 m instead of 2.9, fired 54 shots instead of 131 and died: the cap broke the wheeled multi-point swing into a drift),
so his holds keep E1's 3 m slack as shipped. Test `tests/test_authority_stop_cap.gd`: his stop ends 2.5 m from rest ON v 7.0 m OFF,
shots 29 v 34 (builder0). Dev seeds 7001-7012: probe byte-identical base v cap (no dev seed stages the case).

### Bar E2b (FILED 2026-10-29 ~16:40 PDT, before any number on 11349-11396)

**Arms:** base = without the cap (E2 as shipped), new = with it; since R45.24 the cap is OPT-IN until this bar passes, so
base = no flag and new = `--turn-in-cap=on` (the same comparison, spelled the other way: no line changes); both `--player-authority` ON; one frozen tree (named at
freeze), builder0, native ON, paired by seed. **Workloads:** (S) the authority probe with `--verb=stop` on 11349-11396 (his stop,
every crew kind drawn, alone or one crew of a squad); (M) the authority probe as drawn (Bar E1's mix) on the same seeds.

**Deciding (S, his case = alone):** D1 where his stop ENDS (`stop_moved_m`, from rest until the stop completes): max over rested runs
<= **3.0 m** (the 2.5 m cap + 0.5 m: a leg cut at the cap's braking estimate still settles); D1b no run ends farther than base + 0.5 m.

**Guards:** G1 (M) Bar E1's D2 (pushed rows 0), hold max moved (base +/- 0.5 m: holds are not changed), D3 move ends; G2 fights (S
and M): deaths new <= base + max(1, 1.645 sqrt(base)), enemy hp left within 1.645 se; G3 a stopped crew still shoots back (S): shots
mean new >= base - 1.645 se, and **how many fewer** is reported (a fixed gun that may not swing round fires when the enemy enters its
arc: R45.22's trade); G4 take-back (by order id) unchanged; G5 native-on v `--brains-off=native` EQUAL on (S) new; G6 `make check`
green on the frozen tree; the CPU untouched (sim-baseline).

### R45.24: the `player` fix (a bug on main since 8ef4f584d) — merge hash fea4cfbec

**fea4cfbec GREEN builder0** (`make check exited 0`, 28 targets ALL JUDGED, 3459 passed / 0 failed; the re-run after builder0's
19:52 OOM killed three test shards, exit 137, and the run before that was stopped by the laptop crash). Carries 12c9e673d: E2's
hold / stop re-latch ("holds where it comes to rest") now requires `order.player`; it had tested only the player's TEAM, so an
element's pointless hold on his team (ElementPlan._hold) had its spot dragged after issue (3.8 m in `test_authority_element_hold`,
which fails without the fix). E6's stop cap rides along OFF (`--turn-in-cap=on` until Bar E2b). Main 672067dc4 merged.

**His Gorge replay on fea4cfbec (builder0, native ON, 107 s):** `--player-authority=off` **PASS 20/20 within 3 m**; rule ON (the
default) **FAIL 4/20, first over Green_Hunters_1 @40 s** (unchanged by the fix). **Replays of his matches recorded before E2 need
`REPLAY_FLAGS="--player-authority=off"`** (`make replay-match RECORDING=... REPLAY_FLAGS="--player-authority=off"`), the same as any
switch that changed after the recording. **Why the rule-ON replay parts (traced, builder0, the
fixed tree; `make engage-authority-trace AUTH_UNITS=Green_Hunters_1,Green_Hunters_2 AUTH_FROM=300` ON v
`AUTH_FLAGS=--player-authority=off`):** the heading suspect is KILLED (yaw identical in both arms to 34 s). The first difference is
**Green_Hunters_2 at 28 s: option HOLD (rule ON) v ENGAGE (off)**, same spot and heading. It is the crew he stopped DIRECTLY at
24.3 s: in his game the finished stop left it idle and it engaged an enemy in reach; under E2 it holds where he stopped it (the rule
as designed). At his squad's attack task (34.4 s) the off-arm crew already had a target and its attack-move kept fighting (`attack`
by 38 s); the ON crew had none and drove (14 m further by 38 s); the squad's plan then differs and Hunters_1 parts at ~38 s. **A
genuine order of his that the rule changes, not a leak.**

**Bar E1's G6 on fea4cfbec (builder0):** orders-probe main v `pa_off` 48/48 rows IDENTICAL; manoeuvre-behind ON v off IDENTICAL for
tank, scout, gang_tank (181 rows each). PASS.

### BAR E2b VERDICT (2026-10-29 ~23:00 PDT): FAIL as filed (G5); E6 stays OFF (opt-in) — recommendation

Tree **fea4cfbec GREEN builder0** (3459/0, ALL JUDGED). Seeds 11349-11396, n = 48 per arm (4 lost the crew before his order in
every arm), builder0, native ON; arms base = no flag, new = `--turn-in-cap=on`. Logs `~/overnight-engage/r45/fix/{s,m}_*`.

| Line | base | new | Verdict |
|---|---|---|---|
| D1 where his stop ends, max (S) | 1.1 m | 1.1 m (<= 3.0) | PASS, **vacuous**: base never showed the drift |
| D1b no run worse than base + 0.5 m | - | 0 | PASS |
| G1 Bar E1's lines (M): pushed rows, held max, moves off | 0 / 6.5 m / 1 | identical | PASS |
| G2 deaths, enemy hp left (S) | 9, 195.9 | 9, 197.8 (se 14) | PASS |
| G3 held in range: shots (S) | 44.2 | 43.9 (-0.3, se 12.6) | PASS |
| G4 take-back | 35/35 | 35/35 | PASS |
| **G5 native-on v --brains-off=native (S new)** | - | **46/48 EQUAL** | **FAIL** |
| G6 make check | - | fea4cfbec green | PASS |

**G5's cause (mine):** native's execute step runs a `stop` itself unless the crew is a fixed gun on wheels (execute_native.cpp hands
only that case back to the GDScript, `_stop_turn_in`'s home). `_his_cap` tests only "his stop", so on the GDScript path it also
stopped other hulls' stop motion (11352 / 11362: a wheeled law_artillery's swing) that native never hands back; base native v base
GDScript on those two seeds is EQUAL (checked). The fix is one condition (`mount == "fixed"` and wheels: exactly the hand-back case),
which changes the frozen tree.

**Why not re-bar now:** on 48 fresh seeds the cap changed 6 runs, all fixed-gun wheeled scouts, with **no gain on its own deciding
line** (the 4 m drift never appeared in base) and mixed side effects (11363 ended 6 m nearer the enemy, 11371 did half the damage).
Recommendation: **E6 stays OFF (opt-in `--turn-in-cap=on`)**. Re-bar only with (1) the one-condition fix, (2) a workload that stages
the case (`--verb=stop`, fixed-gun wheeled scouts, the enemy outside the gun's arc), (3) fresh seeds from the orchestrator.

#### Working notes (chronological)

**BAR E1 VERDICT (2026-10-29 ~15:10 PDT): FAIL as filed (D1, D3, G3); D2 and every fight guard PASS.** Frozen tree **60262534f
GREEN builder0** (`make check exited 0`, 28 targets ALL JUDGED, 3451 passed / 0 failed). Bar seeds 11301-11348, n = 48 per arm,
builder0 light lane, native ON (decide native 45/45 ON-arm runs). 3 seeds lost the crew before his order in both arms (11307, 11314,
11339): no row. Table: `~/overnight-engage/r45/bar/judge/table.txt` (the 48 bar logs only; the folder also held dev-seed logs).

| Line | Filed | OFF | ON | Verdict |
|---|---|---|---|---|
| D1 hold / stop moved after rest | every run <= 3.0 m | max 42.6 m (9 runs > 2 m) | max 5.5 m (3 runs > 3 m) | **FAIL** |
| D2 element rows sending his crew elsewhere | 0 | 798 | **0** | PASS |
| D3 his move ends within the crew's arrival radius | every unblocked run | 3 outside | 1 outside | **FAIL** |
| G1 deaths | ON <= OFF + max(1, 1.645 sqrt OFF) = 10.0 | 6 | 7 | PASS |
| G1 enemy hp left (mean, se) | within 1.645 se | 184.3 (12.8) | 185.2 (12.1) | PASS |
| G2 held crews in range: shots | ON >= OFF - 1.645 se | 28.1 (n 21) | 34.1 (n 18) | PASS |
| G3 take-back within 1 s | 100 % | 38/40 | 35/38 | **FAIL** |
| G4 a squad's hold sends crews at the enemy | 0 | 278 rows | 0 | PASS |
| G5 native-on v --brains-off=native | EQUAL | - | 48/48 EQUAL | PASS |
| G6 orders-probe main v pa_off; manoeuvre-behind on v off | identical | - | 48/48 rows identical; 3 hulls x 181 rows identical | PASS |
| G7 make check | green | - | 60262534f green | PASS |

The failing runs (ON v OFF): D1 11315 lone law_scout hold 3.1 v 6.3 m; 11330 lone scout stop 4.0 v 5.4; 11344 artillery in a squad,
direct hold 5.5 v 5.5 (identical). D3 11337 lone IFV move 11.2 v 11.2 m from his click (identical: the drive). G3 11321 lone tank and
11345 artillery in a squad: not taken back in BOTH arms; **11326 lone law_artillery hold then a squad move: taken OFF, not ON (the
one run the rule makes worse).** Taken to the orchestrator the same hour (C45.2). **R45.19 (orchestrator): E1 FAILS as filed; E2 SHIPS ON at 60262534f** on
G6 passing (it did) and 11326's cause written here.

**11326's cause (traced, builder0, 60262534f + the take-back trace line, `--trace=on`):** the crew DID take his squad's new order on
the first tick (order id 2 -> 3, `move`, source player: E2's squad-of-one path). The probe's take-back point (-119.6, 85.3) lies
3.6 m OUTSIDE the drivable limit (116 m: the artillery stands 159 m from its target, near the edge, and the point is 30 m further
back); `Orders` puts an off-arena point back on ground 29 m inland ((-94.5, 70.8)), so the probe's "goal within 20 m of the point"
read it as not taken. OFF, the element's own inset landed within 20 m. Not a missed order, and not a case he can reach (his click is
always on the map). 11321 and 11345 fail the same test in BOTH arms (likely the same artifact; not traced). The fix is the probe's
(take-back = his new order reached the crew, by order id), after the merge, its own commit.
**11330 (stop, 4.0 m):** the scout read v < 0.5 m/s for a moment while braking (the probe's "rest"), then moved ~4 m in the next
second while the stop completed, under the stop's brake, no element row and no re-order. Not isolated further (time-box).

**E4, his Gorge replay (builder0, 60262534f, native ON, 107 s; rule OFF to tick 2500 = his game, then ON):** every move of his
reaches the scout as his order to his exact click and it holds there; his stop at 95.8 s brakes in ~5 m and holds; his hold at
99.2 s holds (0.3 m in 3 s; the card reads "Orders: Holding", the log "hold position"); his last move lands within 1-2 m of his
click; **the scout is alive at 108 s (killed at 105.3 s in his game).** Shots: `~/overnight-engage/r45/bar/shots/e4-t*.png` (LOOKED
AT: e4-t3030 shows the Rat Rod holding on his side of the gap, gun on the enemy across it). The `base-t*.png` set is NOT usable: the
camera did not follow the scout in that run (the frame barely moves from t3030 to t3075). Retaking the before set is the next item.

**NOW (2026-10-29 ~12:30 PDT):** Bar E1 FROZEN at **f853d2a92** (= main 47a15f434+ merged, E2 code 03217e0e4 + the probe's standable
click). Chain on builder0 (`~/overnight-engage/r45/bar/run.sh`): full check -> only if `make check exited 0`: Bar E1 on 11301-11348
(both arms + the native-off arm), orders-probe main v pa_off (seed 11301), manoeuvre-behind both arms, his Gorge replay base v E4.
Dev read on the frozen tree (dev seeds 7001-7012, n = 12/arm, builder0, native decide 12/12, NOT the bar): held max 8.3 -> 2.9 m,
his-case pushed rows 221 -> 0, moves outside arrival 2 -> 0, a squad's hold sent at the enemy 149 -> 0, take-back 12/12 both,
deaths 0 / 0; native-on v --brains-off=native EQUAL 12/12 (on the 03217e0e4 code, dev5).

**E4 dev read (his Gorge replay, his match as played to tick 2500, rule ON from there; builder0, native ON, 03217e0e4 code):** every
move of his reaches the scout as his order to his exact click and it holds there; his stop at 95.8 s: brakes from 14 m/s in ~5 m and
holds (no loops); his hold at 99.2 s: 0.3 m in 3 s, no element rows; his last move lands within 1-2 m of his click; **the scout is
alive at 108 s (dead at 105.3 s in his game).** Final read + shots on the frozen tree when the chain lands.

**Stretch, read from E1/E4:** (1) the short moves that "never arrived" (83.7-91.8 s): on his replay as played, each went to the
one-crew swarm / coil slot ~5 m off his click, and a 15 m/s scout reversing took 2-3 s to turn before the next click replaced the
order; with E2 a squad of one's move goes to his exact click (the slot is gone for a lone crew) and lands (E4: 2632 within 2.7 m,
2713 within 3 m, 3149 within 2.6 m). The reversal time is the drive (manoeuvre's), not authority. (2) the one-crew slot: measured
~5 m off (2700, 2754); removed for a lone crew by (b), so no formation change is asked of manoeuvre.

**Plan (order):** E1 cause by removal-trace (DONE) -> E2 rule behind `--player-authority` ON, tests first -> E3 Bar E1 filed before
numbers -> E4 his replay read -> stretch (short moves, the one-crew slot).

**E1 DONE: which layer moved the scout.** Workload: his Gorge replay, `make replay-match ... REPLAY_SECONDS=107 CREWS=all` =
**faithful, builder0 8d59b2bdf, 20/20 crews within 3 m every second for all 107 s** (`DIVERGENCE ... verdict=PASS`; ignore its
`REPLAY_NATIVE_MISMATCH replay=false` line, the 0.0 m table is his match). That run was the GDScript path (a fresh builder0
folder had no native library). Native (builder2, dc182916f) confirmed it a true read: native v GDScript replays of THIS match are
bit-identical (3042 crew-seconds, worst 0.0000 m), both equal to his census 3025/3025 s; not general (his round-43 Locks left
native at tick ~300). Since native's N2, `native-fresh` builds the library in a new folder and replay-match fails on a mismatch. Probe: `make engage-authority-trace` (new,
`tests/engage/authority_trace.gd`: per tick, the crew's K1 order + source, its element's task / drill / detached, the brain's option,
the mover's goal). Rows from builder0 8d59b2bdf, n = 1 replay (deterministic):

| His order (tick, s) | How it reached the crew | What issued the next rows, and why | What he saw |
|---|---|---|---|
| moves 2510-2838 (83.7-94.6 s) | squad TASK (a one-crew squad selected = whole squad, `rts_controls._is_task`), `drills: false` | element move; goal = the swarm / coil slot, **~5 m off his click** (2700: (-55.8, 78.1) v click (-55.9, 73.1); 2754: (-47.1, 68.9) v (-50.4, 72.7)); after arrival the order completes and the idle brain's ENGAGE drifts it ~5 m | short moves "never arrived": a 15 m/s scout reversing + the slot offset (stretch) |
| STOP 2873 (95.8 s) | DIRECT, source player (element disbanded) | TankBrain latches the stop's goal where the crew was when the order was READ (-42.6, 58.0); at 15 m/s it coasts ~7 m past, then the MOVE option drives loops trying to get back to that point: (-43.3, 47.0) at 2910, 11 m off, still `driving` | "after his STOP it was still driving" |
| STOP 2923 (97.4 s) | DIRECT | stop completes at 2926 -> order empty -> **idle brain picks ENGAGE** (post (-45.2, 47.0) is only a leash): 6 m toward the enemy by 2977 with NO order | the crew creeping on its own |
| HOLD 2977 (99.2 s) | squad TASK (element re-formed, task `hold`, drills on) | `Drills.select` -> **react_to_contact** ("return fire, take cover, report") -> `ElementPlan._engage`: `attack_move` 15 m toward the contact (out of reach) alternating with `move` to a firing spot, re-issued every update: **z 41.2 -> 12.0 by 3078, 30 m into the gap** | "drew itself into an engagement I was explicitly trying to avoid" |
| move 3078 (102.6 s) | squad task, drills false | element move to EXACTLY his click (-47.1, 31.1); the crew was already at (-59.8, 12.0), **22 m past it, carried there by the hold drill**; then blocked on terrain coming back | "ended 25 m past his click" |

Ruled out: the element take-back (`_adopt`) never acted (a direct order removes the crew from its element / disbands a one-crew
element); the drive's arrival (the last move's goal was his click); ElementCommander's rejoin (CPU only). The suspicion in the brief
("a hold finishes at once and the element takes it back") is killed: hold never completes; it was the task path's drill.

**Decision (two readings of "keep it out of combat"):** a held crew under fire either stands and fires or backs out of reach. Built:
**stands and fires** (what he ordered; the brief's recommendation). A crew he wants out of combat he moves out; it then stays there.

**Requests / messages:** orchestrator messaged 2026-10-29 with the cause and a GRANT REQUEST: E2's stop and post rules live in
`game/ai/tank_brain.gd` (+ an additive `player` key in `game/ai/order_feed.gd` normalize), because `order_executor.gd` (my grant) is
inert since TankBrain declares EXECUTES_ORDERS. Proceeding on the most reversible reading (switched, minimal, reuses the `hold` verb so
the C++ decide twin needs no new verb). Relay asked: orders (a squad of one goes down the task path), manoeuvre (the drive's arrival
is NOT the cause; the one-crew slot ~5 m off the click is a formation question).

**GRANTED (R45.2, orchestrator, main 6064df074):** `game/ai/tank_brain.gd` for the `--player-authority` switch only + the
additive keys in `game/ai/order_feed.gd` normalize. C45.4: native-on v native-off EQUAL on the authority probe before freezing.

**E2 (built, `--player-authority=on|off`, ON by default; `Drills.PLAYER_AUTHORITY`):**
- (a) `drills.gd`: his hold task runs no drill; `element_plan.gd` `_hold_in_place`: under his hold every crew holds its own spot
  facing the nearest contact (the halt re-seated a lone crew 5 m forward and a squad's crews up to 30 m).
- (b) `element.gd` `_his_lone_order` (C45.3): his move / hold task to a squad of ONE goes to the crew as his order (`source: player`,
  his exact click), and the crew stays detached (`HIS`) until his next task (`_retake`). Shift-queued tasks keep the element path.
- (c) `tank_brain.gd`: his stop brakes where the crew comes to rest (no drive back to where it was read); a hold he gave no point
  holds where the crew comes to REST (Orders fills the goal with the spot at issue, behind a 15 m/s scout); when his stop / move
  is done the crew holds where it finished (verb `hold`, the existing option: native decide needs no new verb) until its next order.
- `order_feed.gd` normalize: `player` (source == player) and `here` (a hold / stop with no point).
- The CPU: every rule reads `player` / the player's team; the CPU gives no player orders (C45.5). Proof: sim-baseline (CPU v CPU) in
  `make check` unmoved.

### Bar E1 (FILED 2026-10-29 ~11:40 PDT, before any number on 11301-11348)

**Workload:** `make engage-authority-bar AUTH_SEEDS="11301 ... 11348"` (`tests/engage/authority_probe.gd`, table
`tests/engage/authority_table.py --pair`): per seed a drawn arena (gorge / locks / terminus / crossing by seed), crew hull (8 kinds),
enemy gun (4 kinds), a lone crew (squad of one) or a squad of three, driving at a gun that shoots back from just outside the crew's
range; 2.5 s in, ONE order of his (hold / stop / move, by the RtsControls path: task for a squad of one's hold and move, direct
otherwise), standing 15 s; then his squad task (take-back). Arms OFF = `--player-authority=off`, ON = default, paired by seed, one
frozen tree (named when frozen), builder0 light lane, native ON. **His case** = runs where the crew is ordered alone (a squad of one,
or one crew of a squad given a direct order).

**Deciding (ON arm, his case):**
- D1 hold / stop: every rested run's farthest distance from where the crew first came to rest <= **3.0 m** (HOLD_TOLERANCE, the
  hold's own slack before it drives back; the brief's 2 m is under that existing slack, which this rule does not change).
- D2 element rows that send his crew somewhere else (attack, attack_move, or a move whose goal is over 3 m from the crew / from his
  click for his move) while his order stands: **0** in total.
- D3 his move: every run not dead and not ending `blocked` ends within the crew's own arrival radius
  (max(ORDER_ARRIVE 3.5, settle radius)) of his click; blocked ends are listed (the drive: manoeuvre's).

**Guards:**
- G1 fights: crew deaths ON <= OFF + max(1, 1.645 sqrt(OFF)); enemy hp left mean ON within OFF +/- 1.645 se of the paired
  difference (does his crew still hurt the gun).
- G2 a held crew shoots back: over held runs in range at the order, shots mean ON >= OFF - 1.645 se (if none is in range, UNREAD and
  said).
- G3 take-back: his squad task after his crew order reaches the crew within 1 s: **100 %** of living runs ON.
- G4 a squad's hold sends no crew at the enemy: squad pushed rows ON = 0.
- G5 C45.4: the ON arm native-on v `--brains-off=native` EQUAL on every seed (every probe field but the native flag).
- G6 C45.3: orders' multi-squad probe (`make orders-probe`, main v `pa_off:--player-authority=off`, ORDERS_PROBE_SEEDS 11301) rows
  identical (squad orders are element-sourced: the rule should not touch them); manoeuvre's player plain move (`make
  manoeuvre-behind`, both arms): arrival rows identical (post-arrival hold is after its measure).
- G7 `make check` GREEN on the frozen tree (sim-baseline unmoved = the CPU untouched, C45.5).

**What it could BREAK (named before the numbers):** a crew he left holding no longer drifts into a fight to help (G1, G2); a
squad of one's move now ignores the squad's formation (one crew, no formation to keep); a crew he stopped then forgot stands until
told (that is the rule, said to him in player terms).
