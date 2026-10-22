# Stream: doctrine (the CPU defender stops, holds and shoots first)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.2) and
> in *Round 37*: CP37.1, R37.14 (the guard lines' base), R37.22-R37.26 (the rules arms and the motion read), R37.44 (Bar K). Then
> `game_design.md` *OPEN QUESTIONS for him before round 37* and *Summary of his answers*. Rules' close notes:
> `streams/archive/round37/rules.md`. **You own:** brains' paths (`game/ai/**`, `game/tactics/**` outside the carve-outs in
> workstreams *Round 38* Ownership), `tests/tactics/**`, `tests/test_tactics*.gd`, the `tests/ai_scenarios/**` scenarios you add,
> `tests/rules/**` re-reads, `mk/tactics.mk`. **Model:** FABLE. **Machine:** builder2 for guard-line series; builder0 light runs.

## The lead's direction

"How can we make it so that tactics and strategy can win out over a large frontal assault?" ... "in the real world, the defender
generally has an advantage" (round 36, game_design.md). His round-37 answers built rules that reward stopping (sight, accuracy, pinning,
hull-down); every one leaned the right way but none cleared noise because **the CPU defender itself keeps moving**. And his standing
rule: smart AI on both sides; symmetric AI improvements ship without asking.

What he will notice: a CPU force holding a zone stops in cover and shoots first; a blob of his (or the CPU's) charging it loses more
often than today; his own defending squads do the same when parked (settle owns "parked").

## Where things stand

- The guard lines (CP37.1): BLOB (his right-click, everything at once) wins 48 %, TURTLE 39 % against today's CPU (R37.14), paired
  320-fight reads with `tools/scoreboard/guard.py --pair`; guard.sh GUARD_CHUNK=2.
- The motion read (R37.26, `make rules-guard-motion`): blob fires faster than a crawl 70.1 % of rounds, the CPU 55.5 %, and the CPU fires
  41 % more rounds.
- Rules on main, OFF: `--rules-on=sight,spread,pin_slow` (R1-R3), `--cover-on=hulldown` (K2).

## Backlog (in order)

1. **D1 the read:** when CPU elements are tasked to HOLD / defend a zone, how often do their crews fire while moving, and why (which
   brain options move a holding crew: ENGAGE, SPOT, FLANK, re-seat). Design note to the orchestrator before code.
2. **D2 hold-and-fire:** a defending CPU element halts to fire (stops, uses cover seats, bounds only when it must), behind a switch;
   lab first; bar on the guard lines (deciding: the blob's win rate down; guards: the turtle not up, kills/length per faction, perf, and
   "the CPU still attacks when it is the attacker"). A pass ships ON (symmetric).
3. **D3 the re-read:** R1-R3 and K2 ON top of D2, each and as a package, on the same 320 fights.
4. **Stretch:** the CPU choosing low-cover seats when it defends (K5 maps have barriers).

## How to verify

Lab both paths; `make quick-remote`; guard-line series on builder2 (`make guard-run GUARD_ARGS=... GUARD_TAG=...`); every number with
commit, machine, workload, n. Smoke: `make skirmish ARENA=locks`, watch the CPU hold its zone.

## Don't touch

orders' control paths, settle's deploy/halt/seat functions and the parked-hold seam (merge notes), manoeuvre's movement blocks,
`game/match/**`, `game/combat/**`, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-22, in progress):** D1 DONE (design note below). D2 coded OFF (`--cpu-defend`, b9f8a347c); its bar is FILED
below before any arm number; lab 2 leans right (blob 18 -> 13 of 40); full check queued on builder0, then builder2's series.

