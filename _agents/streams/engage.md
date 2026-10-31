# Stream: engage (a hurt crew falls back to its squad; an outranged crew stops backing up under fire)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345, 352, 353, 354), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 48** (C48.1-C48.4) and **Round 47** (C47.1-C47.11; R47.44, R47.50-R47.52, Bars E3 / E7 / E10), your last brief
> `streams/archive/round47/engage.md` (FINAL REPORT and its round-48 list), spotter's classes
> `streams/references/round47/spotter/batch1-classes.md` (**A** and **E** are yours), `game_design.md` *His playtest after round 46's
> ships* and *His spotter labels*. **You own:** as round 47 — `game/ai/gunnery.gd`, `game/ai/fire_lanes.gd`, `game/ai/outranged.gd`,
> `game/ai/tank_brain.gd`'s CLEAR_LANE option, target choice and their constants, R47.50's grant on `_act`'s arms (RETREAT / ENGAGE /
> ADVANCE / HOLD / MOVE) + `withdraw_point`, R47.44's `Tank._short_halt` cancel line, `game/ai/native/native_decide.gd`'s constant table
> (additive), `game/ai/perception.gd`'s target-fix / sight timing ONLY, `game/tactics/drills.gd`, `game/tactics/element.gd`'s
> player-authority code, `game/tactics/element_plan.gd`'s engagement functions, `game/tactics/firing_position.gd`,
> `game/ai/order_controller.gd` (trace lines), GRANT `game/control/order_executor.gd`'s crew branches, GRANT `game/ui/hud_messages.gd`
> (additive), `tests/tactics/test_engage*.gd`, `tests/engage/**`, `tests/test_authority*.gd`, `tests/test_gunnery*.gd`,
> `tests/test_fire_lanes*.gd`, `mk/engage.mk`, `game/garage/**`, `mk/garage.mk`. **Model:** Opus. **Machine:** builder3.
> **Seeds:** 13313-13408. Dev 7001-7012 (never a bar).

## The lead's direction (verbatim)

2026-10-30, Crossing: "in all of the games the gang tanks still just never end up shooting at the SYndicate, they all get killed first.
Is something wrong or do the gang tanks not have sufficient range to shoot across the bridge?"

2026-10-31, on spotter's flagged clips: "For 100% cases that I've checked, it does in fact look dumb."

Memory: units must look smart; his direct order to a unit wins; smart AI on both sides (symmetric improvements ship without asking).

## Where things stand (main df9aacc1a GREEN builder3 3630/0)

- **ON:** E7 press-on (his attack beats RETREAT), E3 snap shots + the short-halt fix, E10 outranged (close by cover under his attack,
  or break line of sight; retreats head for the squad). E10's ship read (R47.51, d8d4979ca, n 39 paired): out_damage 285.8 -> 223.5,
  retreat distance from squad 17.3 -> 11.8 m, his Crossing case lancers killed 0 -> 4. **Bar E10 FAILED D2's reverse half:**
  reverse_m 402.6 -> 230.8 = 0.57x OFF v the 0.5 bound — RETREAT still backs up while an enemy in sight lays on it within 12 m.
- **Class A (4 clips, batch 1 at 1209a934f, before E10):** a crew at 2-10 % hp RETREATs in REVERSE 4-5 m/s for 8-19 s, 50-125 m away
  from its squad, no enemy in sight, then sits alone; its order is still the squad's attack_move. E10's retreat-to-squad branch may
  already cover some of it: unmeasured.
- **Class E (5 clips):** hit from beyond its own range, sitting still or reversing, not shooting back (#5, #10, #19, #12, #20). E10 is
  the answer under his attack; whether the CPU / unordered case is covered is unmeasured.
- Open from round 47: E10 cover use on the close; E8 his post tighter (with R47.43's overstay post).

## Backlog (in order)

1. **E1 classes A and E at main df9aacc1a.** Re-run every class A / E clip (batch 1's lines; batch 2's A/E-like flagged clips from spotter,
   C48.3) on main. For each: still dumb (the same seconds) or fixed by E7 / E10? Report the split in Status and message the orchestrator.
2. **E2 the retreat: turn and drive, toward the squad, stop once out of fire** (ON, smallest change, C47.2). A RETREAT longer than a few
   metres turns and drives forward rather than reversing; its destination is the squad / a covered spot near it; it ends when out of
   fire or line of sight. This IS E10's reverse half, so one bar answers both: **Bar E11** filed before any number on 13313-13360;
   deciding = reverse_m and distance from squad on retreats (E10's lines) plus class A's signal crew-seconds a fight; guards = out_damage,
   crews lost, authority 24/24, friendly hits, E10's D1. Twin first (C47.6), replay stamp entry in the same merge (lesson 354).
3. **E3 class E's leftover** (whatever E1 shows E10 does not cover, likely the unordered / holding crew under outranging fire): the same
   E10 choice (close by cover or break line of sight) for a crew with no order from him; a HOLD from him stays a hold (his order wins).
   Bar E12 on 13361-13408.
4. **E4 E10 cover use on the close** (round 47's list).
5. **Stretch:** E8 his post tighter.

## How to verify

`make quick-remote` to iterate; `make remote T=check` for a hash you will NAME (read `>> remote: make check exited <N>` and `N passed, M
failed`). `make outranged-bar` and the E10 probe are your tools; `make spotter-clip ...` to watch a case before and after; his Crossing
case as the acceptance READ (never a bar). Spotter re-reads class A / E at the new main after your merge (C48.2). Every number with
commit, machine, workload, n. No local Godot runs but a lock-held laptop budget read.

## Don't touch

movement / traffic / yield (manoeuvre), `game/control/**` but your grant and the follow station (orders), `native/**`, `pathing.gd` /
the planner, `game/camera/**`, `game/ui/**` but `hud_messages.gd`, `arenas/**`, `game/match/**`, `game/units/**` (unit ranges are not a fix:
balance waits), `tests/baselines/**`, `tools/spotter/**`.

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
