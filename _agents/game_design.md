# Game design: what Tank Squad is (round 2 onward)

> **Source of truth for the game's rules and player experience.** Written 2026-09-15 from the lead's
> decisions after round 1. It **supersedes** earlier plans where they conflict: MechWarrior-style loadouts
> (weapons per hardpoint, components, heat sinks) and "players author doctrine instead of commanding" are
> out as the core loop. Numbers live in [balance.md](balance.md); the look in [art_direction.md](art_direction.md);
> where it's going commercially in [vision.md](vision.md). Every stream brief builds toward this file. Decisions
> marked **(lead)** are the lead's; **(proposed)** are defaults the streams may tune, recording why.

## The game in one paragraph

A **die-hard real-time squad tactics game** in a Death Race gladiator arena. Before each round you **spend a
budget on fixed unit types**: over-the-top converted war machines like the armored prison-bus dozer. You split
them into **up to 5 squads** and command **one squad at a time** with taps: pick a squad, tap where it goes.
Every vehicle is **smart on its own**. It uses cover, peeks out to shoot, picks targets its weapon is good
against, and avoids shooting its friends, because **friendly fire is real**. You win by combining units that
cover each other's weaknesses, like StarCraft's rock-paper-scissors, and by commanding squads better than your
opponent. Winning earns **credits** that unlock more unit types and bigger budgets.

## Pillars (use these to settle design arguments)

1. **For die-hard players.** Depth over dopamine. No pay-to-win, no premium currency, no shortcuts for sale,
   no ads, no energy timers **(lead)**. Progress comes only from playing well. The web version is free; the Android
   app is a paid app **(lead, intent)**.
2. **Over-the-top eccentric vehicles.** The lead: *"What made Mad Max and Death Race so good was the over-the-top
   eccentric vehicles. This makes it go from a nerdy army game to a fun game"* (in the spirit of the Metal Gear
   Solid era). Every unit is a character with a silhouette you remember ([art_direction.md](art_direction.md)).
3. **Simple units, deep combinations.** Units are **static** during a match: no upgrades, no weapon swaps
   **(lead)**. Depth comes from matchups, positioning, and squad coordination, not from menus.
4. **Smart autonomous units.** Even before any LLM, every vehicle behaves like a competent crew. The player
   decides *where* and *what*; units handle *how* **(lead)**.
5. **Fun first, desktop first** **(lead, 2026-09-15; replaces "mobile first")**. Controls are designed for mouse and
   keyboard (StarCraft-style) to find the fun; Steam is the primary target for now. Touch keeps working and gets its
   own adaptation later; Android with on-device Gemini Nano follows once the game is fun.
6. **Readable at a glance.** You can always tell whose unit it is, what type it is, and where your squads are
   going, even in the dark neon arena.
7. **Alive and responsive** **(lead, 2026-09-15)**. Units obey instantly, never get stuck, and fight like they want
   to win: they move while shooting, dodge, flank for weak spots, and use cover. Arcade-tactical: Twisted Metal
   energy inside an RTS, with counters that still matter.

## Round 3 direction: the lead's playtest verdict (2026-09-15)

After playing the merged round-2 build, the lead:
- *"it's still currently boring and no fun to play … right now this is looking like a military nerd game instead of
  something that's fun to play."*
- **Controls:** *"having to click between squads is quite burdensome; I would say we should draw inspiration from unit
  combat completely from starcraft (i.e. regroup units, click individual units, the units are actually responsive) …
  Trying to manage different formations is overwhelming … re-imagine this in the interest of making it fun (and
  perhaps that even means we target Steam as our primary platform so we can shift, right click, etc)."* Decided:
  **desktop first, StarCraft-style control** (see *Controlling units*).
- **Responsiveness:** *"the units just don't feel controllable right now, they seem to get stuck in some particular
  state and then not respond to my clicks; units within the same squad ended up getting separated and didn't
  rejoin."*
- **Combat feels dead:** *"Tanks will just sit there stationary and shoot each other - there's no intent at evasive
  action, no intent of trying to shoot a weak spot, no intent of trying to circle your opponent (i.e. move
  tangentially from your opponent while shooting at him). There's no action from the computer player to use
  different formations or flanking maneuvers. There's no intent to pop in and out of cover."*
- **Weapons:** *"Tanks should shoot at very low frequency and be able to land devastating hit, but a miss is also quite
  costly. The IFV's were supposed to have something like a 25mm cannon like a Bradley fighting vehicle where it's
  basically a low frequency machine gun (but much higher frequency than a tank). The scouts currently are not
  shooting machine guns (note that I would think machine guns in and of themselves with their wall of bullets would
  even be valuable in circumstances, even though they can only shoot directly forward)."*
- **Inspiration:** *"another game I'm drawing inspiration from is Twisted Metal 3 that I remember playing as a kid (and
  it was fun)."* Decided: **arcade-tactical** feel.
- **Formations:** *"the formations are definitely cool and useful, I know they serve practical purposes and a V
  formation of scouts from the gang coming at you would be scary; I just don't know how to incorporate it well."*
  Decided: formations become **automatic** (see below); the CPU uses them visibly.

## Round 4 direction: doctrine, vision, scale (lead, 2026-09-16)

The lead played the round-3 build: *"this is for sure much better … I can see that the gameplay definitely feels
smarter"*, and set the next round's direction.

### Camera and vision: the view is earned, not given

> *"the game is still fairly unplayable because the camera doesn't really track the vehicles … we should optimize for
> the game being more zoomed in in general (i.e. closer to a Twisted Metal versus Starcraft if we put those 2 on a
> spectrum) … it really should automatically track the entire set of friendly units, and basically always zoom in as
> close as possible with the constraint can see the same horizon as what all units can collectively see … a bird's eye
> view is just an unearned god view; we want to actually make the users expend their sentries to be able to see."*

- **The camera frames what your force can see**, as close as that allows: fit to the sight of the element you're
  commanding (plus its spotted contacts), clamp to a maximum closeness, smooth it, and let manual panning always win.
