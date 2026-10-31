# Spotter stretch S7: an offline parameter search on idle nights (a PROPOSAL for next round's orchestrator)

_Written 2026-10-31 by the spotter worker (stream/spotter). Nothing here is built; nothing here ships. The standing ruling
(game_design.md "What stays shut", 2026-09-19) allows frozen tables from offline search: this proposes one, under it._

## What it would search

Behaviour constants that decide the moment classes the spotter finds most often (its first batches: crews boxed in by
squadmates and reversing, no progress toward the goal, far from the squad). Candidates, each with its owner:

| Constant (file:line at 5020d4dd8) | Now | What it decides | Owner |
|---|---|---|---|
| `Movement.STUCK_SPEED` / `STUCK_SECONDS` (game/ai/movement.gd:79-80) | 0.8 m/s / 1.0 s | when a crew counts as stuck | manoeuvre |
| `Movement.UNSTICK_SECONDS` / `UNSTICK_CLEARANCE` (:81-83) | 0.9 s / 2.0 m | how long / how far an unstick backs off | manoeuvre |
| `Movement.REPATH_SECONDS` (:26) | 4.0 s | how often a crew re-plans its route | manoeuvre / route |
| `Movement.FOLLOW_AHEAD_M`, `WAIT_AHEAD_M` (:227, :265) | 16 / 12 m | when a crew queues behind a squadmate | manoeuvre |
| `TankBrain.LANE_SEARCH` / `LANE_SEARCH_FAR` (game/ai/tank_brain.gd:99, :130) | 10 / 16 m | how far a crew looks for a clear firing lane | engage |
| `TankBrain.FOLLOW_DISTANCE`, `HOLD_TOLERANCE` (:292, :276) | 10 / 3 m | spacing on a follow, slack on a hold | orders / engage |

## The one prerequisite (an owner edit, not the spotter's)

These are `const` today, so a fight cannot vary them without a code change. The `--tune=` path (`Units.apply_tuning`) already
covers unit and weapon stats and a few `match.*` knobs; it would need a **behaviour knob registry**: each owner turns the
constants above into `static var` read at the point of use and registers them, e.g. `--tune=move.stuck_seconds=1.4` (the
`match.*` comment in units.gd explains why the registry must live in the consumer's class). Default values unchanged, so the
sim baseline does not move. Cost: one small edit per owner file; a test per knob that the default is byte-identical.

## How the night shift would run it

- **Arms:** a coarse grid or a random search, one constant at a time first (8-12 values each), then pairs that interact
  (STUCK x UNSTICK, FOLLOW_AHEAD x WAIT_AHEAD). Each arm = the night batch (6 maps x N seeds of the R47.40 block, 240 s) with
  `SPOT_FLAGS=--tune=...`, so the same yield / checkpoint frame applies. builder3 idle ~8 h a night is ~150-200 fights.
- **Objective (what decides):** the spotter's dumb-signal crew-seconds per crew-minute, per class, PAIRED by seed and map against
  the default arm (the same fight, one constant moved). Once S6 has a learned ranker that beats the hand one on his labels, its
  predicted-dumb seconds replace the hand signals as the objective.
- **Guards (each must hold, or the arm is discarded):** fights' outcome balance (green v rust win share within the default arm's
  95 % interval), friendly hits and wall contacts not up, kills / shots per minute not down by more than 5 %, no engine errors.
- **Output:** a frozen TABLE (constant -> chosen value, per unit class or locomotion if it helps), with each arm's paired numbers,
  commit, machine and n. It goes to the owner as a proposal; the owner files a bar for it like any other change. The spotter never
  edits game code.

## Why not now

The registry is an edit in other streams' files (manoeuvre, engage, orders). And the objective is only as good as the ranker:
before his labels say what "dumb" means, a search would optimise the hand signals, which may include things he calls fine (a
crew waiting its turn at a bridge reads as "no progress"). So the order is: S4 labels -> S5 precision per signal -> drop or
reweight the signals he calls fine -> then search.
