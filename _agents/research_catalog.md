# The research catalogue: what two external reviews told us, and what we are going to do about it

> **Provenance.** On 2026-09-19 the lead asked for a research brief to be sent to an external planning system:
> *"formulate a prompt for an external agentic system… express the intent of our game, or simulation in completely
> abstract / research oriented terms… a crucial consideration for this planner is to know that we can take advantage
> of AI as much as necessary for offline simulation formulation… return as many design and algorithmic changes that
> would be useful."* He sent it to **two** services and got two independent replies. The brief and both replies are
> kept verbatim in [`research/`](research/) — read [`research/README.md`](research/README.md) first, it carries the
> three cautions that matter.
>
> **This file is the curation, and it is the authority.** The sources propose; this file decides, orders, assigns an
> owner, and says what measurement would kill each idea. It is deliberately shorter than the sum of its sources: 50
> techniques were proposed, 12 are adopted, and the rest are recorded with the reason they are not.
>
> **Companion file:** [`algorithms.md`](algorithms.md) remains the roster of *what we have and what we owe* — one row
> per technique, states `have` / `OWED` / `parked` / `rejected`. This file is the *incoming* research and the
> reasoning behind each verdict. When something here is adopted and lands, its row in `algorithms.md` changes state
> and points back here. Do not duplicate the state in two places (Invariant 0, `workstreams.md`).

## How to read a row

- **[A]** = only Service A proposed it. **[B]** = only Service B. **[A+B]** = both did, independently, from the same
  brief and with no knowledge of each other. **Treat [A+B] as the strongest signal in the whole exercise** — two
  systems converging on the same named technique for the same stated symptom is the closest thing to a second
  opinion we can buy.
- **Verdict** is ours, not theirs: **ADOPT** (in the round-9 backlog), **CANDIDATE** (wanted, blocked on a
  measurement or a decision), **DEFER** (real, not our bottleneck), **REJECT** (with the reason).
- **Falsifier** is the pre-registered bar. Where a source suggested a number we kept it as the bar and marked it
  *(theirs)*; where it suggested none, or suggested one our own instrumentation cannot read, we wrote our own.
  **A bar nobody can read on the configuration a player gets is not a bar** (`orchestration.md`, and §8 of the brief).
- **Pathology** refers to the seven measured pathologies in `research/brief.md` §5, restated here for convenience:

| # | Pathology | The measured number |
|---|---|---|
| P1 | Direction churn under attack-move | **~6% of travelling time**; 70% of it re-planning inside one unchanged decision, 30% genuine switching; **~45 re-aims per agent-minute** |
| P2 | Gear flipping in car-like hulls | **9–19 reversals per agent-minute** inside a 2 s window; a third ordered, a third the multi-point creep, a third unexplained |
| P3 | A veto fails where a preference works | forbidding fast target switches **more than doubled** switch-and-switch-back |
| P4 | Crowd-flow routing was a null | shared cost-to-goal fields answered 70–75% of route requests, changed stuck-time by **−1% over three seeds** |
| P5 | Scale breaks systems silently | the longest cover object is **12.19 m**; the War Rig is **14.0 m**. Cover registers at 0.99 up to 12.19 m and **0.00** at 12.5 m on yard |
| P6 | Clearance is under-modelled | corridor clearance uses hull **width** only; the navmesh is baked with **one** agent radius for a 5× footprint range |
| P7 | Obeying ≠ looking obedient | **30–36%** of attack-move time is spent driving somewhere other than the ordered destination — correctly |

---

## Part 1 — Five findings that change documents we have already written

These matter more than any single technique, because each one corrects something this project currently believes.

### 1. Our rejection of learned policies is over-broad. **This is a lead decision.**

`algorithms.md` *Explicitly rejected* says: *"a learned policy is a large pile of floats evaluated in an order we do
not control, and replays, lockstep and the sim baseline all require bit-identical output."* Both services
independently pointed out that **the float part is a choice, not a consequence** [A+B]. A network trained offline and
exported as `int8` weights with `int32` accumulators and shift-based requantisation is **exactly** reproducible:
integer addition is associative, there is no rounding mode, and there is no libm. Service A cites Jacob et al. (2018),
*Quantization and Training of Neural Networks for Integer-Arithmetic-Only Inference*; Service B reaches the same place
via distillation into fixed-point decision trees (Verwer & Zhang 2019).

**The corrected statement is:** *runtime learning is blocked by determinism; a frozen, integer-quantised artefact
trained offline is not.* The blocker was never "learning", it was **floats inside the tick**.

This was not ours to decide. The lead asked and answered the RL question on 2026-09-19 on a premise that was partly
wrong, and the design pillars are his, so it went back to him.

**✅ RULED, 2026-09-19 — "yes that sounds like a good decision"** ([game_design.md](game_design.md) *Ruling: offline
compute is unlimited; what SHIPS must be readable*). The shape of it:

- **Open:** arbitrarily expensive offline computation, **provided the artefact that ships can be read by a human.**
  That admits **C7** (frozen lookup tables from offline parameter search) and **C6** (decision trees distilled from an
  expensive offline planner) — both now first-class, not speculative.
- **Shut, for now:** neural-network policies, integer-quantised included. Not on determinism grounds; on
  *legibility* grounds. Revisit only if a pathology appears that a table or a tree cannot express.
- **Shut permanently:** runtime learning. That is the part determinism genuinely forbids.
- **⚠ Prerequisite on both C6 and C7: A12 ships first.** Offline optimisation means naming a number to maximise, and
  A12 exists precisely because the numbers we had were measuring the wrong thing. **An optimiser pointed at a bad
  objective does not fail — it succeeds at the wrong thing, faster than we can notice.**
- **No money spent, and no hardware needed.** The game never requires a GPU (integer inference, ~0.6 µs per vehicle
  per tick); a GPU would be the wrong purchase anyway, because the cost is **running our own simulation**, which is
  CPU-bound. builder0 has no discrete GPU and is a 15 W i5-1345U, which is adequate for overnight match generation
  (~120 thread-hours a night, free). If offline tuning pays off, the correct next purchase is **~3,000–5,000
  spot-CPU core-hours for about $50**, not a GPU.

### 2. The flow-field null is explained, and the *right* shared structure is a different object

nav built flow fields in round 8, measured **−1%** on stuck-time across three seeds, and deleted them with their
switch (P4). The reading recorded in `algorithms.md` was: *a flow field buys CPU when an army shares one goal, and a
fight's goals are per-unit.* **Both services say the same thing unprompted** [A+B] — and both then say the useful
shared structure is not a cost-to-goal field at all. It is an **anisotropic** field, solved on a **coarse tactical
grid per squad order** rather than a fine grid per unit, where the metric is not distance but *exposure*: Sethian's
fast marching method (1996) over a speed function that includes threat, skylining and fire-lane crossing angle.

That is a genuinely different proposition from what we built and measured. A flow field answered *"which way is the
goal"*, which A\* already knew. An Eikonal solve answers *"which way is the goal **without being shot**"*, which
nothing in our code currently answers, and it is the missing consumer for `Match.threat_field`, `cover_map` and
`fire_lanes` — three fields we compute every tick and use only for target selection (`algorithms.md`, *Influence
maps*, **partial**). **The null does not generalise to this.** Recorded so nobody cites round 8 to refuse it.

### 3. The veto backfire has a name, a theory, and a principled replacement

P3 is one of this project's better findings: a hard prohibition on fast target switches made switch-and-switch-back
**more than twice as bad**. Our reading was *"suppressing the expression of a decision the scoring still wants stores
up pressure rather than removing it"* — which is right, and Service A supplies the control theory it is a special
case of [A]: **multiple-Lyapunov-function switched systems** (Branicky 1998; Liberzon 2003). A switched system is
stable when each switch pays a cost related to the energy the switch *destroys*. A hard dwell timer does not do that.
It blocks the switch while the preference keeps integrating, so the switch fires the instant the timer clears — which
is precisely the doubling we measured.

The replacement is a **state-dependent switching cost**, not a timer: permit `i → j` only when the utility advantage
exceeds the physical work the switch throws away — braking energy plus turret/hull slew. A light scout switching
targets 10° apart pays nearly nothing and switches freely; a 14 m rig that must shed 12 m/s and slew 140° pays a lot
and commits. **One expression, no per-class tuning, and it scales itself across a 5× roster** — which is the thing our
flat commitment bonus cannot do.

**⚠ And 1.35 was REVERTED to 1.15 before round 8 closed — read this before adopting A2, because squad has already
handed it a falsifier.** The knee looked clean on the metric (switches 18.1 → 12.7, reversals 0.30 → 0.17 per
unit-minute) and a 48-match ladder said it does not lose. **Two behaviour scenarios then failed on it:** a squad stops
concentrating its fire (focus share equal to brains-alone, i.e. squad tactics buy nothing) and **a scout stops working
onto engine decks — 41 hits / 23 on the deck → 3 / 0.** A win/loss ladder cannot see either. 1.35 survives only as
variant `x5c`.
**So A2 must not buy churn reduction at that price, and those two scenarios are its acceptance test, ready-made.**
This is also the clearest case we have of optimising a proxy: the metric improved and the behaviour degraded.

### 4. The 12 m-vs-14 m question is the wrong question, and there is an O(1) answer