- **Scattered forces:** frame the element you're commanding (the lead agreed); the rest get off-screen markers and
  alerts you can jump to. Switching elements moves the camera.
- **Consequence, deliberately:** seeing the far side of the arena costs you a scout. Vision is a resource.

### Doctrine: trained crews with standard operating procedures

> *"this game will get its novelty from the use of sophisticated battle drills and formations … I'm certain all military
> formations and battle drills are on a degree of science for their effectiveness … battle formations should be a
> tactical advantage - the key is to figure out how to intertwine this with our UX and playability (and also, if the
> opposing computer player can easily create sophisticated formations all the time while the player can't or the
> player's units don't automatically do the same formations a computer does, it would be no good) … the problem is just
> that it's way too much micromanaging to get the units into a specific formation; we should generally treat the game as
> cases where we're commanding well trained battle squads who operated based on standard operating procedures (like the
> army does) … if a unit gets ambushed, the standard operating procedure is to face the direction of the ambush and
> charge forward."*

- **The player commands tasks, never geometry:** move here, take that, screen this flank, support by fire.
- **Every element has a leader** that picks the movement formation and technique from a doctrine table (terrain, threat,
  task, composition) and runs **battle drills** on contact: react to contact, near and far ambush, break contact,
  bounding overwatch, support by fire, assault through, herringbone on halt.
- **Doctrine comes from the literature** (Army field manuals on movement formations, movement techniques and battle
  drills), encoded as data. Self-play measures which drill wins where and tunes the triggers.
- **Parity is architectural:** the CPU and the player's elements run the **same** doctrine library. The player's edge is
  where, when, and with what composition, never manual micro.
- **Formations must pay off through mechanics that already exist or are being added** (mutual support, sectors of fire,
  armor facing, firing lanes, spread versus splash, frontage and spotting), never a "formation bonus" number.

### What earns a place in doctrine (ruled 2026-09-16, from measurements)

Two drills lost to "just let the brains fight" this round, each measured on the same units, enemy and seed:
- **Bounding overwatch** cost survival (0.51 vs 0.75 traveling) until suppression existed, and even with it only
  recovered to 0.60, because covering fire that can't pin is a stopped vehicle.
- **The circular swarm** ("a pack of hyenas") dealt **a third of the damage for identical survival**: circling stops
  units shooting, and the encirclement it was meant to buy already happens, because the brains flank on their own.
  It ships switched off behind its table flag, with the numbers kept for the discovery harness to revisit.

**The rule:** a drill earns its place by deciding *where an element goes and what it points at*, not by driving
vehicles that already fight well. Anything that takes the wheel away from a good brain has to prove it wins.

### Suppression and effective fire

> *"This game should have real concepts of suppressive fire and effective fire (i.e. vehicles make decisions to avoid
> walking into a wall of bullets that will kill them, and opposing forces could concentrate their fire power to create
> those suppressive fire effects or cut off an avenue) … tanks would probably want to provide protective cover for
> weaker units."*

Suppression is what makes drills real: without a wall of bullets that units respect, "base of fire plus maneuver" is
theater. Near-misses build suppression (worse accuracy, pinned units), brains avoid beaten zones, machine guns earn
their place through volume, and heavies interpose themselves between threats and fragile units.

### Army size and factions

> *"I basically want a lot of units but I don't want to stress the performance of the game … a baseline of 30 units per
> side … different factions should have different unit sizes based on the effectiveness of each unit (i.e. the gang is
> diluted with cheaper units, so it should be a bigger swarm, the condemned have more expensive and smaller unit counts
> from there, then the law has more expensive and smaller unit counts from there, and the syndicate would have the
> fewest number of units)."* And: *"while the different factions might have largely similar vehicle types, we can
> definitely make them have different automated tactics."*

- **Baseline ~30 units a side** for the mid faction, if performance allows; measure first (25 / 40 / 60 / 100) and set
  the budget from what holds 60 fps with headroom.
- **Counts fall out of cost and effectiveness,** not fixed numbers: gangs swarm (cheapest), then the Condemned, then the
  Law, and the Syndicate fields the fewest, best units.
- **Factions differ most in doctrine:** gang packs encircle and circle to spread damage ("like a pack of hyenas"), the
  Law advances by bounds behind suppression, the Syndicate kites and repositions.
- **Command stays control groups plus automatic elements** (the lead: a named hierarchy *"doesn't sound much like a game
  unless there's a sleek way we can figure that out from a UX perspective"*).

### Offline tactics discovery (framework, after doctrine)

> *"another framework we haven't explored yet is to create a local, offline simulation of our game that we could plug
> into an AI brain (i.e. AI agents play against each other somehow in the game, or have more explicit control of
> individual unit decisions, and possibly even in slow motion as necessary) not for the purpose of live gameplay, but
> for the purpose of discovering novel tactics and decision making, and somehow formalizing those discoveries into
> deterministic heuristics."*

Doctrine from the literature comes first; the harness that plays tactics against each other (seeded, headless, on
builder0) measures and tunes them. The LLM-plays-the-game layer (through the existing agent bridge, at a slow cadence,
proposing tactics as data) is the discovery experiment on top, and anything it finds is distilled into deterministic
rules before it ships. Nothing runs a model during live play.

### Matches are between different factions (lead, 2026-09-16)

From the lead's announcer review: **the booth names a side by its faction, not its colour** (the Condemned, the
Wreckers, the Law, the Syndicate), and **a match is always between two different factions**. That makes the
commentary sayable, and it makes faction identity the thing the player reads on the field. Mirror matches would need a
naming scheme the booth can't speak, so they're out. It binds combat (army generation and the match runner), the
garage (army building), and audio (lines are recorded per faction). The caller is canonically **Joseph**.

### Audio: cinematic, and alive

> *"The sound effects for the game also currently completely suck … right now the sound effects make it sound like an
> atari game rather than a gritty action game … we can have an agent go ahead and run the full ElevenLabs pipeline …
> some of them were fairly repetitive (i.e. same opening announcement from the syndicate announcer lady across multiple
> cases) … the best case is a living, breathing music selection with the game."*

