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

**Report (2026-10-26, in progress; started from main 98179d62b = code c36217f79 GREEN builder0, no baseline re-run).
RUNNING: B5 round 1 on builder2 since 02:34 PDT (8f2643375 + overrides; `~/balance-runs/b5-r1.log`). Probe smoke: 8f2643375 on
builder0's light lane, one gangs mono fight (terminus 9401, 150 s, th overrides): native on, UNIT_OVERRIDES applied, GUARD_RESULT +
FACE printed; `search.py faces` reads it (in that one fight the mixed side's artillery did 99 % of the damage on the slow-turret
tanks, which hit 11 of 19 shots: an anecdote). Branch tip 407876c0a (tools/docs only after 8f2643375); quick-remote on builder0 pending.**
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
