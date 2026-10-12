# Stream: orders (attack from a side you draw; showmatch recordings worth sharing)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (reading (5), the
> press–drag–release gesture) and *Round 27 direction*, `_agents/workstreams.md` *Round 27* (C27.3, C27.6), and round 26's
> orders report (`streams/archive/round26/orders.md`, *Round 27 candidates*). You own `game/control/**`, the order hints
> in `game/ui/**` (help/hint text about order input only; list them in Status), `tests/test_control*.gd`, the control
> playtests and their make targets in `mk/command.mk`, the showmatch/cinematic tooling you built in round 26, and this
> round (grant) `game/camera/**`'s cinematic framing.

## The lead's direction

Round 26: *"I was trying to get tanks oriented in a screen at a particular angle … This is probably the case for all our
specialized cases (attack, ambush, screen, etc)."* Round 26 gave screen, support by fire, ambush, attack-move and move a
drawn facing; **attack** was left out (decided for him overnight 2026-10-11: a round 27 candidate). Round 26 also: he
asked for `make demo` *"so I can easily record the game to share with people"* — that is `make showmatch`, and he
watched it to give round 27's feedback, so its recordings matter.

What he will notice: press on an enemy and drag, and the squad swings round to come at it from the side he drew; a
showmatch recording that never ends looking at the floor.

## Where things stand (main `04845af7`)

- Armed orders take a facing (press at the spot, drag toward the facing, release); a click keeps the automatic facing.
- Attack (press on an enemy) takes no direction.
- The cinematic camera's last shot can tilt so the bottom third is the purple floor under the arena (seed 43496 docks,
  `HUD=1` movie's end frame).
- Hull facing at rest against a drawn facing has a tail of 100–167° hulls on every task (round 26 probe, small n).

## Backlog (in order)

**O1 — attack with a drawn direction (C27.3).** Press on an enemy, drag, release: the drag's direction (from the release
point toward the enemy, i.e. the side to come from — pick the reading that feels right in play and write the one-line
reason) goes on the attack task as `task["approach"] = [x, z]`; a plain click on an enemy is today's attack. Show the
drag the way the other armed orders do. Until brains' CP0 merges, test against a stub reading `task["approach"]` in your
paths; after CP0, `git merge main` and prove it end to end through the player's input path (lesson 291: probe the path
the player's input takes — `recall_group` → `order_selection`, never `assign_task` directly).

**O2 — the cinematic camera's last shot stays on the arena.** Clamp the framing so the end shot never looks under the
arena floor; screenshots at desktop and phone aspect of the end frame over several seeds/maps (look at them).

**O3 — hull facing at rest, judged properly.** Per hull class at n ≥ 30, same-seed A/B: how far each hull ends from a
drawn facing per task. Report only; anything to fix is a request (the face-at-rest path is in frozen `order_controller.gd`;
the scout's post facing is brains' S6 rule).

**O4 — stretch:** the help text for the new gesture; a short `make showmatch` clip of a flank attack for him.

## How to verify

`make remote T=check`, `make remote LIGHT=1 T=facing-probe` / `T=facing-shots`; scripted input through the real path;
screenshots at desktop and phone aspect. Every Godot run on builder0 (C27.6).

## Don't touch

`game/ai/**`, `game/tactics/**` (brains', scout's, native's); `order_controller.gd` (native's freeze); `native/**`.

## Waiting on the lead

Nothing.

## Status

_Not started._
