# Navigation: how a unit gets where it is sent

> Owned by the **nav** stream (round 6). The contract is **N1** in [workstreams.md](workstreams.md); this file is the
> architecture behind it, written as it is built. The lead's question *"are we using A\*?"* — yes: Godot's
> `NavigationServer3D` runs A* over the navigation polygons baked from the arena's collision at startup
> (`Pathing.find_path`). What was missing in round 5 was everything about *other units*.

## Round 9: the desired-velocity layer, and what replaces what
### When a number is in someone else's document, it stops being yours to reason about (squad's refinement)

nav re-ran a published A/B after changing the code under it, and framed the lesson as *"a number someone else is
already holding is the worst place to skip a re-run"*. **squad sharpened it, and their version is the right one:**

> **The rule is about WHO IS HOLDING IT, not about who measured it.**

Both halves of tonight fail the same way and they are mirror images:
- **nav's case — a number it OWNED.** The figure was mine, the change was small, the direction was conservative.
  *Every one of those is a reason to skip a re-run and none of them is a reason it would have been safe.* Four of
  those figures turned out to be load-bearing in squad's Status, and two were the stated reason their A1 half ships
  with its default off — a stale one would have been cited in a document another stream reads.
- **squad's case — a number it did NOT own.** They relayed scale's corridor table into their brief and reasoned from
  it inside the hour. It was retracted. *(nav did exactly the same thing with the same table.)*

**So the test is not "did I measure it" or "is the change small". It is: has this number left my hands?** Once it
has, it is a dependency of someone else's decision and it gets re-verified when anything under it moves —
or withdrawn out loud.

### Ask the machine what it holds; do not reason about rsync timing (squad's, adopted 2026-09-20)

**A remote check covers the tree that was SYNCED, not the tree you have**, and the way to find out which is to ask
builder0 rather than to reason backwards from when the rsync started:

    ssh slobdell@builder0 "grep -c 'wedged' ~/tank_squad/godot-nav/game/ai/movement.gd"   ->  0

**One query, a definite answer.** That `0` says the running check covers the tree *before* the `wedged` detector —
so its verdict applies to that commit and to nothing committed since. The alternative is comparing an rsync
timestamp against a commit time and hoping, which is how round 8 mis-identified which tree a verdict belonged to.

It is the same instinct as *diff against main by path after any cherry-pick* rather than trusting that a checkout was
undone: **when a fact about the world is one query away, query it.** Both habits cost seconds and both replace an
inference that is right most of the time — which is the worst kind, because it fails silently and only when it
matters.

### An HONEST instrument is not enough if nothing asserts on it (nav, 2026-09-21)

nav's clearance tests failed with this on the line above the failure:

    MEASURE clearance_routing: gang_tank chord slack nan m, scout nan m (chords 0, refused 0)

**Both halves of the diagnosis were printed and neither was asserted.** `chords 0` says the rule was never
consulted. `nan` says the number is a fallback, not a measurement. The counter — built precisely so a zero could
not be mistaken for a result — did its job perfectly, into a log nothing was reading. The assertions then failed on
a comparison downstream, which looks like a wrong threshold rather than a setup that never ran.

**The rule: every denominator you print, assert on.** A counter that only appears in output protects a human who
reads the output. A counter that appears in an `assert_true` protects everyone, including the author at 4 a.m. who
skims to the first FAIL and starts debugging the wrong thing.

**This is one layer beneath the round's arm-and-denominator discipline, and it is where nav kept falling.** The
round produced six false zeros and caught them all — then produced a seventh where the instrument *worked* and the
test ignored it. Printing is not checking. `assert_true(clearance_chords > 0, ...)` costs one line and converts
"these numbers look odd" into "the mechanism never ran", which is a different debugging session.

(The concrete cause was `Movement.of()` returning null before a hull is driven — there is no mover until an order.
nav made the identical mistake in the legibility test the same night. The second occurrence is why this is a lesson
about asserting rather than a note about movers.)

### A positive control proves the mechanism FIRES, not that the row is worth shipping (nav, 2026-09-20)

A4 was measured twice and the two measurements point opposite ways:

    positive control   yard: 423/423, 403/403, 233/233, 180/180, 729/729 blocked gates rescued -- 100% every seed
    the fight          yard seed 3 attack-move progressing -14.4%, seed 5 -12.8%   <- the two WORST breaches
                       terminus, where A4 rescues 0-13%, breaches once and by less

**The map where the mechanism works perfectly is the map where it hurts most.** A4 buys the gate and spends the
fight: it finds a navmesh-valid curved entry for every blocked gate on yard and the hulls that take those entries
fight measurably worse. Had the row been judged on its positive control alone — and 403 of 403 is a compelling
number to be judged on — it would have shipped.

**The rule: a positive control needs a COST bar pre-registered beside it, and the cost bar has to measure the thing
the feature exists to serve.** nav's did: *"routing to a gate costs distance, and if it costs fighting it is not
worth it"*, written before A4 was built. That sentence is the whole reason this round did not ship a row that
reaches 100% of its targets.

**The corollary that is easy to miss:** because the cost rises with how often the mechanism engages, **a weak arm can
look safe**. terminus engages A4 rarely and breaches once; yard engages it constantly and breaches twice as hard. A
row screened only on maps where it barely fires will pass its guard and then fail in the field on the map it was
built for. **Check the guard hardest where the treatment is strongest**, which is the opposite of where a
headroom check sends you.

**On the numbering:** nav minted "Lesson 158" for the entry below without checking the register, which is a shared
global sequence in [orchestration.md](orchestration.md) that only the orchestrator assigns. The number is dropped
rather than kept: both nav entries above are titled and unnumbered, and the two lessons nav *did* earn a number for
this round are **lesson 170** (*a "waiting-on" line is a claim with a date on it — nav and control each blocked on
the other for hours with both halves already done*) and **lesson 171** (*a switched row and its arm field are one
change, not two — nav shipped `a4` and then `a6` without their `NAV_FIGHT_ARM` fields, twice in one night*).
Recorded rather than quietly renumbered, because a lesson about drift that itself drifted is worth the line.

### Before building a recovery, check the PLANT can produce the failure you are recovering from (nav, 2026-09-20)

nav built a recovery for a `face` order that never comes round, measured it, and found it **inert** — not because the
detector was wrong but because **the failure mode does not exist in this simulation**. `tank.gd` assigns
`global_basis` directly and only `move_and_slide()` beneath it resolves anything, so **translation is collided and
rotation is not**. A hull under a `face` never fails to turn; it turns *through* the wall. `face_checked 7,
giveups 0` on the real case and `checked 5, giveups 0` in a corridor where the hull's 44° needed 12.1 m of a 4.8 m
gap.

**The rule:** a recovery is a claim about a state the plant can reach. *Reproduce that state first, and assert you
reproduced it, before writing the thing that escapes it.* The cost of skipping it is not a bug — the code is
correct — it is a row that passes its tests, ships behind a flag, and measures nothing, which is expensive precisely
because nothing looks wrong.

**It is the same family as lesson 153's twin above, one layer down.** That one says an instrument at its ceiling
cannot report. This one says a *mechanism* whose triggering state is unreachable cannot act — and both are found the
same cheap way, by checking the control arm before running the treatment. **The positive control belongs inside the
fixture**: nav's corridor test asserts the hull really is wedged (10.4 m of path ground out) before it asserts
anything about the recovery, so a fixture that stops wedging reports a broken fixture instead of a passing row.

**And the denominator is what made the difference between a null and a discovery.** The first A/B gave two
byte-identical arms, which is the shape of "no effect" and of "never ran" at once. `face_checked` separated them in
one run. **Every switched mechanism gets a denominator** (lesson 147's arm counters, applied to a recovery rather
than a treatment).

### Lesson 153 has a MEASUREMENT twin: a saturated instrument reports nothing (scale, 2026-09-20)

