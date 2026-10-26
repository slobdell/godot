# Stream: manoeuvre (fewer shoves in his big order, judged on what he sees; the bridge crossing clean under the stat change)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 42** (C42.1, C42.4,
> CP42.0, CP42.1) and *Rulings (round 41)* R41.5-R41.10, R41.13; your round-41 brief `streams/archive/round41/manoeuvre.md` (Status:
> CLOSE REPORT, the Q5 labs, the reversing report, the `_wait` timer artefact, *Round-42 notes*). **You own:** movement's drive /
> unstick / side-step / avoidance in `game/ai/movement.gd`, `game/ai/traffic.gd`, `tests/manoeuvre/**`, `tests/traffic/**`,
> `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `mk/manoeuvre.mk`. **Model:** Fable. **Machine:** builder0 light lane (J<=4);
> builder2 for a bar series (`make gcp-start`; Spot). **Seeds:** 9801-9824 (Bar Q5), 9825-9848 (the bridge, fresh BRIDGE_POOLED_SEEDS).
> Dev 7001-7012 (never a bar). Side refs: `wip/manoeuvre-m1v3` (Q5: a45c0b953 + fc8f3697d), `pair/native-wait` 20300bb52.

## The lead's direction

His round-40 playtest (verbatim in `game_design.md`): "when I'm controlling a large set of squads at once and commanding all of them to
go somewhere, a bunch of units block other units ... I suspect that we might get better navigation with a little more coordinated
movements". Round 41 tried both forms of his traffic idea (wait for a friend: Q2 v1-v3; hold the lane: Q4) and both made his 5-squad
order slightly worse (R41.7); G1 v9 (orders) now lays his group click as a column (contacts -23 %). What he sees of what is left is
crews shoving each other (Q5: contacts -28 %, shoved ticks -34 %, but all-in +2 s and never-in 6 -> 7: R41.10). His standing bar
(memory, *units must look smart*): he must perceive units as smart and under his control; contention first.

## Where things stand (main at launch: see HANDOFF)

- **Q5 "no pressing" v2** (`--traffic-on=nopush`, capped ease ~3 s per friend then today's press; fc8f3697d on `wip/manoeuvre-m1v3`):
  OFF, no bar, R41.10's frame for round 42 verbatim: *"a bar decided on what he sees (friendly contacts / shoved ticks), with all-in
  and never-in as strict guards, on fresh seeds; jam-seconds reported, not deciding."* Your proposed lines are in the archived Status
  (*Round-42 notes* 1). Its four members (`_nopush_for`, `_nopush_until`, `_nopush_since`, `_nopush_press_until`) need
  `native/src/exec_fields.h` lines before the commits can sit on a checked tree: **CP42.0, native merges them first; you cherry-pick
  after the orchestrator announces it.**
- **The bridge under the stat change:** balance's v2 overrides tree crossed bridge-pooled 72/72 on fresh 9025-9036 x ticks {1,8,15}
  (pooled rim 26.7 s, worst crew 2.2 s); its only known failure is the 18-run drill's rust t15 s2 (Rust_S_3, 5.1-5.4 s at the rim v
  3 s; cause R40.21: ORCA steers a wheeled follower out past the deck mouth while its leader turns). bridge-pooled is a hard guard,
  not re-seeded or loosened (R40.24, R41.3). Three F1 forms (round 40) and the wait family (round 41) each fixed it and broke
  something else. Bar B2s v2 (balance) waits on this: **CP42.1.**
- `_wait`'s timer artefact (archived Known issues): any revived wait or hold rule must end its timer from every drive phase.
- Every per-crew state is a real Movement member with an exec_fields.h entry (C42.4 = C41.2); a rule that steers differently from ORCA
  says so in its bar; native twins a rule before it ships ON (request via the orchestrator).

## Backlog (in order)

1. **Q5.1 Bar Q5 on fresh 9801-9824, inside R41.10's frame.** After CP42.0: cherry-pick a45c0b953 + fc8f3697d onto main, quick-green.
   File the bar before any number: deciding = friendly contact ticks AND shoved crew-ticks (the reverse attribution) on his 5-squad
   across click (orders' probe, crew headings, 4 maps), ON <= 0.8 x OFF pooled AND paired mean < 0 by >= 2 se, both; strict guards
   (filed first): never-in runs ON <= OFF, every-squad-in mean ON <= OFF + 1.645 se, the wedge trace's fight lines G1-G4; jam-seconds
   REPORTED only (ruled: the orchestrator records your eased-ticks-removed variant as a reported column, not a guard). Both arms
   GDScript drive (`--brains-off=native_drive`) until twinned. The whole suite ON (C31.1) before the series. On a pass: native's twin,
   then ON (the orchestrator merges; perf-judge in a quiet window).
2. **Q6 the bridge rim crew (speed only, C42.4).** Trace rust t15 s2 on today's main with balance's v2 overrides
   (`~/balance-guard-raw/b5/` has override files; the v2 recipe is in balance's archived Status): which crew, which tick, which steer.
   A rule that slows a wheeled follower at the deck mouth while its leader turns (no steering change), real members, OFF behind
   `--traffic-on=<name>`. Bar Q6 before any number on 9825-9848: deciding = bridge-pooled 18/18 under the overrides (the hard line)
   AND pooled rim on 9825-9836 x ticks {1,8,15} x both sides, main and overrides, ON <= OFF (no worse) with the drill's worst crew
   <= 3 s; guards = R41.6's group-order lines on 9837-9848 (all-in mean and never-in squads ARM <= BASE + 1.645 se, contacts <= BASE x
   1.05) and fight G1-G4. A pass = CP42.1: tell the orchestrator the minute the hash is green; balance's Bar B2s v2 runs on it.
3. **Stretch:** the `_wait` timer fix (so a future wait rule's counters can be trusted), tested; a lab on the long shoved episodes
   (15-30 s, stalled or parked heads at street mouths) with Q5 ON: what remains.

## How to verify

`make test FILTER=traffic NATIVE=off`; `make manoeuvre-probe-jam` (the judges and tables under `tests/manoeuvre/`); `make remote
T=native bridge-pooled BRIDGE_POOLED_SEEDS=... BRIDGE_FLAGS=...`; `make quick-remote`; a full check of every hash you name. Smoke like
a player: `make skirmish ARENA=terminus SKIRMISH_FLAGS="--traffic-on=nopush"` v without: select all, send them across; who shoves,
who waits, does anyone stand.

## Don't touch

`game/control/**` and the planner (orders' / nobody's), `game/tactics/**` (engage, settle's functions), `game/camera/**`, `native/**`
(ask via the orchestrator), `game/units/**` (balance), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing. (His decision 2, a click beside his army, is orders' question and needs no code from you.)

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
