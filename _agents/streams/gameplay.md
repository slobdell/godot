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

**Autonomy:** the lead will start you with *"You are the gameplay agent. Execute, iterate, and smoke
test toward completion without my input."* Follow *Autonomous mandate* in workstreams.md. Suggested
order is the **Overnight backlog** at the end of this brief.

## G0. Standing constraint: mobile input (the lead, 2026-09-14)
*"We eventually want to optimize for a mobile experience, meaning we'll be limited to taps, swipes, and button clicks."*
- Every command must be possible with **tap, drag, pinch/two-finger gestures, and on-screen buttons**. Today's drill (Q–T) and formation (Z–N) hotkeys, right-drag, and Space/Tab must all have touch equivalents (e.g. a tap-to-select + drag-to-order grammar, and a compact button bar or radial menu for drills/formations/pause). Keys stay as desktop shortcuts.
- The camera (G4) works with one-finger pan, pinch zoom, and two-finger rotate; the radar (G2) is a primary touch surface.
- Prefer designs where the *common* orders take one gesture; that's also the "few inputs, hidden power" principle in tactical_map.md.
- Test with synthetic `InputEventScreenTouch`/`InputEventScreenDrag` and screenshot at a phone aspect (e.g. 2400×1080 landscape).

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

### G7. Finite ammunition, and lasers that run on heat
The lead: *"Another simple thing to do here to manage strategy is to make ammunition finite, but we
can also make lasers one of the added weapons (also cool lighting effects) which never run out of
ammunition but they will cause the tank to heat up, and a tank cannot overheat. Therefore like in
MechWarrior games, heat sinks can be one of the components added to a vehicle."*
- **Ammo:** ballistic weapons (cannon, and future MGs/artillery) carry a finite ammo count in their weapon profile. Decide whether and how resupply works (none, a slow trickle, or a resupply zone at base that makes pulling back meaningful, which pairs well with G6 shields) and record why.
- **Lasers:** a new weapon in `Weapons.PROFILES`: hitscan or a very fast beam, **no ammo**, and **heat per shot/second**. Give it a clear trade-off against the cannon (e.g. lower burst damage or shorter range, but sustained and ammo-free; a natural anti-shield weapon if G6 wants one).
- **Heat:** each vehicle has a heat level that dissipates over time. **A tank cannot overheat:** a weapon that would push heat past the cap simply can't fire until it cools. (This is our reading of the lead's sentence: a hard cap, not damage or shutdown. It keeps things simple and readable. Revisit if playtests want a risk/reward "override".)
- **Heat sinks** raise the cap and/or the dissipation rate. They are a *component* in directive set 2's loadouts. Before loadouts exist, a per-unit stat is enough.
- **AI:** brains must manage both resources: don't waste shells at long odds when ammo is low, pause laser fire near the heat cap, prefer the laser when ammo runs dry. Add these to the utility inputs and tank_brain.md.
- **Contracts:** `sync_ammo`/`sync_heat` replicated; HUD shows ammo and a heat bar per selected unit; add slots `weapon.laser` + `fx.laser_beam` (`setup(from, to)`, `set_firing`) and `set_heat(ratio)` so look & feel can make hot barrels glow. Add the slot contract rows to streams/assets.md.
- The shell's mesh already lives in the `fx.shell` visual slot (landed on main 2026-09-14, sim hash unchanged), so look & feel can make glowing tracers. Give lasers the same treatment.
- **Acceptance:** tests for the ammo count, heat cap (a shot is refused at the cap), and dissipation. A match series shows lasers vs cannons isn't a blowout (neither side wins >65%), with swap-bases control.

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
- **Chassis + loadout (MechWarrior-style) vs fixed classes: your call, with a recommendation.** A sensible middle: a few chassis (scout, tank, artillery) with 1–2 weapon hardpoints plus component slots (**heat sinks**, extra ammo, shield booster, armor…) drawing from lists with costs, which keeps the garage interesting without an explosion of balance work.
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
- 2026-09-14: directive sets 1 (G0 mobile input, G1–G7 incl. Halo-style shields, finite ammo, lasers + heat) and 2 (budgeted army with components like heat sinks) added from the lead. Nothing started.

### Overnight run 2026-09-14 → 15 (morning report; kept current as items land)