nav's lesson 153 is *a term that merely saturates as one addend goes blind when it is promoted to a priority level,
because inside a level a cost only competes with itself.* scale's maze table is the same fact about **instruments**:

    BEFORE -> AFTER      stuck_units   30 -> 30   (pinned; saturated before the change)
                         oscillating_units 14 -> 27, oscillating_unit_seconds 10.5 -> 132.3 (x12.6)

**`stuck_units` was already at its ceiling in both arms, so it carries no signal at all; `oscillating` sat near its
floor (share 0.004) and moved by an order of magnitude.** Same run, same pathology, and one of the two instruments
could not have reported it whatever happened.

**The rule for choosing an instrument, which is cheap and nav had not written down:** *check its HEADROOM in the
control arm before you run the treatment.* A counter already at 0 % or 100 % before you change anything will still
be there afterwards. That is the same shape as a tolerance that admits everything, a lint that parse-checks zero
files, and a `--nav-off` name nothing reads — **an instrument at the end of its range is indistinguishable from an
instrument that is not connected.**

### The cheapest instrument check nav has, learned from scale (2026-09-20)

**Before trusting a measure, find something already in the repo that knows the answer.** scale's corridor table
reported every map as too tight; the corrected measure reports the maze's tightest point as **exactly 7.00 m**, and
`tools/make_arenas.py` authors `MAZE_TIGHT_GAP = 7.0` — *a number somebody typed on purpose, in the same repo, free.*
Any measure of that gap either reproduces it or is wrong, and the broken one said 4.41.

nav has no instrument that checks itself against an authored constant, and several that could:
`Movement.NAV_AGENT_RADIUS` against `Arena._bake`'s own value (they are mirrored today and should be read, not
copied); the arrival gate's approach length against `APPROACH_RADII`; A11's lattice against `TankMotion` itself —
**which is the one case nav got right by accident**, because the lattice is *generated by* the plant rather than
modelled from it, so it cannot disagree.

**The general rule this suggests, and the reason it is cheap:** a positive control does not have to be built. It
usually already exists as a constant, a fixture, or a generator's own input, and finding one costs a grep.


> Written at the start of round 9 (2026-09-19) and kept current as each row lands. The backlog rows are A7, A11, A1
> and A4 in [research_catalog.md](research_catalog.md); the sequencing argument is in [workstreams.md](workstreams.md)
> *Round 9 goal*; the brief is [streams/nav.md](streams/nav.md).

**The Invariant 0c declaration, verbatim, because a round-9 row is only safe if it REPLACES something** (catalogue
Part 2: *replacing is safe, adding alongside is where two techniques fight*):

> nav owns the **desired-velocity layer** — `game/ai/movement.gd`, `game/ai/combat_motion.gd`, `game/ai/steering.gd`,
> `game/tank/tank_motion.gd`. It assumes **above** it that squad hands down goals and, since round 8, a `facing`. It
> assumes **below** it that the plant honours (throttle, turn) with a bounded yaw rate. **A7 replaces the additive
> blend; A11 replaces the 16-direction ring; A1 replaces the fixed repath / re-aim cadence; A4 replaces the straight
> approach inside the arrival arc. None of the four adds alongside.**

| Row | Replaces, by file and function | Restored by | Arm counter |
|---|---|---|---|
| **A7** null-space priority projection | the additive score in `CombatMotion.choose` (`WEIGHTS`, the `PENALTY_*` terms, `COMMIT_BONUS`) **and** the PID station override's precedence over avoidance in `Movement.drive` | `--nav-off=a7` | `a7_projected` |
| **A11** dynamic-window arcs | `CombatMotion.RING` and the `wheels` / `min_cos` chord test | `--nav-off=a11` | `dwa_candidates_reachable` |
| **A1** state-error tube | the `REPATH_SECONDS` / off-path / stalled cadence in `Movement._next_waypoint` (and, by request to squad, `TankBrain.MOTION_REPLAN_TICKS`) | `--nav-off=a1` | `a1_tube_skips` |
| **A4** clothoid primitives | the straight approach in `Movement._approach_gate` | `--nav-off=a4` | `a4_clothoids` |

**Two rules this layer holds itself to all round**, both bought with round-8 time:

1. **An arm counter, or it is not a comparison** (lesson 147). Round 8's facing A/B compared two arms in which the
   treatment never executed once, and the only thing that said so was a counter added for exactly that. Every row
   above ships its counter in its first commit, and `nav-fight` reports them all under `arms`.
2. **`--nav-off=<row>` selects between the NEW mechanism and the OLD one it replaces**, never "the new thing,
   disabled into nothing", which is a third treatment rather than a control.
   **`a7` is currently INVERTED** — like `holdband` and `r5sidestep` it turns its mechanism **ON**, because A7 is
   built and measured but **is not the default**. See *A7 is built, measured, and NOT shipped on* below.

**Determinism, for every row:** no wall clock inside a decision (`dt` is the tick), neighbours ordered by name, a
fixed iteration count, ties to the lower index. Fresnel integrals (A4) come from a fixed-size table with fixed-order
interpolation, never a series evaluated to a tolerance.

**Audited at the start of round 9, rather than assumed** (`movement.gd`, `combat_motion.gd`, `steering.gd`,
`tank_motion.gd`, `avoidance.gd`, `pid.gd`): the layer reads the wall clock in exactly **one** place,
`movement.gd:435`, and it is a profiling lap timer whose value reaches `OrderController._lap` and nothing else — no
decision consumes it. There is no RNG anywhere in the layer. So the round starts from a clean determinism position
and every new row has to keep it, rather than having to establish it first.

### The arrival gate's three-way counter (round 9, N0)

`gates_offered` / `gates_aimed` / `gates_refused`, with refusals split by reason (`off_mesh`, `on_approach`,
`reached`, `no_facing`, `bad_facing`). Round 8 could not tell *"never offered a facing"* from *"offered one and
refused the gate"*, and those are opposite findings: the first is an instrument failure, the second is a mechanism
finding. `nav-fight` reports the split, and the round's A/Bs all issue at least one order carrying a `facing` (a
squad hold, and a move with one) so the arrival path is a live arm **by construction** rather than by memory.

### A7's priority table (N1a, nav, 2026-09-19) — REVIEW WANTED from combat and feel before any A7 code

> **What this is.** Catalogue row **A7** replaces the additive score in `CombatMotion.choose` and the PID station
> override's precedence over avoidance in `Movement.drive`. *"Six multiply-adds"* understates it: `CombatMotion.WEIGHTS`
> is where round 7's approved behaviour lives — standoff and shoot-and-scoot, commitment, armour toward threats, the
> leash, the dodge, don't-walk-into-a-wall-of-bullets. **Every one of those either survives in this table as a named
> priority or quietly does not.** So the table is written, reviewed and argued before a line of A7 exists.
>
> **Reviewers:** combat (N5 engagement envelope, L2 suppression, A2's switching cost), feel (S4 legibility — the A6
> motion law must appear here as a named priority, not as a new additive term). Route: the orchestrator.

#### How the levels work, and the one honest caveat

The textbook statement (Antonelli, Arrichiello & Chiaverini 2008) synthesises a velocity as
`v = Σ_i (Π_{j<i} N_j) v_i`, each lower task projected into the null space `N_j = I − J_j⁺J_j` of the higher ones.
**Our velocity set is discrete** — a 16-direction ring today, A11's reachable (speed, yaw-rate) lattice after N2 — so
the projection is exercised as a **tolerance-banded lexicographic filter over candidates**, which is the same algebra
applied to a finite set:

    survivors := feasible candidates
    for each level i, highest priority first:
        if the level has no active task: continue          # it leaves the whole set free
        c_i := cost of each survivor at level i
        survivors := { c in survivors : c_i(c) <= min(c_i) + TOLERANCE[i] }
    choose argmin of the last level's cost; ties by lower index

`TOLERANCE[i]` **is** the null space of level *i*: 0 makes the level dictatorial, ∞ makes it a pure preference. Fixed
level count, fixed candidate count, no convergence loop, ties by lower index — deterministic by construction.