- **Cinematic exaggeration** (the lead's choice), not documentary realism: layered sounds, long tails, weight.
- **Announcer:** fix the repetition (more openers, recency memory across matches, more slot variety), then run the real
  ElevenLabs generation and wire the booth into live matches.
- **Music:** a director driven by the same match-mood signal as the announcer and crowd: one track per state (garage,
  pre-match, maneuver, sustained battle, heavy or last stand, victory, defeat), tempo and loop points recorded,
  beat-aligned crossfades, stingers, ducking under the announcer. The lead writes the tracks in Suno later
  (`/tmp/music_prompt.md` holds the style prompts); the pipeline and the per-state prompts come first.
- One agent owns the whole audio pipeline: announcer, sound effects, and music.

## Round 5 direction: the lead's playtest of round 4 (2026-09-17)

> *"right now for this many vehicles the framerate drops substantially. We should fix this one way or another, and I
> suspect that might be possible without so many wild lighting effects (i.e. I bet we can make the game feel more
> realistic and get better frame rate at the same time). The sound effects for the guns and stuff are currently lame.
> Right now the game is still unplayable (mostly because frame rate is bad now) but also because the maps are just too
> simple. We probably need a dedicated agent to formulate maps. I'm also not seeing the assets I asked for earlier like
> the big dystopian TV screen in the match or the shipping containers as re-usable components in the arena. As far as I
> know there's only one map right now and it's boring and doesn't provide any meaningful way to do tactics. Right now
> the game is also unplayable with the camera, it ends up focusing on the enemy instead of our own friendly units. The
> startup screen seems stuck, I can't actually click any of the first buttons, and when I do manage to start the game
> there's a bunch of red error messages in the console log. Also, the accent lights on all the vehicles make those
> lights the overwhelming thing seen by the game (i.e. I don't see tanks, I see blue lights). Also right now, I can't
> tell if perhaps the vehicles have too much range, but when I play the game now it's just these 2 masses shooting at
> each other."*

Decided with the lead: **faction art ships** (desktop first; the web build stays lean), and round 5 **stays on combat
feel** rather than reopening the garage and progression loop.

### What this means, by area

- **Frame rate is the blocker.** A full-scale battle must hold 60 fps on the lead's laptop (Intel UHD 620). The lead's
  hypothesis is worth taking seriously: fewer, better-motivated lights and effects should buy both performance *and* a
  more grounded look. Neon is mood, not the subject.
- **Vehicles must read as vehicles.** Team accent lights currently dominate: *"I don't see tanks, I see blue lights."*
  Team identity has to survive at a fraction of the current glow.
- **Maps are a discipline of their own.** One flat symmetric arena gives tactics nothing to work with. Arenas need
  lanes, chokepoints, cover that matters, sightline breaks, and the arena kit that already exists (stackable
  containers, ad screens, barricades, signs) actually placed in them. Several arenas, each with a different character.
- **Engagement ranges decide whether there's a game.** Two masses trading fire at max range is not maneuver. Weapon
  ranges, sight, and arena size have to make closing, flanking and cover the way to win.
- **The shell has to work:** the title screen accepts clicks, the camera frames *your* units, and the console is clean.
- **Guns must sound dangerous** (the ElevenLabs sound-effect half of round 4's audio work).

### The lead's round-5 sign-off (2026-09-17)

Eleven decisions, answered on the sign-off page (https://claude.ai/artifact/CWhVvcNj7BQBigp5N27kDW; answers live in
its `decisions/<id>` documents). Where the orchestrator recommended otherwise, the lead's answer is marked
**overruled** — those are the ones a future agent must not quietly revert to the "sensible" option.

| Decision | Answer | Notes |
|---|---|---|
| Gun sound batch (~520 credits) | **Run the batch** | The pilot shipped as-is, no changes |
| Ad copy (12 screen ads) | **All of them work** | No cuts, including the two the orchestrator flagged as near-punchlines |
| Arena screens | **Live match content during the fight, ads between** | render draws it; audio's PA reads pair with the between-match state |
| PA lines (~1,500 credits) | **Record them** | Unblocked by the copy approval in the same pass |
| 30 Hz simulation tick | **Start now** (*overruled*: the recommendation was round 6) | combat owns it; the frame rate is what stands between the lead and playing his own game |
| Neon glow (1.6-1.9 ms GPU) | **Keep it** | The frame is simulation-bound; switching it off buys nothing today |
| Team identity | **Rim tint is enough** | No per-team hull paint. The tracer fix and the lit floor solved the read; colour was never the problem |
| Which arena is fun | **Not played yet** | Still open |
| Arena selection | **Players pick** (*overruled*: the recommendation was random-only for now) | control's faction-menu ARENA row, with Random kept as the default option |
| Map generator | **Park it** | `make arena-candidates` stays a tool, not a direction |
| Destructible cover | **Schedule it** (*overruled*: the recommendation was to park it) | Approved as designed — a stack collapses to a lower stack, never changing drivable space. Not landed in round 5: two cross-stream changes at once (with 30 Hz) would make failures unattributable |

## Units: fixed types that counter each other

Each unit type is a fixed package: chassis, one weapon, armor, speed, sight, cost. **No loadouts.**
Round 1's weapons don't disappear; they move onto unit types (the lead: *"the laser is awesome, but we'll
just move that to a different unit type"*).

### Starting roster (proposed; the lead named the scout, tank, and IFV)

| Unit | Real-world idea | Weapon and mount | Strong against | Weak against |
|---|---|---|---|---|
| **Scout** | armored rally truck / dune buggy | **fixed forward machine gun, no turret**: it only hits what it points at **(lead)** | artillery, lasers (fast, gets close, hard to track) | IFVs (fast turret, autocannon shreds light armor) |
| **Tank** | the prison-bus dozer (in the game now) | heavy cannon on a **slow turret** **(lead)** | IFVs, anything heavy that sits still | scouts (the turret can't track them), massed IFVs flanking |
| **IFV** (Bradley / Stryker) | armored bus or garbage truck | **30 mm autocannon**: fast fire, low penetration, **fast turret** **(lead)** | scouts and light units | tanks (can't get through front armor) |
| **Artillery** | crane carrier with a mortar battery | indirect arcing fire, minimum range, needs a teammate's sight | slow clumps, units holding still | scouts, anything that closes the distance |
| **Lancer** (laser) | converted power-utility truck | long hitscan beam, **heat-limited**, strips shields | tanks at range, shielded targets | scouts, IFV rushes |

**Artillery deploys before firing** (proposed 2026-09-15, from the approved crane-carrier concept's outrigger legs):
a deploy and pack-up time (arms extend, legs lower) during which it can't move or fire, like a siege tank. It makes
scouts punishing counters and positioning a real decision. Rules owns a `deployed` state and timing; art animates it
from a slot method (e.g. `set_deployed(ratio 0..1)`) with rigid parts, no skeleton. Today the outriggers are baked
into the hull mesh in the deployed pose, so art needs them as separate parts (cut from the Meshy mesh, or simple
hand-built telescoping beams that hide the seams).

The flamethrower becomes a candidate future unit (a close-range "Burner"). Future units are added one at a
time, each with a clear job and a clear counter.

**Rules that make matchups real** (proposed, rules stream): turret turn rate vs target angular speed decides
tracking; penetration vs armor facing decides whether a hit hurts; fixed-mount weapons only fire inside a narrow
forward arc; scouts' speed beats slow turrets; artillery's minimum range punishes being rushed. Matchups must
emerge from these mechanics rather than a damage multiplier table, and be **measured** with the match runner
(a unit-vs-unit matrix in balance.md).

**Locomotion: wheels drive like cars** (lead, 2026-09-15: *"when we move to wheeled vehicles, they won't be able to
turn like a tank, they will have a turning radius and will need to drive like cars"*). Not built yet: as of
2026-09-15 every unit steers like a tank (rotates at a fixed rate, even standing still, and pivots in place when the
target is behind it; `game/tank/tank.gd`, `game/ai/steering.gd`).
- **Tracks** pivot in place and turn at a rate (the dozer tank).
- **Wheels** can't rotate while stopped: yaw rate = speed ÷ turning radius, down to a minimum radius per unit; steering
  inverts in reverse; tight spots need multi-point turns. Proposed for today's roster: **scout, IFV, artillery, and
  Lancer on wheels, the tank on tracks**, matching their base vehicles.
- Later: **articulated** trucks (the gang war rig: a trailer that follows, the widest turns) and **hover** (strafes,
  drifts on momentum; the Syndicate).
- **A kinematic model we own, not physics wheels** (`VehicleBody3D` is hard to network, to AI-drive, and to make
  deterministic): curvature-based, pure math in `TankMotion`, integer-friendly (determinism.md).
- **Why it matters for play:** a fixed-gun scout on wheels aims by driving, so it fights with attack runs and circling
  instead of pivoting in place; wheels want open lanes, tracks win in dense cover, and arenas (containers, chokepoints)
  become a locomotion choice. It's a counter lever, not just realism.

**The scout's job, ruled 2026-09-15** (ai asked; the lead's answer to rules in round 2 decides it): *"scouts should be
spotters more than fighters, but there will be cases where its machine gun is useful."* So:
- **Spotting is the default behavior.** A scout keeps its distance (rules' roster test: it spots a tank from beyond
  70 m) and feeds team sight. A brain that abandons spotting to hunt engine decks is not the champion, even when it
  wins more duels.
- **Rear-deck runs are opportunistic, not a doctrine:** allowed when the target is reloading, already hurt, occupied,
  or cut off, and there's an escape route. Measure them as a bonus, never as the scout's counter to tanks.
- **The matchup matrix must not expect scout > tank.** Scouts counter artillery and Lancers (fragile, slow-turreted,
  long-range units), and screen for the army.
- **A counter in `good_vs` must be real in the mechanics** (ai measured `scout > lancer` as impossible: a machine gun
  does 15–29 shield dps against a 120 shield recharging 45/s, so the Lancer never drops). Combat either makes it pay
  (machine-gun penetration or shield behavior) or removes the claim from the catalog. Design intent alone isn't a counter.

**Weapons feel (lead, 2026-09-15; the round-3 combat stream implements it):**
- **Tank:** very low rate of fire; a heavy, visible shell that lands a **devastating hit**; a miss is costly (long
  reload), so leading the target and timing matter.
- **IFV:** a **25 mm Bradley-style cannon**: bursts at a moderate rate, far faster than the tank, far weaker per round.
- **Scout:** a real **forward machine gun**: a stream of tracer rounds, a wall of bullets that only hits what the hull
  points at. Deadly against light targets, rears, and exposed crews.
- **Weak spots:** side and rear armor are clearly punishing, so maneuvering for an angle pays off.
- Hits read instantly: impact effects, sparks on armor, a distinct weak-spot hit.

**Keep from round 1:** Halo-style recharging shields over hull health (the lead chose them), finite ammo with
base resupply (rules stream may simplify if it doesn't add decisions), heat only where a unit's weapon uses
it (the Lancer). **Drop:** components, heat sinks, ammo racks, per-hardpoint weapons.

## Factions (lead, 2026-09-15)

The lead: *"So I think we're settled on the idea for factions. We want them, and we'll make them wildly different
characteristics. We will figure out over time how to balance the factions."* Not scheduled yet: round 2 builds one
roster (today's vehicles become the Condemned).

**Principles**
- **Same roles, wildly different trade-offs.** Every faction fills the same five roles (scout, tank, IFV, artillery,
  special), so counters stay learnable, but each role plays differently per faction. The lead's example: the gang's
  tank-class vehicle is a converted fuel truck whose back is a giant war machine, in the spirit of Death Race's
  Dreadnought, not a dozer with different numbers.
- **One shared mechanics vocabulary.** Mechanics are built once in rules (shields, field repair, turning circle vs
  pivot steering, pinning harpoons, burning ground, energy vs ammo, …) and a faction's identity is the combination
  it gets. The AI learns each mechanic once, so faction count doesn't multiply AI work.
- **Counters live between units, not factions** (lead, 2026-09-15: *"I was talking rock paper scissors across
  units. The gang shouldn't inherently be weaker than the syndicate"*). Every faction must have an answer to every
  enemy unit type, so any faction pair is near 50/50 when both sides build good armies. A mechanic that is strong
  against one faction's units (knockback vs light hover units, hover vs ground hazards) is balanced by that faction
  having other units that answer it, and scales with unit properties (knockback by mass), never with the faction.
  **Measure both levels:** the unit matrix shows clear counters; faction vs faction, each with its best searched
  army, lands near 50%. Where it doesn't, add or tune a unit-level answer.
- **Locomotion is part of the vocabulary** (see *Locomotion* above): tracks on the heavies and heavy wheels elsewhere (Condemned), articulated trucks and wheels turn
  wide but run fast (road gangs), heavy wheels are quick and controlled (the Law), hover strafes and drifts on
  momentum (the Syndicate). Factions read apart by how they move.
- **A faction is a choice, never more power** (pillar 1). Unlocking one, if ever, is a sidegrade.
- **Balance over time** with headless simulation: the matchup matrix across factions, plus a search for dominant
  armies ([determinism.md](determinism.md) keeps runs reproducible). Playtests judge feel and exploits.
- **Our own names and designs.** Mad Max, Death Race, and Judge Dredd set the vibe; no copied vehicles or names.
- **People are visible, violence isn't graphic** (proposed): riders and crews on vehicles, **crews bail out** when a
  vehicle dies, riders are thrown clear as damage builds, no blood or gore. Target around ESRB Teen / PEGI 12 (the
  Google Play IARC questionnaire decides). Explosions, fire, and scrap carry the spectacle.
- **Readability:** faction lighting (Law strobes, Syndicate cyan) must never be confused with team accent colors.

**The four factions (working names and first ideas)**

| Faction | Who | Look | Trade-offs | Signature ideas |
|---|---|---|---|---|
| **The Condemned** | Convicts fighting for freedom; the crowd pities them | Prison dozers, armored buses, garbage trucks: tall, boxy, welded shut, hazard paint, cage mesh | Tough, cheap, holds ground; slow | Today's roster: a tracked dozer tank, wheeled light units, shields |
| **Road gangs** (the Wreckers / Scrapborn / Chrome Cult) | Wasteland raiders; the crowd favorite | Low, open hot rods and buggies on huge tires; chrome, rust, spikes, fire; visible crews | **No shields**; fast, cheap, deadly up close, fragile; wheels with turning circles | Field repairs by crews; explosive spears (high penetration, short range); harpoon ballista that pins; catapult of flaming barrels leaving burning ground |
| **The Law** | The state's wardens, the house team the crowd boos; the **baseline faction**, easiest to learn (closest to the lead's original sci-fi army vision) | Militarized cyberpunk police, **professional but worn down** (a failing state): MRAPs, up-armored cruisers, 8×8 assault guns; red and blue strobes, spotlight towers, holo POLICE projections; one exaggerated feature per vehicle | Reliable, moderate damage, heavy wheels | Information and control: reveal, spotting, tear gas and smoke that cut sight and accuracy, knockback scaled by target mass |
| **The Syndicate / "the Sponsors"** | The corporation that owns the show; every match is a product demo | **Curvy sci-fi hover vehicles** (the lead: like Halo's Wraith, but human corporate luxury, our own designs): **ivory tower**: immaculate glossy ivory or black shells, cyan light lines, sponsor logos, hover glow lighting the floor, unmanned | Few, very expensive, strong at range; hover drifts and has lighter armor | Energy (heat and shields) instead of ammo; railgun; lasers (the Lancer); spotter-guided missiles; a shield projector; optical camo |

**Road gang roster sketch:** scout = spear buggy; IFV = hot-rod pickup with twin salvaged machine guns and spear
riders; **tank = the fuel-truck war rig** (lots of scrap hit points, fast in a straight line, wide turning circle,
rams, harpoon ballista, spear riders; weak when flanked while turning); artillery = catapult truck; special =
war-drum truck that rallies nearby units, or a resupply tanker. Idea pool: hub blades that damage what they pass,
a wrecking-ball crane, caltrops or oil slicks, nitro bursts.

**The Law roster sketch:** scout = up-armored pursuit cruiser (ram bar, giant light bar, hood gun, siren pulse that
briefly reveals hidden units); IFV = Cougar-style 6×6 MRAP with a remote autocannon turret; **tank = 8×8 wheeled
assault gun** (Stryker-style: big cannon, faster than the dozer, less armor, longer sight); artillery = truck rocket
launcher firing tear gas and smoke; special = riot truck with water cannon or sonic emitter (knockback).

**The lead's concept picks, 2026-09-15** (approved on the three faction review pages; the picks settle the roles the
roster sketches left open): gangs = semi tanker (tank), rat rod (scout), 1950s pickup gun truck (IFV), tow-wrecker
catapult (artillery), **resupply tanker as the special** (not the war-drum truck); the Law = 8×8 assault gun, pursuit
sedan, retired APC, gas rocket truck, **sonic emitter as the special** (not the water cannon); the Syndicate = supercar
hull tank, teardrop scout, black-glass limousine IFV, missile-wing ring artillery, **the Lancer laser as the special**
(not the shield projector). Both wreck husk concepts were approved.

**Syndicate roster sketch:** scout = hover skimmer drone with optical camo; IFV = hover gunship with a heat-limited
pulse cannon; **tank = curvy hover battle tank with a charge-up railgun** (the conventional tank role, made sci-fi);
artillery = missile platform that fires only at spotted targets; special = shield projector or the Lancer laser
(decide with the full roster).

**How each faction looks: a wear spectrum** (the lead, 2026-09-15: *"The Law should look more professional than
the condemned, clearly but all their vehicles should still be pretty worn down (showing the signs of a defective
state). The Syndicate of course will have an ivory tower vibe"*). Wear and polish tell each faction's story, and
make them readable at a glance:

| Faction | Condition | Concept-art cues |
|---|---|---|
| **The Condemned** | Scrap welded by prisoners | Rust, grime, raw weld seams, cage mesh, faded prison stencils and inmate numbers, hazard paint |
| **Road gangs** | Rusted but *loved* | Rust and dust with polished chrome engines, hand-painted flames and skulls, trophies bolted on: pride in their machines |
| **The Law** | Institutional, **neglected** | A uniform livery that is clearly an organization, but faded and peeling; mismatched replacement panels in primer; rust at the seams; dented, patched armor; a light bar with dead bulbs and a cracked lens; retrofitted cyberpunk gear zip-tied onto old hulls; faded unit numbers and "PROPERTY OF" stencils. Professional design, failing upkeep |
| **The Syndicate** | **Immaculate**, the ivory tower | Spotless even in the grime of the arena; seamless curved panels, pearl and ivory finishes with black glass and thin gold or cyan trim, discreet luxury logos, no visible fasteners or wear; the only faction that looks brand new. Their contrast with the arena is the point |

**Rendering crews cheaply:** oversized "miniature scale" riders baked into the vehicle model, shader sway or a few
rigid moving parts (no skeletons), detail saved for close-ups (army builder, kill-cams, victory), and the same
cheap figure tech as the arena crowds.

## Army, squads, budget

- **Before the round:** a budget, **buy any mix of units, and divide them into up to 5 squads** **(lead)**.
  Squads hold up to 5 units (formations place 5) **(proposed)**. Army size is limited by budget.
- **Squads are the unit of command.** The player commands one squad at a time and **switches squads with one tap**
  (a squad bar) **(lead)**.
- **Cosmetic paint** stays optional and free (never sold). Team identity comes from accent lights.

## Progression: credits earn more options

- **Winning earns credits** **(lead)**. Credits unlock **new unit types** and **higher budget tiers** (bigger armies).
- **Fairness guard (proposed; important for die-hard players):** matches are fought at a **shared budget tier**.
  Both sides get the same budget, so a veteran's bigger bank never buys a bigger army against a newcomer. Unlocks
  add *options*, not raw power: units are sidegrades by design (counters, not upgrades). Losing still earns a
  little. Competitive/ranked play (later) uses fixed budgets and the full roster.
- **No money in the loop**, ever (pillar 1).
- Progress is saved locally first (`user://`); an account system comes with online play (netcode, later).

## Controlling units (desktop first, StarCraft-style; lead 2026-09-15)

- **Select anything:** click a unit, drag a box, shift-click to add or remove, double-click (or ctrl-click) to select
  every visible unit of that type. Number keys: ctrl+1–9 saves a control group, 1–9 recalls it, double-tap centers
  the camera. **Squads become ordinary control groups**, not a mode the player must switch between.
- **Right-click orders:** right-click ground = move; right-click an enemy = attack; A + click = attack-move (fight
  what you meet on the way); shift queues orders; S = stop; H = hold position; F + click a friendly = follow/escort.
- **Orders are instant and always win.** A unit given an order starts executing it within a few ticks, whatever its
  brain was doing; nothing leaves a unit unresponsive. Units that get separated regroup on their own.
- **Formations are automatic.** A selected group moving together arranges itself by role and situation (heavies in
  front, fragile units behind, fast units spreading into a V when charging, a line when holding). One optional key
  cycles a formation for players who want control. The CPU uses formations visibly (a scout V charging at you).
- **Readable feedback:** move and attack markers on the ground, a selection panel with the selected units' portraits
  and health, clear hover and selection highlights, and sounds on order acknowledgement.
- Touch stays supported through an adaptation layer (tap select, drag box, two-finger pan), designed after the desktop
  controls are fun.
- History: rounds 1–2 designed a mobile-first tap grammar (tap a squad, tap the ground; squad bar; formation picker).
  It's in [tactical_map.md](tactical_map.md) and archive/round2/command.md; the round-3 control stream replaces it.

### Round 2's mobile commanding (superseded 2026-09-15)

- **Tap a squad** (its chip in the squad bar, or any of its units on the map) → **tap the ground or the radar**
  → it goes there **(lead)**. No right-click. Advanced (optional): hold-and-drag to set facing.
- **Formations get icons** that show the shape, drawn from the real formation geometry, so a non-military
  player sees what "wedge" or "echelon right" means **(lead)**. Drills (move, bound, hold, assault, break
  contact) get icons and one-line plain-language descriptions too.
- **The camera follows the action** **(lead)**: after an order to somewhere off screen, the camera smoothly tracks
  the squad (or frames squad + destination) instead of making the player zoom out and back in. Manual pan
  always overrides; a tap on the squad bar re-centers.
- Commands stay **SquadCommand data** ([tactical_map.md](tactical_map.md)), so the CPU, Claude, and a future LLM
  commander use the same verbs as the player.

## Unit AI: really good, before any LLM

The lead wants this *"really sophisticated"*. The player's orders set intent; each vehicle's brain does the rest:
- **Cover:** find positions that block line of sight to known threats, reach them, **peek out to shoot and duck
  back** (fire from cover, reload in cover), and prefer hull-down angles that show front armor.
- **Target selection by matchup:** engage what my weapon is good against; avoid duels I lose; call for help.
- **Friendly fire awareness:** never take a shot whose line of fire (or splash) crosses a friendly, or weigh the
  risk explicitly; move to clear a firing lane.
- **Squad tactics:** bounding overwatch, suppress-and-flank, focus fire, covering a retreating teammate,
  protecting fragile units (artillery, Lancers).
- **Alive in combat (lead, 2026-09-15):** move while shooting (circle-strafe: move tangentially around the target),
  take evasive action (jink, dodge slow tank shells), maneuver for side and rear shots, pop in and out of cover, keep
  the range that suits the weapon. The CPU opponent flanks, uses formations, focuses fire, and retreats hurt units.
- **Player orders always override** the brain immediately (pillar 7).
- **Deterministic, measurable:** pure decision functions, seeded; behavior regression scenarios ("peeks from
  cover", "holds fire when a friendly crosses") plus AI-vs-AI tournaments with ELO so a new brain must beat the old one.
- Grounding in game-AI literature: utility AI (what we have), tactical position evaluation (Killzone,
  CryEngine's Tactical Point System, Unreal's EQS), influence maps, and GOAP-style squad coordination (F.E.A.R.).
  Details belong in the AI stream's design doc.

## The arena

- A **gladiator arena** in a converted industrial site, with **stands full of cheering crowds** that react to the
  fight (big kills, close calls) **(lead)**.
- **Textured ground** and **better lighting**: readable at night without losing the neon mood **(lead)**.
- **Map layouts (proposed): authored, symmetric arenas as data, not a full procedural generator yet.**
  Competitive fairness needs point symmetry and curated cover, which generators struggle to guarantee. A small set of hand-made
  layouts (cover, lanes, chokepoints) plus optional seeded variation of dressing is the right first step; revisit a
  generator once we know what makes a good layout. The lead was unsure whether a generator is worth it; this is the recommendation.
- Unit art and arena art come from the Meshy pipeline, **with the lead approving concept images before any
  image-to-3D request** **(lead)**.

### The arena kit: reuse beats new assets (lead, 2026-09-15; not scheduled)

The lead expects asset size to balloon as maps fill up, and proposed two highly reusable pieces. The principle:
**arenas are layouts (C5 JSON) over one shared prop kit**, so a new arena costs kilobytes, not megabytes. Download size
is driven by textures, not meshes: share texture sets, vary instances in shaders, and watch `tools/assets/pck_report.py`.

**1. Shipping containers** (20 ft: 6.06 × 2.44 × 2.59 m; 40 ft: 12.19 m long)
- Two simple meshes (a few hundred triangles) sharing **one** corrugated-steel texture set. Hand-built or CC0 beats
  Meshy for simple hard-surface shapes (verify and record licenses). A 40 ft container is its own mesh with tiled
  UVs, never a stretched 20 ft.
- **Variation without new textures:** per-instance paint color, rust and grime amount, door open or closed, and a
  stencil decal chosen in the shader. Faction-flavored stencils on the same mesh: prison transport, "EVIDENCE" and
  impound (the Law), sponsor-branded (the Syndicate), spray-painted gang tags.
- **Stack them** into walls, towers, and chokepoints. Draw every container of a kind with one MultiMesh (one draw call
  per kind, however many are placed).
- **Gameplay:** containers are axis-aligned boxes, ideal for cover features (C4) and portable collision
  (determinism.md). Stack height is a design lever: one high is hull-down cover, two high blocks line of sight.
- In layout data: `{"type": "container_20", "position", "rotation_deg", "stack": 2}`.

**2. Giant screens** (the Syndicate's arena broadcast, Blade Runner billboards)
- A flat quad with an emissive shader: cheap geometry, and the brightest thing in a night arena.
- **Content without video files:** still ad images or small flipbook sheets, animated by the shader: slow pan and zoom,
  scanlines, CRT flicker, glitch transitions between ads, a scrolling ticker. Avoid real video on web and phones (CPU
  decoding and file size).
- **Text is overlaid, not baked into generated images** (AI images garble text): a font label or font atlas over the
  image, which also allows translations and live text.
- **Live match content:** score, kill feed, shifting betting odds ("RUST 3:1"), sponsor reactions when a Syndicate unit
  scores, the announcer's hype lines. Kill replays rendered from a second camera only on the high quality tier.
- **Light spill:** each ad frame stores its average color, and the screen tints a fake light splat on the ground and
  nearby props (references/fx_tricks.md), so the arena flickers with the ads at almost no cost.
- **Ads are dystopian satire of our own fictional brands** (never real brands or real people), in the spirit of
  GTA's over-the-top radio. First ideas:
  - *Syndicate Life Insurance: "Because you won't make it."*
  - *"CONDEMNED? Win your freedom tonight!\* \*Terms and conditions apply."*
  - *The Law: "Report your neighbor. Earn ration credits."*
  - *AquaCorp: "Hydration is a privilege."*
  - *Organ Futures: "Invest in tonight's champion."*
- **Audio later:** PA jingles and ad voice-overs between rounds (an in-house synthesized corporate voice may fit the
  dystopia better than a human one). The lead's GTA reference sets the tone: ridiculous, dark, funny.
- **Size:** ad images around 512 × 1024, compressed, a few hundred KB each; keep a budget (e.g. 20 ads) and consider
  loading extra ad packs after the game starts.

**Art direction:** these ideas supersede round-1 bans on logos, text, and pristine surfaces (the lead, 2026-09-15);
art_direction.md is updated to match.

### The arena announcer (stretch; lead, 2026-09-15)

The lead: an ElevenLabs pipeline for *"an arena commentator … We'd want the announcer to make it feel like a sporting
event"*, then: *"we can formulate massive dumps of audio data and then just randomly select some fitting phrases …
some giant decision graph where many edges link to many nodes, and traversals are chosen at random."*

**Voices.** Original voices designed from a written description (ElevenLabs Voice Design), aiming at an archetype: a
hyped, conversational fight-night crew. **Never an imitation of a real person:** ElevenLabs' policy prohibits
replicating a voice without consent (and blocks prominent voices), and a commercial game can't use someone's likeness.
A sports-broadcast trio: a hype play-by-play **caller** (`JR1`), a color commentator **"the Veteran"** (a former
arena champion: deep, dry, the expert), and **"the Corporate Co-host"** (`corporate2`) for the arena PA and sponsor reads (a Syndicate
host whose comedy is sincere corporate euphemism over carnage). Casting, the Voice Design prompt, and example lines:
[streams/archive/round3/announcer.md](streams/archive/round3/announcer.md) *Voices*.

**Pre-generated audio, composed at runtime.** No live text-to-speech in a match (cost, latency, keys, offline play).
Instead a large tagged clip library is recorded ahead of time, and a runtime **banter graph** stitches clips into
lines that are different every match.

**The banter graph: tags, not hand-drawn edges.** Drawing every edge by hand explodes. Each clip carries tags, and a
clip can follow another when their tags fit, so edges come for free:
- **Clip tags:** speaker; dialog act (`hype`, `call`, `setup_question`, `answer_agree`, `answer_disagree`, `roast`,
  `stat`, `callback`, `button`, `interrupt`, `filler`, `sponsor_read`); event context (`first_blood`, `friendly_fire`,
  `scout_vs_tank`, `comeback`, `squad_wiped`, …); intensity (1–3); position and intonation (`opener`, `mid`, `closer`,
  `rising`); optional slots it expects (`{team}`, `{unit}`, `{faction}`, `{count}`).
- **Beat templates (the grammar):** an event picks a beat shape such as caller `interrupt` → caller `call` with
  `{team}` and `{unit}` → color `roast` or `answer` → caller `button`. Each slot draws a random clip whose tags fit.
  The math works for us: 20 openers × 60 calls × 80 reactions × 20 closers is ~2 million distinct lines from 180 clips.
- **Slot fillers** ("Rust", "that dozer", "the Law", "three") are recorded in each intonation (mid-sentence, final,
  rising) so stitched lines don't sound pasted together.
- **Memory makes it coherent:** the director tracks match state (momentum from army health, streaks, who caused
  friendly fire, earlier predictions) so it can pick `callback` clips ("told you that scout was trouble") and
  running jokes, and follow a match arc (introductions, early skirmish, momentum swing, final stand, result).
- **Two-person banter by dialog acts:** a setup tagged `setup_question` accepts any answer tagged for it; agree and
  disagree branches keep it from feeling scripted.
- **Anti-repetition:** per-clip cooldowns, least-recently-used selection, and never the same clip twice in a match
  where possible. Lulls get interruptible filler (faction lore, sponsor reads tied to the screens, crowd).
- **The director (presentation only):** match events → priority queue with cooldowns, interrupts for bigger moments,
  no overlapping speakers, ducking music and effects under speech, subtitles through `Hud.post_message`, cues to the
  crowd and screens. Its randomness never touches the simulation's generators.

**Recording tricks for natural stitching** (verify each API feature when building):
- Generate whole sentences for natural delivery and **slice clips at word boundaries** using ElevenLabs' character
  timestamps, instead of generating fragments in isolation.
- Use the API's previous/next-text context (request stitching) so a clip's intonation fits what comes around it.
- Normalize loudness and trim silence (ffmpeg `loudnorm`, `silenceremove`) so any clip can follow any other.
- **Verify every clip with speech-to-text** and flag ones that don't match their text (mispronunciations, dropped words).

**The pipeline** (reference: the lead's `~/projects/led-drone-microcontrollers/mavlink-hud/speech-to-text-elevenlabs`,
which turns a rules JSON into MP3 masters with the ElevenLabs Python SDK, skips files that exist, prints remaining
credits, then converts to OGG with ffmpeg):
1. **Write the library as text first** (Claude can draft thousands of tagged lines): `assets/announcer/lines.json`.
2. **Transcript simulator (cheap, no credits):** run recorded or headless matches through the director and print the
   banter as text, so the lead can read sample matches and judge coherence and tone **before any audio is paid for**.
3. **Generate masters** (`make announcer-generate`): key from `ELEVENLABS_KEY_ID` in the environment (never a file in
   the repo; orientation trip-up 59 about `~/.bashrc`), idempotent by clip id, credits logged to a ledger like Meshy's.
4. **Post-process:** slice by timestamps, loudness-normalize, trim, speech-to-text check, encode mono Ogg Vorbis at a
   speech bitrate (~32–48 kbps; the reference's quality 4 is ~128 kbps, more than speech needs), write a manifest with
   tags and durations.
5. **Packs:** a core pack ships with the game (a few MB); bigger banter packs load after the game starts on web and
   ship inside the paid Android app. At ~2 s per clip and 32 kbps, 1,000 clips is ~8 MB.

**Humor direction (lead, 2026-09-15, after hearing the first samples in ElevenLabs):** *"the humor was far too overt
and just not funny. What makes satire funny is things blur the line between believable and non-believable; in the
humor with our professional reporter the listener should just get the sense that something's slightly off with what
she said. For the JR announcer, it would be easy enough to formulate a lot of stereotypical reactions to the sporting
event, and of course we can draw inspiration from the UFC announcers and how excited they are getting into it."*
- **The Corporate Co-host:** a real, polished broadcaster. Almost everything she says is ordinary sports-broadcast
  professionalism; the dystopia leaks through one slightly wrong detail, delivered with zero emphasis, and she moves
  on. No jokes, no punchlines, no winks, no pun brand names. If a line reads as a joke, cut it.
- **The caller (JR):** authentic fight-night hype: the stock reactions, disbelief, and escalating excitement of real
  MMA commentary, played straight. The comedy is that he's this excited about armored buses.
- **The Veteran:** dry, expert, understated.

**Rights and tone:** commercial use needs a paid ElevenLabs plan (the free plan is non-commercial with attribution).
Dark and understated; mild language only (strong profanity and crude humor raise the IARC rating). Team names by
color, never player names. Lines in other languages later from the same text library.

## Match rules (current defaults)

- Squad-vs-squad elimination; no respawns.
- **Friendly fire on** **(lead)**.
- The center **control point** as a second win condition, **on by default** (the lead, answering rules' question:
  *"sure, I agree with you"*). Round 1 measured that it restores "coordination beats individuals" under shields.
- **Ammo:** only artillery has finite ammo; direct-fire guns never run out (the lead: *"yes that's ok for now"*).
- **Scouts are spotters first** (the lead: *"scouts should be spotters more than fighters, but there will be cases where
  its machine gun is useful"*).
- Fog of war from per-unit sight; scouting matters.

## Later layers (kept, not now)

- Online play: the relay broker and player-hosted matches exist (archive/round1/netcode.md); lockstep for ranked is
  feasible (integer core spike). Resumes after the core loop is fun.
- **The AI Commander:** an optional LLM opponent that issues the same SquadCommands. Bring-your-own Gemini key
  first, then on-device Gemini Nano on Android (the plan and its rules are in vision.md).
- Replays and spectating (recording works over the relay today).
