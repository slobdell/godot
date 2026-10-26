# Stream: balance (an all-tank army stops being the easy win; no faction a free win)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 41** (C41.1, C41.5,
> CP41.1) and *Rulings (round 40)* R40.1, R40.6, R40.16, R40.18-R40.25. Your round-40 brief: `streams/archive/round40/balance.md`
> (Status: FINAL REPORT, the candidate chain, Bar B2s's verdict, B5's write-up, *Next steps (round 41)*). **You own:** `game/units/**`
> unit numbers (C41.5), `tools/balance/**`, `mk/balance.mk`, round 40's brain paths (`tests/tactics/**`, `tests/rules/**`,
> `mk/tactics.mk`, `mk/rules.mk`); `game/combat/weapons.gd` / `armor.gd` numbers only if B5 needs them. **Model:** Fable.
> **Machine:** builder2 (series, J24), builder0 light lane for checks. **Seeds:** B5 bar 9201-9240 + 9301-9340, B5 dev 9401-9440;
> Bar B2s v2 8801-8840 + 8901-8940 (filed round 40, unread).

## The lead's direction

Combined arms (2026-10-24): "using a variety of units should theoretically create the advantage ... having a mix of unit types should
protect other units' weaknesses." Target (R40.6): a well-mixed army beats an all-tank army of equal cost ~60-65 % (all-tanks 35-40 %).

His answer to the IFV-missile recommendation (2026-10-26, verbatim): "what do you mean by giving the IFV a slow, limited anti-tank
missile? Isn't this just turning an IFV into a tank? What about making the tanks slower than they currently are? Or what about making
tank's turrets turn slower?" **So his levers go first; the missile is not built** unless his levers fall short and he asks for it.

Faction balance (R40.1): "when a faction keeps losing, we should change its units' numbers" (+/-15 %; gangs loses in his play).

## Where things stand (main at launch: see HANDOFF)

- All-tanks beats its own faction's mixed deal 82-84 % (CPU v CPU, every map, 320 fights). Cause (B5): about half of each mixed army's
  money can't hurt a tank's front. Armour (armor.gd `penetration_multiplier`, autocannon penetration 5 v tank armour front 8 / side 4 /
  rear 2): an IFV does ~5 % of its damage to a tank's front, ~50 % to its side, ~100 % to its rear. Tank turret 50-60 deg/s (scout 200,
  IFV 175-190); tank hull 9-12 m/s (IFV 10.5-13, scout 14-18). **Why his levers can work:** a slow turret and hull give fast units time
  to get round to the side and rear, where they do hurt. Whether the CPU's mixed army actually flanks is the open question.
- The faction stat change fm_c5r2_lawt5 (ARM d385cd308): v2 dev screen (R40.25, 5be511659 + overrides, builder2, 800 fights an arm):
  flatness 17.9 -> 7.0 (-10.9 +/- 2.2); all 10 G3 cells pass; syndicate blob 76 -> 17 % wins (watch). Its ARM is red on bridge-pooled;
  it waits on manoeuvre's Q3 (CP41.1).

## Backlog (in order)

1. **B5 his levers, dev screen (9401-9440, never a bar).** Arms against today's main, the mono-tank v mixed table per faction (B5's
   workload): (a) tank turret traverse slower (try ~-30 % and ~-50 %), (b) tank hull slower (speed and/or hull turn), (c) both. Read the
   all-tank win share (target 35-40 %), the faction table (must not undo flatness), the blob/turtle lines, fight length. Also read WHY:
   share of mixed-army damage to tanks landing on side/rear, before v after. If none reaches the target, report the gap and what moved
   it (the orchestrator takes it to him; the missile or penetration options come back only with his yes).
2. **Bar B5** on 9201-9240 + 9301-9340, filed before any number, for the lever B5's screen picks (combined with or separate from
   fm_c5r2_lawt5: say which, and why). Guards as Bar B2s (blob/turtle not up, lengths, time-cap, none line, perf, full check with the
   sim baseline adopted on purpose).
3. **Bar B2s v2 after CP41.1:** when the orchestrator tells you Q3 is on main, rebuild v2's ARM on that main + fm_c5r2_lawt5 + the
   R40.18 re-pins (cherry-pick ad956031b), full check + `sim-baseline-record`, then the filed bar (`~/balance-runs/bar-b2s.sh` with
   BASE/ARM edited, J24, `search.py bar`). If B5's lever ships first, say whether B2s v2 needs re-screening on top before running it.
