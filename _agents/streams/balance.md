# Stream: balance (the CPU meets his tank rush with artillery; Law's and Syndicate's artillery can hurt tanks; the faction stat change judged)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 42** (C42.1, C42.5,
> CP42.1) and *Rulings (round 41)* R41.12, R41.16, R41.18; your round-41 brief `streams/archive/round41/balance.md` (Status: FINAL
> REPORT, B5 WRITE-UP FOR HIM, the lines screen, *Next steps (round 42)*, the B2s v2 rebuild recipe). **You own:** `game/units/**`
> (unit numbers within C42.5; `army.gd`'s ARCHETYPES and `cpu_army`), `tools/balance/**`, `mk/balance.mk`, `tests/rules/**`,
> `mk/rules.mk`, `mk/tactics.mk`, your probes in `tests/tactics/` (`face_probe.gd`, `army_probe.gd`, the `*_table.py` / `*_bar.py`
> tools); GRANTS: `game/garage/garage_advice.gd` / `garage_opponent.gd` for the one suggestion line and the opponent deal (merge
> note); `game/modes/skirmish_mode.gd` demo_flags as R41.12; GRANTED 2026-10-26 (B7 call sites): `skirmish_mode.gd` `_start_match` loads both
> armies through `Army.load_pair()` before the spawn loop (stay clear of the `rig.facing` feed lines, camera's C42.3), and
> `game/garage/garage_mode.gd` `fight()` passes `screen.draft.to_doctrine()` into `GarageOpponent.build` as one argument (merge note). **Model:** Opus. **Machine:** builder2 (series, J24; `make gcp-start`,
> it is STOPPED at launch; Spot: read the verdict line, re-queue on preemption), builder0 light lane for checks. **Seeds:** B7 bar
> 9901-9940; B8 bar 10001-10040 + 10101-10140, B8 dev 10201-10240 (never a bar); Bar B2s v2 keeps 8801-8840 + 8901-8940 (filed round
> 40, unread); Bar B5 t50 keeps 9201-9240 + 9301-9340 (unread; only on his yes).

## The lead's direction

Combined arms (2026-10-24): "using a variety of units should theoretically create the advantage ... having a mix of unit types should
protect other units' weaknesses." Target (R40.6): a well-mixed army beats an all-tank army of equal cost ~60-65 %. His levers
(2026-10-26): "What about making the tanks slower than they currently are? Or what about making tank's turrets turn slower?" (measured:
~5 points each, R41.18). Faction balance (R40.1): "when a faction keeps losing, we should change its units' numbers" (+/-15 %).

**The round-41 write-up went to him (archived Status, B5 WRITE-UP FOR HIM) with this recommendation; his answer is pending and the
orchestrator decided the round starts on it:** (1) every faction gets an artillery-heavy lineup the CPU fields against an all-tank
army and the garage suggests ("bring two artillery squads with your tanks"); (2) Law's and Syndicate's artillery numbers within his
15 %; (3) the slow turret only if he likes the feel (its lines screen read G2 turtle +3.0 se 1.5: not safe alone); no missile.
A CPU that fields the counter is the CPU being smarter (memory: *smart AI on both sides*, symmetric improvements ship without asking).

## Where things stand (main at launch: see HANDOFF)

- B5 (R41.12/R41.16/R41.18): all-tanks v the normal mixed army 85 %; his levers -4/-5; IFV +15 %/-15 % -2; turret + IFV 77 %; pen7 0.
  **Artillery-heavy lineups reach the target with no number changed:** Condemned `siege` 47 %, Gangs `gang_hail` 52 %; Law `law_barrage`
  96 %, Syndicate `syndicate_barrage` 87 % (measure_only archetypes in `army.gd`: the Gas Rocket Truck deals 2.65 a credit v the
  Condemned Artillery's 5.4 and needs 79 s to kill an Assault Gun; the Missile Ring 1.06 a credit, 380 credits, dies to the Railgun
  in 5 s). `cpu_army` (army.gd:224) rolls one archetype a game from `archetypes_for(faction)` (measure_only skipped).
- Bar B2s v2 (fm_c5r2_lawt5, ARM d385cd308; 8801-8840 + 8901-8940 unread): BLOCKED on the bridge (R41.13); manoeuvre's Q6 is CP42.1;
  your rebuild recipe (cherry-pick ad956031b's re-pins onto the CP42.1 main) is proven. The v2 overrides tree crossed 72/72 fresh
  bridge seeds OFF; its only known failure is the drill's rust t15 s2.
- Tools: `search.py` (levers, `mono`, `faces`, `bar-b5`), `GUARD_TARGET`, the face probe; raw data `~/balance-guard-raw/b5`,
  `~/balance-runs` (keep).

## Backlog (in order)

1. **B7 the CPU counter-lineup, OFF behind `--cpu-counter=on|off` (ON when its bar passes).** First say in Status how the deal can know
   the player's army (the garage's opponent deal `garage_opponent.gd` sees his draft; a skirmish's `cpu` army may not): the rule = when
   the opposing army's cost is >= 60 % tanks (say the threshold with a reason), the CPU fields its faction's artillery-heavy lineup
   (`siege`, `gang_hail`, `law_barrage`, `syndicate_barrage`: the two measure_only ones become real lineups for this rule only); else
   today's roll. The garage suggestion: one line in `garage_advice.gd` when his draft is tank-heavy ("bring two artillery squads with
   your tanks"), ON (an `=off` escape). Bar B7 before any number on 9901-9940: deciding = all-tanks (each faction's `mono`) v the CPU's
   dealt army, ON <= 60 % pooled over the four factions (BASE ~85 %) AND paired < 0 by >= 2 se; guards (filed first): the mixed army v
   the CPU's dealt army within BASE +/- 1.645 se (a normal army doesn't get punished), fight length within +/-20 %, every faction's
   lineup dealt loads and fields within the unit cap (C25.6), demo and default `cpu` unchanged (test). A pass ships ON (the orchestrator
   tells him in player terms; his veto stands).
2. **B8 Law and Syndicate artillery within his 15 % (R40.1 / C42.5).** Dev screen on 10201-10240 (`search.py`, paired v base, 400 fights
   an arm as B5): Gas Rocket Truck damage +15 % and cost -15 % (each, then both); Missile Ring cost -15 %, toughness +15 %, both; read
   all-tanks v `law_barrage` / `syndicate_barrage` and the faction table (B2s's flatness and G3 fight-length lines). Pick the arm that
   moves all-tanks v barrage most toward 35-40 % without failing the faction lines; file Bar B8 on 10001-10040 + 10101-10140 before any
   number (deciding = that read; guards = Bar B2s v2's G1-G5 and flatness, unamended). On a pass the numbers ship (he hears the size).
3. **B9 Bar B2s v2 after CP42.1** (the orchestrator tells you the minute the bridge hash is on main): rebuild the ARM, run the filed
   bar, report. If CP42.1 never lands this round, say so in Status; the stat change carries again (do not loosen bridge-pooled).
4. **B10 Bar B5 t50 only on his yes** (a lead gate: the lines screen says G2 turtle +3.0 se 1.5 FAILS; the orchestrator tells him).
5. **Stretch:** B3 faction-aware CPU; B6 ADVANCE off a seat (archived round-40 Status).

## How to verify

`tools/balance/search.py` (every number with commit, machine, seeds, n, se); `make quick-remote`; a full check of every hash you name;
`python3 -m pytest tools/balance` if it has tests. Smoke like a player: `make skirmish ARENA=terminus` with an all-tank garage army v
the CPU: does it field artillery and scouts against you; the garage shows the suggestion line (screenshot it, desktop and phone).

## Don't touch

`game/tactics/**` (engage), movement / traffic (manoeuvre), `game/camera/**`, `native/**` (GUARD_TARGET is native's; ask via the
orchestrator), `game/combat/weapons.gd` / `armor.gd` except NUMBERS B8 needs (C42.5), `tests/baselines/**` (the orchestrator adopts).
Don't push.

## Waiting on the lead

His answer to the combined-arms recommendation (the round proceeds on it); the slow turret (B10).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Round 42, in progress (2026-10-26; started from main 18982e8df, launch green 21b20bdce, no baseline re-run).**

**Plan (in order; decisions in one line each):**
1. B7 code (DONE, OFF): the counter rule, the pair loader, the garage deal and suggestion line, tests first.
2. B8 dev screen (DONE 16:44, below: NOTHING SHIPS, no Bar B8 filed): "both" arms first (Gas Rocket Truck damage +15 % and cost -15 %; Missile Ring cost -15 %
   and hull/shield +15 %), v base, 10201-10220 (dev), 200 fights an arm a faction. *Why both first:* the largest move inside
   his 15 %; if "both" moves nothing, the single-change arms can't, and they are skipped (saves ~2 h of builder2).
3. Bar B8 (filed before its numbers) on the arm that moves all-tanks v barrage most, with the faction lines as guards.
4. Bar B7 on the tree that carries whatever B8 ships. *Why B8 before B7's series:* B7's deciding line is pooled over the four
   factions, and last round's dev reads (all-tanks v condemned siege 47 %, gangs gang_hail 52 %, law_barrage 96 %,
   syndicate_barrage 87 %, ~70 % pooled) say B7 alone would FAIL ≤ 60 %; its fresh seeds (9901-9940) are spent once.
5. B9 (Bar B2s v2) when CP42.1 lands; B10 only on his yes; then stretch B3, B6.

**B7 design (41d047cf3; R42.1 grant from the orchestrator):**
- *How the deal knows his army:* the garage knows it exactly: `GarageMode.fight` hands `screen.draft.to_doctrine()` to
  `GarageOpponent.build(..., opposing)`. The skirmish loads both sides first through `Army.load_pair` (before, GREEN loaded
  and spawned before RUST was dealt, so a CPU on GREEN could not see a tank rush on RUST), and each plain `cpu` side is dealt
  against the other side's army as named or rolled (so two plain CPUs are exactly their two rolls).
- *The rule:* opposing army's cost >= **70 % tanks** -> the CPU fields its faction's artillery-heavy lineup (`siege`, `gang_hail`,
  `law_barrage`, `syndicate_barrage`), seeded and bought the same way; an explicit `cpu:<name>` is never swapped. *Why 70 %, not
  60:* every army the CPU itself deals stays below it (the most tank-heavy, Condemned's `armor`, is ~63 % tanks, so a 60 % rule
  would counter the CPU's own armor rolls and change the demo); 70 % is seven tanks in ten, a tank rush. A test walks every
  archetype x 12 seeds x two budgets and pins every deal under the line.
- *The switch:* `--cpu-counter=on|off`, `Army.COUNTER_DEFAULT = false` until Bar B7 passes. A `CPU_COUNTER faction= tank_share=
  archetype=` line prints when it fires.
- *The garage line (ON):* a draft >= 70 % tanks gets "Bring two artillery squads with your tanks." first among the hints, when
  the faction's artillery is unlocked; `--tank-rush-hint=off` is the escape.
- *Tests:* `tests/test_army_counter.gd` (8): share, no rolled deal tank-heavy, the counter per faction (>= 2 artillery, cap,
  budget), OFF / named / mixed opponents unchanged, the pair whichever side loads first, OFF pair = each side loaded alone
  (default `cpu`, the demo, `player_default`), the garage deal ON/OFF, the hint. Laptop 8/8 at 41d047cf3's tree.
- *Smoke (laptop, 41d047cf3's tree, seed 9901, terminus, Law v Law, `--enemy=cpu:mono_tank` = the rush on RUST):* ON:
  `CPU_COUNTER faction=law tank_share=1.00 archetype=law_barrage`, GREEN fields 9 Pursuit Cruisers, 4 Retired APCs, 4 Assault
  Guns, 8 Gas Rocket Trucks; OFF: GREEN rolls law_line (4 / 8 / 8 Assault Guns / 4 Sonic Emitters), no counter line.

**Bar B7 (FILED 2026-10-26 ~15:20, before any number on 9901-9940).** builder2, one frozen commit (B7's code + whatever Bar B8
ships), BASE `--cpu-counter=off`, ARM `--cpu-counter=on`, nothing else different. Fights: all-tanks (`--<team>=cpu:mono_tank`) v
the plain `cpu` deal, same faction both sides (B5's line, BASE ~85 %), the four factions x mono on Green and on Rust x seeds
9901-9940 x ONE arena a seed (9901-9908 terminus, 9909-9916 locks, 9917-9924 sumps, 9925-9932 gorge, 9933-9940 parade), guard
none: 320 fights an arm, paired by (faction, team, arena, seed); se by bootstrap over seeds.
- **DECIDING:** all-tanks win share, pooled over the four factions, ARM <= 60 % AND the paired change < 0 by >= 2 se.
- **G1 (a normal army is not punished):** CPU v CPU, both plain `cpu`, the four factions mirrored, 9901-9910 terminus (40
  fights an arm): every fight's GUARD_RESULT (winner, seconds, tanks left) identical ON v OFF. (By construction no rolled deal
  reaches 70 %; this proves it in the game.) The mixed-army win share is therefore BASE exactly, inside BASE +/- 1.645 se.
- **G2 fight length:** the deciding fights' median length, ARM within +/-20 % of BASE.
- **G3 the deal loads and fields:** 0 load errors in 320 ARM fights; every countered army within the cap (ARMY_CAP_FIELDED).
- **G4 defaults:** `test_army_counter` and `test_tactics_mono_army` green on the frozen commit (default `cpu`, demo unchanged).
- Reported, not deciding: each faction's win share and change; how many ARM fights the counter fired (expected 320/320).
- **Expected before the numbers (from R41.16/R41.18 dev reads on 9401-9410):** condemned ~47, gangs ~52, law ~95, syndicate
  ~87 -> ~70 % pooled: **the deciding line fails on B7 alone**; it passes only if B8 moves Law's and Syndicate's barrage by
  ~40 points between them. A pass ships ON (the orchestrator tells him; his veto stands).

**R42.3 (the orchestrator's ruling, before any 9901+ number):** Bar B7's DECIDING is per faction whose counter FIRES (ARM <= 60 %
AND paired change < 0 by >= 2 se); the counter fires for a faction only if the dev screen shows its counter lineup beating the roll
(all-tanks v counter <= all-tanks v roll - 2 se); the pooled share is reported. The firing list goes in this Status BEFORE the 9901+
series. G1-G4 unchanged. **R42.4:** one line in `GarageScreen._hint()` shows the tank-rush line (below).

**The garage line (fa3ec097d):** `composition_hints` is shown nowhere in the game, so the line is `GarageAdvice.tank_rush_line`,
read first by the garage's status line under the credits bar: "Bring two artillery squads with your tanks · FIGHT when ready".
Looked at (laptop, a Condemned draft of 9 tanks + a scout, 1910 CR): desktop 1920x1080 and phone 1800x810 both show it in full
(`references/round42/balance/b7-garage-line/`).

**B8 result (DONE; commit 9d8e26e44, builder2 J24, dev seeds 10201-10220 x 5 arenas x mono on Green and on Rust, guard none,
n 200 an arm a faction, paired v base on the same seeds; `search.py mono ~/balance-guard-raw/b8`):** all-tanks v law_barrage:
base **96 %** (se 1), b8_grt_both (Gas Rockets 63.25 damage + Gas Rocket Truck cost 213) **92 %** (se 2), paired **-5 (se 3)**,
length -0 %. All-tanks v syndicate_barrage: base **84 %** (se 2), b8_mr_both (Missile Ring cost 323, hull 253, shield 184)
**86 %** (se 2), paired **+2 (se 3)**, length +27 %. *Read:* the largest move inside his 15 % doesn't change who wins (both
inside 2 se of nothing, nowhere near 35-40 %), so the single-change arms are skipped as planned and **Bar B8 is not filed**
(a bar on an arm that moved nothing would spend 10001-10140 for nothing). B8 is written up: measured, nothing ships; the
Gas Rocket Truck's damage rate (~9/s v a mortar's ~31/s) is the gap, and closing it is a larger change than ±15 %
(a question for him, below). Quick-remote GREEN on 75c9f2736 (builder0, `make quick ... exited 0`, 77 passed / 0 failed,
narrowed QUICK_BASE=41d047cf3). `search.py run` waits at the next leg while `~/balance-runs/PAUSE` exists (8fdd85855), so
builder2 can be handed to another stream with no kill.

**Dev series (builder2 J24, commit 9d8e26e44 = B7 code + B8 candidates, counter OFF; seeds 10201-10220 x 5 arenas x mono
on Green and on Rust = 200 fights an arm a faction; raw `~/balance-guard-raw/b8/`):**
- `~/balance-runs/b8-dev.sh` (unit balance-b8-dev, 15:14-16:44, DONE above): all-tanks v law_barrage under base and b8_grt_both; v
  syndicate_barrage under base and b8_mr_both.
- `~/balance-runs/b8-arms.sh` (unit balance-b8-roll, NOT STARTED: held on the orchestrator's word, engage's Bar E1 guards go first): all-tanks v the plain roll (OFF) for all four factions, and
  v siege / gang_hail (condemned, gangs): the firing test of R42.3.
- *Seeds:* 10201-10220 (20 of the dev block's 40) for the firing read. *Why:* the effects in question are either ~25-30 points
  (condemned, gangs: 77 -> 47, 78 -> 52 on 9401-9410) or within ~1 se (law +4, syndicate -5), and 200 paired fights an arm give
  se ~3; 10221-10240 stay in reserve if a read lands near its 2-se line.

**R42.3 firing screen (DONE 20:33; commit 9d8e26e44, builder2 J24, counter OFF, dev seeds 10201-10220 x 5 arenas x mono on Green
and on Rust, n 200 a cell, paired by fight, se bootstrap over seeds; paused 18:32-19:00 for engage):**
| faction | all-tanks v the roll | v the counter lineup | paired | fires (counter <= roll - 2 se)? |
|---|---|---|---|---|
| Condemned | 80 % (se 4) | `siege` 50 % (se 2) | -30 (se 5) | **yes** |
| Gangs | 79 % (se 5) | `gang_hail` 56 % (se 3) | -22 (se 5) | **yes** |
| Law | 92 % (se 2) | `law_barrage` 96 % (se 1) | +5 (se 1) | no |
| Syndicate | 92 % (se 2) | `syndicate_barrage` 84 % (se 2) | -8 (se 3) | **yes** (-8 <= -6) |

**FIRING LIST for Bar B7 (written 2026-10-26 20:40, before any number on 9901-9940): condemned, gangs, syndicate.** Law keeps its roll
against a tank rush (its counter makes all-tanks stronger). Syndicate fires by the filed line but sits at 84 %, far above the
deciding 60 %. **R42.17 (orchestrator):** the verdict is per firing faction: the counter ships ON for each firing faction that
passes its own deciding line and stays OFF for the rest (lines not amended; Syndicate at ~84 % would read "beats the roll by 8
but short of the target").

**Bar B7's frozen tree: fb9e2a95a** (`COUNTER_ARCHETYPES` = condemned siege, gangs gang_hail, syndicate syndicate_barrage; Law keeps
its roll, `law_barrage` loadable by name; tests first: test_army_counter red 7/2 -> 9/0, laptop `make test FILTER=army` 167/0).
**fb9e2a95a GREEN: builder0 `make remote T=check` -> `make check exited 0`, 3298 passed / 0 failed (23:06).** Bar B7 started
on builder2 23:07 (unit balance-overnight: B7 OFF list, ON list, verdict, then Bar B2s v2 on the orchestrator's word given ~22:40).
**B9 ARM 7aceba95f** (c0b61be2e + 8e257f3bc + d385cd308): builder0 `make check exited 2`, 3300 passed / 0 failed, FAILED only
sim-baseline (expected) and bridge-pooled (the drill crew, R42.15's ship gate); Bar B2s v2 runs for its read verdict (BASE
c0b61be2e, `~/balance-runs/bar-b2s-v2.sh`).
**How it runs (8004b9d62):** `search.py b7-lists DIR` writes the two arm lists (360 fights each: 320 deciding + 40 G1, one arena
a seed as filed); `tools/balance/fights.sh fb9e2a95a DIR/b7-off.txt ~/balance-guard-raw/b7` then `... b7-on.txt ...` plays each
list in ONE builder2 call (`mk/balance.mk balance-fights-run`, J24, GUARD_RESUME on preemption, pausable between the arms);
`search.py bar-b7 ~/balance-guard-raw/b7 fb9e2a95a --firing condemned,gangs,syndicate` is the verdict (per faction, R42.17).

**BAR B7 READ (2026-10-27 00:39; frozen fb9e2a95a, green builder0 3298/0; builder2 J24, 2 calls of 360 fights, 0 lost; seeds
9901-9940 one arena a seed, mono on Green and Rust; n 80 a faction, paired by fight, se bootstrap over seeds; `search.py bar-b7`):**
| faction | all-tanks OFF -> ON | paired | deciding (<= 60 % AND < -2 se) |
|---|---|---|---|
| Condemned | 75 -> **46 %** | -28.8 (se 7.5) | **pass: ON** |
| Gangs | 76 -> **60 %** | -16.2 (se 6.9) | **pass: ON** (at the line; -2.4 below 2 se) |
| Syndicate | 92 -> 78 % | -15.0 (se 4.6) | FAIL: stays OFF ("beats the roll by 15 but short of the target") |
| Law (not firing) | 91 -> 91 % | 0 | reported (no counter) |
| fired / all | 81 -> 61 % / 84 -> 69 % | -20.0 (se 3.9) / -15.0 (se 3.0) | reported |
G1 40/40 CPU v CPU fights identical ON v OFF; G2 median length -1.2 % (fired) / -3.5 % (all); counter fired 80/80 in each firing
faction, 0/80 Law. **G3: the judge as run read FAIL (134 of 320) because it checked max(both sides) <= ARMY_CAP's `units=25`**:
the wrong side (the all-tanks side is a named lineup, 26-29 vehicles ON and OFF) and the wrong cap (25 is the player's squads x
five, applied only under the ceiling; a dealt faction army's cap on desktop is Army.MAX_ARMY_UNITS = 45, which test_army_counter
asserts and the OFF rolls reach). Read as filed ("every countered army within the cap"): 320 loaded, 0 over 45 (largest 44; OFF
largest 45) -> pass, VERDICT PASS, ON for Condemned and Gangs. The judge fix came AFTER the numbers, so it went to the
orchestrator for a ruling (both outputs kept: `~/balance-runs/bar-b7-verdict-as-run.log`, `bar-b7-verdict-g3-fixed.log`).
**R42.21 (orchestrator): the as-filed G3 reading stands** (lesson 318: the ruler failed; the as-run judge would have failed its own
OFF base), so **Bar B7 PASSES for Condemned and Gangs**; Syndicate fails its line and stays off. **SHIPPED ON at b3841b301:**
`COUNTER_DEFAULT = true`, `COUNTER_ARCHETYPES` = condemned `siege` + gangs `gang_hail`, `--cpu-counter=off` the escape; the garage
line stays ON. Tests first (test_army_counter red 7/3 -> green; laptop `make test FILTER=army` 168/0). Smoke (laptop, seed 9905,
terminus, Gangs v a Gangs tank rush on Rust): no flag -> `CPU_COUNTER faction=gangs tank_share=1.00 archetype=gang_hail` (16 Rat
Rods, 7 Gun Trucks, 14 Wrecker Catapults, 7 Resupply Tankers); `--cpu-counter=off` -> today's roll (7 War Rigs, no Catapults).
**b3841b301 GREEN: builder0 `make check` exited 0, 3299 passed, 0 failed** (2026-10-27 01:49). Merge it alone (R42.21).

**R42.15 (orchestrator, ~19:10):** Bar Q6 FAILED, so CP42.1 is not reached and the bridge gate for shipping fm_c5r2_lawt5 is not met
(not loosened). RULED: run Bar B2s v2 anyway, overnight on builder2 after the firing screen, B9_MAIN = current main (hash named by
the orchestrator when the screen ends), so his stat-change question gets a read verdict; the change does not ship this round unless
the drill's rust s2 t15 crew is fixed; the verdict carries.

**B9 ready (rebuild recipe, dry-run 2026-10-26 ~17:45):** `B9_MAIN=<CP42.1 hash> ~/balance-runs/b2s-v2-rebuild.sh` = a worktree
`../godot-balance-arm` on branch `balance/b2s-v2-arm-r42` = MAIN + cherry-pick 8e257f3bc (fm_c5r2_lawt5, 55 values) + d385cd308
(= ad956031b's re-pins, identical diff), then builder0 `make remote T=check` + sim-baseline-record (expected red ONLY on
sim-baseline). Both picks apply cleanly onto main 4bf0f3703 (`git merge-tree`). The series driver is
`~/balance-runs/bar-b2s-v2.sh.template` (the filed bar's seeds 8801-8840 + 8901-8940 / 8801-8820, J24, raw
`~/balance-guard-raw/bar-b2s-v2`), started only after the ARM's check and after builder2 is free of the firing screen.

**Stretch, read now:** B6 (ADVANCE walks a deploying crew off its seat) is a brain/element fix (`TankBrain` ADVANCE while the
element deals travel seats, read through `ElementFeed`): `game/ai/**` and `game/tactics/**` are engage's and settle's this round,
so it is BLOCKED by ownership (not asked: engage's E1 is the round's first item). B3 (faction-aware CPU, v1 built OFF round 40 at
2979ee5c8) goes on top of the faction stat change (R40.1), which waits on CP42.1 with B9.

**Known issue (for him, not blocking):** the garage line "Bring two artillery squads with your tanks" shows for every faction's tank
draft, Law's too, while Law's artillery lineup does not beat all-tanks (96 %). Kept as approved (ON); a Law-specific line is his call.

**Questions for the orchestrator (sent; R42.3 answered (1)):** (1) B7's deciding line is pooled; Law's and Syndicate's counter lineups don't beat
tanks today (96 / 87 %). If B8 can't fix them inside 15 %, may Bar B7 be judged per countered faction (Condemned and Gangs:
each ARM <= 60 % and down >= 2 se) with the counter firing only for the factions whose lineup works? Asked BEFORE any 9901+ number.

**Merge notes (shared-path edits, R42.1):** `game/modes/skirmish_mode.gd` `_start_match`: 3 lines before the spawn loop
(`Army.load_pair`) and the loop's `load_army` call replaced by `armies[team]` (nowhere near `rig.facing`); `game/garage/garage_mode.gd`
`fight()`: one argument, `screen.draft.to_doctrine()`. Granted paths: `garage_opponent.gd` (`build`'s `opposing` + 4 lines),
`garage_advice.gd` (the hint + its switch). Mine: `game/units/army.gd` (counter rule, `load_pair`, `load_army`'s `opposing`),
`tests/test_army_counter.gd` (+ .uid), `tools/balance/candidates/b8_*.json`. R42.4: `game/garage/garage_screen.gd`
`_hint()`: one line first (`GarageAdvice.tank_rush_line`).

