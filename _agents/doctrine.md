# Doctrine: formations, movement techniques and battle drills

> **What this is.** The doctrine stream's design doc (round 4). It holds the real-world doctrine we encoded,
> where it comes from, how it becomes data (`doctrines/doctrine_<name>.json`), how the code runs it
> (`game/tactics/`), and the measurements that say whether a formation actually pays off.
> The lead (2026-09-16): *"this game will get its novelty from the use of sophisticated battle drills and
> formations still … I'm certain all military formations and battle drills are on a degree of science for
> their effectiveness … it's way too much micromanaging to get the units into a specific formation; we should
> generally treat the game as cases where we're commanding well trained battle squads who operated based on
> standard operating procedures (like the army does) … if a unit gets ambushed, the standard operating
> procedure is to face the direction of the ambush and charge forward."*

## The one-paragraph version

The player gives an **element** (a cluster of vehicles with a leader) a **task**: move here, attack that,
screen this flank, support by fire, hold. The leader looks at the task, the terrain, the threat and what it is
commanding, reads its **doctrine table**, and picks a **movement formation** (the shape) and a **movement
technique** (how carefully the shape moves). On contact it stops choosing and starts *reacting*: a **battle
drill** runs, the same one every time, because that is what training is for. Every decision produces exactly
one K1 order per vehicle, so the brains keep doing their own cover, peeking, strafing and weak-spot work
inside it. The player never drags anyone into a formation, and the CPU has no tactic the player's elements
don't run automatically.

## Where the doctrine comes from

These are US Army publications; they are the "science" the lead expected. We use them for the *shapes and the
sequences*, not for the numbers (a 30-ton arena machine is not a Bradley).

| Source | What we took |
|---|---|
| **ATP 3-20.15, _Tank Platoon_** (HQDA; supersedes FM 3-20.15) | Platoon movement formations — column, wedge, line, echelon left/right, vee — with what each is for; the **coil** and **herringbone** halt formations; movement techniques; actions on contact; support by fire |
| **ATP 3-21.8, _Infantry Platoon and Squad_** (HQDA, 2016) | Movement formations and their trade-offs (control vs. firepower vs. flexibility); the three **movement techniques** (traveling, traveling overwatch, bounding overwatch) and when each is used; **actions on contact**; the battle drills (react to contact, react to ambush, break contact) in its drills appendix |
| **TC 3-21.76, _Ranger Handbook_** | The battle drills as step-by-step immediate action, including **near vs. far ambush** and the clock-direction break-contact sequence |
| **FM 3-90-1, _Offense and Defense_** | **Support by fire** and attack by fire as tactical tasks; the base-of-fire / maneuver-element split |
| **TC 3-22.240 / FM 3-22.68, _Machine Gun Employment_** | Cone of fire, **beaten zone**, grazing fire, and what "suppression" buys you — the vocabulary combat's L2 field is built in |
| **ADP 1-02 / FM 3-90 terminology** | "Suppress": temporarily degrade a force's performance below the level needed to do its job — i.e. suppression is a *behaviour* effect, not damage |

**Honesty about citations:** drill *numbering* moves between editions (what one edition calls Battle Drill 2
another calls Battle Drill 1A), so this doc cites publications and drill **names**, never paragraph numbers we
can't verify offline. Everything below is doctrine as commonly published in those manuals; the game-specific
choices are marked **(ours)**.

## Movement formations

A formation answers: where is our firepower pointed, how much of the circle can we see, how easy are we to
control, and how much of us can one shell or one burst reach? Each row's *frontage* and *depth* are what
`TacticsFormation.frontage/depth` compute at 12 m spacing for 5 vehicles.

| Formation | What it is for | Fires | Control | Frontage × depth (5 at 12 m) | Our data name |
|---|---|---|---|---|---|
| **Column** | Speed and control through lanes, close country, or when contact is unlikely | Flanks, little to the front | Easiest | 0 × 48 m | `column` |
| **Wedge** | The default when contact is *possible*: fire to the front, security to both flanks | Front + both flanks | Easy | 43 × 24 m | `wedge` |
| **Vee** | Two vehicles forward when contact is expected from the front; the leader sees over them | Heavy to the front | Harder | 43 × 24 m | `vee` |
| **Line** | Maximum fire forward: the assault, the base of fire, the screen | Front only | Hard (no depth) | 48 × 0 m | `line` |
| **Echelon L/R** | Covering one open flank while moving — a march along a threat | Front + one flank | Moderate | 43 × 48 m | `echelon_left` / `echelon_right` |
| **Herringbone** | A halt in a lane or column: the middle vehicles alternate 90° left and right, clearing the route and watching both flanks while the lead watches ahead and the tail behind | All round | Easy | 13 × 38 m | `herringbone` |
| **Coil** | A halt in the open: a ring, guns out, 360° security | All round | Easy | ~24 × 24 m | `coil` |

