# Legibility: the A6 motion law (contract S4)

> **Status: DRAFT, awaiting signatures.** Owner **feel**; signatories **control** and **nav**.
> **No stream writes A6 motion code until all three signatures are on this page** ([workstreams.md](workstreams.md),
> contract S4). Until then the page is the whole deliverable.
>
> Sources: [research_catalog.md](research_catalog.md) row **A6** (Dragan, Lee & Srinivasa 2013, *Legibility and
> Predictability of Robot Motion*, ACM/IEEE HRI) · [navigation.md](navigation.md) *A7's priority table* ·
> [workstreams.md](workstreams.md) contracts **S3** (the metrics this is measured with) and **S4**.

| Signatory | What signing means | Signed |
|---|---|---|
| **feel** (author) | the law below is what "looks obedient" means, and feel will not ask for a different one mid-round | 2026-09-20 |
| **nav** | the law is executed as **level 3** of A7's priority table, claiming the freedoms named in §4, and nav will not express it as an additive term | *pending* |
| **control** | the readout in §6 is what the player is shown, and control will build it | *pending* |

---

## 1. The problem this is, and the problem it is not

The lead's oldest and most repeated complaint is *"they still generally don't do what I command them."* Every round
so far has read that as **obedience** — a UI problem, or an order-plumbing problem — and round 8 fixed real bugs of
that kind (drills aiming at `Drills.nearest_visible` instead of the task's target; five kinds of refused order
returning their reason to nobody). The complaint survived all of them.

**A6's claim is that the residue is not disobedience. It is illegibility.** Dragan et al. separate two functionals
that we have been treating as one:

- **predictability** — the trajectory is the efficient one for the goal the unit actually holds;
- **legibility** — an observer watching the *first part* of the trajectory can infer which goal the unit holds.

A unit that circles its target at 40 m while suppressing it is *predictable* and *correct*, and it is **illegible**:
for a third of the time its velocity points away from where the player sent it. Pathology **P7** is that measurement
— **30–36% of attack-moving time is spent with velocity opposing the ordered corridor**, on all four maps, measured
in round 8 and pre-registered before the run. Nothing in that number is a bug. That is the point, and it is why
another obedience fix would not have moved it.

**What this is not.** A6 is not a new order type, not a stance, not a toggle, and not a slower unit. It does not make
a unit go where it was sent *more*; it makes a unit that is already going there *look* like it is.

---

## 2. Definitions, so all three streams measure the same thing

**The ordered corridor** is the path `nav` is currently driving, not the straight line to the goal. Precisely: the
current leg of `Movement.state(unit)["path_points"]` (contract **N1**) — from the unit's projection onto that leg to
the next waypoint. One definition, one publisher: the law, the readout and the falsifier all read `path_points`, and
nobody recomputes a corridor of their own. When `path_points` is empty (no path yet, or `blocked`), **the law is
inactive** and says so — see §5.

**The corridor tangent** `t̂` is that leg's unit direction, flattened to the ground plane.

**The nose** is the hull's forward vector (`-Z`; [orientation.md](orientation.md) trip-up 2), not the turret's.

**Off-corridor velocity** is a tick whose ground velocity has a negative projection on `t̂` while the unit holds an
unreached move/attack-move goal and its speed is above the creep threshold. The **time fraction** of those ticks,
per unit per match, is P7's 30–36% and A6's falsifier.

**Turreted / hull-fixed** is `Units.PROFILES[id]["mount"]`: `"turret"` or `"fixed"`. Today that is **18 turreted**
(tank, ifv, artillery, lancer, burner, gang_ifv, gang_tank, gang_artillery, gang_support, law_ifv, law_tank,
law_artillery, law_suppressor, syn_scout, syn_ifv, syn_tank, syn_artillery, syn_lancer) and **3 hull-fixed**
(scout, gang_scout, law_scout). The law binds by `mount`, never by a unit id list; a new unit is bound the day it
is added. *(Counted on `stream/feel` at `9f864474`; the count moves with the roster, the rule does not.)*

---

## 3. The law

**A6 has two clauses. They are not the same clause and they do not live in the same place.**

### A6-a — the nose clause (heading)

> A **turreted** hull with an active ordered corridor keeps its nose within **25°** of the corridor tangent `t̂`
> whenever the levels above it leave the heading free, and lets the turret do the fighting.
>
> A **hull-fixed** hull is not held to the corridor — its hull *is* its gun mount — but is held to
> **forward-oblique bounds**: its nose stays within **75°** of `t̂`, so it never drives a leg backwards or
> broadside, and every leg visibly advances.

25° is the figure the round-8 handover carried and it is not arbitrary: it is about the angle at which a viewer at
the lead's 35° telephoto stops reading a hull as "heading that way". It is a **tolerance at level 3**, not a hard
clamp — see §4. 75° for hull-fixed is the weaker bound that leaves a `standoff` hull free to lay its gun anywhere
in the forward hemisphere while still advancing.

