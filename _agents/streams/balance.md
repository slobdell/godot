# Stream: balance (no army wins by charging just because of which faction it is; tactics decide)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/game_design.md` (*Summary of his answers*, *His
> call on R1-R3*, *His round-39 calls*), `_agents/workstreams.md` **Round 40** (C40.1, C40.4, C40.5, CP40.0). Round 39's doctrine brief is
> your predecessor: `streams/archive/round39/doctrine.md` (Status: *ROUND-40 CANDIDATE* faction table, *What round 40 should try first*).
> **You own** doctrine's round-39 paths: brains (`game/ai/**` and `game/tactics/**` outside settle's and manoeuvre's carve-outs:
> `tank_brain.gd`, `element_commander.gd`, `cpu_commander.gd`, `gunnery.gd`, doctrine tables), `tests/tactics/**`, `tests/test_tactics*.gd`,
> `tests/ai_scenarios/**` you add, `tests/rules/**`, `mk/tactics.mk`, `mk/rules.mk`, `tools/balance/**` (new), `mk/balance.mk` (new);
> the C39.4 grant (rule constants) carries over as C40.4. **GRANT C40.5:** `game/units/**` (unit stats, `army.gd`'s CPU army deal): unit numbers
> within +/-15 % per his call R40.1 (below), under a filed bar. **Model:** Fable
> (the lingering problem: two rounds of tactics moved the blob line 0-6 points). **Machine:** builder2 for series (`make gcp-start`;
> Spot, re-queue on preemption), builder0 light for quick reads. **Seeds:** 8301-8340 + 8401-8440 (registered, C40.1); round 39's 6301-6340
> + 6401-6440 for the RE-READ of its own fights only.

## The lead's direction

R1-R3 (verbatim, 2026-10-23): "Regardless of whether or not this makes the game better right now, it's the correct direction to move in,
and we'll continue iterating to ensure that tactics and strategy win our as opposed to full frontal assault slug ests". Earlier (Q10):
"the problem is not the units, but the rules". Pillar: fixed StarCraft-style units, no pay-to-win. Memory: hard CPU, friendly units
equally smart; symmetric AI improvements ship without asking.

## Where things stand (main at launch: see HANDOFF)

Rules-ON base, 773412e49, builder2, 1600 fights: a blob wins 39 %, a turtle 36 %. By faction it is a matchup table, not a doctrine
problem: any blob v a gangs CPU wins 72 % (syndicate's blob 86 %); v a syndicate CPU 12 %; a gangs army loses charging (13 %) or
turtling (17 %). Blob kill ratio by blob faction: syndicate 2.62, law 0.98, condemned 0.83, gangs 0.15. Every doctrine lever tried
(D2/D2b/D2c/SPLIT, R1-R3, hull-down) moved the whole line 0-6 points and left the table's shape alone.

## Backlog (in order)

1. **B1 the per-unit tally (no build of the game).** Native adds per-unit kills/losses/damage dealt to GUARD_RESULT (**CP40.0**, native's N1,
   first). Re-run round 39's OFF-arm fights (773412e49's workload on main) with it and write, per faction: the dealt army (units, cost),
   and by unit type kills, losses, damage dealt per credit. Name which gangs units die without trading and what syndicate's army has
   that the others don't. Before CP40.0 lands: read `army.gd`/`units.gd` and tabulate each faction's dealt army by seed (no fights needed).
2. **B2 ANSWERED (R40.1, 2026-10-24): tune the units' numbers.** His words: "yes, when a faction keeps losing, we should change its
   units' numbers. Obviously the game should be balanced. I was also going to highlight that every time I play with the gang I seem to
   lose. Yes let's go with A". Bounds: +/-15 % of today's value per unit on toughness (hp/armour), damage, cost; no new abilities, no unit
   added or removed. B1's tally picks the candidates (B4's search scores them); the winner ships under a bar on 8301-8340 + 8401-8440
   (deciding: the faction table flatter, e.g. the spread of by-CPU blob win rates down by > 2 se; guards: overall blob and turtle lines
   not up, kills/length per faction, the none line, perf, the sim baseline adopted on purpose). Stat change first, then B3 on top.