**Sectors of fire.** A formation is only half the answer; the other half is who watches what.
`TacticsFormation.sectors()` assigns every slot an azimuth relative to the direction of travel (0 = ahead,
+ = right), 90° wide each, so neighbours interlock. `coverage()` is the share of the full circle the element
watches: a **column covers ~1.0** of the circle (lead ahead, middles on alternate flanks, tail behind), a
**line ~0.42** (everything forward, nothing behind). That is the trade the player is making without having to
think about it, and it is a measured property of the data, not a bonus number.

## Movement techniques

The technique is *how carefully* the formation moves, and doctrine picks it from one thing: how likely is
contact?

| Technique | When | What happens | Cost |
|---|---|---|---|
| **Traveling** | Contact not likely | The whole element moves together, continuously | Fastest, least secure |
| **Traveling overwatch** | Contact possible | The lead section moves; the trail section follows at a distance where it can support by fire, ready to fire | Slower, one section always able to shoot back |
| **Bounding overwatch** | Contact expected | One section moves a short bound while the other is **set** and covering it; then they swap | Slowest, safest: someone is always watching over the gun |

**Bounds are limited by supporting fire, not by patience** — a bound never goes further from the overwatch
element than it can be covered (`legs.support_range_m`, default 85 m). Our elements also *close up before they
bound again*: the next leg waits until every vehicle is within `legs.cohesion_m` of its slot. That is the
doctrinal "close up", and it is also what stops a fast scout from arriving alone.

**(Ours) Legs, not sliding destinations.** Movement runs as discrete legs (45 m traveling, 34 m traveling
overwatch, 22 m bounding). Orders are re-issued only when a leg changes, because every new order resets what a
brain was doing (round-3 lesson). The element therefore *flows* without its vehicles being nudged every tick.

## Selection rules: how a leader chooses

Inputs, all computed in `ElementSituation.build()`:

| Input | Values | How it is judged |
|---|---|---|
| **task** | move, attack, screen, support_by_fire, hold | What the commander asked for |
| **threat** | none, possible, likely, contact | `contact` = taking fire, or a visible enemy within 75 m; `likely` = visible within 130 m; `possible` = something known; `none` = nothing |
| **terrain** | open, lanes, dense | Cover features within 45 m of the element (0–1 = open, 2–4 = lanes, 5+ = dense) |
| **composition** | heavy, balanced, light, support | The roles in the element: artillery and Lancers make it `support`, mostly scouts make it `light`, mostly tanks `heavy` |

