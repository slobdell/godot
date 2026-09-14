# Stream: Gameplay (make squad-vs-squad fun)

> Read [../workstreams.md](../workstreams.md), [../tank_brain.md](../tank_brain.md),
> [../tactical_map.md](../tactical_map.md), and [../squad_ai_design.md](../squad_ai_design.md).
> You own `game/match/`, `game/ai/`, `game/combat/` (except `impact.gd`), `game/tank/` logic,
> `game/arena/` layout, `doctrines/`, `game/camera/`, `game/ui/tactical_map.gd` + `game/ui/radar*`
> behavior, and the offline/skirmish/match-runner modes.

## How the lead wants this stream to work (2026-09-14)

> "We're currently painting in very broad strokes; we're trying to get the broad, general
> foundations up in place before I start fine tuning things with very specific requests. We can
> get really far by having Claude do work and making its own informed decisions based on how to
> make a good game."

**So:** make the calls a good game designer would make, build the foundation solidly, verify it,
and write down what you chose and why (in this brief's Status and the relevant `_agents/` doc).
Don't stall on details the lead will tune later; do make every tuning value easy to find and change.

## Directive set 1 (the lead, 2026-09-14): do these first

### G1. Line of sight: every tank sees a radius, blocked by obstacles
- Each vehicle has a **sight radius** (a per-unit stat; today one value, later scouts see farther). What a tank sees = inside the radius AND an unobstructed line of sight.
- **Team vision = the union** of its tanks' vision. It already feeds `Match.intel`; make that the single source of truth for what a team knows.
- **Fog of war everywhere the player looks:** enemies outside your team's vision are not drawn in 3D (skirmish already hides them; make it robust), not on the radar, and not in the tactical overlay except as fading "last seen" markers.
- Build a **visibility field** a UI can draw: e.g. a coarse grid (1–2 m cells) of "visible now / seen before / never seen", updated a few times per second with shadow-casting or ray fans against obstacle collision. Keep it cheap and deterministic (it must not change `make sim-baseline` unless it feeds decisions; if it does, update the baseline on purpose).

### G2. Radar
- A **minimap / radar** widget always on screen: arena outline and obstacles, **the visible area from G1** (lit vs dark vs remembered), friendly units (commander marked), visible enemies, last-known contacts, squad destinations.
- It's an input too, RTS style: click the radar to select/aim the camera; drag on it to order the selected squad (same SquadCommand as the map).
- **Split with look & feel:** you own the data and interaction (`game/ui/radar*`); its frame and styling come from look & feel (see *Contracts* in workstreams.md: `ui.radar_frame` styling hook). Ship a clean placeholder look and don't block on theirs.

### G3. Commands must feel responsive
The lead: *"I'm commanding the tanks like in an RTS but they're not very responsive."* Likely causes to measure and fix:
- Brains only re-think every 6 ticks, and **commitment** (×1.15 bonus, 45-tick minimum) delays reacting to a *new player order*. **A player command should trigger an immediate re-think and break commitment.**
- `KEEP_SLOT` loses to other options too often (e.g. `ENGAGE`), so tanks wander off orders; player intent must dominate unless a tank is about to die.
- Formation pacing (commander waits for followers), slow hull turning, and path re-planning intervals all add lag.
- **Feedback:** acknowledge every order instantly: the order line/marker appears on click, and units visibly start moving within ~0.25 s.
- Consider standard RTS affordances where they help: selecting individual tanks and box-selecting, shift-queued waypoints, a stop/hold hotkey. Use judgment; keep the "few inputs" principle from tactical_map.md.
- **Measure it:** add a test or metric for "ticks from command to movement" and "command followed vs overridden".

### G4. A 3D camera, not a flat bird's-eye view
The lead: *"the camera view … that was actually 3d and followed a tank was super cool, this 2d bird's eye view is boring."*
- Make an **RTS-style 3D perspective camera** the default in skirmish: tilted, pannable (keys / screen edge / drag), zoomable from close-behind-a-tank (like the follow camera) up to a high tactical angle, rotatable, with "focus/follow selected squad" on a key.
- All map interactions (select, drag orders, ghost formations) must keep working in perspective (ground raycasts already do). Remap any keys that collide with the drill/formation hotkeys.
- The flat top-down view may survive as the far end of the zoom or a toggle, but it isn't the default.

### G5. Turrets keep fighting while the hull moves
The lead: *"when I did get the tanks to move to retreat, they stopped engaging with the enemy because their turrets I guess faced the direction of movement."*
- Turrets must **track a threat independently of the hull**: while moving, retreating, or breaking contact, the turret aims at the most relevant known enemy (from team intel, even if slightly out of range) and fires when it can.
- With no target, the turret should **hold its world-space heading** (or face the likely threat direction), not swing with every hull turn. (Today, with no visible target, the aim point follows the turret's own forward, so the turret rides along with the hull.)
- Acceptance: in a `break_contact` drill with pursuers in range, retreating tanks keep firing (shots > 0 during the retreat) and face their front armor at the threat.

### G6. Rechargeable shields on top of health (from Halo)
The lead: *"a crucial element we should borrow from the Halo series: vehicles should have both a
rechargeable shield and actual health. This allows them to recover to full health after a skirmish
and adds another dimension of gameplay."*
- Every vehicle gets a **shield** layer absorbed before **hull health**. The shield **recharges to full** after a delay with no damage taken (e.g. a few seconds of calm, then a quick refill). Tuning values go in the unit data, not scattered constants.
- **Hull health** is the lasting cost of a fight. Decide whether it regenerates at all (e.g. not at all, only partly, or only at a repair point), and record why. The lead's intent is that units *recover after a skirmish*, while losses still matter; keep attrition meaningful or the snowball/camping problems return in a new form.
- **Design consequences to build in:** breaking contact becomes a real decision (disengage, recharge, re-engage), so brains and drills should value it (`RETREAT`/`break_contact` when the shield is down, return when it's back). Focus fire matters more (burn through a shield before it recharges). Decide how armor facing interacts (e.g. shields absorb evenly, facing applies to hull damage) and whether some weapons are strong against shields and weak against hulls (a natural niche for the flamethrower or a future weapon).
- **Contracts this touches:** a replicated `sync_shield` (netcode's Replication list), and HUD/radar/nameplate display of shield + hull (styling by look & feel; post a message when a squad's shields are down).
- This fixes a known problem: today hurt tanks camp at base because nothing ever heals.

## Directive set 2 (next): the game's shape, a budgeted army

The lead: *"for each game you get some sort of budget to consume, and this can be composed of any
selection of units: scouts that are fast with light, mostly ineffective machine guns but can easily
create vision for other vehicles; tanks which will be the sort of well-rounded workhorse; then maybe
others like mortars or artillery that can lob projectiles over obstacles; … maybe a set of base
vehicles that can each be configured with different weapons (like MechWarrior)."*

This depends on G1 (vision makes scouting valuable) and brings new mechanics:
- **Unit classes as data** (`Units.PROFILES`, like `Weapons.PROFILES`): cost, speed, turn rate, health, armor, **sight radius**, size, weapon hardpoints. Start with **Scout** (fast, fragile, long sight, light machine gun), **Tank** (today's), **Artillery/Mortar** (slow, fragile, **indirect fire**: arcing shells over obstacles, minimum range, inaccurate unless a teammate can see the target).
- **Indirect fire + spotting** is the combined-arms heart: artillery is useless without scouts' vision, and scouts are useless without something that can hit what they see.
- **Budget:** each side gets N points; skirmish setup picks a composition (the garage stream will build the full UI; you define the catalog and costs).
- **Chassis + loadout (MechWarrior-style) vs fixed classes: your call, with a recommendation.** A sensible middle: a few chassis (scout, tank, artillery) with 1–2 hardpoints drawing from a weapon list with costs, which keeps the garage interesting without an explosion of balance work.
- Brains need per-class behavior (scouts avoid fights and spot; artillery stays back and fires on team-spotted targets). Doctrine/squad data must carry unit classes.
- Validate with the match runner: compositions should matter and **no single composition should dominate** (squad_ai_design.md experiment E3, now at the army level).

## Known problems carried over

- Snowballing (the loser usually kills ~1); front-armor slugfests (80%+ front hits); hurt tanks camp (G6 should fix this); the flamethrower is dominated; elimination is the only objective.

## How to work

- **Playtest with the lead** after each directive lands; ask what they tried and what felt bad.
- **Measure:** match stats (`first_shot_seconds`, `first_kill_seconds`, loser kills, hits by face, idle guns) via `tools/match_series.py`, always with the swap-bases control and team-identity counterbalancing.
- **Record** the new `tests/baselines/sim_state_hash.txt` when you intentionally change the simulation (say why in the commit).

## Don't touch

`game/theme/**`, `game/ui/widgets/**` and `hud.tscn` styling (look & feel), `game/network/` and server/client modes (netcode). Coordinate through the contracts.

## Status

- 2026-09-13: brief written.
- 2026-09-14: directive sets 1 (G1–G6, incl. Halo-style shields) and 2 (budgeted army) added from the lead. Nothing started.