The lead has an open decision: shrink the War Rig to 12 m so it fits our longest cover object, or keep it at 14 m and
lose cover entirely on yard (P5: **0.99 at 12.19 m, 0.00 at 12.5 m** — a step function, because cover is registered
by sampling the hull's *centre point*). Service A's Technique 22 removes the decision [A]: define a vehicle's cover
fraction as the **line integral of point-occlusion along its own hull centreline**, and evaluate it by differencing
**directional summed-area tables** precomputed over K = 8 canonical headings. That is **two array lookups and a
subtraction, independent of hull length** — 2.8 m and 14 m cost the same, and the answer is a *fraction* rather than
a boolean, so "half in cover" becomes expressible instead of rounding to *at cover*.

Service B arrives near the same place from the other side with swept-volume capsule clearance (Schulman 2014) and
shadow extrusion [B]. **The step function is an artefact of point sampling, not of the arena.** Told to the lead
plainly: he should keep the rig at 14 m because it looks right, and we should fix the query.

### 5. Reeds–Shepp stays parked, but the reason it is parked is now a better reason

`algorithms.md` parks Reeds–Shepp because its only measured symptom — a 20.7° heading overshoot — turned out to be an
angle-wrap bug in the reporter. Correct, and both services now supply the *forward* argument for not reaching for it
first [A+B]: Reeds–Shepp paths are **curvature-discontinuous**. They concatenate arcs and straight lines, so a
car-like hull must change steering angle instantaneously at every join, which no physical vehicle does and which our
plant will express as exactly the visible correction the lead complains about. The established fix is **clothoids /
Euler spirals** — curvature *linear* in arc length (Fraichard & Scheuer 2004) — and where reverse genuinely helps, a
**cusp-penalised** variant that prices a gear change rather than forbidding one. Both files say *penalise, do not
prohibit*, which is P3's lesson arriving in the geometry layer.

**So the un-park is not "build Reeds–Shepp".** It is: build continuous-curvature primitives, price cusps, and let the
planner choose a reversal when it is genuinely cheaper. That is also the honest candidate for P2's unexplained third
of gear flips.

---

## Part 2 — The composition hazard, and the invariant it suggests

Service A ran a satisfiability audit over combinations of its own proposals across seven orthogonal architectural
axes and reported that **a majority of combinations of individually-valid techniques violate a cross-layer
invariant** [A]. *(Its specific counts — 9,216 / 2,187 / 906, a 58.57% incompatibility rate — are unverifiable: it
has no access to our code. **Do not quote the digits.** The structural claim is what survives, and it survives on its
own reasoning.)*

The examples it gives are concrete and they are ours. A space-time reservation scheme assumes an agent will execute a
plan it has committed to; an event-triggered replanner assumes it may abandon one at any tick. Each is correct alone.
Together, one agent reserves a corridor slot and the other never arrives to use it. A null-space priority projection
guarantees that safety dominates formation-keeping; an additive context-steering ring guarantees the opposite by
summing them. **Adopt both and you get neither.**

This is the exact shape of lesson 116 — *inertness does not compose* — and it is a real hazard for us specifically,
because this project's whole method is **five or six streams adopting techniques independently in parallel worktrees**.
That is the organisational structure most likely to produce precisely this failure, and no worker is positioned to
see it. The orchestrator is.

> **Proposed Invariant 3 for [`workstreams.md`](workstreams.md):** *Two techniques adopted in different streams must
> be checked against each other before either merges. A technique's brief names the layer it owns, what it assumes
> the layers above and below it will do, and which already-adopted technique it replaces — because **replacing** is
> safe and **adding alongside** is where the two fight.* Concretely: when a stream adopts a row from this catalogue,
> it must fill in that row's **Replaces** column in the brief, and if the answer is "nothing", the orchestrator asks
> the question again.

---

## Part 3 — ADOPT: the round-9 backlog

Twelve. Ordered by (measured pathology it attacks) × (smallness of mechanism), which is the project's own
preference ordering. Every one is deterministic by construction: closed form or a fixed iteration count, no
convergence test, no wall clock, no float reduction order.

### A1. Self-triggered replanning — a state-error tube instead of a fixed rate
**[A]** · Tabuada (2007), *Event-Triggered Real-Time Scheduling of Stabilizing Control Tasks*, IEEE TAC 52(9) ·
**Stream: nav** · **Pathology: P1**

When a plan is computed at state *x(t_k)*, also compute the radius within which that plan stays near-optimal. Skip
replanning entirely while the agent stays inside the tube. **Replaces** our fixed-rate repath and re-aim.

*Why first:* P1 decomposes as **70% re-planning inside a single unchanged decision**. That is not a decision problem,
it is a *cadence* problem, and this is the smallest mechanism that addresses it — a norm comparison against a stored
threshold. It also directly answers open question 2 from the brief (*is there a principled re-decide cadence?*) with
"yes, derived, not tuned".
**Determinism:** integer squared-norm comparison. No state.
**MEASURED IN ROUND 9 (nav, 2026-09-20, provisional pre-CP1): a negative result that relocates P1.** The fixed
route cadence (`REPATH_SECONDS`) accounts for **~3% of re-plans** in a fight, so A1's tube on the route replanner
cannot move P1. The cause split then found the real driver: **968 of 2,059 re-plans (47%) were nav re-planning against
a goal it was already regulating** — a follower's station sliding ~1 m — fixed with a tolerance that scales with the
remaining route (out of squad's `following` observation). The brain's `MOTION_REPLAN_TICKS` half remains squad's — **measured (squad `1a797642`, 05:40, laptop, merged
tree, `make squad-decisions TUBE=on|off`, seed 3, 120 s, yard, 34 GREEN brains):** re-decides 5514 → 2076
(**−62.3%**, the bar met), motion-internal jumps −17.2% (an independent instrument, pre-registered), switches per
unit-minute **20.5 in both arms to the decimal** and reversals 0.4 in both — the latency guarantee holds in a fight,
not only in the unit test. **And it ships OFF:** GREEN finishes 29 of 34 against 33 of 34, RUST untouched at 41 both
ways, one seed. Held share 0.46 → 0.81 means the tube holds plans against a world four times staler. Gate
pre-registered in squad's brief: the same A/B over ≥ 5 seeds reporting GREEN losses and exchange ratio beside the
counts; flip only if losses are flat within seed noise. *"The instrument that can finally see the mechanism is the
one that tells you not to ship it."*
**Falsifier:** intra-decision re-plan rate drops **≥ 60%** (theirs: ≥ 80%) *and* path-tracking error stays within
**0.15 m** *and* reaction latency to a new contact stays **≤ 2 ticks**. If churn falls but latency rises, this is
stubbornness wearing a hat and it reverts.

### A2. State-dependent switching cost (multiple-Lyapunov dwell)
**[A]** · Branicky (1998), IEEE TAC 43(4); Liberzon (2003), *Switching in Systems and Control* ·
**Stream: combat** · **Pathology: P1, P3**

Permit an option switch only when its utility advantage exceeds the physical work the switch discards — braking
energy plus slew. **Replaces** the flat commitment bonus (**1.15** on `main`; 1.35 was reverted — see Part 1 §3) and any dwell timer.
**Acceptance is not just the churn metric:** squad's two behaviour scenarios (fire concentration, and a scout's
engine-deck targeting) must hold, because that is exactly what the 1.35 knee cost.
**Determinism:** four multiplies and two adds, stateless.
**⚠ CORRECTED IN ROUND 9 (combat, 2026-09-20): braking + slew is not the whole of what a weapon switch destroys.** A
stationary turret swapping between two targets on the *same bearing* prices at exactly zero under the two catalogue
terms, and squad's `test_brain_decide::test_commitment_prevents_flip_flopping` is precisely that case. The third thing
a switch throws away is **the gun's lay** — N5's own acquisition gate (`Engagement.acquire_seconds`) invested in the
target being abandoned. Added from `Engagement`'s constants, **backward-looking on purpose**: a crew laid on nothing
pays nothing, so taking up a newly seen contact is never made slower and the ≤ 2-tick reaction criterion is untouched.
**Round-9 measurement note (combat, 2026-09-20, provisional until CP1):** the control arm is proven — `switch.price=0`
runs the same code path, consulted 0.92–0.99 of thinks, flips exactly 0.000 decisions; the live arm changes 6–23% of
decisions. Both acceptance scenarios hold (focus 100% vs 69% unchanged; engine deck bit-identical at 23/41/45). **One
regression found by looking past the acceptance:** a "stance floor" that charged any option change on one target
(added to price ENGAGE↔SUPPRESS thrash, not in the catalogue) cut the turreted duel's **flank seconds 60%** — it taxes
ENGAGE→FLANK, which is *prosecuting* the fight, not changing one's mind; the 1.35 knee's exact shape, against a
behaviour the lead named in round 3 (*"no intent of trying to circle your opponent"*). Made an arm (`switch.stance=0`)
with `option_share` and `transitions_per_unit_min` columns so a suppressed manoeuvre is visible; if it costs flanking it
goes. **P3 is measurable for the first time:** `main`'s commitment was two mechanisms (flat bonus + hard dwell timer),
now split (`switch.dwell=0`) into the triplet none / flat / flat+dwell.
**Correction to the orchestrator's premise (combat, same day):** the lay term is charged only when the *target*
changes, deliberately — a suppressing crew is still firing at that contact and has not abandoned its acquisition. So
if the stance floor goes wholesale, **ENGAGE↔SUPPRESS on one target is priced at exactly zero** (same bearing, same
target, no lay), and that pair is one of round 7's two measured thrash shapes. **Predicted, not to be discovered.**
The sharper reading of `_act` (`tank_brain.gd:1833`, `:1845`): SUPPRESS *halts* inside the band (standing still is
what makes fire effective) while ENGAGE and FLANK keep manoeuvring — so ENGAGE→SUPPRESS genuinely discards the
velocity in flight and ENGAGE→FLANK does not. **If the removal arm shows the floor buys something, the velocity
discard is charged only for options that fight from a standstill (SUPPRESS, COVER_FIRE's hide/peek, BOMBARD), a
physical property of the option read in one place — never a per-class knob.** Order: removal arm first; the
halting-option form is a third arm only if removal costs reversals more than the flank seconds are worth.
**FIVE-ARM TABLE (combat, 2026-09-20, laptop `a1209857`, yard, seeds 1/3/7, `gang_ram` vs `law_line`, 120 s, 15
runs):** switches per unit-minute, tank class — cost (A2) 20.7, cost-nostance 20.4, flat 12.8, flat+dwell (`main`) 12.7,
none 31.3; other classes the same ordering. Three results: **(1) the stance floor bought nothing** (−1% to +23%,
no consistent sign) — removed; ENGAGE→SUPPRESS on one target is priced zero and asserted as deliberate. **(2) The dwell
timer is inert**: flat vs flat+dwell is −11% to +6% — all of `main`'s churn suppression is the flat bonus, and
`MIN_COMMIT_TICKS`/`EMERGENCY_MARGIN` are retired for free. **(3) A2 is a weaker suppressant than the flat bonus it
replaces**: +47% to +79% more switches than flat, −7% to −34% fewer than none; the −60% bar is missed in the wrong
direction. Whether the extra switches are genuine re-targeting or the wheeled creep is metrics' cusp split to answer
(switch-event files with predicted angle/slew/brake/lay per event). **combat's mechanism claim corrected by its own
instrument:** FLANK's time share is 0.000–0.018 in every arm; the duel's flank seconds are `_combat_move`'s circling
*inside* ENGAGE, and the live candidate is tanks' ENGAGE share 0.319 (cost) vs 0.523 (flat) with COVER_FIRE 0.231 vs
0.094 — A2 moves tanks from circling into static hide/peek. **RULED (orchestrator, overnight): the default ships as
the flat bonus with the dwell timer retired; A2 stays as the opt-in arm with its acceptance scenarios asserted; the
flip waits for the cusp split, then either raise `PRICE_PER_SECOND` and re-measure, or leave it off and say so.**
**Falsifier:** genuine option-switch churn **−60%** and switch-and-switch-back within 4 s below **0.2/agent-min**,
with reaction latency **≤ 2 ticks**. **Guard:** the arm must be distinguishable — assert the switching cost is
non-zero and varies by hull class, or we are A/B-ing a build against itself (lesson 117).

### A3. Hull-chord cover as a line integral over directional summed-area tables
**[A]**, with **[B]** converging via swept volumes · Lozano-Pérez (1983) configuration-space convolution; Darken
(2004), *Visibility and Concealment Algorithms for 3D Tactical Simulations* · **Stream: arena** (tables) +
**combat** (consumer) · **Pathology: P5**

Cover becomes a fraction of hull length occluded, evaluated in two lookups and a subtraction at any hull length.
**Replaces** centre-point cover registration. See Part 1 §4. **This closes a lead decision rather than asking him
one**, which is why it is third.
**Determinism:** integer prefix-sum differences. Exact.
**Falsifier:** exposed hull fraction for units reporting `AT_COVER` drops below **5%** at **every** hull length
2.8–14.0 m, and the yard cover score for a 14 m hull rises from **0.00** to within 0.1 of its 12 m value. **This one
has a positive control we can write today:** the 12.19 m step function is a sharp, reproducible signature; if it is
still there, the treatment did not engage.

### A4. Continuous-curvature clothoid primitives, with priced cusps
**[A+B]** · Fraichard & Scheuer (2004), *From Reeds and Shepp's to Continuous-Curvature Paths*, IEEE T-RO 20(6) ·
**Stream: nav** · **Pathology: P2, and the lead's "manoeuvres should look intended"**

Curvature linear in arc length, so steering rate is bounded and no join demands an instantaneous steering change.
**Replaces** the arc/line concatenation implied by Dubins/Reeds–Shepp and augments the round-8 heading-aware arrival.
See Part 1 §5.
**Determinism:** Fresnel integrals from a fixed-size lookup table with fixed-order interpolation. **Not** a series
evaluated to tolerance.
**MEASURED IN ROUND 9 (nav, 2026-09-20, `nav-fight` yard seed 3, 45 s, default path, laptop `9c5c73ef`):** of 6,364
arrival gates offered, 1,196 were refused, 835 of them `off_mesh`. Probing each refusal at shrinking run-in lengths
splits that one number into two bugs: **474 (57%) would have fitted with a shorter run-in** — cheap but *not free*,
since `APPROACH_RADII` 2.5 is a measured value and at 1.5 radii an IFV arrived 63° off, so 75% of it trades refusals
for unmeasured heading error and needs its own A/B — and **361 (43%) fit at no length tried: the approach corridor is
blocked, and no straight gate reaches them at any length.** **CORRECTED 04:10 (nav):** at the pre-registered 120 s the yard figure is **26%, not 43%** (430 blocked of 1,641
off-mesh; the recoverable class grows faster with run length), **14%** across four maps, and **0% on boulevard, pit and
boneyard** — two of which the player never sees: nav's map set was `FIGHT_MAPS`' default, not `Arena.ROTATION`
(`yard, pit, terminus`), so it screened two unplayed maps and omitted one played one. **Then terminus reported (nav `28653da1`, laptop, 120 s, seed 3) and REVERSED the picture: terminus 806 blocked of
1,468 off-mesh gates (55%), yard 430 of 1,641 (26%), pit 0 — 34% across the rotation, and terminus produces nearly
twice yard's blocked gates**, because 20 m streets between sheer blocks are exactly the corridor a straight run-in
cannot enter off-axis. **The sentence for the lead: the clothoid earns its place on two of the three maps he plays,
and most on the Terminus.** The A/B runs on terminus and yard; pit is refused by nav's own rule. The screened set had
been *bias with a direction*: it held two maps he never sees and omitted the map where A4 is strongest, and pointed
at killing the row. `nav-fight-maps` now reads `Arena.ROTATION` from the code and prints strays and omissions.
**A/B RESULT (nav, 04:50, merged tree `0d8587d6`, laptop, terminus + yard, seeds 1 3 5 7 9, 120 s, arms labelled by
treatment): A4 FAILS its pre-registered bars and the default stays OFF, on measurement.** Positive control: yard
**100% of blocked gates reached on every seed** (423/423 … 729/729); terminus **0–13%** — the fan generates hundreds
of curves per run and on terminus they do not land on the navmesh: a clothoid works by *leaving the approach axis*,
which needs lateral room, and 20 m streets between sheer towers have none. The bars: `net_over_path` down in 11 of 16
wheeled-type seed cells, `oscillating_share` up in 9 of 16, and the fight guard breached on 3 of 10 seed-runs — worst
on yard (−14.4%, −12.8%), **the map where the mechanism succeeds completely: the better A4 works, the more it costs.**
Routing to a curved gate buys the gate and spends the fight. Bounds on the instrument: `off_mesh_fit.none` counts
events not gates, and the seeds are not replicates (gates offered 9,077–57,078), so no mean across seeds is reported.
This does not retire the primitive: it retires *this consumer* (the arrival arc aiming a gate). **The missing test, built (nav `032953eb`, 06:00, terminus, one wheeled hull, a goal blocked at every straight
length, both arms on one shared arena): the straight arm arrives in 4.3 s (61° heading error, 4.0 m short); the
curved arm does NOT arrive in 45 s, ending 147° off and 9.8 m short.** A4 turns an arrival into a non-arrival with
the hull nearly reversed. That re-reads the A/B's guard breaches: at least some of the "cost" is hulls not getting
there — same direction, worse mechanism. The fixture finds its own blocked case and refuses a run where terminus
offers none. (A first version built terminus once per arm, the navmesh failed to sync, and the number read 27 m; on
one shared arena it is 9.8 m: a measurement on a degraded navmesh is not a measurement.) **Rule before anyone builds it:** the
shorter run-in and the clothoid fix *different* failures and are never shipped together or credited to each other
(round 7's shape: ship, measure twice, find the mechanism was never reached).
**POSITIVE CONTROL PASSED (nav, 2026-09-20, laptop, provisional pre-CP1): 403 of 403** blocked-corridor gates — the
class no straight run-in reaches at any length — are reached by a curved clothoid entry, reported as that class only
and never as the aggregate aimed count, so the run-in half cannot leak into it.
**Falsifier:** signed cusp density below **1.5 per agent-minute** with **zero unexplained cusps** (currently 9–19,
a third unexplained), and peak steering rate never saturates on a nominal traverse.

### A5. Anisotropic fast marching for route *selection* over the influence fields we already compute
**[A+B]** · Sethian (1996), PNAS 93(4); Tsitsiklis (1995), IEEE TAC 40(9) · **Stream: nav** (solver) +
**squad** (caller) · **Pathology: the unused fields; and P4's real lesson**

Solve the Eikonal equation on a coarse tactical grid **per squad order**, with a speed function penalising threat,
skylining and shallow fire-lane crossings. Routes then hug defilade and cross open ground perpendicularly.
**Replaces nothing** — it is the missing *consumer* of `threat_field` / `cover_map` / `fire_lanes`. See Part 1 §2.
**Determinism:** upwind stencil with a fixed-point priority queue ordered by cell index on ties.
**Falsifier:** cumulative incoming line-of-sight exposure integral over a flank order drops **≥ 35%** (theirs: ≥ 45%)
for **< 15%** added transit time. **Pre-registered revert:** if exposure falls and transit rises more than that, it
is a null like flow fields and it comes out with its switch.

### A6. Legibility as an explicit objective, plus a dual-heading law
**[A+B]** · Dragan, Lee & Srinivasa (2013), *Legibility and Predictability of Robot Motion*, ACM/IEEE HRI ·
**Stream: feel** (motion) + **control** (readout) · **Pathology: P7**

Predictability and legibility are distinct functionals: legibility maximises an observer's posterior on the *ordered*
goal early in the trajectory. Concretely for us — a **turreted** vehicle fighting off-axis keeps its hull nose within
~25° of the ordered corridor tangent and lets the turret do the fighting; a **hull-fixed** vehicle is constrained to
forward-oblique bounds so every leg visibly advances toward the destination.
*Why this matters here:* P7 is the lead's oldest complaint (*"they still generally don't do what I command them"*) and
we have been treating it as a UI problem. **It is a motion planning problem**, and the brief guessed as much.
**Determinism:** dot-product weighting, closed form.
**Falsifier:** time fraction with velocity opposing the corridor tangent under attack-move drops from **30–36%** to
**< 10%**, *without* a fall in exchange ratio. If units look obedient and start dying, we bought the wrong thing.
**Baseline measured by the judging instrument (nav `c025bc6b` for yard and pit, `5369bd13` for terminus — one Status
file apart, verified by diff, and metrics' `--pool` banner caught it; builder0, A12 `--order-verb attack_move --team 0`,
`Arena.ROTATION`, FIGHT_SEED=3, 120 s each, pure default path):** off_corridor yard **0.304** (active fraction 0.631,
28,472 active ticks), pit **0.321** (0.595, 25,764), terminus **0.331** (0.738, 41,818); **pooled 0.320**, weighted by
active ticks over 96,054 (a mean of the three fractions gives 0.319 today and diverges the day one map dominates, so
the weighted pool is the method). All three inside the pre-registered 30–36 %, spread 0.304–0.331, and that spread is
the finding: terminus had 806 blocked gates against pit's zero, yet the off-corridor fraction agrees to three points,
**so the pathology A6 targets belongs to the movement layer, not to a map.** A6 is a roster-wide row, the opposite of
where A4 landed. Taken while A6 is inert, the only window where the mechanism cannot shape its own baseline. **Quote
the active fraction beside the fraction, always:** A6 can act on 59–74 % of ordered ticks depending on the map
(inactive, slow and S4's arrival-arc obedience excluded), so its *opportunity* is map-dependent though the pathology
is not, and "< 10 % over active ticks" is a weaker claim than "< 10 % of the fight"; the falsifier is read over the
whole fight. Per hull on yard: ifv 0.373 (active 0.664), lancer 0.436 (0.407), tank 0.255 (0.692); `arc_live`
164 s / 171 s wheeled, 0.0 s tracked (a measurement, not an absent field: a tracked hull is never offered an arc).
The three logs (~100 MB each) are in nav's session scratchpad; the targets wipe `build/`. **12:45: `p7-pit.jsonl`
on the laptop has ONE FLIPPED BIT (line 143,873, `0x78 → 0xf8` inside the key `slot_x`; metrics' reader now refuses
with file, line and byte), on a STALE copy in the laptop's `build/`; nav's copies taken out of `build/` after each run parse clean line by line, and metrics' re-pool from them reproduces 0.3203 over 96,054 ticks exactly; nav's copies are the record.** The control arm
from the two usable logs (whole roster, both armies): yard eff_mean 0.681, osc_share 0.044, net/path 0.815,
cusp/min 43.10, SPARC −2.013; terminus 0.660, 0.052, 0.799, 69.14, SPARC −2.013. **Cusp density swings 60 % between
maps with no treatment, so it mostly measures the arena; SPARC is −2.013 on both to three decimals. A6's
pre-registration reads SPARC and the off-corridor pair, not cusp density.**

### A7. Null-space behavioural control — priority projection instead of weighted sums
**[A]** · Antonelli, Arrichiello & Chiaverini (2008), *The Null-Space-Based Behavioral Control for Autonomous
Robotic Systems* · **Stream: nav** · **Pathology: P1, and the stall case**

Safety, weapon-arc/standoff and formation-slot tasks are executed in strict priority, each lower task projected into
the null space of the higher ones, so **opposing goals can no longer cancel to zero**. **Replaces** additive
context-steering blending and PID formation override. *This is the one ADOPT row that is an architectural change
rather than an addition, and per Part 2 it must land before or with A1/A4, not alongside them uncoordinated.*
**Determinism:** rank-1 projection, six multiply-adds.
**Falsifier:** zero ticks where a unit with an unreached goal holds |v| < 0.2 m/s with no blocking geometry.

### A8. Affine / complex-Laplacian deformable formations
**[A+B]** · Zhao (2018), *Affine Formation Maneuver Control*, IEEE TAC 63(12); Lin et al. (2014), IEEE TAC 59(7);
Belta & Kumar (2002) via [B] · **Stream: squad** · **Pathology: the lead's "formations that read as deliberate"**

Express a formation as a nominal shape plus a per-squad affine transform, then compress laterally and elongate
longitudinally as a function of corridor width — so a wedge becomes a column through a defile and re-expands after,
**continuously and without dissolving**. **Replaces** rigid slot offsets held by PID.
**Determinism:** closed-form 2×2 matrix algebra.
**⚠ CORRECTED IN ROUND 9 (squad, 2026-09-20): a pure affine map CANNOT turn a wedge into a column.** A wedge has
slot pairs at the same depth differing only across the heading; no 2×2 separates two such points while squeezing that
axis toward zero — at the limit they land on top of each other, so a literal implementation stands hulls inside each
other in exactly the narrowest corridors. The shipped form is a **shape morph plus a diagonal matrix and a shear**: the
nominal shape is pulled toward single file with ranks splitting apart *along* the heading before the shape closes
*across* it, then scaled per axis. The file's target order is the shape's own depth order, not the slot index (a vee
has slots ahead of its leader). Every slot keeps its index, so zero crossings and zero rank inversions hold by
construction; the test sweeps 15 corridor widths × 11 shapes × 5 squads × 3 spacings.
**MEASURED AND SWITCHED OFF (squad, 2026-09-20, laptop, `make squad-defile`, the maze's 11 m gap = 5.0 m of navmesh,
five Condemned wheeled vehicles, forced wedge, 70 s, `DEFORM_ENABLED` the only difference):** deform ON — arrived
**0/5**, not through the gap, crossings 6, inversions 21; deform OFF — arrived **4/5**, through, crossings 1,
inversions 20. The deformation is the difference between getting through and not, and it moves crossings the wrong
way. `TacticsFormation.DEFORM_ENABLED := false` (one constant, the whole revert path). One configuration, not three
seeds — seeds 3/5/7 were byte-identical because the scenario has no enemies (lesson 22). **What survives:** every
geometric invariant holds by construction over 15 widths × 11 shapes × 5 squads × 3 spacings. **The structural
finding, reached by squad and nav independently within an hour:** a formation-level intent (a deformation, a leash)
lives in a slot layout that the layer actually moving the hull cannot see — nav measured `CombatMotion` deciding under
a tenth of a hull's ticks with `Movement` driving the rest and knowing no leash at all. **A8 also never applied to a
plain right-click move** (the plain-move path sets the corridor to INF), so the lead's commonest order could never
have got it. Next-round candidate: intent reaches `Movement`'s goal selection.
**Falsifier:** zero slot crossings / rank inversions during defile passage, and post-defile recovery time **−60%**.
The lead has already ruled on the trade this needs: *"a 4s slower march for a tidier traversal is better, yes."*

### A9. Time-synchronised co-arrival, and bounding overwatch as an explicit two-phase machine
**[A]** · Beard & McLain (2003), CDC · **Stream: squad** · **Pathology: heterogeneous squads arriving in dribbles**

Compute the bottleneck arrival time across a squad and parameterise every member's longitudinal profile to hit phase
waypoints together, rather than each driving at its own top speed. Then pair fire-teams: one element stationary on
overwatch while the other advances, alternating every 5–8 s.
*Why: this is the single row that most directly buys the lead's stated goal* — *"base-of-fire-and-manoeuvre to be
legible to a spectator"* — and he has already approved the mechanic: *"making the units appear smart is better, so
flanking and maneuvering is fine."*
**Determinism:** tick-count phase synchronisation.
**Ruled in round 9 (2026-09-20):** two alternating halves of an odd-sized element cannot keep ≥ 50% stationary (3 of 5
moving leaves 40%). An odd element therefore leaves a **permanent base of fire** (the unit whose firepower is worth
most static — indirect-fire and long-reach roles first) and bounds the rest in two equal teams; even elements alternate
halves; a pair alternates singles; a single vehicle does not bound. Doctrinal, and it meets the bar by construction.
The measured minimum stationary share is still reported.
**MEASURED (squad, 2026-09-20, laptop, same gap, forced wedge + `bounding_overwatch`):** stationary share
**0.60 on both arms** (the 3-of-5 the base-of-fire ruling predicts), `bounding_ticks` in the thousands so the phase
machine ran. **Arrival dispersion: tracked 1.23 s, wheeled 41.4 s.** Co-arrival paces off top speed and route ETA
and reads no locomotion; what makes a wheeled hull late is its turning circle and gear changes — nav's subjects, and
metrics' CP1 finding reproduced by an independent instrument. **Every faction but the Condemned is wheeled or hover,
so on the vehicles the lead fields A9 mostly cannot make a squad arrive together, for reasons below the squad layer.**
**Falsifier:** inter-element arrival dispersion at an objective line drops from **> 12 s to < 1 s**, and **≥ 50% of
squad firepower is stationary at every tick** of an advance.

### A10. Deterministic auction assignment with an incumbent bonus
**[A+B]** · Bertsekas (1988), *The Auction Algorithm*, Annals of OR 14(1); [B] proposes regularised Hungarian ·
**Stream: squad** · **Pathology: slot thrash and path-crossing on formation change**

Assign units to slots and elements to objectives by integer auction with dual prices, plus a bonus for the slot a
unit already holds so a re-solve cannot swap two units for a marginal gain. **Replaces** whatever nearest-slot rule
we have.
*We chose auction over Hungarian deliberately:* pure integer arithmetic, a hard iteration cap, a bid queue ordered by
unit name, and warm-startable — all four are determinism properties we need and Hungarian's float-tolerance variants
are not.
**Determinism:** integer utilities scaled by 10⁴, fixed ε, fixed cap.
**MET (squad, 2026-09-20, laptop, `4741c723`):** spurious re-assignments under a 0.5 m nudge **0 of 512**; crossing
driving paths on a formation change **0 of 96**; five-squad idle orders **0 and 0** (round 7's 4–6, without the `fixed`
flag that achieved it). `STABLE_MARGIN` and `fixed` deleted, plumbing included; `_hungarian` kept only as the test
reference. Two numbers were measured rather than chosen and both started wrong: the bid cap at 8 fell through to the
greedy completion and produced 6 spurious re-assignments (an approximation artefact), and the incumbent bonus at 0.5
spacings (7 m) was outbid by a CPU slot drift measured at 9.3 m — **a hysteresis term has to exceed the noise it exists
to resist**; now one full spacing (14 m). Lesson 153 honoured: nothing in the utility is clamped. The first crossings
measurement (8 before, 47 after) measured a configuration the game cannot produce and is struck, not revised.
**STOOD DOWN before merge (squad `02762b8d`, 04:40): the tip went red on four tests, and the cause was not the solver.**
Both solvers return optimal assignments; "heavies in front, artillery behind" had **never been a cost term in this
codebase** — it was an artefact of the Hungarian's tie order (the tier cost is identically zero for the toughest
vehicle), and it survived every round until the auction broke ties differently. Lesson 50's load-bearing coincidence,
in the seating. A correct cost exists (`c0f22597`: a normalised tier mismatch whose coefficient never vanishes — the
"symmetric-looking" form moved the blind spot to the median tier — plus a deadband for station drift bracketed by two
measured distances, 1.34 and 3.8 spacings), one test short — **and that failure is Invariant 0c, not bookkeeping** (squad's correction, 05:00): A10 deleted the
`fixed` flag, whose guarantee is written in `_group`'s own comment (*keeps last update's seating whatever it costs — a
plain move standing on its spot*), and neither the incumbent bonus nor a distance deadband reproduces an unconditional
guarantee; the test drifts two crews 1.34 spacings onto each other's slots on purpose. A named mechanism was replaced
without preserving what it guaranteed. **A10's first job next round: keep `fixed` for the on-the-spot case (or make the
deadband unconditional when the anchor has not moved), then the cost.** The branch ships X1, X5, A8-off and A9 without A10. And the
fourth coat of lesson 164: the perturbation test was not what hid this — *every test exercised tiers only where the
tie-break could not matter*: the instrument never visited the case.
**Falsifier:** zero path-crossing slot assignments on a formation transition; spurious re-assignments under a small
perturbation reach **0%**.

### A11. Tactical dynamic-window arcs in place of the context-steering ring
**[A]** · Fox, Burgard & Thrun (1997), *The Dynamic Window Approach*, IEEE RAM 4(1) · **Stream: nav** ·
**Pathology: P1, P2**

Score a fixed 9×9 lattice of (speed, yaw-rate) pairs that the plant can **actually reach this tick**, as
constant-curvature arcs over a ~2 s lookahead, with a gear-continuity bonus. **Replaces** the 16-direction
interest/danger ring, which scores *directions* the vehicle may be unable to take — the ring is why a heavy hull
picks a heading it then has to hunt toward.
**Determinism:** fixed grid, row-major.
**MEASURED (nav, 05:10, laptop, five duels pooled): `--nav-off=a11` alone is a NO-OP** — every `a11_on()` sits
inside `choose_projected`, which runs only when A7 is on, so the earlier duel question was asked on an arm that
could not act (byte-identical arms with the flag honestly printing `a11=true`: the switch worked, the arm did not).
With the right arms, **A7+A11 vs A7 alone: duel 20.0 → 6.3 s, shots/s 0.27 → 0.57, damage/s 18.9 → 51.5, damage per
shot 70 → 91; front hits 84% (21/25) → 67% (10/15), Fisher p = 0.26.** A11 more than doubles the exchange tempo; whether
that is lethality or blundering is undecided because a 6.3 s duel cannot produce enough hits. Needs many seeds or a
scenario that does not end at the first death. A test now fails if A11 ever escapes `choose_projected`; the duel
scenario's `shots >= 6` fails a faster fight for being faster and becomes a rate (squad's file).
**Falsifier:** angular-acceleration saturation events in close quarters reach zero; steering oscillation **−60%**.
**Note the overlap with A7 and A1** — all three touch the same code path. Part 2 applies: they are sequenced, not
parallel.