**The caveat, stated plainly so nobody is surprised at merge: A7 does not remove tuning, it restructures it.** Eight
weights that traded off incommensurable quantities (metres of range against radians of turn) become five tolerances,
each with units inside one level. That is a better-shaped problem, not a smaller one, and the honest claim for the
round is *"opposing goals can no longer cancel to zero"*, never *"nothing is tuned any more"*.

#### The levels

| # | Level | What it is | Null space it leaves |
|---|---|---|---|
| **0** | **FEASIBILITY** (a mask, not a level) | reachable by the plant this tick; inside the arena; not crossing or ending in an obstacle | everything else. If the mask is empty the boxed-in fallback runs, exactly as today |
| **1** | **SURVIVAL** | a round that would hit me; a route through a beaten zone | free whenever no candidate is safe — a unit boxed in by fire still goes somewhere |
| **2** | **WEAPON** | the standoff band (radial), the ram guard, keeping the target in sight | **the whole tangential component** — which is why circling survives untouched |
| **3** | **ARC / ARMOUR** | front toward threats; the angle style's side-on guard; **A6's motion law, named** — A6-a the nose clause, A6-b the shoulder clause | **speed alone.** A6-b claims the sign of the arc (feel's one change, accepted — see below) |
| **4** | **FORMATION** | the leash on the element slot; crowding; `Movement`'s PID station | everything inside the slot's cell |
| **5** | **PREFERENCE** | tangent, side, flank, continuity, turn cost, reverse cost, commitment | — (argmin here decides) |

**Level 5 keeps the additive weighted sum, deliberately.** A7 forbids summing *across* priority levels, not within
one. Continuity, the turn cost and commitment go on working exactly as round 7 measured them; what changes is that
they can no longer outvote a dodge or a standoff band.

#### Every term in the code today, and what it becomes

| Term (`combat_motion.gd`) | Today | Becomes | The lead-approved behaviour it encodes |
|---|---|---|---|
| `WEIGHTS[*]["range"]` (1.0 / 1.0 / 1.2 / 0.0) + `_band()` | additive | **Level 2**, as a constraint on the **radial** component only. **The band stays `[weapon.preferred_min, weapon.preferred_max]` read from `Weapons.PROFILES` via `tank_brain.gd:2315`** — no radial constant beside it, or the motion band and N5's firing envelope drift apart silently (combat's condition) | Round 7 standoff / shoot-and-scoot: closest approach 3.0 → 27.7 m, shots 29 → 211. The project's largest measured behaviour win — it is a priority, not a preference |
| `standoff_holds()` → `{"hold": true, "index": -1}` | an early return **before** the ring is scored | **Level 2's zero-radial solution, scored as a candidate like any other — and carrying its own level-5 term** (see *The hold's own term* below) | Round 7's "stop and shoot". **This is the round-8 cancellation failure being fixed**: a hold returns index −1 today and therefore never consults commitment, so we shipped and measured a term that was never in that code path |
| `MIN_GAP`, `PENALTY_RAM` (1.2) | penalty | **Level 2** (the band's inner wall) | "Scouts are just running directly into their targets" |
| `SIGHT_CHECKS` (6), `clear_line_coarse` | a post-hoc rescan of the best 6 | **Level 2's null-space preference** — it orders everything that ties on the band, not only the top 6. **Carries a CPU number** (up to 16 line checks per plan against 6) | "Circling out of view loses the fight" (the Lancer after CP2). Strictly better than today by construction |
| `PENALTY_HIT` (3.0), `would_be_hit` | penalty | **Level 1** | X3 the dodge. Now strictly dominant — but **predict this as a TAIL effect, not a headline**: 3.0 against a maximum achievable `strafe` sum of ~3.25, so today it is outvoted only by a candidate that is near-perfect on everything else |
| `beaten` (L2) + `beaten_fallback` | **already a hard skip** (`:313-316`), released only when nothing is safe | **Level 1**, with the same release. **This is a rename, not a win** (combat's word, and it is right): the behaviour is dominant today and stays dominant | "Don't walk into a wall of bullets" — and the release keeps "a unit boxed in by fire has to go somewhere" |
| `WEIGHTS[*]["armor"]`, `threats`, `MULTI_THREAT_ARMOR`, `BUSY_ARMOR` | additive 0.15–1.0 | **Level 3** for hull-fixed and heavy hulls; **null-space task (level 5)** for turreted hulls, whose gun does not need the hull. **Scope, corrected by combat: this reaches only the `strafe` style, where the weight is 0.15** — already the smallest term in that vector against `range` 1.0 and `tangent` 0.8 | X3 "keep your front toward threats", and the busy-target flank |
| `PENALTY_SIDE_ON` (1.5), `ANGLE_MASK_COS` | penalty, angle style only | **deleted as a constant**; it is level 3's expression for the `angle` style | Heavy hulls rocking along one angled heading instead of turning side-on |
| `PENALTY_LEASH` (1.5), `LEASH_FALLOFF` | penalty | **Level 4** | X1 "fight from your place in the formation" |
| `PENALTY_CROWD` (0.6), `FRIEND_SPACING` | penalty | **Level 4** | Mutual support without piling up |
| `WEIGHTS[*]["tangent"]` | additive | **Level 5**, inside level 2's null space | Round 3's circling — the lead's "no intent of trying to circle your opponent" |
| `WEIGHTS[*]["side"]`, `flank`, `BUSY_FLANK` | additive | **Level 5** | X3 the busy-target flank |
| `WEIGHTS[*]["continuity"]`, `["turn"]`, `turn_seconds()` | additive | **Level 5** | "A pivot is time standing still, the easiest shot there is" |
| `WEIGHTS[*]["reverse"]` | additive; **negative means never reverse** (`run`) | **Level 5**, priced — never a veto | P3: forbidding a switch more than doubled switch-and-switch-back. A reversal is priced, and A4 prices its cusp |
| `COMMIT_BONUS` (0.35) | additive | **Level 5, UNCHANGED by A7** | Round 7 commitment. **See the composition hazard below — this term is also combat's A2 this round** |
| `RING`, `wheels`/`min_cos` | the candidate set | **untouched by A7; A11 replaces them at N2** | — |
| `HOLD_SLACK_M` / `--nav-off=holdband` | opt-in hysteresis | **unchanged**, still opt-in | Its A/B missed its bar in round 8; it is not smuggled in under A7 |
| `fixed_style == "run"` | round 3's attack runs | **keeps the old additive blend, untouched** | It exists to be an A/B control (`--nav-off=standoff`). A control that is also rewritten is not a control |

| Term (`movement.gd`) | Today | Becomes |
|---|---|---|
| `_avoid` (ORCA) vs `_keep_station` (PID) | the station PID runs **last** and overwrites the avoiding velocity (`movement.gd:483`) | **the priority inversion A7 exists to fix**: avoidance is Level 1, station is Level 4, and the station's correction is clamped into the avoidance-feasible set instead of applied on top of it |
| `_around_fire` | pipeline stage | Level 1 |
| `_next_waypoint` / `_approach_gate` | pipeline stage | Level 2 (the goal task); A4 replaces the gate's straight approach at N4 |
| `_guard_steer`, the chord test | pipeline stage | Level 0 (feasibility) |

#### By style, since a style stops being a weight vector

| Style | Level order | Level 5 weights |
|---|---|---|
| `strafe` (turret) | 1 · 2 · 4 · 5, **armour demoted into 5** | tangent high — the turret aims independently of the hull |
| `angle` (heavy tracked) | 1 · 2 · **3** · 4 · 5, armour promoted above formation | wider radial tolerance at level 2, so it rocks along one angled heading |
| `standoff` (fixed gun) | 1 · 2 (with the hold as a candidate) · **3** · 4 · 5 | armour at level 3 because the hull *is* the gun mount |
| `run` (A/B control) | — | the round-3 additive blend, unchanged |

#### The hold's own term (combat's blocking objection, 2026-09-19 — accepted)

combat traced the table's own filter and found that making the standoff hold "a candidate like any other" **votes it
out every tick**: a crew in band has a level-2 radial cost of ~0, so the hold survives — but so does every in-band
ring direction, and level 5 for `standoff` then does argmin over `tangent 0.5, flank 0.3, continuity 0.3, side 0.2`.
**The hold scores zero on tangent; a tangential candidate scores the full 0.5.** That is not a tolerance to discover
after the code exists; it is the default outcome of the weights as the table originally left them.

**The fix, and it is a statement rather than a constant: for the `standoff` style, level 5's `tangent` and `side`
terms apply only while level 2 is UNSATISFIED.** A fixed gun's tangent term exists to reposition it into its band. In
band, a fixed gun's nose *is* its aim (measured: nose-on **0.91**), so tangential motion costs the shot and buys
nothing — which is precisely what round 7 removed when it replaced `run` with `standoff`. No hold bonus is introduced,
because a bonus would be a number nobody can defend; the rule is that a satisfied weapon level does not want motion.

**The documented "slide along the band when rounds are incoming" survives, and by the right mechanism:** level 1
filters first, so an incoming round that would hit removes the hold candidate and leaves the sliding ones. The
behaviour is unchanged; what changed is that it is now a consequence of the priority order instead of a special case.

**And the hold finally reaches the commitment path.** The hold keeps `index = -1`, and the level-5 commitment term
matches `previous_index == -1`, so a unit continuing to hold is rewarded for continuity exactly as a unit continuing
to drive is. Round 8's clearest finding was that `COMMIT_BONUS` was never in the hold's code path at all; **the arm
counter reports holds separately so this is a number, not a claim** (combat's condition, and lesson 117).

**Acceptance, pre-registered, reported before and after with the hash** —
`scenario_motion::test_a_scout_holds_a_firing_position_instead_of_ramming`, pristine `9f864474`, laptop,
`make ai-scenarios`: **closest approach 26.9 m, in-band 0.92, nose-on 0.91, 226 shots**, against the `run` control's
6.0 m / 0.05 nose-on / 13 shots. **If A7 moves any of those four the wrong way, A7 is wrong, not the scenario.**

#### A held unit's leash is a level-0 bound, not a level-4 preference (orchestrator's ruling, 2026-09-19)

Level 1 filtering before level 4 means a unit ordered to hold a firing line could be pulled off it by fire without the
leash ever being consulted — which breaks the product constraint that **the player's units hold until ordered**, and
squad's `scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move` with it (baseline: base shots
5 then 4, through a friend 0).

**So: for a unit under a hold or a station order, the leash is a level-0 FEASIBILITY bound on every candidate,
including dodges.** A held unit may dodge *within* its leash and never leaves it; a dodge that would exit the leash is
**infeasible, not merely dispreferred**. For a unit that is not holding, the leash stays the level-4 soft term it is
today (X1: manoeuvre inside your slot's cell, be pulled back rather than frozen). squad gets that scenario's
before/after with the hash.

#### A1: the state-error tube, and why its radius is not a number (2026-09-20)

**`--nav-off=a1` turns A1 ON.** It replaces the fixed `REPATH_SECONDS` 4.0 cadence in `Movement._next_waypoint`.
The goal-moved, off-path and stalled triggers are **events** and are untouched: a plan is abandoned the instant
something invalidates it, never on a clock.

**The radius has an exact answer rather than a tuned one, and finding that took two wrong versions.** Tabuada's
self-triggered control stores, at plan time, how far the state may drift before the plan stops being near-optimal.
For *this* plan on *this* navmesh:

> The navmesh is **static** and the route is **optimal**, so by Bellman's principle the route is still optimal from
> every point **on** it. Nothing about driving along a valid route degrades it. The only state errors that can
> invalidate it are leaving the route, the goal moving, or being stuck — **and all three are already events.**
> **So the tube radius IS the off-path corridor**, and `REPATH_SECONDS` on top of it was re-asking a question whose
> answer could not have changed.

**The two wrong versions, both measured before being discarded** — and they failed the same way, which is the
transferable part: *a radius derived from the route's shape is a cadence wearing a radius.*

| version | why it failed |
|---|---|
| distance to the second corner ahead, capped at 40 m | a tank covers ~36 m in the 4 s cadence, so the **cap** bound first. `a1_tube_skips` **0**, re-plans **3 of 3** |
| the same, uncapped | navmesh routes are funnel-smoothed polylines — **19 points over 100 m** — so "two corners ahead" is **28.7 m** and the hull drifts past it in **3.2 s**. It fired **earlier than the cadence it was replacing**. `a1_tube_skips` **0** again |

The probe that settled it is worth keeping in mind before designing any geometric budget on a route: at 9 m/s the
hull's drift from its plan point passed 28.7 m every 3.2 s, all the way down a clear straight corridor.

**Two instrument bugs caught on the way, both of which would have flattered the treatment:**
1. **The cadence clock did not re-arm while the tube held**, so `_repath_left` sat below zero and `a1_cadence_due`
   ticked **once per tick** — *120 "cadence firings" in 8 seconds*. It now re-arms whether or not a re-plan follows,
   so the counter says what the cadence would really have fired on that run.
2. **The test helper had the switch inverted** (`a1` is opt-in, so `--nav-off=a1` turns it *on*) and the arms came
   back the wrong way round. The counters caught it — which is the entire reason they exist, and a reminder that a
   test helper lies about the arm exactly as readily as a probe header does.

#### A11: the dynamic window, and the two things building it taught us (2026-09-20)

**`--nav-off=a11` turns A11 ON, inside A7's chooser (itself opt-in).** `RING` and the `min_cos` chord test survive
only in `choose_blended`, the round 3–8 control.

**It is generated in COMMAND space and evaluated through the plant.** A fixed 9 × 9 grid of (throttle, turn), each
rolled through `TankMotion` for the control period; the resulting pose, speed and yaw rate *are* the cell. Nothing in
A11 models the plant, so nothing in A11 can drift from it — which is precisely what the `min_cos` chord test does
today, restating the wheeled turning rule a file away from the rule itself.

**Lesson 1 — the creep is a plant reflex that eats commands, and a hand-written inverse cannot see it.** The first
version inverted the plant by hand (pick a speed, solve for the throttle). It was wrong for wheels, because the
multi-point creep hijacks the throttle whenever `|throttle| < WHEEL_CREEP_THROTTLE × |turn|`: the lattice promised
3.53 m/s and the plant delivered 4.30. Evaluating the plant makes that region **honest instead of invisible** — the
creep's legs appear as cells with their real speed and yaw, so a K-turn is one scored option among 81. *Whether
`WHEEL_CREEP_THROTTLE` survives is now a finding rather than a decision*, which is what the brief asked for.

**Lesson 2 — the window is over the CONTROL PERIOD, not over one tick.** A one-tick window offered a tracked hull
starting from zero yaw only `yaw_accel × dt`; held constant over a 2 s arc that is **21° of heading change** when the
hull can swing 160°. Every candidate pointed nearly the same way and level 3 had nothing to choose between.
`DWA_CONTROL_SECONDS` is 0.25 — the brain's own re-plan cadence, and exactly `YAW_RAMP_SECONDS`.

**Measured** (laptop, against the A7-only arm; pristine `9f864474` in brackets):

| | A7 | A7+A11 |
|---|---|---|
| scout standoff: closest / in-band / nose-on / shots | 22.7 / 0.92 / 0.92 / 225 | **25.5 / 0.93 / 0.92 / 227** *(26.9 / 0.92 / 0.91 / 226)* |
| slot drift / shots | 42.1 m / 5 | **38.7 m / 6** *(blend 15.4 / 10)* |
| **turreted duel** | 100% / 100% front hits over 20 s | **67% over 6.3 s** ✗ |

**⚠ CORRECTION (nav, 2026-09-20): the assertion that fails is NOT the front-armour one.** nav first reported this
as *"front hits 67% against a bar of 80%"*. Both halves of that were wrong. The scenario's front-armour bar is
**≥ 50%** and A11 reads **67%**, which passes comfortably — *the check the scenario is named for is fine.* The
failing line is **`and they still fight ([2, 2] shots)`**, a bar of **6** shots.

**And the shot count is low because the duel ENDS AT 6.3 s of a 20 s scenario** — the harness breaks the moment
either tank dies (`_duel`, `scenario_motion.gd:24`). Under A11 the two hulls move markedly more (0.77 / 0.76 against
0.67 / 0.73) and kill each other **three times faster**, so there is no time to fire six rounds.

**So the open question is not "does A11 cost front armour" — it is "why does A11 settle a tank duel three times
faster", and whether that is lethality or blundering.** The scenario cannot answer it: it was built to check that
hulls weave with their fronts on the gun, not to judge how quickly a duel should end. That is the first thing to
look at when A11 resumes, and it needs an instrument that measures the exchange rather than the survival time.

#### ⚠ A7 is built, measured, and NOT shipped on (2026-09-20)

**A7 is opt-in: `--nav-off=a7` turns it ON, and the default is the additive blend.** Everything below it in this
section is built, unit-tested and measured. It is not the default because **the behaviour assertion and the ladder
disagree, and the rule is to believe the behaviour assertion** (lesson 150).

**What fails** — `scenario_elements::test_a_unit_fighting_from_a_formation_slot_stays_in_it`, same tree, A7 against
the blend (laptop):

| | blend (default) | A7 |
|---|---|---|
| in-slot drift | **15.4 m** (bar ≤ 16) | **42.1 m** ✗ |
| free drift | 43.2 m | 62.9 m |
| in-slot shots | **10** (bar ≥ 6) | **5** ✗ |

**What passes:** all six A7 unit tests; all four `scenario_motion` scenarios, including both of combat's
pre-registered ones — the scout standoff (closest 22.7 m, in-band 0.92, nose-on 0.92, 225 shots against the pristine
tree's 26.9 / 0.92 / 0.91 / 226) and the turreted duel that is the armour demotion's falsifier (front hits
**100% / 100%** against the pristine **100% / 80%**); and all five `scenario_elements` scenarios on the default path,
which reproduces the pristine numbers exactly, so the sim baseline does not move.

**The cause, localised by switching each level off in turn rather than guessed: level 2.** With the weapon level
inactive the drift returns to 16.3 m; with level 3 inactive it stays at 37.6 m. **Strict "weapon above formation"
makes a unit hold its band around the enemy, and holding a band around an enemy is what takes it out of the slot it
was given.** The blend let the two compromise; strict priority does not.

**Why this is a contract question and not a tolerance to tune.** The fix for exactly this failure already exists and
was ruled on: state the task region at level 0, so a unit manoeuvres *within* its leash. It does not engage here,
because **`TankBrain.element_slot()` returns null for the `bound` and `maneuver` roles**, and an attacking element's
members are one of those — so there is no leash in the request and no task region for level 0 to state. So the
question for squad is: **should an attacking element's members carry a leash?** Under the blend the answer did not
matter, because `WEIGHTS["range"]` and `continuity` compromised by accident. Under A7 it decides the behaviour.

**Two things this measurement is worth keeping for, whatever squad answers:**

1. **A level that speaks late only gets to rank what the levels above it left.** nav's leash, nav's `_front_share`
   floor and combat's score floor are three instances of the same shape in one day — *the ranked set was already
   destroyed before the ranking ran*. The leash version is the sharpest: no tolerance at level 4 can fix a level-4
   term, because the candidates it wanted were removed at level 2.
2. **Making a cost monotone changes what its tolerance means.** The first monotone `arc` cost kept `TOLERANCE` at
   0.25 and the duel's front hits fell 100% → 75%, because `(1 − dot) / 2` reaches 0.25 at 60° where the floored
   `1 − max(0, dot)` reached it at 41°. The tolerance has to be re-derived with the cost or the level quietly loosens.

#### A6 at level 3, and the one cell feel changed (accepted, 2026-09-20)

feel's [`legibility.md`](legibility.md) confirms level 3 — the law does **not** outrank the standoff band — and asks
for one change to this table, which nav accepts because the argument is right and it is the difference between A6
mattering and A6 being decorative:

> Level 3's null space was written as *"the sign of the arc (either shoulder), and all speed"*. **A6 claims the sign
> of the arc. What level 3 leaves below it is speed alone.**

**Why that is right:** A6's falsifier is measured on **velocity**, not on heading. For a turreted hull the nose is
already free of the gun — the velocity is chosen at levels 1, 2 and 5 and the nose follows it — so **A6-a (the nose
within 25° of the corridor tangent) would pass its own review and leave P7 at 30–36%.** The clause that moves the
number is **A6-b**: when a unit must go off-corridor for the band or for survival and both shoulders serve equally,
take the shoulder that advances along the corridor. A unit orbiting at band radius can orbit either way, and today
that choice is made by `tangent` / `side` / `flank` / `continuity`, **none of which has ever heard of the corridor.**
Round 3's circling is untouched: it is the *shoulder* that is claimed, not the circling.

**The two clauses as explicit rows, so the table is complete before the code** (the orchestrator's request):

| Clause | Level | What it CONSTRAINS | What it LEAVES FREE | Replaces |
|---|---|---|---|---|
| **A6-a** the nose clause | 3 | the hull's **heading**: a turreted hull within **25°** of the corridor tangent `t̂`; a hull-fixed hull bounded **forward-oblique at 75°** (its hull *is* its gun mount) | the whole velocity — which is why this clause alone cannot move the falsifier | **nothing.** The nearest thing was `PENALTY_SIDE_ON` / `ANGLE_MASK_COS`, and A7 already deletes that constant and re-expresses it as level 3's arc task, so A6-a **composes** with the arc task rather than replacing it |
| **A6-b** the shoulder clause | 3 | the **sign of the tangential step** when a unit must go off-corridor for the band or survival and both shoulders serve that equally: take the one whose velocity has a non-negative projection on `t̂` | **speed alone**, and the radial component entirely (level 2 owns that). Round 3's circling is untouched — the *shoulder* is claimed, not the circling | **nothing.** Today the orbit direction is settled by `tangent` / `side` / `flank` / `continuity`, none of which reads the corridor |

**The corridor is N1's `path_points` current leg and nothing recomputed — confirmed against the code, not agreed.**
`Movement.reading()` slices `path_points` from the mover's own `_path_index`, so `path_points[0]` **is** the next
waypoint and the current leg runs from the hull's projection onto it. There is no second leg index to disagree with.

`TOLERANCE["arc"]` stays nav's and A6 wants it **banded, not dictatorial** — prefer the advancing shoulder unless the
retreating one is better at level 3's own cost by more than the tolerance — so nothing is wedged into a worse arc for
a tidy line. Inside level 3, feel's per-style composition applies: `strafe` is A6-a alone (armour is already demoted
to level 5 for turrets by nav's style table), `angle` is armour first with A6-a in its null space, `standoff` is
armour/lay first then A6-a's 75° forward-oblique bound, and `run` is untouched.

**BUILT at `e2fbd1aa`** (opt-in, `--nav-off=a6`), exactly as composed above, with three things worth carrying
forward from writing it:

- **A6-a's cost is monotone OUTSIDE the bound and flat INSIDE it**, and that is the correct shape rather than
  lesson 153's bug. A floor that makes a level rank nothing is the leash defect; a floor that expresses a **bound**
  is what a bound *means*. Candidates meeting the bound tie, and that tie is the null space A6-b then works in.
- **`TOLERANCE["arc"]` is INHERITED, not derived.** A6 reuses level 3's existing 0.125 because nav had no
  measurement to set its own, and inventing one would be a constant chosen before its experiment. It is the first
  thing to measure once the corridor reaches the decision.
- **The law is inert until `request["corridor"]` arrives from `tank_brain.gd`** (squad's file — `choose()` takes a
  request with no unit handle, so nav's velocity layer cannot fetch its own mover's corridor). `a6_no_corridor ==
  a6_asked` in `arm_report()` says so from inside the run.

**And the falsifier is not nav's to compute.** §7: *"Measured with A12 and nothing else"*, because it is a
trajectory-space statistic and one implementation is the point. nav nearly built a second counter for it and
stopped at that sentence. **A12 cannot compute it today**: the trajectory log carries `goal_x/goal_z` but not the
corridor tangent, and §2 rules out the straight line to the goal as the definition — which is wrong in exactly
A6's cases, since a hull rounding a corner has a tangent along the leg while the goal bearing points through a
wall. Requested of metrics as two floats per sample.

**Two assumptions the page makes about this layer, both checked rather than agreed:**

1. **The corridor is N1's `path_points` current leg, one publisher.** True today and better than feel knows:
   `reading()` already slices `path_points` from `_path_index`, so **`path_points[0]` IS the next waypoint and the
   current leg runs from the hull's projection to it.** nav will publish the tangent explicitly (`corridor`) at N5
   rather than leave every consumer to re-derive it from the array — one publisher should mean one *interpretation*,
   not just one array.
2. **An inactive law must not look like a broken one** (lesson 149). nav owns the flag: A6 is inactive with no
   order, on `phase == "blocked"`, with no path yet, while a reflex owns the heading, or under `run`. The falsifier
   is computed over active ticks only with the active fraction reported beside it — a number that improves because
   the law switched itself off more often is not a pass.

**Nothing of A6 is in code, and nothing will be until the page carries all three signatures** (contract S4). A7 ships
level 3 carrying the arc/armour task only; A6 joins that level at N5.

#### ⚠ Composition hazard, for the orchestrator: A7 and A2 both touch `COMMIT_BONUS` this round

This is catalogue Part 2 happening in real time, in two streams, on one constant. **A7 relocates the commitment term
into level 5 without changing its value; combat's A2 replaces the flat bonus with a state-dependent switching cost.**
Those compose only if A2 lands as *the level-5 commitment term's new expression*. If A2 lands as an additional
penalty somewhere else in the same scorer, we get the exact failure Part 2 predicts: two correct techniques, neither
working. **nav's proposal: A2's switching cost IS level 5's commitment term, and nav adopts combat's expression
verbatim rather than keeping a constant beside it.** Sequencing: A7 lands first and leaves the term in one named
place, so A2 has one line to replace. **Adopted as contract S5** (`workstreams.md`), with three integration terms
settled with combat:

1. **nav takes `SwitchingCost.seconds_for()`, not `penalty()`.** The seconds are the portable quantity; combat's
   `PRICE_PER_SECOND = 0.07` and its 0.35 cap are calibrated to the brain scorer's 0..1.2 range and mean nothing in
   nav's level-5 units. nav scales the seconds itself and publishes the exchange rate and the tree it was calibrated
   on.
2. **nav drops combat's stance floor.** combat charges `max(v·(1−cos Δθ), v)` when the *option* changes on one target,
   because ENGAGE / SUPPRESS / ORBIT drive to different places and that floor is the only thing pricing option
   thrash. nav's candidates are **directions**, which already carry their own Δθ, so the floor would charge every
   candidate the full velocity and flatten the ring. nav uses the bare `slew + v·(1−cos Δθ)/braking` with a ceiling.
3. **It stays a price with a ceiling, never a veto** (P3).



#### What nav is asking each reviewer for

- **combat:** does the level order above preserve N5's engagement envelope and L2's suppression behaviour? Two
  specific predictions nav wants challenged: (1) making the dodge **strictly dominant** (level 1, not a −3.0 penalty)
  will break units off under fire more decisively than today; (2) demoting armour to level 5 for turreted hulls is
  right because the turret aims independently — but the scout's engine-deck behaviour (41/23) is exactly the kind of
  thing that dies quietly to a change like that, so **run your two scenarios on nav's A7 commit rather than a copy**.
- **feel:** A6's motion law (S4) is written into **level 3** above. Is a heading constraint at level 3 — above
  formation, below the weapon band — where the legibility contract wants it? If the law should outrank the standoff
  band, say so now: that is a one-line change here and a re-argument after the code exists.

## The layers

```
 squad / control / a brain's hop        "be here"          Movement.request(unit, to, opts)   (or a move_to order)
   └─ OrderController (the composer)    one per unit       orders, reflexes → a TankCommand every tick
        ├─ Movement (game/ai/movement.gd)   nav            route, avoidance, right-of-way, unstick, the N1 reading
        │    ├─ Pathing        A* over the navmesh (NavigationServer3D)
        │    ├─ Avoidance      ORCA over the 6 nearest hulls (game/ai/avoidance.gd)
        │    ├─ right-of-way   ask / give way, peer to peer (in movement.gd)
        │    ├─ Pid            station-keeping on a moving goal (game/ai/pid.gd, gains in control_gains.gd)
        │    └─ Steering       heading error → throttle, turn (tracks; wheels by pure pursuit)
        └─ Gunnery (game/ai/gunnery.gd)     combat         when a gun may speak (N5); apply(cmd, seconds) after Movement
   Tank._drive → TankMotion (the plant) → move_and_slide
```

## N1, the Movement API

| Call | Meaning |
|---|---|
| `Movement.request(unit, to, opts)` | Drive the Tank `unit` to `to`. `opts`: `arrive_radius`, `pace` (0.2..1), `facing`, `priority`, `reverse`, `direct`. Replaces the move order (a `move_to` on its controller); the weapon order is untouched. |
| `Movement.state(unit)` | `{"phase", "eta_s", "remaining_m", "path_points", "blocked_by", "goal", "stalled_s"}`, or `{}` for a hull nothing drives (the player's own tank in `make run`, a client's copy). |
| `Movement.eta(unit, to)` | Seconds to drive there: the navmesh route at `ETA_CRUISE_SHARE` (0.85) of top speed, plus the pivot onto the route at the hull's turn rate. Straight line while the navmesh isn't ready. |
| `Movement.cancel(unit)` | Stop where it stands. |
| `Movement.of(unit)` | The unit's mover (or null) — for code in nav's own paths. |

**Phases.** `arrived` — no move order, or steering has nothing left to do inside the arrive radius. `pathing` — a
route is wanted but the navmesh has not synced yet. `driving` — under way and making progress. `blocked` — no progress
(0.5 m closer along the route than its best) for `BLOCKED_SECONDS` (2 s); `blocked_by` names the cause: **the name of
the nearest hull ahead** within 8 m (friend or enemy), else `"no_path"` when the route ends more than 3 m short of the
goal, else `"terrain"`. `yielding` — giving way to a friend that asked (X4); `blocked_by` and `yield_to` name it.

**The guarantee:** a unit with a destination arrives or reports `blocked` with a reason. It never stands still
silently. Round 5's brains declared a stalled move *complete* from 12 m away (`TankBrain.ORDER_STALL_ARRIVE`); that was
deleted at `c8c7a79d`, measured with `make nav-orders` (a unit "completing" 8 m short in a maze corridor had been the
cause of the one unit that never arrived).

**Determinism.** Everything a decision reads is per tick: stall counts in ticks (`_step` under a controller stride),
`delta` = the fixed tick. The blocker scan walks `tanks_root` in scene order and keeps the nearest, strictly, so ties
go to the first in that order — which is the same on every run of one build. No wall clock.

## Where things live

| File | What |
|---|---|
| `game/ai/movement.gd` | N1, and the per-unit mover: `_next_waypoint` (repath every 1 s or when the goal moves 1 m), `_around_fire` (step round a beaten zone), `_avoid` (ORCA), right-of-way (`_negotiate`, `ask`, `right_of_way`), `_keep_station` (PID), `unstick` (blind reverse), progress and phase. |
| `game/ai/avoidance.gd` | ORCA (RVO2's linear programs, ported), the per-tick neighbour table (grid-hashed, one per tick for the whole match), hull radii. |
| `game/ai/pid.gd`, `game/ai/control_gains.gd` | N6: the regulator and its gains as data (per-faction overrides are X8). |
| `game/ai/order_controller.gd` | The composer: orders, reflexes, the controller stride; one `Movement` and one `Gunnery` per controller. Forwards `stalled_ticks`, `_wheel_radius()`, `FIRE_LOOKAHEAD` (Movement) and `engaged_target`, `watch_point`, `spotter`, `engagement_lay`, `ticks_since_fire`, `lane_blocked_ticks`, `lane_blocker`, `hold_for_friends`, `_nearest_shootable()` (Gunnery) for the brains, bridge, HUD and tests that read them there. |
| `game/ai/gunnery.gd` | **combat's**: the firing rules, split out of the controller at CP4. Reads the controller for `tank`, `tanks_root`, `weapon_order`, `move_order`; handed seconds, not ticks. combat's three wiring tests in `test_combat_envelope.gd` go red if its call is cut (checked at the split). |
| `game/ai/pathing.gd` | `find_path`, `is_ready`. |
| `game/ai/steering.gd` | The P controller for tracks and pure pursuit for wheels. |

## X7: path quality

The hull steers at a **carrot** 5 m (cars: 1.2 turning radii, further if needed, see *Wheels*) along the route beyond
its own projection on it — pure pursuit along the polyline — instead of at raw navmesh corners, so corners are rounded
inside the navmesh's 2 m erosion rather than driven to, pivoted on, and left. While facing more than 60° off the route
it steers at a fixed corner instead (a carrot that slides with the hull never gets turned onto). The route is
re-planned when the goal moves > 1 m, the hull is > 5 m off it, it has stalled for 2 s, or every 4 s as a safety net —
not every second as in round 5: the navmesh is static, so a route only goes stale when the hull or the goal moves.

## X8: factions by their gains

`ControlGains.FACTIONS` overrides the default station-keeping gains per faction (the Condemned are the default): the
Syndicate crisp (kp 1.5, kd 0.9), the gangs loose (kp 0.45, kd 0.05), the Law damped (kp 0.7, kd 1.2). The mover
builds its regulator from the unit's faction. A goal re-issued unchanged after 0.35 s means the slot stopped, and
feed-forward stops with it (before that fix every crew overshot a halting slot by ~3.2 m).

## Measuring

`make nav-suite` runs arena's probe over arenas × sizes × traffic in parallel; `make nav-where` is one run that also
names every unit that didn't arrive, where it is and what its Movement says; `make nav-orders` is the lead's own test
WITH BRAINS (5 player squads ordered across one another through control's Orders), recording when each order
completes and how far from its goal the unit really was. `--nav-off=…` switches single mechanisms off for an A/B
(grace, minpace, pushidle, carrot, yield, unstick, repath; `r5sidestep` turns round 5's sidestep back on).

### The measuring switches, and what each one proves

**An unknown name is refused** (`Movement.OFF_NAMES`, round 8): a switch nothing reads switches nothing off, and the
A/B then comes back a clean null with a correct-looking arm header. arena hit that with `flow` on a tree that did not
have it. Add the name to `OFF_NAMES` in the commit that adds the switch.

`--nav-off=a,b` on any run (`make nav-where NAV_FLAGS=--nav-off=…`; in a test, set `Movement._off`,
`Movement.avoidance_on`, `Movement.station_on` directly and restore them). Each isolates one decision:

| switch | turns off | what an A/B with it answers |
|---|---|---|

| `--no-avoidance` | ORCA (X3) | how much arrival and flow come from avoidance at all |
| `--no-station-pid` | PID station-keeping (X6) | P-law chase vs regulated slot (0.35 vs 4.58 m, `test_station_keeping`) |
| `grace` | the 10-tick K1 start window | whether K1's 3-tick response depends on it (it does: control's response test) |
| `minpace` | the 15% creep floor in that window | tail cost of creeping (on outside the window: head-on maze t100 182 → 163 s) |
| `pushidle` | asking a parked friend at once | whether pushing idle units helps (180 vs 182 s: marginal) |
| `yield` | right-of-way (X4) entirely | how much of a jam resolves by negotiation |
| `unstick` | the "room behind" check (old blind reverse) | whether ramming friends in columns matters |
| `repath` | X7's re-plan policy (back to every 1 s) | cost/benefit of re-planning |
| `carrot` | X7's pure-pursuit carrot (round 5's exact corner-following) | path smoothing's effect |
| `standoff` / `commit` | round 7's standoff style / CombatMotion commitment | fixed-gun behaviour; re-aim churn (read live from `NAV_FIGHT_ARM`) |
| `holdband` | **turns ON** round 8's standoff-hold hysteresis (HOLD_SLACK_M, hit-only break; off by default: its A/B missed) | whether hold ↔ move flips are the wheeled "yaw in place" |
| `r5sidestep` | **turns ON** round 5's single-friend sidestep | the one thing X3 REMOVED; it alone restored squad's near-ambush timing (555 → 531 ticks) |

**Two traps, both hit this round — read before trusting an A/B:**
1. **A switch that silently does nothing gives you "no difference" for free.** The first `carrot` switch returned the
   wrong point (0/60 arrived — broken), and an equal result from a switch you haven't seen change *anything* proves
   nothing. Check each switch moves some number before reading an equal result as "not this mechanism".
2. **The moment a nav commit is merged, `main` stops being your control.** I told the orchestrator a failure "happens
   on main too, so it isn't nav" — main already contained my merge. Bisect on named commits (`00c99bf4` before nav,
   `7cce78af` nav's merge), never on "main vs my branch". And the cause turned out to be something *removed*, which no
   switch of added mechanisms can find — hence `r5sidestep`.

`make nav-maze` (arena's, `tests/arena/maze_probe.gd`) is the acceptance instrument: it only watches positions, so it
keeps meaning the same thing whatever nav rewrites. Note it drives plain `OrderController`s, not brains — round 5's
`_around_friends` never ran in it.

## X3: avoidance (ORCA)

Each tick a moving unit wants a velocity: toward its next waypoint at its order's speed, easing off near the end.
`Avoidance.solve` returns the velocity closest to that which keeps clear of its 6 nearest hulls (within 14 m, ordered
by distance then name) for a 2 s horizon, assuming each mover does half the avoiding and a parked unit none. That
velocity is steered at (a point 3–8 m along it) with the throttle scaled by its speed. An avoiding velocity that would
put the hull off the navmesh 3 m ahead is refused: the unit keeps its route and slows instead. Enemies are in the
neighbour set too. Hull radius = mean of half-width and half-length + 0.25 m. Two hulls on one spot part by name.

**K1 comes first.** The player's response guarantee is 100 ms = 3 ticks with nothing spare, and avoidance must not
spend it: for `AVOID_GRACE_TICKS` (10) after a new destination the hull steers along its route and avoidance only sets
its throttle, and a way on that is crowded but not reversed is still driven at `AVOID_MIN_PACE` (15%) at least, so
a new order always visibly starts. (Found by control's response test at 4 ticks; the orchestrator ruled 3 is a hard
constraint, not a target.) A goal that jumps > 3 m counts as a new destination; a slot sliding along does not.

**Wheels.** A car's steering point — route carrot or avoiding point — must be one it can drive *forward* onto,
outside both turning circles; a point inside one is a three-point turn. The carrot walks further along the route (up
to 4 turning radii) until it is; an avoiding point that isn't is dropped for the route. (Found by control's click test:
an IFV with a 1.2-radius carrot three-point-turned for a second on a 40° bend.)

Tanks are not holonomic, so ORCA's "take this velocity now" is only approximately achievable; in practice the hulls
turn fast enough (80°/s) that it resolves. **Do not** read the chosen velocity as a physics guarantee — hulls still
collide through `move_and_slide`, and that is intended (vehicles are vehicles).

## The engine's `NavigationAgent3D` avoidance against ours (nav, round 9, stretch) — COMPARED, NOT SWAPPED

[`algorithms.md`](algorithms.md) has carried an open instruction since 2026-09-19: *"Do not swap without measuring
both — but do not leave the comparison unmade either."* This is the comparison. **Verdict: keep ours. Revisit only on
a profile that shows ORCA dominating the tick, which is not the profile we have.**

**The surface, probed from `ClassDB` on our pinned Godot 4.7.2, not read from docs:** `NavigationAgent3D` has
`avoidance_enabled`, `radius`, `height`, `neighbor_distance`, `max_neighbors`, `time_horizon_agents`,
`time_horizon_obstacles`, `max_speed`, `velocity`, `avoidance_layers`, `avoidance_mask`, `avoidance_priority` and
`use_3d_avoidance`; `NavigationServer3D` exposes the same as `agent_*` calls plus `agent_set_avoidance_callback` and
`agent_set_velocity_forced`. The computed velocity comes back through the **`velocity_computed` signal** (the node's
`_avoidance_done` callback), not as a return value.

**The algorithm is not the difference.** Godot's avoidance is RVO2 internally and `game/ai/avoidance.gd` is a port of
RVO2's linear programs. Choosing between them is an *integration* question, not a quality one, and that is what makes
the five differences below decisive rather than a matter of taste.

| | ours (`avoidance.gd`) | the engine's |
|---|---|---|
| **When the velocity arrives** | synchronously, inside the mover's own tick | **asynchronously**, via `velocity_computed` after the server's sync |
| **Reciprocity** | 0.5, and **a parked neighbour takes none, so the mover takes all** | 0.5, with `avoidance_priority` as a scalar override |
| **Navmesh awareness** | an avoiding velocity that would put the hull off the mesh 3 m ahead is **refused**; the unit keeps its route and slows | none — RVO2 agents avoid agents and `NavigationObstacle3D`s, not mesh boundaries |
| **K1 (the 100 ms response guarantee)** | `AVOID_GRACE_TICKS` 10: avoidance sets throttle only, and `AVOID_MIN_PACE` keeps a crowded way on moving at 15% | no equivalent; it returns a velocity |
| **Right-of-way (X4)** | peer-to-peer negotiation: yield spots on the navmesh, debts, refusals, a player order cancelling a give-way | `avoidance_priority`, a static scalar |

**The three that decide it:**

1. **The asynchronous delivery breaks an invariant we rely on.** Every controller runs before any tank moves, so all
   of them see one tick's positions — that is why `Avoidance.refresh()` can build one neighbour table per tick for the
   whole match and why the result is deterministic by construction. A velocity that arrives on a signal after the
   server's sync is a velocity from the *previous* state, and lockstep multiplayer and the sim baseline both depend on
   this not being true.
2. **`avoidance_priority` is coarser than the knob we already know we need.** Catalogue **C4** — proposed
   independently by both external reviews — wants inertia weighting `α = Iⱼ/(Iᵢ+Iⱼ)`, a **per-pair** responsibility
   split, because a 50/50 split is wrong across a 5× footprint range and CP2 is about to make that range wider. The
   engine exposes one scalar per agent. Swapping would move us *away* from the row we intend to adopt.
3. **We would keep most of our integration anyway.** The navmesh refusal, the K1 grace, the minimum pace and X4 are
   all ours and none of them has an engine counterpart, so the swap buys a C++ inner loop and keeps the wrapper.

**And the thing the swap would buy is not a bottleneck.** ORCA, right-of-way and the carrot together cost **+0.57 ms
per tick** at 60 brains (builder0, `1923059c`, `make ai-perf --profile-parts`; `move` 1119 → 1688 µs). The frame-rate
fight was won in round 5, and round 9's own T1 finding is that a `check` on builder0 is one single-threaded process at
~7% CPU — we are latency-bound, not compute-bound. **Buying CPU we are not short of, at the price of determinism, the
navmesh refusal and K1, is a bad trade in a game whose measured problem is the *shape* of the motion.**

**What would change the verdict:** a profile in which ORCA dominates the tick at the unit counts the lead plays; or
the engine gaining a per-pair responsibility weight. Neither is true at `7edec4fb`. **`NavigationObstacle3D`,
`NavigationLink3D` and `PATH_METADATA_INCLUDE_*` remain genuinely worth having and are unaffected by this** — the
verdict is about the avoidance solver only.

## X4: right-of-way

A unit that has made no progress for 1 s names the hull ahead of it (within 8 m, ±60°). If it is a friend with a mover:
a unit going nowhere always gives way to one going somewhere; between two movers the one with the shorter remaining
route gives way; the name breaks a tie; and a unit that gave way to me last time is owed the favour back. The one that
gives way searches `YIELD_SPOTS` (to the side of the asker's line it is already on first, then the far side, then
leading the way out ahead) for a point on the navmesh, clear of the asker's line by both radii + 0.75 m, and 3.5 m from
every other hull. It drives there, holds at least 1 s, and resumes its own order once the asker is past or 9 m away
(at most 6 s). A player's new order cancels giving way at once. It never gives way twice in a row to the same unit.
A mover that avoidance is holding below half speed behind a *parked* friend asks it at once, without waiting for a
stall (StarCraft's "idle units get pushed aside"). A yield spot never lies closer to the asker than the yielder
already is (backing into the unit you are letting past is how two units end up nose to tail), and a car's spot must
be forward-reachable. The unstick routine no longer reverses blind: it backs off only with 2 m of room behind it.
The asking is a direct call on the other unit's mover (`ask(asker, from, direction)` → accepted or not); refused asks
make the asker give way itself.

## X6: station-keeping (N6)

A `move_to` whose goal is moving (estimated from how far it moved between re-issues; > 0.5 m/s; stale after 1 s)
and is within 14 m, on the last leg, is regulated: throttle = (goal speed along my heading + PID on the along-track
gap) / top speed, steering at where the goal will be in 0.6 s. The PID's derivative acts on the gap's own rate (my
speed relative to the goal's), so a slot that jumps doesn't kick. `--no-station-pid` and `--no-avoidance` are the
measuring switches (read once from the command line).

## Measurements

| When | Machine | What | Result |
|---|---|---|---|
| `30e3250d` (= round-5 behaviour) | builder0 | `make nav-suite`, hold-fire, 180 s | arrived: maze-30 15/30, maze-60 35/60, maze-60 head-on **0/60**, yard-60 34/60, yard-60 head-on 33/60, foundry-60 40/60 (`references/nav/nav_suite_30e3250d_baseline.json`). Five seeds were identical: the probe has no randomness. |
| `e291a35a` (X3+X4+X6) | builder0 | same | **60/60 everywhere, 30/30 on maze-30**; t90 maze-60 129 s, head-on 145 s, yard 47 s, foundry 38 s |
| `e291a35a` | builder0 | `test_station_keeping` | a slot at 5 m/s: mean gap 0.35 m (PID) vs 4.58 m (P law) |

| `30e3250d` vs `1923059c` | builder0 | `make ai-perf` (60 brains fighting, `--profile-parts`) | `move` part 1119 → **1688 usec per tick** (+0.57 ms: ORCA, right-of-way, carrot); AI band per living unit 150.4 → 165.9 usec. Different battles (21 vs 19 alive at the end), so the per-part number is the comparable one. |
| `1923059c` | builder0 | `make nav-suite` | 60/60 on maze-60 (t90 120 s), maze-60 head-on (144 s), yard-60 (55 s), yard-60 head-on (42 s), foundry-60 (40 s); maze-30 30/30 (74 s) |

The probe spawns 60 units on 52 spawn points, so 8 pairs start on top of each other; at `30e3250d` those pairs never
moved at all. That is part of the baseline's failure, and a real case (respawns can overlap too).