3. **B3 a faction-aware CPU (symmetric, ships without asking if it passes).** Each faction plays to its army: per-faction ambush/hold
   tables in the doctrine (e.g. gangs holds and ambushes rather than trading in the open), on both sides' brains. Bar on 8301-8340 +
   8401-8440 (deciding: the gangs-CPU cells' blob win rate down by > 2 paired se; guards as Bar D3: blob kr, turtle line, kills and
   length per faction, the none line, perf).
4. **B4 the balance search harness.** `tools/balance/`: within his +/-15 % bounds, run N sims a candidate on builder2 (native's N3
   `--unit-overrides`) and score the faction table's flatness; it feeds B2's candidate. If B4 is ready before B1's read names the
   candidates, do B4 before B3.
5a. **B5 combined arms (R40.6, his note 2026-10-24: "I tried playing some games where I used 100% tanks versus the enemy, and it seemed I
   was able to more easily win. Should we also include game balancing to ensure that using a variety of units should theoretically create
   the advantage?").** (1) Measure: a mono-army line in guard_line (all-tank army v a mixed army, same faction, same budget, every map,
   both sides; on your B4 screening seeds), by faction. (2) Target: mixed beats mono ~60-65 %. (3) Lever: counters within +/-15 %
   (anti-armour v tanks, tanks v light units, MGs v light armour); a filed bar on a fresh block from the orchestrator. If the bounds can't
   reach it, write it up for him (player terms) rather than going past them. Add to Bar B2s, before any number on its seeds, the guard:
   mono-tank line's win rate not up.
5b. **B6 (R40.8, after B2s and B5): ADVANCE walks a deploying crew off its seat.** Settle's census (754fee377, builder0 light, 96
   squads): of 45 crews that were in and drifted off before the deploy, 20 were on ADVANCE. His "Stay put and shoot" for parked squads.
   Settle's T1 v2 works round it, so this is a cleanliness fix, not a blocker.
5. **Stretch:** a second balance pass after B3 (the faction-aware CPU changes the table again).

**His answer (2026-10-24):** R1's full sight stays at ~3 s after a halt ("sounds fine"); HALT_DWELL_SECONDS stays 2.0.

## How to verify

Every series: a full check of the named hash first, `guard.sh` on builder2 (GUARD_CHUNK=8), `guard.py --pair`; one full check + one
judged series per builder at a time. Smoke: `make skirmish SKIRMISH_FLAGS="..."` with a syndicate army blobbing a gangs CPU, then a
gangs army blobbing a syndicate CPU.

## Don't touch

settle's deploy/halt functions and PARKED_HOLD seam, manoeuvre's movement/traffic, orders' `game/control/**`, `native/**` (request),
`tests/ai_scenarios/guard_line.gd` (native's), `game/units/**` beyond C40.5, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (B2 answered: R40.1).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-24, in progress).** Plan, in order: B1 tally (DONE, no fights) -> B4 harness + dry run of two candidates on
dev seeds (running) -> pick the candidate -> Bar B2s series on 8301-8340 + 8401-8440 -> ship -> B3 on top. Reason: R40.1 put the stat
change before B3, and B4 is ready before B3 would be.

**B1 DONE (no build; b8c8cfca2).** `make balance-tally RUNS=~/doctrine-guard-raw/773412e49-off` reads round 39's OFF arm (773412e49,
builder2, 6301-6340 + 6401-6440, 800 blob + 800 turtle fights): each kill line names killer and victim, and a faction's squads are
pure by role, so the squad name is the unit type. Kills tally to GUARD_RESULT on 3198 of 3200 sides. Damage dealt waits on CP40.0.

| faction | units a fight (cost) | kills / unit | survive | killed value / credit |
|---|---|---|---|---|
| condemned | 32.0 (5164) | 0.63 | 40 % | 0.64 |
| gangs | 43.4 (5000) | 0.21 | 17 % | **0.36** |
| law | 25.2 (5128) | 0.80 | 38 % | 0.54 |
| syndicate | 16.7 (5125) | 1.74 | 63 % | **0.84** |

- **Gangs units that die without trading:** Gun Truck (110 pts, 9160 fielded) 0.02 kills/unit, 12 % survive, kr 0.03: twin_mg's
  penetration 2.5 sits on the armour floor against everything; Resupply Tanker 0.10 kills, 19 % survive; War Rig 0.33 kills, 22 %
  survive, kr 0.43 (a Condemned Tank 1.15, a Law Assault Gun 2.37). Rat Rods trade best per credit (0.39) but 12 % survive. The
  Wrecker Catapult is the one gangs unit that pays (0.96 value/credit, kr 1.37).
