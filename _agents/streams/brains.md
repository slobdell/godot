# Stream: brains (artillery drives to your side and shells from there; a drawn flank is carried out; your bridge 108/108 again)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–303), `_agents/game_design.md` *Round 28 direction*
> (his calls 3 and 4), *Round 28: decided for him*, **Round 29: his artillery call**, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 29** (C29.1–C29.8), and round 28's brains report
> (`streams/archive/round28/brains.md`: *FINAL REPORT*, B1, B2, B4). **You own:** `game/ai/**` EXCEPT traffic's,
> manoeuvre's and native's carve-outs (C29 list; `order_controller.gd` is manoeuvre's face path + native's seams),
> `game/tactics/**`, `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`,
> `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`,
> `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`. **Granted to others in your files:** traffic's one gate line each
> at `_track_progress`, `_update_phase` and the element's make-room / re-seat clock (C29.3: a crew holding for traffic is
> not stalled, not "blocked", not re-seated); manoeuvre's three lines in `TankBrain._order_move`; scout's SUPPRESS arm
> only if manoeuvre's stretch opens (C29.6). **The C++ (C29.2):** `decide`, `build_situation`'s core and the
> TacticalQuery functions run in C++: a change there goes to native as a diff first.

## The lead's direction

**Round 28, his calls (2026-10-12):** artillery with a drawn attack side: **SHELL FROM HIS SIDE** ("a drag means the same
thing for every unit"); a drawn flank onto a stronger squad: **SWING ROUND ANYWAY** (the squad carries out the order even
if it costs crews). Decided for him (reversible): a target that CHARGES the squad latches the flank "in" and the squad
fights where it is (`--approach-latch=off` restores the literal rule).
**Round 29, his artillery call (2026-10-13), his words:** *"I thought artillery generally had the disadvantage that it needs
to be positioned still in order to fire."* Re-asked in those terms, he chose **GO STRAIGHT TO MY SIDE**: it packs up, drives
round, sets up on his side and opens fire; the first round ~25 s after the order is accepted. It does NOT set up and fire
where it stands first.

What he will notice: drag a side for his artillery and it drives round without stopping to fire, sets up on that side and
shells from there. Drag a side for a squad attacking a dug-in enemy and it comes round and hits it from that side. His
bridge drill passes every cell again.

## Where things stand (main `bcef46a1`)

- **B2 artillery from the drawn side, parked** on `lab/brains-r28-battery` = `88b6a724`. Tuning seeds 4–6 (builder0,
  n = 18): fires from the side 18/18 (median shooter bearing 28.2°), alive 3.00 = clicked, first round 25.8 s v clicked
  2.3 s. It failed only on the first round's +23.5 s against a +15 s cut-off: **he has now accepted that wait**. Three
  traced fixes are on the branch: a mortar on a named move deploys and never leaves; a plain move fires at will on contact
  and deploys; a column re-laid from the moving centre swung round its post. Today on main a battery already carries its
  approach through `APPROACH_BATTERY`.
