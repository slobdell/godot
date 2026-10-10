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

## Standard of work (lead, 2026-09-19) — read before choosing an approach

> *"We should absolutely adopt and use these classical techniques, and I should have been more clear about this. We want
> to build this game to high standards. This isn't me just throwing something together. We want to make the highest
> quality software possible, and that means taking full advantage of the academic knowledge on each of these topics. For
> gaming I assume it's pretty established what the 'Best' algorithms are. We want to use the best algorithms, no matter
> how difficult they might be to implement (but I don't think any of them are difficult per se because it's all well
> established industry knowledge)."*

**This settles a question no stream had been told the answer to: when a good-enough approach and a known-best approach
differ, take the known-best one.** Difficulty is not a reason to decline. Nor is "the simple version passes the test" —
several round-6 fixes were the cheapest thing that satisfied a measurement, and the lead has now said plainly that is not
the bar.

**What it does not license:** inventing a technique where a standard one exists, or reaching for novelty (see *machine
learning*, below). *"Take full advantage of the academic knowledge"* means **find the established answer and implement it
properly**, not build something clever. The failure mode to avoid is a bespoke solution to a solved problem.

**The concrete roster lives in [algorithms.md](algorithms.md)** — every established technique, what we have, what we
**owe**, the canonical reference for each, and the measured symptom it addresses. That file exists because the gaps were
first named only in a message to one stream, which is the failure this project keeps writing lessons about.

**And it does not suspend determinism** ([determinism.md](determinism.md)): replays, networked play and the sim baseline
all require the same inputs to produce identical output, and `sin`/`cos` already differ across builds. **A "best
algorithm" that cannot be made deterministic is not available to us** — which rules out learned policies and any
floating-point method whose evaluation order we do not control. It does not rule out any of the classical techniques
below.

**On machine learning, asked and answered (2026-09-19):** it exists for navigation and it is the wrong tool here. The
determinism requirement is the hard blocker; beyond that, the problems being hit are missing *numbers* and missing
*standard techniques*, not missing models — RL would learn a standoff distance we can simply write down. Where ML earns
its place in games is army-level strategy (AlphaStar-style) and animation, neither of which is the current problem.

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

### The lead's playtest during round 5 (2026-09-17, after the merges)

> *"The game is still unplayable because of the framerate, the units aren't very responsive to my input (they all also
> just rush forward right away at the start of the game), and on the visual side every vehicle currently has an ugly
> dark rectangle below it. I played as the Syndicate and the sound effects were no good they sounded like a cheesy
> cartoon."*

Dispatched the same hour, and these are the round's carry-over into round 6 if they don't land first:

- **Frame rate** — combat's 30 Hz, in flight. Still the blocker; nothing else he lists makes the game playable on its own.
- **Responsiveness** — control, to *measure* click-to-visible-movement at 30 a side and split it into input lag,
  order latency, acknowledgement feedback and vehicle response before anyone fixes anything. A unit that acknowledges
  instantly feels responsive even when it takes a second to move.
- **His own army charges at match start**, before he gives an order — ai with control. The ruling: **the player's units
  hold until ordered**; a player's army that moves without being told isn't an army. This may also explain measurements
  that have puzzled three streams: if both armies sprint into contact by second ten, the fight is decided before any
  tactic applies, which is consistent with median hit range being 39-43 m on every map regardless of terrain.
- **A dark rectangle under every vehicle** — render. The blob shadow; a *rectangle* means the texture, the alpha
  falloff or the ground conform is wrong. Possibly newly visible now that the floor is lit.
- **The Syndicate's weapons sound cartoonish** — audio. Specific to the energy/laser family, not the pipeline: he
  called the same batch "awesome" on the Condemned. "Laser" is the most cliché prompt in sound design and reaches
  straight for the 1950s ray-gun; prompt for the physical event instead (a capacitor bank discharging, an arc flash, a
  transformer failing) and avoid pitch sweeps entirely.

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
| **Frame-rate target** (asked later the same day, once render had modelled it) | **A locked 30 fps at 1080p with the full 30 a side, plus a 720p 60 fps performance option** | 60 fps at 1080p is unreachable this round whatever the tick rate does: the GPU alone is 14.8 ms there, and every available cut together still leaves ~9 ms of a 16.7 ms frame. A locked 30 fps holds 60 vehicles with the tick change alone. The army size the lead has asked for twice is preserved; a stable 30 reads as smooth where an unstable 60 reads as broken. Baseline for comparison: 60 fps used to hold at **13 vehicles** at 720p and **never** at 1080p |
| Destructible cover | **Schedule it** (*overruled*: the recommendation was to park it) | Approved as designed — a stack collapses to a lower stack, never changing drivable space. Not landed in round 5: two cross-stream changes at once (with 30 Hz) would make failures unattributable |

## Round 6 direction: the lead's playtest of round 5 (2026-09-18)