**D1 the read (DONE).** Tool: `make native tactics-hold-fire` (tests/tactics/hold_fire_probe.gd extends the guard line read-only;
every direct round, the same weighted by damage a round, and a 2 Hz crew sample, split by posture, posture reason, map half,
element task verb, brain option and seat distance, motion as R37.26). Reads, all builder0 native ON, light:
(1) 640850023, blob 80 fights + turtle 45 (the slot's 90 min cap took the rest; ~/doctrine-runs/d1);
(2) 6e049da5b with damage and reasons, blob 55 of 80 (stopped at the orchestrator's request, the box was loaded; ~/doctrine-runs/d1b).
- **The CPU is not defending when the blob comes.** Blob line, damage-weighted (2): 81.7 % of the CPU's damage is fired in ATTACK
  posture, and **75.0 % is ATTACK because it "holds no objective" while it stands in its OWN half**: the blob reaches the CPU's
  near ring (the blob's target) before the CPU has taken it, and Posture.decide only holds a zone the side already owns. 17.4 %
  "threatened" (a held zone, enemy within 60 m), 0.3 % ahead. Rounds (1): 82.6 % attack posture, 55.5 % moving (= R37.26).
- In attack posture it fights as an attacker: by verb (damage) attack 42 % (50 % of it moving), support_by_fire 32 % (54 %),
  screen 11 % (62 %); by option ENGAGE 39 % (48 % moving), MOVE 23 % (79 %), HOLD 24 % (23 %); by seat, crews > 15 m from their
  slot 35 % of damage (66 % moving), within 5 m 19 % (17 % moving).
- **A CPU crew that holds on its seat already stops to fire** (hold|HOLD|near: 83 % still by damage, 93 % by rounds). In hold
  posture the movers are crews driving to posts 15 m+ away (hold|MOVE|away 72 % moving): `_hold` re-lays the posts across the
  enemy's CENTRE each think, so as the blob comes on the post line swings and crews drive mid-fight.
- Turtle line (CPU the attacker, as it should be): 90 % of its rounds in attack posture, 56 % moving.
- Not the lever: the HOLD option itself, ENGAGE inside a hold (2 % of damage), SPOT (< 1 %).

**D2 design (my paths only: posture.gd, element_commander.gd; native: no twin, confirmed by native).** `--cpu-defend`:
(a) DEFEND posture: a side whose near ring (Posture.near_ring) is not the enemy's and has a known enemy within THREAT_M (60 m)
of it HOLDS that ring, owned or not yet, whatever the score; a threatened held zone still comes first; the hold is kept
(POSTURE_KEEP_TICKS) while the ring is not the enemy's. The hold is round 19's `_hold` as it is: posts across the zone facing
the threat, recon screening out, support behind, one post on an intruder. (b) the posts keep the facing they were laid with
until the enemy's direction from the zone swings > 45 degrees. Symmetric: every side a commander runs (both CPU sides in CPU v
CPU); his squads are not commanded (parked = settle's). Why not the brain: a holding crew on its seat already fires still.
Lab: tests/test_tactics_posture.gd 16/0 (6 new: off = today, defend, far enemy, enemy-owned ring attacked, mirrored, held zone first).

**D2 lab (NOT judged: 40 blob fights, 2601-2604 x 5 maps x both sides, builder0 native light J=4, paired with D1's OFF rows
at 6e049da5b; `tests/tactics/hold_fire_pair.py`).**
- Lab 1, 6877a099c (defend (a)+(b) at 60 m): CPU damage in defend posture 0 -> 39.6 %, in attack/"nothing"/own half 77.5 -> 26.4 %
  (the posture engages), but CPU damage fired moving only 49.8 -> 47.0 %; blob wins 18 -> 20 of 40 (flips 2 / 4: noise). Why:
  inside the hold the first post's `attack` on an intruder was 20 % of all CPU damage (43 % moving), and crews drove onto posts
  laid after contact (hold|MOVE|away 87 % moving).
- So (still before any judged number, same switch): (c) a defending post never breaks off for an intruder; (e) an element in
  contact within 35 m of its post stands where it is; (d) defend triggers at 100 m (Posture.DEFEND_M), not 60. Tests 18/0.
- Lab 2, b9f8a347c (a)-(e): **blob wins 18 -> 13 of 40 (flips to a loss 5, to a win 0)**; CPU damage fired moving 49.8 ->
  **37.4 %** (per-seed se 3.8); in defend posture 43.4 %; holders (hold verb) 73 % still; kills blob 681 -> 655, CPU 894 -> 917.
  The remaining movers: attack posture 31 % of damage (52 % moving), hold|MOVE|away 5 % (90 % moving). Lab only: the bar decides.

**Bar D2 (FILED 2026-10-22 before any arm number; C38.1/C38.2).** Change: `--cpu-defend` ON v OFF.
- **Base:** main 1c484a525's `references/scoreboard/guards/1c484a525.fights.jsonl` (320 fights, builder2). Gate: my pair tree
  OFF replays it with 0 flips on one seed block (2601), else the base is re-run on the pair tree and paired against that.
- **Workload:** the same 320 guard fights an arm (5 maps x 2601-2608 + 2701-2708 x both sides x blob/turtle), builder2,
  `guard.sh`, judged `guard.py --pair`. Plus the CPU v CPU line (`GUARD_KINDS=none`, 2601-2608, both arms).
- **Positive control:** `tactics-hold-fire` ON on the blob line: the CPU's damage share fired in "defend" posture > 0 on every
  map, and its share in attack/"holds no objective"/own half DOWN.
- **Deciding:** the blob's win rate DOWN v base by > 2 x paired se AND exact McNemar p < 0.05.
- **Second line:** the blob's kill ratio not UP by > 2 x paired se (a contradiction, not a pass).
- **Mechanism (reported, the brief's claim):** the CPU's moving share of damage fired on the blob line, ON v OFF (base 50.8 %, 55
  fights); expected down.
- **G1 (the CPU still attacks when it is the attacker):** turtle v tactics: the turtle's win rate not UP by > 2 x paired se and
  its McNemar p not < 0.05 in its favour; turtle median length not up by > 2 x paired se.
- **G2:** kills a fight and median length per faction, both lines, within base +- 2 x paired se (a faction outside is named).
- **G3 (what DEFEND could break: two defenders stall):** CPU v CPU (none line, 40 distinct fights x 2 sides): fights reaching the
  600 s cap ON <= OFF + 2, and median length ON <= OFF x 1.2; decisive results reported.
- **G4:** perf: commander code is a think a second (no per-crew cost); perf-judge on builder0 when the orchestrator judges main.
- **Equality:** sim-baseline unmoved with the switch OFF.
- **A pass ships ON** (symmetric AI improvement: his standing rule). One re-tune allowed only on the guard lines (THREAT_M for
  defend), then judged as it stands.

**Pairing base (native, 2026-10-22):** main 1c484a525's `references/scoreboard/guards/1c484a525.fights.jsonl` (on main since
cc7c7ef1a; 320 fights, builder2): blob 49 % (± 7), turtle 40 % (± 16). Arms pair with `guard.py --pair` against it; main's rolling
guard.sh (cc7c7ef1a) resumes per fight; I merge main for it before D2's series.

**Plan (in order; one-line reasons):**
1. D1 the read: `make tactics-hold-fire` (tests/tactics/hold_fire_probe.gd, extends the guard line read-only): every CPU direct round
   and a 2 Hz crew sample split by posture (hold/attack), element task verb, brain option and seat distance, with R37.26's motion
   buckets; blob AND turtle lines, the base's seeds 2601-2608 x 5 maps x both sides (160 fights), builder0 light. Reason: the
   brief wants the cause (which option moves a holder) before any code.
2. D1 design note to the orchestrator: where a holder moves, which lever, and the bar (C38.1: the property it could break).
3. D2 hold-and-fire behind a switch, lab first; quick-remote; one full check on a named hash; the paired guard series on builder2.
4. D3 R1-R3 and K2 re-read on top of D2.
5. Stretch: low-cover seats when defending.
