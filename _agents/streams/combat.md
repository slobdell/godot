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
| `scenario_motion::test_brains_dont_dither` | 17.7 / 15.6 option switches per minute against a bar of 12 | **The blocker.** Legibility is product constraint #1 |
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

### X2, first finding: shortening the bands may have taken the bite out of suppression

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

### Infra: `make engagement` was broken, and `make matchup-search` silently wrong (`9f798368`)

`mk/ai.mk` sets `VARIANTS ?= r1,a4,a6` (brain-variant *names*). **A make variable set in any `mk/*.mk` is global**, and
`mk/match.mk` used the same name for a *path to a JSON file*, so `$(if $(VARIANTS),…)` was always true and always
wrong — `make engagement` died on `FileNotFoundError: 'r1,a4,a6'`, which is the exact command
[references/combat/README.md](references/combat/README.md) gives for reproducing the round-5 baseline. *A "reproduce
with" line nobody re-runs is a claim, not a reproduction.* `matchup-search` took the same collision **silently** and
would have searched three brain names instead of the file you meant. Both now take `VARIANT_FILE=`. `mk/ai.mk` is
untouched: the bug is two makefiles claiming one name, so the newcomer moves. **Name make knobs after the target that
owns them.** No dependency on the envelope — cherry-pick to `main` on its own (lesson 9).

### X5 — the duplicated Lancer (proposal, for the orchestrator to relay)

**The Syndicate should lose `syn_lancer`; the Condemned keep `lancer`.** The reasoning is the engagement envelope
itself. Post-CP4 the Syndicate already fields the longest reach in the game — `syn_tank`'s railgun covers **104 m**,
more than any other unit — so a second long-range specialist at 86 m duplicates a job that faction already does
better than anyone. The Condemned have no other unit past 45 m, so the Lancer is the *only* thing that stretches their
line, and removing it there would flatten the faction into one band. Dropping `syn_lancer` also removes the roster's
only case of two units sharing a weapon (`laser`), which is what made the duplication visible in the first place.
Not blocking: both still exist until the lead rules.

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

# 3. Only after the bands are settled: move the sim baseline (it WILL move; ranges are the simulation).
make remote T=sim-baseline-record    # twice, confirm the two agree
cp build/sim_state_hash.txt tests/baselines/sim_state_hash.txt   # builder0's glibc line is the canonical one
#    The laptop is glibc 2.39 and has no line in that file, so `sim-baseline` SKIPS locally and only the
#    remote check ever tests it. Do not be reassured by a green local check.

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

### Merge notes (shared files)

- `game/ai/order_controller.gd` (nav's): the four edits above, all inside `_apply_weapon` / `_shootable` / the var
  block. No movement code touched.
- `game/modes/match_runner_mode.gd` (mine): `--no-acquisition`, a measurement control.
- **The sim baseline moves** (invariant 2 says combat may): ranges *are* the simulation.