4. **Then:** B3 faction-aware CPU (built OFF, round 40), B6 ADVANCE off a travel seat (traced, round 40).

## How to verify

`python3 -m unittest discover -s tools/balance`; `search.py check` (the from-behind rule); `make quick-remote`; a full check of every
hash you name. Playtest commands for him: `make skirmish SKIRMISH_FLAGS="--unit-overrides=<file>"` (N3's flag) with an all-tank army.

## Don't touch

manoeuvre's movement/traffic, orders' control, camera, `native/**`, `tests/baselines/**` (the orchestrator adopts). No new weapon or
ability. Don't push.

## Waiting on the lead

B5's read decides whether a missile/penetration question goes back to him.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**REPORT SKELETON (filled as the last arms land; the numbers above are final where marked DONE):**
- **Playtest for him (no change ships; the lineups exist today):** his all-tank army v the artillery-heavy CPU:
  `make skirmish ENEMY=cpu:siege ENEMY_FACTION=condemned` and `make skirmish ENEMY=cpu:gang_hail ENEMY_FACTION=gangs` (field
  only tanks in the garage); after 3ef8d5771 also `ENEMY=cpu:law_barrage ENEMY_FACTION=law` and `ENEMY=cpu:syndicate_barrage
  ENEMY_FACTION=syndicate`. His levers in a real fight: `make skirmish SKIRMISH_FLAGS="--unit-overrides=$HOME/balance-guard-raw/b5/overrides-t50.json"`
  (turret x0.5; `overrides-t50_ifv15.json` for the combined arm; N3's flag, the file is units only).
- **Merge notes (shared-path edits on stream/balance):** `game/modes/skirmish_mode.gd` demo_flags, one condition widened (R41.12,
  `begins_with("cpu:")`); `game/units/army.gd` two `measure_only` ARCHETYPES + `archetypes_for(faction, with_measure_only)`
  (callers: the explicit-name check asks for them; the roll and the garage don't); `tests/test_army_economy.gd` the digest skips
  measure-only lineups (one additive condition; its baseline unchanged); `tests/test_tactics_mono_army.gd` two tests;
  `tests/tactics/face_probe.gd` (+ .uid); `mk/balance.mk` balance-guard-run / balance-faces; `tools/balance/**`. No unit number
  changes on stream/balance (every arm was overrides or a --tune on a clean checkout).
- **Known issues:** `search.py apply` wrote into the script's own tree (fixed: `--tree`, printed); the harness has no
  `assert_false`; builder2's 50-fight calls idle ~3 min at each tail (J24 > 50 fights: use 20 seeds a call next time).
- **Next steps (round 42):** (a) if he says yes to the lineup answer: the CPU fields an artillery-heavy lineup against an
  all-tank player army (a deal rule in `Army.cpu_army` / the garage opponent: a design change, his call, measured 47-52 % and
  the barrage numbers); the garage suggests the same lineup to him; (b) Bar B2s v2 after the bridge (R41.13; the ARM rebuild is
  mechanical); (c) Bar B5 for t50 only if he wants the slow turret for feel (the lines screen below says whether it's safe);
  (d) B3 faction-aware CPU, B6 ADVANCE off a seat (not started this round: B5 took the round).

**Report (2026-10-26, in progress; started from main 98179d62b = code c36217f79 GREEN builder0, no baseline re-run).
RUNNING: B5 round 1 on builder2 since 02:34 PDT (8f2643375 + overrides; `~/balance-runs/b5-r1.log`). Probe smoke: 8f2643375 on
builder0's light lane, one gangs mono fight (terminus 9401, 150 s, th overrides): native on, UNIT_OVERRIDES applied, GUARD_RESULT +
FACE printed; `search.py faces` reads it (in that one fight the mixed side's artillery did 99 % of the damage on the slow-turret
tanks, which hit 11 of 19 shots: an anecdote). Quick-remote GREEN on 752f1b266 (builder0, `make quick exited 0`, 68 passed / 0 failed, 286 scripts lint); later commits are tools/docs only. First base run (gangs, mono on Green, 50 fights, 12 min at J24): mono wins 82 %, median 194 s; 73 % of the mixed army's DIRECT fire on tanks already strikes a side or rear (tank 38 % of it, Rat Rod 31, artillery 26, Gun Truck 4).**
Plan, in order: B5 plumbing (levers in the harness, a face probe for WHY) -> B5 round 1 on 9401-9410 (base, t50, h25, th; mono
line, 400 fights an arm, builder2 J24) -> read, expand the lever that moves the share (9411-9440, the lines for the faction table)
-> name Bar B5's lever and file the bar before any 92xx/93xx number -> Bar B2s v2 when CP41.1 lands (parallel if builder2 is free)
-> B3, B6. Reason: the mono line is the deciding read for his levers and the cheapest; the faction table follows the lever that works.

- **B5 plumbing (built, this branch):** `search.py` takes his levers at any size (C41.5: `turret_turn_rate_deg`,
  `max_forward_speed`, `max_reverse_speed`, `hull_turn_rate_deg`; `scale role:tank:turret=0.5,speed=0.75,hturn=0.75`, unclamped;
  the +/-15 % keys as before); `catalog_dump.gd` carries them. `tests/tactics/face_probe.gd` (extends guard_line, read-only)
  prints a FACE line a fight: each team's hull+shield points on ENEMY tanks by the face struck, by shooter role, and on every
  enemy; `mk/balance.mk balance-guard-run` plays guard-run through it; `tools/balance/guard_probe.sh` is guard.sh with that
  target's name (an adapter, guard.sh is native's); `search.py run --probe`, `search.py faces` (side+rear share, se by seed
  bootstrap, paired v base), `search.py mono` now prints the median fight length. Candidates: `t30`, `t50` (tank turret
  traverse x0.7 / x0.5), `h25` (tank hull forward+reverse speed and hull turn x0.75), `th` (t50 + h25). Catalog tank rows today:
  turret 60 / 70 / 55 / 50 deg/s (gangs / law / syndicate / condemned), hull 12 / 12 / 11 / 9 m/s, hull turn 55 / 85 / 90 / 80.
- **Decisions:** a slower hull slows reverse too (one lever, "the tank is slower"); hull turn goes with hull speed in h25 (his
  "slower than they are" read as the whole hull); t50 before t30 (if -50 % doesn't move the share, -30 % won't); 10 dev seeds
  first (400 fights an arm; the mono share's se was 3 at n 320, and the gap to close is ~45 points), the winner expanded after.
- **Questions for the lead:** none yet (B5's read decides).
- **B5 round 1 series (dev 9401-9410, never a bar; `~/balance-runs/b5-r1.sh`):** commit 8f2643375 + overrides, builder2 J24,
  GUARD_KINDS=none GUARD_SIDES=green, mono on Green then on Rust per faction (8 runs an arm, 50 fights each = 400 an arm),
  arms base, t50, h25, th, in that order; paired reads with `search.py mono ~/balance-guard-raw/b5 --match -mono-t50- --base-match
  -mono-base-` and `search.py faces` the same way. Expected (written before any number): base ~82 % mono wins as round 40; a
  lever that works moves the share down by > 10 points at this n (se ~2.5) AND the side+rear share of the mixed army's faced
  damage to tanks UP; if a lever moves the share without moving the faces, something else (fight length, the tanks' own
  fire) did it, and the read says so.

**B5 round 1, BASE arm read (8f2643375, builder2 J24, 9401-9410, mono line both teams, 400 fights, 0 attempts lost, 55 min):**
mono-tank wins **85 % (se 3)**: condemned 77 (se 9), gangs 78 (5), law 92 (2), syndicate 92 (3); on Green 82 / on Rust 87; median
fight 179 s (syndicate 94 s). Units: mono 21.5 v mixed 30.2. Same shape as round 40's 82 %.
**WHY, today (`search.py faces`, direct fire = every shooter role but artillery):** the mixed army's direct fire on the tanks
ALREADY strikes a side or rear **65 % of the time (se 1.0)**: condemned 62, gangs 71, law 66, syndicate 51. By shooter: the mixed
army's own tanks do 35 % of all damage on the mono tanks, artillery 34 %, scouts 13 %, IFVs **10 %**, lancers 7 %. So the fast
units are not failing to get round; the IFV's share is small even though 72 % of its hits land on a side or rear (its damage a
hit is small, and 2-6 % of IFVs live, round 40). What a slower turret / hull can still buy: fewer tank hits a minute (the tank
can't track a crossing target), and more time for the mixed army's artillery; the t50 / h25 / th arms say how much.

**B5 ROUND 1 DONE (2026-10-26 06:36 PDT; 8f2643375 + overrides, builder2 J24, dev 9401-9410, mono line both teams, 400 fights an
arm, 0 attempts lost, 4 h for 4 arms).** All-tank army's win share v its own faction's mixed deal, paired v base (85 %, se 3):
| arm (tank levers) | all | condemned | gangs | law | syndicate | median length | direct fire on tanks side+rear |
|---|---|---|---|---|---|---|---|
| base | 85 % | 77 | 78 | 92 | 92 | 179 s | 64.6 % |
| t50 turret x0.5 | 80 % (**-5, se 1**) | -7 (2) | -3 (5) | -7 (2) | -4 (2) | +8 % | +1.1 (0.7) |
| h25 hull speed + turn x0.75 | 81 % (-4, se 3) | -2 (7) | -3 (6) | -6 (3) | -4 (3) | -1 % | **-2.9 (0.6)** |
| th both | 80 % (-5, se 2) | -5 (5) | -1 (3) | -5 (4) | **-9 (3)** | +3 % | -2.5 (0.6) |
**Verdict:** each of his levers buys ~5 of the ~45 points to his target (35-40 %), and both together buy no more than the turret
alone (syndicate is the one faction where they add: -9). The turret lever works by the tank missing crossing targets (flank
share unchanged); the hull lever costs flanking (a slow tank crawls front-first). **Pick: t50 (the turret alone)**: as much as
th, one lever for him to feel, no flanking cost. **Round 2's combined arm is therefore `t50_ifv15`** (the orchestrator's rule:
th did not beat t50 by more than its se). Round 2 (ifv15, then t50_ifv15) started 06:36 on the same seeds; round 3 (the blob +
turtle lines for base / t50 / t50_ifv15 on 9411-9420, 200 fights an arm, Bar B5's guards as a dev screen) is queued behind it
(`~/balance-runs/b5-r3.sh`; stop by PID if Bar B2s v2's ARM goes green first).

**B5 ROUND 2 DONE (08:46; 8f2643375 + overrides, builder2 J24, 9401-9410, mono line both teams, 400 fights an arm, 0 lost):**
| arm | all | condemned | gangs | law | syndicate | median length | flank share |
|---|---|---|---|---|---|---|---|
| base | 85 % | 77 | 78 | 92 | 92 | 179 s | 64.6 % |
| ifv15 (IFV toughness +15 %, cost -15 %) | 82 % (-2, se 2) | -3 (4) | +2 (5) | -5 (2) | -3 (1) | +2 % | -0.9 (0.9) |
| **t50_ifv15** (turret x0.5 + ifv15) | **77 % (-8, se 1)** | -10 (4) | -10 (4) | -3 (3) | -8 (2) | +8 % (syndicate +52) | +0.7 (1.0) |
**The nearest arm inside his rules lands at 77 %, 37-42 points short of 35-40 %.** The IFV's dealt a credit under the combined
arm: condemned 0.8 -> 1.5, law 0.8 -> 1.15, still 4-8 % alive. Next (running): the deal arm (R41.12), then pen7, then the lines.

**DEAL ARM DONE (09:51; 9204009f6, builder2 J24, 9401-9410, mono line both teams, 400 fights, 0 lost; all-tanks v the faction's
named archetype at the same money, no stat change):** all **85 -> 73 % (-12, se 3)**; **condemned v `siege`** (2 artillery, 2
scouts, tank, IFV) **77 -> 47 % (-30, se 10)**, 38 % with the tanks on Green; **gangs v `gang_hail`** (2 artillery, 2 Rat Rods, Gun
Truck, Tanker) **78 -> 52 % (-26, se 6)**, 40 % on Green; law v `law_dragnet` (3 scouts, artillery, tank, suppressor) 92 -> 93 %
(+1); syndicate v `syndicate_standoff` (2 Spotter Platforms = its lancer, 2 Skimmers, Missile Ring, Gunship) 92 -> 99 % (+7, se 3). **What wins is artillery:**
5.1-5.4 points dealt a credit, 94-99 % alive at the end (condemned siege fields 10 artillery a fight v 2.9 in its normal deal).
The two archetypes that fail are the ones with no artillery weight (law's is three MG scouts; syndicate's Lancers die to the
Railgun in 30 s). So "a well-mixed army beats tanks" is TRUE today for the artillery-heavy mixes, with no number changed; the
CPU's seeded deal just rarely fields one, and law / syndicate have none to field. (Detail from the first reads, kept:)
**Deal arm, in progress (9204009f6, builder2, 9401-9410, paired with base):** gangs v `gang_hail` (2 artillery, 2 Rat Rods, Gun
Truck, Tanker; no tank): all-tanks **78 -> 52 % (-26, se 6)**, 40 % when the tanks are Green, 64 % when Rust; length +2 %.
Syndicate v `syndicate_standoff` (2 Spotter Platforms = its lancer, 2 Skimmers, Missile Ring, Gunship; no tank): all-tanks **92 -> 99 % (+7, se 3)**,
length +71 %: the Railgun Platform (110 m, 420 a shot) one-shots Lancers (1 % alive, 30 s lived, 0.43 dealt a credit); the
syndicate's best anti-tank unit IS its tank (1.58 dealt a credit in the base deal), so a no-tank deal loses harder. The deal
answer is per faction, not one rule. Law and condemned running.

**B5 round 2, ifv15 arm read (every IFV hp/shield/front+side armour +15 %, cost -15 %; same series, 400 fights, paired, 07:37):**
mono-tank wins 85 -> **82 % (-2, se 2)**: condemned -3 (se 4), gangs +2 (se 5; the Gun Truck's twin MG, pen 2.5, gets through
nowhere, so toughness buys it nothing), law -5 (se 2; length -15 %), syndicate -3 (se 1). The IFV's share of the damage on tanks
10 -> 12 %; its dealt a credit 0.8 -> 1.1 (condemned, law), still 6-7 % alive, ~66 s lived. Flank share -0.9 (se 0.9). **The
in-bounds IFV buff is worth ~2 points.** Combined arm t50_ifv15 running (ends ~08:30).

**B5 round 2c (queued behind the combined arm; the orchestrator's ask ~07:50; dev 9401-9410, NEVER a bar, OUTSIDE R40.1's keys: a read
for his decision):** `pen7` = the IFV guns' penetration up as a `--tune` on the base tree (autocannon 5 -> 7: Condemned IFV + Law IFV;
pulse cannon 6 -> 7: Syndicate IFV; twin MG 2.5 -> 4: Gun Truck), mono line, paired with base (`~/balance-runs/b5-r2c.sh`, driver
`b5-arm.sh` = b5-r1.sh + B5_EXTRA_ARGS). Static: an IFV behind a tank kills it in 11 s instead of 13, from the side 17 instead of 23,
from the FRONT 44 instead of 187 (the front stops being a wall: the design cost); v non-tanks only fronts change (IFV v IFV head-on
~3x). Expected (written before the number): 3-5 points. **Grant asked** (via the orchestrator): widen R40.7's demo_flags line to keep
any explicit `cpu:<archetype>` so a `deal` arm (all-tanks v the faction's anti-armour archetype: siege / gang_hail / law_dragnet /
syndicate_standoff) can run: "change what the mixed army buys" with no stat change. Round 3 (the lines) now waits behind 2c.

**R41.12 (granted ~08:00) at 9204009f6:** `SkirmishMode.demo_flags` keeps any explicit `cpu:<archetype>` (was: only cpu:mono_*);
`test_tactics_mono_army` pins the default path unchanged. **Deal arm** (`~/balance-runs/b5-deal.sh`, chained before pen7): all-tanks
v the faction's anti-armour archetype (condemned siege, gangs gang_hail, law law_dragnet, syndicate standoff), same money, mono on
each team, 9401-9410, paired with base. Expected (before the number): if these win 60 %+, the problem is what the CPU buys, not
the numbers.
**Incident (08:05):** the 02:20 dry run of the v2 ARM rebuild ran `search.py apply` from the scratch worktree, but `apply` wrote
into THIS tree (the script's own ROOT): units.gd / weapons.gd carried fm_c5r2_lawt5 uncommitted 02:20-08:05. No commit carried
them (adds by path); the series ran guard.sh's clean checkout of 8f2643375; but **the quick-remote "green" on 752f1b266 was of
that dirty tree and is void**: re-run on 88f9b139b: **GREEN** (builder0 `make quick exited 0`, 103 passed / 0 failed, 28 scripts lint; test_tactics_mono_army and test_control_showmatch in the filter). `apply --tree` now names the checkout and prints it. **Confirmed 08:15: `git status` in godot-balance is clean** (the smoke's untracked overrides/ removed too). **No B5 arm ran from the working tree:** every raw folder's driver.txt reads "8f2643375 on slobdell@builder2" (41 runs so far), guard.sh runs `git checkout --force --detach` + `git clean` in ../godot-balance-guard (now at 8f2643375 with no diff under game/) and overlays only mk/scoreboard.mk, guard_line.gd and tools/*; the remote tree is rsynced from that worktree, never from this one.

**Backlog item 3, Bar B2s v2: BLOCKED this round (R41.13, ~08:30): Bar Q3 FAILED**, the wait family stops, CP41.1 won't land, and
Bar B2s v2 (8801-8840 + 8901-8940) carries into round 42 unread. For round 42's notes (the orchestrator's fact): on 72 fresh
bridge runs (9025-9036 x 3 ticks x 2 sides) the v2 overrides tree with the rule OFF crossed 72/72, worst crew 2.2 s; its only
known bridge failure remains the 18-run drill's rust t15 s2 (R40.20). The ARM rebuild recipe (apply + cherry-pick ad956031b)
is proven mechanical on ff30edf87 (`apply --tree` now). builder2 stays on B5: the deal arm, pen7, then the lines screen.

**pen7 ARM DONE (10:51; 8f2643375 + `--tune=autocannon.penetration=7,pulse_cannon.penetration=7,twin_mg.penetration=4`, builder2,
9401-9410, 400 fights, 0 lost, paired with base; OUTSIDE R40.1's keys, a read for his decision only):** all-tanks **85 -> 85 %
(+0, se 1)**: condemned +7 (se 3), gangs -4 (se 4), law -2 (se 2), syndicate +1 (se 2); length +1 %; flank share +0.7 (se 0.6).
The IFVs did trade better (dealt a credit: condemned 0.81 -> 0.95, law 0.78 -> 0.96, Gun Truck 0.23 -> 0.50, its side-face rate
0.09 -> 0.48 a second alive) and still died (2-5 % alive, 32-64 s lived). **A sharper IFV cannon is worth ~0 points: the IFV's
problem is that it dies before its fire adds up, not what gets through.** Closed: not a lever for his target.
**pen7 arm, first run (gangs, mono on Green, 50 fights, 10:02):** the tune landed (GUARD_RESULT args carry it; the Gun Truck's
dealt a credit 0.23 -> 0.50, its side-face rate 0.09 -> 0.42 pts a second alive: twin MG pen 4 gets through a War Rig's side now);
all-tanks 82 -> 80 % (-2, se 3). Seven runs to go.

**Barrage arm (the orchestrator's ask ~10:05; queued behind pen7, then the lines):** `law_barrage` and `syndicate_barrage`
(army.gd ARCHETYPES, `measure_only`: never rolled by a seeded "cpu" deal nor offered by the garage; loads by name through R41.12),
siege's shape in each roster (artillery, scout, tank, artillery, IFV, scout), same money as the base deal. All-tanks v each, mono
on each team, 9401-9410, paired with base (`~/balance-runs/b5-barrage.sh`). Test pins the roll and the load. Quick-remote on the first cut failed twice (no assert_false in the harness; then test_army_economy's 17-archetype digest, which now skips measure-only lineups: one additive condition in a shared test, **merge note**); the arm runs on 3ef8d5771: **quick-remote GREEN** on 601963cd5 = 3ef8d5771 + Status (builder0 `make quick exited 0`, 269 passed / 0 failed, 71 scripts lint).

**B5 WRITE-UP FOR HIM (10:55; Law and Syndicate's barrage numbers pending, else final; the orchestrator takes it to him).**
*What you noticed is real, and it is not about facing.* An army of only tanks beats the same faction's normal mixed army, same
money, 85 % of the time (CPU v CPU, 5 maps, both sides, 400 fights). Your target was the mixed army winning 60-65 %, so the
tank army should win 35-40 %: about 45 points away.
*Your two levers, measured:* a tank turret turning half as fast (Condemned 50 -> 25 deg/s, Gangs 60 -> 30, Law 70 -> 35,
Syndicate 55 -> 27) takes the tank army from 85 to 80 %. A tank hull a quarter slower (and turning a quarter slower) takes it to
81 %. Both at once: 80 %. So each lever is worth about 5 points of the 45, and they don't add. The slow turret works the way
you'd expect: the tank misses more of what crosses in front of it. The slow hull doesn't get flanked more: a slow tank crawls
with its front to the fight, and the mixed army actually hit its sides and rears LESS (65 -> 62 % of its direct fire).
*Why the mixed army loses anyway:* its fast units already get round. Two thirds of the mixed army's direct fire on the tanks
lands on a side or rear today. The trouble is the IFV's trade. One Condemned IFV needs 187 s of fire to kill a tank from the
front, 23 s from the side, 13 s from behind; the tank kills the IFV in 9, 5 or 4 s. The IFV dies in one or two shells before
its flank fire adds up: 4 % of IFVs are alive at the end, and all IFVs together do 10 % of the damage on the tanks. Artillery
(34 %) and the mixed army's own tanks (35 %) do the work. The Gangs Gun Truck is the extreme: its twin MG can't scratch a tank
from any side, at any toughness.
*An IFV 15 % tougher and 15 % cheaper (your +/-15 % rule) takes the tank army from 85 to 82 %.* With the slow turret as well:
77 % (Condemned and Gangs 67-68 %, Law 89 %, Syndicate 84 %).
*So inside your rules the all-tank army ends near 77 %, not 35-40 %: the best in-bounds change closes about 8 of the 45 points.*
*But a different mixed army already beats the tanks, with no number changed.* We put the all-tank army against each faction's
artillery-heavy lineup at the same money. Condemned "siege" (two artillery squads, two scout squads, a tank squad, an IFV squad):
the tank army wins 47 % (38 % when it attacks from the Green side). Road Gangs "hail" (two catapult squads, two Rat Rod squads, a
Gun Truck squad, a Tanker): 52 % (40 % from Green). That is your target, today. What does it is artillery: a credit of artillery
puts 5 points of damage on the tanks and 94-99 % of it is still alive at the end; a credit of IFV puts 0.8 and dies. Law and
Syndicate have no such lineup to field: Law's "dragnet" is three machine-gun scout squads (the tank army still wins 93 %) and
Syndicate's "standoff" is Spotter Platforms (its lancer), which the Railgun Platform kills in one shot from 110 m (99 %).
*So the recommendation changes:* (1) give every faction an artillery-heavy lineup and make the CPU field it when it faces an
all-tank army (and show you the same lineup in the garage): no unit changes, the game already has the units; measured at 47-52 %
for the two factions that have one [Law and Syndicate: barrage arm, pending]. *What you'd do differently in the garage:* bring
two artillery squads with your tanks instead of IFVs (Condemned: two Artillery squads, two Scout squads for eyes, a Tank
squad, one IFV squad; Road Gangs: two Catapult squads, two Rat Rod squads, a Gun Truck squad and a Tanker). Keep the scouts: the
artillery only hits what someone can see. *What the CPU would field against your all-tank army:* the same lineup, so your
tank rush meets a wall of indirect fire it can't shoot back at until it closes, and the Rat Rods / Lancers open it from the
side while it closes. Today the CPU rolls one of three lineups a game and only one of them is this one (Law and Syndicate have
none), which is why your tanks have walked through most games. (2) The slow turret (5 points) only if you like how it feels. (3) The IFV's trade (it dies
in one or two shells before its flank fire adds up) is a separate, smaller question: tougher-and-cheaper buys 2 points; a
sharper cannon (armour-piercing 5 -> 7, so an IFV behind a tank kills it in 11 s instead of 13 and from the side in 17 instead
of 23) buys nothing at all (85 -> 85 %): the IFV still dies first. The missile is not needed for your target.

**B5 round 1, t50 arm read (tank turret traverse x0.5; 8f2643375 + overrides, builder2 J24, 9401-9410, 400 fights, paired):**
mono-tank wins 85 -> **80 % (-5, se 1)**: condemned 77 -> 70 (-7, se 2), gangs 78 -> 75 (-3, se 5), law 92 -> 85 (-7, se 2),
syndicate 92 -> 88 (-4, se 2). Median length +8 % (syndicate +37 %: 94 -> 128 s; the others +0-2 %). Faces unchanged: direct fire
on tanks side+rear 64.6 -> 65.7 (+1.1, se 0.7), so the lever works by the tank missing more, not by more flanking (the mixed army's
own tanks' damage a second alive 5.8 -> 5.1 condemned, 3.6 -> 3.7 gangs, 7.9 -> 7.9 law). **A real lever, a small one: ~5 of the
~45 points to his target.** Round 2's ifv15 arm is queued to start the minute round 1 ends (`~/balance-runs/b5-r2.sh`).

**B5 round 1, h25 arm read (tank hull speed, reverse and hull turn x0.75; same series, 400 fights, paired):** mono-tank wins 85 ->
**81 % (-4, se 3)**: condemned -2 (se 7), gangs -3 (se 6; on Green 62, on Rust 88: a noisy cell), law -6 (se 3), syndicate -4 (se 3).
Median length -1 % (syndicate +32 %, condemned -13 %). Faces: the mixed army's direct fire strikes a side or rear LESS, 64.6 ->
61.7 (**-2.9, se 0.6**; rear 19 -> 13 %): a slow hull doesn't get flanked more, it crawls with its front to the fight. As small a
lever as t50 and it costs flanking; **t50 is the better of his two levers so far**; th (both) runs now. Round 2's combined arm is
built as `th_ifv15` (or `t50` + ifv15 if th reads no better than t50).

**The IFV split (the orchestrator's ask, 2026-10-26 ~03:50; base arm's rows, no new runs; `tools/balance/trade_table.py`):**
(a) in the mono line every enemy of the mixed army is a tank: 100 % of IFV fire went on tanks and made 10 % of the damage, so
"busy with other targets" is not the cause here. (b) per second alive on tanks: condemned IFV 1.9 pts/s (0.5 front / 0.9 side /
0.5 rear), lives 64 s, 4 % survive; its tank 5.8/s, artillery 7.3, Lancer 5.9; law IFV 2.8/s (55 s, 2 %); Gun Truck 0.4/s (twin
MG pen 2.5 gets through nowhere); syndicate IFV 2.1/s (32 s). Dealt a credit: IFV 0.8 (condemned, law), 0.2 (gangs, syndicate)
v tanks 1.6-2.1, artillery 1.4-5.4. (c) the static trade (catalog through armor.gd, no aim): one condemned IFV needs 187 s of
fire to kill its tank on the front, 23 s on the side, 13 s on the rear; the tank kills the IFV in 9 / 5 / 4 s; per 1000 CR, IFV
28 / 3 / 2 s v tank 3 / 2 / 1. Per credit the IFV is near even on a flank ON PAPER but dies in one or two shells first: a tank's
gun (64 raw dps) is twice an autocannon's (33) at 1.33x the price, and its armour + hp buys 2-3x the life under fire. So 150 CR
of IFV is out-traded by 200 CR of tank at every facing in practice. His levers can cut the tank's hits (turret) and buy the
artillery / Rat Rods time (hull); neither touches the IFV's trade. In-bounds options for that trade: IFV toughness +15 % / cost
-15 % (R40.1's keys, a screen); beyond the bounds, the honest number.

**Bar B5 (DRAFT; filed for real, lever named, before any number on 9201-9240 + 9301-9340).** BASE = the tree as it ships
without the lever; ARM = the same tree + the lever's values written into units.gd (`search.py apply`), one frozen ARM
(R40.13). Workload: the mono-tank line (B5's: guard none, 5 guard arenas, mono on each team in turn, per faction; 9201-9240
+ 9301-9340 = 80 seeds x 5 x 4 x 2 = 3200 fights an arm) AND the blob + turtle lines on the same seeds (both sides, 1600 an
arm) for the guards. **Deciding:** the all-tank army's win share v its own faction's mixed deal down by > 2 paired se, toward
35-40 % (reported per faction; the gap left is stated in points). **Guards** (each fails at > 2 paired se the wrong way, as
Bar B2s): G1 blob line's win share not up; G2 turtle line's not up; G3 median length of each line within +/-15 % and of each
guard faction within +/-20 % (a slower tank makes fights longer: the band is the bar, not a target); G4 time-cap share not
up; G5 flatness not worse (the faction table must not undo what fm_c5r2_lawt5 buys, read on the lines); G6 perf-judge on
builder0 passes on the shipped hash; G7 full check green on the shipped hash (sim-baseline adopted on purpose by the
orchestrator). Judge: `search.py bar` extended for the mono deciding line (to be written before the series). Whether the
lever is judged alone or on top of fm_c5r2_lawt5 is named with the lever (default: alone, so his two questions get two
answers; v2's Bar B2s then re-screens with the lever in its BASE).
- **Requests to other streams:** native: a `GUARD_TARGET` knob in tools/scoreboard/guard.sh (default guard-run) would retire
  tools/balance/guard_probe.sh (not urgent; the adapter works).
