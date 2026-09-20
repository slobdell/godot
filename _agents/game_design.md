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
