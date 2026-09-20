# Stream: combat (seeing an enemy is not the same as opening fire)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *Units*, *Match rules*), [../workstreams.md](../workstreams.md) (you own **N5**, **K2**,
> **K3** data, **L2**, **L3**, **C1–C4**), [../balance.md](../balance.md), and your round-5 report in
> [archive/round5/combat.md](archive/round5/combat.md) with its saved results in
> [references/combat/](references/combat/).
>
> **You own** `game/units/`, `game/combat/`, `game/match/`, `game/ai/doctrine.gd` (the army-JSON loader, C2), `game/tank/` **except `tank_motion.gd`** (that moves to nav
> this round: it is the plant nav's controller regulates; its *data fields* stay yours),
> `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`.

## The lead's direction (2026-09-18, verbatim)

> *"The long range of the weapons is also I think making the game unplayable (units see each other and then everyone
> just starts firing)."*

He said a version of this in round 5 too (*"I can't tell if perhaps the vehicles have too much range, but when I play
the game now it's just these 2 masses shooting at each other"*). It did not land. **It is this round's CP4, it lands
once, and it lands early.**

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

**The mechanism behind his sentence is real and it is one line.** `OrderController._shootable()`
(`order_controller.gd:734-747`) admits a target if it is *inside the weapon's range and has a clear physics line of
sight* — and the comment there records that the `seen` (spotted) test was found unused and **removed**. So a gun does
not require the contact to be acquired, tracked, or even spotted. There is no acquisition step between "exists on the
other side of the map with nothing in the way" and "shoot at it". The trigger is
`cmd.fire = _clear_to_fire(in_range and aimed and tank.ready_to_fire(), aim)` (`:710`).

The second half is that **`effective_range` equals `range` for every core weapon**, so there is no band where a shot
is legal but bad:

| weapon | range | effective | preferred band | damage | reload |
|---|---|---|---|---|---|
| `cannon` | 70 | 70 | 20–45 | 320 | 5.0 s |
| `autocannon` | 60 | 60 | 15–45 | 15×4 | 1.8 s |
| `laser` | 90 | 90 | 76–86 | 22 | 0.5 s |
| `machine_gun` | 45 | 45 | 12–35 | 3.5 @10/s | 0.1 s |
| `mortar` | 160 (min 42) | — | 60–140 | 140, splash 9 | 4.5 s |
| `flamethrower` | 20 (cone 30°) | — | 6–16 | 55 dps | — |

Faction weapons reach further still (`guided_missiles` 170, `gas_rockets` 150, `catapult` 120, `railgun` 110).

Sight radii (`units.gd`) run 55–135 m: tank **62**, scout 110, law_scout 125, syn_scout 135, syn_tank 105.
`Match.SENSOR_RANGE` is the tank's 62 m; contacts are remembered 12 s. Suppression cuts sight 40%.
Accuracy already degrades with range (`RANGE_SPREAD_FACTOR 3.0`, `MOVING_SPREAD_FACTOR 1.5`) — it is not enough to
stop anyone shooting.

**The measured consequence:** median hit range 39–43 m on *every* arena regardless of terrain, and flanking routes
using 4–5% of unit-time. The fight is decided at first contact, everywhere, always.

## Backlog (in order)

**X1 — the engagement envelope (N5, CP4). Do this first and land it once.** Make seeing and shooting two different
things:
- **Acquisition is a real step.** A weapon may only engage a target the unit has *acquired* — spotted (or handed a
  contact by a spotter), tracked for some time, still remembered. Put the `seen` test back, deliberately and with a
  design behind it, and give acquisition a duration so a contact at the edge of sight is not instantly a target.
- **An effective band that means something.** `effective_range` becomes genuinely shorter than `range`: beyond it a
  shot is legal but unrewarding (spread, penetration falloff), and the AI's own rule prefers to close. The
  recommendation is a real gap — effective around 55–65% of maximum for direct-fire weapons — but **measure rather
  than accept that number.**
- **Fire discipline.** A unit should not open up on the first thing it can technically reach. Hold fire until inside
  effective range unless ordered otherwise, or unless the target is worth a long shot.
Then measure the before/after on the configuration players actually get (faction armies, 30 a side, control point on,
default flags): median hit range, time to first shot, time to first kill, match duration, flanking-route unit-time,
and the faction win matrix. **Report the sample size** and name the commit and machine (lesson 26 exists because a
number went to the lead that was 18 shells).

**Tell the orchestrator the day X1 merges.** Every other stream re-runs its measurements after it, and nobody may
publish a number that straddles it.

**X2 — closing has to be survivable.** If you shorten engagement without changing anything else, the side that closes
dies on the way in and the game becomes "hold the longest stick". Check, and fix what you find: cover actually blocks
(arena's props), suppression actually buys movement (L2 — it was built for exactly this), smoke or speed or armour
gives an approach a chance, and the round-5 `break_contact` finding (doctrine went 91-29 without it) is not being
re-created by the new ranges.

**X3 — the arena is sized for the old ranges.** Half-size 121 m with 70 m cannons means two spawns are barely two
engagements apart. Once X1 lands, check with arena whether the map scale still fits, and say so with numbers rather
than leaving it implied.

**X4 — the gangs' 23%.** Still open from round 4, twice deferred. Road gangs win 23% against Condemned 70%, Law 63%,
Syndicate 47% (5 seeds, pre-Jolt, pre-30 Hz, pre-everything — **re-measure before tuning anything**). Two real defects
were fixed and neither moved it. With engagement ranges changing under it, re-run `make faction-matrix SEEDS=5
TIME=150` *after* X1 and treat the old number as history.

**X5 — the duplicated Lancer.** The Condemned `lancer` and the Syndicate `syn_lancer` share a role; the lead was asked
and hasn't ruled. Propose which faction loses it, with the roster reasoning, and put it in your Status for the
orchestrator to relay.

**X6 — the scout's counter.** `good_vs` claims must be real in the mechanics; `scout > lancer` still has no mechanic
behind it. Give it one or remove the claim (ai asked for this in round 4; it is still owed).

**X7 (stretch) — weak spots and armour facing, now that closing matters.** Flanking is only worth the risk if a rear
or side hit pays. Check that `Armor.penetration_multiplier` and the weak-spot rules are doing visible work at the new
ranges, and make the payoff legible (feel draws the cue; you provide the event).

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make faction-matrix`, `tools/match_series.py`, `make matches`, `combat_duel.py` — always in the players'
  configuration, always with the sample size stated.
- **Play it** (`make skirmish`) and ask the lead's question: does a fight start at a distance where anything but
  shooting is still possible?
- `make determinism` and the sim baseline: **yours to move, on purpose**, with the reason in the same commit
  (`make remote T=sim-baseline-record` on builder0, twice, to confirm it repeats).
- Balance numbers are spread across `weapons.gd` (damage, reload, range, spread), `tank.gd` (`max_health`) and
  `match.gd` (`SENSOR_RANGE`, arena size) — trip-up 33. Re-measure pace and re-run the fairness control after any of
  them.

## Don't touch

`game/ai/**` (nav's and squad's) **except `game/ai/gunnery.gd`, which becomes yours**: nav's X1 splits
`order_controller.gd` into movement (theirs) and gunnery (yours) so the firing decision lives with the stream that
owns the firing rule. Until that split lands, ask nav for the edit rather than making it — and agree the seam in
writing first. Also: `game/control/` `game/ui/` `game/camera/` (control's), `arenas/` `game/arena/` (arena's),
`game/theme/**` (feel's), `game/tank/tank_motion.gd` (nav's).

## Waiting on the lead

1. **The Lancer** (X5): which faction keeps it. Not blocking — propose and continue.

## Status

_Round 6, opened 2026-09-18. Branch `stream/combat`, from `a975e262`._

### `ENGAGE hop` — the cadence question, and a falsifiable prediction (thinking only, 2026-09-19)

arena measured **30–36% of `attack_move` time spent driving somewhere other than the order**, `blocked_terrain`
0.000–0.010, and **about three quarters of the re-tasking is `ENGAGE hop`** — the same option re-aiming, a
destination change **every ~1.3 s**. nav is measuring whether that produces visible oscillation (pre-registered:
≥5% of under-way time on any of his maps = real, <1% on all four = not). **Nothing is built until that lands.**

**The design question is genuinely combat's, and N5 already answers most of it.** `attack_move` means *fight your
way there*, so re-aiming is obedience, not disobedience — the defect, if there is one, is **cadence**. And the
engagement envelope already defines the only principled floor: **a crew that switches target restarts acquisition**
(`Lay.engage` zeroes `progress` on a new target), and acquisition costs **0.3 s at arm's length to 1.6 s at the
edge of vision**, ×0.55 for a scout, ×2 under suppression. So:

> **Re-targeting faster than `acquire_seconds` cannot produce fire. It can only produce motion.**

At ~1.3 s between hops, a crew at anything past close range never finishes a lay. **The brain is issuing orders the
gunner cannot cash.**

**THE PREDICTION, which makes this falsifiable before anyone writes code.** If `ENGAGE hop` is real churn rather
than obedience, then under `attack_move` the re-task rate and the *fire* rate must move in opposite directions:
**`shots_per_unit_minute` should be depressed while re-tasking is high**, and units should show a high ratio of
*time held on a contact* to *shots taken*. If instead fire rate is healthy at 45 re-aims a unit-minute, the hops are
tracking a genuinely changing picture and the right answer is to leave it alone. **Both metrics already exist**
(`make engagement`, `shots_per_unit_minute` from round 6) so this costs a run, not a feature.

**If it is real, the fix I would propose** — and it is a consequence of the envelope rather than a new tuning knob:
a brain under a player's order **holds a chosen target for at least the time it would take to acquire and fire it**,
breaking early only when the target dies, leaves line of sight, or is displaced by a contact better by some margin
(the same hysteresis shape as `RELEASE_FACTOR`). That makes the cadence fall out of `acquire_seconds` per unit and
per range — a scout re-aims quickly because it acquires quickly — instead of adding a constant nobody can defend.

**It touches squad** (the brain chooses) **and combat** (the envelope says what a choice costs), so it is a contract
conversation before it is code.

### PRE-REGISTERED: is the `gangs vs law` collapse the rig getting STUCK? (2026-09-19, before the run)

**Written before the measurement, so it can fail.** nav's bare-ground control settled what the rig's pivot metric
actually is: on an empty arena **every hull length reads 7° and 6.7 m of wander, identical to the decimetre**; on
`yard` the same three lengths read 7° / 23° / 26° with wander *falling* 5.5 → 3.9 → 3.5 m. **A long rig does not
pivot. It catches on scenery a short one cleared, and keeps yawing while it is stuck.** (My prediction, nav's run;
their first mechanism could not be right because `hull_size` never reaches `TankMotion`.)

**That is a candidate for the other open thread.** `gangs vs law` went 9/20 → 0/20 with the 14 m rig, and the two
explanations on the table were *bigger target for splash/suppression* and *the wheeled creep*. **There is now a
third, and it is better than both: a vehicle jammed on terrain is a stationary target, and law is the faction
built to punish anything that stops moving** — the suppression on the loser in both law matchups was the highest
figure in the whole table (0.077, 0.078) with gang losses near-total (40.0, 40.7 of 43).

**THE PREDICTION.** `make engagement PAIRS=gangs:law ARENA=yard`, the 14 m rig against the 5.6 m control, same
machine, same seeds, build declared as the arm:

- **If the rig is getting stuck:** the gangs' **`static_share` rises materially** with the 14 m rig. That is the
  share of unit-time spent stationary, and a jammed vehicle is stationary by definition.
- **If it is the bigger-target story instead:** `static_share` is flat and the damage shows up in losses and
  suppression without the gangs standing still any more than before.
- **If `static_share` falls or is unchanged while the matchup still collapses**, all three explanations are wrong
  and I have no mechanism — which is a result I would rather publish than paper over.

**Why this is worth a run rather than an opinion:** the three candidates predict the *same* aggregate (the gangs
lose badly to law) and differ on one cheap metric that already exists. **Nobody has to build anything.**

**⚠ AMENDED, WITH DISCLOSURE: `static_share` CANNOT ANSWER THIS, and I had seen one number before I amended it.**

`EngagementStats` computes it as `speeds[0] < STILL_SPEED and speeds[1] < STILL_SPEED` with `STILL_SPEED = 1.5`
m/s — **mean SPEED, not displacement, and it requires BOTH TEAMS to be slow at once.** nav's tick dump of the
creeping rig reads 3.50, 0.47, 3.10, 0.80 m/s: **a rig shuffling on the spot is never "still" by this definition**,
and a metric about the whole fight being static cannot report that one army is going nowhere. My prediction was
unfalsifiable in the direction that mattered: the "stuck" arm would have shown a flat `static_share` **whether or
not the rig was stuck**, and I would have read that as evidence against it.

**The honest order of events:** nav warned me the metric might be speed-based *before* the run reported; I checked
`engagement_stats.gd` and confirmed it; **and then the 14 m arm printed `static 0%` while I was writing this up.**
So I had seen the treatment figure before the amendment was committed, though the reasoning that voids the metric
preceded it and came from someone else. **Recorded rather than tidied, because "I changed the prediction after
seeing the number" is exactly the shape that needs the timeline attached.**

**THE REPLACEMENT PREDICTION**, which the existing metrics can actually test. The signature of shuffling is
**moving fast while getting nowhere**, so it lives in the gap between speed and displacement:

- **stuck/shuffling:** `moved` (`centroid_travel_m`) and `push` (`net_advance_m`) fall materially with the 14 m rig
  **while fire rate and engaged distance hold up** — an army that is fighting but not travelling.
- **bigger target:** `moved` and `push` hold; the damage shows in losses, suppression and kill distance.
- **neither:** nothing moves but the matchup still collapses, and I have no mechanism and will say so.

**14 m arm (builder0, `b16b8d78`, gangs:law on yard, n=6):** len 109 s, first shot 5 s, **fire 24.8/unit/min**,
contact @108 m, engaged 42 m, kill 24 m, **static 0%**, held-line 12%, **moved 220 m**, **push 98 m**, off-axis
kills 57%, flank+rear 62%, cover time 31%. The 5.6 m control is running on the same seeds and machine.

### THE 14 m RIG'S COST: one matchup, not one faction (2026-09-19)

Treatment vs the baseline taken with the rig reverted, both maps, `make compare-arms` with the build declared as
the arm, positive control engaged in all four runs. **Per matchup, because per faction hides it:**

| map | arm | gangs vs condemned | **vs law** | vs syndicate | gangs overall |
|---|---|---|---|---|---|
| yard | baseline | 60% | **60%** | 70% | 63% |
| yard | **rig 14 m** | 40% | **0%** | 40% | **27%** |
| pit | baseline | 20% | **30%** | 40% | 30% |
| pit | **rig 14 m** | 50% | **0%** | 40% | **30%** |

**THE FINDING: `gangs vs law` went from 9/20 to 0/20 across both maps.** Twenty counterbalanced matches, no wins,
two-sided p ≈ **2×10⁻⁶**. Nothing else survives both maps — vs condemned the rig *helps* on pit (+30) and hurts on
yard (−20), which is what a map-dependent nothing looks like.

**AND POOLING HID IT COMPLETELY ON PIT.** The gangs' overall rate there is **30% in both arms** — a flat zero —
because losing the law matchup outright was offset by gaining the condemned one. A per-faction table says "no
effect on pit"; the per-matchup table says one matchup became unwinnable. **The yard headline I first reported
(−37 points to the gangs) is the same effect seen through a pooled number, and it understates what happened on
one matchup while inventing a size that does not generalise.** Read matchups, not factions.

**Mechanism, stated as a hypothesis with the evidence it rests on:** law is the suppression faction (Sonic Emitter,
Gas Rocket Truck). In both maps' law matchups the suppression on the loser is the **highest figure in the table**
(0.077 yard, 0.078 pit) and gang losses are near-total (**40.0 and 40.7 of 43 vehicles**). A 14 m hull is a far
larger target for splash and for the near-miss rounds that drive suppression. **Not established** — the rival
explanation is the wheeled creep (`TankMotion`'s designed multi-point turn: alternating 0.5 s forward/reverse legs
whenever throttle falls below `WHEEL_CREEP_THROTTLE × |turn|`), which a big hull in a packed formation meets far
more often, and a unit shuffling under fire dies without needing to be a bigger target. **The two differ at the
trajectory level, which nav's counters can already measure.**

**Nobody is proposing to shrink the truck over this.** The lead asked for it three times; feel measured 14 m as the
length that reads *huge* (281 px against a tank's 95) and **12 m as the length that first reads unmistakably as a
semi** (242 px) — so 12 m is a real option if someone wants to buy part of the cost back, and that is the lead's
call against his own word "huge", not mine.

### THE BALANCE PICTURE ON THE MAPS HE ACTUALLY PLAYS (2026-09-19)

**Every faction number this project has ever quoted was measured on `foundry`** — a square, one central objective,
`centre_sees_share` 0.56, **and a map the lead cut.** `Arena.ROTATION` became `["yard", "pit"]` at `474abf53`, and
both are now **hexagons at the 140 m bound with off-centre mirrored objective pairs** (decision spread 0.43 and
0.42, where every map read 0.00 two days ago). So these are the first faction numbers taken on the ground the
player stands on. builder0, n=30 per faction per map, SEEDS=5, the positive control engaged in both runs.

| faction | yard | pit | swing | significant? |
|---|---|---|---|---|
| **gangs** | **63%** | **30%** | **+33 pts (2.6 SE)** | **YES** |
| condemned | 50% | 70% | −20 (1.6 SE) | no |
| law | 43% | 43% | 0 | no |
| syndicate | 43% | 57% | −13 (1.0 SE) | no |

**THE FINDING IS THAT THE MAPS DISAGREE MORE THAN THE FACTIONS DO.** The gangs' 33-point swing between the two
maps he plays is **the only difference in the whole table that clears the noise** — at n=30 a gap needs 25 points,
and every within-map spread is under it. The gangs are the strongest army on one of his two maps and the weakest
on the other, by the largest margin anyone has measured.

**What this licenses:** nothing about faction strength as a property. *"The gangs are strong"* and *"the gangs are
weak"* are both supportable from this table by choosing a map, which is exactly the error that cost two rounds and
retired the 23% → 53% numbers. **A faction win rate without a map is not a number.**

**What it does NOT license, and I am saying so before anyone reads it harder than it can bear:** no within-map
difference here is significant. Gangs 63% on yard has a 95% CI of **45–81%**; condemned 70% on pit is **52–88%**.
Resolving a 20-point within-map gap needs **n≈48 (SEEDS=8)**, about 60% more builder0 time per map.

**Do not tune any of this.** The lead has deferred balance explicitly (*"we'll worry about evening up factions
later"*). This is the baseline the 14 m rig gets measured against once squad's deployment fix lands, and the reason
it was taken **with the rig reverted** (`44d87a28`, restored immediately after): an army deploying with 0.4 m gaps
is not a balance baseline.

**Both runs are comparable:** `git diff --name-only 44d87a28 d24f2ea1` is one markdown file. Checked rather than
assumed, because the two `run:` headers name different commits and that is exactly what a mismatched comparison
looks like from the outside.

### ROUND 8 (2026-09-19) — the semi, and the bug found on the way to it

**The lead, third time of asking:** *"the gang tanks are still tiny (the intent for the semi trucks is that they're
huge - we'll worry about evening up factions later)"*. **Balance is explicitly deferred on this: measure what the
size does and report it, do not tune against it.**

**Why 3.14× the scout still read as tiny — two causes, neither of them the number I picked.**

1. **We grew it on the axis the camera hides.** War Rig `[3.0 w, 4.4 h, 5.6 l]`: height 3.14× the gang scout
   (inside the "3 or 4 times" he named in round 6) but footprint only 1.95× a tank's, and a top-down camera
   foreshortens height and shows footprint.
2. **Worse: the height was never drawn.** feel fits art by LENGTH so the approved model is never distorted, so a
   4.4 m box drew a **2.09 m** truck. At the lead's pose the rig renders **114 px tall against a Condemned tank's
   95** — the "huge" semi is barely taller on screen than a regular tank. **The catalog number I was free to
   choose was height, and I chose it well; the axis that carried the intent was not mine and was not drawn.**

**feel's number, measured at the lead's camera: `gang_tank` `[3.32, 5.24, 14.0]`** (281 px, ~3× a tank) and
**`gang_support` `[3.39, 3.59, 7.0]`**. Its full box-vs-mesh table is in the round-8 messages; **every art-bearing
unit's collider disagrees with its mesh**, worst `gang_tank` (+1.67 w, +2.31 h — shells that visibly clear the roof
hit it) and `law_suppressor` **inverted** (drawn 0.96 m taller than its box — visible hits pass through). That is a
hit-registration bug, not a look bug, and `hull_size` IS the collider (C1). The orchestrator has ruled it in scope.

**WHERE IT STANDS (2026-09-19, branch at `2141904b`, `main` merged at the `85c774d0` checkpoint).**

**The sizes are landed and the branch is NOT mergeable on that commit.** `gang_tank` `[3.32, 5.24, 14.0]` and
`gang_support` `[3.39, 3.59, 7.0]` are in; the army could not stand in them; squad has fixed the cause on
`stream/squad` at **`9a736f15`**. Sequence from here: squad lands on `main` → orchestrator announces → **merge, then
re-run `make test FILTER=army_footprint` with the rig as landed**, and only if it is clean, ping feel to re-shoot at
the lead's camera and report the per-map effect **without tuning it** (balance is deferred by the lead, deployment
is not).

| gang_ram, laptop seed 1 @5200 | vehicles | min | median |
|---|---|---|---|
| merged tree, before the size change | 41 | 3.7 m | 6.8 m |
| **with the 14 m rig** | 41 | **0.4 m** | 2.7 m |
| squad's fix + these sizes (squad's tree) | 41 | **4.3 m, 0 overlaps** | — |

**My diagnosis of that regression was WRONG and squad's is right — worth keeping because of the shape.** I reported
*"inter-squad placement does not keep up"* and reasoned about `GAP_SPACINGS`. The real causes: **ranks stacked by
slot-centre depth while a 14 m hull overhangs 7 m each way**, and **ranks clamped at the drivable back edge stacking
onto each other** (that was the 0.4 m cross-squad pair at z≈114). Neither is about gaps between squads. **The named
pair was data and it was useful; the mechanism was a guess wearing its confidence**, and it would have sent squad to
the wrong function. What I should have sent was the pair, the z, and *"I do not know why yet"*.

**And the guard lesson, which cost nothing only because squad was more demanding than me:** I left the gang_ram
assertion out of my own probe and printed it as a `MEASURE` line, for the good reason that the bar was not mine to
set. The effect was that **the regression I introduced passed my own test** and I caught it by reading a number.
squad asserted on gang_ram, gang_pack and law_line when it landed the file, and its version would have failed
immediately. **The stream that owns the thing being guarded should own the assertion, because it is the one that
will set the bar high enough to fail.**

**⚠ THE SPAWN GRID DOES NOT CONSTRAIN VEHICLE SIZE, AND I SPENT an hour believing it did.** `SPAWN_ROW_SPACING`
(8.0) − 2×`SPAWN_JITTER_MAX_Z` (1.2) = **exactly 5.6**, the War Rig's length, which looks like the smoking gun.
It is not: `load_doctrine` ends with `ArmyLayout.deploy()`, which **teleports every unit at tick 0 before any
physics step**, so a spawn slot is overwritten before two hulls can coexist in a simulated frame. I asked *which of
two copies of the spawn geometry wins* — a good question, correctly answered — and never asked *whether spawn
positions survive the frame*. **Finding the authoritative copy of a value is not the same as checking that the value
still matters.**

**⚠ RETRACTED THE SAME DAY — the table below is REAL BUT STALE, and is kept only as a worked example of how.**
It was measured on this branch at `787d8632`, where `ArmyLayout` is `ASSEMBLY_SPACING_M := 8.0` over a flat
`MIN_SPACING_M := 5.0`. **squad's `f1c3afcb` — "army start spacing derived from each squad's longest hull" — is on
`main` and is not in this tree** (merge base `c6a5c550`). So I reported a defect squad had already fixed, and
recommended to them the fix they had already written. **I carried the commit on the number, which is the rule, and
the rule was not enough: carrying the commit makes a number ATTRIBUTABLE, it does not make it CURRENT.** A defect
measured on a branch is a statement about that branch; I stated it about the game.

**The check against `main` was invalid too, so there is no replacement number here.** Copying `main`'s
`army_layout.gd` into this tree and re-running gave min 0.0 m and **median 0.0 m** for both armies — not a result,
every unit in one place. One file from a tree ~40 commits ahead is a Frankenstein build: the mismatched comparison
`compare_arms` exists to refuse, assembled by hand. Both of its numbers are discarded. **squad has been asked to run
`tests/test_army_footprint.gd` on its own tree**, which is where the answer lives.

**The stale table (laptop at `787d8632`, pre-`f1c3afcb`), nearest-neighbour centre-to-centre after deploy:**

| army | vehicles | min | median |
|---|---|---|---|
| **gang_ram** | 41 | **0.2 m** | 4.6 m (a 5.0 m tanker with **0.9 m** of room) |
| gang_pack | 45 | 0.8 m | 4.6 m |
| law_line | 24 | 2.3 m | 3.7 m |
| **syndicate_standoff** (control) | 18 | **7.4 m** | 8.3 m |

On that tree a gang army stood with about four metres of hull interpenetration, and the 18-vehicle control got
7.4 m from the same code — so on **that** tree the defect was `ArmyLayout` compressing a rank to fit the zone with
no reference to hull length. **squad's `f1c3afcb` does exactly what I was about to recommend**, so the likeliest
reading is that this was fixed before I measured it.

**What survives the retraction, and it is the useful half:**

- **`tests/test_army_footprint.gd` is a real instrument** and worth keeping whatever the answer: it measures the
  geometry that actually constrains vehicle size, and it is the regression guard for a 14 m rig.
- **The spawn grid still does not constrain vehicle size.** That correction stands on its own — `deploy()`
  teleports at tick 0 regardless of anyone's spacing constants.
- **The size question is no longer blocked.** squad reports assembly spacing is now `max(6.5 m, longest hull + 2 m)`,
  so a 14 m rig gives a gang squad ~16 m between vehicles and a wider frontage, which squad will re-check on sight.
- **Not landing the assertion was right for a second reason I did not have at the time:** had I landed it, my branch
  would now carry a failing test asserting a defect that main has already fixed.

### GREEN AND READY TO MERGE: `80bcd085`

`>> remote: make ... exited 0` on builder0, **1187 passed, 0 failed**, plus `match-pytest` **Ran 11 tests — OK**.
Working tree clean at that hash and unchanged since the sync, so the verdict is that commit's and not an
unlabelled tree's.

**The fourteen targets:** lint, test, net-smoke, combat-smoke, broker-test, relay-smoke, lobby-smoke, match-smoke,
determinism, garage-smoke, army-loop-smoke, announcer-check, audio-check, match-pytest. **`sim-baseline` is
excluded** — invariant 2, and see *why invariant 2 is right* below: a branch's green baseline predicts nothing
about `main` after merge, so recording it here would be worse than not running it.

**This branch contains arena's `877dc34a`** (a real merge at `0da3f015`, authorised by the orchestrator) and
`main` at the `96368bf6` checkpoint (baseline `253ecfdeed84bc4d`) via `c6a5c550`. **It does NOT contain the four
branches merged after that**, deliberately: control owns the `radar.gd` resolution against my X3 block and should
take it on its own post-merge re-check rather than have me sit on both sides of it.

**One shared-file edit to know about:** `mk/core.mk` (`ac3f331f`) appends `match-pytest` to `check` — 3 ms, and
appended rather than inserted because `check` aborts at the first failing target.

### IF YOU ARE A FRESH AGENT, START HERE (round 7, 2026-09-19)

**Round 7 in one paragraph.** X4 (the gangs' unattributed 23% → 53% swing) and X3 (the arena bound) are **built**;
N7 and CP4 shipped in round 6. The round's real output turned out to be **instruments rather than features** —
`compare_arms`, the positive control, the arm-adherence refusal — because three separate measurements this stream
quoted were measuring something other than what they claimed. **The one backlog item still carrying a number is the
four matrix runs** (`make faction-matrix-arms ARENAS="boulevard yard"`); everything else is done, blocked or stretch.
See *Next steps* and *The instruments, and what each one can and cannot prove* — read the second one before you
quote any number, because reaching for the wrong guard is how each of these got past a check.

**`main` is merged in at `c6a5c550`** (baseline `253ecfdeed84bc4d`), including arena's `877dc34a`. `DRIVABLE_LIMIT`
is **116 and that is deliberate** — do not "finish the job" by moving it to 117; the reasoning is under *X3*.

_The six items below were written 2026-09-18 against an imminent context loss. They are all still true and item 4
is the one most likely to have gone stale — check the current baseline before believing it._

**1. The decomposition inverts what this round spent its effort on.** N5 has three gates (sight, acquisition, fire
discipline) plus X6's crossing penalty. Measured over 75 matches against a true round-5 control:

| | kill distance | engaged | off-axis kills |
|---|---|---|---|
| **sight + acquisition + crossing** | **−11 m** | −4 m | **+17 pts** |
| fire discipline (the bands) | −3 m | −8 m | +2 pts |

**Tune acquisition first, bands second.** The *bands* absorbed nearly all of the round's design argument — the
`preferred_max` decision, the 0.65-versus-0.55 sweep, a long exchange with squad about standoffs — and they are the
smaller contributor to both headline numbers.

**Why it stayed invisible for most of the round, which is the reusable part:** my first control tuned
`effective_range` back to `range` and called it "the old world". It was not. Sight, acquisition and crossing are
**code**, and `--variants` only tunes **data**, so they were present in *both* arms and the comparison measured fire
discipline alone. **A data-only control is not a "before" when the change spans data and code.** I built the control
out of the knobs that happened to be reachable rather than out of what the question needed; it looked like a control
for hours. Sample size would not have caught it.

**2. The retraction, and why it was right even though the number was nearly correct.** I reported *"the fight is
decided 28% closer"* from **two matches on one mirror**. I retracted it. The true figure against a proper control is
**26%** — almost exactly what I withdrew. **Retracting was still correct:** against the control actually in use at the
time, the honest figure was **7%**. *A number that lands near the truth from the wrong comparison on an inadequate
sample is a coincidence, not a result.* The lesson a reader might otherwise draw — "trust the small sample, it was
nearly right" — is wrong and would cost someone a round. Also retracted and **still** retracted: *"fire goes up, so his
complaint was never about volume"*. Fire goes **down**, 17.8 → 15.2.

**3. `matchup-search` silently ran at `--units 60` for its whole history.** `mk/ai.mk` defaults `UNITS ?= 60`, make
variables are one global namespace, and `mk/match.mk` used the bare name — so every run passed `--units 60` whatever
the caller asked, **and the tool never recorded the value it used.** Round-3 `matchup-search` conclusions in
[../balance.md](../balance.md) that assumed a non-default unit count are unreliable and **cannot be re-derived**.
Fixed to `SEARCH_UNITS`. General rule: **print every resolved knob into the output.**

**4. CORRECTED 2026-09-19 — these targets are a latent trap, not a live failure.** On a CURRENT baseline they
**pass**: the 13-target gate at `2cf61f57` (builder0, 1181 passed / 0 failed) has `announcer-record-smoke passed`
and `music-smoke passed`. So the components were never the problem and the brief has been overstating this for two
rounds — it read as "three targets are broken" when the truth is "three targets misfire whenever the baseline
moves", which is once a round, by design. **feel's fix is still worth doing and blocks nothing.** The original
note, which remains the correct diagnosis of the mechanism:

**Three targets fail on a stale sim baseline and two of them blame the wrong component** —
`announcer-record-smoke` says *"the booth changed the simulation"* and `music-smoke` says *"the soundtrack changed
the simulation"*, **while computing exactly the hash `sim-baseline` computed**, which is the proof they changed
nothing. **These are feel's targets and the fix is unbuilt:** run the match twice in one invocation, with and without
the subsystem, and compare the two hashes *to each other*. A differential question must not be implemented as an
absolute comparison against a shared file. Invariant 2 guarantees the baseline moves once a round, so this misfires
every round until fixed.

**5. N7 is the strongest candidate for the next round's first item** — see *N7* below for the full argument. In one
line: the gates matter more than the bands, and **a central objective is the terrain-level version of the same
problem** — it collapses the space in which acquisition and flanking can matter at all, and the **45% off-axis kills
were achieved *despite* one central control point on every map.** arena's half is landed and tested; combat's half is
a pure read-through of `Arena.objectives_of`. Score **proportional to the share of objectives held**, because at N=1
that reduces exactly to today's behaviour.

**6. The evidence is committed, not in `build/`.**
[references/combat/n5-engagement-envelope-2026-09-18.json](references/combat/n5-engagement-envelope-2026-09-18.json)
is the 75-match series with its conditions in the README row. **The sim baseline is NOT combat's to record**
(invariant 2) — N5 moves it and the orchestrator records it once at the end.

**And now the reason, which round 7 supplied and which the rule needs** (2026-09-19): *inertness does not compose.*
"A is inert" and "B is inert" does **not** give "A+B is inert", because A can be inert only in the absence of B —
arena's new `_build_perimeter()` builds the wall from the shape's polygon instead of the authored boxes, which is
geometrically identical and creates different physics bodies in a different order, and that is enough for Jolt.
So **three green `sim-baseline` runs on three branches predict nothing about `main` after merge**, and a hash that
disagrees with them is not an anomaly — it is the expected result of composing changes each measured alone. The
only baseline that means anything is the one measured on `main` after the last merge, which is exactly what
invariant 2 says; the rule without this reasoning invites the shortcut of trusting a branch's green.

Corollary that cost this stream an hour today: **a commit's position in the log does not tell you what a queued
job measured.** `253ecfdeed84bc4d` was recorded from a tree captured before arena merged, though arena's merge sits
earlier in the log — so a baseline commit should state the hash of the **tree it measured**, not the commit it was
launched after.

---

### Read this first

**CP4 is done, measured, and merged with all three checkpoints.** On `c765275f` (nav CP1 + squad CP3 + arena CP2 +
squad's precedence fixes): `make test` is **1106 passed, 2 failed**, and **neither failure is combat's** — both are
stale thresholds in squad's scenario files whose underlying behaviour is now correct (see *What the last two failures
actually say*). **Do not make them pass by weakening anything**; the geometry needs deriving from the band, the way
this stream re-derived its own tests when the bands moved.

**What fire discipline at the shipped bands is worth** (builder0 `c765275f`, **n = 15 per row**, three
counterbalanced pairings, SEEDS=3 — [../balance.md](../balance.md) has the full table):

| | control | **shipped bands** |
|---|---|---|
| engaged distance | 68 m | **60 m** (−12%) |
| kill distance | 43 m | **40 m** (−7%) |
| flank+rear kills | 63% | **69%** |
| fire rate | 16.9 /unit/min | 15.2 (−10%) |
| matches ended by | 11 elim / 4 control | 11 elim / 4 control |

**Every metric moves the right way. All of them move modestly.** That is the honest state.

**Three earlier claims of mine are RETRACTED — if you have seen them anywhere, they are wrong:**
~~"decided 28% closer"~~ (really 7%), ~~"fire goes UP so the complaint was never about volume"~~ (it goes down), and
~~"`engaged_distance` does not discriminate, read `kill_distance`"~~ (inverted — engaged distance moves *most*). All
three came from **two matches on a single Condemned mirror**, the pairing most exposed to the army draw. I argued the
fire-rate one hardest *because* it was surprising and had a tidy mechanism, which is exactly when a result deserves
least trust: **the more a finding reframes something, the smaller the sample you should accept for it.**

**And a caveat the table above still carries:** the control tunes `effective_range` back to `range`, which disables
**fire discipline only**. Sight, acquisition and X6's crossing penalty are *code*, not data, so `--variants` could not
switch them off and they were in **both** arms. **That measures fire discipline, not N5.** I had built a control out
of the knobs that happened to be reachable rather than out of what the question needed — it looked like a control and
was not one. Fixed at `fa4e7077`: a variant may now carry runner flags, and a genuine round-5 arm
(`--no-acquisition --no-crossing`) runs beside a discipline-off-only arm so the two are separated rather than
conflated.

**Still owed:** the 75-match true before/after (running). **The sim baseline is NOT combat's to record** — round 6
made that invariant 2; the orchestrator records it once on `main` after the last simulation-changing merge.

| Commit | What |
|---|---|
| `14a1a29b` | **N5, the engagement envelope** (CP4) — sight, acquisition, fire discipline |
| `a493d4b5` `f1c1a903` | **X6** — a crossing contact is harder to lay on, plus a `--no-crossing` control |
| `82128d85` `fd5ac1af` | The metrics that made the above sayable: direct-fire split, shots per unit per minute |
| `9f798368` | **Infra** — the `VARIANTS`/`UNITS` make-variable collisions |
| `5478fa61` | The brain-range fix — superseded by squad's `fire_band`, which found a third call site I missed |

### The plan (ordered)

X1 first and alone, because it is CP4 and every other stream's measurements wait on it. Then X2 (closing must be
survivable) with the same series, because the two are one question asked twice. X3/X4 are re-measurements that can
only be taken after X1 lands. X5 and X6 are small and go where they fit. X7 is stretch.

### X1 — the engagement envelope (in progress)

**The design.** Three gates between "there is an enemy over there" and "the gun speaks"
(`game/combat/engagement.gd`, which is combat's file — see *merge notes* for the seam into nav's
`order_controller.gd`):

1. **Sight.** `_shootable()` requires the contact to be *seen* — the team's shared intel through the existing
   `spotter` callable (`Match.is_visible_to`), else the crew's own `sight_radius`. This is the `seen` test round 5
   found computed-and-discarded; it is back, and it sits *before* the line-of-sight raycast, so a rejected contact
   now saves a ray instead of costing a dictionary walk.
2. **Acquisition.** A crew must hold a contact for `acquire_seconds` before its first round: 0.3 s at arm's length
   rising to 1.6 s at the edge of its own vision, doubled at full suppression, ×0.55 for a scout. **Switching target
   restarts it**, so swinging onto a new contact costs time. Losing the contact bleeds the lay off at half rate
   rather than wiping it, so a target that ducks behind a crate is not found from scratch.
3. **Fire discipline.** A crew holds fire until it is inside its weapon's **effective range**. Two exceptions, both
   deliberate: a commander who designates a target *by name* has taken the decision, and a crew already being shot
   at (`suppression ≥ 0.25`) may answer at any range it can reach. A 1.12× release hysteresis stops the gun
   stuttering at the edge of the band.

**The decision I had to make, and why.** `effective_range` was equal to `range` on all eleven direct-fire weapons, so
round 5's spread falloff had never fired once. I set it to each weapon's own `preferred_max` — the band the weapon was
*designed* for — rather than a flat fraction of reach, because a flat fraction destroys the two long-range archetypes
(the Lancer's laser, the Syndicate's railgun) whose entire job is out-reaching a tank. That makes one number per
weapon serve the spread, the brain's positioning and the trigger, which is why they are deliberately the same number.
cannon 70→45, autocannon 60→45, laser 90→86, machine_gun 45→35, twin_mg 35→28, spear_gun 30→24, scrap_cannon 50→36,
assault_gun 80→62, railgun 110→104, pulse_cannon 70→55, pulse_repeater 55→45.

**It is a proposal until the series says so.** `tools/matchup_variants/engagement_bands.json` holds the three
alternatives (reach = the old world, 0.65 × reach, 0.55 × reach) as `--tune` strings, and the control for gates 1–2 is
`--no-acquisition` on the match runner. Numbers go in the next revision of this section, with sample size, commit and
machine. The design and the method are written up in [../balance.md](../balance.md) *Round 6 N5 (CP4)*, with the
measurements section explicitly marked **pending** so nobody quotes a design decision as a result.

**The trap that nearly voided the whole contract.** My first cut let any `{"type": "target"}` weapon order lift fire
discipline — "unless ordered otherwise", which is what this brief says. But `TankBrain`'s ENGAGE state issues a
`target` order **every tick**, so that exception would have exempted **every CPU unit in the game** and left N5 doing
nothing at all, while all sixteen of my rule tests went on passing. The override is now an explicit `"long_shot": true`
on the order, which nothing sets by default. It is orchestration.md lesson 23 inverted: not a feature behind a flag the
default path never passes, but an *exception the default path always passes*. The generalisable rule, which is the
part worth keeping: **when you add an exception to a rule, grep for every caller that would take it before you write
the test that proves the rule works.** I wrote the passing test first and it told me nothing.

**CP4 IS NOT READY TO MERGE, and the reason matters more than the code.** The envelope is a rule about *when a gun
may speak*; `TankBrain` is full of positioning logic written when "in range" and "worth firing" were the same number.
Landing N5 alone trades the lead's *last* complaint for his *first* one — units standing still in a fight. See
*The brain's range reasoning* below. The orchestrator has recorded that CP4 merges **paired** with squad's fix.

**Verification so far** (laptop, working tree on top of `a975e262`; the pristine baseline `make remote T=check` was
green on builder0: `1010 passed, 0 failed`, `>> remote: make check exited 0`):
- `make test FILTER=envelope` — **20 passed, 0 failed** (`tests/test_combat_envelope.gd`).
- Sixteen of those test the *rule*; four drive a real `OrderController` in a real match and test the **wire**.
  **Mutation-checked**: reverting both gates in `order_controller.gd` turned the wiring tests red and left every rule
  test green — which is exactly why the wiring tests exist (lesson 27: a failed edit and a wrong diagnosis look
  identical from the outside).
- `Engagement.covering_range()` returns **45.0 m** live, for arena's `exposure()` (see *Requests to other streams*).

### The brain's range reasoning (the thing that gates CP4)

`TankBrain._combat_move()` asks "can my gun reach that far?" with `weapon["range"]` in two places — the **outranging**
branch and the **short-halt-to-reload** branch. Under N5 a crew may not *fire* at maximum range, so both now halt a
unit exactly where it cannot shoot. Instrumented evidence, not inference: in
`scenario_orders::test_attack_move_fights_on_the_way` a tank with an attack-move order **stops 61 m from a scout and
sits there for the full 45 s — 0 shots, 0 metres, never arrives**, and the brain names its own reason every tick:
`opt=ENGAGE why="outranging it" move={"type":"stop"}`. Its cannon reaches 70 m so the old heuristic called the scout
outranged; its band is 45 m so the trigger is held.

That is orchestration.md lesson 17 (a behaviour starved by a rule above it) and the generalisation is worth keeping:
**when you narrow a quantity, grep every consumer of the old one** — a rule and a heuristic reasoning about the same
quantity in different units will deadlock.

`5478fa61` on this branch is a **proposal in squad's file**, verified: with `Engagement.effective_range(weapon)` in
both conditions the tank closes, kills with one shell and arrives in **14.9 s — faster than the 20.8 s the same
scenario measured before N5**, because it no longer stops to snipe. `their_reach` deliberately stays the contact's
full `range`: what can hurt me is their maximum reach. Squad's to take, replace or revert.

**Four scenarios still regress with that fix in**, attributed against a **pristine baseline of `make ai-scenarios`**
(40 passed, 6 failed on `a975e262`) rather than assumed — which turned "9 regressions" into *5 pre-existing, 1 fixed
by N5 (`scenario_squad::test_a_squad_focuses_its_fire`), 4 mine*:

| Scenario | What it says | Read |
|---|---|---|
| `scenario_motion::test_brains_dont_dither` | ~~17.7 / 15.6 switches per minute against a bar of 12~~ — **the counter was double-counting.** Real: 7.8 → 6.2 | **Resolved by squad**, and my alarm was louder than the evidence. I measured a metric and did not check the metric |
| `scenario_suppression::test_holding_a_crew_down…` | pinned crew 91% vs calm 100%, wants a wider gap | In the `check` subset, so it blocks a green check. Likely a threshold to re-derive from the band |
| `scenario_cover::test_a_healthy_tank_near_a_wall…` | hidden 42% of the fight, 3 shots | The peek position is now outside the band |
| `scenario_motion::test_a_scout_makes_attack_runs…` | 1 run, but 20 shots all into side/rear and **the tank took 0** | May be *better* behaviour (it commits). The test may be what is wrong |

### The player's units stop holding — product constraint #4, and N5 only exposed it

`test_ai_player_holds::test_the_players_units_wait_for_orders_and_the_cpu_does_not` fails on my branch. **It is mine,
it is not flakiness, and it is not the machine** — I assumed the laptop at first and I was wrong. Same file, same
laptop, bisected:

| Tree | Player's unit moved | |
|---|---|---|
| pristine `a975e262` | **2.0 m** | passes (bar is 5 m) |
| + N5, no brain fix | **10.2 m** | fails |
| + N5 + X6 + brain fix | **15.2 m** | fails |
| + N5 + brain fix, `CROSSING_ACQUIRE_PENALTY = 0` | **15.2 m** | X6 contributes **nothing** |

So N5 causes ~8 m of it and the brain-range fix the other ~5 m. Instrumenting the held unit's brain shows exactly what
happens, and it is not what I expected:

```
PH t=15   d=0.0  HOLD   | move=stop          <- correct, holding as ordered
PH t=645  d=0.3  ENGAGE | going for its side, weaving, front armor on it | move=move_to
PH t=675  d=6.6  ENGAGE | weaving, front armor on it                     | move=move_to
```

The unit holds for 21.5 s and then **decides on its own to flank**. The lead's round-5 ruling is *"the player's units
hold until ordered. An army that moves without being told is not an army"* (workstreams.md product constraint #4), and
ENGAGE is overriding it.

**The part worth keeping: that constraint was being upheld by accident.** Before N5, a held unit that entered ENGAGE
hit the *outranging* branch — `distance <= weapon["range"]` was true at that range — and `_combat_move` returned
`{"type": "stop"}`. The unit stayed put because an unrelated range heuristic happened to return "stand still", not
because anything in the hold logic said so. Narrow the range and the accident stops happening. **This is lesson 17
for the third time this round** (a behaviour starved — here *sustained* — by a rule above it), and the generalisation
is nastier than the deadlock one: **a guarantee that no test isolates can be held up by a coincidence, and it will
look fine until something unrelated moves.**

**Squad's to fix** (`game/ai/tank_brain.gd`, option precedence): a unit whose orders come from the player and which
has no move order must not *initiate* movement from a fight option. It may shoot, turn, and take cover under fire —
it may not decide to flank. My branch cannot go green alone while this stands, which is a third independent reason
CP4 merges paired rather than first.

### The CP3 × CP4 collision: a support-by-fire line inside the near-ambush radius

Found on the merged tree (`82128d85`, 1068 passed / 3 failed).
`test_tactics_scenarios::test_support_by_fire_forms_a_firing_line_at_a_standoff_and_fires_from_it` fails with
*"nobody advances onto the point (closest 31 m)"*, and its MEASURE line shows the real damage:

```
verb support_by_fire  closest_m 30.7  center_to_point_m 30.8  shots 19  orders_last_10s 128
drills: support_by_fire, near_ambush, support_by_fire, near_ambush, ...   (every tick)
```

**Cause.** `ElementPlan._plan_support_by_fire` picks `standoff = max(min(member effective_range) * 0.8, 25)`. It is
keyed on **`effective_range`**, which was `== range` for every weapon until this round. The standoff used to come from
a 70 m cannon (**56 m**) and sat comfortably outside `near_ambush_m` (**38 m** default, **42 m** Condemned). Narrowed
bands make it **28–36 m — inside the trigger.** So the element drives to its firing line, the line is inside
near-ambush, `near_ambush` pre-empts `support_by_fire`, the plan re-selects, and the two drills take the element off
each other forever. **Round 4's trip-up 17 reached by a new road.**

**This is the third load-bearing coincidence of the round**, after the player-hold guarantee resting on the outrange
branch and this standoff resting on `effective_range == range`. Nothing anywhere says *"an SBF standoff must be
outside the near-ambush radius"*; it held for four rounds because 56 happened to exceed 42, two numbers chosen
independently in different files by different streams. **When two independently-owned numbers must stay ordered, the
code has to say so — nothing will tell you the day they cross.**

**The answer (orchestrator, 2026-09-18), and it is better than the two I proposed.** I offered a choice between
keying the standoff on `range` and stating the distance invariant, and framed the residue as a doctrinal trade:
*"support-by-fire now has to choose between effective fire and not triggering an assault drill."* **That framing was
wrong and I withdraw it.** A rule fighting itself is not a trade, and it would be indefensible to explain to the lead.

The real defect is one level up: **`near_ambush` should not pre-empt a support-by-fire task at all.** Near-ambush is a
*reaction* drill — what a crew does when jumped at close range. An element deliberately posted in a firing line by its
commander, at the standoff its own task chose, is not being ambushed. Squad's X5 already made an SBF task outrank
`react_to_contact` and `far_ambush`; **`near_ambush` was simply missing from that list.** So it is an incomplete
precedence rule, not a distance — which also explains why no distance tweak felt satisfying.

Keying the standoff on `range` is rejected on my own measurement: 56 m lands **~50% of shells against ~100% at 36 m**,
and **a base of fire that cannot hit is not a base of fire.** This is the exact button the lead pressed and watched do
nothing, so it has to work well, not merely legally. The genuine costs of posting an element are already real and
already quantified — arena's **+0.127 on open foundry against +0.024 in dense yard**, and my **~70%-of-hits** penalty
for reaching past the band. Those are trades a player can reason about; self-interruption is not.

**Still take the invariant** (`max(reach * 0.8, near_ambush_m + margin, 25)`) on top of the precedence fix: it is the
part that stops two independently-owned numbers crossing again silently.

### X2, second finding: breaking contact just got much cheaper, which is round 5's problem drill

Geometry, flagged before the series so it is not discovered afterwards. A unit that wants to disengage used to have to
open the range past its pursuer's **70 m reach**. It now has to clear the **45 m band plus the 1.12× release
hysteresis — about 50 m.** Twenty metres of separation instead of twenty-five past a much shorter starting distance:
**disengaging is roughly a third of the work it was.**

The asymmetry that makes it worse is the return-fire exception. A crew being shot at may answer to full range — but a
unit that successfully breaks contact *stops shooting*, so its pursuer is no longer suppressed, so **the pursuer is
held to 45 m while the runner is not being fired on at all.** The exception protects the side that stays and fights,
not the side that leaves.

That matters because round 5 measured `break_contact` as the drill that was actively costing doctrine games: without
it the army went **91-29 and won on every arena**, and that was the one per-drill finding that survived the "attribute
a cost only by removing it" test (lesson 25). If N5 makes disengaging cheap, the drill may come back — either as a
dominant strategy for the CPU, or as a fight the player can never finish because everything he engages simply leaves.

**To measure, not to assume:** `net_advance`, `centroid_travel` and `held_line_share` in the CP4 series will show it
(a fight nobody can close on reads as high travel, low held line, and a long duration), and the direct test is ai's —
re-run the army with and without `break_contact` at the new bands. **`RELEASE_FACTOR` is the knob** if disengaging
turns out to be too cheap: raising it keeps a gun on a target that is pulling away, which is what makes a pursuit
possible at all.

### X2, first finding — WITHDRAWN: suppression kept its bite, and my own test says so

**Disconfirmed, and I am striking it rather than softening it.** I predicted below that narrowing the bands would
soften suppression, because its penalty is angular and closer fights forgive angular error. My own controlled test
measures the opposite at the ranges that now matter:

```
MEASURE pinned_accuracy inside the band (36 m of 45): calm 13/13 (100%), pinned 7/13 (54%)
```

**A fully pinned crew lands 54% where a calm one lands 100%** — suppression is worth about half a crew's fire inside
the effective band. That is a strong effect, not a softened one, and `SUPPRESSION_SPREAD_FACTOR` **should not be
touched.**

What misled me was reading it off a *scenario* instead of a controlled measurement.
`scenario_suppression::test_holding_a_crew_down…` reports 100% against 100% — but it holds the target at **0.73**
suppression, not 1.0, and at a range short enough that nothing misses either way. **The scenario measures a
configuration where the mechanic cannot show, and I read its null as evidence about the mechanic.** My own test fixes
distance to the band and suppression to 1.0 and sees the effect immediately. The scenario needs its geometry derived
from the band, the way I re-derived my own tests — a squad fix, not a balance change.

This is the fourth hypothesis of mine this round that measurement has killed (after disciplining opportunistic
suppression, artillery contamination, and X6 causing the dodge regression). The pattern in all four is the same and
worth naming: **I keep generating plausible mechanisms and they keep being wrong, and the only reason none of them
reached the lead is that each one was measured before it was believed.**

<details><summary>The original prediction, kept for the record</summary>

### (withdrawn) shortening the bands may have taken the bite out of suppression

`Match.SUPPRESSION_SPREAD_FACTOR` (2.0) is **mine**, and its own comment states the assumption N5 just invalidated:
*"A pinned tank's 0.8 deg becomes 2.4 deg: it still shoots, it just stops hitting anything far away."* Suppression's
penalty is **angular**, so what it costs in hits depends entirely on how far away the fight is. Push fights inside
45 m and the same 2.4° lands a much higher share of its shells — 2.4° is 2.9 m of scatter at 70 m but 1.7 m at 40 m,
against a hull about 3.5 m wide. `scenario_suppression::test_holding_a_crew_down_lets_a_teammate_work_on_it` is
already reading it: a pinned crew landed **10 of 11 shells against a calm crew's 11 of 11**.

That matters because L2 exists to make *base-of-fire-and-maneuver* real, and X2 ("closing has to be survivable")
depends on suppression buying an approach. If pinning no longer spoils aim, closing gets more expensive exactly when
N5 requires more of it.

**I have deliberately not tuned it.** One scenario assertion is not evidence for moving a core constant, and I have
just recorded a negative result from acting on a mechanism that looked obvious. The honest sequence is: measure
suppression's bite **inside the new bands** in the CP4 series (hit-rate delta pinned vs calm at the *new* typical
engagement distance, not the old one), and tune `SUPPRESSION_SPREAD_FACTOR` with that number if it has really
softened. Flagged here so nobody reads the passing/failing scenario as noise.

</details>

### A negative result: do NOT discipline opportunistic suppression

I exempted `suppress` orders from fire discipline, which made suppressive fire **strictly more available than
engaging** beyond the band — and the dither instrumentation showed units flipping `ENGAGE → SUPPRESS → ENGAGE` in
under a second at 47–50 m, right at the edge. Closing that hole (disciplined opportunistic suppression, `long_shot`
suppression still reaching) looked obviously right. **It was not:** dither did not move *at all* (17.7 / 15.6,
identical), and total scenario failures went **9 → 11**, adding `scenario_perf` CPU budget and
`scenario_suppression::test_holding_the_aim_point_suppresses_far_better_than_tracking`. Reverted; it is in no commit.
The ENGAGE↔SUPPRESS flip is a *symptom*, not the cause, and the real driver is upstream in option scoring.
**A fix justified by a mechanism you can see in a log is still a hypothesis until it is measured (lesson 20).**

**Known breakage from the new bands, and it is the interesting kind.**
`tests/ai_scenarios/scenario_cover.gd::test_a_hurt_tank_under_fire_gets_out_of_sight` places two Rust guns at **46 and
47 m** and asserts a hurt tank under fire breaks line of sight within 5 s. The cannon band is now 45 m, so the guns
correctly hold their fire, the subject is never under fire, and a test about *taking cover* fails for a reason that
has nothing to do with cover. The scenario's geometry silently encoded the old ranges — orchestration.md lesson 3 in
new clothes. **That file is squad's**, so the fix is theirs to choose (see *Requests to other streams*).

### X6 — `scout > lancer` now has a mechanic (`a493d4b5`, `f1c1a903`)

The roster has claimed `lancer.weak_vs = ["scout"]` since round 2 with nothing behind it, and ai asked for this in
round 4. **A contact CROSSING the gunner's field is harder to acquire than one driving straight at him** — the
component of its velocity perpendicular to the line of sight, over the range, against a 20°/s reference, capped at 3×.
A 14 m/s scout at 86 m crosses at 9.3°/s and costs a Lancer **2.25 s to acquire instead of 1.54 s**: 31 m of closing,
bought by moving across rather than at him.

Why this rather than a number in the counters table: **it pays for the right behaviour.** A scout that charges down
the sight line gets no protection at all (asserted in the tests); only the attack run does. And it is a rule about
gunnery, not a special case about scouts — a tank crossing an IFV's front is just as hard to lay on.

**The risk it creates, and the control that measures it.** N5's discipline delays the *start* of a fight; X6 delays
each *engagement* within it. Stacked, they are the one combination that could make fights too **quiet** — the opposite
of the lead's complaint and much easier to ship without noticing. Two scenarios already read it (a moving duel drops
to `[3, 2]` shots; the dodge champion finds nothing worth dodging), both outside the `check` gate and both X6 working
as intended. `--no-crossing` isolates it from the rest of acquisition, because `--no-acquisition` would switch off
gates 1, 2 *and* X6 together. If the series says it is too much, `CROSSING_ACQUIRE_PENALTY` is one number.

### X3 — the arena is no longer sized for the old ranges (geometry, pending the series)

This is arithmetic, not a measurement, and it is flagged as such. `arenas/foundry.json` (and every shipped layout) has
`half_size` **120** with spawn rows at z **±90** — the two armies start **180 m** apart.

| | before N5 | after N5 |
|---|---|---|
| Approach, in cannon-lengths | 180 / 70 = **2.6 reaches** | 180 / 45 = **4.0 bands** |
| Measured separation at first contact (round 5) | **~108 m** | should fall toward the band |

So the brief's premise — *"half-size 121 m with 70 m cannons means two spawns are barely two engagements apart"* —
**inverts**: in engagement terms the same map is now about **1.5× larger**, and the approach is the part of the match
that grows. My reading is that the maps should **not** shrink, and that the round-5 complaint about a single central
control point funnelling everything matters *more* now, not less: a longer approach is only interesting if there is
somewhere worth approaching other than the middle. That is arena's X3 and N7, and it is the strongest argument I have
for doing N7 promptly after CP4.

**What would change my mind:** if the series shows contact still happening at ~100 m (because team spotting plus the
`long_shot` override keep long-range fire alive), then the bands are not binding and the map question is untouched.
That is exactly what `separation_at_contact_m` and `engaged_distance_m` measure, so X3 resolves itself out of the CP4
series rather than needing its own run.

**X3 — DONE (2026-09-19), once the orchestrator authorised merging arena's commit directly.** `ARENA_HALF_SIZE`
is **140 and a bound**: a layout declares its own `half_size` under it, so Pit and Yard stay 120 x 120 and nothing
about the maps the lead has played changes. `stream/combat` contains arena's `877dc34a` (a real merge, `0da3f015`),
which is what makes the bump legal — before it, `validate` demanded equality.

**`DRIVABLE_LIMIT` stays at 116, and that is a deliberate deviation from the instruction to set 117.** The warning
behind the instruction is right and I kept it: scaling it with the bound to 136 would make a *square* clamp admit
points 192 m from centre on a hexagon whose wall is 121 m away on the flats — about three times too permissive, and
`Arena.validate` would approve every one of them. But 117 is the hexagon's inscribed bound (121.0 − 4.0) and **116
is already inside it**, so 116 is safe for the hexagon *and* for today's squares, while moving to 117 would take a
metre of clearance off every shipped map in exchange for nothing. It is a fallback square bound; `Arena.contains()`
is the real answer, and each surviving `clampf(..., DRIVABLE_LIMIT)` is a site still to migrate.

**What the bump broke, and why it was fixed here rather than requested.** `ARENA_HALF_SIZE` was doing two jobs —
*how big is the play area* and *how big is the world the HUD must cover* — and a non-square arena is what makes them
different numbers. Three readers were on the wrong side of that split and would have shipped visibly wrong the
moment the constant moved, so they moved with it (**owners: rewrite freely, this is your call, not mine**):

| File | Owner | Was | Now |
|---|---|---|---|
| `game/ui/radar.gd` | control/feel | a **square** outline at `±ARENA_HALF_SIZE` | `Arena.perimeter()` — the real inner face. Two bugs in one line: it would have drawn 20 m outside every wall, **and** drawn a hexagon as a square |
| `game/agent/agent_bridge.gd` | agent | declared `bounds` = the constant | the active layout's size — it was about to tell an agent the world is 140 m wide when the map is 120 |
| `game/match/visibility_field.gd` | **combat** | `const ORIGIN` off the constant | `var origin`, sized to the active layout. Presentation only, but a 120 m map would have carried a 280 x 280 field: 36% more cells to fill and upload, all of it outside the walls |

`VisibilityField.ORIGIN` is therefore `field.origin` now — per-instance, because the answer depends on which layout
is loaded. `radar.gd` and `skirmish_mode.gd` were the two static readers and both are updated.

**And one of arena's tests was measuring the map size, not the shape.** `test_a_hexagon_is_the_shape_that_varies_most`
probed the pinch ratio at a hard-coded **z = 60 m**. The ratio is scale-invariant — hexagon 0.711, octagon 0.914 at
*any* bound — but 60 m is a different fraction of a 140 m arena than of a 120 m one, so at the new bound it read
**0.753 against a 0.75 bar and failed**, having detected nothing except that the map got bigger. The probe now sits
at `bound * 0.5` and reproduces the original numbers at every size. **A constant in a test is a scale assumption
whenever the thing under test has a size.**

_Superseded, kept for the record — the blocked writeup:_ **X3 was BLOCKED (2026-09-19), on another stream.** Raising `ARENA_HALF_SIZE` to 140
as a *bound* needs `Arena.validate()` to stop demanding equality, which is arena's `877dc34a` ("half_size is a bound,
not a requirement (unblocks combat's ARENA_HALF_SIZE)"). **That commit is on `stream/arena` and is NOT on `main`** —
I checked with `git merge-base --is-ancestor 877dc34a main` after merging main, precisely because my own notes had
recorded it as landed. Until it merges, every layout must still have `half_size == 120` and the change cannot be
made on this branch at all.

Two things for whoever picks it up:

- **It is a contract change, not a combat edit.** The clamps live in six places across five streams —
  `ui/radar.gd`, `ui/tactical_map.gd`, `control/rts_controls.gd`, `tactics/army_layout.gd`, `ai/combat_motion.gd`,
  `ai/cover_map.gd` (plus `arena/arena.gd` and `match/visibility_field.gd`) — so it goes through
  [../workstreams.md](../workstreams.md) before a line moves.
- **`DRIVABLE_LIMIT` goes to 117, not 136.** It is `ARENA_HALF_SIZE − 4` today (120 → 116); keeping that *relative*
  relationship at 140 would push the drivable edge out by 20 m and silently re-scale every spawn row, cover map and
  fog grid that derives from it. The bound is meant to make room for a non-square layout, **not** to grow the maps.

### Infra: `make engagement` was broken, and `make matchup-search` silently wrong (`9f798368`)

`mk/ai.mk` sets `VARIANTS ?= r1,a4,a6` (brain-variant *names*). **A make variable set in any `mk/*.mk` is global**, and
`mk/match.mk` used the same name for a *path to a JSON file*, so `$(if $(VARIANTS),…)` was always true and always
wrong — `make engagement` died on `FileNotFoundError: 'r1,a4,a6'`, which is the exact command
[references/combat/README.md](references/combat/README.md) gives for reproducing the round-5 baseline. *A "reproduce
with" line nobody re-runs is a claim, not a reproduction.* `matchup-search` took the same collision **silently** and
would have searched three brain names instead of the file you meant. Both now take `VARIANT_FILE=`. `mk/ai.mk` is
untouched: the bug is two makefiles claiming one name, so the newcomer moves. **Name make knobs after the target that
owns them.** No dependency on the envelope — cherry-pick to `main` on its own (lesson 9).

### X6 cleared of the dodge regression (squad's A/B, 2026-09-18)

`scenario_dodge_rate` reads ~0 dodge attempts under CP4, and X6 was the obvious suspect: a dodging unit is by
definition moving across, so the crossing penalty makes it harder to lay on, fewer shells arrive, and a unit with
nothing inbound has nothing to dodge. Squad ran the A/B in the real pair state (combat `29eab0d8` + squad `9ba36681`,
laptop, the scenario's own seeds, `Engagement.crossing_enabled` flipped directly since `--no-crossing` is
match-runner only). Attempts / inbound ticks:

| | crossing ON | crossing OFF |
|---|---|---|
| ifv x5p / x6t5 / x6t4 | 0/484, 10/474, 19/489 | 0/495, 0/483, 0/478 |
| tank x5p / x6t5 / x6t4 | 0/530, 0/551, 0/557 | 15/552, 32/547, 0/556 |

**It is not X6.** The champion's IFV is at 0 either way, and the handful of attempts simply move between variants from
run to run. **`CROSSING_ACQUIRE_PENALTY` stays where it is** — I am not tuning a mechanic on single-digit counts out
of ~500 ticks, which is the 18-shell mistake (lesson 26) wearing a different hat.

The tidy-looking flip (every attempt on the IFV with crossing on, every attempt on the tank with it off) is the sort
of pattern that invites a story, and it should not get one: total attempts are 0–32, the sim diverges chaotically from
any change, and **the real finding underneath is round 5's** — dodging has *never* fired at either tick rate (254 of
254 candidate directions scored "would still be hit"). A behaviour that does not fire cannot regress. That is a live
open issue with no owner, not a CP4 consequence.

### CP4 is green at `f0f89e52`, and the stale baseline accuses three innocent components

**Verified on builder0:** lint, **1111 passed / 0 failed**, net/combat/broker/relay/lobby/match smokes, determinism,
garage-smoke, army-loop-smoke, announcer-variance and transcripts. I ran every target `make check`'s first failure
*skipped* by hand, because **make stops at the first error and a check that skips is not a check that passes** — four
targets never ran on the first attempt and reporting that as green would have been a partial green with a confident
label.

**Three targets fail, all on one stale hash** — computed `91db23888123f642`, baseline `8ebbed52fbff0723` (squad's
pre-CP4 record). Per invariant 2 combat does **not** record it; the orchestrator does, once, at the end.

```
sim-baseline            FAILED: expected 8ebbed52… got 91db2388…
announcer-record-smoke  FAILED: the booth changed the simulation      (91db2388…, baseline 8ebbed52…)
music-smoke             FAILED: the soundtrack changed the simulation (91db2388…, baseline 8ebbed52…)
```

**The booth did not change the simulation. The soundtrack did not change the simulation.** Both computed *exactly*
the hash `sim-baseline` computed, which is the proof they changed nothing — and each still announces a specific,
false accusation against its own subsystem. They are feel's targets, so a feel agent would go hunting in the audio
code for a bug that does not exist.

**The defect: a differential question implemented as an absolute comparison.** Both targets want to answer *"does
this subsystem perturb the simulation?"* — a question about the difference between two runs — but they answer it by
comparing one run to the **global baseline file**, so they fail whenever anything else legitimately moves it. Invariant
2 now guarantees that happens once a round. **The fix (feel's, `mk/announcer.mk:118` and `mk/audio.mk:34`): run the
match twice in one invocation, with and without, and compare the two hashes to each other.** That tests the claim, is
immune to the baseline moving, and needs no coordination with invariant 2 at all.

**And a gap in invariant 2 itself:** it says the orchestrator records the baseline once at the end. It does not say
that **until then three targets are red and two of them lie about why.**

### N7 — DONE (`5d0ca30f`). 1134 passed / 1 failed, and the one failure is not combat's

`Match` reads `Arena.objectives_of(Arena.active)` and keeps per-objective owner and progress. **No shipped arena
changes**: a layout with no `objectives` list reports exactly the single central zone this file used to hard-code.

**Three decisions, each with a reason worth reusing:**
- **Score by the SHARE of objectives held** (`ticks += INTEL_EVERY_TICKS × held/total`), because **at N=1 it reduces
  to the old accumulation exactly.** A generalisation that does not reduce to the current case is not a read-through,
  it is a balance change wearing one's clothes. Holding both of a mirrored pair scores at the old rate; holding one
  scores at half, so splitting to take both is the decision the contract exists to create.
- **`control_owner` / `control_progress` are a write-through VIEW of `objectives[0]`, not a copy.** A copy is exactly
  what broke `test_control_point` when this landed: it poked `control_owner` between frames, the tick overwrote it,
  and the match silently never ended. Five streams both **read and write** this state, so a view is what keeps them
  all working.
- **`--control` is a match flag, not a layout property**: a layout declaring no `control_point` still gets the
  central zone, or `--control` would silently do nothing on it.

`control_changed` still fires for the primary objective; `objective_changed(index, owner)` is the N7-aware signal.
The static `Match.in_control_zone` is kept (five streams call it) but **can only know the default central zone** —
`in_any_objective` / `objective_presence` are the replacements, and `cpu_commander.gd:181` is the one call site that
will go quietly stale rather than loudly break when arena ships an off-centre layout. **Squad has been told.**

**The sim baseline moves** (objective handling is simulation). Per invariant 2 combat does **not** record it.

**The one failing test is `test_audio_music_director::test_it_follows_a_mood_signal`, and it is feel's** —
order-dependent, arrived with a `main` merge, reported with its bounds. **Do not attribute it to N7**, and note how
nearly I did: I first compared a *filtered* pre-N7 run against a *full* post-N7 run, saw pass-then-fail, and concluded
it was mine despite the test having zero references to `control`. **That comparison is invalid** — a filtered run and
a full run answer different questions (lesson 45). The filtered run on the N7 tree passes 17/0, which is what
excludes N7. *I had flagged that exact distinction to the orchestrator the same morning and still made the mistake
when it was my own change under suspicion.*

### (the case for N7, written before it was built) why it compounds with N5

**Taken on (2026-09-18), and the case for doing it in round 6 rather than deferring it comes out of the series.**
arena's half is landed and tested: `Arena.objectives_of(Arena.active)`, mirrored pairs enforced, and every shipped
layout still reporting exactly the single central zone `Match` hard-codes. My half is a pure read-through —
`CONTROL_CENTER`/`CONTROL_RADIUS` become per-objective state.

**The argument:** the decomposition says the **gates** matter more than the bands — making a crew find and hold a
target is what moved where fights are decided (−11 m) and who dies from the flank (+17 points), while the bands mostly
pulled the armies closer. **An objective that funnels every fight into the middle is the terrain-level version of the
same problem: it collapses the space in which acquisition and flanking can matter at all.** The 45% off-axis kills
measured above were achieved *despite* one central control point on every map. Moving objectives off the centre line
should **compound** with N5, not sit beside it — which is why this is round 6 work and not round 7's.

**The one design decision it needs, and the rule that settles it.** With N objectives, what scores? Independent
scoring doubles the pace at N=2; a majority rule makes control wins rare and pushes every match to elimination.
**Score proportional to the share held** — `ticks += INTEL_EVERY_TICKS * held_by_team / total_objectives` — because
**at N=1 it reduces exactly to today's behaviour**, which is what makes the change a genuine read-through rather than
a balance change wearing one's clothes. Holding both mirrored objectives scores at the old rate; holding one scores at
half; splitting your force to take both is rewarded, which is the decision the contract exists to create.

**Sequencing:** CP4's merge first, always. N7 must not delay it by a minute — squad's X6 baseline, arena's X3 and
nav's `gunnery.gd` split are all waiting on CP4 being on `main`. And **N7 may move the sim baseline again**; per
invariant 2 combat does not record it, and the N7 report must say whether it moves.

### X7 — ANSWERED (2026-09-19) from evidence already committed, no new run

Read out of [references/combat/n5-engagement-envelope-2026-09-18.json](references/combat/n5-engagement-envelope-2026-09-18.json)
(builder0 at `fa4e7077`, n=15 per arm). **The brief's target was two claims and they have different answers:**

| | round 5 (true control) | **shipped** | |
|---|---|---|---|
| flank + rear kill share | 55.4% | **68.6%** | **a majority — target met** |
| off-axis kill share (the strict measure) | 25.7% | **45.5%** | **not a majority — but nearly doubled** |
| rear kill share | 11.2% | **20.8%** | nearly doubled |
| **centroid travel** | 236.8 m | **248.1 m** | **+5% — essentially unchanged** |

**1. "A majority of direct-fire kills come from the flank or the rear": YES by the hull-face measure (68.6%), NO by
the stricter one (45.5%).** Quote the strict one. An oblique shot across a wide front registers as a "side" hit
without anyone having flanked anything, which is why `off_axis_kill_share` exists — and by it the game is just
short of half, having risen from a quarter.

**2. "The armies' centres of mass move during the fight": YES, and N5 did not cause it.** Centroid travel is
236.8 → 248.1 m, about 5%, which is inside the noise of a 15-match arm. **The armies moved this much before the
engagement envelope existed.** So the flanking gain is *not* the armies manoeuvring more — it is a change in **how
kills happen within an engagement**, at the same amount of movement. That is worth knowing before anyone credits
N5 with making the battle more mobile: it did not. It made the shooting more directional.

**Caveat, stated because this stream has been bitten by exactly this:** these are round-6 arms at `fa4e7077`, not
the current tip, and the control is the true round-5 arm (`--no-acquisition --no-crossing` *plus* bands at reach),
not the discipline-off-only arm. Read the fourth row of that file, not the third.

### (superseded) X7 (stretch) — the event half is already done; what is left is one number

Checked rather than assumed. `projectile_impact` already carries `weak_spot` (K2), feel's `game/theme/fx/k2_events.gd`
already reads it, and there is a dedicated `weak_spot_hit` sound layer with two variants. **So "feel draws the cue;
you provide the event" is satisfied on both sides** — nothing to build.

What is left of X7 is therefore a measurement, not a feature: *does flanking pay more now that fights happen closer?*
That is `flank_rear_kill_share` and `off_axis_kill_share`, both already in the engagement summary, so **X7 resolves out
of the CP4 series** exactly as X3 does. The round-5 baseline for a Condemned mirror was 47–78% flank+rear, and the
brief's target is *"a majority of direct-fire kills come from the flank or the rear, and the armies' centres of mass
move during the fight"* — read `off_axis_kill_share` and `centroid_travel` for it rather than the hull-face split,
since an oblique shot across a wide front counts as a "side" hit without anyone having flanked anything.

### The pair-measurement with arena: design agreed, not yet buildable

arena has a route model (cost × reward → scenery / dominant / trap / **interesting**) and designed the test that
could kill it before building five maps on it: **do units actually take the routes the map calls interesting?**
combat measures the unit-time; arena hands over the classification as data (polyline, cost, reward, quadrant) so
there are not two implementations of the same geometry drifting apart.

**A null result is ambiguous three ways, and each needs its own control.** *"Units did not take the interesting
route"* can mean:

| | cause | how to tell |
|---|---|---|
| **a** | the route is genuinely unattractive — **arena's model is wrong**, the finding the test exists to produce | free arm: units never enter it |
| **b** | units **cannot execute it** (mis-path, blocked, no route) | **commanded arm** |
| **c** | units were **dragged off it by a fight** | nav's `retasked:<option>` bucket |

**(c) is nav's finding and I had not thought of it:** under `attack_move`, units re-task their drive target **46
times per unit-minute** (builder0, yard, seed 7), **54% of that from ENGAGE re-aiming its combat hops**. So a free-arm
unit that "does not take the route" may simply have been pulled into a fight. **Order the commanded arm with a plain
`move`** — 0 re-tasks measured — or it measures the fight rather than the route.

**The arrival check is nav's, not mine** (`Movement.state(tank)` per tick). Since `ab93d85b`, `phase == "arrived"`
means within the order's arrive radius of the **goal**, never the route's end; a route stopping more than 3 m short
(NavigationServer's "nearest reachable point" answer) reports `reachable: false` and `blocked` / `no_path`. So the
caveat I raised is already handled — and I will still check flat distance to the scripted waypoint, because belt and
braces costs nothing and a second opinion on "did it get there" is the one place I want redundancy rather than reuse.

**A refinement arena should have before it reads any result:** *entering a route and then fighting on it **is** taking
it.* The metric is **unit-time on the route**, not completion — a map whose interesting route is where the fights
happen is the map working, not failing. Only *never entering* is declining it.

### The designator: two runs measured a different game, and neither was caught by a check

**Run 1 (void).** Re-roling the Lance Platform to `role: "designator"` **silently dropped it from every army** —
`Army.squads_for()` iterates `SQUADS`, not the units, so a role with no entry is omitted with no error. The Syndicate
fought 60 matches with four unit types and the result read *"the designator makes them slightly worse"* (43% → 40%).

**Run 2 (lower bound only).** With the `SQUADS` entry added the unit was fielded — but `role: "designator"` is absent
from `FRAGILE_ROLES` and `PROTECTED_ROLES`, and `CpuCommander` classifies unknown roles as **line**, so a spotter was
pushed to the front. Boulevard, superseded build: condemned 53%, gangs 53%, law 47%, syndicate 47%. **Understates the
mechanic; not quotable.**

**Both were found by a result looking *slightly wrong*, not by any check** — which only works when the confound
happens to push the implausible way. So the fix is not vigilance:

- **`designates: true` is a capability, not a role** (`f1fb19ad`). `role` is a taxonomy **eight places key off across
  four streams** — `Units.ROLES`, `Army.SQUADS`, `SquadTactics.FRAGILE_ROLES`, `TacticsFormation.PROTECTED_ROLES`,
  `CpuCommander`'s line/support split, `ElementSituation`, `ArmyCatalog.ROLE_LABELS`, `command_icons` — and **none
  reference a single registry.** A value eight places key off is not a value, it is an interface; this one has no
  owner. Round-7 debt. The mutation-checked `SQUADS` guardrail is the down-payment.
- **A positive control** (`e0f6ce40`): `Match` reports designators **fielded** and paints **landed** per team, and
  `faction_matrix` **refuses** — not annotates — a result where a side fielded one and painted zero. *A treatment arm
  with no treatment is a failed run, not a null result.* The `run:` header proves **which build**; this proves
  **which behaviour**.

**The control then broke the instrument it was guarding, which is the part worth reading** (`9821cac7`). Shipped
`e0f6ce40` with unit tests over `Match`'s two counters and **never ran `faction_matrix` once end to end**. The block
read `outcomes`' values as result dicts; they are `(result, first_is_green)` **pairs**. Every matrix run after it
died on `AttributeError` before printing a row — a guard against bad numbers that produced **no** numbers, and it
would have mis-attributed the faction anyway, because team 0 is Green and which faction that *is* depends on the
flag. Two lessons, and the second is the general one:

1. **"The counters are tested" is not "the instrument works".** The unit tests were real and passed; nothing
   exercised the thirteen new lines that consume them. A guard is code on the hot path of every future run, so it
   earns *more* end-to-end scrutiny than the thing it guards, not less.
2. **A guard that is silent when it ran and silent when it never ran is indistinguishable from no guard** — which is
   precisely how the designator got measured twice without engaging. So the run now *always* states what the control
   saw: `positive control: 6 side(s) fielded a designator, 97 paints -- treatment engaged`, or **`NOT EXERCISED`**.
   Zero fielding sides is often legitimate — a faction army draws **one** archetype and `syndicate_escort` carries no
   Lancer, so a small matrix can field none at all — but legitimate is not the same as *passed*, and a control that
   cannot be seen firing will eventually be believed without having fired. **Make an assertion report its own
   coverage.**

Verified end to end on the laptop at `9821cac7` (8 matches, foundry, 45 s limit — a plumbing run, **its win rates are
not a balance result and must not be quoted**): tool exits 0, json written, both branches of the evidence line seen.

### Every faction number this project has quoted is a FOUNDRY number — and foundry is near-open

`faction_matrix.py` passed no `--arena` until `c2b27516`, so every matrix run used the default layout and **said so
nowhere.** The numbers are sound as *differences* (both arms ran on the same ground) and unsound as *properties*.
Fixed: `ARENA=`, the map named in the header, a per-arena json, and `balance.md`'s rows relabelled.

**The part that reframes the baseline** (arena, measured, `make arena-report`): foundry is **`centre_sees_share`
0.56 — the second-most-open map in the game.**

| arena | centre sees | |
|---|---|---|
| **boulevard** | **0.64** | the open extreme |
| foundry / furnace | 0.56 | ← **every number we have quoted** |
| boneyard | 0.40 | |
| pit / scrapyard | 0.30 / 0.29 | (the lead kept pit, cut scrapyard — the ranking predicts him at the extremes, not the middle) |
| **yard** | **0.20** | the closed extreme |

So the gangs' 23% → 53%, the 47-to-10-point collapse and the heights null were all measured on **near-open ground**,
which sits close to the favourable end for anything that pays off with sightlines. **Prop counts are not a proxy for
openness** and would have inverted the ranking: `scrapyard` has 36 obstacles and measures 0.29, `boulevard` has none
in `obstacles` and 100+ in `props` and measures 0.64 — the split is schema history (v1 vs v2), not a difference in
what blocks.

**Why the designator must be reported per map and per faction, never as an aggregate.** Its payoff is *conditional*
on sightlines, so one number over a mixed pool is either noise or one map doing all the work. And a pairing table
cannot distinguish the two results that matter: **one faction moving between maps** (an asymmetry — the map pays one
army more) from **every faction's spread widening on the open map** (a property of the map). `faction_matrix.py` now
prints a per-faction block for exactly that (`1314bfd9`).

**The open question this decides, and it is arena's target:** `centre_sees_share < 0.30` was set when every unit saw
alike. N5 put time between seeing and shooting, sight radii vary 62–135 m, and the designator converts one faction's
eyes into its whole side's tempo — so exposure is now a property of **the map and who is standing on it**. arena's
position, which I accept: keep the target, because it is evidence about *whether a map is worth building*, while the
designator is evidence about *whether one faction gets more out of a given map*, and both can be true. It changes only
if the Syndicate's advantage on the open map is large enough to be a balance problem rather than a flavour
difference. **The boulevard/yard pair decides it.**

### X5 — the Lancer: **the recommendation was incomplete. HOLD the removal.**

**The lead approved dropping `syn_lancer`; then I implemented it and it broke the Syndicate.** Removing it leaves
them with only the four core roles and **no special at all**:

| faction | roles | special(s) |
|---|---|---|
| condemned | 6 | **lancer + burner** |
| gangs | 5 | support |
| law | 5 | suppressor |
| syndicate | 5 → **4** | lancer *(their only one)* |

`test_combat_factions::test_every_playable_faction_fills_the_core_roles` catches it, and it catches it because it
asserts a **design pillar** — *"counters stay learnable across factions"* — rather than an implementation detail.
**That asymmetry strengthens the half of the recommendation that was right** (the Condemned can afford to lose the
Lancer because they also have the Burner) **and invalidates the half I never checked** (the Syndicate cannot, because
it is their only one). *I made a recommendation about one unit without looking at the roster it would leave behind.*

**Three ways forward; the choice is the lead's:**
1. **Keep it and re-role it** so it is not a second sniper. The Syndicate fields **15 vehicles at 5200 points**
   against the gangs' 39 — an elite-few faction has room for a special that is not about range.
2. **Design a replacement special first.** `syn_scout` has the game's best eyes (135 m sight), which under N5's gate 1
   is worth more than it was; a designator or spotter would fit the faction and not duplicate the railgun's 104 m.
3. **Accept a four-role Syndicate** — argued against here: it makes them the only faction with no identity beyond
   the core four.

**Reverted on this branch**, so nothing is half-landed. feel's work on that model is only wasted under (3).

### (the analysis that still stands) why the Condemned keep theirs

Measured from the rosters, not argued from memory. Direct-fire **bands** by faction and slot:

| slot | Condemned | gangs | Law | Syndicate |
|---|---|---|---|---|
| scout | 35 | 24 | 35 | **45** |
| ifv | 45 | 28 | 45 | **55** |
| tank | 45 | 36 | 62 | **104** |
| **lancer** | **86** | — | — | **86** |

**The Syndicate's Lancer is outranged by the Syndicate's own tank.** `syn_tank` covers **104 m**; `syn_lancer` covers
86. It is a cheaper (340 against 470) but *shorter-ranged* duplicate of the role that faction already dominates — and
the Syndicate holds the longest band in **every** slot, so nothing about a long-reach specialist is distinctive there.
It competes with their tank instead of complementing it.

**For the Condemned it is the opposite: the Lancer is the only thing that stretches their line.** Their next-longest
direct-fire band is **45 m**, so the Lancer's 86 nearly doubles it, and it is their only answer to a Syndicate tank
shooting effectively from 104 m. Remove it and the faction flattens into a single band.

**The framing that makes this more than a roster tidy-up** (the orchestrator's, and it is the right one): the Lancer's
86 m band is *why* `engaged_distance` sat at ~70 m in **every** configuration of the CP4 series, including the old
world — an army-level average is set by its longest-reach unit. So "which faction keeps the Lancer" is really **which
faction gets to distort its own engagement profile.**

That argues the same way. In the Syndicate it would be the *second* distorter on top of a 104 m tank — the faction's
profile is already stretched and the Lancer merely piles on. In the Condemned it is a **single** exception to an
otherwise 45 m line, which is a *contrast inside the roster* rather than more of the same, and contrast is what makes
a faction legible to a player. **A long-reach unit is only interesting in a faction whose other units are short.**

**What the Syndicate loses, and why it is affordable:** a cheaper long-range option. They keep `syn_tank` (104 m
band), `syn_artillery` (170 m reach) and `syn_scout` (45 m band, 135 m sight — already the best spotter in the game).
The gap is a price point, not a capability.

### (superseded) X5 — the duplicated Lancer

**The Syndicate should lose `syn_lancer`; the Condemned keep `lancer`.** The reasoning is the engagement envelope
itself. Post-CP4 the Syndicate already fields the longest reach in the game — `syn_tank`'s railgun covers **104 m**,
more than any other unit — so a second long-range specialist at 86 m duplicates a job that faction already does
better than anyone. The Condemned have no other unit past 45 m, so the Lancer is the *only* thing that stretches their
line, and removing it there would flatten the faction into one band. Dropping `syn_lancer` also removes the roster's
only case of two units sharing a weapon (`laser`), which is what made the duplication visible in the first place.
Not blocking: both still exist until the lead rules.

### X4 — RESULT (2026-09-19, builder0 at `f745f48a`, n=30 per faction per arm)

**The ablation ran, the treatment engaged in all four arms, and it CANNOT settle the question. That is the
finding, and the untreated factions are what prove it.**

Faction directives ON minus OFF, per map, never pooled:

| faction | boulevard (open, 0.64) | yard (closed, 0.20) | treated? |
|---|---|---|---|
| **gangs** | **+7 pts** (50% → 43%) | **+7 pts** (53% → 47%) | **yes — the only one** |
| law | −7 pts | **−10 pts** | no |
| condemned | +3 pts | +0 pts | no |
| syndicate | −3 pts | +3 pts | no |

**`gangs/scout` is the only faction-keyed entry in `Army.SQUADS`, so the gangs are the only faction the ablation
treats.** Every other row is therefore a measurement of what an *untreated* faction does between two arms — and
**law moved −10 points without being treated at all, which is larger than the gangs' +7.** At n=30 the standard
error of a difference of win rates is **12.9 points** (a 95% band of ±25), so a 7-point effect is well inside the
noise, and the untreated rows demonstrate that empirically rather than by arithmetic.

**What this licenses and what it does not.**

- The direction is consistent: the gangs are worse without their own directive on **both** an open and a closed
  map, +7 on each. That is what you would expect if the directive helps. It is not evidence that it does.
- **It is an order of magnitude short of explaining 23% → 53%.** Whatever produced a 30-point swing, an effect
  this size is not it — so **neither CP4 nor the `gangs/scout` fix is established as its cause, and combat still
  claims none of it.**
- **The likeliest explanation is that the original comparison was never a comparison.** The 23% and the 53% were
  taken on different builds and, on the evidence of this stream's own foundry finding, plausibly different maps.
  `compare_arms` exists precisely to refuse that subtraction; it did not exist when those numbers were made, and
  they cannot be reconstructed now.

**To resolve ±7 points you need about n=400 per faction per arm** (SE_diff ≈ 3.5), i.e. roughly `SEEDS=70` — about
seven times this run, or ~4 hours of builder0 for the four arms. **That is the price of the question, and it should
be paid deliberately or not at all.** My recommendation is *not at all* for now: a 7-point faction effect is
smaller than the balance differences the lead would notice, and the same builder0 hours buy more elsewhere.

**Incidental, and the more useful number: the factions are close to the design target on both maps.** Normal play,
`f745f48a`, n=30 each: boulevard condemned 53 / gangs 50 / law 50 / syndicate 47; yard condemned 53 / gangs 53 /
law 53 / syndicate 40. game_design.md asks that "any faction pair is near 50/50 when both sides build good armies"
and every faction is within 3 points of even except the **Syndicate on the closed map (40%)** — which is the
direction its design predicts (fewest vehicles, longest guns, a designator that turns sight into tempo) and the one
number here worth a second look, though it too is inside the noise band at this n.

### X4's ablation: how to settle who earned the gangs' 23% → 53% (`f7c0d712`)

**Nothing may credit CP4 with that swing until this runs.** The directive fix and the engagement envelope landed in
the same commit and no matrix ran between them, so the 30 points are shared between two changes by an accident of
sequencing. The ablation separates them:

```bash
# Both arms, both maps. ARENA is not optional: a faction number without a map is a foundry number (see below).
make remote T="faction-matrix SEEDS=5 TIME=150 JOBS=8 ARENA=boulevard"            # normal play
make remote T="faction-matrix SEEDS=5 TIME=150 JOBS=8 ARENA=boulevard ABLATE=1"  # the control arm
# ...and the same pair on `yard`, because boulevard is open (0.64) and yard is closed (0.20).
```

Read it as: **gangs' win rate, arm A minus arm B, per map.** If the gangs collapse without their own directive, the
directive earned the swing and combat earned none of it. If they hold, CP4 has a claim — *and still only on the maps
it was measured on.*

Three properties of the arm, each there because of a specific way this stream has been wrong before:

- **`Army.faction_directives` is a flag, not an edit of `SQUADS`.** A hand-edit leaves the tree modified, so the arm
  is invisible in the output, `run_conditions` marks the run dirty, and the number surfaces weeks later with no way
  to tell which arm made it.
- **`MATCH_RESULT` carries `controls`** — `{acquisition, crossing, faction_directives}`. Print every resolved knob;
  `matchup-search` spent its entire history at `--units 60` and recorded it nowhere.
- **`ABLATE=1` sets the flag *and* the output filename** (`build/faction-matrix-<arena>-plainroles.json`) from one
  make variable. Two arms writing one filename is how a control silently overwrites its treatment and leaves a
  single file that reads as both runs.
- **`faction_matrix` refuses a run whose `controls` are not what was asked for.** The positive control asks whether
  the *treatment* engaged; this asks whether the *arm* was the one requested. A dropped flag gives two files that
  differ only in their names and a "no effect" that is really *I ran the same thing twice* — round 6's data-only
  control, in the one form a tool can catch.

**The static is reset on every run, not only when the flag is present.** A control that leaks into the next run in
the same process makes both arms read as the ablated one, which is the silent version of this whole problem.

### The CP4 series: exact commands, in order

**Do not run any of this until the brain-range pair is green** — on a build where units halt at 61 m it measures a
game nobody plays. Every command names the machine and the commit in its own output; record both.

```bash
# 1. The before/after, in the configuration players actually get (faction armies, 30 a side, control on).
#    NOTE the knob is VARIANT_FILE, not VARIANTS (see mk/match.mk: VARIANTS is mk/ai.mk's, and it is global).
make remote T="engagement PAIRS=condemned:condemned,gangs:law,condemned:syndicate SEEDS=3 TIME=240 JOBS=8 \
    VARIANT_FILE=tools/matchup_variants/engagement_bands.json"
#    4 configurations x (3 mirror + 12 counterbalanced) = 60 matches.
#    The `reach (the old world)` variant IS the control: it puts every band back at its weapon's maximum,
#    which is exactly the world before this contract. Without it the result is an assertion, not a comparison.

# 2. Attribute the gates. Same pairing, three runs, one knob each.
make remote T="engagement PAIRS=condemned:condemned SEEDS=3 TIME=240"                      # everything on
make remote T="engagement PAIRS=condemned:condemned SEEDS=3 TIME=240 TUNE=<bands=reach>"   # discipline off
#    ...and --no-acquisition / --no-crossing through the match runner for gates 1-2 and X6 separately.

# 3. DO NOT record the sim baseline. Round 6 made this invariant 2 (workstreams.md): no stream records it;
#    the orchestrator records it ONCE on main after the last simulation-changing merge. Three streams moved it
#    this round (combat's ranges, squad's brain fixes, nav's ORCA/PID), so every per-stream hash is stale by the
#    next merge. Say in your green report that your change moves it, and stop there.
#    Why it has to be a rule rather than care: the file is keyed per glibc, the laptop is 2.39 and has NO 2.39
#    line, so `sim-baseline` SILENTLY SKIPS locally. A check that skips is not a check that passes, and all
#    three of us could have committed a stale hash behind a green local check.

# 4. X4's re-measure, which must come after all of the above and never across it.
make remote T="faction-matrix SEEDS=5 TIME=150"

# 5. Play it, which is the only check that counts for the lead's actual question.
make skirmish     # does a fight start at a distance where anything but shooting is still possible?
```

**Read every result from the wrapper's own `>> remote: make <target> exited <N>` line and the runner's
`N passed, M failed`** — never a shell exit code through a pipe (lesson 28; I made this mistake once already this
round by reading a "waiting for a slot" line as a queue when I had in fact been granted one).

### Questions for the lead

1. **The Lancer** (X5): which faction keeps it. Not blocking — a proposal will be here.

### Requests to other streams

1. **arena — replace `exposure()`'s hard-coded 110 m watcher range with `Engagement.covering_range()`** (45.0 m
   today). It is the median of `min(effective_range, sight_radius)` over all four rosters, derived from the data so it
   cannot go stale when a band moves. Distribution, because it matters more than the median: 24–36 m for the light
   units (`gang_scout` 24, `gang_ifv` 28, `scout`/`law_scout` 35, `gang_tank` 36), **45 m for the mass of every roster**
   (`tank`, `ifv`, `law_ifv`, `syn_scout`), 55–62 m for `syn_ifv` and `law_tank`, and 86–104 m for the two long-range
   archetypes (`lancer`/`syn_lancer` 86, `syn_tank` 104). Run a second pass at 86 m for "deniable by a sniper".
   **Carry this caveat with any exposure number you publish:** an ordered `long_shot` reaches the weapon's full range,
   so an approach outside the radius is safe from units using their own judgement, not safe absolutely.
2. **squad — one of your scenarios now fails because of my bands, and the fix is yours to pick.**
   `scenario_cover.gd::test_a_hurt_tank_under_fire_gets_out_of_sight` puts its two guns at 46/47 m, just outside the
   new 45 m cannon band, so they hold fire and the subject is never under fire. Either (a) move those two guns ~6 m
   closer along the same bearing — I checked the sight lines against WallWestA and the wall geometry the scenario
   depends on still works; or (b) give `AiScenario.shooter()` a `{"type": "fire_at_will", "long_shot": true}` default,
   on the grounds that a scenario shooter is **a prop whose job is to deliver fire**, not a unit whose fire discipline
   is under test — one line, and it fixes every scenario of this class at once. **I recommend (b)**, with a comment
   saying why. Note `long_shot` lifts only fire discipline: your props still have to see and acquire, so scenarios
   keep realistic behaviour. Tell me if you would rather I made the edit.
3. **squad / control — `"long_shot": true` is the hook if a doctrinal task should authorise a long shot.** A
   support-by-fire or attack-by-fire element (squad), or a player deliberately designating a distant target (control),
   are the two cases the exception was built for. Nothing sets it today and that is the safe default.
4. **nav — the gunnery seam.** X1 needed four edits inside `order_controller.gd` (your file): the `seen` gate in
   `_shootable`, one member (`engagement_lay`), the trigger line in `_apply_weapon`, and a `_seconds_step()` helper.
   Every rule behind them lives in `game/combat/engagement.gd`; the controller only carries the state and feeds the
   target the weapon scan already picked, so when your X1 splits the file into movement and gunnery these four go
   with gunnery untouched. Nothing here reads a path, a waypoint or a throttle.

### Known issues (open, and whose)

| Test | Whose | Why it fails |
|---|---|---|
| ~~`test_ai_player_holds::test_the_players_units_wait_for_orders…`~~ | **FIXED on `main`** | Product constraint #4. A held unit picked ENGAGE and flanked; the rule had been upheld by the outrange heuristic returning `stop`. Now enforced as a rule — squad measured 15.2 m → 0.0 m in a CP4 worktree, and it passes here |
| `scenario_suppression::test_holding_a_crew_down…` (**in `check`**) | **squad** | Pinned crew lands 10 of 11 vs a calm 11 of 11. Suppression's penalty is angular, so closer fights soften it — a threshold to re-derive, or evidence for raising `SUPPRESSION_SPREAD_FACTOR` (mine) once the series says |
| `test_tactics_scenarios::test_support_by_fire_forms_a_firing_line…` (**in `check`**) | **squad** | CP3×CP4: the SBF standoff is keyed on `effective_range`, so narrowed bands put the firing line inside `near_ambush_m` and the two drills alternate every tick (see above) |
| `scenario_cover::…fights_from_cover`, `scenario_motion::…attack_runs`, `scenario_motion::brains_dont_dither`, `scenario_dodge_rate::…`, `scenario_motion::…duel_on_the_move` | **squad** | Outside `check`. All downstream of the same thing: positioning logic written when "in range" and "worth firing" were one number. ~~**Dither (15.6–17.7/min against a bar of 12) is the blocking one**~~ — **RETRACTED: the counter double-counted.** Real 7.8 → 6.2, i.e. dither is *below* the bar and was never the blocker. See line 323 |

Five further `make ai-scenarios` failures are **pre-existing on `a975e262`** and nothing to do with this work —
baseline that suite before attributing anything to a change (it is not in `check`, which is why no baseline existed).

### Next steps, in order

_Rewritten 2026-09-19 (second pass). Round 6's list is done; of the list written this morning, **1, 4 and the
instrument work are done** and the two measurements remain._

_All backlog items are complete as of 2026-09-19: X1–X6, N7 and X7 (stretch). The list below is what round 8
would pick up, not outstanding work._

0. ~~**The matrices**~~ — **DONE**, see *X4 — RESULT*. ~~**X7**~~ — **DONE** from committed evidence, no run needed.
1. **(superseded, kept for the method) The matrices, both maps, both arms.** `ARENA=boulevard`
   (open, 0.64) and `ARENA=yard` (closed, 0.20), each with and without `ABLATE=1`, then subtracted with
   **`make compare-arms`** rather than by eye. Report **per map and per faction, never pooled**; quote both maps or
   neither. The `gangs/scout` question is the same four runs: if the gangs collapse in the ablated arm, the
   directive earned the 23% → 53% swing and CP4 earned none of it.
2. **X7 (stretch)** — the event half is done; one number is left.

**Round-7 debt, unowned:**

- The eight-place `role` taxonomy still has no registry (see *The designator*). The `SQUADS` guardrail is a
  down-payment on one of the eight, not a fix.
- **`match_runner_mode.gd`'s bench spread is still a square clamp** on `DRIVABLE_LIMIT` (M4). Harmless while every
  layout is a square and wrong the day one is not; listed unmigrated rather than quietly left.
- **A killed `make remote` leaves its `make` running on builder0.** `remote.sh` dying locally does not stop the
  remote job, so the orphan holds a heavy-run slot and the next `rsync --delete` overwrites the tree underneath it.
  The orchestrator has this for round 8 (a trapping wrapper, with a test, when nothing is mid-flight) — until then:
  identify by `readlink /proc/<pid>/cwd`, **never by pattern**, and kill the remote side before the local wrapper.
  **"I cannot account for this process" is a reason to leave it alone, not a reason to include it** — I killed my
  own running gate by assuming anything older than my launch was stale, and checks legitimately run 30–50 minutes,
  so that assumption describes most healthy runs on the machine.

### The instruments, and what each one can and cannot prove

Three guards were built this round, and they answer three different questions. Reaching for the wrong one is how
each of them got skipped in the first place:

| Guard | Asks | Cannot tell you |
|---|---|---|
| `run_conditions` (`run:` header) | **which build** produced this | whether the run did what you asked |
| `faction_matrix`'s positive control | **did the treatment engage** in this run — designators fielded vs paints landed | whether the OTHER arm was different |
| `compare_arms` | **are these two runs subtractable** — same build, same question, genuinely different arms | whether a flag that was recorded actually did anything in the sim |

The last cell is the honest edge of all three. A flag accepted, recorded and silently inert still looks fine to
every one of them; only `faction_matrix`'s per-run adherence check reads what the RUN emitted (`MATCH_RESULT`'s
`controls`) rather than what the caller passed, and only for the designator. **Per comparison, against emitted
state, is the version still unbuilt.**

### Merge notes (shared files)

- **The gunnery seam now has a shape to copy.** nav's CP1 landed `game/ai/movement.gd` as *one `Movement` instance
  per `OrderController`*, which is exactly the shape I asked for on the gunnery side — so `Gunnery` should mirror
  `Movement` rather than invent a second pattern: an instance on the controller, `gunnery.apply(cmd, seconds)` after
  the movement half, reading the controller for `tank`, `tanks_root`, `weapon_order` and `move_order["type"]` (the
  last only so a fixed-mount hull can swing onto its target when halted). **Seconds, not ticks** — the acquisition
  timer is booked in seconds and must stay that way at any tick rate (lesson 30). The ten methods and eight pieces of
  state to move are listed verbatim in `_agents/streams/nav.md`.
  *Merging CP1 was a live test of this:* nav restructured `order_controller.gd` around my edits (moving
  `_apply_unstick` into `Movement`, adding `movement.idle()` next to my `engagement_lay.forget()`), and all 25
  envelope tests still passed — including the four wiring tests that exist to fail if the gates are dropped.
- `game/ai/order_controller.gd` (nav's): five call sites, all in the **direct-fire** path — the `seen` gate in
  `_shootable`, one member, the trigger line and the lost-lay line in `_apply_weapon`, and `forget()` on death, plus a
  `_seconds_step()` helper. **No movement code touched.** `_apply_indirect` (artillery) and `_apply_suppress` (L2 fire
  at ground) are deliberately untouched — verified, not assumed. The orchestrator recorded this as a named exception
  (`f662d304`) because nav had no session; the seam nav should build is in `_agents/streams/nav.md` verbatim.
- `game/ai/tank_brain.gd` (squad's): `5478fa61` only, **a proposal to take, replace or revert.**
- `tests/ai_scenarios/ai_scenario.gd` (squad's): `shooter()` defaults to `long_shot: true` — squad chose this option
  and made the same change on its own branch, so expect a trivial identical conflict; take either.
- `game/modes/match_runner_mode.gd` (mine): `--no-acquisition` and `--no-crossing`, measurement controls.
- `mk/match.mk` (mine): `VARIANT_FILE` / `SEARCH_UNITS` renames. **`9f798368` and `fd5ac1af` have no dependency on the
  envelope and can go to `main` on their own** (lesson 9).
- **The sim baseline moves, and combat deliberately does NOT record it.** Ranges *are* the simulation, so N5 changes
  the hash — but round 6 made this invariant 2: the orchestrator records it once on `main` after the last
  simulation-changing merge. Three streams moved it this round. The laptop is glibc 2.39 and has no line in `tests/baselines/sim_state_hash.txt`, so `sim-baseline` **skips
  locally** and only the remote check ever tests it. Do not read a green local check as covering it.