### A12. Trajectory-space evaluation metrics, so we stop measuring the wrong thing
**[A+B]** · Balasubramanian et al. (2012/2015) spectral arc length; Benhamou (2004) windowed tortuosity; Dragan
(2013) goal-posterior margin; Zhao (2018) affine residual · **Stream: orchestrator-owned tooling** ·
**Pathology: all of them, and the meta-failure**

The brief's §7.11 admits it: *"we repeatedly measured [time-allocation] while the human complaint was about
[trajectory]"*. A unit that oscillates for 0.5 s costs **6% of travel time** and ruins the next fifteen seconds of
watching. Four replacements, each with an acceptance bar: **windowed displacement efficiency** (net displacement over
path length on a 4 s sliding window — this is *exactly* the 8 m/2 m signature we described), **signed cusp density**,
**spectral arc length** of the speed profile, and **affine formation residual**.
**Build this first in wall-clock order even though it is listed last**, because every other row above is falsified
against it. A bar we cannot read is not a bar.
**Falsifier:** it reproduces the round-8 oscillation finding (5.3–7.2% on four maps) from the same replays. If the new
metric cannot see a pathology we already measured, the metric is wrong.

---

## Part 4 — CANDIDATE: wanted, blocked on something

| # | Technique | Source | Blocked on |
|---|---|---|---|
| C1 | **SE(2) state lattices with precomputed motion primitives** — a per-hull-class graph of dynamically feasible manoeuvres, searched instead of a polygon graph | [A+B] Pivtoraiko, Knepper & Kelly (2009) | The natural *answer* to open question 3 (*what represents "a body of length L fits through here"*) and to P6. Blocked because it is a **replacement for navmesh A\***, not an addition — the largest single change proposed anywhere in either file. Wants a round of its own, after A1/A7/A11 have settled the layer beneath it |
| C2 | **Per-hull-class clearance from a medial-axis / ECM decomposition** | [A+B] Lee (1982); Geraerts ECM | P6 directly: one baked radius for a 5× footprint range. Blocked on **the navmesh baker ignoring boxes above ~8 m of footprint** (`algorithms.md`) — we cannot bake per-class meshes until that is understood, and arena's slab-tiling workaround is a workaround |
| C3 | **Halton-sequence MPPI** — 32 deterministic low-discrepancy control rollouts over a 1.5 s horizon | [A] Williams, Aldrich & Theodorou (2017) | This is the named form of the `algorithms.md` **model-predictive lookahead** row. Genuinely deterministic (perturbations from a frozen table, not a PRNG). Blocked on A11 landing first: DWA is the same idea at a twentieth of the cost, and if 81 arcs fix P1 we do not need 480 rollouts |
| C4 | **Asymmetric-responsibility non-holonomic reciprocal avoidance** — the yield split weighted by mass/inertia rather than 50/50 | [A+B], and **both give the identical form** α = Iⱼ/(Iᵢ+Iⱼ) | Our ORCA assumes comparable agents; a 14 m rig and a 2.8 m scout cannot yield equally. Blocked on a **decision, not a measurement**: Godot's built-in RVO has `avoidance_priority` and we wrote our own ORCA anyway (`algorithms.md` names the unmade comparison). Make the comparison before extending either |
| C5 | **Aspect-angle armour convolution** — precomputed polar vulnerability kernels, so a hull presents its thickest armour to the primary threat and arrival chooses a terminal *heading* | [B], and [A] Technique 24 | Wants directional armour to exist first. Cheap once it does (a 16-bin dot product) and visually legible — tanks angling their glacis is one of the most recognisable things armour does. Depends on a balance decision that is the lead's |
| C6 | **VIPER / DAgger distillation of an expensive offline oracle into oblique decision trees** | [A] Bastani, Pu & Solar-Lezama (2018); [B] via Verwer & Zhang (2019) | **The single best answer to the brief's §3** (*"the offline budget is effectively unlimited"*), and the lead's own framing. A depth-10 tree of linear splits is fixed-point, printable, inspectable, and orders of magnitude cheaper than the planner it imitates. Blocked on **having an oracle worth imitating** — there is nothing to distil until C3 or a full offline optimiser exists — and on finding 1 of Part 1 |
| C7 | **Offline quality-diversity tuning of battle-drill parameters** (CVT-MAP-Elites over a behavioural descriptor space, shipped as a frozen atlas) | [A] Cully et al. (2015); Vassiliades et al. (2018) | Replaces hand-tuned drill constants with an offline-optimised table indexed by situation — squarely the §3 framing, and it attacks the real complaint that *"three separate subsystems were implicitly sized for a 4 m hull"*. Blocked on A12: quality-diversity needs a scalar objective per niche, and we do not yet trust our objectives |
| C8 | **Space-time reservation** for corridor sharing | [A+B] van den Berg & Overmars (2005) | Attractive for defiles. **Explicitly held back by Part 2** — it assumes plan commitment and A1 assumes plan abandonment. Not adoptable in the same round as A1 without a stated arbitration rule |