### A6-b — the shoulder clause (velocity)

> When a unit must move off the corridor to satisfy a weapon band or survival, and **both shoulders are equally
> good** for that purpose, it takes the shoulder whose velocity has the **non-negative** projection on `t̂`.

**A6-b is the clause that moves the falsifier, and it is the reason this page exists rather than a one-line brief.**
The falsifier is measured on **velocity**, not on heading. For a turreted hull the nose is *already* free of the
gun, so A6-a alone changes almost nothing a player can measure: the velocity is chosen at levels 1, 2 and 5, and the
nose follows it. A law that constrains only the nose would pass its own review and leave P7 at 30–36%.

Circling is the concrete case. A unit orbiting its target at the band radius can orbit either way. One way carries it
along the corridor and one way carries it back down it; today the choice is made by `WEIGHTS["tangent"]`, `side`,
`flank` and `continuity`, none of which has ever heard of the corridor. **A6-b claims exactly that choice.** The
circling round 3 bought is untouched — it is the *shoulder* that is claimed, not the circling.

### What A6 does NOT claim

- It never overrides the weapon band or survival (§4).
- It never adds speed, removes speed, or lengthens a path. It reorders choices that were already free.
- It says nothing about the turret. A turret aims where gunnery says; A6 exists so the hull stops arguing with it.

---

## 4. Who executes it: level 3 of A7's priority table

nav's table ([navigation.md](navigation.md), *A7's priority table*, `stream/nav` at `7edec4fb`) places A6 at
**level 3 — ARC / ARMOUR**: above formation, below the weapon band and survival.

**feel confirms level 3. The law does not outrank the standoff band, and must not.** Three reasons, recorded so this
is not re-argued in round 10:

1. **The falsifier forbids it.** A6's bar is *"off-corridor time 30–36% → under 10%, **without a fall in exchange
   ratio**"*. Putting a heading law above the band is the single most direct way to lose the exchange ratio. If units
   look obedient and start dying, we bought the wrong thing, and A6 says so in its own row.
2. **For hull-fixed hulls, above the band is an anti-goal.** Their hull is the gun mount. A law that pointed a
   `standoff` scout's nose down the corridor while the enemy was off to the side would stop it shooting. That is why
   A6-a holds hull-fixed hulls to a *bound* (75°) and not to the corridor.
3. **For turreted hulls the conflict is nearly empty anyway,** which is what makes level 3 cheap rather than a
   concession. Level 2 constrains the **radial** component and — in nav's own words — *"leaves the whole tangential
   component"* free. A6-a wants the nose; A6-b wants the sign of the tangential step. Neither is radial. A turreted
   hull can hold the band and hold the corridor at the same time nearly always, and the ~never case is exactly the
   case where we want the band to win.

### The one change feel asks for in the table

Level 3's null space is written as *"the sign of the arc (either shoulder), and all speed"*.

> **A6 claims the sign of the arc.** Level 3's remaining null space is **speed alone**.

That is A6-b, and it is the difference between A6 mattering and A6 being cosmetic. It is a one-line change to the
table's *Null space* cell, not a new level and not a new term. `TOLERANCE[3]` remains nav's: A6 wants it **banded,
not dictatorial** — prefer the advancing shoulder unless the retreating one is better at level 3's own cost by more
than the tolerance — so that a unit is never wedged into a worse arc for the sake of a tidy line.

### Composition inside level 3, with the arc/armour task

Level 3 already holds *"front toward threats; the angle style's side-on guard"*. A6-a is a second heading task at the
same level, so their precedence must be written down rather than discovered:

