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

**Report (2026-10-22, in progress):** D1 first read in; the damage-weighted re-read running (builder0 light, 6e049da5b).

**D1 first read (builder0 light, native ON (NATIVE_EXEC lines), 640850023 = main 5b20bfd62 + the probe only, `make native
tactics-hold-fire`, seeds 2601-2608 x 5 guard maps x both sides; blob 80 fights; turtle 45 of 80: the light slot's 90 min cap
killed the rest; logs in ~/doctrine-runs/d1).** Blob line: CPU 58,805 direct rounds, 55.5 % faster than a crawl (per-seed se 1.6;
R37.26 read 55.5 % on the same fights: the probe replays it).
- **The CPU is not defending when the blob comes: 82.6 % of its rounds are fired in ATTACK posture** (ElementCommander's
  Posture.decide), 17.4 % in hold. Its moving rounds by element task: screen (recon) 54 % of all moving rounds (65 % of its
  rounds moving), support_by_fire 29 % (49 % moving), hold 9 % (46 % moving), attack 6 %.
- By brain option: SUPPRESS 26 % of rounds (64 % moving), MOVE 22 % (77 % moving), ENGAGE 23 % (61 % moving), HOLD 26 % (21 %
  moving). By seat: crews > 15 m from their element slot fire 49 % of rounds (69 % moving); crews within 5 m fire still 87 %.
- **A CPU crew that is holding and on its seat already stops to fire** (hold|HOLD|near: 93 % still). Within hold posture the
  movers are crews driving back to a post 15 m+ away (hold|MOVE|away, 76 % moving) and recon screening.
- Turtle line (CPU the attacker, as it should be): 90 % of CPU rounds in attack posture, 56 % moving.
- Reading: the lever is not inside the HOLD option; it is (a) the posture (the CPU meets the blob as an attacker), (b) the
  support_by_fire line re-seated on a moving focus, (c) recon fire on the move. Re-read weights rounds by damage (a scout's MG
  fires ~10 rounds to a cannon's 1) and splits by posture reason and map half before the design note.

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