## Part 5 — DEFER and REJECT

| Technique | Source | Verdict and reason |
|---|---|---|
| **Q32.32 fixed-point core with CORDIC transcendentals** | [A+B] Volder (1959); Muller (2006) | **DEFER — but this is the right eventual answer and it is now written down.** It would delete our worst determinism tax: the sim baseline is keyed per glibc version (`glibc-2.43` on builder0, `2.39` on laptops, which **silently skips**). A fixed-point core makes the fingerprint portable across libc, compiler and architecture. Deferred because it is a rewrite of the geometry layer with no gameplay symptom attached, and `determinism.md` already names an integer graph as the eventual direction. **Revisit the moment the per-glibc split costs us a real bug rather than an inconvenience** |
| **Deterministic fork-join parallelism with static entity partitioning and fixed-topology reduction trees** | [A] Blelloch (1990); Leiserson et al. | **DEFER.** Recovers multi-core inside a deterministic tick, which is genuinely non-obvious and worth having recorded. We are not CPU-bound at 90 units on the laptop, so this buys nothing today. Filed against the day we are |
| **Fixed-iteration QP / LCP trajectory optimisation** (ADMM–OSQP with a pre-factored KKT matrix; or Lemke) | [A] Stellato et al. (2020); [B] Bemporad (2002) | **DEFER.** The correct deterministic answer to "constrained multi-step optimisation" — fixed iteration count, warm-started, no convergence test. Subsumed for now by C3, which is the same layer at lower cost. Keep for high-value heavy hulls if clothoids plus DWA prove insufficient |
| **Decision Field Theory second-order preference integrators** | [A] Busemeyer & Townsend (1993) | **DEFER in favour of A2.** Both fix option thrash; A2 derives its constant from the vehicle's own physics and this needs a critical-damping frequency chosen per option set. **We do not adopt two treatments for one pathology in one round** — that is how round 8 measured commitment twice for nothing |
| **Consensus-Based Bundle Algorithm** for multi-step task bundles | [A+B] Choi, Brunet & How (2009) | **DEFER.** Real answer to army-layer allocation of *sequences* of objectives, with submodular rewards that prevent deathballing. Our army layer is not yet the weak link, and A10 covers the assignment we actually re-solve every second |
| **Gale–Shapley stable matching** for role-to-position | [A] Gale & Shapley (1962) | **DEFER.** Guarantees no blocking pair under attrition. A10 already removes the thrash we have measured; this addresses a cyclical-swap case we have never observed. Adopt only if A10's falsifier shows 3-way swap thrashing |
| **Morton-order / space-filling-curve scheduling** of agent updates | [B] Morton (1966) | **DEFER.** A cache-locality win that also happens to be a canonical deterministic iteration order. Genuinely nice; not a bottleneck |
| **Time-to-collision energy landscapes** | [B] Karamouzas et al. (2014) | **DEFER.** Empirically derived pedestrian interaction law, a better *potential* than distance-based repulsion. Mostly subsumed by C4 for our case, and derived from human crowds rather than vehicles, which is the wrong prior for a 14 m articulated hull |
| **Control-barrier-function QP safety filters** | [A] Ames et al. (2017) | **DEFER.** Provable forward-invariance of a safe set — the rigorous version of "never drive into a wall". A7's strict priority projection buys most of the safety guarantee with a tenth of the machinery |
| **Frenet–Serret corridor projection** for lateral/longitudinal decomposition | [A] Werling et al. (2010) | **DEFER — likely arrives free.** It is the natural coordinate frame for A4 and C3, so it will show up as an implementation detail rather than as a decision |
| **Generalised velocity obstacles via precomputed lookup tables** | [A] Wilkie, van den Berg & Manocha (2009) | **DEFER.** The offline-table form of C4. Decide C4's direction first |
| **INT8 / Q16.16 quantised MLP policies trained by offline RL** | [A+B] Jacob et al. (2018) | **REJECT for now, on a corrected premise, and it is the lead's call to overturn** — see Part 1 §1. It is *not* barred by determinism, which is what `algorithms.md` claimed. It is barred by our own preference for mechanisms whose failure mode we can read, and by the absence of any pathology above that needs a nonlinear policy. C6's decision trees are the same trade with a readable artefact |
| **Runtime-learned or adaptive policies of any kind** | — | **REJECT, unchanged.** Bit-identical replay, lockstep networked play and the sim baseline all forbid state that evolves outside the tick's inputs. Nothing in either response challenges this |