- **What syndicate has:** the Railgun Platform, 5.12 kills/unit, kr 16, 1.79 value/credit; the Missile Ring kr 10, the Spotter kr 6.2.
  Every syndicate gun outranges every gangs gun (railgun 110 m, missiles 170 m v spear 30 m, twin MG 35 m, scrap cannon 50 m).
- **Not the R1-R3 rules:** the rules-OFF base 686150ed2 has the same table (gangs CPU beaten 83 %, syndicate 7 %; n 30-45 a cell).
- **Cost is a weak lever for gangs:** gangs field 43.4 of the 45-unit cap (Army.MAX_ARMY_UNITS), so a cheaper gangs unit buys almost
  nothing; hp, armour and damage are the gangs levers, cost is a syndicate/law lever (fewer units).
- **Per-unit damage (CP40.0, N2's `guard.py --by-unit`; 7b53f5f85, builder2, dev 8513-8524, 240 fights):** hull+shield dealt / taken a
  credit fielded: syndicate 1.82 / 0.73 (68 % live), law 1.29 / 1.46, condemned 1.20 / 1.66, gangs 1.07 / 1.58 (20 % live). Gun Truck
  dealt 0.30 a credit, 13 % live; Railgun Platform 3.10 dealt / 0.65 taken, 11.6 kills a 1000 credits (law Assault Gun 9.3,
  condemned Tank 4.1, War Rig 3.3). The kill-line tally above stands.
- All MG units are weak everywhere (Condemned Scout kr 0.09, Pursuit Cruiser 0.15, Skimmer 0.46): spotters by design, not a faction gap.

**B4 harness (built; dry run in progress).** `tools/balance/search.py`: `check` (his +/-15 % bounds; refuses a damage change on a weapon
two factions share: laser, autocannon, machine_gun), `scale` (per-faction multipliers -> a candidate), `run` (guard.sh on builder2 with
`--tune=`; cost refused until native's N3 `--unit-overrides`), `score` (the faction table and FLATNESS = RMS of the 16 cells "guard's
faction F" / "CPU's faction F" minus the line mean over blob and turtle, in points, se by bootstrap over seed units; `--base` pairs).
Round 39's OFF arm scores 17.4 (se 1.4); OFF v SPLIT paired change -0.1 (se 0.9). Candidates: `tools/balance/candidates/`
`faction_max` (gangs hp/armour/damage +15 %, syndicate -15 %, law +5 %) and `targeted` (B1's units only).

**B4 dry run (dev seeds 8501-8512, builder2, guard.sh J20 GUARD_CHUNK=8, 240 fights an arm, NOT a bar).** Base 066d0ff95 (= main's
code 68d0410d3 + tools): flatness **26.6 (se 4.0)**; blob 45 % (v a gangs CPU 83 %, v a syndicate CPU 6 %), turtle 42 %. Same shape as
round 39. **faction_max** (gangs hp/armour/damage +15 %, syndicate -15 %, law hp/damage +5 %;
shared weapons untouched): flatness 26.6 -> **13.8**, paired change **-12.8 (se 2.4)**; blob 45 -> 37 % (v a gangs CPU 83 -> 43, v a
syndicate CPU 6 -> 37), turtle 42 -> 45 % (n 120 a line, dev seeds; not a bar). **targeted** (B1's units only): 26.6 -> 21.1, change
-5.5 (se 2.5); blob v a gangs CPU 83 -> 67, v a syndicate CPU 6 -> 17. **B4's dry run is DONE: faction_max wins.** Pooled over its four
cells (as blob/turtle guard, and 100 - the CPU cell), faction_max leaves law weakest (34 %) and syndicate/condemned strongest (61/56 %).
**Round 2** (on 7b53f5f85 = main b25b803e5 with N1+N3 merged; fresh dev seeds 8513-8524; J16): base, faction_max again, `fm_law`
(law to +15 % too), `fm_law_cost` (fm_law + syndicate cost +10 % through N3). Then the mono line (B5).
  Round-2 reads (7b53f5f85, builder2, 8513-8524, 240 fights an arm, paired with its base; base flatness 18.5 se 3.5):
  | arm | flatness | change (se) | blob line | blob v gangs CPU | blob v syndicate CPU | turtle line |
  |---|---|---|---|---|---|---|
  | base | 18.5 | - | 40 % | 52 % | 7 % | 34 % |
  | faction_max | 12.9 | -5.6 (2.4) | 40 % | 36 % | 27 % | 38 % |
  | **fm_law** | **10.1** | **-8.4 (3.1)** | 36 % | 32 % | 33 % | 40 % |
  | fm_law_cost | 13.6 | -4.9 (3.7) | 41 % | 24 % | 60 % | 34 % |
  fm_law_cost overshoots (syndicate blob 20 %, a syndicate CPU beaten 60 %). **fm_law is round 2's winner**; its mono line (and the
  base's) run next, both sides, 8513-8520, one guard side (GUARD_SIDES=green), before the bar candidate is named.
  **Round 3 (the turtle guard, R40.13 note):** fm_law's turtle line rose +5.8 (se 3.3), faction_max's +4.2 (2.8); fm_law_cost's held
  (+0.0) but overshot syndicate. **fm_law_c5** (fm_law + syndicate cost +5 %): flatness 18.5 -> **8.3**, change **-10.2 (se 3.1)**,
  blob line **+1.7 (3.4)**, turtle line **-0.8 (3.7)**; blob v a CPU of each faction 32-47 %. The best on every line read.
  **PROVISIONAL BAR CANDIDATE: fm_law_c5**, named only once its mono line (G8 screen, 8513-8520, both sides) is not above the base's.
  BASE = **5be511659** (stream/balance, main 9d5907ddd's T1 merged), ARM = **494a3d33d** (`balance/b2s-arm`, worktree
  ../godot-balance-arm: BASE + `search.py apply fm_law_c5`, 55 values in units.gd/weapons.gd, cross-checked 0 mismatches). ARM's full
  check is running on builder0 (expected red only on sim-baseline). **Expected bar outcome, written before the series:** deciding
  passes (dev change -10 at se ~3 a 240-fight read, so ~-10 at se ~1.2 at 1600); G1 blob flat and G2 turtle flat on dev, but each
  at ~0 +/- 3.5, so either could cross +2 se (~+2.4 points at the bar's n) by chance or a small real rise: the riskiest guards; G3
  lengths unknown (not screened); G8 known after the mono screen.
  **ARM 494a3d33d's full check: NOT green** (builder0 `make check exited 2`, 3203 passed / 9 failed + sim-baseline, all 13 maps moved).
  (a) `test_combat_mechanics::test_everything_hurts_from_behind` (a design invariant): +15 % REAR armour on War Rigs / Law units puts the
  twin MG from behind under 0.4. **Candidate is now `fm_law_c5r`** = fm_law_c5 with every rear armour as today (no bar number seen).
  **ARM = 6d95d4eba** (`balance/b2s-arm-r`, BASE 5be511659 + apply; rear armour verified unchanged); its full check queued on builder0
  after BASE's. (b) Eight tests pin the prices the syndicate cost +5 % moves (C19.2): test_army_economy x6, test_army_screen::
  test_a_spent_army_says_so, test_army_size::test_the_table_at_two_thousand (Skimmer 120 -> 126 CR, Gunship 172 -> 180, Railgun 269 ->
  283, Missile Ring 218 -> 228, Spotter 195 -> 204; 2000 CR buys 15 Skimmers, not 16). **R40.18:** c5r accepted; the eight re-pinned,
numbers only (adopted on purpose, R40.18) -> **ARM = ad956031b** (6d95d4eba + the re-pins). Its full check queued on builder0 after
BASE 5be511659's. Before naming c5r: its mono line (G8 screen) and one paired lines read on 8513-8524 (builder2, queued).
  **fm_law_ca (B5, every tank -15 % hp/armour/damage +15 % cost on top of fm_law):** flatness 18.5 -> 17.3 (-1.2, se 2.7), turtle
  line **+9.2 (3.3)**, syndicate back on top (blob v a syndicate CPU 20 %): the tank nerf undoes the faction table. Not a candidate;
  its mono line runs only to measure what the in-bounds tank nerf buys against the all-tank army.
  builder2 (Spot) was preempted ~05:00 PDT during c5r's first mono arm; guard.sh restarted the box and retried that chunk (attempt
  2), nothing lost (fm_law_ca's lines had ended 04:59). The rest of the screens run at J10 (`~/balance-runs/r8.sh`) beside settle's gate.
  **Smoke (ARM ad956031b, builder0 light):** `faction-shots GREEN_FACTION=syndicate RUST_FACTION=gangs SEED=8513`: at 60 s a War Rig's
  nameplate reads 483 hp (the +15 %), gangs hold the centre 18-0 on points while syndicate leads kills 16-4, a contest; `garage-shots`:
  the Syndicate card reads 126-283 CR, the vehicle cards 126 / 180 / 204 / 228 / 283 CR, the suggested army fits (6 CR left); phone
  aspect clean. Frames in ../godot-balance-arm/build/light/build/screenshots/ (looked at).
  **G8 screen, c5r's mono line (7b53f5f85 + overrides, builder2, 8513-8520, both sides, 320 fights, paired with the base's):** mono
  wins 82 -> 80 %, **-1 (se 2)**: not above base. By faction: condemned +0 (se 0; its units don't change, so its fights replay
  identically, the pairing's check), gangs -6 (7), law **+6 (4)** (Law's buffed Assault Gun helps an all-tank Law army most),
  syndicate -5 (3).
  **ARM ad956031b's full check: still red on the same invariant, its other half** (builder0 `make check exited 2`, 3211 passed / 1
  failed + sim-baseline): "rear hurts at least as much as the front" broke on the Skimmer (2/2/2 armour: a cut front under an unmoved
  rear). **Candidate is now `fm_law_c5r2`:** rear armour moves only where armour goes DOWN (syndicate all faces -15 % as c5 had; a
  buffed rear stays as today). Self-check over every weapon x unit with the penetration math: 0 breaks; the four affected test files
  on the new ARM: builder0 light 57 passed / 0 failed. **ARM = 66c4839a2** (`balance/b2s-arm-r2`: 5be511659 + apply c5r2 + the
  re-pins cherry-picked); full check running on builder0. c5r's lines read was stopped by PID (wrong candidate now); c5r2's lines read
  and its syndicate mono arms run on builder2 (`r9.sh`). c5r2's other factions' units equal c5r's, so their mono fights replay
  identically (condemned's +0 / se 0 above shows it): c5r2's G8 screen = c5r's gangs/law/condemned arms + c5r2's syndicate arms.
  **c5r2 screens:** lines (7b53f5f85 + overrides, builder2, 8513-8524, 240 fights, paired): flatness 18.5 -> **7.9**, **-10.6 (se
  3.5)**; blob line **+1.7 (3.0)**, turtle line **-2.5 (4.2)**; blob v a CPU of each faction 37-50 %. G8 mono (c5r's gangs/law/condemned
  arms + c5r2's own syndicate arms, separate runs: overrides sha edf790a4 v 27c1b3e2, 8 of 80 fight lengths differ, the same wins):
  mono 82 -> 80 %, **-1 (se 2)**. **ARM 66c4839a2: green but for sim-baseline** (builder0 `make check exited 2`, 3212 passed / 0
  failed, 26 of 27 targets, perf-judge JUDGED PASS attempt 1; only sim-baseline red, all 13 maps moved). **sim-baseline-record on
  builder0 (light): 13 maps read twice, agreeing**, equal to the check's: foundry 59e197160f23b82d, yard 368d787dbe03a5fe, pit
  ccdfc12f382f87f2, terminus c7cc13e24f73009a, crossing b4489ed8f9df7024, sumps 857a99ed0d2d273f, locks 0fc4a99c36dee823, parade
  838aa1bf6d5d2c31, gorge f55e040a106496c4, archipelago fefa4465e3025a7c, cut 3a19138ad98c4dc6, docks 835465f77b5d2cd4, yard_open
  12307bd04c9ff832 (`~/balance-runs/sim_baseline_adopt-66c4839a2.json`). BASE 5be511659 green (builder0 3212/0, ALL JUDGED).

**B5 WRITE-UP FOR HIM (draft; the orchestrator attaches it to his decision; the armour line waits on fm_law_ca's mono read).**
*What you noticed is real.* An army of only tanks beats the same faction's normal mixed army, at the same money, 82 % of the time
(CPU v CPU, every map, both sides, 320 fights): Condemned 71 %, Road Gangs 80 %, Law 86 %, Syndicate 89 %. Your target was the
mixed army winning 60-65 %, so the tank army should win 35-40 %: about 45 points away.
*Why:* in a mixed army, the units built to kill tanks do their job. Artillery deals 3-5 hit points per credit to a tank column and
nearly all of it survives; the gangs' spear buggies 2.4; the Condemned Lancer 3.4. The trouble is everything else: about half of each
army's money (44-61 %) is in vehicles that can't hurt a tank at all. An IFV's cannon does 5-10 % of its damage to a tank's front
(0.2-0.8 per credit), a scout's machine gun 5 %, and the support trucks nothing. So the tank army fights half an army.
*What's inside your +/-15 % on unit numbers:* tank armour -15 % only doubles an IFV's effect on a tank's front (5-10 % -> ~10-20 %),
and when we tried every tank -15 % (with +15 % cost) the faction table got worse again (the Syndicate back on top; turtles winning
more). [Measured mono rate with that change: PENDING.] It doesn't reach the target.
*What would (outside the numbers):* (1) give the IFV a real anti-tank weapon, slow and limited, like a Bradley's TOW (the orchestrator's
recommendation: fixed units, authentic); (2) let armour-piercing ("penetration") move per unit, not just damage; (3) change what each
faction's army buys (fewer IFVs, more anti-tank). Recommendation: (1).

**B6 (queued after B2s and B5; code read only so far):** a crew under an element/player order gets `order_context`, so
`TankBrain` nulls its doctrine objective and an "idle" crew's objective becomes the order's goal (radius 5 m); `commanded` (which zeroes
ADVANCE) is the doctrine squad's slot, false for an ordered crew. ORDER_OPTIONS["idle"] allows ADVANCE, scored 0.45 with no threat in
sight when the crew is > 5 m from that goal: a crew sitting on its travel seat (not its goal) drives off it. Fix sketch: ADVANCE = 0
while the crew's element is still dealing its travel seats (Element.deploy, not yet "deployed"), read in the brain; the feed is
mirrored in native's feed_native.cpp, so the read goes through ElementFeed.element_of, not a new feed key. Needs its own bar.

**NAMED B2s CANDIDATE: fm_law_c5r2. BASE 5be511659, ARM 66c4839a2.** Series: `~/balance-runs/bar-b2s.sh` on builder2 (lines 8301-8340
+ 8401-8440, 1600 an arm; none line 8301-8320; G8 mono 8301-8320 both teams per faction; GUARD_SIDES=green on none/mono, whose two
guard sides are one fight). **Expected outcome (written before any bar number):** deciding passes (dev -10.6 at se 3.5 on 240 fights
-> about -10 at se ~1.3 on 1600); G1 blob and G2 turtle flat on dev (+1.7 / -2.5, se 3-4), so each passes unless a real rise near +2.5
points exists (the riskiest guards); G3 lengths not screened (unknown); G4 time-cap share unknown; G5 none line unknown (flatter
factions should not make it worse); G6 perf-judge PASS on ARM; G7 green but sim-baseline, re-pins adopted on purpose (R40.18); G8 -1
(se 2) on dev: passes unless law's +6 (se 4) is real and large.
**The bar's judge (written before any bar number):** `tools/balance/search.py bar ~/balance-guard-raw/bar-b2s 5be511659 66c4839a2`
prints one BAR_B2S line a rule and a VERDICT. Readings fixed here: se is a bootstrap over seed units (400 reps); deciding = paired
flatness change < -2 se AND blob v a gangs CPU down AND blob v a syndicate CPU up; G1/G2 fail at a paired share change > +2 se; G3
fails when a median-length change is outside +/-15 % (line) or +/-20 % (guard faction) AND more than 2 se from zero; G4 fails at a
time-cap share change > +2 se; G5 fails at a none-line flatness change > +2 se; G8 fails at a mono win-share change > +2 se. Dry run
on the c5r2 dev reads: 17 of 18 rules hold, G5 not read (no dev none line); blob median length +11.4 % (se 5.2) is the nearest to a band.

**B5 combined arms (R40.6; plumbing done, c1d7b88ae, quick-remote builder0 264/0).** `cpu:mono_<role>` deals a faction's units of one
role at the budget (Army.mono_army, never rolled); `SkirmishMode.demo_flags` keeps a `--player`/`--enemy` naming `cpu:mono_*` (R40.7's
one line; otherwise unchanged). Mono-tank v its own faction's deal, CPU v CPU (guard none), 8501-8510, mono on Green: queued after the
candidates. The none line's green/rust guard-side fights are exact duplicates (checked on d2c's none run), so half a none series is
wasted until guard.sh passes GUARD_SIDES (asked of native; on main since 5a9743c2c).
**B5 mono-tank line, base (7b53f5f85, builder2, 8513-8520, guard none, GUARD_SIDES=green, mono on Green then on Rust, 320 fights):**
an all-tank army beats its own faction's mixed deal at equal budget **82 % (se 3)**: condemned 71 % (26.0 v 33.5 units), gangs 80 %
(29.0 v 43.6), law 86 % (20.0 v 25.4), syndicate 89 % (11.0 v 16.4). His experience confirmed; his target (mixed wins ~60-65 %) is
~45 points away. Side effect: Rust wins ~8 points more than Green in this line (mono-on-Green 74 %, mono-on-Rust 89 %), so both arms
always run. **Why (CP40.0 per-unit rows, `tools/balance/mono_roles.py`, same fights):** the mixed army's anti-armour units trade
well against the tank blob (artillery 3.0-5.5 hp dealt a credit, 92 % live; Rat Rod spears 2.4; Condemned Lancers 3.4); the units
that lose are the ones that can't hurt armour: IFVs 0.2-0.8 a credit, 2-6 % live; MG scouts 0.04-0.17; Tanker / Sonic Emitter ~0.3.
44-61 % of each mixed army's credits sit in units dealing < 1 hp a credit to tanks. Armor.penetration_multiplier: an autocannon
(pen 5) hits a tank's front at 0.05-0.10, its side at 0.34-0.50; MGs sit on the 0.05 floor. So it is the armour/penetration rule
(numbers), not how the CPU places them: no doctrine fix would make an IFV hurt a tank. Next: `fm_law_ca` (fm_law + every tank -15 % hp/armour/damage, +15 % cost, clamped) on the lines and the mono line; if
the bounds can't reach the target, a write-up for him (R40.6 (3)).

**Bar B2s (the stat change; FILED before any number on 8301-8340 + 8401-8440).**
- Arms: BASE = the tree as it ships without the change; ARM = the same tree with the chosen candidate (named in this Status before
  the series; chosen from dev seeds only). Paired fights: seeds 8301-8340 + 8401-8440, blob + turtle, 5 guard arenas, both sides
  (1600 fights an arm), builder2, guard.sh GUARD_CHUNK=8, after a full check of the named hash. None line: 8301-8320 (200 an arm).
- **Deciding:** flatness (search.py score) down by > 2 paired se, AND the two worst cells move toward their line mean: blob v a
  gangs CPU down, blob v a syndicate CPU up.
- **Guards** (each fails at > 2 paired se the wrong way): (G1) the blob line's overall win share not up; (G2) the turtle line's not up;
  (G3) median match length of each line within +/-15 % of base, and of each guard faction within +/-20 %; (G4) the share of fights
  ending on the time cap (won on points) not up; (G5) the none line's flatness not worse; (G6) perf: perf-judge on builder0 passes on
  the shipped hash; (G7) the full check green on the shipped hash, with sim-baseline's moved maps adopted on purpose by the
  orchestrator (no other test edited to pass). (G8, added 2026-10-24 per R40.6, before any number on the bar seeds) the mono-tank
  line: an all-tank army's win share v a mixed army of its own faction at equal budget (CPU v CPU, the none line, every guard
  arena, mono on each team in turn; 8301-8320) is not up.
- Ships as numbers in `game/units/units.gd` (C40.5) and weapon damage in `game/combat/weapons.gd` (requested, below).

**Questions for the lead:** none open.

**Requests to other streams / orchestrator:**
- Dev seeds for B4's screening (never the bar's): using **8501-8540**, unregistered; please register or reassign.
- A grant for weapon `damage` values in `game/combat/weapons.gd` (his bounds name damage; C40.5 covers only `game/units/**`).