The doctrine table is a list of rules tried **in order, first match wins**, ending in a catch-all — so the same
situation always picks the same row (determinism) and every situation has an answer. Every row carries its own
`why`, and that string is what the player reads on the element ("contact likely: bound forward, one element
always overwatching the other"). The standard table, in words:

1. halted in cover → **herringbone**; halted in the open → **coil**
2. screening → **line**, traveling overwatch (widest frontage, most eyes)
3. support by fire → **line**, traveling (every gun on the objective, nobody advances)
4. in contact → **line**, traveling (get every gun into the fight)
5. contact likely, dense → **column**, bounding overwatch (lanes; bound between covered positions)
6. contact likely → **wedge**, bounding overwatch
7. contact possible + light element → **vee**, traveling overwatch (*the lead's "a V formation of scouts coming at you would be scary"*)
8. contact possible + support element → **column**, traveling overwatch (artillery and Lancers move behind the guns)
9. contact possible → **wedge**, traveling overwatch
10. nothing known, dense → **column**, traveling
11. anything else → **wedge**, traveling

## Battle drills

A drill is not a decision, it is a reflex: a trigger, a fixed action, an abort condition and a timeout. All of
them are pure functions in `game/tactics/drills.gd`, so each one has a unit test on a hand-built situation and
a seeded scenario in a real match. **Every drill yields instantly to a player order**: the element stops
commanding any vehicle whose current order did not come from it (`Element._adopt`), so a drill can never hold
a unit against its commander (K1's response guarantee).

| Drill | Trigger | Action | Abort / timeout |
|---|---|---|---|
| **React to contact** | Taking fire, or an enemy inside fighting range, and no drill running | Deploy: vehicles in range engage, the rest hold. This is the "deploy and report" step of *actions on contact* — a short pause while the leader evaluates | After `react_ticks` (1.2 s) it becomes fire-and-maneuver; ends at once if the contact is gone |
| **Near ambush** | A contact appears *suddenly* within `near_ambush_m` (38 m standard), or one that close while we are being hit | **Turn into it.** Every vehicle drives at the ambush, which swings its hull and its armour to face the threat | Becomes *assault through* after the turn (0.5 s) |
| **Assault through** | Follows a near ambush | Abreast in **line**, drive *through* the ambush position and `assault_through_m` past it | Ends when the element is through, nothing is visible, or the timeout |
| **Far ambush** | Visible enemy beyond near-ambush range after react-to-contact | **Fire and maneuver**: the heavy half becomes the base of fire and suppresses; the other half swings `flank_m` off the line of contact and turns in | Ends when nothing is visible |
| **Support by fire** | The task itself is `support_by_fire` | The whole element takes a firing position and suppresses; nobody advances | Ends when the task changes |
| **Break contact** | Our strength below `break_contact_ratio` of what we can see, **and** the nearest enemy beyond `disengage_m` | Bound back by sections toward a rally point: one half moves, the other covers, then swap | Ends when the contact is broken (`broken_contact_m`) or the odds recover (25% hysteresis) |
| **Herringbone** | Halted with a threat known | Lead watches ahead, the middle vehicles turn out to alternate flanks, the tail watches the rear | Ends on contact or on a new movement task |

**Why near ambushes are charged.** Doctrine is blunt about it: in the kill zone of a near ambush you cannot
outrun the fire, so you return fire and **assault through**. That is exactly the lead's instruction, and it is
the most visible piece of doctrine in the game: an element that gets jumped at 25 m turns as one and drives at
whatever is shooting at it.

**(Ours) Facing comes from driving.** K1 orders carry no facing, so a halt formation's crews are given a goal
a few metres out along their sector: they arrive pointing the right way. A `facing` field in K1 would do this
properly — a request to control (see *Requests* below).

## Why formations pay off (X4)

The rule from game_design.md: *"Formations must pay off through mechanics that already exist or are being
added … never a 'formation bonus' number."* The mechanics they lean on:

| Property | The mechanic it pays off in | Measured by |
|---|---|---|
| **Sectors of fire / coverage** | Spotting and intel: an element that watches its flanks sees an approach earlier | `TacticsFormation.coverage()`; scenario: who spots first |
| **Frontage** | How many guns can bear forward at once, and how much ground is screened | `frontage()`; damage in the first seconds of contact |
| **Depth** | How few vehicles are exposed to fire from the front (a column presents one) | `depth()` |
| **Dispersion (closest pair)** | Splash radius and machine-gun beaten zones reach what is bunched | `closest_pair()`; suppression and splash damage per volley (needs combat's L2) |
| **Armour facing** | Turning into an ambush presents front armour; a flanked column presents sides | `Armor` / `Match.armor_multiplier`; damage taken per facing |
| **Mutual support** | The overwatch element can actually cover the bound (`support_range_m`) | Kills by the overwatch element while the other bounds |
| **Suppression** | Base of fire pins them so the maneuver element lives (combat's L2, CP2) | Suppression applied per drill |

Measurements land in *Measurements* below as they are run. Some of them (dispersion vs. splash, suppression)
are only meaningful once combat's **L2 suppression** merges at CP2.

## Parity: the same library for both sides (X5)

The CPU commander assigns **tasks** to elements exactly as the player does; everything below that line —
formation, technique, drills — is this shared library. There is no CPU-only path, and no player-only one.
`ElementCommander` (`game/tactics/element_commander.gd`) is the whole CPU side of it: classify each element
(line, recon, support), pick an objective, hand out move / attack / screen / support-by-fire, and stop.

**What a spectator sees.** `make tactics-parity` runs a scripted match with a commander on both sides and
prints every element's shape, technique, drill and reason. From one run (seed 5, combined_arms vs
anvil_hammer, `build/tactics-parity.log`):

```
PARITY t=10s score 0:0 alive 5:5
  GREEN Battery: column, break contact — outgunned here: break contact and bound back | task support by fire
  GREEN Eyes:    column, break contact — outgunned here: break contact and bound back | task screen
  GREEN Guns:    line, near ambush — ambushed at 36 m: turn into it and assault through | task attack Rust_Anvil_1
  RUST  Anvil:   line, react to contact — contact: return fire, take cover, report | task attack Green_Guns_1
  RUST  Hammer:  line, far ambush — far ambush: pin them by fire, flank with the rest | task support by fire
PARITY t=40s score 2:4 alive 1:3
  GREEN Eyes:    column, break contact — outgunned here: break contact and bound back | task screen
  RUST  Anvil:   herringbone, traveling — halted in cover: herringbone, alternate flanks watched | task move
```

In one match the two sides between them used the wedge, the column, the line and the herringbone, and ran
react to contact, near ambush, far ambush, support by fire and break contact — all from the same tables. Every
line also carries the *reason*, which is what the HUD shows the player: nobody has to know what "echelon" means
to see that their element is refusing a flank because contact is likely.

## Faction doctrines (X6)

Same engine, different tables (`doctrines/doctrine_<faction>.json`).

| Faction | How they move | How they react |
|---|---|---|
| **The Condemned** | Close up (12 m in the open), line up and grind forward; column when nothing is in sight | Charge ambushes from 42 m; `break_contact_ratio` 0.25 — they almost never withdraw |
| **Road gangs** | Vee at every threat level, always traveling, widest spacing (18 m), longest legs: a pack that never stops to cover itself | Charge from 55 m, flank 60 m wide, react in 0.7 s, and **no break-contact drill at all** |
| **The Law** | Bounding overwatch whenever contact is possible or worse, longest bounds with the widest supporting range | Deliberate: react for 1.5 s, flank 48 m, withdraw at 0.6 — the professionals leave a losing fight |
| **The Syndicate** | Echelon and line, traveling overwatch, stand-off ranges (110 m supporting range) | Only charge an ambush inside 22 m; `break_contact_ratio` 0.75 and a 115 m break distance: they reposition constantly |

## Publishing decisions: doctrine talks to the announcer (the lead, 2026-09-16)

> *"Rather than cluttering the UI, we can use that information to generate scripted statements from the
> announcers about how a squad is lining up in whatever formation for whatever reason. Presumably we at
> least want the structured data publishable."*

Every decision an element takes is published as **structured data in the K5 event shape**, on
`Elements.element_reported(event)`. Doctrine publishes values; the words belong to audio's line library. The
announcer's `MatchEventAdapter` already works this way for everything else — it only listens to signals and
never writes to the simulation — so wiring is one `connect`.

**Two event types.** Both carry `team`, `element`, `size` (vehicles alive) and `reason` (the doctrine table's
own `why`, so the booth can quote the element's logic instead of inventing one):

| Type | When | Extra fields |
|---|---|---|
| `element_formation` | The element changed shape or movement technique, took its first task, or came off a drill | `formation`, `technique`, `changed` (which of task/formation/technique moved) |
| `element_drill` | A battle drill **started** | `drill`, `formation`, `distance` (how far off the trigger was), `target` (what set it off) |

`tick` and `t` are not included: whoever puts an event into a timeline stamps them, exactly as
`MatchEventAdapter` does today. `make tactics-parity` writes a real one to
`build/tactics/element_events.jsonl` — 36 events from a 45 s, five-element match — so lines can be written
against a timeline instead of a guess:

```json
{"changed":["task","formation","technique"],"element":"Eyes","formation":"line","technique":"traveling_overwatch",
 "reason":"screening: a line watches the widest frontage","size":1,"t":1.0,"team":"green","type":"element_formation"}
{"drill":"break_contact","element":"Battery","formation":"column","distance":118.7,"target":"Rust_Anvil_1",
 "reason":"outgunned here: break contact and bound back","size":1,"t":5.3,"team":"green","type":"element_drill"}
```

**What doctrine filters out, so the booth doesn't have to.** An announcer that repeats itself is the exact
complaint the lead made about the PA, so the noise is cut where it is generated:
- an element with **no task** says nothing (before its first order it is parked, not "halting in cover");
- a **reason changing on its own** is not a call (the same wedge for a slightly different reason);
- a **leader change** is the HUD's business, not the booth's;
- the **same call is not repeated within 10 s** per element (`ElementReport.COOLDOWN_TICKS`), which is what
  stops an element that halts, moves and halts again from announcing the same herringbone three times;
- `element_drill` always means a drill **started**; coming off one reports as a shape change.

That took the sample from 43 events to 36 with nothing interesting lost.

## The code

| File | What it does |
|---|---|
| `game/tactics/element_task.gd` | The commander's task: verb, destination, target. Validates, so a typo fails loudly |
| `game/tactics/tactics_formation.gd` | Formation geometry, sectors of fire, frontage/depth/dispersion. Pure math |
| `game/tactics/doctrine_table.gd` | The doctrine files: parsing, strict validation, rule selection |
| `game/tactics/element_situation.gd` | The only impure step: what the element knows (members, contacts, terrain, threat) |
| `game/tactics/drills.gd` | Drill triggers, aborts and timeouts. Pure |
| `game/tactics/element_plan.gd` | The leader's decision: formation + technique + drill → one order per vehicle. Pure |
| `game/tactics/element.gd` | One element: roster, leader succession, task, plan state, issuing K1 orders, `state()` for the HUD |
| `game/tactics/elements.gd` | All elements of a match: form/of/disband, the update cadence, `element_changed`, `element_reported` |
| `game/tactics/element_report.gd` | A decision as a K5-shaped event for the announcer, and what is not worth saying |
| `game/tactics/element_commander.gd` | A CPU commander that assigns *tasks* to elements (parity demo, X5) |
| `doctrines/doctrine_*.json` | The tables: standard plus one per faction |

## Sketch: what an offline discovery harness would search (stretch)

game_design.md wants a harness that plays tactics against each other and distils what wins into deterministic
rules. Doctrine is already the right shape for that, because a doctrine is **data**:

- **The search space** is a doctrine table: the order of the movement rules, the formation and technique each
  one picks, the spacing per terrain, the leg lengths, and the drill numbers (`near_ambush_m`,
  `break_contact_ratio`, `flank_m`, `react_ticks`, …). A candidate is one JSON file.
- **The fitness** is the tournament ai already runs: table A against table B, same armies, same seeds, both
  sides swapped, scored on wins and on what survived.
- **The moves** are small and safe: change one number, swap one rule's formation, reorder two rules. Every
  candidate is still a valid table (the parser rejects anything that is not), and every candidate is still
  *readable* — which is the point, because what the harness finds has to end up as a rule a player can be told
  ("in close country, bound").
- **What must not happen:** a search that produces a table nobody can explain, or one that only wins because
  the CPU can run it and the player's elements can't. Parity is checked by construction: the player's elements
  use the same tables.

ai owns the harness; doctrine owns the format and will take its findings as new rows with a `why`.

## Measurements (X4)

Every number below comes from `make tactics-measure` (seeded, headless, `build/tactics/measurements.json`)
and `make tactics-drills`. Same arena strip, same enemy, same seed per trial: only the doctrine changes.

### Formations: four tanks walking into two dug-in guns at 80 m (seed 29, 20 s)

| Shape | Spacing | Survived (hull + shield) | First hit on them | Sector coverage | Frontage |
|---|---|---|---|---|---|
| **Wedge** | 14 m | **0.75** | **3.6 s** | 0.63 | 37.8 m |
| Line | 14 m | 0.63 | 3.8 s | 0.42 | 42.0 m |
| Column | 14 m | 0.57 | 8.0 s | 1.00 | 0 m |
| Wedge, bunched | 3 m | 0.67 | 7.4 s | 0.63 | 8.1 m |

The wedge at doctrinal spacing is the best of the four *into contact*: most of its guns bear forward, it is
still deep enough not to be one target, and it hurt the enemy in half the time the bunched element took. The
column is the safest shape for *seeing* (it watches the whole circle) and the worst for a fight to the front:
eight seconds before it did any damage, because only the lead vehicle can shoot. That is the trade the
doctrine table makes when it picks a column for a road march and a wedge when contact is possible.

**Dispersion versus splash: no effect yet.** Against artillery the same wedge survived 0.91 spread out and
0.93 bunched — inside the noise. Today's splash and the absence of suppression mean bunching is not punished,
so "spread out" currently rests on frontage and armour facing alone. *This is combat's L2 (CP2): re-measure
suppression and splash against `closest_pair_m` when it lands.*

### Movement techniques: the same advance into the same guns (seed 31, 24 s)

| Technique | Ground taken | Survived (before suppression) | Survived (with L2, 2026-09-16) |
|---|---|---|---|
| Traveling | 50–59 m | 0.74 | 0.75 |
| Traveling overwatch | 96–97 m | 0.74 | 0.74 |
| **Bounding overwatch** | 63–65 m | **0.51** | **0.60** |

**Bounding buys safety by having one element *set* and able to cover the other — and covering fire only means
something when it makes the enemy shoot worse or stop shooting.** Before suppression existed, the overwatch
element was simply a stationary target that was not advancing, and bounding cost a quarter of the element
against just driving.

**Re-measured with combat's L2 merged (2026-09-16): bounding went from 0.51 to 0.60, closing about a third of
the gap, while traveling did not move.** So the mechanism works in the direction doctrine says it should —
but bounding still loses, and the reason is known and specific: nothing deliberately suppresses. Combat
measures a mean of 0.03 suppression per living unit across 16 matches, with nothing ever pinned, because
brains only fire at things they can kill. What moved this number is *incidental* near-misses from ordinary
fire. The rest of the gap is the missing "keep firing into that lane" option (see below). If bounding still
loses once that exists — especially with a Law element and its sonic emitter behind it — then the honest
answer is that the tables should stop choosing it, and they will.

### A halt: jumped from the flank at 45 m (seed 37, 14 s)

| Shape at the halt | Survived | First shot back |
|---|---|---|
| **Herringbone** (hulls turned out to their sectors) | **0.93** | 1.62 s |
| Column (parked as it drove in) | 0.69 | 1.35 s |

Facing your flanks at a halt is worth about a quarter of the element. The parked column got its first shot
away marginally sooner (its guns were already pointed down the lane the enemy came from) and then paid for
every second afterwards, because its flank armour was toward the guns.

### Next: what suppression changes (combat's L2, measured on their branch)

Combat measured that suppression bites: a pinned tank hits 5 of 13 shells at 60 m where a calm one hits 13 of
13, and takes 208 ticks instead of 105 to swing its turret 90°; one machine gun settles a tank at 0.42
suppression, two at 0.82. **But over 16 seeded matches the mean suppression per living unit is 0.03 and
nothing is ever pinned**, because no unit ever fires at *ground it wants denied* — brains only shoot at
things they can kill. So the base of fire in a far ambush or a support-by-fire task suppresses nobody.

What that means for the drills, in order:

1. **A base of fire needs an order that means "keep firing into that lane".** K1 has no such verb and the
   brains have no such option (`fire_at_will`, `target`, `hold_fire`, and `aim` never fires — trip-up 25).
   ai owns that option; doctrine owns *where* it points, which is the drill's job. Until it exists,
   `support_by_fire` and the base of fire half of `far_ambush` are engagement orders, not suppression.
2. **Trigger drills off suppression, not just hits.** `Tank.is_pinned()` (above 0.6) is the honest trigger
   for react-to-contact and break-contact; `ElementSituation.suppression_of()` already reads `Tank.suppression`
   when the build has it and falls back to recent hits when it doesn't.
3. **Route the maneuver element around the beaten zone.** `Match.is_beaten_zone(team, from, to)` and
   `Match.threat_along(team, from, to)` let the far-ambush flank pick a lane that is not being swept; today it
   swings a fixed `flank_m` off the line of contact and takes whatever ground is there. (Note the signature:
   the contract wrote `is_beaten_zone(from, to)`, and combat added the team first, because incoming fire has
   to belong to somebody.)
4. **Then re-measure**, with `make tactics-measure`: bounding overwatch (0.51 today against 0.74 for
   traveling) is the number that should move, and dispersion against splash is the other. Both halves of the
   trade should flip together — the base of fire starts buying something, and the element that bounds behind
   it starts surviving.
5. **The sharpest test will be a Law element** (combat's X4 rosters): the **sonic emitter** applies 4.0
   suppression per second in a cone, about ten times a machine gun, and the **gas rocket truck** 5.0 a burst
   over 14 m — both with almost no damage. They are suppression *delivery systems*, so an element built
   around "shut it down, then walk in" is where support by fire either pays or visibly doesn't. The Law's
   table already bounds at every threat level; if suppression works, that table should stop being the
   cautious one and start being the effective one.

### Drills (seed per scenario, `make tactics-drills`)

| Drill | What happened |
|---|---|
| Near ambush | Sprung at 25 m; the element turned into it, drove through to 1.9 m of the ambush position and out the far side **6.3 s** later; both ambushers destroyed, no losses |
| Far ambush | React to contact, then fire and maneuver: the base of fire held **4.6 m** off the line of contact while the other half swung **24.3 m** round; both guns destroyed, 3 of 4 alive |
| Bounding | A section was **set 38%** of samples while the other moved, and the element still made 50 m |
| Break contact | Outgunned pair broke from 76 m to **106 m**, both alive |
| Herringbone | Halted, all-round security, **1.0** of the circle watched |

## Open questions and requests

_See the stream's Status in `_agents/streams/doctrine.md`._