---

## Part 6 — The consensus list, which is the actual headline

Stripped of everything else: **two independent systems, given only `research/brief.md`, both named the following.**
They had no knowledge of each other, no access to our code, and different house styles. Where they agree, we are
about as close to an outside second opinion as this project can get.

1. Continuous-curvature clothoid paths — **A4**
2. Cusp *penalties* rather than cusp prohibition — **A4**, and P3's lesson in a new layer
3. SE(2) state lattices with precomputed feasible primitives — **C1**
4. Medial-axis / ECM clearance, per hull class — **C2**
5. Asymmetric-responsibility avoidance, **with the identical α = Iⱼ/(Iᵢ+Iⱼ) weighting** — **C4**
6. Anisotropic exposure-metric route selection over influence fields — **A5**
7. Hull-*length* cover as a swept/integrated query, not a point sample — **A3**
8. Affine/deformable formation structures — **A8**
9. Dragan legibility as an explicit objective, and decoupled turret/hull headings — **A6**
10. Deterministic assignment with switching friction — **A10**
11. Space-time reservation for shared corridors — **C8**
12. Fixed-iteration optimisation instead of convergence loops — Part 5
13. Fixed-point arithmetic with table-driven transcendentals to kill the per-libc fingerprint — Part 5
14. Distillation of an expensive offline planner into a small deterministic artefact — **C6**
15. Trajectory-space rather than time-allocation metrics — **A12**