**Plan** (the Overnight backlog order, below): 1 G5 turrets · 2 G3 responsiveness · 3 HUD messages ·
4 G7 ammo/heat/laser · 5 G6 shields · 6 G1 line of sight + fog · 7 G4 RTS camera · 8 G2 radar ·
9 G0 touch pass · 10 unit catalog + scout · 11 artillery · 12 budget · 13 army balance · stretch.

**Done:**
- **G5 turrets fight while moving** (d17dcc4). The turret holds its world heading with nothing to shoot
  (was: 28° drift during a 1.5 s hull turn) and covers a `watch_point` brains set from team intel
  (chosen target > visible gun on me > nearest visible > freshest memory, dead-reckoned ≤ 1.5 s).
  Series anvil_hammer vs individuals, 20 + 20 (swap) matches: **idle guns 83–87% → 61–68%**, first shot
  7.3 → 6.2 s, loser kills ~1.2 → ~1.5. Tests: `tests/test_turrets.gd` (heading hold and watch fail
  without the change; break_contact and move-away keep firing, ≥ 80% front armor toward pursuers).
- **G3 responsiveness** (d17dcc4). New squad order → every brain re-thinks next tick, commitment dropped
  (`Squad.order_serial`). KEEP_SLOT 0.95 under move/bound/hold; RETREAT overrides only when about to die.
  Commander pacing counts only followers lagging behind. Map pings the ordered spot. Measured
  (`tests/test_responsiveness.gd` prints MEASURE lines): ticks to first obey [1, 6] → [1, 1]; slowest
  tank starts moving in 11 ticks (budget 15); the commander covers 5 m in 53 ticks (acceleration-limited).
- **HUD messages.** `game/match/announcer.gd` (`MatchAnnouncer`) turns match events into
  `Hud.post_message` for the player's team in skirmish: order acknowledged / rejected, first contact
  (20 s cooldown), "Alpha lost Alpha 1 (4 tanks left)", enemy destroyed, commander succession,
  VICTORY/DEFEAT. New signals: `Match.tank_destroyed(victim, killer)`, `Squad.commander_lost(fallen,
  successor)`. Tests: `tests/test_announcer.gd`. Smoke: a headless scripted skirmish prints the
  `HUD_MESSAGE` lines in order.
- **G7 ammo, heat, laser** (6dc6ada, tuned 4794a19). Cannon: 45 shells; shells come back 1/s within
  30 m of your base. Laser (`Kind.BEAM`): hitscan pulse, 55 m, 9 damage every 0.5 s, 12 heat per pulse,
  no ammo, flatter armor table (0.7/1/1.3). Heat: capacity 100, −12/s; a shot past the cap is refused.
  AI: RESUPPLY option, no long shots at ≤ 30% ammo, less appetite when empty or hot. `sync_ammo` +
  `sync_heat` replicated; `weapon.laser` + `fx.laser_beam` placeholder slots. Map readout shows `aN`
  shells / `hN%` heat. Balance (lasers vs cannons, Individuals doctrines, swap + team-identity
  counterbalanced): before shields lasers won 14/60 (23%); with shields and multiplier 1.5, 29/40
  (72%); at 1.25, 14/24 (58%). Tests: `tests/test_ammo_heat.gd`.
- **G6 shields** (d3556b5, tuned 4794a19). Hull 300 + shield 150; the shield refills 50/s after 4 s
  without damage. Shields are directional (front 0.7 / side 1.0 / rear 1.4) and weapons scale them
  (cannon 0.8, laser and flamethrower 1.5: energy and fire strip shields, shells break hulls). Only
  damage the shield can't absorb meets the armor. Hulls mend only at base (6 HP/s once not hit for
  4 s). AI: RECHARGE (shield down, gun on me, hull < 75%: duck into cover or back off 25 m, return
  at 60% shield), worn tanks go home to mend and stay until 90%. `sync_shield`, hull slot
  `set_shield(ratio)`, nameplate `300 +150`, "Alpha: shields down". Tests: `tests/test_shields.gd`.
  Measured (anvil_hammer vs individuals): camping at base is gone (worn tanks go home, mend, come
  back); loser kills ~1.0 (unchanged: still snowbally); first kill ~37 s (was ~33–41 s).
- **G1 line of sight + fog** (3dbb214). `Tank.sight_radius` (75 m, from Units) feeds team intel and
  sensing. `VisibilityField` (`game/match/visibility_field.gd`): 2 m grid of never / seen / visible
  for the player's team, staggered over 30 ticks (full refresh 12.5 ms for 5 tanks); presentation
  only. `Match.is_visible_to(team, tank)`. 3D fog of war via a new `fx.fog_of_war` slot
  (placeholder shader). Screenshot `build/screenshots/g1_fog.png` shows lit fans, wall shadows,
  remembered ground. Tests: `tests/test_visibility.gd`.