- **B1 a drawn flank, parked** on `lab/brains-r28-flank` = `f3a0145d`. Judged (fresh seeds 7–9 × 6 ticks): (a) even roster
  on side 10/18 against a bar of 12 (clicked 0/18; kills 10 v 4, alive 2.00 v 1.50); (c) a charging target 4/18 and the
  fight guard failed (kills 10 v 18, alive 2.39 v 4.89): the latch needs the target inside the CREWS' reach (35 m × 1.15),
  but the charging IFV stops at its own 45–60 m to shoot, so the trucks are shot while going round. (b) a Law five is a
  wipe either way (balance). On main `APPROACH_CARRY` is off (`--approach-carry=on` for B1's rule).
- **B4 his bridge 106/108, parked** on `lab/brains-r28-reissue` = `254fd98f`. Bisected to `7baffe24` (round 26: a heading
  change > 20° re-issues a crew's order); `--reissue-heading=off` gives 4/4 v 2/4 on his cells. The narrow fix (re-issue
  only when the TASK's drawn facing changed) traded his two cells for two new ones: rust t5 seed 1 (crossed 3/4) and
  rust t16 seed 2 (rim).
- Tools: `make approach-trace`, `flank-probe`, `flank-clip`, `recon-probe`, `contact-census`, `queued-screen-shots`,
  `bridge-series`, `bridge-pooled`.

## Backlog (in order)

**B1 — artillery from his side, his way (DECLARED).** From `88b6a724` with its three fixes: on a drawn side a battery packs
up, drives round to its post on the drawn side WITHOUT deploying on the way (no fire at will that deploys it, no named-move
deploy), sets up there and fires. Clicked artillery unchanged. **Bar (send before the numbers; one attempt):** fresh
seeds (not 4–9), n = 18: fires from the side (median shooter bearing within the side cone) ≥ 16/18; alive ≥ clicked − 0.5;
**no round fired before it is on side** (a counter, lesson 300); first round ≤ clicked + 30 s median (his accepted ~25 s;
the cut-off is the orchestrator's, set from round 28's 25.8 s); clicked byte-identical; ≤ 0.5 ms. A before/after
`flank-clip`-style clip of one run for him.

**B2 — a drawn flank, the target's reach (DECLARED; the last attempt).** From `f3a0145d`: the latch keys on the TARGET's
reach of a crew (a charging target that stops at its own 45–60 m to shoot latches "in" there), not the crews' own reach.
The rest of B1's design stays (column on a wide ring, the side-sector fight). **Bar (send before the numbers):** round 28's
bar (median hit bearing within 35°; (a) even roster ≥ 12/18; (c) charging ≥ 9/18 or the partial rule; fight guard kills ≥
clicked − 2, alive ≥ clicked − 0.5; (b) reported; clicked byte-identical) on NEW fresh seeds 10–12 × {1,3,6,8,11,16}
(lesson 298: (a) is NOT re-judged on new seeds for a latch-only change unless the bar says so up front; say which).
`flank-probe` on 3 fresh seeds and a before/after `flank-clip` on one seed where it comes round (what he judges).

**B3 — his bridge 108/108 (DECLARED).** Trace the two cells `254fd98f` loses (rust t5 seed 1: crossed 3/4; rust t16 seed 2:
the rim) BEFORE another fix (lesson 302); then one fix that keeps round 26's re-issue case (its tests) and passes all 108.
Bar: 108/108; reorder_heading + the fight tests pass; arrive series fresh seeds not below control − 1 on the 8 m line,
median within +2 %; thirteen declared.

**B4 — the gang trucks' screen slots (formation geometry, C29.8).** Four gang gun trucks (10 m hulls) screening get 6 m
slots side-on; one parallel-parks for ~1 min (TacticsLab seed 61, screen to `[LANE_X, 0]` facing east from 50 m south).
Slots laid at hull length for long hulls arriving side-on. Also any slot spread manoeuvre's M1 asks for (through the
orchestrator).

**B5 — stretch:** the element re-seating crews 3/4 for 36 s at a blocked slot (traffic's T3 lead: Sumps arrive cell
law_scout:law_ifv:law_tank:law_tank, seed 1, `make traffic-settle-trace`, n = 1, a lead); a queued attack-move / attack
after a waypoint takes its automatic facing from the last waypoint (B5's known gap); the support-by-fire line for wheeled
turret hulls (O3: 91° drawn v 56° clicked) if manoeuvre's M1 does not cover it.

## How to verify

`make remote T=check` (builder0 only, C29.7); `approach-trace`, `flank-probe`, `flank-clip`, `bridge-series`,
`bridge-pooled`, arrive series, `native-verify-scenarios`; clips and shots for him (look at them).

## Don't touch

Traffic's `traffic*.gd`, `avoidance.gd`, the give-way block, `_avoid`; manoeuvre's drive body, k-turn block,
`manoeuvre*.gd`, `wall_contact.gd`, `order_controller.gd`; native's `native/**`; `game/control/**` (ask: round 28's B5
grant is closed).

## Waiting on the lead

Nothing: his calls are made (artillery: go straight to his side, 2026-10-13).

## Status

_Not started (round 29 launch, 2026-10-13)._