**Eight of the twelve ADOPT rows are on this list.** That is the reason to believe the backlog.

## Part 7 — What this exercise did not answer

Recorded so the next round does not mistake a gap for an oversight.

- **Neither service addressed articulation.** The lead's round-8 note that *"the gang semi trucks don't actually
  behave like a semi truck with a truck and a trailer — both components just move together"* has no answer in either
  file, because the brief described hull length but never said the word *articulated* except in passing. **That is a
  brief defect, not a research gap** — tractor-trailer off-tracking is a thoroughly solved problem. If we send a
  second brief, this is the first thing to add.
- **Neither addressed the balance consequence of scale.** `gangs vs law` went **9/20 → 0/20** with the 14 m rig and
  the cause is still unresolved (shuffling evidenced against, splash evidenced against, "bigger target" surviving by
  elimination only). Not asked, so not answered.
- **Neither questioned the three-layer decision stack**, which the brief presented as settled. Open question 1 —
  *is per-agent path ownership right at all?* — got an answer from A (a three-tier hierarchical ownership scheme) and
  silence from B. Neither is evidence.
- **No proposal costed integration.** Every runtime figure in both files is a per-agent microsecond count for the
  technique in isolation. Nobody costed the *interaction*, which Part 2 says is where the risk is.

## How to use this file

1. **A stream does not adopt a row because it is listed here.** It adopts it because its brief says to, and the
   brief carries the falsifier and the **Replaces** answer (Part 2).
2. **When a row lands, change its state in [`algorithms.md`](algorithms.md)** and link back to this file's row id.
   State lives in one place (Invariant 0).
3. **Never quote Service A's audit counts or Elo figures to the lead**, or to anyone. They are unverifiable
   assertions about a codebase neither service has seen. The *reasoning* in Part 2 stands on its own.
4. **If a sentence in `research/` reads as nonsense, it is truncation.** Both sources are corrupted in places.

---

## Round 10 addendum: the second brief's reply, curated (2026-09-20, evening)