| Style (units) | Inside level 3 | Why |
|---|---|---|
| `strafe` — turreted, front armour < 6.0 (**10 units**) | **A6-a alone.** Armour is demoted to level 5 for turreted hulls by nav's own style table, so there is nothing to compose with | the turret aims independently; the hull is free and legibility is the only claim on it |
| `angle` — turreted, front armour ≥ 6.0 (**8 units**: tank, ifv, burner, gang_tank, law_ifv, law_tank, law_suppressor, syn_tank) | **armour first, A6-a in its null space.** A6-a holds only where the side-on guard has already been satisfied | a thick front toward the shooter is worth more than a tidy line, and it is also *legible* — a heavy squaring up to a threat reads as deliberate, not as disobedience |
| `standoff` — hull-fixed (**3 units**: scout, gang_scout, law_scout) | **armour/lay first, then A6-a's 75° bound** | the hull is the gun mount; the bound is what is left |
| `run` (the A/B control) | **A6 does not apply.** The control stays a control | a control that is also rewritten is not a control ([orchestration.md](orchestration.md), and nav's own note) |

A6-b applies to all three real styles, unchanged.

### Invariant 0c — what A6 replaces

**Nothing is removed, and that is a claim this page has to defend rather than assert.** There is no heading law and no
corridor concept anywhere in the motion code today: a hull's heading is a by-product of the velocity `CombatMotion`
chose, laid in by `TankMotion.yaw_toward`. The nearest thing to A6 is `PENALTY_SIDE_ON` / `ANGLE_MASK_COS`, and
**nav's A7 already deletes that constant** and re-expresses it as level 3's arc task for the `angle` style — so A6-a
does not replace it either; it composes with it, as the table above says.

**The honest form of the claim:** A6 replaces nothing, and therefore A6 is an *addition*, and therefore A6 must earn
its place on its falsifier alone. Its cost is one level-3 cost term over an already-built candidate ring, evaluated on
candidates that survived levels 1 and 2 — a dot product each, which is what the catalogue means by *"dot-product
weighting, closed form"*.

---

## 5. When the law is inactive, and why that must be visible

A6 is active only while a unit holds an unreached ordered goal *and* `path_points` gives a current leg. It is
**inactive** — with no fallback, no guessed corridor — when:

- the unit has no order (holding, or its task is complete);
- `Movement.state(unit)["phase"]` is `"blocked"`, or there is no path yet (`Pathing.is_ready()` false, the
  straight-line fallback);
- the unit is under a reflex that owns its heading for the tick (dodging a round, a reverse out of contact);
- the style is `run`.

**An inactive law must never look like a broken law.** Round 8 shipped a facing feature that could not fire at all
on the lead's control scheme (lesson 149) and it read as "the feature does nothing" rather than "the feature is off".
So: every unit-tick carries whether A6 was active, and if it was not, which of the above it was. control's readout
(§6) reads that flag; the falsifier (§7) is computed **only over active ticks**, and reports the active fraction
beside it. A falsifier that improves because the law switched itself off more often is not a pass.

---

## 6. What the player is shown (control's half)

Legibility is a claim about a **viewer**. A law that cannot be seen at the lead's camera has not been tested, and
the only check that counts for "does it read as obedience" is a human looking at it.

control owns this; feel is asking for three things and nothing more:

1. **The corridor, drawn.** The ordered path leg for the selected element, at the lead's 12° and 35° poses. The
   player cannot judge "on the corridor" against a corridor nobody drew. Round 8's order markers are the seam.
2. **Attribution when the law gives way.** When A6 is overridden by level 1 or level 2 — the case the player
   experiences as *"it stopped doing what I told it"* — the existing "why did my element do that" line says so, in
   the vocabulary already shipped (*taking fire*, *holding range*), not in the vocabulary of this page. **This is the
   part that matters most**: the lead's complaint is about attribution, and a unit that breaks off *for a reason the
   player can see* is not disobedient, it is professional.
3. **Nothing new on the command card.** A6 is not a button, a stance, or a toggle the player sets. If it needs UI the
   player operates, it is the wrong feature.

**The A/B control's prerequisite:** control's desktop right-drag facing lands first regardless of this page
([workstreams.md](workstreams.md), S4), because without a way to *order* a facing there is no way to A/B one.

---

## 7. The falsifier (joint; feel, nav and control all fail together)

Pre-registered, in full, before any code:

> **Time fraction with velocity opposing the corridor tangent, under attack-move, over active ticks:
> 30–36% → under 10%, with no fall in exchange ratio.**

- **Measured with A12 and nothing else** (contract **S3**, metrics' `tools/metrics/`). The quantity is a
  trajectory-space statistic and A12 exists so every stream reads it from one implementation.
  **CP1 before any verdict** — build and iterate before it, publish after.
- **Baseline: 5.3–7.2% oscillation / 30–36% off-corridor, round 8, four maps, pre-registered.** The raw data is in
  `_agents/streams/references/round8/`. Every number cites its commit and its machine (the laptop is ~2.75× slower
  than builder0).
- **Exchange ratio** from combat's existing match series, same doctrines, same maps, same seeds, across the same
  commit pair. **A fall in exchange ratio fails A6 outright**, however good the first number looks.
- **Reported beside both: the active fraction** (§5), and the off-corridor number for `run`-style units as an
  untreated control.
- **And the frames.** The falsifier is necessary, not sufficient: the claim is *"it reads as obedience"*, and for
  anything subjective a human is the only check that counts. The number and the lead's verdict are reported together.

**Pre-registered revert:** if off-corridor time falls below 10% and exchange ratio falls at all, A6 comes out with its
switch, the way flow fields, the gear-change cost and the target-switch floor came out in round 8. Three things were
built, measured and thrown away that round, and all three were cheap because they were measured before they shipped.

---

## 8. Open questions

- **`TOLERANCE[3]`'s value** is nav's, and it is the knob that decides whether A6-a is a law or a suggestion. feel
  has no measurement to offer on it before A12; asking for 25° is asking for the *shape*, not the number.
- **The 25° / 75° figures are feel's judgement, not a measurement.** They come from what reads at the lead's camera,
  not from a study. If A12 shows the falsifier moving on the shoulder clause alone, the nose tolerance can widen and
  should — that is a cheaper law, and a cheaper law that passes is the better one.