> *"ok here's what I noticed in gameplay, I'd ideally like to delegate to workstream workers. 1. The main thing that
> makes the game unplayable right now is that the vehicles aren't smart enough yet to really navigate around like they
> should. If we have a hoarde of units, and I tell different squads to move in different directions a bunch of cars
> just get stuck or blocked by other cars. I would assume this should be solved by both making the computer units
> smarter but also like a real-world situation with units that presumably knew about each other or saw each other, I'd
> imagine an in-game command could be sent peer to peer between units to move out of the way or whatever the case is.
> Second to that, we have this concept of quasi military units that should operate with standard operating procedures
> and so forth. The game is still far from coherent in terms of unit behavior. A good standard is Starcraft 2, where
> the units definitely seem smart (but we want our stuff to be even smarter). For the controls on a squad level basis
> (the UX), we should definitely iron these out; I don't know what some of these buttons are (i.e. screen), and buttons
> like move and follow are already accessible via mouse click, so we shouldn't have buttons for them. I finally found
> the "support by fire button" (there's a standard military symbol for support by fire, we should ideally use these),
> and when I clicked it, the units definitely did not form up. In general I don't think we have any coherent formations
> working either. At the start of the game there's a big lag between pressing "Fight" and the game loading, so we
> should likely invest in some loading UX indicators and screens. The maps are still pretty basic, right now the game
> is just this big open brawl with dumb units. We want to be able to set up ambushes, do flanking maneuvers. I don't
> know if you're managing it like this, but if I select an entire squad and I tell them to move somewhere, I would
> think that there's a higher level abstraction / higher level movement above individual units where there's a target
> formation for the squad and therefore a target position for each individual unit (i.e. no matter where they might be
> currently, there's a formula to "form up"). The more sophisticated we can make this the better. For example, it might
> be easy enough computationally to estimate the position and time at which an individual unit would converge with its
> formation, but we're dealing with a discrete control system, where there should probably be things like PID loops all
> throughout the system somehow (we might even be able to differentiate units of different factions by PID values
> somehow) and so my point is that intuitively a PID loop would conceptually be useful for a unit trying to get back in
> his formation. I know video games using pathing algorithms like A* and stuff like that. Are we using that? We might
> even want a map that's a quasi maze just for test purposes to ensure units can get through it. On the look and feel
> side, I think the bird's eye view is what's problematic on the camera. I think it should be more of a 3d perspective,
> possible just at an angle in general, and the lower camera angles look good because we actually get to see the
> vehicles. And remember, previous guidance from me is that we're trying to get somewhere in the middle between
> Starcraft 2 and Twisted Metal in terms of perspective (I know this is hard to figure out). On the look and feel side,
> I notice that the background / ambient crowd in the stands is non-existent. The long range of the weapons is also I
> think making the game unplayable (units see each other and then everyone just starts firing)."*

**The round's goal: movement you can trust.** Everything above the wheels — doctrine, drills, formations, the element
layer — has been built on a locomotion layer that cannot get a horde through a gap. Round 6 fixes the bottom of the
stack first, then the layer that commands it, then how the player reads and issues it.

### What this means, by area

- **CLOSED, and the cause was worse than the symptom.** The lead opened round 6 with *"a bunch of cars just get stuck
  or blocked by other cars"*. The survey found `TankBrain.ORDER_STALL_ARRIVE = 12.0`: after 3 s of no progress, a unit
  **within twelve metres of its goal declared its order complete** — which explained why a jammed horde looked like it
  had *decided* to stop. It was described in this round's briefs as *dishonest reporting*. **It was worse than that: it
  created the jam.** nav's measurement on the maze, before deleting it: 29/30 arrived, one "completed" **8.1 m short**,
  and one **never arrived at all, blocked 90 m out**. The unit that falsely completed had **parked in a corridor**, and
  the unit that never arrived was the one stuck behind it. A rule that let a vehicle stop early turned that vehicle into
  an obstacle for everyone behind it. After deletion: **30/30, t100 73.2 s, 0 finishing short.**
  The generalisable form: **a lenient completion rule does not merely mis-report, it leaves a live obstacle in the
  world.** Anything that lets an actor declare success while still occupying contested space converts one soft failure
  into a hard one for whoever comes next.
- **Navigation is the blocker, and it is three separate problems.** (a) *Path planning*: does a unit have a route
  around an obstacle at all (A*/navmesh/flow field)? (b) *Local avoidance*: two units heading through the same gap
  must resolve it — the lead's own instinct is the right one, units that see each other negotiate ("an in-game command
  could be sent peer to peer between units to move out of the way"), which is what RVO/ORCA and SC2's unit pushing
  formalise. (c) *Unsticking*: whatever the first two miss, nothing may remain stuck — detect no-progress and recover.
  **Acceptance is a maze map**, which the lead asked for by name: a quasi-maze test arena a horde must get through.
- **A squad move is a formation move, not N unit moves.** The lead described the architecture he expects and it is the
  right one: an order to a squad computes a *target formation* anchored on the destination, assigns every unit a
  *slot*, and each unit drives to its slot. "No matter where they might be currently, there's a formula to form up."
  Slot assignment should minimise crossing (units keep their relative places), the group paces itself to its slowest
  member, and form-up is continuous, not a one-shot teleport of intent.
- **PID as the house control law.** The lead asked for it explicitly and it is a good fit for a discrete-time control
  system running at a fixed tick: station-keeping in a formation is a classic regulator problem, and the derivative
  term is exactly what stops the oscillation a proportional-only follower shows. Use it where there is a continuous
  error to regulate (slot station-keeping, speed matching, turret lay), not where the problem is discrete choice.
  **Per-faction gains are approved as a differentiator** ("we might even be able to differentiate units of different
  factions by PID values") — the Syndicate crisp and twitchy, the gangs loose and overshooting — but only after the
  default gains are stable, and tuned values must be data, not constants in code.
- **"Even smarter than StarCraft 2" is the bar for unit behaviour.** The comparison the lead reaches for is SC2's
  legibility: units look like they know what they are doing. Coherence beats cleverness — no unit standing still in a
  fight, no unit driving through a firefight to reach a stale waypoint, no element flip-flopping between drills.
- **The squad UX has to earn every button.** Cut what the mouse already does: *"buttons like move and follow are
  already accessible via mouse click, so we shouldn't have buttons for them."* Keep the tasks a mouse cannot express,
  name them so they can be recognised, and **use the real military symbology** — the lead asked for it by name
  (APP-6/MIL-STD-2525 tactical task graphics: support by fire, attack by fire, screen, guard, cover, fix, block). A
  button that claims a doctrinal task must produce the doctrinal behaviour: he pressed support-by-fire and *"the units
  definitely did not form up."*
- **Loading has to be visible.** The gap between FIGHT and the match is dead air. Progress UX, staged loading, and a
  loading screen that carries the game's voice (faction art, doctrine cards, announcer stings).
- **Maps must support ambush and flank, not a brawl.** Round 5 built the arena kit and four layouts; the lead still
  reads the fight as *"one big open brawl"*. Terrain has to create approaches that are not covered from everywhere —
  and the three streams' round-5 finding stands: a single central control point overrides every tactical choice.
- **The camera moves toward Twisted Metal.** *"The bird's eye view is what's problematic"* — the default is too
  top-down and too far. Lower the default pitch, get the vehicles in profile, keep the tactical read. The standing
  guidance is unchanged: **somewhere between StarCraft 2 and Twisted Metal**.
- **The stands are empty.** Ambient crowd — visible in the stands and audible — is missing entirely.
- **RETRACTED 2026-09-18, and left here as a warning rather than deleted.** For a few hours this section claimed
  *"what the range complaint actually was: not volume of fire but distance — adding discipline makes the fire rate go
  UP"*, and drew a design conclusion from it. **That rested on two matches of a single Condemned mirror and does not
  replicate.** At **n = 15** (three counterbalanced pairings, SEEDS=3) the fire rate goes **down**, 16.9 → 15.2 per
  unit per minute. The reframing is unsupported and must not be quoted.
  **Why it got in here is the part worth keeping:** combat sent the number labelled *directional, n = 2, not for the
  lead*, and the orchestrator held it back from him correctly — then wrote the *conclusion* into this document as
  established design understanding, where the caveat did not survive. **A caveat that travels with a number in a
  message does not travel with the idea into a doc.** Lesson 26 says a relayed number becomes a fact; this is the same
  failure committed against oneself, in writing, in the file that briefs every future stream. **Nothing goes into this
  document from a sample that could not support a claim to the lead.**
- **SETTLED (75 matches, 15 per configuration across three counterbalanced faction pairings, builder0, `996a25fd`),
  against a genuine round-5 control** — bands at reach **plus `--no-acquisition --no-crossing`**, so the gates are off
  and not merely the bands:
  **kill distance 54 → 40 m (−26%)**, engaged distance 72 → 60 m (−17%), **off-axis kills 26% → 45%**, rear-armour
  kills 11% → 21%, fire rate 17.8 → 15.2 (−15%). The round-6 acceptance target — *a majority of direct-fire kills come
  from the flank or the rear* — is **met at 69%**, up from 55%.
- **THE DECOMPOSITION, and it is the most important thing round 6 learned about combat:**

  | | kill distance | engaged distance | off-axis kills |
  |---|---|---|---|
  | **sight + acquisition + the crossing penalty** | **−11 m** | −4 m | **+17 pts** |
  | **fire discipline (the effective bands)** | −3 m | **−8 m** | +2 pts |

  **The gates do the heavy lifting; the bands mostly pull the armies closer.** Making a crew *find and hold* a target
  before it may shoot is what moves where the fight is decided and who dies from the flank. The effective bands — the
  part that took by far the most design argument this round, the whole `preferred_max` decision, the 0.65-vs-0.55
  sweep, the standoff negotiation — are the **smaller** contributor to both headline metrics.
  **If anyone tunes this later: acquisition first, bands second.** This was only visible once the control disabled the
  gates rather than just the bands; a control that is not a real "before" hides which half of a change did the work.
- **Why the objective must come off the centre line, stated by two streams arriving from opposite ends** (arena from
  terrain, combat from the engagement decomposition, 2026-09-18). They are **the same claim at two scales:**
  the acquisition gates reward approaches that **break line of sight**, and an objective off the centre line is what
  makes taking such an approach **worth the drive**. arena's measurements say the terrain *already* offers covered
  routes at a **1.0–1.1× detour on every map** — nobody takes them because the only thing worth holding is in the
  middle. arena's sentence, which is the round's sharpest statement of the risk:
  > *"If N7 lands and objectives stay central, the gates will have made flanking pay in a game that still gives no
  > reason to flank."*
  **⚠ TWO CORRECTIONS to how this gets summarised (combat, X7, 2026-09-19, from
  `references/combat/n5-engagement-envelope-2026-09-18.json`, builder0 at `fa4e7077`, n=15 per arm against the TRUE
  round-5 control):**
  1. **Quote the STRICT measure, 25.7% → 45.5%, which is what "off-axis kills" above already is.** A looser hull-face
     measure reads **68.6%**, and it flatters us: **an oblique shot across a wide front registers as a "side" hit without
     anyone having flanked anything.** So the honest claim is *"flank and rear kills rose from a quarter to just short of
     half"*, **not "a majority of kills are now flanking"**. Rear kills alone 11.2% → 20.8%.
  2. **N5 did NOT make the battle more mobile, and the natural summary saying so is FALSE.** Centroid travel moved
     236.8 → 248.1 m, about **5%, inside the noise of a 15-match arm** — **the armies moved this much before the
     engagement envelope existed.** So the flanking gain is **a change in how kills happen within an engagement at the
     same amount of movement**, not more manoeuvre. combat flagged this unprompted because *"it is the kind of thing that
     gets repeated once written."*

  The 45% off-axis kills CP4 measured were achieved **despite** one central control point on every map, so the two
  changes should compound rather than merely coexist.
- **THE GANGS' 23% IS GONE — 53%, joint best, and nobody tuned them** (60 matches, 5 seeds per pairing,
  counterbalanced, builder0 `1333cc73`).
  **⚠ SCOPE, added 2026-09-19: every number in this table is a *foundry* number.** `faction_matrix.py` passed no
  `--arena` and nothing in its output said which map it ran on, so the whole faction history of this project was measured
  on one layout. Fixed at `c2b27516` — the tool now takes `ARENA=`, names the map in its header, and writes a per-arena
  file. **The comparisons remain sound, because every arm ran on the same ground**; what is *not* established is that any
  of these win rates is a property of a faction rather than of a faction on foundry. **Re-read every row below as "on
  foundry".** And foundry is **not a neutral default**: arena measured it at `centre_sees_share` **0.56, the second-most
  open map in the game**, so every number here sits on ground that *favours anything paying off with sightlines*. Lesson 90.
  **⚠ AND THE EXPLANATION BELOW IS UNDER CHALLENGE, added 2026-09-19.** combat found that `Army.squads_for()` iterates the
  `SQUADS` table rather than the units, so **a unit whose role is not a key is silently dropped from every army** — and
  that same table's comment records the gangs' rat rods being given the Condemned scout's *spotters-first* directive,
  *"and the faction won 10-30% of everything."* **That is this table's 23%.** So there is a competing explanation for the
  recovery — *somebody fixed the directive bug* — and it is simpler than the one written below.
  **TIMELINE ANSWERED (combat, `git log -S'"gangs/scout"'`): the fix came FIRST.** `f1b0ee9e` (2026-09-16) **reports the
  23% and adds the `gangs/scout` entry in the same diff** — the run found the bug, and the fix was written in response to
  it. No faction matrix ran again until `1333cc73` (2026-09-18), which measured 53%. **So the 23% is a pre-fix number and
  the 53% is a post-fix one.** But the gap between them also contains the `ready_to_fire` tick, armies holding until
  ordered, 30 Hz, Jolt and all of CP4 — so **the directive bug is an unexcluded candidate, not a demonstrated cause, and
  neither is the mechanics story below.** combat has retracted its own attribution in `balance.md` at `0c1fb760`, in
  place, keeping the measurement and striking the cause. **Read the explanation below as one of two candidates.**
  **⚠ ABLATION RUN, AND IT CANNOT ANSWER THE QUESTION — so both numbers are RETIRED rather than explained** (combat,
  builder0 at `f745f48a`, n=30 per faction per arm, per map, never pooled; positive control fired in all four arms —
  21 sides fielded a designator, 535/559/758/656 paints; `compare_arms` accepted both subtractions):

  | faction | boulevard (0.64) | yard (0.20) | treated? |
  |---|---|---|---|
  | **gangs** | **+7 pts** | **+7 pts** | **yes — the only one** |
  | law | −7 pts | −10 pts | no |
  | condemned | +3 pts | +0 pts | no |
  | syndicate | −3 pts | +3 pts | no |

  **`gangs/scout` is the only faction-keyed entry in `Army.SQUADS`, so every other row measures what an UNTREATED faction
  does between two arms — and law moved −10 points without being touched, larger than the gangs' +7.** The noise floor is
  not an argument; it is in the table, measured by factions that received no treatment. SE of a difference of win rates at
  n=30 is **12.9 points**.
  **The direction is consistent** (the gangs are worse without their directive on both an open and a closed map) **and it
  is an order of magnitude short of explaining 23% → 53%.** So **neither CP4 nor the `gangs/scout` fix is established as
  the cause, and combat claims none of it.**
  **Most likely the original comparison was never a comparison** — different builds and, on this project's own foundry
  finding, plausibly different maps. **That is exactly the subtraction `compare_arms` now refuses and could not refuse
  then.** Resolving ±7 points would need ~n=400 per faction per arm — about SEEDS=70 and four hours of builder0 — for an
  effect smaller than any balance difference the lead would notice. **Decision: do not chase it. The two numbers are
  retired.**
  **And the 23% itself was not a false number** — combat's correction, which is the sharper point: *a build in which 15
  assault vehicles sit at standoff spotting while the swarm dies really does win 23%.* **The error was treating a
  measurement of a configuration as a fact about a faction** — the same error as reading a foundry number as a property
  of the game. This matters beyond the history:
  the 23% → 53% collapse is the evidence for *"a balance problem dissolved by mechanics"*, which is the principle the
  stream twice used to refuse tuning against mid-flight numbers. If the evidence is a bug fix, **the principle needs
  different evidence rather than a quiet retirement**:

  | faction | win% | was (pre-CP4) |
  |---|---|---|
  | condemned | **53%** | 70% |
  | **gangs** | **53%** | **23%** |
  | law | **50%** | 63% |
  | syndicate | **43%** | 47% |

  **The spread across all four factions collapsed from 47 points (23–70) to 10 points (43–53).** Two defects were fixed
  in round 4 and neither moved it; what moved it was the engagement envelope, the brain's range reasoning and suppression
  landing together. **A balance problem dissolved by mechanics** — which is exactly what the stream was holding out for
  when it refused to tune against numbers taken mid-flight, twice, across two rounds.
  **Why it is believable rather than lucky:** the gangs field **43 vehicles to the Syndicate's 25**. A cheap swarm is
  precisely the army that suffers most when anything can be shot at maximum range the instant it is seen, and gains most
  when fire only counts up close. N5's decomposition said the *gates* do the heavy lifting, and **a 43-vehicle army
  closing under an acquisition delay is the shape that benefits.** The mechanism predicts the direction of the result.
  **What does NOT survive, stated firmly because it is the same trap the 23% was:** each pairing is **10 matches**, so a
  95% interval is roughly **±30 points** and **every cell in that table is statistically indistinguishable from 50%.**
  The 47-point spread collapsing is visible at any sample size; a 10-point spread is not. **The Syndicate's 43% is not a
  finding** — it is the lowest cell, inside the noise. **It must not become the next 23%**, which cost two rounds of
  deferred tuning precisely by being carried forward as a fact. If anyone wants to act on the Syndicate, the answer is
  more seeds, not a stat change.
  **The old 23/70/63/47 line is retired wherever it appears** — it describes a game that no longer exists and it is
  quoted in several places.
- **0.55 of reach is confirmed as the overshoot**: lowest fire rate, longest matches, fewest eliminations of any arm.
  A fight the player cannot close. The shipped bands are nowhere near it.
- **Superseded, kept for the method:** an earlier n = 15 pass
, stated at the strength the evidence allows (builder0,
  `c765275f`, three counterbalanced pairings, SEEDS=3, **with acquisition and the crossing penalty on in both arms** —
  the control tunes `effective_range` back up, so it isolates *fire discipline alone*, not all of N5):
  fire discipline at the shipped bands moves the fight **modestly** closer — **engaged distance 68 → 60 m (12%)**,
  **kill distance 43 → 40 m (7%)**, **flank+rear 63% → 69%** — with a **small reduction** in fire rate and **no change**
  in how matches end. **Every metric moves the right way; none moves dramatically.** A true before/after needs the
  control arm to disable acquisition too, which the harness cannot yet pass; until then these numbers are about
  discipline, not about the whole envelope.
  The over-correction is still real and still recognisable: at **0.55 of reach** kill distance falls to 34 m but the
  fire rate drops to 11.4 and matches lengthen — tune toward it and the fight becomes one the player cannot close.
  **The shipped bands are nowhere near it.**
- **Weapon ranges are still too long.** *"Units see each other and then everyone just starts firing."* This was round
  5's combat brief too, and the lead still sees it: the first contact should not be the whole fight.

### The lead's camera pick (2026-09-18)

He chose from control's page (https://claude.ai/artifact/6LEzbnaQc1T6oyVo2jmxaL — one frozen 30-a-side fight shown at
every pose): **pitch 25° · 50 m out · FOV 60°**, no note. Applied as `DEFAULT_PITCH_DEG 25`, `FOV_DEG 60` (was 55),
start 50 m out; the player tilts freely 22°–50°, and `O` is the deliberate 77° top-down.

**REVERSED IN PLAY, 2026-09-18, and this supersedes everything below: the lead played `make skirmish` at 12° and
said the game is UNPLAYABLE.** His words: *"I was totally wrong about the camera, the game is unplayable now with low
field of view."* **The default pitch goes back to ~45°. 12° remains reachable in the player's range; it is not the
default and must not be restored as one.**

**Why the wrong answer was produced, because the mechanism matters more than the number.** He was asked to choose from
a page of **still frames of a frozen fight** — and a still frame cannot show playability. It shows *composition*, and at
12° the composition is genuinely striking: that is why he picked the floor of the range twice, and why control and feel
both reported independently that it looked excellent. What a still cannot show is how much ground you can read while
commanding, how the horizon eats the screen when you need to decide where to send a squad, or what panning feels like.
**He evaluated a photograph and then had to play a game.** The orchestrator designed that question and put no played
sequence in front of him, so the failure is in the question, not in his answer.

**What survives, and it is the actual win:** his original complaint was that *zooming out turned into a bird's-eye
view*. **Decoupling pitch from zoom fixed that**, and it is untouched by this reversal — as are the wall cutaway and
the far-range tilt floor. A 45° default with an independent tilt axis is a strictly better camera than round 5's, which
is what he asked for. The 12° default was an over-correction produced by a bad question.

**The rule for next time: a playability choice is made from a played session, never from a frame.** If a decision is
about how something *feels to operate*, the artefact put in front of him must move — a recording, a short clip, or him
driving it himself. Stills are for looks.

---

**Superseded (kept for the record): he went lower twice on stills — `pitch 12° · 50 m · FOV 60°`.** Asked a second time on a page
offering 12/16/20/25°, he took **the floor of that grid too** (`picks/lead` on
https://claude.ai/artifact/GcEpxjxyaUcjCjrmdrH2q7, no note). Two pages, two floors: this settles the long-open
question of where *"somewhere in the middle between StarCraft 2 and Twisted Metal"* actually sits, and the answer is
**much nearer Twisted Metal than this project has ever assumed**. Treat 12° as the intended look, not an experiment —
and do not let a later agent "correct" it upward toward a conventional RTS pitch because the tactical read is easier
there. If a lower band is ever offered again, expect him to take it.

**THE ONE PLACE THE CAMERA OVERRIDES HIS PICK, and he has been told:** past **70 m** the tilt lifts on a soft floor —
about **30° by 130 m, 40° at 160 m and beyond**. Up to 70 m, *including his 50 m default*, the tilt is exactly his 12°.
The reason, found by playing it: when the vision camera pulls back to frame a whole army (~150 m), 12° turns the arena
into a thin strip between sky and a black void with units as specks. **It is two constants if he would rather have it
otherwise** (`rts_camera.gd`). Nobody may widen this floor into the ≤70 m band without asking him — that band is his
pick and the whole point of it.

What 12° cost, and what was done (all played and tested, `rts_camera.gd`):
- The cutaway had to clear the **3 m wall's top edge** as well; at 12° that edge survived the cut and hid every vehicle
  parked against it.
- The cutaway now cuts **only when the stands would actually hide something** — always when the camera is among the
  seats, otherwise only if the sight line to a vehicle inside the wall runs through their measured profile. Far and
  high, the stands and crowd stay as foreground. Mutation-checked: the first version left the railings standing across
  the whole view.
- **No popping.** The cut starts at the wall top's depth, which is ~zero as the camera crosses the wall, so it is
  continuous.
- **Close up it is excellent**, and commanding is no harder than at 25° — if anything picking out individual vehicles
  is easier. Vehicles read in profile with the stands and crowd behind them, and feel's skyline shows above the far
  stands.
- **Open, and now seen every match: the ground plane ends at the stands.** Any camera outside the venue (far framing,
  and the free camera after a defeat) looks down past the stands into black void — the bottom 15–40% of a far frame.
  A dark plaza, car park or road out toward the new skyline would fill it. feel's to take.

Consequences that follow from 12° and are now design facts rather than open questions:
- **`MIN_PITCH_DEG` moves down with it**, so the player's whole tilt range shifts toward the ground.
- **The wall cutaway stops being occasional and becomes constant.** A 12° camera crosses arena walls most of the time
  on most maps, so the near-plane cutaway is load-bearing, not a nicety. It is cheap (one perimeter ray and a dot
  product per frame, setting `Camera3D.near`), but everything that assumes a camera mostly clearing the walls needs
  re-checking at this pitch.
- **The crowd becomes about a third of the frame.** At 12°/70 m the far stands sit across the middle third of the
  screen, so the venue is no longer background dressing — it is a third of the image, for the whole match.
- **Off-screen edge markers fire less often**, because more of the army is genuinely in view. Correct, not a bug.

His earlier pick, superseded: 25° · 50 m · FOV 60°.

**He picked the lowest angle on the page**, which is worth recording as a *direction* and not just a value: the grid
offered 25/35/45/60° and he took the floor of it. The honest reading is that the range may not have gone low enough,
and that "between StarCraft 2 and Twisted Metal" sits nearer the Twisted Metal end than this project had assumed.
Before treating 25° as settled, offer him a second band below it (roughly 15–25°) and find out whether the floor was
his choice or merely the lowest option available.

Two things this pick changed on its own:

- **The L4 vision cap counted sky as unseen ground.** At 25° about a fifth of the screen is sky, so the cap would have
  fought his own pick and pulled the camera back up. Sky now leaves the count (control).
- **`perf_scene.gd` reads `RtsCamera.FOV_DEG` and `pose_for`**, so the performance harness's camera becomes 25°/60°
  at that merge: **M1 frame numbers move for a camera reason, not an art reason**, and a 25° camera sees all the way
  to the far stands. Re-baseline after the merge; never publish a frame number measured across it.

## Round 7 direction: the lead's playtest of round 6 (2026-09-18, same evening)

> *"ok with make skirmish it's still not playable because of the camera. Here's what I need: we need some 3d
> perspective view so it's not a lame. And then I think the camera is another dimension that can really make or break
> this game. Basically I think the camera's yaw orientation should match the intended facing position of the squad or
> selected unit - this is what I think can differentiate us from a normal RTS game. This makes it so the user can always
> see the action, is somewhat constrained based on the perspective of the vehicle, squad, or selection, and has a good
> understanding of the orientation of the vehicle, which should be an important thing (i.e. trying to emplace units in
> an ambush). I also just did another quick play. The bird's eye view was better but then it also made it so tanks were
> shooting at enemies I couldn't even see. So I think it makes sense here to somehow make the field of view match the
> range of the vehicle or the max range of the selection. For the UX indicators on the bottom, there's some obvious
> improvements to make: 1. instead of tank icons or scout icons, we should be able to actually re-use the meshy
> renderings we have per vehicle. The control buttons (i.e. screen, etc) are too small and difficult to make out. It's
> also really overwhelming to know what each of those buttons does - we should add some popover help type thing on a
> sleek HUD that shows an animation of the movement would do for the squad (i.e. I don't know what it means to tell a
> unit to screen. I don't know what way they'll point or if they'll hold position or what. So it would be really cool to
> have a sleek video game HUD that takes advantage of our theme and does some entertaining but visually purposeful UX to
> communicate what each action does). Also, some of the vehicles pointed backwards at start-up when I played with the
> gang. ALso it seems like squad are not scoped together at the start; the units should start out like an army where
> there actually is a starting formation where each squad is separated. The other thing that's really confusing about
> the buttons is that some of them seem to be actions that require a follow on click, and other seem to be buttons that
> are applied passively (if I click the attack button will they do something or do I need to direct them?). My last run
> of make skirmish was also worse camera behavior than whatever was iterated, it's unplayable because of the field of
> view right now"*

**THE CAMERA IS SETTLED, from a played session with live controls, 2026-09-18:**

```
CAMERA_POSE pitch=21 distance_m=49 fov=35 yaw=-0 zoom=0.365 auto_frame=on
```

**`fov=35` is the floor of the offered range, and it is the answer nobody guessed.** A *low* angle with a
**telephoto** lens. Every still page and both agents reasoned the other way — control measured that FOV 60 shows more
of the fight than 55 and concluded *"on his 'enemies I couldn't see', wider is the right direction"*, and the
orchestrator relayed that. It was backwards. At a low pitch a wide lens produces a sweeping vista of mostly horizon
with tiny vehicles; the same pitch at 35° crops to the action and makes the machines large. **"Low field of view" meant
what it said, and he wanted it lower still.**
Three things this settles that months of argument did not:
- **Pitch 21° is close to the 12° he rejected** — so pitch was never the problem. *The lens was.* His two "wrong"
  picks from stills were right about the angle and could not express the lens, because a still at a fixed FOV cannot
  show you that you want a different one.
- **He left `auto_frame=on`.** The L4 vision framing is wanted; it just needed a distance floor (control set 45 m after
  finding it closed to ~29 m).
- **A telephoto at 49 m is the Twisted-Metal-to-StarCraft answer** the project has been hunting since round 4: the
  compression makes vehicles read as heavy machines rather than units on a map, without a close camera's loss of
  tactical read.
**Nobody may widen `FOV_DEG` toward 55–60 again without him.** It is the constant two agents independently argued the
wrong way about.

**The rest of the camera work below is round 7.** Everything else in this section is round 7.

### The camera design he is asking for, which is a real differentiator and not just a fix

1. **Yaw follows the selection's intended facing.** *"The camera's yaw orientation should match the intended facing
   position of the squad or selected unit — this is what I think can differentiate us from a normal RTS game."* Three
   things he wants from it: the player **always sees the action**; the view is **constrained to the unit's own
   perspective** rather than being a free god view; and the player **understands which way his vehicles are pointing**,
   *"which should be an important thing (i.e. trying to emplace units in an ambush)"*. Note how this compounds with
   round 6: armour facing, the crossing-acquisition penalty and support-by-fire arcs all make *facing* mechanically
   real, and the camera currently hides it.
2. **Field of view tied to the selection's weapon range.** From a real observation: at a high angle *"tanks were
   shooting at enemies I couldn't even see."* So the frame should show what the selection can **fight**, not an
   arbitrary distance — the view and the engagement envelope become the same number. This is the camera version of
   round 4's *no unearned god view*, and it also means round 6's shortened ranges should pull the camera **in**.
3. **A 3D perspective, "not lame."** Both extremes are rejected now: 12° is unplayable, and bird's-eye hides the fight.
   The answer is somewhere between, and **nobody has found it from stills** (lesson 72 — no agent here can play).

### The HUD he is asking for

4. **Vehicle renderings, not role icons.** *"Instead of tank icons or scout icons, we should be able to actually re-use
   the meshy renderings we have per vehicle."* The art exists (`game/theme/factions/`).
5. **The control buttons are too small and difficult to make out.**
6. **Popover help that ANIMATES what an action does.** *"I don't know what it means to tell a unit to screen. I don't
   know what way they'll point or if they'll hold position or what."* He wants *"a sleek video game HUD that takes
   advantage of our theme and does some entertaining but visually purposeful UX to communicate what each action does"* —
   an animated preview of the resulting posture, not a tooltip. **This is the answer to round 6's N4 the round did not
   find:** the military symbol made the button nameable; it did not make the behaviour knowable.
7. **Which buttons need a follow-on click, and which apply immediately, is not legible.** *"If I click the attack button
   will they do something or do I need to direct them?"* Two different grammars share one row of buttons with no visual
   distinction.

### Two more defects from the same session (2026-09-18)

10. **No machine-gun fire from the scouts.** *"I'm not seeing any cool machine gun fire from the scouts."* The weapon
    exists (`machine_gun`, 45 m, 3.5 damage hitscan at 10/s) and round 5's audio work covered it; what is missing is the
    **visible** fire. A hitscan weapon with no tracer is invisible, and the scouts are the units whose whole job is to
    be seen working.
11. **Unit sizes are not to scale, and the discrepancy is backwards.** *"There's a huge size discrepancy for the units.
    Our semi truck for the gang that was supposed to be a huge tank is tiny compared to the other vehicles. Our unit
    sizes should be reflected here. Scouts are small, the IFVs are bigger, the tanks bigger than that (everything drawn
    to scale basically)."* The catalog already carries `hull_size` per unit (C1), so **the data exists and the visuals
    are not honouring it** — a gang *tank* rendering smaller than a scout inverts the read the whole
    rock-paper-scissors design depends on. This is the same class as every other round-6 finding: the information is
    there and does not reach the screen.

### Map building blocks: the lead's two additions (2026-09-18)

12. **A kit of sci-fi buildings drawn from primitives, not from Meshy — and the reason is a cityscape map.** He
    clarified the purpose (2026-09-19): *"on the shaped primitives, the reason I was thinking about this is because a
    cityscape type map would be good, but I would just need to get it to match the theme and consistency of our gladiator
    environment."* **So the deliverable is not a generic block kit, it is a city that reads as part of this venue.** That
    is a harder and better brief: the constraint is *theme consistency with the gladiator arena*, which already has a
    settled look — blast-barrier walls with neon light bars, grandstands, floodlight towers, ad screens, gang-tagged
    container barricades, a lit city skyline on the horizon (feel's X4). A cityscape map should read as **the city that
    skyline belongs to**, seen from inside it, rather than as a different game's level.
    Note the pleasing consequence: feel built a distant skyline this round for the camera to find at low angles. **A
    cityscape arena is that skyline made playable** — same palette, same neon vocabulary, the buildings the horizon was
    promising. *"To build more complex maps we'll need more
    building blocks to work with. I realize that all these meshy artifacts take up a lot of space. Therefore, would we
    be able to formulate some of cool-looking sci-fi 'buildings' or blocks or something like that that's completely
    rendered using primitive types in our system - you should have better ideas than me but I'd envision that has the
    cyberpunk neon borders. This way, these can become building blocks for creating more complex maps (where we can
    allow teams to set up kill zones or whatever other strategy)."*
    **Why this is better than it sounds, and cheap:** procedural blocks cost no disk, no Meshy credits and no concept
    review cycle; they are **parameterisable**, so a map author asks for *"a 40 m block with two entrances"* rather than
    placing meshes by hand; and they suit the renderer, which does not batch 3D draws (trip-up 45) but does batch static
    art per material via `StaticBatcher`. They also sidestep round 6's terrain limits: **the navmesh caps slopes near
    26.6° and every ramp needs a flat shelf at the top** (arena's X4), and blocks with explicit footprints are far
    easier to keep navigable than sculpted geometry. The existing arena kit (containers, ad screens, barricades, signs)
    is the precedent; this extends it with buildings.
13. **Water or pits: impassable but shootable over.** *"We need water or pits - these would be elements that units could
    not cross but they could still fire over. Useful for setting up kill zones. i.e. we could have a map that required
    crossing some bridges to get to the other side."*
    **This is the single cheapest tactical primitive available to us, because of how the two systems are already
    separated:** navigation is baked from collision shapes in the `navigation_source` group, while line of sight is a
    physics ray at 1.3 m eye height (`game/ai/perception.gd`). **So a hole in the navmesh that carries no tall collider
    is impassable and transparent to fire, for free** — no new mechanic, only geometry. It needs: a `water`/`pit`
    footprint type that carves the mesh, a **bridge** that restores a walkable strip across it, and fairness care —
    holes and bridges must be point-symmetric like everything else, because the mesh is baked as one half plus its 180°
    mirror (trip-up 21).
    **And it is the terrain answer to the round-6 finding three streams reached independently:** covered flanking routes
    already cost only a 1.0–1.1× detour and nobody takes them, because the only thing worth holding is in the middle.
    A map where crossing is funnelled onto bridges makes *position* matter without needing the objective to move —
    it is arena's X3 argument achieved with geometry instead of rules, and the two should compound.

### The lead's arena verdict (2026-09-19, read back from the review page's store)

| Arena | His call | Centre sees |
|---|---|---|
| **Boulevard** | **CUT** | 0.64 |
| **Foundry** (and the Furnace) | **CUT** | 0.56 |
| **Boneyard** | **CUT** | 0.40 |
| **Scrapyard** | **CUT** | 0.29 |
| **Pit** | **KEEP** | 0.30 |
| **Yard** | **KEEP** | 0.20 |

No notes. **He kept two and cut the rest** — five of seven shipping arenas, counting the Furnace on Foundry's card.

**The finding that matters more than the verdict: centre-visibility predicted it.** Rank the six by the share of the
field their centre can see and **the four most open maps are exactly the four he cut.** He had those numbers on the page
but no way to sort by them, so this is not him reading the metric back to us. Scrapyard (0.29) and Pit (0.30) are nearly
tied and he split them, so it is not a pure function of the measure — but **nothing else we have predicts his taste this
well.** That turns `centre_sees_share` from a description into a **design target**: a map whose middle can see most of
the field is a map he will not want, and we can now know that before he plays it.

**CONFIRMED by him in words as well as buttons (2026-09-19):** *"the only two maps worth keeping were the last one and
the one with the octagon of shipping containers. All the maps need to be higher quality regardless."*
- **One ambiguity, deliberately not resolved by guessing:** neither Pit nor Yard is a clean ring in the data (container
  radii spread wide on both), so *"the octagon of shipping containers"* does not map onto one of them unmistakably. **His
  button answers are the record** — Pit and Yard — and nothing is being deleted, so a mismatch is cheap to correct. Ask
  once when convenient rather than inferring.
- **"All the maps need to be higher quality regardless"** — so the two survivors are not finished either. Keeping a map
  means investing in it, not shipping it as-is.

**NOT ACTED ON — awaiting one line from him, and the reason is size, not doubt** (arena raised both, correctly):
1. **The page did not prepare him for a cut this large.** It said cut was a real answer we would act on and led with
   boulevard; it did not say *"you are about to remove five of the seven maps in the game"*. He may mean exactly that, or
   he may mean *"these four are not worth fixing — prioritise accordingly"*. One line settles it.
2. **Foundry is `Arena.DEFAULT_LAYOUT`.** Every headless run, the sim baseline and most tests use it. **Cutting it is an
   infrastructure change, not a content change**, and it would move the baseline. That must be deliberate rather than a
   consequence.
**Meanwhile, treat the four as "do not invest" rather than deleted:** no new work on them, and any round-7 map effort
goes to Pit, Yard and new maps built to the risk-and-reason principle below.

#### MEASURED: every shipping arena scores `spread 0.00` — there is nothing to cross the bridge *for* (arena, 2026-09-19)

**arena built the cost-and-reward metric and the first result is a flat zero on every map in the game.** The reason is
not subtle: **every shipping arena has exactly one objective**, so **every route is the same route** — there is no
expensive path and no cheap path, because there is only one thing to go to and it sits in the middle.

**This is the lead's own principle, measured, and it says the principle is currently unimplementable:**

> *"Clearly crossing a bridge is risky, so you don't want a simple map with 2 sides connecting two bridges. **There
> generally has to be some compelling reason to cross the bridge to take some advantageous ground.**"*

**A bridge cannot be compelling on a map with one central objective**, no matter how the terrain is arranged. Risk
without reward is just cost, and units correctly decline it — which means **the flanking, ambushing and manoeuvre he
wants cannot be produced by geometry alone.** It needs something worth taking that is *not* in the middle.

**What this reframes:**
- **N7 (objectives are the arena's, not a constant) stops being infrastructure and becomes the gate on the whole map
  programme.** Until an arena can place its own objectives off-centre, `spread` cannot move off zero and no amount of
  chamfering, hexagons, water or bridges will produce a reason to manoeuvre.
- **It explains "one big open brawl" better than openness does.** We had been reading his complaint as *the maps are too
  open* and answering it with `centre_sees_share`. Both are true, but **a single central objective is a stronger cause**:
  it actively instructs both armies to converge on one point.
- **It gives the bridge work an acceptance test rather than a look.** A bridge is doing its job when `spread` is
  non-zero *and* combat's falsification test shows unit-time actually spent on the expensive route. Either alone is
  decoration.

**FIRST MAPS ABOVE ZERO (arena, 2026-09-19).** A mirrored objective pair authored on both maps the lead kept:

| arena | decision spread | `centre_sees_share` |
|---|---|---|
| **yard** | **0.00 → 0.35** | 0.20 (unchanged) |
| **pit** | **0.00 → 0.26** | 0.30 (unchanged) |

**Each pair gives a side one objective it holds cheaply and one it must contest** — which is the lead's *"compelling
reason to cross the bridge"* expressed as geometry plus reward rather than geometry alone.

**And `centre_sees_share` did not move on either map, which is what should happen:** objectives change what is *worth
reaching*, not what can be *seen*. **Two axes behaving independently is the first evidence that splitting them was the
right model** — openness and reason are separate design knobs, and a map can now be tuned on one without disturbing the
other.

**SHIPPED AND VERIFIED (arena, 2026-09-19). Both maps the lead kept are now HEXAGONS at the 140 m bound, and both pose
a question:**

| | shape | `centre_sees_share` | decision spread |
|---|---|---|---|
| **yard** | hexagon @ 140 | 0.20 | **0.43** |
| **pit** | hexagon @ 140 | 0.30 | **0.42** |

**A real 120 s match on each: zero `Objectives` errors (was 35,336), zero `ERROR` lines of any kind, winner declared.**

**⚠ AND DECISION SPREAD IS NOT A QUANTITY TO MAXIMISE.** pit needed re-tuning rather than re-enabling: coordinates chosen
for the 240 m square gave **0.13** in the hexagon, because the arena grew and the distances that made one objective
contested stopped being asymmetric. A placement sweep:

```
z = -30 -> 0.13      z = -50 -> 0.42      z = -60 -> 0.63      z = -70 -> 0.96
```

**0.96 is not a better map.** It means one objective is nearly free and the other nearly impossible — **a formality
rather than a choice** — and at z = −70 it sits in the base's approach funnel, **which is the boulevard failure this
project already wrote a placement rule against.** Both shipping pairs sit near **0.4**, and the reasoning is in
`objective_pair`'s docstring so the next author does not read the number as a score to beat.

**⚠ HELD BACK, NOT SHIPPED.** A real match on the paired yard fired squad's `Objectives` guard **35,336 times**: *"the
arena declares an objective other than the single central zone; squad's deciders still read `Match.CONTROL_CENTER`."*
**The match completed and produced a winner while the deciders competed for the wrong ground throughout** — degraded,
not fatal, which is the worse of the two. **The pairs land when squad migrates `game/tactics/objectives.gd` onto N7's
instance API**; the coordinates and measured effect sit in `make_arenas.py` as a one-line re-enable.

**The metric needed no build slot and no other stream**, which is worth noting for its own sake: the most important
design finding of the day came from writing down a number nobody had asked for.

### The principle behind all of it: terrain makes risk, objectives make reason (lead, 2026-09-18)

> *"On the bridge note, what I'm thinking though is that clearly crossing a bridge is risky, so you don't want a simple
> map with 2 sides connecting two bridges. There generally has to be some compelling reason to cross the bridge to take
> some advantageous ground."*

**This is the design rule the round-6 findings were circling, and it settles what arena's X3 is actually for.** Note
that the two failures it describes are the *same* failure inverted:

- **A central objective** makes every fight collapse into the middle, so terrain has nothing to decide. Measured three
  ways this round: flanking routes used 4–5% of unit-time on dense layouts, median hit range 39–43 m on *every* map
  regardless of shape, and doctrine winning at squad scale but losing at 30 a side *with a control point*.
- **A bridge with nothing beyond it** makes every fight collapse onto your own side. Both armies hold safe ground,
  crossing is pure downside, and the map is a wall with a decoration on it.

Both are the same defect: **the map offers no reason to be somewhere risky.** So:

> **Terrain creates risk. Objectives create reason. Neither works alone, and they must be placed in relation to each
> other — the prize goes where the risk is.**

What follows for map authoring, and these are testable claims rather than taste:
0. **THE METRIC: cost and reward as two axes, not one score** (arena, 2026-09-19, `b2f54bd1`). Cost is what the
   existing analysis measures — exposure, detour. **Reward is newly computable now that objectives are data:** *what does
   arriving here let me hold or deny?*

   | | low reward | high reward |
   |---|---|---|
   | **low cost** | **scenery** — *and every arena we ship is full of these, which the old metric has been calling flanks* | **dominant** — free and decisive; a design bug |
   | **high cost** | **trap** | **the one we want** — the lead's own words about the bridge |

   **A map's quality is how much of its route space sits bottom-right.** That replaces the bare exposure figure in
   `arena-report`.
   **And the share-of-objectives scoring sharpens it:** reward is not a property of a position, it is a property of a
   position *given what the other side is doing*. Holding both of a mirrored pair at full rate and one at half is what
   makes *"advantageous ground"* a quantity rather than a mood.
   **The model comes with its own falsification test, chosen before five maps were built on it:** measure **unit-time on
   routes classified high-cost/high-reward.** If units do not take the route the map says is interesting, **the model is
   wrong** — and that is the thing to learn before the maps exist, not after.
   **Placement rules, recorded so a hexagon cannot quietly acquire the boulevard failure:** no objective inside a base's
   approach funnel, and the test is **at least two approach corridors that do not share their final leg and differ
   materially in exposure** — one corridor is a funnel, and identical exposure is a false choice.
1. **The measurement we had scored only half of this, and arena flagged it.** Its X2 exposure analysis scores a route
   by **what it costs** (exposure, detour) and never by **what it reaches**. So it reports that every map already offers
   cheap covered flanks — 1.0–1.1× detour everywhere — when the lead's framing says the cheapness is the *symptom*:
   **a route that is cheap and leads nowhere worth going is not a tactical option, it is scenery.** Any round-7 metric
   for this needs a term for *what is at the end of the route*, or it will keep reporting that the maps are already fine.
2. **An objective must sit on ground you have to cross something to reach**, or the crossing is decoration. arena's
   measurement — covered flanking routes already cost only a **1.0–1.1× detour** on every map and nobody takes them —
   is exactly this: the routes are cheap and lead nowhere worth going.
2. **Contested ground must be *better* than your own safe ground**, or a rational player never leaves. Symmetric safe
   ground plus a symmetric objective in the middle is the current map and it produces the brawl he has complained about
   twice.
3. **A kill zone is only a decision if the defender gives something up to hold it.** If overwatching the bridge is free,
   it is not a choice. arena has the instrument for this already: posting an element buys **+0.077 on open foundry
   against +0.017 in the dense yard** — so what an overwatch position is *worth* is already measurable per map, and a
   good bridge map should show a large gap.
4. **Therefore arena's X3 and the bridge work are one job, not two.** Moving the objective off the centre line and
   funnelling crossings onto bridges are the reason-half and the risk-half of the same change, and measuring either
   alone will under-read it — exactly as combat's series under-read N5 until its control disabled the gates as well as
   the bands (lesson 62).

## Round 8 direction: the lead's playtest of round 7 (2026-09-19, late)

> *"ok I just did a quick game and I can see there are improvements but it still sucks. First, the gang tanks are still
> tiny (the intent for the semi trucks is that they're huge - we'll worry about evening up factions later). And on the
> navigation from, they still generally don't do what I command them. On the navigation from, units are still just
> getting stuck behind basic barriers where they seem to just move back and forth indefinitely trying to get unstuck. I
> also don't know how easy this is to do or if we should shelve it for later but the gang semi trucks don't actually
> behave like a semi truck with a truck and a trailer - both components just move together. I can also see that the semi
> trucks are yawing in place (should be impossible, they're not a tracker vehicle). ANother obvious problem right now in
> make skirmish is that not all units belong to a squad. There seem to be orphaned units that don't get selected at all
> when I cycle through the numbers on my keyboard (1, 2, 3, 4...). I'm also testin just telling a group of units to
> attack a single unit, but they don't obey and instead they shoot at whatever they were already shooting at. Also, of
> the algorithms we identified earlier, which ones are actually implemented now?"*

**"It still sucks" is the headline and everything below is subordinate to it.** Round 7 merged seventeen branches and he
still cannot command his units. **Improvements he can see did not change the verdict.**

### MEASURED ON MAIN: the back-and-forth is real, it is churn, and it is gear-shuffling (nav, 2026-09-19)

**His complaint:** *"units are still just getting stuck behind basic barriers where they seem to just move back and forth
indefinitely trying to get unstuck."*

**Pre-registered before the run** (oscillating = **≥ 8 m of travel in 4 s with net displacement under a quarter of it**,
relative to the ORDER's goal, not the brain's target; **≥ 5% on any map means real churn**). Tree `aa984edd` with `main`
merged and no nav changes on top; builder0; `STALL_VERB=attack_move`; seed 3; 120 s; Condemned vs Condemned. **Arm read
live from the code on every run: `commit=true, fixed_style=standoff, off=[]`.**

| map | oscillating | no_progress | attack-move progressing |
|---|---|---|---|
| yard | **7.2%** | 0.426 | 0.44 |
| boneyard | **6.6%** | 0.477 | 0.43 |
| pit | **5.8%** | 0.425 | 0.468 |
| boulevard | **5.3%** | 0.470 | 0.419 |

**All four ≥ 5%, so by the rule fixed in advance the answer is YES.** The sentence for him, nav's:
> *"About 6% of the time an attack-moving unit is driving back and forth: ≥ 8 m of travel in 4 s for less than a quarter
> of it in net progress. On every map, on the game you play."*

**⚠ AND IT IS NOT TERRAIN.** `blocked_terrain` is **0.000–0.010** on every one of these maps. **The fix was never
pathing** — the orchestrator assigned flow fields to this complaint and would have spent a round on the wrong layer.

**THE MECHANISM, and it makes the semi complaint and this one ONE BUG:** of 11 scout in-place-yaw events, **all were in
phase `driving`, none creeping, and 7 of 11 had forward AND reverse above 0.5 m/s in the same 2-second window.**
**The units are gear-shuffling** — `CombatMotion`'s context steering picking a forward direction, then a reverse one.

**So *"the semi trucks are yawing in place"* and *"moving back and forth indefinitely"* are the same churn seen from two
angles: heading and position.** A vehicle alternating forward and reverse rotates without translating *and* travels
without progressing. **One fix should move both**, and the `--nav-off=commit` A/B is pre-registered to test exactly that.

### MEASURED: cover is a STEP FUNCTION at 12.19 m, so 12 m vs 14 m is binary (arena, 2026-09-19)

**Share of the contested field within 45 m of a prop long enough to hide a hull of each length.** Best case by
construction — a box's screening length is its longest horizontal side, so this assumes the hull is parked along it and
the shooter is square to it. **A hull that fails here cannot be hidden at all.**

| hull length | 6 m | 7 m | **12.19 m** | **12.5 m** | 14 m |
|---|---|---|---|---|---|
| **yard** | 0.99 | 0.99 | **0.99** | **0.00** | **0.00** |
| **pit** | 0.85 | 0.48 | 0.46 | **0.00** | **0.00** |
| **terminus** | 0.98 | 0.95 | **0.91** | **0.91** | **0.91** |
| boneyard | 1.00 | 0.92 | 0.85 | 0.33 | 0.33 |

**The cliff is at 12.19 m — the shipping container's own length — and it is a step, not a gradient.** yard covers
**0.99 up to 12.19 m and 0.00 at 12.5 m.**

**So the lead's open question is not "how huge do I want it, and what does cover cost": it is binary.**
- **At 12 m the rig hides on 99% of yard, using props already on the map, with no map change at all.**
- **At 14 m it hides nowhere on either map he kept.**
- **The Terminus holds 0.91 at ANY hull length**, because its city blocks are 40 m. **It is the only map he plays that
  covers a 14 m rig.**

**⚠ AND THIS ARRIVED WITH THE ARENA KIT.** `foundry` and `scrapyard` cover a 14 m hull fine — the **legacy v1 `wall`
obstacle is 18 m**. The v2 kit that replaced it **tops out at 12.19 m**. **The two maps he kept are exactly the two v2
maps with zero long props**, so the regression is invisible precisely where it matters most.

**It is a FORECAST, not a current defect:** on arena's tree `gang_tank` is still 5.6 m, and the check **reads
`game/units/units.gd` rather than copying it**, so it flips itself the moment 14 m lands with nobody needing to remember.

**No long prop has been added to yard or pit, deliberately** — they are maps he kept and ruled on, and **if he rules 12 m
the problem disappears with no map change at all.** If he rules 14 m, a jackknifed trailer or a container *wall* reads as
the same venue and wants feel's eye.

**And this does NOT explain `gangs vs law` 9/20 → 0/20.** combat's arms show `unit_seconds_near_cover` flat and
`deaths_near_cover` **falling**, which is the opposite of what *dying while exposed at cover* predicts.

### Two decisions from the lead (2026-09-19, answering queued gates)

> *"a 4s slower march for a tidier traversal is better, yes. For the attack mechanics - **making the units appear smart
> is better, so flanking and maneuvering is fine**."*

**1. ELEMENT FLOW STAYS ON.** While a leader is more than 15 m from its slot, members follow it at their slot offsets.
Measured: transit gap **9.0 m against 11.4**, worst unit off-slot at arrival **2.9 m against 6.5**, arrival **17.4 s
against 13.1**. **He has bought the 4 seconds.** `ElementPlan.FLOW_ENABLED` stays true and the trade is settled, not
provisional.

**2. "APPEAR SMART" BEATS "APPEAR OBEDIENT" — *within* an order, never instead of one.** This resolves a tension that
had been implicit all round, and it must be read precisely:

- **A flanker swinging wide with the player's target in its order is OBEYING**, and the pin counts it as complying:
  `ATTACK · 2/4 on target · 1 moving round · 1 NOT COMPLYING`. **Do not exclude it and do not flag it.**
- **A crew shooting something the player did not name is the DEFECT** — that was squad's drill bug (task path
  **765/155 → 164/759** unit-ticks on the wrong/right target), and it stays a defect.
- **So "attack" does NOT mean *everyone stands and fires now*.** The `drills: false` task flag is not wanted.

**⚠ And the boundary that keeps this from licensing disobedience: manoeuvring is smart, CHURN IS NOT.** nav measured
**5.3–6.6% of attack-moving units' travel time oscillating** on all four of his maps — **which is the same complaint he
opened with**. A unit that flanks looks intelligent; a unit that re-aims every 1.3 s looks broken. **The test is whether
the motion resolves into fire**: combat's floor — *a crew that cannot acquire a new contact in under `acquire_seconds`
has no business re-aiming faster than it can shoot* — is the principled expression of that, and it makes the cadence a
consequence of the engagement envelope rather than a new tuning knob.

### The eight items, with what is already known about each

1. **THE SEMI IS STILL TINY, AND SIZE IS NOT A BALANCE QUESTION.** *"the intent for the semi trucks is that they're huge
   — we'll worry about evening up factions later."* combat measured 4.4 m against the scout's 1.4 m — **3.14×, inside the
   3–4× band he named in round 6** — and he says it is still wrong. **So the measurement satisfied the number he gave and
   not the intent behind it.** He has now explicitly removed balance as a constraint on this. **Do not defend 3.14× with
   the round-6 quote; make it huge.**
2. **"They still generally don't do what I command them."** The round's central claim, unmoved by facing (2/30 → 27/30),
   the standoff, the order pins and commitment.
3. **UNITS STUCK BEHIND BASIC BARRIERS, "moving back and forth indefinitely trying to get unstuck."** nav measured
   blocked-by-terrain to **zero** in `nav-fight`; he sees it in `make skirmish`. **The instrument and the game disagree,
   and the game is right** — this is lesson 23's shape: a number taken in a configuration the player does not get.
4. **The semi is not articulated** — tractor and trailer move as one body. He explicitly offers to shelve it: *"I don't
   know how easy this is to do or if we should shelve it for later."*
5. **⚠ THE SEMI YAWS IN PLACE, "should be impossible, they're not a tracker vehicle."** **The symptom is real; the
   orchestrator's first mechanism was wrong and nav corrected it from the code.** `step_in_place` does **not** pivot
   wheeled hulls like tracks — the wheels branch sets `yaw = |speed| × turn / turning_radius`, **so a car at 0 m/s cannot
   yaw at all**, and speed is re-read after `move_and_slide` from what the hull actually did.
   **nav's hypothesis: the wheels' multi-point-turn CREEP.** When a car is told to *face* something — which brains do
   constantly while holding or fighting — the plant drives **alternating forward/reverse legs of 0.5 s at low throttle**.
   **Each leg is kinematically legal; ±1 m shuffles at full lock add up to a truck rotating on the spot.** Same symptom,
   different mechanism, and a different fix: **legs long enough to be real (distance-based, a share of the turning
   radius), plus probably brains not asking cars to face in place at all** — which is squad's half.
   **Pre-registered test, written before the run:** a wheeled hull that turns **≥ 30° while its centre stays within
   1.5 m of its start** is *yawing in place*. Running on `gang_tank` (12 m turning circle).
   **For tracks and hover the angular-acceleration limit in the plant still stands**, and it is a separate fix.
6. **ORPHANED UNITS: not every unit belongs to a squad**, so cycling 1–4 never selects them. **A player cannot command
   what he cannot select**, which makes this a direct cause of item 2.
7. **A GROUP ORDERED TO ATTACK ONE UNIT KEEPS SHOOTING WHAT IT WAS ALREADY SHOOTING.** An explicit target order is the
   most direct command in the game and it is being ignored. **Round 6's `test_a_move_order_beats_every_brain_state` has a
   sibling that does not exist for attack.**
8. **"Of the algorithms we identified earlier, which ones are actually implemented now?"** — answered from
   [algorithms.md](algorithms.md), which is the file that exists to answer exactly this.

### THE ROUND'S HEADLINE: the units are still not smart enough (lead, 2026-09-19)

> *"Another thing that's making the game unplayable on closer inspection is that the vehicles are still just too dumb. A
> lot of them just keep getting stuck in places, and that's I think why I'm feeling like the units aren't obeying me. Dumb
> vehicles that can't get into formation will also never provide the feel I was hoping for to create formations. And in
> fact, the fact that this is challenging to implement is a good sign, because when it does eventually work it will look
> and feel sophisticated. I want you to research and implement whatever pathing algorithms or decision weighing
> algorithms necessary to make these units look and feel smart."*

**This contradicts round 6's headline number, and the contradiction is the finding.** nav measured **60/60 arrival on
every configuration** and **30/30 order completion with five squads ordered across one another**. Both are real. **Both
were measured with no enemy.** `tests/nav/order_probe.gd` says so in its own header: *"Nobody fights (no enemy): this
measures driving and order completion only."* And `mk/nav.mk` notes the maze probe has no randomness *"in a hold-fire
drive"*.

**So the round proved that a horde can drive. It never measured whether a horde can drive while fighting** — which is the
only configuration the lead ever plays. This is lesson 23 for the fifth time in this project: *a number taken in a
configuration the player does not get measures a game nobody plays.*

**The suspect is therefore not pathfinding, and the lead's own phrasing points at it:** *"pathing algorithms **or decision
weighing algorithms**"*. In a real fight the decision layer re-tasks the movement layer constantly — brains re-decide
(ENGAGE, SUPPRESS, cover-seeking, `CombatMotion`'s 16-direction context steering), drills re-issue element orders,
targets change, units halt to shoot and back away under fire. **A unit re-tasked before it can complete any movement
looks stuck and is stuck, with no pathing bug anywhere.** Round 6 has direct evidence that this class of failure is real
and common: round 4's drills stole the element from each other *every tick* so neither completed once; the
support-by-fire line alternated with `near_ambush` **every tick**, 128 orders in 10 s; and squad's own X4 found 47 idle
re-issues per window before fixing it. **Every one of those was thrash between a decider and an executor, and every one
was invisible until something measured it.**

**MEASURED (`make nav-fight`, builder0, yard, 120 s, seeds 3 and 7, 34 and 52 player units) — and it splits in two, which
the orchestrator's hypothesis did not predict:**

**(A) Under a plain MOVE — a right-click — re-tasking is ZERO and progress is 74–92%.** So the decision-layer thrash I
predicted **does not happen on the order he presses most.** The remaining ~23% stalled at 52 units is **the movement layer
itself**: blocked by a friend 6.7%, blocked by terrain 5.9%, yielding 4.2%, slow 4.7%, unreachable 1.6%. **That is his
"stuck in places", it scales with crowding, and it is nav's to fix** — not a thrash problem, a mutual-blocking problem.

**(B) Under ATTACK_MOVE, progress is about 45%**, and 29–47% of unit-time is spent driving somewhere *other than* the
order — ENGAGE (290–430 unit-s), CLEAR_LANE, COVER_FIRE, FLANK — plus 2–10% halted with nothing engaged. The drive target
jumps more than 8 m **46 times per unit-minute**; 54% of that is ENGAGE re-aiming within the same option, 11% FLANK
re-aiming, and about a third are genuine option switches.

**But (B) is partly correct behaviour, and this is the important caveat:** `attack_move` *means* "fight your way there".
A unit that breaks off to engage is obeying. And nav flagged that the jump count is contaminated — **`CombatMotion`'s
steer point is 12 m out, so any 45° jink moves it more than 8 m, and that jinking is what the lead asked for in round
3.** A direction-reversal measure (A→B→A) is being added to separate thrash from evasion.

**So the design question underneath his complaint may be a UX one:** the order he presses may not be the order he means.
If *"move"* and *"attack-move"* differ by 30 points of progress-toward-the-goal, and nothing on screen says which one
will fight on the way, then **"they aren't obeying me" is a reasonable reading of a unit correctly executing
attack-move** — which is exactly his separate complaint that *"some of them seem to be actions that require a follow on
click, and other seem to be buttons that are applied passively."*

**What the round must therefore build first is an instrument, not an algorithm:** the arrival, stall and re-task
measurements **in a real fight**, per unit, with the *reason* a unit is not making progress attributed — re-tasked,
blocked, yielding, halted to shoot, no path. Until that exists, any algorithm is a guess, and this project has spent a
round learning what guesses cost.

**And his framing is worth keeping, because it licenses the expensive version:** *"the fact that this is challenging to
implement is a good sign, because when it does eventually work it will look and feel sophisticated."* He is explicitly
authorising research and real algorithms rather than patches. Formations that *look* sophisticated are the goal; a unit
that cannot hold a slot while fighting cannot ever deliver that.

#### RESOLVED: the scouts that ram their targets (2026-09-19)

> *"Scouts are just running directly into their targets and then they have to turn around to get a fix again."*

**It was neither a pathing bug nor a range bug. It was a movement *style* we designed in round 3 and it did exactly what
the lead describes.** `CombatMotion`'s `run` style, for a fixed gun: drive straight at the target, veer past its flank
only in the last 19 m, break off at **9 m absolute — whatever the weapon's band** — then drive **away to 22 m with the gun
pointing backwards** and turn round. His sentence is a description of the algorithm.

**The fix is the standard gun-truck pattern, shoot-and-scoot, as a new `CombatMotion` style `standoff`:** arrive at a
firing position inside the effective band, **stop** (Gunnery already lays a stopped fixed mount's hull onto its target),
fire, slide *along* the band when rounds come in, and never enter the 6 m ram gap.

**Measured on builder0 — one scout ordered onto a durable tank, 25 s:**

| | round-3 `run` | `standoff` |
|---|---|---|
| closest approach | 3.0 m | **27.7 m** |
| nose on target | 17% | **79%** |
| shots fired | 29 | **211** |
| time inside the effective band | — | **91%** |

**Seven times the shots.** The unit was previously spending most of its life driving rather than fighting, which is why it
read as *dumb* rather than as *badly positioned*. **⚠ `--nav-off=standoff` silently does nothing on `main`** (nav,
2026-09-19) — a static-initialisation-order bug, fixed by resolving switches at read time. The measurements above were
taken by assigning the style directly and are unaffected; only the command-line A/B was broken.

**The design lesson, and it generalises past scouts:** *the unit whose weapon cannot turn must place its whole vehicle
where the weapon needs to be, and then stop.* A fixed gun is a positioning problem, not an aiming one. Round 3's `run`
style treated it as a strafing problem, which is a design for a vehicle that can shoot sideways.

**And a test was asserting the bug.** `test_a_scout_makes_attack_runs_on_a_tank` asserted `runs >= 3`; the fixed scout
makes **zero**. A scenario test written from a design intention pins that intention in place, and the intention was
wrong — so the assertion becomes *"does not close inside the ram gap, and spends the majority of its time in band"*, which
is the property the lead actually complained about and the one that can regress.

### ANSWERED: why he could not tell which way his units were facing (2026-09-19)

*"I couldn't tell what direction they were facing."* **Facing was broken at every layer, and two streams found the halves
independently without either seeing the whole:**

- **squad found the value being dropped.** K1 has carried an optional `facing` since round 5, and **`OrderFeed` never
  passed it to the brain** — so *a unit told to face east faced north*. Element tasks **rejected `facing` outright** as an
  unknown key. Both fixed.
- **nav found that even when it arrives, brains never execute it.** Measured (`make nav-facing`, builder0, yard, 30 units
  ordered to face 90° off their travel): after move+facing **the median unit is 85° off and still is 10 s later — 2 of 30
  within 15°**; for hold+facing, **1 of 29**. The cause is in `tank_brain` (squad's file), and nav has a **measured
  prototype patch** — move **29/30** within 15° at +10 s, hold 22/29 — left at
  `_agents/streams/references/nav/round7_brain_facing.patch` rather than applied to someone else's file.

**So there was usually no facing to see.** The contract carried it, the feed dropped it, the tasks rejected it, and the
brain ignored it. **Three independent failures of one feature, none of which any test noticed**, because nothing asserted
the *outcome* — that a unit told to face a direction ends up facing it. That is lesson 47's shape again: a guarantee no
test isolates.

**MEASURED AFTER THE FIX (nav, on squad's `bfcc2607`, builder0, yard, 30 player units in 5 squads each ordered to face
90° off their direction of travel — same probe and same configuration as the "before"):**

| units within 15° of the ordered facing | before | after |
|---|---|---|
| **MOVE + facing**, at +10 s | **2/30** | **27/30** (median **1.6°**; 20/30 already at +2 s, 24/30 at +5 s) |
| **HOLD + facing**, at +10 s | **1/29** | **21/30** (median **5.5°**; 15/30 at +2 s, 18/30 at +5 s) |

**For the lead, in one line: an ordered facing now actually happens, within seconds, for about 9 in 10 units on a move.**

**The remaining tail is named rather than hidden:** move leaves 3 units off after 10 s (worst **136°**), hold leaves 9 off
(worst **73°**). **Hold settles slower and less completely than move**, and nav's hypothesis is that **wheeled units cannot
pivot** — a car rolls round at `WHEELS_MIN_THROTTLE` instead of turning on the spot — or that units are still settling onto
their position. nav owns the execution of *face* and will diagnose the tail after the commitment A/B.

**Why this matters beyond the complaint:** round 6 made facing *mechanically* real in four places — armour facing, the
crossing-acquisition penalty, support-by-fire arcs, `UnitCommand.facing`. **All four were operating on a quantity the
player could not control and the units did not honour.** Emplacing an ambush, the use case he named, was not achievable.

### The arena's shape and finish (lead, 2026-09-19)

14. **The announcers cut each other off.** *"The announcers cut each others' audio off, so that destroys the feel of the
    announcement."* A priority/queueing defect in the booth, not a content problem — and it undoes the most expensive
    asset in the game. Round 4 already found one silencing bug in the booth (a priority rule starving the Veteran), so
    this is the second time announcer *scheduling* has been the fault rather than the lines.
15. **The arena is a plain square and needs to stop being one.** *"We need to figure out how to upgrade the vibe of the
    arena. Our environment is very clearly a simple square. As was the case with our popups, chamfered edges even though
    they're fairly subtle gives the attention to detail to bring the game to life. The arena could also take on octagon
    or hexagon-like shapes."*
    Two separate asks inside that, and the first is cheap while the second is not:
    - **Chamfered edges as a design language**, carried from the HUD widgets into the 3D world. He is pointing at
      something the UI already does (the cyber frames) and asking for the same restraint in the arena: subtle, not
      showy, and specifically as *attention to detail* rather than as decoration.
    - **A non-rectangular arena** — octagon or hexagon.
    **The shape change is NOT an art job, and this is the coupling to know before anyone starts.** `Arena.validate()`
    requires `half_size` to equal `Match.ARENA_HALF_SIZE` exactly — a single scalar — *"the perimeter, radar, and fog are
    sized for it"*. And `RtsCamera` computes the wall cutaway as **how far the focus is from the perimeter *square***
    (`perimeter_half()`, and the comment says square). So a hexagonal arena touches: **the camera's cutaway** (control's,
    and it is load-bearing at the lead's 21° pitch), **the radar outline**, **the fog**, **spawn and point-symmetry
    validation**, and **the navmesh's half-plus-180°-mirror construction** (which survives 6- and 8-fold symmetry, but
    the bake region and the seam do not obviously). Octagon and hexagon both contain a 180° rotation, so fairness is
    preservable — but it is a contract change across three streams, not a layout edit.
    **DECIDED: a hexagon, flat side facing each base** (arena, 2026-09-19, `40029d59`). Measured at our 121 m apothem,
    not argued:

    | shape | side | midfield width | width at z = ±60 | centre-to-wall variation | corner |
    |---|---|---|---|---|---|
    | square | 242 m | 242 m | 242 m | **41.4%** | 90° |
    | **hexagon** | 139.7 m | **279 m** | **210 m** | 15.5% | 120° |
    | octagon | 100.2 m | 242 m | 222 m | **8.2%** | 135° |

    Base-to-base is 2 × apothem = 242 m in all three, so the crossing itself does not change.
    **The hexagon is the shape that varies most, and variation is what the complaint is about.** Wide in the middle
    (**279 m — 15% more lateral room to flank** than either alternative) and pinched to 210 m at the approaches: an open
    midfield for manoeuvre and two natural funnels in front of the bases, **produced by the boundary alone, before a
    single prop is placed.**
    **The octagon is the most uniform arena available** — 8.2% variation, width barely changing, 135° corners that
    shelter almost nothing. **The closest thing to a featureless disc, and *"the game is just this big open brawl"* is
    the complaint we are answering, so its uniformity is the failure mode rather than a neutral property.** The stands'
    tiling (a hexagon takes exactly 6 × 23.07 m modules; an octagon leaves 3.9 m gaps at all eight corners) agrees and
    was **confirmatory, not decisive** — arena states it would have chosen a hexagon with no stands at all.
    **Orientation is a real choice and it is flat-side-to-base**, which preserves how bases sit on a wall today. The
    alternative — a *vertex* facing each base — inverts everything: spawns in a corner, pinched midfield, wide
    approaches. One constant, and worth an argument rather than an assumption if anyone prefers it.
    **The caveat, with a trigger date:** the pinch leaves **less room for a wide flank near a base** (210 m against the
    square's 242 m). That is fine, arguably good, **only while objectives stay off the base line** — an objective near a
    base turns that funnel into a corridor with no way round, which is the boulevard failure in a new shape.
    **Re-check when off-centre objectives land**, which is also when the reward-term metric exists to check it with.

    **Cheapest first step if the shape ever needs deferring:** chamfer the *corners* of the existing square — which is literally an octagon with
    four short sides, gets the visual win he is asking for, and can be done with a per-arena corner-cut parameter rather
    than by making `half_size` a polygon.

### Two defects to fix, not design

8. **Some vehicles point backwards at start-up** (seen with the gangs).
9. **Squads do not start as an army.** *"It seems like squads are not scoped together at the start; the units should
   start out like an army where there actually is a starting formation where each squad is separated."* Round 6 built
   formations and form-up, and then the match still opens with an undifferentiated mass.

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

### MEASURED: the maps disagree more than the factions do (combat, 2026-09-19)

**First balance picture ever taken on the maps the lead actually plays** — `yard` and `pit`, both hexagons at the 140 m
bound with off-centre mirrored objectives. builder0, **n=30 per faction per map**, SEEDS=5, positive control engaged in
both runs (844 and 668 paints), the 14 m rig deliberately reverted for the runs.

| faction | yard | pit | swing |
|---|---|---|---|
| **gangs** | **63%** | **30%** | **+33 pts — the only significant difference in the table** |
| condemned | 50% | 70% | −20 (1.6 SE) |
| law | 43% | 43% | 0 |
| syndicate | 43% | 57% | −13 (1.0 SE) |

**The gangs are the strongest army on one of the two maps he plays and the weakest on the other, by the largest margin
anyone here has measured.**

**What this licenses: nothing about faction strength as a property.** *"The gangs are strong"* and *"the gangs are weak"*
are **both supportable from this table by choosing a map.** That is exactly the error that cost two rounds and retired
the 23% → 53% pair — **and the only reason it is visible now is that the tool takes `ARENA=` and prints it.**

**What it does NOT license, stated before anyone reads it harder than it can bear:** at n=30 a gap needs **25 points** to
clear 95%, and **gangs 63% on yard carries a CI of 45–81%.** **No within-map difference here is significant**, and combat
claims neither that the gangs are overpowered on yard nor broken on pit. Resolving a 20-point within-map gap needs
**n≈48 (SEEDS=8)**, about 60% more builder0 time per map — **not proposed, because the lead has deferred balance.**

**And the comparison nobody may make: these are NOT comparable to the old yard numbers.** That yard was a 120 m square
with one central objective; this one is a hexagon at 140 with two off-centre ones. **Same name, different map** —
subtracting them is the subtraction `compare_arms` refuses.

**The design consequence, which is the lead's to weigh and nobody else's:** if map choice swings a faction by 33 points
while nothing else in the table moves at all, then **"is this faction balanced" is not a question with an answer** until
the map pool is settled. **Balance follows map design here, not the other way round.**

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

> **Round 19 (2026-10-05): the game's money is now 1000 credits a game, every vehicle open** (the lead: *"each player
> is given 1000 credits per game (and we might change this in the future so that as players advance they get more
> credits or something)"*). The tiers and unlocks below are RETIRED from the garage; the profile still records wins and
> an earned total. What follows the list is the sketch of his later layer (garage stretch c): nothing is built.

- **Winning earns credits** **(lead)**. Credits unlock **new unit types** and **higher budget tiers** (bigger armies).
  *(Round 19: retired from the garage; kept here as the history of the idea.)*
- **Fairness guard (proposed; important for die-hard players):** matches are fought at a **shared budget tier**.
  Both sides get the same budget, so a veteran's bigger bank never buys a bigger army against a newcomer. Unlocks
  add *options*, not raw power: units are sidegrades by design (counters, not upgrades). Losing still earns a
  little. Competitive/ranked play (later) uses fixed budgets and the full roster.
- **No money in the loop**, ever (pillar 1).
- Progress is saved locally first (`user://`); an account system comes with online play (netcode, later).

### Sketch: "as players advance they get more credits" (round 19, garage stretch c; NOTHING BUILT)

The one-line version: **a rank, earned by playing, raises the money a player brings to a game he chooses to play at
that rank; a game is always fought at the lower of the two sides' money.** It keeps his fairness guard (a veteran's
bigger bank never buys a bigger army against a newcomer) and his simplicity rule (one number on the garage's meter).

- **Rank, not a bank.** Playing earns rank points (the profile's earned total already counts them: `Progression.award`
  pays a win 100, a draw 30, a loss 10, plus 6 a kill, nothing for a match under 60 s). Ranks are thresholds on that
  total; nothing is spent, so a player never chooses between "save up" and "play".
- **Rank sets the ceiling, the match sets the money.** Rank 0 plays at 1000 credits; each rank adds a step (say +250,
  to a ceiling around 2000). Against the CPU he picks any money up to his ceiling and the CPU matches it. Online, both
  sides fight at the lower ceiling, so the money is always shared.
- **What grows is the army, never a unit.** More credits buy more of the same vehicles, at the same prices. The
  25-vehicle cap (five squads of five) is the natural limit: at 2000 credits every faction would hit it, so a higher
  rank is a richer MIX (dearer vehicles) rather than a bigger crowd. If he wants rank to mean a bigger crowd, the cap
  has to grow with it (a sixth squad), which is a formation and command question first.
- **The garage shows it once:** the meter reads "1250 CREDITS (RANK 2)"; a tap on the rank says what the next one
  needs. No other screen changes.
- **Questions it leaves for him:** does a rank ever go down? does a challenge or a ranked online game pay more? should
  a new player be able to opt into a bigger game early (a "sandbox" at 2000 that records nothing)?

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
- **Control: the map's scoring zones** as a second win condition, **on by default** (the lead, answering rules'
  question: *"sure, I agree with you"*; round 1 measured that it restores "coordination beats individuals" under
  shields). **Every dealt map scores TWO mirrored side zones** (`Arena.objectives_of`), named on the board, on the
  floor and by the booth as the map names them ("the west ring", and its mirror by its compass word, "the east
  ring"); the older arenas score one centre zone. A side alone in a zone fills it in 8 s (flat rate; both inside
  freezes it); each side scores the share of the zones it holds, a point a second for all of them; first to 90 wins;
  a time-out goes to points, then cost-weighted losses. (Rewritten round 19, board's text: the "center control point"
  wording dated from the one-zone arenas.)
- **Kills are shown, not scored** (round 19): the board carries each side's kills and the credits destroyed (the
  victim's price); they decide only a time-out tie.
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

## The external research review (2026-09-19)

The lead asked for a research brief to be written for an external planning system, then sent it to two of them and
brought both replies back. **His words, verbatim:**

> *"Basically what I'd like to do next is for you to formulate a prompt for an external agentic system; assume there's
> sort of a proprietary boundary between the 2 of you but you're otherwise free to speak about strictly abstract and
> research concepts. This system is optimized to produce design strategies and additional input outside of what you
> might have already considered. So I'd like for you to be able to express the intent of our game, or simulation in
> completely abstract / research oriented terms, outlining what our system is currently composed of, the general intent
> of creating extremely intelligent simulations based on state of the art computer science principles, with the
> constraints we have in place (i.e. deterministic simulation). We basically want to outline the intent that if
> [the genre's gold standard] is a gold standard, we want to exceed that standard in terms of making our AI vehicles
> intelligent individually and coherent in high-level unit structures. A crucial consideration for this planner is to
> known that we can take advantage of AI as much as necessary for offline simulation formulation. This also includes
> thins for navigation, waypointing, splining, and whatever else I'm missing. We would ask this remote agent to return
> as many design and algorithmic changes that would be useful for this endeavor."*

And on what to do with the two replies:

> *"I want you to do 2 things: First, distill and curate the feedback from both responses as it applies to our game and
> ensure this is rigorously documented inside our own codebase. Then I want you to create a final markdown doc in
> ~/Desktop/final.md that basically re-articulates the data to a human audience (me) - you would explain what
> approaches we're going to incorporate and what it means in pragmatic terms."*

**Where it lives:** the brief and both verbatim replies are in [`research/`](research/); the curation — 50 techniques
proposed, 12 adopted, every rejection given its reason — is [`research_catalog.md`](research_catalog.md). The lead's
own copy of the readable summary is `~/Desktop/final.md`.

**Two design points this raised that are HIS to rule on, not ours:**

1. **Our blanket rejection of learned policies was built on a wrong premise.** He asked and answered the RL question
   earlier the same day, and the answer recorded in `algorithms.md` was *"determinism is the blocker."* Both external
   reviews independently pointed out that the float part is a choice: a network trained offline and exported as integer
   weights is bit-exact, because integer addition is associative and there is no libm. **The blocker was never
   "learning", it was floats inside the tick.** Our recommendation is still to decline — a frozen net's failure mode
   cannot be read, and decision trees buy the same trade with a printable artefact — but the premise he decided on was
   wrong and he should get to decide again on the right one.
2. **The 12 m-vs-14 m War Rig question should be withdrawn.** Cover reads 0.99 at 12.19 m and 0.00 at 12.5 m because we
   sample the hull's **centre point**; the step function is an artefact of the query, not of the arena. There is an
   O(1) exact answer that costs the same at 2.8 m and 14 m. **Keep the rig at 14 m because it looks right, and fix the
   query** (catalogue A3).

### Ruling: the War Rig stays at 14 m (2026-09-19)

The lead, closing the question the orchestrator should never have asked him:

> *"Yes the war rig stays at 14m, we can revisit that later if it's still an issue."*

**So the 12-vs-14 decision is closed and the fix is in the query, not the vehicle.** `Arena`'s cover table stands as
measured — yard 0.99 up to 12.19 m and **0.00** at 12.5 m, pit 0.46 → 0.00, terminus 0.91 at any length — but that
cliff is an artefact of sampling the hull's **centre point**, not of the arena's geometry. Catalogue row **A3**
replaces it with the fraction of hull length occluded, evaluated by differencing directional summed-area tables: two
array lookups and a subtraction, **identical cost at 2.8 m and at 14.0 m**.

Consequences now settled, so nobody re-opens them:
- **arena owns the tables, combat owns the consumer** (`research_catalog.md` A3).
- **The standing note in `arenas.md` not to add a long prop to yard or pit still holds**, and holds *more* now: the
  rig is staying long and the fix is elsewhere.
- **`make arena-report`'s WATCH line — *"NOTHING on this map can hide the longest hull"* — must be revised in the
  same commit as the tables.** It is true under the point-sample definition and will be false under A3, and a WATCH
  line that is confidently wrong is worse than silence (arena's warning, and it is right).
- arena's step function at 12.19 m becomes **the positive control** for A3: if the cliff survives the change, the
  treatment did not engage. Lesson 147 is why that matters.
- **Still unresolved and not blocked by this:** `gangs vs law` went **9/20 → 0/20** with the 14 m rig, p ≈ 2×10⁻⁶,
  and the mechanism is unknown. Shuffling is evidenced against (the rig converts **0.95** of path to net displacement,
  the *best* of any gang type; the gang **scout** is the shuffler at 0.68). Splash is evidenced against (indirect
  kills 8.4% → 3.7%). *"Bigger target"* survives by elimination, which is not evidence.

### Ruling: offline compute is unlimited; what SHIPS must be readable (2026-09-19)

The lead, after asking the practical questions the orchestrator had skipped — *"Is there an opportunity to train some
lightweight integer model somewhere? The only thing is that I don't want this game to require a big GPU or something,
and I can't invest a bunch of money into training a model (i.e. how much would $50 of GCP resources get me?) — or
perhaps I can buy some cheap GPU or maybe builder0 even has a nice enough GPU"* — ruled:

> *"yes that sounds like a good decision"*

on the proposal: **the offline budget is open; the shipped artefact must be something a human can read.**

**What this permits:** frozen **lookup tables** from offline parameter search, and **decision trees** distilled from an
expensive offline planner (catalogue **C6**, **C7**). Both are computed by arbitrarily expensive offline work, both
ship as a small frozen artefact, both are bit-exact at runtime, and **both can be printed and read** — which is the
property the ruling turns on.

**What stays shut, for now:** neural-network policies, including integer-quantised ones. **Not because determinism
forbids them** — see the premise correction below — but because a frozen net is an artefact whose failure mode cannot
be read, and this project's standing preference is *a smaller mechanism whose failure mode is understood over a larger
one that is merely better on average*. Revisit only if a pathology appears that a table or a tree cannot express.

**The premise correction that made the re-decision necessary.** Earlier the same day the orchestrator told him
determinism was the blocker for learned policies. **It was not.** Integer arithmetic is associative, has no rounding
mode and no libm, so an offline-trained network exported as integer weights is bit-exact across platforms. **The
blocker was never "learning" — it was floats inside the tick.** He had ruled on the wrong reason, which is why the
question was re-put. Runtime learning remains impossible and that part is unchanged: anything that changes itself while
the match runs breaks replay, lockstep and the baseline.

**The hardware answers, measured rather than assumed, because two of his three worries were misdirected:**
- **The game will never need a GPU.** Inference on a shipped artefact is integer multiply-add — order **0.6 µs per
  vehicle per tick**, well under 1% of one core for 90 vehicles at 30 Hz. A GPU is involved in *making* the numbers,
  never in *using* them. Nothing here raises the player's hardware requirement.
- **A cheap GPU would be the wrong purchase.** The networks in question are ~6,000 parameters and train in seconds;
  the expense is **generating experience by running our own simulation**, which is CPU-bound Godot headless at a fixed
  30 Hz. A GPU does not speed that up at all.
- **builder0 has no discrete GPU** — Intel Iris Xe integrated, and its CPU is an **i5-1345U, a 15 W thin-laptop part**
  (10 cores / 12 threads). That is why `make check` takes 30–50 minutes. For running matches overnight it is fine:
  ~120 thread-hours a night, free.
- **$50 of GCP spot CPU ≈ 3,000–5,000 core-hours** (a 32-vCPU spot VM at roughly $0.30–0.50/hr — verify before
  spending), which is **25–40 nights of builder0 bought in an afternoon**. That is the correct *next* purchase if
  offline tuning pays off. **Not a GPU.** It costs engineering effort rather than money: our sim would need packaging
  to run there.

**Nothing has been spent, and the first step costs nothing:** offline parameter search on builder0 overnight (C7),
which directly attacks the measured problem that *three separate subsystems were implicitly sized for a ~4 m hull*.

**⚠ The prerequisite, and it is not negotiable:** offline optimisation means telling a machine *"find the parameters
that maximise this number"*, and **our numbers are exactly what we discovered were measuring the wrong thing** — time
spent oscillating, while his complaint was about the shape of the motion. **Catalogue A12 (the trajectory-space metric
suite) lands before any offline search runs.** An optimiser pointed at a bad objective does not fail; it succeeds at
the wrong thing, faster than we can notice.

### The Syndicate airship (2026-09-19, the lead) — round 9, and it costs no credits

His words:

> *"there's another asset that I think would tie everything together: I'm wondering if the marginal cost is low in terms
> of assets to add a Bladerunner-like Airship that hovered over the arena, sometimes visible in the field of view, that
> also had a big TV screen? I suppose the theme would be consistent if this airship had a Syndicate-feel to it?"*

**Answer: the marginal cost is very low, because the screen is already built.** Recorded with the reasoning so nobody
re-derives it, and **approved by him for round 9** ("yes please record that").

**What we already own, and the airship gets for free by joining a channel:**
- **`AdBroadcast`** (`game/theme/arena_kit/ads/ad_broadcast.gd`) — one ad laid out in a 2D viewport with a slow
  push-in, flipbook frames, brand/headline/fine print in real fonts and a scrolling ticker; glitches between ads and
  on `FxWorld.spectacle`. **"Ten screens cost one layout"** — every screen on a channel shares one material, so an
  eleventh screen is approximately free. Each ad's average colour already **becomes the light it throws on the
  ground**, so the airship washes the arena in whatever it is showing.
- **`LiveFeed`** (`live_feed.gd`) — a broadcast camera follows the fighting and renders at 15 Hz into a ring of
  SubViewports; newest slot is live, the whole ring is a replay buffer, so **a kill is replayed from frames already on
  the GPU**. Already tiered: off on LOW (web, phones), 16 slots on MEDIUM, 30 on HIGH. Visual only.
- **So when the player gets a kill, the airship overhead replays it.** Zero new code for that beat.

**The hull: build it from PRIMITIVES, not Meshy. This is a recommendation, not a compromise.**
- **Meshy would cost a gate and money** — 88 credits left, and `HANDOFF.md` says new 3D art needs a top-up.
- An airship is the most primitive-friendly shape in the game: ellipsoid envelope, fins, gondola, a flat screen plane.
  It is seen **far away, in the sky, often half out of frame**, so nothing about it rewards a high-detail model.
- **And Meshy is actively the wrong tool here.** Its failure mode is "cartoon" — the first Meshy concept was rejected
  for exactly that ([art_direction.md](art_direction.md)) — and the Syndicate must read **pristine, not cartoonish**.
  Clean geometry is easier from primitives than from a generator.
- It also exercises the primitives work he asked about and had not yet seen.

**Syndicate is the right faction and it tightens the theme.** The art direction has the Syndicate as the ivory tower,
almost no rust, curvy hover vehicles, clean sci-fi. **The faction that owns the sky and advertises down at the inmates
of a prison blood sport is exactly that** — and it gives the Corporate Co-host a physical platform, so the announcer
layer reads as coming from somewhere.

**Three constraints, each earned from a failure this project already paid for:**
1. **NO collision body, none.** Visual-only should leave the sim hash alone — but arena's `_build_perimeter()`
   produced geometrically identical walls with a different body creation order and **moved the baseline anyway**
   (Invariant 2). So pre-register the expectation that the hash does not move, and treat a move as information rather
   than a surprise.
2. **Verify "sometimes visible" AT HIS POSE, with frames.** He plays a 35° telephoto. *"Sometimes visible in the field
   of view"* is exactly the class of claim that turns out false: this round already shipped a camera fix for the HUD
   hiding his own selection, and a facing feature that **cannot fire on his control scheme at all** (lesson 149).
   control's per-edge `camera-looks` frames are the tool. **"Visible in a screenshot taken deliberately" is not
   visible.**
3. **Drift from the fixed tick**, never the wall clock, so a replay shows it where it was.

**Owner:** arena (placement, the primitive build) with feel on the livery and the screen's look. Small enough to ride
round 9 beside the A3 cover tables rather than displacing anything.

**BUILT AND MEASURED (feel, round 9, 2026-09-20 `5ae7e531`, laptop):** primitives, no Meshy, no collision, on the ad
channel (kills replay on it for free), tier-aware. **The lead will NOT see it at his default pose, and the reason is
geometry, not art:** the frame's top edge sits at `FOV/2 − pitch` above the horizon, which at 21°/FOV 35 is **3.5° below
it — the sky is not on screen at all**, and to fit over the arena even at his lowest tilt (8°) it would have to fly below
42 m on a map with 40 m blocks. Decided overnight: it moved out to **radius 560 m, altitude 56 m** over the *city*
(inside the skyline's 640 m); measured 768 samples: **12.5% of frames at 8–12° tilt, 105–108 px on screen, 0% at 17°
and above.** `build/airship-look/airship_widest.png` has it top-left against the lit city, half out of frame — his phrase.
**His call in the morning:** keep it as a thing he sees only when he tilts down, or make it a presentation element
(title, results, replay) where the camera can look up. Both are one constant.

## Round 9 direction: the lead's two feedback items (2026-09-19, evening)

Given while asking the orchestrator to prepare round 9. His words, verbatim:

> *"I have 2 minor feedback items I'd like to get into the round: 1. The semi trucks for the road gangs are still one
> long box itself of a truck / trailer combination. 2. We resized the semi trucks for the gang and this makes the game
> much cooler and awesome. We need to do proportional, real-world relative sizing for all of our vehicles. As an
> example, the bus-tanks and garbage trucks for the condemned definitely need resizing, so by extension I'm sure so do
> the rest."*

He called them minor. **The second one is the largest change in the round**, and it is scheduled as its own stream.

### 1. The War Rig is one rigid box: articulate it (feel, this round)

This is round 8's item 4 again (*"the gang semi trucks don't actually behave like a semi truck with a truck and a
trailer — both components just move together"*), which he offered to shelve then and has now asked for a second time.
feel costed it at the close of round 8: **a visual-only hinge is about a day**, negligible runtime, the simulation
untouched; the rigid 14 m collision box stays as the compromise. That is the shape adopted:

- **The tractor is the simulated body.** Nothing in `game/tank/`, `game/ai/` or `game/units/` changes. `articulated`
  in `Units.LOCOMOTIONS` stays reserved.
- **The trailer is art that follows the hinge.** The approved War Rig model is cut at the fifth wheel exactly the way
  `FactionArt.GUN_CUTS` cuts a baked gun out of a hull, and the trailer part's yaw follows tractor-trailer kinematics
  from the drawn motion each frame (the trailer heading lags the tractor's by the standard off-tracking law). It
  jackknifes on a tight turn because that is what a trailer does. **Its collision is still the one 14 m box** — a shell
  can hit empty air inside a jackknife this round, and that is the accepted cost of not touching the sim.
- **The Resupply Tanker is not articulated.** Round 8 settled it as a rigid tanker truck with a semi cab, 7.0 m.
- **Pre-registered:** the sim baseline hash does not move. Art cannot reach it (round 7 proved that by construction).
  If it moves, that is information about something else.
- **The real thing — a second simulated body with its own collider, and `articulated` locomotion in the plant — is
  the follow-on**, and the research catalogue's Part 7 already records that neither external review addressed it. It is
  not in round 9.

### 2. Proportional, real-world relative sizing for the whole roster (a new stream: scale)

**What he has confirmed by playing:** making the semi its real size relative to everything else made the game *"much
cooler and awesome"*. The round-8 measurement that mattered was not the number, it was that a semi finally *looked
like a semi next to a car*. He now wants that for every vehicle.

**The state of the roster today:** 21 units; every hull except the War Rig (14.0 m) and the Resupply Tanker (7.0 m)
is between **2.8 and 5.0 m long** — a school bus, a garbage truck, an 8×8 assault gun and a rat rod all drawn within
a couple of metres of each other. Real-world reference vehicles are named for almost every unit in *Factions* above
(prison bus, garbage truck, dozer, rally truck, utility truck, rat rod, 1950s pickup, tow wrecker, tanker, pursuit
sedan, retired APC, 8×8 assault gun, rocket truck, riot truck, supercar, limousine). The round-8 finding that
*"three separate subsystems were implicitly sized for a ~4 m hull"* is the other half of this: the roster is toy-scale
and the systems around it were tuned to the toys.

**The sizing rule, decided by the orchestrator (broad strokes are Claude's), recorded so it is not re-derived:**

- **One scale factor for the whole world, anchored by the War Rig.** The lead ruled the rig stays at **14.0 m**. A
  real tractor and tanker trailer is about 18–21 m, so the world's vehicles are drawn at **K ≈ 0.67–0.78 of real
  size** — the scale stream fixes K from the rig's reference length with a cited source and publishes it once.
  **Every other unit's length = its real-world reference length × K.** Nothing is sized by opinion; the only judgment
  per unit is *which* real vehicle it is, and the design doc already names most of them.
- **Width and height come from the approved mesh at that length**, via feel's `SizeLook.box_at_length(unit, length)`
  — the tool round 8 used for the rig. The collision box is the mesh's proportions at the chosen length, never a tidy
  round number, because `hull_size` IS the collider and a box that disagrees with the mesh means shells hitting empty
  air. This also discharges feel's round-8 roster-wide finding that **all 19 art units' boxes disagree with their
  meshes by more than 5% on some axis** — the resize fixes it by construction, and the every-unit box-fill test lands
  with it.
- **Why rig-relative rather than real metres:** real metres would put the rig at 18–21 m, which re-opens a question he
  closed, and would roughly double every arena's apparent crowding; rig-relative keeps his ruling, keeps the smallest
  vehicles near their current size, and grows the mid-roster (bus, garbage truck, APC, assault gun) by 1.5–2×, which is
  exactly the change he described. **If he would rather have real metres, it is one number (K) and a re-run of the
  table.** That is the one question on this round's decisions page.
- **Balance is not a constraint on sizing** — his round-8 ruling (*"we'll worry about evening up factions later"*)
  extends to the whole roster. Measure the consequences (the rig's 9/20 → 0/20 is still unexplained); do not tune
  sizes to fix them.

**What the resize reaches, so every owner knows to re-measure after it lands (checkpoint CP2):** the spawn grid
(`SLOT_X` 11 m columns and 8 m rows were sized for a 2.6 × 4 m hull, and length was the axis that appeared to cap the
rig in round 8); the navmesh's single agent radius (P6: one radius for a 5× footprint range); formation slot spacing
(squad); cover registration (catalogue A3 exists precisely so cover works at any hull length); muzzle heights
(rounds fly flat at muzzle height, so every muzzle must stay below the shortest hull's top); the camera at his 35°
telephoto (control); and the sim baseline, which moves and is recorded once by the orchestrator. **Nobody publishes a
size-dependent number measured across CP2.**

**WITHDRAWN (2026-09-20 02:40): the gap-widening ruling.** For twenty minutes the record said the kit's gaps would widen
to the widest hull plus 1 m, because scale's `arena-report` showed the direct route pinching below the 4.74 m artillery
on 8 of 10 maps. **The measure was wrong**: it returned twice the distance to the *nearest* obstacle, which equals a
corridor width only with an obstacle on both sides; yard's reported 4.72 m "pinch" is a route hugging one wreck with
20 m of clear ground behind it — the real span is ~23 m. The orchestrator ruled on it within minutes without checking
one value. **The maps are not changing on that evidence.** What stands: the resize lands as is; squad's artillery did
fail one defile on the maze fixture at its old width, and that is nav's plant/right-of-way question, not geometry.
scale's corrected measure (march perpendicular to travel both ways until something tall is hit) reports when it lands;
if a real pinch exists the question is re-put with the right number.

**The lead sees the roster before it ships:** the scale stream renders all 21 vehicles side by side at the new scale
in one frame (the rig and a Condemned tank as references, the same camera as the gallery) and puts it on a review page.
It is the one subjective check that counts; the numbers are derived and need no approval.

## Round 9 addition: the arena as a light show, and the camera inside the Terminus blocks (2026-09-20, the lead)

Enqueued mid-round, with `/tmp/widget2.md` (the breathing-conductors HUD spec) as the reference for *how* — bake the
expensive part once, animate only a scalar. His words, verbatim:

> *"The point is not the widget itself, it's the concept of creating efficient graphics effects in an efficient manner
> (i.e. we can get away with nice effects that bring the arena to life without costing much in terms of frame rate).
> Basically the new Terminus map is AWESOME and really cool. But it also looks pretty retro for a game. We could easily
> bring these figures to life by making the lit edges breathe and glow. These were also set up as looking like city
> buildings, but since this is an arena theme, we can also fade in and out different lights on those buildings. But if
> we want to make this really cool, rather than just randomly having breathing lights, we should immerse ourselves in
> this whole arena sporting event, and ideally we could create lighting patterns that were consistent with an
> entertainment event (i.e. imagine light shows in Las Vegas). Similarly, the arena edges right now are just a dull neon
> purple. Those could easily have a breathing effect as well."*

> *"One more feedback item that also wasn't accounted for: In the Terminus map it's highlighting another problem where
> the camera often ends up inside a building and we can't see what's going on inside the alleyways. We need to make it so
> the camera is forced outside the solid for these cases."*

> *"Note that for the buildings I'm obviously talking about the Terminus case, but in theory these blocks should be
> highly re-usable, so the point is that we'd want abstract modules for creating light effects. You're better than me at
> identifying what those abstractions are exactly, but if our whole theme is a sporting / entertainment arena then we
> could probably account for all sorts of abstractions for creating lighting effects (i.e. stadiums also have spotlights
> and signage all along the rafters, we might be able to later add lighting effects to things like roads or bridges,
> etc. I would give the guidance to make it beautiful, with the idea that we can easily create desirable lighting
> effects at low compute cost using whatever programming tricks we can."*

### The abstractions (the orchestrator's answer to "you're better than me at identifying what those are")

Stage lighting already has the vocabulary, and it maps onto what the renderer can do cheaply:

- **Fixture.** Anything emissive that can be driven: a block's lit edges, its window grid, the perimeter neon rim, a
  floodlight pool, a sign, a spotlight beam; later a road stripe or a bridge. A fixture is **not a light** — it is an
  emissive surface on an existing mesh or MultiMesh instance, driven through per-instance custom data or a material
  uniform. Adding a fixture adds **zero draw calls and zero real lights** (M1's budget; `fx_tricks.md`).
- **Channel.** A named, time-varying scalar or colour computed **once per frame on the CPU** and pushed as one uniform
  or one instance-data write: breathe (period, phase — incommensurate across fixtures so the ensemble never syncs, the
  widget spec's rule), chase, strobe, sweep (direction, speed), colour cycle. A show has tens of channels, never one per
  fixture.
- **Patch.** Which fixtures listen to which channels, **in data** per arena (the layout JSON's dressing or a show file
  beside it), so the Terminus, the yard and a future bridge are patched without code.
- **Cue.** A programme of channel settings bound to **match state** — L5's `MatchMood` (`lull`, `skirmish`, `battle`,
  `last_stand`, `victory`, `defeat`) and K5 events (FIGHT: house lights down, spots up; a kill: a ripple across the
  blocks; last stand: everything strobing at the losing base; victory: a sweep to the winner's colour). **This is what
  makes it an entertainment event rather than random breathing.** Idle is the slow breathe; the cues are the show.
- **The efficiency rule, from the widget spec:** *bake the expensive part once, animate only a scalar.* Glow halos
  (signs, beams, edge bloom) are pre-rendered sprites or emissive geometry, never a per-frame blur; the breathing lives
  in the modulation value. No `OmniLight3D`/`SpotLight3D` added by the show.
- **Visual only.** The show reads the match and never writes it; it runs on frame time, not the tick (nothing in the
  simulation may depend on it); pre-registered: the sim hash does not move.

**First frames (show, 2026-09-20 03:27, builder0, `685df1f2`; 30 frames, terminus and yard, `shader errors 0`, sent to the
lead):** the block edges (chamfers, bevels, parapets) carry an emissive strip where they were a pale albedo, each block
on its own clock; window grids vary per window; the rim breathes. **Decided overnight:** the direction is approved; the
edges currently read as an outline on every building, some in cool white, which `art_direction.md` warns against, so a
second variant ships beside it. **feel's ruling (art owner, 03:45), adopted as the default:** energy and colour were not
what was wrong — `show_edge` is added to emission on the bevel/chamfer branch, which IS the silhouette, so it can only
ever draw an outline, the named Never in `art_direction.md`; in the street frame it is a glowing bar stuck diagonally
across a flat wall with no housing. **Default: `show_edge` 0 on the vertical chamfers; the breathing lives on
`show_window` and `show_shop` (light inside things, the "Blade Runner night" the art direction names); one horizontal
run on the roof parapet only, dimmer than the windows; venue palette (magenta, cyan, amber), red reserved for beacons and
warnings, no cool white.** The full-outline look stays as a named patch variant so the lead can compare both in the
morning — his words were *"lit edges breathe and glow"* and he gets to see it. **The rule that matters for play:** the
arena floor and the vehicles must stay the brightest read in the frame (in the first frames the building edges were the
brightest pixels and the fight the darkest); `show-frames` now measures it and refuses a strip where the periphery wins. **Then the three-arm strip (show
`924b2506`, 04:50) showed the inversion is the Terminus, not the light show:** the BEFORE arm with no show at all already
has the block band brighter than the fight ring in 22 of 30 frames at his 21° pose over dark asphalt. An absolute gate
would have blocked the merge for a property of the venue. The bar is now relative — the show must not make the
ring/band ratio worse than the same frame with the show off, tolerance 3% against ±1.5% noise — and **the parapet
default moves it −2.6% to +7.4%, mostly positive: lit interiors make the fight marginally easier to read.** feel's
"brightest pixels are the edges" was a maximum on the outline variant, not this mean; frames now report both. **Diagnosed (feel, 05:20): the Terminus is the only arena with `block` props — eight 40 m lit towers INSIDE the fight at
r = 40 and 69 m — and has half of pit's floodlights at the same size, both out at r = 128 on the centre line. The venue
got brighter and the floor did not. Fix requested from scale (the layout is the one owner of arena brightness; feel
refused to compensate in its materials): two floodlights at the street intersections among the blocks.** Found only
because show reported a no-show control arm beside its treated one.

**The cost, measured with the instrument that works (show `96e10e82`, builder0, terminus 1080p seed 3, the `no_show`
layer toggled within one run seconds apart): GPU +0.22 ms, draw calls +2.25, against the run's own 7.69 ms GPU; the CPU
figure came out −2.0 ms, i.e. inside the method's noise, so the honest reading is under half a millisecond of GPU and
nothing measurable on CPU. On the laptop's GPU (~2.3× slower) that is ~0.5 ms of a 33.3 ms budget: about 1.5% of frame
time for the whole venue light show.** The luminance gate passes 36 of 36 frames against a measured null (median 0.5%,
p95 1.3%, bar 3%), at the cost of one look decision: the window band was narrowed from [0.70, 1.35] to [0.80, 1.10]
because the channel's peak frame was −7.3% against the fight ring, so the buildings breathe less hard at the top than
he asked for; it is one number (`show.channels.windows.ceiling` in `arenas/terminus.json`) and the gate says what raising
it costs the fight. Five 6 s clips (lull, battle, last stand, victory, kill) are in `build/show/clips/`.

**Read the stills knowing this (show, 06:35):** the coloured horizontal lines on every block in *both* arms are
**feel's round-7 shopfront neon band** (`CityBlock` surface 1, ~4 m up), not the show — they were on the Terminus he
called retro. The show-off arm is genuinely off (the band's luminance differs by a median −0.39%, noise). **Between
feel's dark-chamfer default and the readability gate, the default patch is now conservative to the point of being
almost invisible in a still: the venue *breathes* rather than *looks different*, and the clips are the evidence, not
the strip.** Three dials for him, all data, none code: `show.channels.windows.ceiling` (1.10, was 1.35 — how hard the
buildings breathe; the gate says what raising it costs the fight), `show_edge_energy` (0.8, parapet only), and
`"style": "outline"` (the full-silhouette look, rendered in `build/show/outline/`, which feel argues against). **A
latent bug found on the way (feel's file, one line):** `CityBlock.neon_color()` honours only colours beginning with
`#`, so `arenas/terminus.json`'s `"neon": "cyan"` on four blocks and `"magenta"` on four are all silently ignored and
the bands come out random amber/white/red/violet instead of the cyan and magenta the layout chose. Stills cannot show a cue (a chase is
motion; last-stand caught at a strobe trough reads dimmer than idle), so short clips per cue and a before frame from the
no-show arm follow. The kill ripple did not read in its frame (likely no headroom above the battle cue's 0.96) and is
unproven until shot against lull. Cost: 15 uniform writes per frame idle, 16 on a kill, 25 in the victory sweep, driving
eight buildings, every window, six rim edges, every sign and floodlight — O(driven materials), not O(instances).

**The bar is his: "make it beautiful."** Frames at his pose (21°, FOV 35, 49 m) on the Terminus and the yard, before
and after, plus `make perf-scene` numbers on builder0 showing the locked 30 fps at 1080p with 30 a side still holds.
He judges the look; the frame time is the check.

### The camera inside a block (control)

His words above. The venue already has a wall cutaway (control's, the perimeter); the blocks are `StaticBody3D` boxes
from the kit. control decides the mechanism — pushing the camera to the nearest point outside the solid along the view
ray, or a cutaway of the block between camera and focus, or both — and proves it with frames on the Terminus at his
pose, in the alleys, with the case that hides the alley when the camera is pushed out shown and handled. Recorded for
control's backlog; the running worker adds it to its own brief.

**Decided overnight (control, 2026-09-20, orchestrator endorsed on the lead's behalf): the mechanism is a LIFT, not a
push-in.** At his pose the camera sits 17.6 m up and 45.7 m back; the Terminus blocks are 40 × 24 × 40 m with 20 m
streets. Shortening the boom until it exits the block collapses 49 m → ~11 m — below `MIN_DISTANCE`, near
first-person, and the far side of the street still walls the alley: that answers the sentence and not the problem.
Lifting over the roof takes the pitch **21° → 32°**, keeps 41.5 m of horizontal reach, and looks *down into* the alley;
it is inside the tilt range he can reach by hand (8°–70°), and only shortens the boom when even `MAX_PITCH_DEG` cannot
clear a roof. Measured over every open ground point on the Terminus × 8 yaws at his pose: **703 of 4,328 poses had the
camera inside a building; 0 after; worst lift 11.0°; nothing pulled in.** **But the second half of his sentence is not
fixed by it** (control, measured the same night): over those 703 poses the sight line from the camera to the ground it
aims at was blocked by a building in **700 before and 518 after — a 26% reduction.** 518 cameras are correctly outside
every solid and still looking at the side of one. **The occlusion cutaway is still owed, and the alley frames decide
it; 703 → 0 must not be read as the item finished.** **Built the same night (control, `bd69de5f`, laptop):** the block
between camera and aim point is hidden (`visible = false` on its visual slot — no alpha, no uniform, no emission, collision
untouched, its cue keeps running underneath), and **the alley behind a wall goes 518 → 0** over the same 703 poses.
Caveat to report with it: every one of the 518 was a *building*, so the 6 m "buildings only, never cover" threshold
cost nothing on the Terminus and is untested on an arena with tall cover. Alley frames at his pose follow. Mutation-checked; an arena with no cityscape
is provably untouched. Because this is the second place the camera overrides his tilt (after the far-range floor), it
reports `lifted_deg` and is flagged to him rather than hidden. Frames at his pose in the alleys follow. **He can
overrule this in the morning**: a push-in variant is the same test with a different resolver.

### MEASURED: the factions already drive differently enough to see, and none drives better (squad, 2026-09-20)

The lead asked for it by name (*"we might even be able to differentiate units of different factions by PID values"*).
One hull driven against a moving-then-stopping slot, laptop, `stream/squad` (X6):

| gains | tracking gap | overshoot on stopping | settling |
|---|---|---|---|
| default | 0.20 m | 1.89 m | 3.23 s |
| syndicate | 0.09 m | 1.68 m | 3.23 s |
| gangs | 0.81 m | 2.56 m | 3.30 s |
| law | 1.00 m | 1.56 m | 3.20 s |

Every intent beside the tables holds: the Syndicate is 2.2× tighter than the reference crew, the gangs overshoot most,
the Law overshoots least and — the surprise — tracks loosest, the honest consequence of *damped and deliberate*
(heavy D, light I: never overshoots, never quite closes). The tracking gap spans **11×**; at his camera a metre of
station slop is a quarter of a hull and 2.5 m of overshoot is most of a hull past the mark. **Settling time is 3.20–3.30 s
for all four, a 3% spread: nobody arrives faster, they arrive differently** — flavour without a balance lever, which is
what the no-pay-to-win pillar needs. **In one sentence for him: the factions already drive differently enough to see,
and none of them drives better.** What this is not: one hull, a synthetic slot, no enemies or terrain; whether the
difference reads *in a fight* and stays balance-neutral in a match is unmeasured, and cannot be measured until
`ControlGains` takes a runtime override (nav's file, requested) so identical armies can be given different gains.

## 2026-09-20, afternoon: first play after round 9's merges (`make skirmish`, main at `7424420b`)

His words, verbatim:

> ok what are we waiting on to merge right now? I did a make skirmish and there is neither the blimp that I wanted
> to see or the lighting effects on the Terminus map (i.e. making use of the windows). I did see the subtle glowing
> effect but that's it. The units seem a little smarter but it's hard to tell - The Terminus map is also probably
> still not ideal because these containers in the middle of the road make it hard to tell if the section is just
> impassible - I'll know that they units are doing what I want when I can navigate them through the Terminus streets

What that is against the tree he played (orchestrator's reading, 16:40):
- **The blimp was never briefed.** No stream, brief or design note in this repo mentions one; it is a gap in the
  orchestrator's record of his intent, not a stream's miss. Round 10 item, art direction his.
- **The Terminus windows DO breathe on that tree** (`show_window` / `show_edge` uniforms in `city_block.gdshader`,
  driven from `show.gd`), and they are exactly as subtle as the show stream measured them to be: a 30 % swing on a
  `[0.80, 1.10]` band, every cue gated by a luminance pair at a 4.6 % bar. "Subtle glowing effect but that's it" is
  the show as built. His eye is the verdict the brief said counts: the dial is the band's WIDTH (show's own note), and
  round 10 turns it up until HE says it reads, with a before/after pair for each step.
- **"Units seem a little smarter":** hold-on-arrival, squad facing, the hull-shaped marker and control's chevron are on
  the tree; combat's settle tick (`Tank.place()`, every match's first tick fixed) is NOT yet, and the plant constraint
  is OFF. The acceptance he names, driving squads through the Terminus streets, is round 10's bar for nav + squad.
- **Containers in the middle of Terminus roads:** an arena-authoring question (feel's kit, nav's clearance rule). The
  read he wants, "is this passable", is a legibility problem before a routing one.

His follow-up, verbatim (16:55):

> ok but previously I had given some long prompt about how I wanted to effectively see light shows. Those 3d buildings
> right now look like a 1990s game, and we could bring it to life by having some sleight-of-hand lighting tricks (i.e.
> basic primitives to adjust individual lights on the building) and couple that with light show effects in general.
> But in any case, our goal right now is to converge so we can re-merge and reset the environment

Reading: the long prompt is `/tmp/widget2.md` from the night before (breathing, glowing lit edges on Terminus;
Las Vegas-style fading light patterns; breathing arena edges; the camera forced outside solids; abstract light-effect
modules; beautiful at low compute cost), which show's brief carried as the dials page and the channel engine. What
shipped is the engine with its dials set where the gates allowed; what he asked for is the SHOW. Round 10's show brief
starts from these two quotes: **basic primitives to drive individual lights on a building** (per-window, per-edge, per-sign
addressable, not one uniform over eight blocks), and **light-show effects composed from them**, judged by his eye against
a 1990s-game baseline frame, not by a luminance bar. The immediate goal is convergence: merge, close, reset.

## Round 10 direction: the lead's playtest on Terminus (2026-09-20, evening, main at `de31eeea`)

His words, verbatim (one message; the round is split from it):

> I want to review the next round of work. Reviewing an iteration of gaming, it's hard to give feedback because there
> are some general playability blockers. I'm playong on the terminus map, and I want to gauge how smart units are by
> trying to navigate them through the city. But there streets are blocked with these shipping containers so there's
> almost no passageway. Some problems though - vehicles are going straight through and overlapping with some of the
> assets (like the lights). I asked for lightshows on the building walls but haven't gotten that yet, we're missing the
> blimp I wanted. We can definitely expand the set of things announcers can say (try to generate more stuff on the same
> theme to create more selection - let's burn through some ElevenLabs credits). You alreayd mentioned that the truck
> rigs had yaw problems. Units are still driving into walls. The turret placement on our vehicles is wrong (at least
> with the condemned and the gangs). When I select a set of units that doesn't necessarily belong to a squad, the
> buttons to do support by fire or whatever the case is is disabled - any way we can make that usable for new, random
> selections? I can see that the condemned bus is too small still. It should be longer than the garbage truck and
> heightened proportionally. I'm also trying to move units, and they weren't responding (I can see improvement for sure
> in formation generation and stuff). But I had a selection and the yellow X's on the map were in the center, that's
> where they were driving to, and I was trying to right click to move them in a different direction and they didnt
> respond

**What it means for the round (orchestrator's reading; every item below is a stream's first backlog entry):**

1. **The playability blockers come first.** He cannot judge unit intelligence until he can (a) give a move order and
   see it obeyed at once, (b) give element orders to any selection, and (c) drive through the Terminus streets. Those
   three gate every other judgement, so the round is ordered by them: commanding → the Terminus streets → walls and
   yaw → the look (lights, blimp, turrets, bus) → the announcer.
2. **The unanswered right-click is the worst bug in the game right now.** A selection with orders in flight (the
   yellow X markers at the map centre were its destinations) ignored a fresh right-click elsewhere. A new order from
   the player replaces an in-flight one, always, within one input frame; anything the squad layer does after arrival
   (hold-on-arrival, co-arrival pacing) yields to it. control diagnoses on the default `make skirmish` path from the
   input event to the crew's order, and the readout must say what was ISSUED (lesson 183).
3. **Element orders for any selection.** "Support by fire or whatever the case is" is disabled unless the selection is
   a squad. Decision: any selection of two or more units becomes a transient element when an element order is given
   (one of them the base, the rest the manoeuvre element, by role and position); the buttons are never disabled for a
   selection that could carry them. squad provides the API, control the buttons and the readout.
4. **The Terminus streets.** Containers in the roads are the map's fault, not the units'. Decision: streets are for
   driving; containers and other props stand on lots, against walls and at kerbs, never across a street; a few authored
   chokepoints are allowed but every street keeps a lane wider than the widest hull (the War Rig's 3.32 m plus the
   bake margin), and the arena report prints each street's narrowest lane beside that number. Every prop a vehicle
   cannot drive through (lamps, containers, planters) has a collider AND sits in the navmesh bake; a prop without a
   collider is a decoration and lives where no vehicle drives. "Vehicles going straight through the lights" is that
   rule broken by the round-9 lamps.
5. **Walls and yaw.** Units still drive into walls (nav's), and the rigs still yaw through geometry (combat's plant
   constraint, off since round 9's bisect). The acceptance for both is his: a squad ordered through the Terminus
   streets arrives with zero wall contacts and no hull rotating through a building, measured on the default path.
6. **The look.** The light show on the building WALLS (per-window primitives composed into effects; his eye against a
   1990s-game baseline frame, not a luminance bar); the blimp he asked for, visible at HIS pose over the arena (the
   round-9 airship sits at 560 m over the city and is out of frame at 21°: that is the miss); the turret mounts on the
   Condemned and gang hulls sit in the wrong place; and the Condemned bus reads too small: **longer than the garbage
   truck (the Condemned IFV, 7.54 m) and taller in proportion**. The bus's number is his eye, not the reference table:
   the S1 rule is amended for `tank` (and `burner`) so the lead's ruling on the lineup frame is the source and the
   reference is recorded beside it.
7. **The announcer.** More lines on the SAME themes, for selection variety, and he has authorised the spend: "let's
   burn through some ElevenLabs credits". Decision (orchestrator, on his words): lead gate 1's text approval is
   satisfied for this round by the standing humour direction above (satire that is slightly off, never a punchline;
   the caller as authentic fight-night hype) plus the audit tool; the announcer stream writes, audits, puts every new
   line on the review page, and generates WITHOUT waiting; a line he vetoes on the page is regenerated or dropped
   (cheap). The ledger records every run. Scope is his to limit (memory: he limits the asset count, not the spend).

### Maps: bridges, pits and water (the lead, 2026-09-20, evening, after the round was briefed)

> another possible workstream - what about map generation? I had asked about adding bridges / pits / water elements
> to create different mapping types, but this never materialized

Why it did not (orchestrator's reading): the round-7 mechanism exists (`ArenaTerrain`: water and pits carve the
navmesh, bridges restore a deck, a 0.9 m rim stops hulls and not shells, all measured by `make water-probe`), but
**no shipping arena carries a `terrain` list and the `arena.terrain` art slot was never filled**, so there was
nothing to see; and until round 6's off-centre objectives landed (`spread` 0.00 → 0.35 on yard), a bridge had nothing
on the far side worth crossing for, which is his own rule. Both gates are now open. **Round 10 adds a ninth stream,
`terrain`:** the art for the slot first, then two maps that use the mechanism with mirrored objective pairs (a river
with two bridges; pits as kill zones), each judged by the arena report's `spread`, a paired match series showing the
expensive route used, and his eye on the arena page. Bridges are lanes under R4 (the rig fits, corners certified).

### Squad orders for a mixed selection: regrouping already works, the UX must say so (the lead, 2026-09-20, night)

> quick feedback after a few games - one of my earlier confusions is now gone. If I select a group of units composed
> of multiple squads, I complained how the formation options went away. I see now that if I just regroup the unit,
> they can operate as a formation. That is good behavior, but the UX just needs to clarify that

Consequence: **R1 is narrowed.** No transient element is formed automatically from an arbitrary selection; the
existing behaviour (assign the selection a control group, 1–5, and it becomes a squad that carries formation and
element orders) is the design. What changes is discoverability: the greyed task buttons say why in words the player
reads, and the card offers a one-click **Form squad** action that assigns the next free group number and enables the
buttons at once. Squad's CP1 API is withdrawn; control owns the whole item.

### Formations still do not come together (the lead, 2026-09-20, night, after a few games)

> Formation behavior is still not great, i.e. the units really don't coherently come together in a formation. I
> assume that's somethin we're still ironing out and working on?

Yes; it is the round's centre. The four measured causes and their owners: arrival declared at the slowest member
after every slot is dressed (~40 s on a 20 m move; squad's three-phase arrival, bar 8 s); slot pitch from width where
rotation needs the turning envelope (squad's pitch, arena's spawn grid); wheeled hulls that cannot dress to a facing
(they keep the approach heading, the turret covers); the mover that knows no leash or corridor (nav's seam item, the
funnel construction). Combat's yaw freeze underneath all four. The acceptance is his: squads driven through the
Terminus streets and seen to arrive as a formation.

## Round 11 direction: the lead's playtest of the airship build (2026-09-23, night)

He played a few matches and sent one message. It is a **light round** by his own framing — eleven items, most of them
defects with a named cause, and one of them ("no new maps") turning out to be a one-line rotation table. His words,
verbatim and unedited:

> *"we still barely have any maps, I haven't seen any bridges or pits that I've asked for, there have been no new maps.
> Syndicate has some backwards vehicles.
> The turret on the Law's IFV is not spinning
> The vehicle sizes on the tanks for The Condemned are not consistent. THere is some variant of the tank which is quite
> tall. Then there are the previously sized units. They need to be uniform, but also it was good for the busses to be
> slightly taller (as in the deformed version, but not quite so tall). Also, I notice that units can still drive right
> through the spotlight assets in Terminus; solid objects should not intersect. In Terminus, if I tell a squad to go
> somewhere, a lot of vehicles still look dumb because they'll drive into a wall before trying to back up (i.e. it looks
> like our algorithm is trying to do a multi-point turn based on hitting an obstacle) - it would be more ideal if the
> units detected that their path would bump into a wall, and therefore they need to go in reverse first; a real-world
> driver would execute a 3 point turn as necessary. Also in terminus when I tell a squad to go to a point, it appears as
> though a unit's target position ends up inside of a building or something, because some of them still just look dumb
> getting stuck behind a wall. I suspect (and I could be wrong) that what I described is a 2 part problem. I also notice
> that the camera can end up inside the airship - similar to what we did with buildings, it would be ideal if the camera
> and airship intersected, we push the camera up above the airship (that way there's more likelihood of seeing the cool
> airship for an in-game effect). The tanks for the law should be bigger, and the IFVs probably should also then be
> bigger. It also looks like the turret on the law tank is disconnected (i.e. the barrel of the tank is detached at the
> tip, there's a floating piece of the barrel that stays fixed in front of the tank). It also looks like the airship
> itself ends up intersecting with the buildings in Terminus as it flies around"*

### THE FIRST ITEM IS NOT A CONTENT GAP, IT IS A ROTATION TABLE (orchestrator, before briefing)

`Arena.ROTATION` (`game/arena/arena.gd:63`) is `["yard", "pit", "terminus"]`. Those three are the **only** maps the
faction picker offers and the only ones "Random arena" can roll, and `arena_choices()` is built from `ROTATION`, not
from the layout directory. `arenas/` holds **fifteen** layouts. Round 10's `terrain` stream built and measured exactly
what he asked for a round earlier — **the Crossing** (5 terrain entries: water with two bridges) and **the Sumps**
(6) — and neither has ever been reachable from the game. The Boneyard and the Boulevard are in the same position.

This is lesson 32 for the third time ("it's missing" means "it doesn't reach me"), and it is the reason the brief's
first item is *publish what exists, with his eye on it* rather than *build more maps*. Note the second half of the
same sentence, which is a genuine gap: **`arenas/pit.json` carries `terrain: []`** — "The Pit" is a name, not a pit.
He has asked for pits twice; the mechanism (`ArenaTerrain`, round 7) carves them and `make water-probe` measures them,
and no shipping map uses it for a pit.

### The 2-part problem he suspects in the Terminus, named

He is right that it is two problems, and they have different owners:

1. **The path is not consulted before the hull commits.** Reversing today is *reactive* — something has to go wrong
   (contact, no progress) before the driver considers reverse, which is exactly the "multi-point turn based on hitting
   an obstacle" he describes. What he is asking for is the *planned* version: look at the next leg, ask whether this
   hull's turning circle can take it from this heading, and if it cannot, **reverse first** — a three-point turn
   decided before the bumper touches the wall, not after.
2. **The destination itself can be inside a building.** A formation slot is geometry; a building is not consulted when
   the slot is computed. A unit given an unreachable point behaves exactly as he describes — it drives at the wall
   nearest the point and sits there — and no amount of driver intelligence fixes a goal that is inside a solid.

Both halves are nav's; neither is fixed by the other.

### Solid means solid, and it applies to the airship too

Two of his items are the same rule at two scales: **units drive through the Terminus spotlights**, and **the airship
flies through the Terminus blocks**. A prop the player can see is a prop the player expects to be solid. The airship's
case is the harder one because it has no collider by design (giving it one would move the sim baseline), so its
clearance has to come from the layout's own prop extents rather than from physics.

### The camera and the airship: push up, not away

> *"similar to what we did with buildings, it would be ideal if the camera and airship intersected, we push the camera
> up above the airship (that way there's more likelihood of seeing the cool airship for an in-game effect)"*

Note what he is asking for: not "don't let the camera clip the hull" but **"use the collision as an excuse to show the
airship off"**. Up and over, so the hull comes into frame; the round-9 rule for buildings pushes the camera *outside
the solid*, and this one has a direction.

### Vehicle proportions: uniform within a faction, and The Law is too small

Four separate asks, one owner:
- **The Condemned's tanks must be one size.** A variant that is "quite tall" is a deformation, not a design choice.
- **The buses keep some of the extra height** — "slightly taller (as in the deformed version, but not quite so tall)".
  So: the bus's height is deliberate and stays above the stock hull; the tank's is a bug and goes.
- **The Law's tanks should be bigger, and its IFVs with them.** Relative scale is a faction read: the Law is the state,
  and it should look like it outweighs the scrap it polices.
- **Two rig defects:** the Law IFV's turret does not spin at all, and the Law tank's barrel has a **detached tip that
  stays fixed in front of the hull** — a node left parented to the wrong parent, not an art problem.
- **The Syndicate has vehicles facing backwards.** Godot's forward is −Z; the airship's own pass-2 bug was exactly this
  and cost a night. A per-model yaw convention that is checked by a test, not by eye, is the fix that stops it coming
  back a fourth time.

### Round 11: the lead's verdicts from the two review pages (2026-09-24, answered live)

**From the arena page** (https://claude.ai/artifact/DUa5fN72G9YDTjLYRFkuj6 — note: built WITHOUT the `db`
capability, so his taps could not be recorded and every question had to be re-asked by hand in the orchestrator's
session. **Every review page from now on declares `db`**; that is the cost of forgetting it):

1. **The Crossing and the Sumps: KEEP BOTH.** They are verdict maps now, like the yard and the Pit — no longer
   "dealt but unruled" (`Arena.ROTATION`'s comment; `test_random_deals_only_the_maps_the_lead_kept` lists them as
   kept).
2. **The Locks: DEAL IT**, and he approves recording *"the Locks"* for the 18 announcer lines that say `{arena}`.
   A paid ElevenLabs run, authorised (~2,071 credits, priced as a dry run before a character was spent). It joins
   `Arena.ROTATION` **in the same commit as its recordings, never before** — a dealt map without them reddens
   `announcer-check`.
3. **The Pit: DIG IT.** Four sheer pits at the ring's corners ship in `pit.json`, the map he kept in round 9, with
   not one container moved: "The Pit" stops being a name. The undug Pit is preserved as the fixture `pit_dry` and
   the change is one line to undo (`tools/make_arenas.py`; before/after frames in
   `_agents/streams/references/arena/pit-dug-2026-09-24/`).
4. **Water reads black and should read wet** — he agrees, and chose *next round* over tonight. Written up as the
   first item of the next art/terrain round in `_agents/arenas.md` *Water reads black*, briefed from arena's own
   frames and pointed at from `roadmap.md`. **Not started.**
5. **Is the Locks' open canal the kill zone he wants, or does it need cover on the quays?** He did not answer, and it
   blocked the stream, so **the orchestrator ruled: LEAVE IT OPEN**, and the ruling is recorded beside the layout.
   The exposure IS the map's proposition — the short way over is watched, the flanks are not — and adding cover
   before he has driven it erases the only thing that distinguishes it from the Crossing. Re-put to him on the next
   page AFTER he has played it, with the exposure number beside the question (the centre sees 45 % of the field).

**From the fleet page** (https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS — `db` declared, taps recorded in
`decisions/<id>`, read back with `read_db`):

6. **The Law at 1.25× the real-world rule: APPROVED.** Assault Gun 5.84 → 7.30 m, APC 5.01 → 6.26 m. Recorded as a
   declared per-faction multiplier on top of the round-9 rule (`length = reference × K × FACTION_SCALE[law]`), not as
   two hand-edited numbers, so it stays a rule a reader can check. **This is the first time a faction's scale departs
   from the one-world-K rule, and it is his call, not a derivation.**
7. **The burner keeping the bus's shape: REJECTED**, and his words reframe the question:
   > *"I had no idea these were 2 separate unit that all makes more sense now. We will want to create a different unit
   > type for the burner because it looks identical to the tank"*

   So the burner returns to 2.40 m, and the real answer is that **the burner must stop being a reskinned prison bus.**
8. **All three round-10 burner concepts: REJECTED**, with the direction:
   > *"I had no idea there was a dedicated burner yet. To keep things ridiculous this should be based off of an actual
   > fire engine."*

   A new concept set briefed from a real fire engine (ladder, pump panel, hose reels — the silhouette a child points
   at), from the Condemned's approved art as `REFS`, never from adjectives. `roadmap.md` already carried "the fire
   engine 3D" as one of his round-10 taps: this is the second time he has asked.
9. **The bus: `bus_r10_b` APPROVED for 3D** (a and c rejected). It replaces the stretched dozer the bus wears today.

**And on the airship, watching the clip:** *"I opened that video and it looks fine."* — the camera lift is approved
as shipped. **The orchestrator's ruling on the airship's own open question** (on the Terminus, "never intersect a
building" and "in his frame at his pose" cannot both hold at any size): **keep it as a zoomed-out sight there.** The
Terminus is the only shipping map with 40 m blocks inside the fight; he asked to see the airship *more*, not
constantly; and the alternative re-opens a size he has already ruled on twice.

## Round 12 direction: fine-tuning, not a round (2026-09-26, the lead in the main checkout)

The lead: *"we are not going to orchestrate work we are just going to fine tune some things now. This game is getting
pretty good, and the issues I see now are rather fine tuned."*

**Navigation and formations.** *"The maps are small, and it seems to take a long time for units to form up in the
desired formation. It's hard to tell if the formations even work — I think they do but I think the units are just so
inefficient at getting to that state that it's almost unusable (although, perhaps it's an element of the game that it
takes time for units to get in formation). … I just started a game where my first action was to click a location for a
squad, they were in auto formation (which I assume is a wedge based on the UI), and they all split apart and navigated
their own way to the destination."*

What was found and built is in `doctrine.md` *A plain move travels AS a formation*: the scatter was the design of the
plain move (one shape on the click, every crew by its own route, the round-7 flow gated on a leader-at-the-front that
round 10's seating made rare), and the shape he was looking for was not the one being formed (the AUTO icon shows a
wedge; the doctrine picks a column on the maps he plays, which classify as dense). A travelling anchor now carries the
squad's shape along the route. He asked *"go ahead to build"* after the diagnosis, adding: *"The game felt right, but I
was also playing with The Law."* His verdict on the build, the same evening: *"ok commit your changes, this is now really
good."*

**Music and announcer** (parked at his request until the formation work landed): *"I hear 'they are trading, they are
trading in the middle of the floor' quite often — do we not have enough random phrases that accomplish the same
filler? And do we have a wide selection of music tracks? I can't tell if it's playing the same music over and over on
opening — if there are comparable moods across tracks (which there should be, I did a few variations), it would be good
if we can randomize the selection."*

### Round 12 becomes a round (2026-09-26, later the same day; the lead asks for workspaces)

Shown the list of pending items (roadmap items 1–11, the fall-in rule, the Locks question, the housekeeping), the lead:

> *"ok that all looks good but note that some of it might be stale. I believe direct path doesn't scatter of the last
> fix. Another note: I believe I'd approved a render for a fire truck for the condemned and I haven't seen that
> materialize yet. Can you set up our workspaces to orchestrated workloads for all these items?"*

**What the record shows on both notes (the orchestrator, checked before briefing):**

- **The fire truck: he is right, and the approval was lost between the page and the repo.** The fleet review page
  (https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS, `db` declared) holds taps at **2026-09-24 17:27 UTC**:
  **`burner_r11_b` APPROVED** (the turntable-ladder fire engine: the flamethrower rides the ladder's turntable),
  `burner_r11_a` and `_c` rejected; **`bus_r11_i` APPROVED** (bus b's look at part of a coach's length), `bus_r11_h`
  rejected; and **`q_r11_bus_fit` APPROVED** (regenerate the van-shaped bus b as a long, narrow coach). The round-11
  fleet stream's last read of the page was at 16:00 UTC and the round closed the same day, so `assets/review/review.json`
  still says `waiting` for all six, `make art-apply-decisions` was never run on them, and **no image-to-3D was ever
  requested for the fire engine.** The taps are dumped verbatim in `_agents/streams/references/round12/fleet_page_db/`.
  Lesson: a review page's database is read at the round's CLOSE, not only when the worker last looked (orchestration.md
  lesson 220). Meshy balance is **809 credits** (`assets/meshy_ledger.md`, 2026-09-24), not the 88 an old HANDOFF line
  still says.
- **The direct path: he is right for the selections he makes.** Round 8 puts every spawned squad on a number key
  (`ControlGroups`, `groups.save(number, roster)` at spawn), and `RtsControls._is_task()` routes any move whose
  selection is a whole element or a whole control group down the TASK path — which is where the travelling anchor
  lives. So a box-select that happens to be a whole squad travels as a formation. The direct path
  (`Orders._resolve_group`, one route per vehicle) is reached only by a PARTIAL squad, a mixed selection, or a
  shift-queued order. Round 12 verifies that on the default path and decides whether a partial selection deserves the
  anchor too; it is no longer listed as "still scatters".

### Round 12: the lead's verdicts as they land

**Camera (2026-09-26 evening, the camera page https://claude.ai/artifact/We5PxYjNqXZDqXmuoNurxp; `db` doc
`answers/camera` read back at 06:00 UTC 2026-09-27: `lamp: keep`, `screen: nocut`, `left: leave`, no note).** His
words, as he sent them to the orchestrator:

> *"Camera: drawn solids, my answers*
> *- 1 · The camera in a floodlight's lamp head: Keep it*
> *- 2 · An ad screen between you and the fight: Don't cut screens*
> *- 3 · What I left standing: floodlight masts and signs: Leave them standing"*

What each means in the code (`_agents/streams/archive/round12/camera.md`): **1** the camera's placement asks the DRAWN extents
(`RtsCamera.seen()`), so it rises out of a floodlight's lamp head at a low tilt (kept); **2** `BlockCutaway` does NOT
hide ad screens, and `BlockCutaway.DRAWN_CUT` is empty, so the cutaway takes building-height colliders only, as before
round 12 (the screens are the show; they stay drawn); **3** floodlight masts and signs are not cut either (never were).
Confirmed by the camera stream against its own page's labels (`db` version 3).

**The Condemned tank (the prison bus), on the fleet page's `bus_r12_mv` card (2026-09-27), his words verbatim:**

> *"I don't understand what this URL is asking from me? The firetruck looks great, I don't know why it's giving me the
> condemned tank for approval. There was nothing wrong with the tank"*

**Ruling from that:** the fire engine is approved as shipped; **the Condemned `tank` keeps its current look** (the
dozer at 2.90 × 4.08 × 9.70) and the bus item is CLOSED. `bus_r12_mv` is rejected with these words; no further bus
concept or 3D unless he raises it. The earlier approvals (`bus_r10_b`, `bus_r11_i`, `q_r11_bus_fit`) stand as history:
he approved a look, the tool could not deliver its proportions, and he does not want the slot chased. Lesson for pages:
a card must say in one line WHY it exists and what "approve" costs; this one read as "approve the tank" to him.

**The booth's 67 new lines, on audio's veto page (2026-09-27): ALL 67 KEPT** (the page's `verdicts` collection,
dumped to `streams/references/round12/audio_veto_db/`). His words, verbatim:

> *"ok I finished approving the announcers, those are great - with all the new voice overs for the 2 male announcers it
> makes me feel like there's more good content that can be created for the female announcer"*

**Direction from that:** the female announcer — the PA voice (`pa`, 226 lines against the caller's 521 and the
Veteran's 439; round 12 added 49 caller and 18 color lines and **zero** PA lines) — gets her own deepening: more
content in her register, under the standing humour direction, generated under C12.7, on a veto page. Routed to audio
as item M6 the same night.

**The PA's 49 new lines, on audio's second veto page (2026-09-27): 39 KEPT, 10 VETOED** (`streams/references/round12/
audio_pa_veto_db/`). Vetoed: `pa.kill.14, .15, .16, .17, .19, .26, .31`, `pa.signoff.15, .19, .22`. **An observation
from the taps, labelled as the orchestrator's reading and not his words:** the ten he cut are the ones where the joke
lands on the crews' or the fans' bodies and homes (a cell reassigned for tomorrow's arrivals, power cut to a crew's home
block, a hearing check, the medical team's rounds, younger fans' district selection); what he kept is the venue's
corporate deadpan about itself. Worth carrying into the next batch's brief as a boundary to test, not a rule.

**Arena's water page (2026-09-27), answered in chat:** *"ok there's a bunch of review feedback on that URL. Everything looks
good, can we just get things wrapped up?"* — the wet look is APPROVED as shipped (every step kept); the pits stand; **the
Locks' open canal stays open** (the orchestrator's 2026-09-24 ruling, now with his "everything looks good" over it; re-ask
only if he raises it after driving it). His taps on the page did not reach its `decisions` collection (empty when read
twice; the page's save path is `db.doc("decisions/"+id).set`), so the chat words are the record.

## Round 13 direction: the lead's answers to round 12's candidate list (2026-09-27)

Shown the eight candidates at round 12's close, the lead:

> *"ok I feel like we can resolve some of these issues now. For some of these I need clarification on what you're asking
> but here are my known answers: 1. I need clarification. 2. Default wedge. 3. I don't understand the question. 4. leave
> 5. 29 MB of music is fine. 6. Yes let's add garage music, but I've never even smoke tested the garage. 7. ok 8. don't
> worry about this"*

Read against the list he was shown (`roadmap.md` *Round 13 candidates*):

1. **Right-of-way sized for long hulls** — clarification owed (below); started as nav's item on the orchestrator's
   recommendation, his veto stands.
2. **The default plain-move shape is the WEDGE.** Squad's measurement (wedge faster in 23 of 32 paired runs, column
   only better through the yard's chokepoint) becomes the rule: a plain move forms a wedge by default; the doctrine
   tables' `dense → column` row survives only where squad shows it still wins on the same seeds.
3. **Squad's S6 candidate** — clarification owed (below); measured, not assumed.
4. **A partial or mixed selection stays as it is** (round 10's R1 design). Closed.
5. **The web music pack at 29 MB is fine.** Closed.
6. **Garage music: yes.** And: *"I've never even smoke tested the garage"* — so the garage gets a player's smoke test from
   the title before its music, and whatever that finds is the item.
7. The next PA batch carries the boundary from his vetoes. Acknowledged; not scheduled until he asks for more lines.
8. Key rotation after the incident: *"don't worry about this."* Closed.

**The two clarifications, as put to him:**
- **(1)** Nav's back-and-fill made the War Rig get through the Terminus streets far more often, but when a rig now
  GIVES WAY to another vehicle it backs up into a yield spot sized for a small hull (round 6's right-of-way), so its
  reverse-gear wall scrapes rose 57 %. The item is: teach the give-way rule the hull's length so a 14 m rig yields into
  room it fits in. Not a question about whether the rig should yield; a fix for how far.
- **(3)** After a squad arrives, wheeled scouts with fixed guns are told to face a direction even when nothing is in
  sight; a wheeled hull turns in place with a multi-point turn, which used to walk them off their slot (nav bounded
  that this round). Squad's candidate is to stop issuing the pointless face order when nothing is in sight, which may
  remove the turn altogether. The ask was only whether to measure it; it is measured now, in the same stream as (2).

**A correction to the squad brief (squad, 2026-09-26):** the brief said the yard and the Terminus both classify as
*dense*. `make tactics-terrain` shows only the yard's spawns are dense and the Terminus is *lanes*; and no squad the
lead fields uses the standard table — a squad uses its units' FACTION table, and the Condemned and Law catch-alls pick a
**column in any terrain**. So the question is "column vs wedge for a Condemned/Law plain move", measured that way.

**Squad's S4, decided (a):** a partial or mixed selection does scatter (plots in squad's Status), and the lead himself
withdrew transient elements on 2026-09-20 (R1 narrowed). **Open for the lead:** does a partial selection deserve the
travelling anchor, or is "Part of Squad N: press N" the answer? Recommended: leave it.

### Round 13: S6 decided (2026-09-27, evening, in chat)

Shown the question (an 8 s faster stop for the mixed squad against scouts that park as they arrived instead of
squaring up to their sector), the lead:

> *"ok go ahead and turn it on, but let's make sure it's documented in our codebase that this behavior can be toggled
> I might want to change it later"*

**S6 stays ON** (`TankBrain.IDLE_FACE_NO_PIVOT := true`, `game/ai/tank_brain.gd`; the comment above it says how to flip
it and what each setting looks like). Where to read it: `doctrine.md` *S6*, the archived brief
`streams/archive/round13/squad.md`, the frames in `streams/references/round13/squad/q2_*`. The flip is one line and no
test pins the value: `tests/test_tactics_idle_face.gd` sets it explicitly both ways.

### Round 14 direction, first item: the airship steers clear of the player's view (2026-09-27, evening, in chat)

> *"the other work item I want to add here is the airship - frequently when we're playing the airship flies right in
> front of the camera and disrupting the game. I had asked for this because it was better than making the airship
> transparent, and ensuring it was visible in the game. But can we take a different approach here and make the aircraft
> choose its flight path such that it doesn't go directly into the player's view? IN other words, instead of trying to
> work around the blocking visibility from the airship, can we just make the airship smarter and try to avoid blocking
> the player's field of view?"*

Read against what is on main: the airship's pilot (`airship_pilot.gd`, round 10 pass 2) chases a carrot that circles
wherever the fight is, and the CAMERA is what gives way — `RtsCamera.clear_pose` lifts the camera out of the hull's box
and the cutaway never touches the airship (his round-12 verdict: don't cut screens, leave the machinery standing). He
is asking for the opposite dependency: **the carrot, not the camera, avoids the player's view.** Transparency stays
refused; the airship stays visible and in the venue; what changes is where it chooses to fly. Not a design pillar
change; a round-14 item (`roadmap.md` *Round 14 candidates*, item 1).

### Round 14 direction, second item: two War Rigs turned invisible (2026-09-27, evening, in chat, while playing)

> *"ok there's also clearly a bug in the game (I'm playing now in case you need the recording). I have 2 war rigs for
> the game that turned invisible during gameplay"*

A defect, first in the airship brief's backlog (A0): it is about what is and is not visible in his view, the same
family as the airship item, and no fleet or camera stream runs. His recording is the evidence; the map and the moment
are asked for below the quote in `HANDOFF.md`. Candidates the worker must measure rather than assume: the cutaway
(`BlockCutaway`, buildings-only by his round-12 verdict — does it ever hide a vehicle?), the rig's own hull art
(`game/theme/` rig files: a mesh that stops drawing, a LOD, a visibility range), the airship's occlusion logic, or a
rig driven under something that hides it (a covered bridge, the Locks). Not to be fixed by guessing (lesson 219).

**Read from the recording (the orchestrator, 2026-09-27 23:30):** the lead did not know the map (*"dude I don't know
the name of the map - are you not able to just pull up the recording of the last game played?"*). The last match
recording is `build/recordings/2026-09-27T23-20-40-locks.jsonl` (the recorder's `latest.txt`): **the Locks, seed
76424, 23:20–23:24**, Gangs (13 War Rigs in element Guns) vs Law. Eleven rigs died; the two that survived —
`Green_Guns_7` and `Green_Guns_9` — are the two he lost sight of. He ordered them there himself: at tick 2734 (91 s)
Guns_9 → (87.9, 9.5), at tick 2858 (95 s) Guns_7 → (−94.0, 3.2); they arrived and sat at **(94.9, 13.6)** and
**(−91.5, 12.9)** for the last 40 s, `arrived`, full health. Those are the approaches of the two swing bridges
(chokepoint regions at (±92, 0); the arena's own note: *"the bridges are the covered way round, behind the
warehouses"*). **Hypothesis, labelled as one (lesson 219):** each rig is standing under a covered bridge (or behind a
warehouse) and the cutaway leaves roofs standing by his round-12 verdict ("cut nothing but buildings"), so a friendly
unit under cover is hidden from him. The measurement that kills it: rebuild the Locks at seed 76424, drive a rig to
(94.9, 13.6), look from his pose. If it holds, the fix is a design call for him: does the cutaway open a roof (bridge,
canopy) when a friendly unit is under it, the way it opens a building? Recommended: yes, for the player's own units.

**The lead's correction (2026-09-27, 23:35), which KILLS the roof hypothesis above:**

> *"no, the trucks just became completely invisible when I was moving them around. Their graphic was gone and instead
> it was just a blue circle"*

So: the selection ring (the blue circle) was drawn where the rig was; the rig's own art was not; it happened WHILE
they were being driven under his orders, not parked. A rendering defect in the rig's art or in something that hides
meshes (culling by a wrong AABB, the cutaway hiding a mesh instance, the theme's own-hull-art swap, a visibility flip),
not the map. The recording still gives the worker the exact match (the Locks, seed 76424) and the orders he gave the
two rigs (Guns_9: five single-unit moves between ticks 2176 and 2734; Guns_7: one at 2858) to replay against.

**MECHANISM FOUND (airship, 2026-09-28 early, measured on builder0 by replaying his recording):** the two rigs
**spawned inside the city block at (−30, 42)** — his recording's tick-0 census has `Green_Guns_7` at (−39.5, 57) and
`Green_Guns_9` at (−35, 57), inside the block (x −50…−10, z 22…62), with several Hunters. On tick 2 the engine's
depenetration pushed each buried hull out the shortest way: DOWN, 6.24 m under the floor (replay: Guns_9 y = −6.241
from tick 3 to the end; every other rig y ≤ 0.002), and the floating motion mode never brings it back — so it drove the
whole match under the ground, art hidden by the opaque floor, the selection ring drawn on top: *"just a blue circle"*.
Why: `ArmyLayout.deploy` promises every slot standable ground via `SlotGround.standable`, which returns the point
UNCHANGED when the nav map is not ready and tests only the centre; 13 × 14 m rigs overflow the Locks' 32 m-deep Green
zone forward into the block. Fix: `_clear_spot` rejects a spot whose hull footprint overlaps an obstacle box (airship,
under a carve-out into `game/tactics/army_layout.gd`), a regression test on the Locks at seed 76424, and a logged
safety net (a hull 0.5 m below the floor after settle is a defect). It was never the rigs' art, nor the roof, nor the
canal rim: the third hypothesis in a row died to a measurement (lesson 219 again).

### Round 14: the view-climb decided (2026-09-28, in chat)

Shown what the view-climb does (the flight treats the wedge in front of the camera lens as one more thing to climb over),
what it buys (hides the fight about half as often on fresh seeds; the longest intrusion from ~20 s to ~6 s) and what it
costs (the airship in his frame about half as often), the lead:

> *"ah ok that's a great idea, turn that on by default"*

**The view-climb is ON by default** (`AirshipFlight.view_climb := true`, `game/theme/arena_kit/airship/airship_flight.gd`,
the comment above it names both settings; `AIRSHIP_OFF=viewclimb` on any launch restores round 13's flight). The
steering term (`viewsteer`) stays OFF: it measured no help live. Sim baseline unaffected (the airship is dressing).

## Round 15 direction (2026-10-01, in chat)

Asked whether a list of next items existed and shown round 14's candidates, the lead:

> *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for the night.
> You can assume that we want to reset our environment across the board"*

Read: no playtest list this time — the game feels good; round 15 is built from round 14's Status reports
(`roadmap.md` *Round 15 candidates*); an overnight round (memory: *overnight autonomy* — every agent working, decide
rather than block, validated work by morning); "reset across the board" = the round-14 sessions closed, fresh worktrees
and fresh briefs for every stream.

### Round 15: the gangs' table, decided on the page (2026-10-02, 09:09:44 UTC, a tap)

Squad's decision page (https://claude.ai/artifact/TjdypH5KxNgdmwQfSea176) put four arms in front of him — the table as
shipped (encircle off, bait on), encircle on, bait off, both flipped — with 16 paired fights per opponent on two maps
and the recommendation to keep the table. **His tap: "As shipped"** (no words; `db` `decisions/choice`, read by squad
at 03:28 PDT). The gangs' table is unchanged. Round 14's one-seed flips were noise. The two drill DEFECTS squad found
on the way (the far-ambush turn-in that flipped every 1.5 s; the bait runner that never came home) are fixed as
mechanisms, not balance, and are on main.

### Round 15: the IFV concepts, decided on the page (2026-10-02, 09:34 UTC, taps)

Fleet's review page (https://claude.ai/artifact/KDZKwAhyD1JNAnySsfwMeh) put five IFV concepts in front of him with each
card's first line saying what APPROVE costs (~15 credits, replaces that faction's IFV). **His taps: APPROVED `ifv_r15_a`
(the crash-tender wedge, the Condemned IFV) and `law_ifv_r15_a` (the tracked police APC, the Law IFV); the other three
rejected; no words.** Read by fleet at 09:59 UTC; the `db` dump is in `streams/references/round15/fleet/page_db`. The
paid image-to-3D (~30 credits) follows his taps (lead gate 1 satisfied); a hull-box change, if the new art needs one,
is a CP (declared, merged alone, the baseline recorded twice), never folded in.

### Round 15: the airship's "what gives way", decided on the page (2026-10-03, 01:55 UTC, a tap); Law's APC handling (in chat)

Airship's page (https://claude.ai/artifact/NzztKZUw66Du6n9DPRzv6X) asked *"When the airship's path crosses your
camera, what should give way?"* with four options. **His tap: C** — the airship climbs against where the camera RESTS
(the B1 fix, `viewrest` + `viewlow`) AND the camera stops lifting over the airship (the airship leaves the camera's
occluder group). Measured on fresh seeds 25–32: the hull hides the fight 0.00–0.08 % on four maps, no intrusion over
1.5 s, seen about half as often as round 13 (as now). Read by the orchestrator 2026-10-02 (`db` `decisions/airship_view`
{choice "C", note "", at 2026-10-03T01:55:56Z}). Airship's caveat stands: two rendered worst frames caught C in the
way after big camera moves (suspected builder0 edge-pan, unproven) — his playtest of C on the pit is the check.

And in chat, on fleet's open item (Law's new tracked APC still handling as 'wheels'):

> *"For the law's tracked APC if it is now a tracked vehicle it should behave as one."*

**Decided: `law_ifv` locomotion wheels → tracks.** A handling change in `game/units/units.gd` (fleet's carve-out), a
simulation change: pre-register the baseline by the path (is `law_ifv` in the 40 s baseline match?), attribute both
arms, a CP if it moves. Round 16's first items (`roadmap.md`).

## Round 16 direction: the game is choppy; find the efficiencies before touching the picture (2026-10-02, in chat)

The lead, opening the round:

> *"the game is getting extremely choppy, which might mean that we need to start deploying as a native app. But more
> importantly, it's likely that we just haven't done the work latley to optimize our code to just find basic
> efficiencies we can gain across the codebase - before sacrificing any of the existing graphics or gameplay let's find
> (or profile our code) where we can just get better performance out of our application"*

Asked where and when (three taps): **he plays `make skirmish` / `make garage` — the native Godot binary on this laptop
(Intel UHD 620)**, not the browser; **the chop is there from the first seconds and all match**, not growing and not
only in big fights; **default armies**. His latest recorded game is the Sumps at seed 92721, Law (24) against
the Condemned (27), 30 Hz, 124 s. So the round is a performance round with one rule from his words: **nothing in
the picture or the gameplay is cut to buy frames** — the work is finding what the code wastes (per-frame and per-tick
work that need not happen, work done more often than it is used, allocations, O(n²) passes, redraws of what has not
changed), measured on his machine along his path. A native desktop app is not the lever: he is already native. The
web build is slower still and is not this round's question.

Two more items, the same evening:

> *"when I run make skirmish can we make the opponent actually randomized so I can get more varied gameplay? Also, the
> intro music is really cool but then it just stops when we start the initial game and it goes to a loading screen -
> is it possible to keep the music playing through that loading screen?"*

Read: (1) `make skirmish`'s faction menu opens with the enemy on `Units.DEFAULT_FACTION` and the CPU army on `cpu`
every time; he wants the opponent (faction and army) to vary between launches unless he picks one. (2) The title's
music is cut when the title hands over to the match (the tree reloads under `GameLauncher.start`, and the director is
a child of `main`); he wants the opening track to carry through the loading screen into the match's own opening.

A third item, the same evening, on the booth:

> *"I had given feedback before about the announcers. The announcers absolutely make the game. But I believe we have
> different sets of possible statements based on actions in the game. I feel like there are cases where the set of
> things to choose from for an announcer to say must be minimal, because I keep hearing a lot of the same statements
> across gameplay"*

Read: repeats ACROSS matches for some moments; his model of the library (pools per action, some thin) is the design.
The round's booth stream measures the effective pool at each pick over his matches, fixes the free half first (memory
across launches), writes lines for the thin pools in the established voice and puts them through his veto page before
any generation (lead gate 1). Standing taste (memory): satire subtle and believable, never punchlines; the caller is
authentic UFC hype.

### Round 16: the announcer lines, approved in chat (2026-10-02, late evening)

Booth's veto page (https://claude.ai/artifact/QYrMFqKyrMZM1hAvzzadNR) put 62 drafted lines in front of him — the caller's
streak, flurry, "another one", the cut-in, streak stat, final kill and upset pools, and four PA results toward the venue;
74 recordings, ~5 374 ElevenLabs credits if all approved. His answer came in chat, not on the page:

> *"for whichever agent was waiting my approval on the web UI, I approved all the proposed announcements"*

**Decided: all 62 lines approved; lead gate 1 satisfied; generation goes ahead on the ledger.** The chat words are the
record whether or not his taps reached the page's `db` (round 12's rule, lesson 222); booth reads the `db` once more and
records the time.

### Round 16: the random opponent never mirrors (the orchestrator's call, 2026-10-02, late)

Play's P3 opens `make skirmish`'s faction menu on RANDOM for the enemy, rolled from the launch seed, and asked whether
Random should ever deal a mirror match. Decided by the orchestrator under his words (*"so I can get more varied
gameplay"*): **Random draws from the three factions that are not the player's**; a mirror match is the least varied
opponent and undoes the faction read (two Law armies). `ENEMY_FACTION=` (or a tap on the menu) still pins any faction,
his own included. His veto is one line at the code site.

### Round 16: the transparent effects' draw order, defined (the orchestrator's call under C16.1, 2026-10-03)

Render's pixel-parity work found that round 15 never defined the draw order of SIX transparent effect systems — bursts,
decals, beams, tracers, order marks, heat haze — which share one world-sized bounding box and so sort at an exact depth
tie settled by an unstable sort: any change to the render list, by any stream, flipped the fireballs between brighter
and paler (round 15's changed pixels are redder: an additive contribution, not the haze's dimming). No single explicit
pin reproduces round 15's frames (render probed every one against the real frames, 40 pairs each), so "round 15's
picture" at that tie is not a state. **Decided: all six are pinned explicitly, once, back to front — ground decals, order
marks, heat haze, beams and tracers, bursts — so the fire is never covered and the order can never flip again**; asserted
by a test; the priorities named at one code site. The 5–7 staged-frame pairs that differ from round 15 by 1–2.4 % are
recorded as "round 15's undefined tie, now defined". The only thing he may notice: explosions never dimmed by haze.

### Round 16: two HUD defects decided (the orchestrator's call, 2026-10-03)

Hud found two defects while cutting the HUD's per-frame work and asked: (1) **every unit's health bar sat at a fixed
3.2 m** — `UnitBars._top_of` read the hull size as a Vector3 while the catalogue gives `[w, h, l]` — so the bar was
inside the 14 m War Rig and far above a scout; **fixed: 1.2 m over each hull's own top** (a visible change, a defect
fix). (2) **A hurt or selected friendly showed two health bars** a few pixels apart (the controls' round-3 `_draw_health`
beside `UnitBars`); **the duplicate is dropped** where UnitBars runs (kept under `--no-unit-bars`). Before/after crops at
his pose in `streams/references/round16/hud/`. Neither is a performance cut; both are repairs under C16.1.

Addendum (the duplicate bar, looked at in hud's crops): the controls' bar was drawn over EVERY selected unit, bright and
full width, so dropping it also took the bright bar off a healthy selection. **Decided: a selected unit keeps a bright bar**
— UnitBars draws selected units at full alpha, at its own width and place — because the selection reading its own health
at a glance was round 3's legibility design and he plays by it.

### Round 16: the render levers, decided on the page (2026-10-03, 07:07–07:09 UTC, taps and words)

Render's page (https://claude.ai/artifact/PMFmmgGgQJ5QdfS5jh9pDG) put seven priced picture-changing GPU levers in front of
him, all OFF. **His taps: ON `scale_075` (−3.48 ms at his window), `lights_2` (−0.62), `no_env_fog` (−1.05), `no_haze`
(−0.46), `crowd_medium` (−0.31); OFF `unlit_stands`; `scale_085` untapped** (superseded by 0.75). Together ≈ 5.9 ms of the
~6 the 10 ms GPU budget needed at his window. His words on the render scale, verbatim:

> *"Note that we are testing development here on a crummy laptop (to catch these very cases). We should still have the
> option to keep scale at 1.0 on better gaming setups"*

**Read and decided (the orchestrator): the five levers become a RENDER PRESET, not the default for everyone.** Two presets,
`laptop` (the five levers ON) and `desktop` (none: scale 1.0, environment fog, haze, four pooled lights, the full crowd);
the default is chosen once by the video adapter type (an integrated GPU → `laptop`, a discrete one → `desktop`), overridable
by `--render-preset=laptop|desktop`, persisted in the settings, and switchable by hand in the HUD beside the QUALITY 30 /
PERFORMANCE 60 toggle. Parity shots of both paths; the GPU ms of each at his window. `unlit_stands` stays off everywhere.

## Round 17 direction: containers that look placed by people, and guns you feel (2026-10-03, in chat)

The lead, after round 16's playtest (two items "about the game in general"):

> *"1. For all of the containers that we have on our maps, in all cases they are completely aligned and completely
> orthogonal, and it looks completely synthetic as a result. Containers stacked on top of each other are done so
> perfectly. For all cases of containers on maps, I think we should rotate them just slightly so that it doesn't look
> synthetic."*

> *"2. the sound effects for all the gunfire and possibly explosions are lacking - when we're talking about tanks and
> fighting vehicles we want to assume that if a game player played this game in their living room with a great sound
> system, they'd really feel the action. I've heard AH-64 Apaches, Bradley fighting vehicles, and Abrams tanks all
> firing and in all cases it is awe-inspiring booms. I would expect our tanks to sound more like an Abrams tank round
> going off (those are of course unbearably loud, but we at least want to convey the raw power and kinetic energy from
> these weapons). I mention the Apache and the Bradley because I would expect our IVF's to sound more like this. And
> similarly, our scouts with their light machine gun fire should also have powerful machine gun sound effects. This is
> all heavy mechanized fighting vehicles and the sound effects should reflect that."*

Read (the orchestrator; both are subjective, so **his eye and his ear are the only checks that count**):

**Containers.** "All cases" means every map and every stack, not one yard. The references he has in his head are real
ports and motor pools, where nothing is square to anything. What the tree holds today (`6adf94bb`, counted from
`arenas/*.json`): **668 containers in 15 layout files (dry twins counted); 448 at exactly 0° and 172 at exactly 90° (93 % square to the
grid)**; only the Boneyard is fully off-grid and the Pit partly. 492 of them are stacks of two or more. `container_prop.gd` already jitters a stack,
but only the levels above the ground and only by **±0.6° and ±4 cm** — nobody can see that from his camera (a 12 m box
turned 0.6° moves its corner 6 cm), and the ground level is never turned at all. So two amounts are wrong, not one
feature missing: the ground placement (layout data, `tools/make_arenas.py`) and the per-level stack offset (the visual).
The design question a worker must settle and record: **a layout `rotation_deg` turns the collider with the picture**
(the sim baseline, the cover tables and the lane validators move, on purpose, once), while **a visual-only yaw leaves
the truth square** and a shell then meets the picture up to ~0.3 m from where it is drawn at the corner of a 40-footer
turned 3°. The orchestrator's lean: the ground level turns for real (truth and picture agree, a few degrees, seeded
per container, both halves of a mirrored map turned as mirrors so fairness holds), the upper levels get a visible
visual offset and yaw inside the footprint the collider already has. "Just slightly" is his phrase: rows still read as
rows; a wall of containers stays a wall (no new gaps a hull or a sightline fits through that the square wall did not have).

**Guns.** The standard is his own ears on the real things (an Abrams' 120 mm, a Bradley's 25 mm Bushmaster, an
Apache's 30 mm chain gun), heard on **a great living-room sound system**, which is a different target from every
earlier audio round (round 3 tuned for phone speakers: *"the heavy sounds carry most of their energy above 200 Hz"*;
round 4/5 for a laptop). Cinematic exaggeration is still the pillar (*Audio: cinematic, and alive*, above): the aim is
**raw power and kinetic energy**, not documentary loudness. Mapping from his words: **tanks → an Abrams main gun; IFVs
(the 25 mm autocannon family) → a Bradley / an Apache's chain gun; scouts' machine guns → heavy, powerful machine-gun
fire; explosions "possibly"**. What the tree ships today (measured from `assets/audio/layered/*.wav` at `6adf94bb`, on
the laptop; a file measurement, not a listening test): every weapon sound is **mono**, 44.1 kHz; the tank's shot has
**77–91 % of its energy below 200 Hz and under 1 % above 2 kHz** (takes 1 and 2) — a soft thud with no crack and no pressure front, where a
real main gun is a supersonic crack, then the body, then a long tail rolling off the terrain; the 25 mm is the same
shape (85 % below 200 Hz, 3 % above 2 kHz) at −6 dB in the mix; a machine-gun round sits at **−13 dB**; the whole World
bus is trimmed −6 dB under a −1 dB limiter, and every sound falls off with inverse distance from a camera that is
never close. So the suspects are in three places and a worker must separate them by ear-level evidence, not assume the
samples: **the source material** (no transient, no width, no tail), **the mix** (levels, the limiter, ducking under the
booth and the music, distance fall-off and its low-pass), and **the playback format** (mono sources, no deliberate
low-frequency layer for a subwoofer). New ElevenLabs sound-effect generation is lead gate 1 (the ledger in
`assets/audio/elevenlabs/ledger.md`; production quality over credits, he limits scope not spend); the shape that has
worked for assets is **two or three directions per weapon on a page he can listen to and tap**, before a batch.

**Added the same day, as the round was being briefed (the lead, in chat):**

> *"also, we have sound effects for guns firing, I don't know if we also should have sound effects for rounds landing
> (i.e. different sounds for a round hitting the ground or a building versus making a direct hit on a vehicle versus
> hitting the plasma shield versus destroying a vehicle). In general we want good sound effects, and I don't think we've
> invested effort into that. There miht also be other sound effects I'm not thinking of, but we have Elevenlabs credits
> to burn so we should use them"*

Read: three things. **(1) Where a round lands should be audible as what it hit** — ground, a building, a vehicle, a
shield, a kill. What exists (`game/theme/fx/weapon_fx.gd` `FAMILIES`, `6adf94bb`): an impact is chosen by the weapon's
fire model and by hit-or-miss only. A tank shell or a mortar round that misses plays `dirt_impact` whatever it struck (a
container, a tower block, water, dirt); **a 25 mm burst or a machine-gun stream that misses plays nothing at all**; a hit
on a vehicle plays `shell_hit_armor` / `bullet_hit_metal`, the weak spot its own, the shield `shield_hit` /
`shield_down`, a kill `explosion_big`. So the vehicle, shield and kill cases exist (and fall under "lacking"), and **the
surface is not known to the sound at all**. **(2) A full audit**: *"other sound effects I'm not thinking of"* — the
stream lists every event in a match that happens in silence or borrows another event's sound, ranked by how often he
would hear it, and fills the list from the top. **(3) Spend is authorised: *"we have Elevenlabs credits to burn so we
should use them"*.** For sound effects this round, lead gate 1 is answered in advance: generate on the ledger without
waiting for a tap, at production quality, as many takes as the sound needs. What stays his is the result — the
audition page is where he hears it and says which direction is right — and the gate stands unchanged for everything
else (announcer text, Meshy).

## Round 17: the browser build decided (the lead's five taps on ship's page, 2026-10-03, 14:11–14:16 PDT)

Read from the page's `db` by the orchestrator at 14:16:41 PDT (`streams/references/round17/ship_w2_choices_db.json`);
no notes on any of the five. What a browser player gets, by his choice:

- **The announcers reach the browser one line at a time** (`voice` = D): each clip is fetched the first time it is
  said and kept; nothing is added before the title; a line whose clip is late stays a subtitle. Hostable on GitHub
  Pages; on itch.io the clips would have to be bundled.
- **The browser's voice is 24 kbit/s, 22 kHz** (`bitrate` = 24k): the smallest of the four he heard that he accepted.
  The desktop build keeps the clips as recorded.
- **The Gangs, the Law and the Syndicate look like themselves in the browser, from a second pack fetched after the
  title** (`factions` = later): 21.3 MB, fetched once; a faction picked before it lands is drawn as the Condemned for
  that match. The main pack stays the largest single file, under the 100 MB a file GitHub Pages allows.
- **The desktop build's voice sits in a folder beside the program, as recorded** (`desktop` = beside; +80 MB).
- ~~**The browser plays sound through the game's own mixer** (`mix` = stream)~~ **SET ASIDE the same afternoon (14:47 PDT):
  the number he tapped on was wrong.** Guns' "no dropouts in Stream" run had served Sample to both arms (a server the
  script failed to kill kept the port). Measured properly (laptop, headless Chrome on the real GPU, N=2 per arm, two
  different Stream exports agreeing): Stream plays ~40 % of audio blocks at ~10 fps — audibly broken — against 100 %
  for Sample. The orchestrator relayed the wrong number to him; a tap on a wrong price is not a decision. The web
  default stays Sample (every sound plays, with guns' bus-layout fix; no bus effects, so no limiter, ducks or
  sidechain in the browser) until Stream is re-priced against frame rate and he decides again on the corrected page.
  **Decided again, on the corrected page: `mix` = sample-duck (tapped 2026-10-03 16:59:33 PDT; read 17:48 PDT).** The
  browser keeps the engine's default sound mode, where every sound plays, and the game itself turns the battle down
  under the caller by the same depth as the native duck he chooses (guns' scripted duck), with a web-only Master trim
  for headroom. What he chose it over, as measured: Stream plays 6–7 % of the time at his army size in the browser
  (3.4–4.9 fps on the laptop), 50–74 % with a 300 ms buffer.

Facts the page established that outlive the decision: the announcer's clips were in no export at all, desktop
included; Cloudflare Pages cannot host the build (25 MiB a file); the web pack had carried 107 MB of our own
documentation screenshots; in the engine's default browser sound mode one runtime bus send silenced every sample, so
a browser player heard only the fight music (fixed by guns with a declared bus layout).

## Round 17: the containers decided — twice the turn (the lead's taps on yard's page, 2026-10-03, 18:11–18:12 PDT)

Read from the page's `db` by the orchestrator at 18:22 PDT (`streams/references/round17/yard_y5_taps_db.json`): eight
taps, every one **B** — the Yard, the Pit, the Terminus, the Crossing, the Sumps, the Locks, and the two close frames
(the Yard's stacks, the Pit's three-high wall). No notes. He did not tap the Terminus kerb stack's question, so the rule
that a container flush against a building stays parallel to it stands.

B is twice what round 17 first shipped: **±4.0° on a 40 ft box, ±6.4° on a 20 ft, upper stack levels offset up to
45 cm.** His *"just slightly"* meant more than the subtle amount at his camera pose (yard's own read of the frames was
the same: A is a few pixels of jog, B reads clearly and still looks placed by a crane). It is a second change of
fights on the dealt container maps (CP2), built to CP1's standard: walls stay walls, lanes and junctions guarded, the
long hulls' wall contacts counted again.

## Round 17: the audition's first verdicts (the lead, 2026-10-03, 14:21–14:22 PDT; read 18:22 PDT)

Seventeen keep/redo verdicts on guns' audition page (`streams/references/round17/guns_g4_verdicts_db.json`): **keep**
all eleven impact-by-surface sounds, the tyre skid and the burning wreck; **redo** the mortar round coming down, the
shield charging back up, the tank braking hard and the tank turning hard. No notes, and no family picks (tank, 25 mm,
machine gun, the kill, the booth, the music) yet. Guns generated two new directions for each redo; the game plays the
first tries until he picks. These verdicts sat unread for four hours: both the orchestrator's and guns' later reads
looked only at the `picks` collection (lesson 248).

## Round 17: the sound decided (the lead's sixteen picks on the audition page, 2026-10-03, 23:31–23:37 PDT)

*"ok I'm all done making audio selections"* (in chat, 23:37). Read from the page's `db` by the orchestrator at 23:37:55 PDT
(`streams/references/round17/guns_g4_picks_db.json`); the option ids are the page's, read back by guns before anything
is applied.

- **The guns:** the tank **A**, the scouts' machine gun **A**, a vehicle destroyed **A**, the twin machine gun, the
  missiles, the pulse cannon and the flamethrower **A** — the directions guns had shipped as defaults. **The IFV's
  25 mm: B, the Bradley burst** (each round cut from a generated four-round 25 mm burst), not the default.
- **The railgun: today's sound** — the one from before round 17. He prefers it to the new direction.
- **The mortar: today's sound for now, and a redo** — his note: *"Both of these sound lame and we should redo"*.
- **The four he had sent back:** the track skid **B**, the track squeal **C**, the incoming mortar round **B**, the
  shield charging back up **C** (the second tries).
- **The booth over the battle: MID** (−24 dB at 4:1; the caller about 17 dB over the fight). **The music: +4 dB in a
  match** (half its lost ground back; the title untouched).
- With the 13 "keep" verdicts of the afternoon (every impact by surface, the tyre skid, the burning wreck), the round's
  sound is decided except the mortar.

**The mortar, still open (2026-10-04, 00:00 PDT on the page; read 00:06):** the second tries were rejected too. His
note: *"These don't sound like mortars being fired, they sound like a mortar being loaded."* In chat: *"the sounds
still stink"*. Three designs rejected. Read: what he hears is the round going down the tube; what is missing is the
SHOT — the propellant charge firing, a single sharp deep blast with the tube's ring, nothing before it. The game keeps
today's mortar until a design passes his ear.

**The mortar decided (2026-10-04, 02:00 PDT):** on the third tries he picked **D, the light mortar's sharp bark** — the
propellant charge going off, nothing before it. Two earlier rounds were rejected (*"lame"*; *"they sound like a mortar
being loaded"*). With it the round's sound is decided in full: seventeen picks and thirteen keeps.


## Round 18 direction: a formation picker he can see, and maps with room to manoeuvre (2026-10-04, in chat, ~03:50 PDT)

He played another game after round 17's sound and containers landed. His verdict on the whole: *"It's getting quite
good."* Two items follow, in his words, verbatim. Neither is launched; both are round 18's first candidates
(`roadmap.md` *Round 18 candidates*, items A and B).

### A. The formation button: a picker, not a toggle

> *"There's a quick UX request I think we should have - trying to change the formation by way of toggling through button
> clicks takes too long and it's not apparent what the next formation is. I think we should instead have a widget that
> does a mouseover effect that shows the possible formations, and I think we had a mouseover effect on top of each
> formation still that shows the sleek visualization of what the formation does."*

**What the code does today (read at `c1cb2adb`, not played):**
- The play view's Formation button (key G) calls `RtsControls.cycle_formation()` (`game/control/rts_controls.gd:954`),
  which steps through `FORMATION_CYCLE = [AUTO, wedge, line, column, vee]`: five states, so up to four presses to reach
  one, and nothing shows which comes next. The button's glyph and label show only the current one
  (`CommandIcons.formation_readout`, `game/ui/selection_panel.gd:283`).
- Echelon left, echelon right and coil are not in the cycle at all; they exist in the formation geometry and in the
  tactical map's picker (`PICKER_FORMATIONS`, `game/ui/tactical_map.gd:777`).
- The "sleek visualization" he remembers is real and is in two places. The task buttons (attack-move, screen, support by
  fire, ambush) have the animated top-down loop in their tooltip (`TaskPreview`, round 7, built from the real planner).
  The tactical map has a formation picker whose cards are drawn from the real formation geometry with a plain-language
  line each (`CommandIcons.FORMATION_INFO`). **The play view's Formation button has neither**: its tooltip is a title
  and a line of text.

**What he asked for, read plainly:** hovering the Formation button opens a small panel of every formation he can pick,
each drawn as its shape; one click picks it; hovering a formation in that panel shows what it does, in the same style
as the task previews. The current choice is marked. G keeps working for keyboard play. Ours to decide and record:
whether AUTO sits in the panel as its own card (recommended: yes, first, showing the shape the doctrine is forming now),
whether the echelons and coil join the play view's set (recommended: yes, the picker has room and the geometry exists),
and direct keys per formation (the tactical map already has Z X C V B N).

### B. New maps: room to manoeuvre, chokepoints, and a centre a line abreast can be ambushed in

> *"As another work item, I think we need to have an agent get creative with some other map alternatives and ideas. We
> would basically experiment by just making creative maps and then playing them. The general feedback with the current
> set of maps is that a the navigable spaces are really low and they obstacles are sort of just making navigation hard.
> Part of the reason why we did this is for testing, but at this point the vehicles are pretty smart at moving around. I
> think the best maps will be ones where there is room for vehicles to maneuver, perhaps some chokepoints in the map,
> and opportunities to really use formations like screens and ambushes; I don't know what this means exactly relative to
> what we have, but basically with the narrow corridors that exist on all the maps currently I never get to just have
> vehicles move line abreast - which one that note, I think a generally good idea for a map would be a large open center
> that allows us to use these big formations, but then create the necessary cover such that any team using a line
> abreast formation could easily be ambushed from cover (i.e. a line abreast formation could get ambushed by another
> formation that was orthogonal)"*

**What the layouts measure (the six dealt maps, `arenas/*.json` at `c1cb2adb`; every map is 280 m square):**

| Map | Lanes | Lane width, narrowest / median / widest |
|---|---|---|
| yard | 7 | 26 / 28 / 30 m |
| pit | 4 | 12 / 30 / 30 m |
| terminus | 7 | 18 / 18 / 20 m |
| crossing | 2 | 14 / 14 / 14 m |
| sumps | 6 | 14 / 14 / 16 m |
| locks | 3 | 14 / 14 / 16 m |

A squad's default spacing is 12 m (`TacticsFormation.DEFAULT_SPACING`), so four vehicles line abreast need about 36 m
of frontage plus their hulls, and a wedge of four about 24 m. **No lane on any dealt map fits a line of four at its
own spacing**, and four of the six maps do not fit a line of two. He is right, and it is a property of the layouts, not
of the formations: `arenas.md` itself says of a lane that *"frontage is limited to the lane width, so a column or wedge
beats a line"*.

**The brief this becomes (the experiment is the method, in his words: make creative maps, then play them):**
- Several candidate maps, different in kind, each playable by him the day it exists. Rough and many beats polished and
  one. His play is the judge (C15.2); nothing joins the rotation except on his word.
- The first candidate is the one he described: a large open centre, wide enough for two or three squads line abreast,
  with cover along its edges placed so that a force crossing the centre in line shows its flank to anything waiting in
  that cover. The ambusher's formation is at right angles to the line's advance.
- The qualities he named, each of which should be measurable per map before he plays it: room to manoeuvre (the share
  of the map a line of four can drive through at its own spacing), chokepoints (few, deliberate, with a way round), and
  ground where a screen and an ambush each have a reason to exist.
- What is already known and must be carried: the round-9 verdict that cut boulevard and boneyard (`game_design.md`
  *The lead's arena verdict*); `arenas.md`'s rule that an objective needs at least two approaches that differ in
  exposure; the sim baseline covers one map (round 18 candidate 1), so a new map is invisible to it; a dealt map needs
  its announcer name recorded in the same commit (`arena.gd` `ROTATION`); the CPU's doctrine was tuned on corridor maps
  and its behaviour in open ground is unmeasured; open ground puts more vehicles in view at once, which is the laptop's
  expensive case ([[project-laptop-is-the-test-bed]]).

### His pick, and two standing rules it carries (2026-10-04, in chat, ~14:20 PDT)

The orchestrator first gave him the candidate list in the project's own shorthand. His answer, verbatim:

> *"ok you gave me a ton of candidates that are my call. I don't understand the questions"*

Re-asked as what he would notice when playing (units peek out of cover at a loaded gun and get hit, and fixing it
makes the CPU tougher; the game freezes for two or three seconds at the final kill; long vehicles scrape containers;
surround sound sends everything to the subwoofer and some events are silent; the browser version is too slow to play
and hosting often fails; cleanup he would not see), with a recommendation to add only the freeze. His answer,
verbatim:

> *"1. Yes make the CPU smarter, this would apply to all units. We want to make the computer opponents hard, but kind
> of like in Gears of War, our friendly players are just as smart, so it just makes the game better. Don't worry too
> much about the browser version right now, I don't want to sacrifice anything on our game to accomodate browser play"*

**What that decides:**

- **The peeking fix is in, for every unit on both sides** (`roadmap.md` candidate 6; round 18's `brains` stream, B1).
- **Standing rule: smart on both sides.** Hard computer opponents are wanted, and his own units are to be exactly as
  smart as the CPU's (his reference: Gears of War, where the friendly squad is as capable as the enemy). So a decision
  improvement that applies to every unit on both sides is not a difficulty question to bring to him: it ships on our
  evidence (a scenario, a ladder, a paired series in his frame). What remains his: anything that makes the two sides
  unequal (a CPU-only advantage or handicap, what a difficulty setting means), and balance values. This supersedes the
  note on candidate 6 that *"the difficulty side is his call"* and narrows round 17's C17.4 (*a lever is priced, never
  shipped on our call*) to levers that trade behaviour for cost.
- **Standing rule: the native game never bends for the browser.** No browser work in round 18 (candidates 7, 11 and
  12 held). When a feature of the game and the browser build conflict, the game wins and the browser build is what
  gives; nobody cuts or shrinks a native feature to keep a web target green.
- **Not answered by him, included on the orchestrator's recommendation:** the freeze at the final kill (candidate 8;
  the `finale` stream). He was told it would be included and that the other items wait. Candidates 3 (long hulls on
  the Sumps), 9 and 10 (the missing sounds; the subwoofer in 5.1) and the cleanup items were offered and not taken:
  held, except where one rides as a stream's stretch.
- **Supporting work he did not have to decide** (told to him as such): a baseline that sees every dealt map
  (candidate 1; `ship`), and the CPU's doctrine measured in open ground (`brains`, beside the maps).

**The lesson for whoever asks him next** (orchestration lesson 254): a question to the lead is written as what he
would see, hear or feel when playing, with one recommendation; candidate numbers, stream names and hashes are ours.

### Decided for him during round 18, while he was away (2026-10-04 evening → 2026-10-05; each reversible)

He answered nothing after ~14:20 PDT on the 4th. These were decided on his standing guidance (*broad strokes, Claude
decides*; *overnight autonomy*), and each is his to overrule:

- **The arena screens' live feed keeps glow.** Not visible from his camera (the screens are about 90×150 px and often
  show ads); no measurable frame cost on his laptop; it lets the shader warm-up drop its feed render, taking the
  cold loading screen from about 13 s to about 9 s. `--feed-glow=off` restores the old screens and warm-up exactly.
- **DEFEAT / VICTORY sits at 66 % of the screen height**, below the last explosion, during the end-of-match slow
  motion (it used to cover the kill).
- **The peeking rule is "never into a gun it knows is laid on it"** (`x18m`), not "only while the enemy reloads",
  which he was first described and which lost the squad fight.
- **Not decided, kept for him:** whether the computer runs squad leaders in his skirmish (what would let it ambush;
  about +20 % a tick on his laptop today; `roadmap.md` round 19 candidate 10); the slow motion's length (about 2 s);
  which candidate maps are dealt and whether `yard_open` replaces the Container Yard.

### His verdict on the six maps, and the dealing (2026-10-05 evening, in chat)

He played them from the page's commands and said: *"ok the maps are fine, but I only see one new map. Were the others
modified or something?"* (the candidates were hidden from the in-game picker by design), then *"just keep all of the
maps. Let's get things merged and closed out so I can clear context here and restart"*. Asked whether to spend about
11,300 ElevenLabs credits on the booth's recordings of their names (a dealt map must be nameable), he chose
**"Yes, record and deal all six now"**, and **"the Open Yard"** as the spoken name of the opened Container Yard.
Dealt in `da0bdef3`: the rotation is twelve maps; `yard_open` sits beside the Container Yard; actual spend 12,714
characters, 34,490 → 22,724 credits. The six Keeps on the maps page from 20:33 PDT the day before are moot.


## Round 19 direction: formations per squad, a two-squad move that scatters, the garage he imagines, and a scoreboard (2026-10-05, ~21:15 PDT, in chat)

He played two games on round 18's `main` (the twelve-map rotation, `da0bdef3`) and wrote one message. His words,
verbatim, in his order:

> *"ok some quick gameplay feedback (over the last 2 games). 1. It seems that I can't assign different formations to
> different squads. It looks like if I apply a formation to one squad, when I select another squad, that same formation
> was applied. 2. I just tried a simple movement where I selected 2 squads and right clicked a point on the map - the
> resultant indicator dots for all the units was all over the map, and a bunch of vehicles just basically ran off to
> the middle of the map.."*

> *"Otherwise, I've mostly been testing gameplay, but might as well offload workloads to agents - the garage as it
> stands is not what I envision - if this is already meant to satisfy my intent then the UX is no good. The way I
> imagine this game is that each player is given 1000 credits per game (and we might change this in the future so that
> as players advance they get more credits or something). Each vehicle has a cost, and they allocate so many credits to
> buy the units they want, and the player should be able to group squads however they want (we have max 5 I think?)
> That means that squads can get created with a mix of vehicles. This UX should be relatively simple, the beauty of
> this game is its simplicity. In the UI in the garage we also want chamfered borders and stuff, and I think we have
> enough content now where we have a theme to build off of."*

> *"On the gameplay note, I think we need more sense of a scoreboard. There's this notion of taking the center floor to
> win the game, but there's no obvious scoreboard to show how close someone is based on holding that positions -
> there's also no notion of a scoreboard tracking kills. The scoreboard is a chance to take advantage of our slightly
> satirical game (i.e. a ghastly kill is met with celebratory score increases in a manner that's consistent with
> watching a professional televised sports game)"*

### 1. Formations are per squad (read at `93ec68b4`, not played by the orchestrator)

**What the code does:** the chosen formation is ONE variable on the controller (`RtsControls.formation`,
`game/control/rts_controls.gd:128`), written by G (`cycle_formation`, `:955`) and by the picker (`set_formation`,
`:960`; `formation_picker.gd:144` calls only that and closes). No squad is told anything when he picks: *the next
order* carries it (`:652` task path, `:950` direct path), and every later move, attack-move or hold sent to ANY squad
carries it until he picks again. Selecting another squad never changes the variable, and the button and the picker's
marked card show the variable, not the selected squad's own shape (`selection_panel.gd:293`,
`command_icons.gd:411-418`: only AUTO reads the element's real state). So both of his sentences are true: squad 2
gets squad 1's formation on its next order, and the button says so before he orders. The squads already store their
own formation (`Element.formation`, `element.gd:45`; the task's `formation` key, `:477`), so the fix is to make the
picker a per-squad order, read back per selection. **His design, read plainly:** a formation belongs to the squad he
gave it to; picking one applies it to the selected squad at once (the tactical map's `apply_formation` already does
this, `tactical_map.gd:262`); selecting another squad shows that squad's formation; G cycles the selected squad's.

### 2. Two squads, one right-click: the dots everywhere and the run to the middle (read, not reproduced)

Two paths exist, and which one he hit depends on how he selected the two squads (`rts_controls.gd:620`, `_is_task`):

- **Two squads selected together** (1 then shift+2, or a box): the direct path (`:936-952`) disbands both squads,
  removes every unit from its element and issues one group order of ~10 units: rows of five around the click,
  seated by toughness tier before distance, so crews cross the whole group but the goals stay within about 60 m of
  the click. Bounded, but it throws away both squads and their formations to do it.
- **One control group that holds exactly both squads** (Ctrl+N over both, or an earlier task that formed them into
  one): the task path forms ONE element of ~10 vehicles (`Elements.form`, `elements.gd:80`, no size cap; the plan
  never passes `TacticsFormation.auto`, so a 10-vehicle wedge stays a wedge at the 14 m "open" spacing: about 126 m
  across and 70 m deep, centred on the click, on an arena 240 m wide) and starts the transit from the CENTROID of all
  members (`Element._advance_transit`, `element.gd:434`; stations laid around it, `element_plan.gd:291`). Two squads
  on opposite flanks have their centroid on the centre line, so every crew first drives to the middle of the map,
  and the final goals are spread across most of it. This matches both symptoms.

Neither is tested with two whole squads (`test_control_group_moves.gd` uses 8 bare units; `partial_probe.gd
--case=mixed` is two partial squads). The first job is to reproduce both cases headless and measure every unit's goal
against the click. **His design, read plainly:** two squads ordered together stay two squads, each in its own
formation, both arriving at the point he clicked, side by side; the dots show where each will stand; nothing drives
through the middle first.

### 3. The garage he imagines: 1000 credits a game, any mix, up to five squads, simple, in our theme

**What the code does:** the garage (`game/garage/`, `make garage`) already allows mixed squads and five squads (the
rules in `army_draft.gd`; `MAX_SQUADS = 5`, `MAX_SQUAD_SIZE = 5`), but almost nothing else matches his sentence:
the budget is not 1000 but a TIER bought with a persistent "credits" currency earned by winning (800, 1200, 1700,
2400, 3200: `progression.gd:19-25`); three of the six Condemned units are LOCKED behind that currency; only the
Condemned are offered (`army_catalog.gd:66-75`); and the screen carries a name field, presets, load, save, delete,
share, a credits button, a tip bar, a tier menu, an enemy menu and four overlays. The panels are rounded
(`garage_screen.gd:160`), not the chamfered frames the HUD and title use (`CyberFrame`, `CyberUiTheme`,
`GameTheme._cyber_panel_style`: the theme exists; the garage does not use it). And **1000 credits at today's prices
buys five tanks**: the army he plays in `make skirmish` is a faction army at 5,200 points (about 24–39 vehicles).

**His design, read plainly, and what the orchestrator decided under it (each reversible; he overrules any):**
- **1000 credits a game, for both sides.** The per-game spend is called credits and is 1000. Both sides buy at the
  same 1000 (his fairness guard from 2026-09-15 stands: *"matches are fought at a shared budget tier"*). The bought
  tiers are retired from the garage. "Players advance and get more credits" is his later layer: nothing built, the
  profile's earned total kept in the file for it.
- **1000 credits buys the army he plays today, not five tanks** (orchestrator's recommendation, put to him): prices
  are re-expressed so a faction army at 1000 credits is about the size a skirmish fields now, relative prices kept
  (C12.6: balance is his; a uniform rescale keeps it). If he prefers small armies, the garage stream has the lever.
- **Every vehicle is buyable from the first game.** The unlock ladder (300 / 600 / 1000 / 1500 credits for a unit)
  is retired from the garage: it contradicts "buy the units they want" and the simplicity he named. The pillar
  "unlocks add options, not power" stays true by construction (nothing is locked).
- **He picks a faction, then buys from its roster.** The garage offers all four factions, as skirmish does.
- **Squads: up to five, any mix, grouped how he likes**, with the plainest possible gesture (drag a bought vehicle
  into a squad, or tap a squad then tap vehicles). A squad's size cap is the largest the formations seat cleanly
  (today five; brains says what the geometry allows).
- **One screen, three questions**: which faction, which vehicles (the credits left always visible), which squads.
  Then FIGHT. Everything else (presets, codes, compare, challenges, the turntable) is either folded in quietly or
  dropped; the saved-army file format stays readable.
- **Chamfered frames from the existing kit, documented as a kit** so the scoreboard and later screens build on the
  same theme: that is what *"we have enough content now where we have a theme to build off of"* means to us.

### 4. The scoreboard: how close each side is, and kills, in the voice of a televised sport

**What the code does:** a match is won by holding the map's objective zones to 90 points (`CONTROL_POINTS_TO_WIN`;
each zone fills in 8 s, holding every zone scores 1 point a second, half for half of them) or by eliminating the
other army (`match.gd:508-569`). **Every dealt map in the rotation has TWO mirrored side zones, not one centre**
(`Arena.objectives_of`; e.g. the Terminus's "west ring" at (−75, −26) and its mirror): the "centre floor" he
remembers is the older arenas' single control point and the announcer's "we hold the center". **Nothing on the
desktop path shows the control score**: the one meter that draws it (`TacticalMap._draw_control_meter`) exists only
under `--touch-map`; the HUD's "Scoreboard" label shows units alive; a text warning fires once at 15 points to go.
Kills are counted (`stats["kills"]`, `kills_by_unit`, every kill worth 1, never toward winning a skirmish) and shown
nowhere in play except the arena screens' "live" card, which the live camera feed covers during a match. The
announcer already SAYS there is a board (`pa.control.02` "The scoreboard reflects the change", `caller.stat.08`
"Look at the board") and emits `line_started(cue)` for exactly this, unconnected.

**His design, read plainly, and what the orchestrator decided under it:**
- **A board he can read at a glance all match**: each side's progress to the win (the zones held, the points, how
  far from 90) and each side's kills, in the televised-sports register: a score bug like a broadcast's, team names
  by faction, the number that just changed celebrated the way a broadcast does (a flash, a tick-up, the caller's
  line), never a joke (his humour rule of 2026-09-15 stands: *"what makes satire funny is things blur the line
  between believable and non-believable"*).
- **A kill is worth what the victim cost** on the board (credits destroyed), beside the count. This is display:
  kills do not decide a match this round (a rules change is his: C18.4). The board stream puts the question to him
  with its recommendation.
- **The board says what the map scores.** On the twelve dealt maps that is two zones, named as the map names them;
  "centre" where a map has one. Whether he wants one central floor instead of two side rings is put to him as a
  question (it is a map design change, not the board's).
- **The arena screens join in**: the live card's score and a "ghastly kill" reaction on the giant screens are the
  stretch, after the HUD board.

### Round 19, after the launch: the board is first of all an INDICATOR that the rings score (2026-10-05, ~22:20 PDT, in chat)

> *"there's very little indication that holding the center is what scores points, or that standing in the ring scores
> points. Getting points for killing doesn't really matter much because ultimately one army eventually dies, but we at
> least need some sort of indicator - this is a matter of making the game more engaging to create the look and feel of
> a professional sporting event"*

**Read plainly, for board:** the first job is not a kill tally; it is making it OBVIOUS, while he plays, that standing
in a ring is what scores and that the score is moving: the ring itself must show it filling for whoever stands in it
(on the ground, on the radar, on the board), the board's meter must visibly tick while a side holds, and the moment a
ring starts scoring must be an event he cannot miss (the caller, the screens, the ring's light). Kills on the board
are secondary: one army dies anyway. The whole point is the look and feel of a professional sporting event. The
board brief's backlog is reordered under this (S2 is the indicator first; the kill tally rides on it).

## Round 20 direction: the garage, played (2026-10-06, morning, in chat)

He played round 19's main and said: *"ok this is much better."* Then, on the garage, verbatim:

> *"2 feedback items on the garage: We should incorporate the graphics of the vehicles we're adding to the squads, and
> I also wasn't able to spend my entire budget to get the 5 squads of 5 or max vehicle count. I assume this means we
> should change the cost or lower the credits. Basically a player should be able to max out their entire set of
> squads with nothing but scouts. This might also mean changing the assumptions our maximum allowable unit count"*

### 1. The vehicles are SEEN in the garage

**What the code does:** the round-19 garage shows a vehicle as a card of words (name, length, "×7 in the army", good
against) and a squad's vehicles as text chips; the old 3D turntable was dropped with the old screen. The real meshes
exist and `make vehicle-gallery` renders them. **His design, read plainly:** every card and every chip in a squad
carries a picture of the vehicle, so an army reads as vehicles, not names. **Decided:** pictures, not live 3D
viewports (a 3D view per chip is twenty-five viewports on his laptop and the phone): a thumbnail per unit per faction
rendered from the real mesh by a make target on builder0 and committed under `assets/`, in the kit's style (one
angle, the team's accent, transparent), with the live turntable back only on the single selected card if it is cheap.

### 2. An all-scout army spends exactly 1000 credits: 25 scouts

**What the code does:** 1 CR = 5 points for every faction (round 19, C19.2), so a faction's cheapest vehicle costs 14
(Gangs), 22 (Condemned), 28 (Law) or 42 (Syndicate) CR, and 25 of them cost 350 / 550 / 700 / 1050: three factions
cannot spend 1000 on a full army, and the Syndicate cannot fill one with scouts. **His rule, read plainly:** the
budget and the slots meet at the cheapest vehicle: five squads of five scouts is exactly 1000 credits; anything
dearer than a scout buys fewer vehicles. **Decided (reversible; his overrule stands):**
- **Prices are per faction: a faction's scout costs 40 CR**, and every other vehicle of that faction keeps its
  relative price (its points ÷ the scout's points × 40, rounded to the credit). `Units.cost` (points, balance, the
  baselines) does not change; the CPU opponent buys at the same 1000 with the same faction prices. The consequence
  he should know: at 1000 credits every faction's biggest army is 25 vehicles, so the Road Gangs are no longer "many
  cheap vehicles" by COUNT (their skirmish identity at 5,200 points stands untouched); a Gangs army at 1000 is 25
  scouts or about 10 War Rigs (100 CR).
- **The cap stays 25 (five squads of five)** this round: formations seat five, the HUD and the maps' lanes are tuned
  for armies of that size, and his sentence is satisfied exactly by the price rule. His remark about the maximum unit
  count is kept as the open question below; a bigger squad is a formation change first (brains).
- **The garage never leaves credits unspendable:** with scouts at 40 and 25 slots, 1000 is always spendable; the
  "your army is full" line survives for dearer mixes that end short of a slot.

**Open with him:** does he want MORE than 25 vehicles when the army is all scouts (bigger squads, say five of eight;
a formation and command change), or is 25 scouts for 1000 the right ceiling (recommended: yes, 25; a squad of five
is what a formation is).

### Round 20: the cap and the price anchor, decided (2026-10-06, in chat, minutes after the launch)

> *"for now we will assume that an all scout army for the road gangs is 25 vehicles, and all costs and counts can be
> based on that"*

**Read plainly, and it replaces the per-faction rule decided at the launch:** the Road Gangs' scout (70 points) is
the anchor: 25 of them is 1000 credits, so **one credit = 1.75 points for every faction** (the Gangs' scout 40 CR), and
every other price follows from its points at that one scale (Condemned scout 63, Law 80, Syndicate 120 CR; a Gangs War
Rig 100). The 25 cap (five squads of five) is the count everything is based on. The factions keep their identities
by COUNT at 1000 credits, as in skirmish: an all-scout army is 25 Gangs, about 15 Condemned, 12 Law, 8 Syndicate.
Rounding: to the credit; the garage shows the credit price; the simulation keeps points. If he meant every faction's
scouts to fill 25, that is the launch's per-faction rule and he says so.

### Round 20, afternoon: his attack order and the gangs' bait drill (2026-10-06, in chat, after playing CP1)

He played the price rule with 25 Rat Rods (foundry, seed 40047, `build/recordings/2026-10-06T14-59-04.jsonl`) and said:

> *"I just played a game where I used 25 scouts from the gang. I selected all units, selected a V formation, and
> then I commanded all units to attack a single vehicle. But instead of the anticipated action of the scouts
> attacking the vehicle, they all just spread out and drove away."*

**What the recording shows (the orchestrator, read at `ea322e9f`):** the attack went out as one order per squad
(round 19's rule). Alpha attack-moved straight in, arrived alone and lost five vehicles in ten seconds. Bravo to Echo
each selected the **bait** drill on sight of the enemy (`why: "one runs at them and leads them back onto the pack"`),
sent their fastest non-leader scout forward and HELD the other four 45 m back; the holding four then backed away
toward their own start line (centroids from 50 m out to over 100 m in twenty seconds) because a baiting pack
retreats to draw the chasers on, and the Law vehicles never chased. The bait scouts died one by one. The V formation
was applied as ordered. The drill is the gang behaviour he asked for on 2026-09-16 (a vehicle drawing fire back onto
the rest), built for the computer's packs; the doctrine table is per faction and the AI symmetric, so his own gang
squads run it under an attack order with a visible enemy 30–95 m away.

**His design, read plainly:** *the anticipated action of the scouts attacking the vehicle*: a squad he gives a direct
attack order to attacks. **Decided (reversible; his overrule stands):** under a player's attack with a named target
the gang's elective drills (bait, encircle) do not fire; a squad keeps them for the computer and, for the player, on
movement without a named target (an attack-move into the open), where "spreading wide" and "one draws them on" are
what he asked the gangs to feel like. Handed to brains as M1b (its paths: `game/tactics/**`).

### Round 20, close: what brains measured and decided (2026-10-06 evening; the orchestrator accepted both)

- **The computer's opening posture is built and OFF** (`--cpu-opening` switches it on). Brief's decision overturned on
  evidence: opening-series, builder0, 8 paired seeds: when he sets off at once neither arm ambushes (margin +2.6 ±
  4.3); when he waits 10 s on parade, round 19's posture already ambushes 8 of 8 and trades better than the opening
  (−2.4 ± 4.1 alive with it). On the Sumps the near ring has no site, so the arms are identical.
- **The computer's ambush hides its whole line, not one point** (M3, shipped). parade, 24 paired seeds: the ambush
  springs +2.20 s later (se 1.00), his loss +214 HP (se 100), CPU-minus-his alive +1.25 (se 0.80); eight seeds alone
  were inside the noise, twenty-four agree in one direction. No cost on maps with no site (the Open Yard: 8/8
  identical). Only runs with CPU squad leaders on, which is **still his decision** (3–5 ms a tick on his laptop).

### Round 20, evening: played again after the close (2026-10-06 ~18:40, foundry, seed 29989, 25 Rat Rods v the Syndicate)

> *"I just played again with 25 scouts, once again just trying to attack a target in formation. A lot of vehicles
> didn't actually drive toward the target they just circled around. I don't know if that was them trying to get in
> formation or what, but even when there was only one vehicle remaining it was still just driving in circles instead
> of actually moving to the target I designated"*

**The recording (`build/recordings/2026-10-06T18-38-40.jsonl`, main `6c03daad`), read by the orchestrator:**
1. **His first click was an attack-move, not a named target** (tick 474: `move`, drills on, spread to ±116 m again),
   and **the bait drill fired again** (tick 654: four `hold` + one forward in every squad but Alpha; Alpha went in
   alone and died). M1b only covers an `attack` with a named target: the orchestrator's scope was too narrow. **Decided
   for round 21: no bait/encircle under ANY player order** (attack-move included); the gangs' elective drills are the
   computer's.
2. **His named-target click worked** (tick 795, `attack Rust_Hunters_1`, "vee, as ordered"): every squad closed.
3. **The circling.** His last attack (tick 1827) named `Rust_Eyes_3`, a Syndicate spotter platform that was RETREATING
   from (−33, 6) to (15, −112) over the next 17 s. His survivors never closed: Bravo_1 drove east past the target's
   old position, turned and drove back west (an orbit ~40 m across); Delta_1, the last vehicle, "arrived" 70 m short of
   the target and sat, then crept. The element's attack plan is chasing a moving target by re-laying its vee stations
   around where the target is each replan, and a lone Rat Rod at 18 m/s overshoots a station and circles back to it
   (the yard IFV case from M1, at scale). Bravo_4 was also `blocked/terrain` once at x = −96 after the spread sent it to
   the wall. **Round 21, brains:** an attack on a named target that moves is a PURSUIT: stations relative to the
   target's velocity, the whole squad at road speed, no "arrived" until in weapon range (30 m for the spear); a single
   survivor drives straight at it. Scenario: five Rat Rods attack a spotter retreating at 8 m/s; assert monotone
   closing distance and no orbit (heading reversals) for any vehicle.

### Round 21: decided for him at the launch (the orchestrator, 2026-10-06 evening; each reversible)

His words for this round are the two sections above (*Round 20, afternoon* and *Round 20, evening*); he gave no new
direction between the close and the launch. Three decisions made for him, written as what he will notice:

1. **A squad never runs the gangs' bait or encircle under any order of his** (attack-move included), not only an
   attack on a named vehicle. The computer's packs keep every drill (brains P1). Reason: symmetric AI is the rule, and
   lesson 264 says a direct order wins; his two recordings show the drill under both order shapes.
2. **When he attacks a vehicle that runs, his squad chases it:** the squad follows where the target IS (or was last
   seen, carried forward by its speed), never stops short, and a single survivor drives straight at it (brains P2).
3. **Five squads ordered with one click go as a body, up to three abreast with the rest in a second rank**, instead of
   a 400 m row the arena's edge pins at ±116 m (orders O1). Two squads keep round 19's side-by-side.
4. **The airship should be seen on every map about as often as on the open ones today** (a glimpse every minute or
   two, 20–30 % of its flight in frame) and never over the ground he is looking at (airship V2). Asked in the launch
   message as a question in his terms; the stream builds the recommendation.

CPU squad leaders on by default stays his (asked again, recommended yes: the ambush and the hidden line only run with
them, at 3–5 ms a tick on his laptop).

### Round 21: his two answers, minutes after the launch (2026-10-06 evening, in chat)

> *"yes let's just go ahead and add the cpu leaders feature. I want the airship same as other maps."*

1. **CPU squad leaders ON by default** in his skirmish and the garage's fight (`ELEMENT_CPU_DEFAULT := true` in
   `game/modes/skirmish_mode.gd`, brains' one carve-out this round, C21.5; `--no-element-cpu` keeps the old path for
   A/B). Pending since round 18; the price he accepts is 3–5 ms a tick on his laptop (round 19's measurement).
2. **The airship on the built-up maps is seen as often as on the open ones** (24–31 % of its flight in his frame on
   parade, yard, gorge, archipelago at `0a9ce446`): that is airship V2's bar, not a recommendation any more.

### Round 21: the close (2026-10-07; what shipped against his words, and three overturns)

**Shipped on `main` (`main-checked` `d25d0579`, builder0, 2211/0, thirteen lines unmoved):** five squads ordered with one
click go as a body (at most three abreast, 200 m, ranks behind; the FRONT rank on his click); no bait, encircle or far
ambush under any order of his (the computer keeps them; return fire, near ambush and break contact stay as reflexes);
an attack on a vehicle that runs is a pursuit (live or last-known track, never "arrived" short, the last survivor
straight at it: time to kill −2 to −3 s, his loss −80 to −120 HP, reversals 94 → 3–16, two machines, n = 24 + 16 paired);
a drill's end no longer leaves a squad standing at a stale anchor (both sides); a slot pushed off a prop lands on the
side the squad reaches it from; the airship is built on foundry and every default-size map; the computer's squad
leaders run in every game (his answer).

**Overturned by measurement, each recorded by its stream (lesson 266):** the holding element falling back one bound
when losing (against on every measure, 8 paired seeds, two maps: OFF); low airship stations on the built-up maps
(reach the open maps' seen-share on three maps but hide the fight ~2× and for 5–12 s at a time; failed the
pre-registered confirmation seeds: OFF everywhere, the trade filed for him in `roadmap.md` *Round 22 candidates* 1);
and the orchestrator's own suggestion of a far airship pass (the frame's ceiling FALLS with distance at his pitch).

**Ruled by the orchestrator for him (reversible):** the front rank of a body stands ON his click, never past it (an
attack-move must not drive into contact he did not choose; round 19's "arrive at the point he clicked").

**For him to decide later:** the airship trade (candidate 1) and the Syndicate-over-gangs range gap (candidate 2).

## Round 22 direction: double the army, and a vehicle that sits and takes it (2026-10-07, ~13:00 PDT, in chat)

After playing round 21's main (*"I just played the game, it's great"*):

> *"Based on our earlier rule of maxing out at 25 scouts, the only feedback I have now is that the armies I can create
> with tanks are too small, so we need to figure that out. Maybe that means allowing more squads, you had said
> formations are based in groups of 5"*

Shown the table (1000 CR = 25 Gangs scouts / 10 Gangs tanks / 6 Law tanks / 3 Syndicate tanks) and the recommendation
(double it: ten squads, 50 vehicles, 2000 credits; measure 50-a-side in his frame on the laptop first and set the cap at
the biggest size that still plays smoothly, credits scaled to it; squads stay five, since every formation, drill and
test assumes five):

> *"yeah double it sounds good."*

> *"Also another piece of feedback: in my last play I had one of those laser vehicles from the condemned. It was
> shooting at a Syndicate vehicle at range, and the SYndicate vehicle just sat there and took it until it died. THat
> clearly looks like dumb CPU player"*

**Read from his recording (`build/recordings/2026-10-07T12-58-28.jsonl`, foundry, seed 73429, his Condemned v the
Syndicate, main `5beb038f`):** `Rust_Hunters_2`, a Limousine Gunship (pulse cannon), stood at (−6.7, 51.7) under a
`hold` order from its element (`src element`, phase `arrived`) from tick 1096 to its death at 1771, 22.5 s, and never
moved: 36 hits of 9–29 damage (a laser's chip damage) took it from shield 200 / hp 240 to dead. The same match's
`Rust_Eyes_1` (Skimmer) also died standing in a `hold` (ticks 976–1113, hp 150 → 29 → dead). The CPU's holding posture
(round 19's B2, now on his path since round 21's P0 turned its squad leaders on) keeps a crew on its post while it is
being shot by something it cannot answer (out of its range, or out of its sight). Round 21's hold fall-back (a losing
TRADE) was a different trigger and measured against; this one is *taking fire you cannot return*. Symmetric: his own
units under a hold do the same.

### Decided for him at the launch (the orchestrator, 2026-10-07; each reversible)

1. **The army doubles: ten squads of five, 50 vehicles, 2000 credits** (the Gangs' scout stays 40 CR, so 50 scouts =
   2000 exactly; the Law 25 scouts / 13 tanks; the Syndicate 16 scouts / 7 tanks). The final cap is set by the
   measurement of his frame on the laptop at 50 a side with the computer's squad leaders on; if 50 does not play
   smoothly at the laptop preset the cap drops to the largest that does and the credits scale with it (50 → 2000,
   40 → 1600, 30 → 1200). Control groups 1–9 and 0.
2. **A vehicle taking fire it cannot return does not sit on its post:** it closes to its own range, gets out of the
   line of fire, or falls back out of range, on both sides (brains; scenario from the recording; a paired series).
3. The airship trade (the Cut, the Docks, the Sumps) and the Syndicate-over-gangs range gap stay his, asked again in
   the launch message.

### Round 22, an hour after the launch: the airship trade is closed, and a choppy match measured (2026-10-07 ~14:00 PDT, in chat)

> *"ok whatever this new airship mode is doesn't seem good, now it's not even visible in the gameplay. Also in my last
> round, it was really choppy, I think our framerate performance has regressed"*

**The airship trade (round 22 candidate 1) is CLOSED: no.** He tried the flag on the Sumps (`2026-10-07T13-46-42-sumps`)
and did not see it; the stations stay OFF everywhere and the flag is not offered again. Nothing to build.

**The choppy match, read from his own frame log (`build/recordings/2026-10-07T13-46-42-sumps.perf`, kept under
`streams/references/round22/perf/his/`; main `5beb038f` + the airship flag; the Sumps, seed 5988, his Law 24 v the
Syndicate 17):** frame average 100–280 ms through the battle (4–10 fps), the sim at its 3-ticks-a-frame catch-up cap
and the game slowed to 0.35–0.6× real time; per frame the tick 25–63 ms (so ~15–20 ms a tick at 20–40 vehicles), the
UI 5–60 ms, the GPU 11–13 ms. **An hour earlier on foundry** (`12-57-13`, `12-58-28`, no flag, 9–13 vehicles) the same
build ran at 33 ms a frame (the 30 fps cap), tick 5–7 ms, UI 2.4 ms. So the regression is real and specific: the Sumps
with the computer's squad leaders on (new since round 21's P0; round 19 priced them at +4.6 ms median a tick on the
Sumps, the navmesh grounding of slots round the water) and/or the airship flag's station search; the doubling is not
on main yet. **Perf's P0 and brains' B3 (the Sumps case) at once; attribution by removal on his seed.** His frame log
is the instrument: every match writes `build/recordings/<match>.perf` (per second: avg/p95/max ms, tick, gpu, ui,
vehicles, phase).

### Round 22, same hour: six vehicles, one line, two points, and they bumped (2026-10-07 ~14:10 PDT, in chat)

> *"I have 6 vehicles selected and I was trying to move them to a location in line formation. There were 2 resultant
> points selected so I assume that means the squad of 6 was split into 2 for formation purposes based on the max 5
> vehicle constraint you mentioned. It looked like the lines were criss-crossed in terms of current position versus
> what they were trying to achieve. As such, the vehicles were all basically bumping each other and contending trying
> to get in formation."*

**Read from the same recording (`2026-10-07T13-46-42-sumps.jsonl`, ticks 3615–4430):** his six were two SQUADS of three
Retired APCs (Green_Hunters 1, 5, 7 and 4, 6, 8: the survivors of two garage squads, kept as two squads by round 19's
rule), standing intermingled (centres 7 m apart at tick 4430), ordered together six times; each click laid the two
squads abreast (two points 13–42 m apart). The squad-centre paths never cross; the crossing is at the VEHICLE level:
two interleaved squads sent to two side-by-side lines must pass through each other, and inside each line the seat
assignment can cross too. **Orders (this round, ahead of O2): a selection whose squads stand interleaved is laid out
and seated so that no two vehicles' paths cross** (seats assigned across the whole body by position across the
heading, not per squad; or the squads re-dealt by position when he has selected loose survivors of several), with his
case as the scenario (the Sumps, seed 5988, those six at their tick-4430 positions, a line to (102.5, 21.1)) and the
count of path crossings and hull contacts as the measure. What he expected, one line of six, is a squad of six: not
offered (brains' five is the invariant); two lines of three side by side with no crossing is the answer.

### Round 22: the close (2026-10-08; what shipped against his words, and what the measurements overturned)

**Shipped on `main`:** 2000 credits a game (a Law army 13 tanks, the Syndicate 7, both under the cap); the VEHICLE CAP
STAYS 25 in five squads this week (everything is built for ten squads / 50 and flips back by one constant); squads on
keys 1–9 and 0; two interleaved squads sent abreast no longer cross; ten squads in nested ranks about 100 m deep with
the front rank on his click; the x50 portrait, a legible radar at 50; a vehicle under fire it cannot return closes,
takes cover or backs off instead of dying in place, both sides (under his own hold it holds and the readout says why);
the contact alert above the two-row group bar; a music fade bug.

**Overturned by measurement:** the doubling itself. He said *"double it"*; perf's size series (builder0, 3 seeds × 120 s)
found nothing above 25 a side holds the frame bar, the tick costs ~0.7 ms per vehicle in contact on builder0 (~2 ms on
his laptop) and even 25 a side fully in contact is slow motion there; brains' think-rate lever bought 15–25 %, not 2×,
and the one equal-answer cut that measured was not equal. The orchestrator set the cap at 25 with the credits at 2000
(his complaint was tank armies, and those double under 25) and filed the per-vehicle tick as round 23's first item. His
"it was really choppy" was not a regression: the same build an hour earlier ran at 30 fps because 9–13 vehicles were
alive; his Sumps match had 41.

**His verdicts this round:** the airship trade: no (stations OFF for good). **Still his:** the cap choice (built as
recommended), two columns 14 → 28 m, the Syndicate-over-gangs range gap.

## Round 23 direction, first item: the fast crew slows so the squad forms up on the way (2026-10-08, ~00:30 PDT, in chat, playing)

> *"units getting into formation is getting better, but there seems to be an obvious optimization we can do - when I
> had tanks in line abreast and had them move somewhere, they never got into formation until the very end - because
> the lead vehicle was already closed to the target point at the start, the other vehicles never caught up to it until
> it stopped. It seems that we could more easily get info formations if some vehicles slowed down to et back
> information formation with the rest of the squad"*

**Reading (the orchestrator):** round 20's M1 (form up on the move) starts each crew's station where it stands and
converges the stations onto the shape over the first leg, but every crew drives at its own top speed toward its
station; a crew that starts nearest the destination reaches its seat at once and simply drives on at full speed, so
the shape only closes when the leader stops. The squad needs a PACE: the anchor moves at the speed that lets the
farthest-behind crew reach its seat (a crew ahead of its seat slows, a crew behind catches up at full speed), the way
`GroupFormation.pace` already does for a direct (non-element) order. **Round 23, brains:** the element's transit paces
the anchor to the slowest-to-seat crew; scenario = his case (a line abreast, the destination off the line's end so one
crew starts nearest; assert the shape is formed within the first N metres, not at the stop); the arrive series must
not get slower than the slowest crew already makes it; the pursuit (P2) keeps road speed (a chase is not a parade).

### Round 22, after the close: he played main (2026-10-08, ~01:00 PDT)

> *"ok I played the game, there's no obvious feedback right now."*

On main at the close (2000 CR, the cap 25, B1, the untangle, keys 1–9 and 0): nothing to report. Round 23 launches on
the filed candidates (`roadmap.md` *Round 23 candidates*: his pacing item first, then the per-vehicle tick).


## Round 23 direction: the launch (2026-10-07, ~23:00 PDT by the clock, in chat, going to bed)

The orchestrator put the round 23 picture to him (three streams: **brains** = his pacing item; **native** = the
per-vehicle tick, round 19's held item 2, native code for the vehicle brain's hot loop; **orders** = the two columns'
spacing, AUTO at ten squads, the chip under the alert; the laptop baseline the orchestrator's first job) with the two
open decisions, one recommendation each. His answers:

> *"ok, the two decisions that are mine, I go with your recommendations. Both this laptop and builder0 are all yours.
> I'll be going to bed soon so I'll expect you to get work done. Go ahead and get the workspaces set up as you see fit
> so we can kick off some work"*

**So, decided by him (2026-10-07, ~23:00 PDT):**

1. **Two squads in column side by side: 28 m apart, not 14** (orders' question 1 from round 22, recommended yes; he
   will see two files that read as two and do not brush). Orders builds it; one layout constant; his eye refines the
   number later if 28 reads too wide.
2. **The Syndicate range gap stays** (four Syndicate beat ten Rat Rods for no damage; one spotter beats five Rat Rods
   12 of 16; B4's measurement): leave it this round. A balance call, filed, not a bug. Nobody touches the numbers.

**Native code's language:** he asked whether "GDExtension" meant Rust. The orchestrator's recommendation, taken unless
he says otherwise: **C++ through godot-cpp** (the official binding; the engine's own types and build system; the
Android export path well trodden; the brain's hot loop is plain math over arrays, where C++ gives everything Rust
would, and Rust would add a second toolchain on builder0 and an Android cross-compile for no gain on this code).

**The laptop and builder0 are the orchestrator's tonight** (his words above): the laptop baseline at 25 and 30 a side
runs while he sleeps; no gate blocks tonight (memory: overnight autonomy; every decision recorded here or in a brief's
Status for him to refine in the morning).

### Round 23, the afternoon: the per-tick loop goes to C++; why not Rust (2026-10-08, in chat)

After the round's numbers (every native port −22 % of the brains' cost at 50 a side, builder0, n = 3; 25 a side in
contact still ~30 ms a tick on his laptop against the 25 ms bar), the choice put to him: rewrite each vehicle's whole
per-tick loop in C++ (multi-round, recommended) or have vehicles think less often in big fights. His answer:

> *"ok yes let's plan on re-writing the whole per-tick loop in C++. But also, at the start of this conversation I
> asked if we should re-write in Rust. You didn't answer that and instead you just completely into development. Is
> Rust a potentially better option here?"*

**Decided by him: the per-tick loop is rewritten in native code (round 24's stream; native's N3 plan in
`_agents/native.md`).** The orchestrator owned that it had recorded C++ for him without answering his Rust question,
and answered it: **stay with C++**, because the proof is bit-for-bit equality with GDScript and godot-cpp ships the
engine's own vector math (same operations, same order), while godot-rust reimplements it in Rust (every rounding
difference ours to find); the C++ toolchain, both machines' builds, the check and four proven ports exist; Rust's real
advantage (memory safety in a large rewrite; no automatic multiply-add fusion) is covered by the equal-answer proof
on every check and one compiler flag. Rust stays open if he prefers it: the moment to switch is before the rewrite
starts.

## Round 24 direction, his playtest after round 23's close: the bridge, and the squad that wandered off (2026-10-08 ~20:20 PDT, in chat)

He played main at the close (`fc56bd64` code; the Locks, seed 15833; recording
`streams/references/round24/his/2026-10-08T20-17-24-locks.jsonl.gz` + `.perf` + `.booth.txt`):

> *"ok I also found another obvious bug that one of the workstreams should take on. I just tried smoke testing the
> game, and on the map there's a bridge. I told all my units to go and attack at the remote locationa cross the
> bridge, and a whole bunch of them got stuck seemingly trying to drive through the river. Clearly our pathing
> algorithms are not navigating maps correctly, i.e. identifying that they need to cross a bridge to get where they
> need to go. Additionally, this is more minor but I think a subtle thing that should be accounted, but I had a lot of
> units selected, I moved them all to the west side of the map, and one squad took a whole different route and
> basically arbitrarily detached from the rest of the force - I'm not sure how our navigations algorithms work but
> presumably in decision making there should be a cost associated with a vehicle or vehicles detaching from the
> safety of the rest of their army"*

**Reading (the orchestrator; VERIFY against the recording first, lesson 274):** (1) a bug: an attack-move across the
Locks' river sends crews into the water instead of over the bridge. Candidates to test, in order: the navmesh (does a
path over the bridge exist, and is the river cut out of it?); the route (does `Pathing.find_path` return the bridge
route, and does the element's anchor follow it, or does an attack-move's leg / a crew's straight-line steer take the
direct line?); the slot grounding (`closest_point` snapping a slot onto the far bank, and a crew driving straight at
it). Round 23's native N2a reimplemented `closest_point` bit for bit (proven equal on every map), so it should NOT be
the cause; prove that by running the recording's order with `--brains-off=native`. (2) a design gap: several squads
ordered together to one place route independently; one took another way and left the army. He asks for a cost on
detaching from the force: route choice for squads ordered together should prefer the route the body takes (one
shared corridor, or a penalty on routes that split from the group's), symmetric for the CPU.

## Round 24 direction: the launch (2026-10-08 ~21:00 PDT; the orchestrator, he is setting up the worker terminals)

He asked the orchestrator to set up the round's workstreams. **Decided for him (reversible; his to overturn):**
- **The bridge first, the rewrite second.** Brains fixes the bridge (his bug) as the round's first merge (CP1); native's
  rewrite of the per-vehicle tick (his decision of round 23) starts editing `movement.gd` / `tank_brain.gd` only after
  that fix is on `main`, so the C++ ports the fixed behaviour. Native spends the hours before CP1 on the data the C++
  will own and on the map of what can be ported exactly and what must be declared.
- **Two streams** (brains, native); orders, army and perf rest: nothing of his is waiting on them.
- **The squad that wandered off** becomes a COST on a squad leaving the body's route when squads are ordered together,
  not a rule that they never split (a second bridge that saves real time may still be taken, and the case is written
  down); the CPU's grouped orders get the same cost (*Smart AI on both sides*).

## Round 24, his decision on big fights (2026-10-09 ~06:30 PDT, asked in chat)

Asked (in player terms): on his laptop 25 a side still slows to ~80 % speed when the armies first clash, and 50 a side
cannot reach full speed there even with every C++ port left (native's honest estimate, `references/round24/perf/laptop/`).
**His answer: "25 a side, no slow-mo"** (the recommended option, as written to him): finish the remaining C++ ports
(~25 % more), and have brains design vehicles far from the shooting think a little less often, his crews and the
CPU's alike; what he would notice: the opening clash at 25 a side plays at full speed, a crew at the back might
react a fraction of a second later. **The army stays 25 a side on the laptop; 50 a side becomes a better-hardware
question** (not this round).

Consequences recorded by the orchestrator: (1) the round's bar moves from "50 a side ≤ 25 ms" (C24.4, unreachable
here) to **"25 a side, no slow motion in the opening clash on his laptop"** (C24.7). (2) Thinking less often is a
DECLARED behaviour change (C24.3), symmetric, and it must be decided from simulation state only (contact, reach,
distance to the nearest enemy, orders), never from the player's camera or selection: the match must stay identical on
every machine (relay-only servers, `determinism.md`). (3) Round 22's `brain_stride` ruling (OFF: "15–25 % not worth a
declared change", the orchestrator's) is reopened by this answer: brains may use it or something finer.

## Round 24, his pick of the think-rate setting (2026-10-09 afternoon, in chat)

Offered A (`--l1=2:3:5`, game speed 0.885 in the opening clash) and B (`--l1=2:4:3.333:7.5:6`, 0.916), laptop, code
`8d2f0f85`, n = 6 ABBA (brains), with the rule "B unless its behaviour series shows something he would notice that A
does not (more crews stalled at the bridge rim, a slower pursuit, worse plain-move arrival than A); then A". His
words: *"yeah B sounds great. We'll go to A if necessary, but intuitively I don't see why we would really need
micro-fast decision loops"*. **Decided: B, with A as the fallback by that rule.** His intuition is recorded for round
25: he does not value sub-0.1 s decision loops for their own sake, so a coarser think rate is in bounds where the
behaviour series stay clean (the lever toward the 0.97 bar).

**Amended the same afternoon (the orchestrator, by his rule's intent; reversible):** B as the default failed `make
check` (builder0, `f2a33b90`): 15 tests, 6 AI scenarios. Attributed per knob (brains, 44 scenarios each): quiet 2 Hz
and stride 4 pass 44/44 alone; **settled 3.3 Hz** fails 3 (a healthy tank fights from cover by a wall; a scout works
onto a tank's engine deck; a unit fighting from its slot stays in it) and **engaged 7.5 Hz** fails 1 (two tanks duel on
the move, front armour first), for ~+0.008 game speed each. **Shipping B′ = quiet 2 Hz + stride 4 (with enemies
about only), settled and engaged OFF, element re-plan unchanged:** crews in a firing exchange keep today's reaction;
only crews near the fight but not shooting slow down. Re-priced and re-run through his series before it ships.