**Source:** [`research/brief2.md`](research/brief2.md) (sixteen questions from round 9's negative results) and
[`research/response2_verbatim.md`](research/response2_verbatim.md). Same cautions as above: the service has not seen
the code; its numbers are arguments; its falsifier figures are its proposals and the bars below are ours. **What is
different this time:** we asked for reframings before techniques, and the reply's value is mostly in five
reframings that name mechanisms we had measured but could not explain. Each row says which round-10 brief carries it;
the briefs each have a *Research addendum* section pointing back here. State changes live in `algorithms.md`.

| Id | Reframing or technique | Verdict | Replaces | Our falsifier (pre-registered) | Brief |
|---|---|---|---|---|---|
| **B1** | **The seam is an "unbuffered decoupling": the deliberative layer emits point targets, so the 30 Hz mover must invent the trajectory and treats intent as malleable.** Remedy shape: the element publishes a *funnel* (a chain of convex corridor polytopes plus a leash/stationarity bound) as the shared contract; the mover is a *reference governor* that projects its nominal velocity onto the funnel's admissible set every tick (scaling speed along the centreline, never leaving the corridor). Neither "move intent down" nor "execution up". Refs: Kolmanovsky/Garone/Di Cairano 2014; Burridge/Rizzi/Koditschek 1999. | **ADOPT as the shape of nav's seam item** (nav item 6); A7's projection, A6's corridor and squad's leash all become consumers of one object | the point-target contract between element and Movement; the unstick heuristics inside the funnel | on the Terminus drive test and five_squads: off-corridor share and unstick triggers fall with the active fraction beside them; formation residual (A12) does not rise; no new freeze. The service's 85 %/90 % are not our bars | nav (owner), squad (publishes the funnel) |
| **B2** | **The yaw freeze is a deadlock with a named sequence:** formed-up hulls settle inside each other's collision margins (a non-zero penetration baseline), every candidate yaw compares worse against the *squadmate* contact, both refuse, and the deepest contact masks the wall term. Our ranking measured lateral gaps only; nose-to-tail contact was never measured. Fix family: (i) a **capsule-string / multi-circle hull** whose distance field is monotone in yaw (no OBB discontinuity, no masking); (ii) **reserve the turning envelope before rotating**, yield by priority if denied (hold heading, stop); (iii) **elongated wheeled hulls do not rotate in place** (yaw coupled to forward speed, ω ≤ v/R_min); the invariant *slot pitch ≥ 2 R_ext unless single file*. Refs: Kanayama 1990; multi-circle approximation. | **ADOPT the mechanism test first, then (i) as the candidate predicate, (ii) as the arm behind it**; (iii) is a design ruling we take (it is what the creep already tries to be) | combat's per-candidate OBB `_penetration`; the "world-only mask" idea (withdrawn) | combat item 1 instruments the deepest-contact collider identity per candidate per tick: the mechanism is confirmed if the refusing crews' deepest contact is a squadmate and the seating crew's is not; the fix passes CP4's three bars (five_squads 0/30, the corridor 11.6°/6.1 m kept, the wedged rig never frozen: zero runs of >3 consecutive refused ticks) | combat (owner), squad (pitch), arena (spawn grid) |
| **B3** | **Articulated vehicle without a joint solver:** closed-form hitch kinematics (θ̇₁ = v₀/L₁ · sin ψ − d/L₁ · ω₀ cos ψ; RK2 at 30 Hz), the trailer pose analytic from the tractor's, a second *hinged OBB collider* placed from it (no sweep of its own), a jackknife lock at |ψ| ≥ 75–85° in reverse. Refs: Altafini 2001. | **CANDIDATE** (the lead did not raise it; S2's recorded follow-on now has a shape) | the one 14 m box (shells pass through a fold) | a shell through the fold misses both boxes; the sim baseline moves once for this cause; hitch separation identically 0 | combat (stretch; feel's hinge kinematics are already the visual) |
| **B4** | **Swept-path certification offline per vehicle class** (road-design practice: turning templates per class; a corridor graph with per-edge width and per-vertex fillet radius; a certification pass that flags edges and corners per class and prices speed at corners; an affordance overlay for the player). Refs: AASHTO 2018. | **ADOPT the corner half into R4 now** (a lane is certified at its corners by the rig's turning template, not only at its straight width); the per-class routing table is nav's next-round row | the straight-width-only lane assertion; the per-chord `clearance_shortfall` as the routing refusal | arena's lane test fails on any Terminus corner the rig's template does not clear; nav's drive test with rigs shows zero wall contacts at corners | arena (corners), nav (later), control (overlay, later) |
| **B5** | **Four-tier clearance vocabulary:** static footprint (collision, projectiles), swept travel ribbon (corridor transit, headway), turning envelope (slot pitch, pivot licensing), combat signature (the aspect-projected silhouette A = H(L|sin θ| + W|cos θ|) for fire checks and cover). One name per use. | **ADOPT as the vocabulary** in `workstreams.md` *What reads `hull_size`* and lesson 197 | the diagonal disc used in two roles; "clearance" as one number | every `hull_size` reader names its tier; the three disc sites migrate to the combat signature (combat's `hull_disc` arm) | all; orchestrator records it |
| **B6** | **Reciprocal avoidance is wrong in a passage narrower than twice the swept width; replace it there with a corridor right-of-way TOKEN** (a single-lane exclusion zone with two terminals; the leader takes the token with a polarity, squadmates inherit at ≥ 1.5 L headway, the token frees when the last rear axle exits; ties by unit id). Zone-triggered, not stall-triggered, which is exactly why our right-of-way "never asked". Refs: Dresner & Stone 2008; Treiber et al. 2000. | **ADOPT as nav's defile arm** | ORCA inside narrow passages; the stall-triggered ask | the maze defile (`make squad-defile`, wheeled 41.4 s vs tracked 1.23 s today): every unit arrives within 1.25× its unimpeded transit, zero head-on deadlocks over 200 opposing runs, the `wedged` detector fires 0 times | nav |
| **B7** | **Command latency has two regimes:** acknowledgement within ~100 ms (a pin, wheels deflect, the turret slews toward the destination) and visible intent within ~1 s; and **arrival is three phases**: transit under pacing → *operational arrival* the instant the centroid enters the zone and every hull is braking (the ORDER completes here; pacing lifts; weapons free) → *independent dressing* (tracked/hover neutral-steer to the facing; wheeled hulls stop and keep their approach heading, accepting a residual, the turret covering). Refs: Card/Moran/Newell 1983; Reeds & Shepp 1990. | **ADOPT** (squad's settle item and the wheeled-facing row are re-specified by it) | the settle-until-every-slot-is-dressed completion; the round-9 ruling that a held wheeled hull manoeuvres to its facing (kept ONLY for hull-fixed wheeled units whose weapon arc the residual exceeds) | a 20 m move on flat ground reports COMPLETED in ≤ 8 s (our bar; the service says 6.5) with no rise in collisions; a crew shows visible intent within 1 s of the click on the default path | squad (arrival phases), control (acknowledgement), nav (the hull-fixed exception) |
| **B8** | **Ad-hoc coalition split by a fitness score:** S = (range × DPS) / (speed × agility), agility 1.0 tracked/hover, 0.5 wheeled, 0.2 articulated; sort, ties by unit id; top ⌈n/2⌉ = base; then match assignments to positions projected on the normal of the target vector so deployment paths do not cross. | **ADOPT as R1's default split** | nothing (R1 is new) | the element forms with zero crossing deployment paths on five random selections; the split reads as sensible to the lead on the card | squad |
| **B9** | **Balance attribution as a 2 × 2 factorial:** physical collider (rescaled vs legacy mesh) × AI perception model (diagonal disc vs oriented box / chord). Arm B (true mesh, box perception) decides whether perception caused the 9/20 → 0/20; arm C (legacy mesh, scaled disc) whether perception alone suffices. Plus the aspect exposure formula: broadside is 4.2× head-on for the rig, so a hull that cannot keep its nose on the threat is the other candidate. | **ADOPT as the design of combat's gangs-vs-law series** (two extra arms) | the single `hull_disc` on/off pair | per cell, never pooled; the box arm recovers the cell or does not; arm C isolates perception; the null is evidence against | combat |
| **B10** | **Per-window lighting from a packed per-instance attribute** (zone, phase, palette index, wave mode in 32 bits) evaluated in the shader from ONE time uniform: per-window chases and pulses at zero CPU per frame; CPU writes only for event ripples. Plus **camera-facing attenuation** (facades facing the camera dim) as a dial, a **3 : 1 luminance ratio** of fight over venue as the CI gate, and the **affordance language** for passable vs impassable (warm street light and painted kerbs on certified lanes; cold light and height ≥ 1.2 m on chokepoints; a light behind every corner so the entrance silhouettes). | **ADOPT** (show's item 2 becomes packed attributes + a shader wave; arena's item 3 and feel get the affordance table) | the planned CPU-written per-window buffer as the only mechanism | draw calls unchanged, zero lights added, per-window chase visible in a pair at his pose; the readability gate at 3 : 1 reports | show, arena, feel |
| **B11** | **Commentary:** recency-decay penalty (Σ exp(−Δt/τ)) plus a lifetime count; clause assembly (prefix × subject × action × clause) with matched pitch/tempo per clip for the deadpan voices; an authoring framework for the PA and the Veteran (bureaucratic banality, technical detachment, understated inconvenience; never the caller, who is hype). | **ADOPT the scoring and the framework; clause assembly is a stretch** (the pipeline slices whole sentences by design) | LRU + cooldown scoring | repeat-within-three-minutes rate on the fixtures falls to zero at pools ≥ 12 | announcer |
| **B12** | **Experimental hygiene as four safeguards:** activation assertion (an arm counter that must move), differ assertion (test ≠ control state), **positive sensitivity control** (inject a known disturbance; the metric must see it or the harness is blind), **hermetic state verification** (hash the shared state between tests). We had the first two by lesson 195; the third and fourth are new. | **ADOPT as a standing rule** (workstreams round 10) | ad-hoc arm proof | every A/B in round 10 states its positive control; the seal's drain is the hermetic half for navigation and a state hash is the next-round tooling row | all; metrics next round |
| **B13** | **Perceived-intelligence proxies:** SPARC on speed and yaw (we have it), a goal-inference legibility score (how early an observer can infer the destination from the trajectory prefix), acknowledgement latency; a composite index calibrated once against human ratings. | **CANDIDATE** (an A12 column next round) | nothing | — | metrics (next round) |
| **B14** | **Composition hazards named:** governor × right-of-way (the hold line must be a barrier inside the admissible set, not an "obstacle" that trips unsticking); turning reservations × dressing (tracked hulls hold reservation priority; wheeled lock to the approach heading); articulated × terminal curves (plan the trailer's rear axle, bound ψ); mutation runs × replays (sandbox the state). | **ADOPT as invariant 0c rows** for the pairs that land together | — | each pair's landing brief names the rule | nav, squad, combat |

**What the reply did not answer:** it did not cost the funnel's *authoring* (who computes the polytopes for 90 agents
per deliberative step; our navmesh corridor is the obvious source and the reply assumes it); it answered the balance
question with the mechanism we had already suspected rather than a new one (arm C is the new part); its commentary
section describes a three-voice cast that is not ours; and its lighting affordance table is a design language, not a
measurement. The first brief's Part 7 caution stands: neither reply questioned the three-layer stack, and B1 is the
first proposal that gives the stack a shared object instead of a new layer.


---

## Round 10 addendum, part 2: the third brief's reply, curated (2026-09-20, late)

**Source:** [`research/brief3.md`](research/brief3.md) (the four things the second reply left open) and
[`research/response3_verbatim.md`](research/response3_verbatim.md). Cautions as before, and one more: this reply
quotes attribution percentages and pool-size tables to the decimal; **they are its model's outputs, not observations
of our game.** What survives is the *structure*: which quantity to measure, which arm to run, which formula to
compute offline. Rows C1–C12; each names the brief that carries it and the round it lands in.

| Id | What it answered | Verdict | Replaces / refines | Our falsifier | Brief |
|---|---|---|---|---|---|
| **C1** | **Who computes the funnel, and at what cost.** From the navmesh corridor the agent already has: run the portal funnel with the apex offsets shifted inward by an effective clearance `r_eff = r_a + R_min·(sec(Δψ/2) − 1)` (the off-tracking term for a turn of exterior angle Δψ), shrink each corridor polygon's boundary half-spaces by `r_eff`, and intersect neighbours around each portal into a convex overlap polytope. O(M) per agent per deliberative step, M ≈ 6–20 polygons for a 3–5 s horizon, 3–6 half-spaces each; one fixed pass. IRIS-style inflation is offline-only at our scale. Refs: Lee & Preparata 1984; Hershberger & Snoeyink 1994; Kallmann's LCT; Geraerts' ECM. | **ADOPT as the construction for B1** (nav's seam item): our `pathing.gd` string-puller is the same funnel, so the polytope chain is a by-product of the route we already compute | the point-target contract; A7's leash as a scalar | the chain exists for every routed unit on the Terminus drive test at a stated cost per agent per step (commit, machine); the executor never leaves it (off-corridor share → 0 with the active fraction beside it) | nav |
| **C2** | **Disjoint corridors without negotiation.** Three single-pass mechanisms: (i) a deterministic total priority order (key: in-emergency-brake, −clearance slack, stopping distance v/a, distance to goal, unit id) and sequential half-space cuts against higher-priority reservations (zero iterations); (ii) buffered Voronoi cells asymmetric by priority (disjoint by construction, any order); (iii) a short spatio-temporal reservation table with one-step priority inheritance (PIBT). Plus the rule that a higher agent's cut may never intersect a lower agent's CURRENT braking set (truncate the higher's reservation instead). | **ADOPT (i) as the "who yields" rule** that B2's turning-envelope reservation and B6's token both needed; (ii) as the geometric form of the cut | ties by unit id alone | no freezing-robot cascade: no agent's active polytope is ever sliced empty (a counter); five_squads 0/30 with reservations on | nav (owner), combat (the yaw reservation reads the same key) |
| **C3** | **Starvation is safe by construction:** every deliberative packet carries a contingency braking trajectory ending STATIONARY inside its last polytope, so a missed deliberative step degrades to a stop, never to an unstick heuristic. The executor's feasibility condition is closed-form: consecutive polytopes overlap by a ball of radius `r_a + R_min(sec(Δψ/2) − 1) + v·Δt`, and speed caps propagate backward from v = 0 at the chain's end. | **ADOPT with C1** | the `wedged`/unstick regimes as the response to a stale route | the unstick counter falls to zero inside a live corridor; a deliberately dropped deliberative step produces a stop, not a wedge (positive control) | nav |
| **C4** | **The offline/online split for the bake-radius question:** 3–8 kinematic classes, each with an eroded navmesh and medial skeleton precomputed per map, portal-pair transition polytopes and entry/exit speed bounds precomputed; online is array lookup plus neighbour cuts. This is the per-class navmesh row, priced. | **CANDIDATE, next round** (the bake stays 2.0 m this round; arena's corner certification (B4) is its first half) | one mesh at one radius | — | nav / arena (round 11) |
| **C5** | **The non-holonomic corner pinch is a named failure**: a 2-D erosion by footprint radius alone leaves a sharp corner with an empty viability kernel for a car-like hull; the `R_min(sec(Δψ/2) − 1)` term is the fix and the certification test. | **ADOPT into R4 now**: arena's corner check uses this closed form with the rig's `min_turn_radius_m` and each junction's exterior angle | "the rig's turning template" as an unspecified object | every Terminus junction prints its Δψ, the rig's r_eff, and the lane's inscribed clearance; the drive test with rigs shows zero corner contacts | arena |
| **C6** | **Attribution: split the proxy, not just the roster.** The one `hull_disc` knob flips three sites at once; the reply says intervene on ONE subsystem at a time (line-of-fire blocking, incoming-threat, spacing, aim) with the disc kept in the others, then Shapley effects over the subsets. And the sizing rule: run every arm on the SAME seeds (common random numbers), test discordant pairs (McNemar); ~32 paired seeds detect a 25-point shift, ~64 estimate components; anytime-valid sequential stopping. | **ADOPT as the series' design** (combat item 6; squad's `incoming_fire.gd` site is one of the knobs) | ten unpaired matches per cell; one knob for three sites | per site, per cell, paired by seed; the report prints discordant counts, never pooled rates | combat (owner), squad (its site) |
| **C7** | **Counterfactual forking beats whole-match comparison:** replay a seed to a checkpoint (every ~5 s), fork under each configuration for 1 tick (which predicate flipped: `is_lof_blocked_by_friendly`, threat, mode) and for 5 s (net damage from the identical state). Removes the butterfly divergence that makes two whole matches incomparable after 20 s. Our determinism makes this cheap (replay to tick T, switch a knob, run 150 ticks). | **ADOPT as an instrument** (combat's match runner: `--fork-at=T --tune=...`) | whole-match aggregates that conflate cause and effect (a losing team fires less because it has fewer units) | the 1-tick action-disagreement rate between disc and box on the gangs-vs-law seeds, split by predicate | combat |
| **C8** | **Two named traps for the balance question:** (a) after a rescale, an aim point that stays at the hull ORIGIN rather than the centre of visible mass fakes an exposure shift (our origin sits at the box centre on the ground; the turret mount fix R5 and the muzzle path must be checked for this); (b) hard thresholds in utility selectors turn a 1 % proxy change into a 100 % mode flip. | **ADOPT (a) as a check inside item 6; (b) is a note for A2's verdict** | — | the aim point of every weapon reads the target's hull centre at its height (a test); the selectors' thresholds near the disc radius are listed | combat |
| **C9** | **Pool size per moment is a formula, not a flat number:** `N_c = ⌈λ·τ⌉ + ⌈λ·T_eff / −ln(1 − R)⌉`, with λ the moment's trigger rate per minute (from our fixtures), τ the cooldown, T_eff the role's memory horizon, R the target repeat-perception rate. Role horizons differ by an order of magnitude: the caller's hype lines fade in 90–180 s; the Veteran's analytical lines in 5–10 min; **the PA's one-wrong-detail lines are remembered across sessions** (the Von Restorff isolation effect): one hearing, and a repeat is a jarring 100 % hit. Its table (its numbers): a moment firing 2/min needs ~22 caller lines (×3 takes), ~58 Veteran, ~135 PA; 0.5/min: 9/21/42; rare: 4/7/12. | **ADOPT the formula and the role ordering; recompute the table from OUR λ per moment** | "every pool ≥ 12" | the pool report prints λ, N_c and the current count per (speaker, moment); generation targets the deficit; the repeat-within-three-minutes rate on 12-minute transcripts falls below 5 % for the caller and the Veteran and to ZERO for the PA | announcer |
| **C10** | **Delivery variation substitutes for text variation only for the caller** (3–4 prosodic takes per line, pitch ±3.5 semitones, rate ±18 %: an effective pool ×1.8–2.4); barely for the Veteran (×1.15); **not at all for the PA** (a second take of the same wrong detail is a repeat, and emphasis on the detail breaks the register). Authoring gates for the PA: exactly one anomalous span of 1–6 tokens, mid-sentence, followed by ≥ 4 mundane tokens (never clause-final: that is a punchline's position); the carrier in flat informational register; no two lines with the same CATEGORY of wrong detail. Diversity audits without listeners: Distinct-n / self-BLEU (surface templates), a compression ratio of simulated transcripts, and, with an embedding model, the Vendi score (the effective number of distinct lines). | **ADOPT**: the caller gets multiple takes (the cheapest good use of the credits he authorised); the PA gets one take and the anomaly rules in the audit; Distinct-n and the compression ratio go into `audit_lines.py` now, embeddings later | one take per line for every voice; the audit's tone check as prose | the caller's takes pass STT and differ in pitch/rate by the stated margins; the PA audit rejects a clause-final anomaly and a duplicated category; the transcript compression ratio rises with the pool | announcer |
| **C11** | **Why a street reads blocked at his pose, in three numbers:** (a) a gap ACROSS the screen is foreshortened by sin 21° ≈ 0.36, so the same clearance reads 2.8× narrower on the ring road (cross-screen) than on the avenue (in depth); (b) a foreground object of height h hides `h·cot 21° ≈ 2.6 h` of ground behind it, so a 1.5 m barricade hides 3.9 m of the street's contact line; (c) the telephoto camera flattens depth, so the eye needs ground-scale anchors (lane markings, paving slabs, kerb stones) between the vehicle and the throat. Low obstacles (0.4–0.9 m: barricades, kerbs) project 3–6 px tall and camouflage; overhead geometry (awnings, bridges) reads as blockage. **The dominant predictor of a correct judgement is the unoccluded screen-space clearance margin at the throat** (visible throat width minus the vehicle's projected width, in JND units), then the occluded fraction of the throat's ground-contact line, then edge contrast at the contact line, clutter, and scale-anchor proximity. Refs: Gibson's ground theory; Warren & Whang 1987; Rosenholtz 2007. | **ADOPT as a render-test instrument and as design rules** | "reads open" as an eyeball question | a headless frame at his pose per lane: the throat's visible screen width vs the rig's projected width, the occluded fraction of its contact line; the ring road's numbers beside the avenue's; the page shows the frame with the throat drawn | arena (the instrument, with control's camera tooling), feel (kerb markings and lit low obstacles), show (a light behind every corner) |
| **C12** | **A per-frame legibility score** as a logistic over those five features, calibrated once against a 2AFC human study (their weights are guesses). | **CANDIDATE**: compute the five features now; calibrate only if the lead's own reads disagree with the ranking | — | — | arena (round 11) |

**What this reply did not answer, and we stop asking:** the funnel's cost is now a formula and a construction, so
the question is closed until measured; the attribution methodology is complete enough to run; the commentary rows
are actionable; the legibility instrument is specified. The remaining unknowns are ours to measure.