- **G4 RTS camera** (04f1437). `game/camera/rts_camera.gd` drives the main camera in skirmish: tilted
  perspective, zoom from 16 m close behind (25°) to 260 m high (82°), arrows / screen edge /
  middle-drag pan, wheel zooms toward the cursor, `,` `.` rotate, F follows the selected commander,
  Tab overview. Touch: drag pans (grab the ground), pinch zooms, twist rotates. Nameplates in skirmish
  are short and never show brain intents (enemy intents leaked through the fog). Tests:
  `tests/test_rts_camera.gd`. Screenshots `build/screenshots/g4_*.png`.
- **G2 radar** (a17a574). `game/ui/radar.gd`, bottom right: obstacles, fog (lit / remembered / dark),
  friendlies with commanders ringed, enemies in sight, fading contacts, destinations, camera footprint.
  Tap aims the camera; drag orders the selected squad. Enemies only from intel. Contract row recorded
  in workstreams.md (styling hook `GameTheme.ui["radar_frame"]`). Tests: `tests/test_radar.gd`.
- **G0 touch pass** (e077288). Tap tank = select (again = commander); tap ground = go there; hold then
  drag = go + face; drag = pan; pinch/twist = camera. Buttons ≥ 40 px (7% of screen height) for every
  drill, formation (popup row), squad, Pause/Resume, Overview, Follow. Tests: `tests/test_touch.gd`
  (including a real `InputEventScreenTouch` through Godot's input). Screenshot `g0_phone.png`.
- **Laser tuning**: laser shield multiplier 1.5 → 1.25; lasers vs cannons 29/40 (72%) → **14/24 (58%)**.
- **Directive set 2 part 1: catalog + scout** (4ca53ea). `Units` v1 drives every tank stat
  (`Tank.apply_loadout`); doctrine tanks take `unit`, `weapon`/`weapons`, `components`, `paint`
  (validated, with reasons); armies up to 20 units in 4 squads. **Scout**: 110 pts, 140+80, 14 m/s,
  110 m sight, machine gun or laser; brain option SPOT keeps enemies at 85 m (outside cannon range)
  and scouts ahead. Components: heat sink, ammo rack, shield booster, armor plating. Paint colors the
  vehicle; team color goes to `set_team_accent` (the lead's accent-light rule). Tests:
  `tests/test_loadouts.gd`.
- **Directive set 2 part 2: artillery** (2caf994). 180 pts, 200+80, 6.5 m/s, 60 m sight, mortar:
  35–160 m, 90 damage in an 8 m burst, over cover, only at team-spotted targets
  (`OrderController.spotter`). Brain: BOMBARD from 80 m+, SHADOW behind friendlies, never brawls. A
  lone battery mostly suppresses shields (each hit restarts their recharge); kills come with direct fire.
  Tests: `tests/test_artillery.gd`. `doctrines/combined_arms.json`.
- **Budgets** (d917809). `Army` (`game/units/army.gd`): budget check, seeded CPU armies from archetypes
  (balanced, armor, recon_strike, siege, swarm) that spend leftovers on components (heat sinks on
  lasers first). Skirmish enemy defaults to `cpu` (seed printed as `SKIRMISH_ARMY`); `--budget`,
  `--seed`; the match runner takes `cpu:<archetype>` too. Chassis + loadout recommendation written up in
  [`_agents/balance.md`](../balance.md). Tests: `tests/test_army.gd`.

- **Stretch: control point** (7b2e9e9, opt-in `--control`). 16 m zone at the center, flat 8 s capture (a
  bigger army doesn't capture faster: anti-snowball), 1 point/s to the holder, first to 90 wins or
  elimination. Brains CONTEST; map/radar rings, center score in the map panel, announcements. Tests:
  `tests/test_control_point.gd`. Measurement below under *Balance*.
- **Stretch: CPU commander** (69b9456). `game/ai/cpu_commander.gd` issues real SquadCommands for a CPU
  team's gun squads every 2 s from intel (move/bound, assault when stronger, break contact when weaker,
  hold otherwise). On for skirmish's CPU army (`--no-commander` to disable); runner flags
  `--green-commander` / `--rust-commander`. Tests: `tests/test_cpu_commander.gd`.

**Balance** (full tables in [`_agents/balance.md`](../balance.md)): see the archetype round robin and the
stretch series there.

**Decisions:**
- G5: tanks fire only at enemies in their *own* line of sight and range; team intel only aims the turret.
  Shooting at positions only a teammate sees would mostly hit walls.
- G3: "player intent dominates unless about to die" = under move/bound/hold/break_contact, RETREAT only
  below 8–25% health (by caution). Assault keeps the old loose weights on purpose (brains hunt).
- G3: kept hull turn rate (80°/s) and acceleration; measured start-up lag was think stagger and pacing,
  not the hull. Revisit if the lead still finds turning sluggish.
- Phone screenshots are taken at 1200×540 (a 2400×1080 phone at 2× UI scale): the 1920×1080 desktop
  clamps bigger windows. Real phones need `display/window/stretch/mode` (see Questions).

**Questions for the lead:**
1. **Shields broke the coordination result (T1).** Anvil & Hammer (coordinated) vs Individuals went
   60% (after G5) → 46% (G7 ammo) → **~5–10% with G6 shields** (2/20 per series, several variants).
   The Individuals mirror is fair (9–11 of 20). Ablations with `--tune`: no shield (hull 300) 31%;
   no shield, hull 400: 31%. Tried and not enough: directional shields, a short RECHARGE instead of
   retreating home, letting RECHARGE break an anchor's leash, a "Focus Fire" doctrine (2/20). My read:
   recharging shields reward concentrated, sustained aggression (5 tanks hitting the same targets
   before shields come back), and punish split/holding doctrines. Options: (a) keep shields and
   retune doctrines (the CPU and player defaults) for concentration; (b) slower recharge / smaller
   shield (the effect shrinks); (c) team-level mechanics that reward holding ground (control points,
   stretch item). I kept shields as briefed and moved on; `--tune=tank.max_shield=…` makes (b) a
   one-flag experiment. **Update:** (c) works: with the center control point (`--control`) Anvil &
   Hammer vs Individuals is **10 : 10**. My recommendation: make `--control` the default skirmish rule
   (it's opt-in now because it changes the victory condition you asked for).
2. Directive set 2 balance (E3): the first archetype round robin had **Siege (2 artillery) at 81%** and
   scout-heavy armies at 12–25%. I added a counter triangle (scouts hunt artillery) and raised artillery
   to 220 points; round robin #2 is in `_agents/balance.md`. Worth deciding: is "an all-scout army can't
   win" acceptable (scouts as eyes, not an army), or should scouts be viable alone?
3. Real phones need content scaling (`display/window/stretch/mode="canvas_items"`, aspect `expand`)
   in `project.godot` (shared). I haven't changed it; the phone screenshots use a 1200×540 window.

**Requests to other streams:**
- Look & feel: `Hud.post_message` is still the print-only stub, so in-game the only visible order
  feedback is the tactical map's toast. Once banners render, the map toast can go (it duplicates them).

**Known issues:**
- T1 regression above. Fights still snowball (loser kills ~1).
- Idle guns rose from 61–68% (G5) to 70–90% after G7/G6. Part is by design (low-ammo tanks hold
  long shots; empty or overheated guns count as idle); not yet separated out.
- Beams are too thin to see from the flat tactical view (fine in 3D; look & feel owns the look).

**Merge notes** (for the morning integrator):
- Branch `stream/gameplay`, based on `ee20791`, not rebased (overnight rule). `make check` and
  `make web-smoke` pass on the last commits; sim baseline changed on purpose several times (each
  commit says why), now `acbce16086414508`.
- Edits outside gameplay's paths, all additive: `Makefile` (`ENEMY ?= cpu`); `game/network/replication.gd`
  (appended `sync_ammo`, `sync_heat`, `sync_shield`: netcode please review); `game/theme/game_theme.gd`
  (slots `weapon.laser`, `fx.laser_beam`, `fx.fog_of_war`, `weapon.machine_gun`, `fx.tracer`,
  `weapon.mortar`) + placeholder scenes in `game/theme/default/` (`weapon_laser.tscn`, `laser_visual.gd`,
  `fx_laser_beam.tscn`, `laser_beam_visual.gd`, `fx_tracer.tscn`, `fx_fog_of_war.tscn`,
  `fog_of_war_visual.gd`): look & feel owns the look; `_agents/streams/assets.md` slot rows;
  `_agents/workstreams.md` contract rows (visibility/radar, unit catalog v1, loadout fields);
  `game/ui/hud.gd` (text: shield, ammo); `game/agent/agent_bridge.gd` (shield in observations);
  `tools/match_series.py` (pace, loser kills, what brains do). Untouched: `project.godot`, `main.gd`,
  `main.tscn`, `game_mode.gd`, `mk/core.mk`, `tests/run_tests.gd`, `hud.tscn`.
- Likely conflicts: look & feel also edits `game_theme.gd` and `game/theme/default/` (keep both sets of
  slots); garage writes loadout JSON (now validated strictly: unknown units/components are errors).

**What to playtest:** `make skirmish` now fights a random budgeted CPU army (`SEED=3` for a swarm of
scouts, `ENEMY=cpu:siege` for artillery, `ENEMY=individuals` for the old five tanks). New camera: arrows/wheel/`,` `.`, F follows, Tab overview. The
radar (bottom right): tap to look, drag to order. Try it like a phone: tap a tank, tap the ground,
hold-then-drag, use the buttons. Order a squad back toward base (Move or Break contact) while in
contact; guns should stay on the enemy. Orders should visibly start within a blink. Watch the fog:
the dark areas are what your team can't see. The squad readout shows hull+shield, shells (`a`),
heat (`h`). `make skirmish ENEMY=individuals_laser` fights laser tanks. Pull a worn squad back to
base (Break contact) to mend hulls and refill shells.
`make skirmish-shots` takes scripted screenshots (desktop + phone aspect) into `build/screenshots/`.

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. Each item: tests + `make check` + a smoke test (skirmish screenshots at 1920×1080 and 2400×1080 that you look at, and/or a match series) + a commit + a Status update. **Every change should show up in `make skirmish`**, since that's what the lead plays in the morning.

1. **G5 turrets fight while moving.** Small and fixes the bug the lead saw. Includes the break_contact acceptance test.
2. **G3 responsiveness.** Immediate re-think on player commands, measure ticks-to-move before/after, and add a test.
3. **HUD messages.** Call `main.hud.post_message()` for order acknowledgements, commander down, unit lost, shields down (later), and victory/defeat. Look & feel turns them into banners.
4. **G7 finite ammo, heat, and the laser weapon** (+ `sync_ammo`/`sync_heat`, append-only in `replication.gd`'s list; netcode owns the file, so keep the edit minimal). HUD readouts can be plain text for now. Add the `weapon.laser`/`fx.laser_beam` slot ids to `GameTheme.DEFAULT_SLOTS` with a simple default scene (a minimal additive edit to look & feel's registry; note it in the merge notes). Balance series lasers vs cannons.
5. **G6 shields + hull health**, with brain use (disengage to recharge) and `set_shield(ratio)` invoked on the hull slot. Measure: loser kills, time-to-kill, camping (idle-gun samples) before vs after.
6. **G1 line of sight + visibility field**, and fog of war driven by it. Update the sim baseline on purpose.
7. **G4 RTS 3D camera** with touch gestures (one-finger pan, pinch zoom, two-finger rotate), plus mouse/keys as extras.
8. **G2 radar** (own `game/ui/radar*`, added from code by skirmish mode; don't edit `hud.tscn`): visible area, units, contacts, tap/drag orders.
9. **G0 touch pass over the whole skirmish:** an on-screen button bar or radial menu for drills, formations, and pause; tap-select and drag-order everywhere; tests with `InputEventScreenTouch`/`ScreenDrag`.
10. **Directive set 2, part 1:** wire `Units.PROFILES` (game/units/units.gd, schema v0) into Tank/Match as the source of stats; doctrine tanks accept `unit` (the garage writes it; see the Loadout fields contract). Add the **scout** class (fast, fragile, long sight, light MG) and scouting brain behavior.
11. **Directive set 2, part 2:** **artillery/mortar** with indirect arcing fire and spotting (fires only at team-visible targets), with its brain behavior.
12. **Budget in skirmish:** player and CPU armies built from a budget (a doctrine per army; the CPU picks a seeded composition). Chassis+loadout recommendation written up, with components (heat sinks first).
13. **Army-level balance series:** no single composition dominates (E3 at army level). Record results in tank_brain.md or a new `_agents/balance.md`.
- **Stretch:** anti-snowball ideas from "Known problems" (objectives/control points, comeback mechanics), measured with the match runner; flamethrower niche via shields; better CPU commander (uses drills).
