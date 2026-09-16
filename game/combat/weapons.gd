class_name Weapons
extends RefCounted
## Weapon profiles are DATA. A tank carries a weapon id; the rules (Match), the
## order layer (aiming/firing), and the brain (preferred range) all read the
## profile. Adding a weapon should mostly mean adding a row here.
## See _agents/tank_brain.md "Weapons v1".

## PROJECTILE: a Shell flies (travel time). CONE: continuous spray. BEAM: instant hitscan pulse (G7 laser).
## ARC: an indirect round lobbed at a ground point; it flies over obstacles and bursts on landing (artillery).
enum Kind { PROJECTILE, CONE, BEAM, ARC }

## K2 (round 3) weapon profile v3, for effects, sound, the announcer, and the AI. `kind` stays the mechanical
## resolver; `fire_model` is how the weapon reads: shell (one heavy round), burst (a few rounds per trigger pull),
## stream (continuous fire while held), beam (instant pulse), arc (lobbed). Other v3 keys: reload_s (seconds between
## trigger pulls; equal to the round-2 "reload"), burst_count and burst_interval_s (rounds per pull and the gap
## between them), projectile_speed_mps (0 = hitscan), spread_deg, damage (per round), penetration, splash_radius.
const FIRE_MODELS := ["shell", "burst", "stream", "beam", "arc"]

## L2 (round 4): how much SUPPRESSION one round lays down along its path (`ThreatField` units), independent of the
## damage it does. This is where "a machine gun's value is volume, not damage" lives: multiply by the weapon's rate
## of fire to compare. Streams and cones (fire_model "stream" with Kind.CONE) are per SECOND, everything else is per
## round. Rate of fire at a glance: MG 10/s x 0.10 = 1.0/s, 25 mm 2.2/s x 0.35 = 0.78/s, cannon 0.2/s x 1.2 =
## 0.24/s, laser 2/s x 0.15 = 0.3/s, mortar 0.22/s x 3.0 over a 9 m splash. Match.SUPPRESSION_FULL_DENSITY (3.0) is
## what it takes to pin, so one machine gun holds a lane at about half suppression and two crews pin it.

const DEFAULT := "cannon"

const PROFILES := {
	"cannon": {
		# K2 (round 3): profile v3.
		"fire_model": "shell",
		# X2 (round 3, the lead: "very low frequency … devastating hit, but a miss is also quite costly"): 2.5 s -> 5 s,
		# 34 -> 320 damage, 70 -> 75 m/s. A side hit strips a full tank shield and ~45% of its hull (63% of shield +
		# hull); front 39%; rear 95%. Kills: side 2, rear 2, front 4 (shield regrows 1 s between shells). A shell flies
		# 0.7 s over 50 m: lead the target, and a jink makes it miss.
		"reload_s": 5.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 75.0,
		# R2: armor-piercing power vs a unit's armor thickness on the face it hits (Units "armor").
		"penetration": 10.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		# Shorter than the 84 m between bases, so contact is something you maneuver into.
		"range": 70.0,
		"preferred_min": 20.0,
		"preferred_max": 45.0,
		"damage": 320.0,
		"reload": 5.0,
		"aim_tolerance_deg": 2.5,
		# Shot spread (standard deviation, degrees) when stationary. Firing on the move
		# multiplies it (see Match.MOVING_SPREAD_FACTOR): long-range shots from a moving
		# tank mostly miss, so halting to shoot (hold, overwatch) matters.
		"spread_deg": 0.8,
		# G6: damage to shields is (damage x shield_multiplier), evenly from any side; only what
		# gets through the shield meets the armor (Armor.penetration_multiplier). Cannons are hull breakers.
		"shield_multiplier": 0.8,
		# Weapons without an "ammo" key never run out. Rules R8 (2026-09-14): direct-fire guns lost their finite
		# loads (cannon 45, autocannon 300, machine gun 600). In squad-vs-squad matches (~2 min, no respawns)
		# unlimited ammo changed no outcome (Armor vs Balanced 26:6 finite, 25:7 unlimited) and resupply trips
		# took 0-6% of brain time: it added readouts, not decisions. Artillery keeps its 24 rounds.
		"heat_per_shot": 0.0,
		# L2: one shell is terrifying but rare — 0.24 suppression per second of sustained fire.
		"suppression": 1.2,
	},
	# Round 2 (the lead): the IFV's "equivalent of 30 mm cannons" (round 3: a 25 mm Bradley-style gun). Fast fire, low
	# penetration, modest range:
	# it shreds light hulls and scouts' shields but can't get through a tank's front armor.
	"autocannon": {
		# K2 (round 3): profile v3.
		"fire_model": "burst",
		# X2 (round 3, the lead: "a 25mm cannon like a Bradley … a low frequency machine gun"): 4-round bursts 0.12 s
		# apart every 1.8 s at 180 m/s (0.33 s to 60 m, near-instant). 9 dmg / 0.35 s (26 dps) -> 15 x 4 / 1.8 s (33
		# dps): shreds scouts, chips tank fronts, hurts tank rears (pen 4 vs rear armor 2). Projectile, not hitscan:
		# rounds still fly, so they miss what dodges at range and incoming_projectiles sees them.
		"reload_s": 1.8,
		"burst_count": 4,
		"burst_interval_s": 0.12,
		"projectile_speed_mps": 180.0,
		# X6 (round 3): 4 -> 5, so bursts get through a Lancer (armor 3 now) and hurt flanks; still x0.05 on a tank
		# front (8).
		"penetration": 5.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		"range": 60.0,
		"preferred_min": 15.0,
		"preferred_max": 45.0,
		"damage": 15.0,
		"reload": 1.8,
		"aim_tolerance_deg": 3.0,
		"spread_deg": 1.0,
		"shield_multiplier": 0.9,
		"heat_per_shot": 0.0,
		# L2: a 4-round burst every 1.8 s is real suppression (0.78/s), second only to the machine gun.
		"suppression": 0.35,
	},
	# G7: the laser never runs out, but every pulse heats the tank, and a tank can't fire past its
	# heat capacity (a hard cap, no damage). Trade-off vs the cannon: shorter range, less burst, no
	# travel time, armor matters less; sustained fire is limited by heat, not ammo.
	"laser": {
		# K2 (round 3): profile v3.
		"fire_model": "beam",
		"reload_s": 0.5,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"penetration": 12.0,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		# Which visual slot draws each pulse (see Match.show_beam).
		"fx": "fx.laser_beam",
		# Round 2: the Lancer's "long hitscan beam" (55 m on round 1's laser tanks). R7 matrix (2026-09-14): 85 m
		# with a 72-82 m preferred band outranges the cannon (70 m) and the tank's 75 m sight, so a Lancer duels
		# tanks from where they can't answer: Lancer vs tank 33% -> 67%.
		"range": 90.0,
		"preferred_min": 76.0,
		"preferred_max": 86.0,
		# R7: 9 dmg / 12 heat -> 12 / 16: burstier, so it wins against a few big hulls but overheats against a
		# swarm of IFVs (IFV vs Lancer 42% -> 75%).
		# X2 first pass (round 3): the cannon went from ~14 to ~64 dps, so the Lancer keeps its job (tanks at range)
		# with 12 -> 28 per pulse and 16 -> 20 heat: 5 pulses from cold, ~17 dps sustained. X6 tunes it against the
		# matrix.
		# X6 (matchup search, 2026-09-15): 28 -> 22, heat 20 -> 18, range 85 -> 90 (preferred 76-86). Stronger or longer
		# and IFV rushes lose every time; weaker or shorter and tanks run Lancers down. See balance.md "Round 3".
		"damage": 22.0,
		"reload": 0.5,
		"aim_tolerance_deg": 2.0,
		"spread_deg": 0.3,
		"heat_per_shot": 18.0,
		# G6: energy weapons strip shields. 1.5 made lasers win 29/40 vs cannons (above the 65% bar);
		# 1.25 measured 14/24 (58%), swap + team-identity counterbalanced (2026-09-15).
		"shield_multiplier": 1.25,
		# L2: a silent beam doesn't make anyone duck; the Lancer suppresses least per second of any gun.
		"suppression": 0.15,
	},
	# Directive set 2: the scout's light machine gun. Hitscan bursts: cheap, fast, and mostly
	# ineffective against a tank's shield and front armor; fine against other scouts and exposed rears.
	"machine_gun": {
		# K2 (round 3): profile v3.
		"fire_model": "stream",
		# X2 (round 3, the lead: "machine guns … with their wall of bullets"): a stream, 5 -> 10 rounds/s, 4 -> 3.5 dmg,
		# spread 1.5 -> 2 deg. Hitscan: at 45 m a real round arrives in a tick or two, a stream of nodes would cost 10
		# spawns/s per scout (and network spawns), and the counterplay is getting out of the nose arc, not dodging
		# single bullets. Feel draws the tracers from weapon_fired.
		"reload_s": 0.1,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"penetration": 3.0,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		"fx": "fx.tracer",
		"range": 45.0,
		"preferred_min": 12.0,
		"preferred_max": 35.0,
		"damage": 3.5,
		"reload": 0.1,
		"aim_tolerance_deg": 4.0,
		"spread_deg": 2.0,
		"heat_per_shot": 0.0,
		"shield_multiplier": 0.6,
		# L2: the wall of bullets. 10 rounds a second at 0.10 each is the best suppression per second in the game,
		# which is the whole point of a machine gun that can barely scratch a tank's front.
		"suppression": 0.10,
	},
	# Directive set 2: the artillery's mortar. Lobs rounds over cover at a ground point; the burst hurts
	# every enemy within splash_radius (falling off to 30% at the edge). It can only aim at what the
	# TEAM sees (OrderController.spotter), so it needs scouts or tanks to spot for it.
	"mortar": {
		# K2 (round 3): profile v3.
		"fire_model": "arc",
		# Arcs scatter where they land ("scatter" below) instead of spreading at the muzzle.
		"spread_deg": 0.0,
		"reload_s": 4.5,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 40.0,
		"penetration": 10.0,
		"kind": Kind.ARC,
		"range": 160.0,
		# R7 (2026-09-14): 35 -> 42 m: scouts that close get under it (scout vs artillery 92%).
		"min_range": 42.0,
		"preferred_min": 60.0,
		"preferred_max": 140.0,
		# A lone battery can't out-damage a recharging shield for long (each hit restarts the recharge
		# delay, though): artillery's job is pressure and finishing what the direct-fire guns wear down.
		# 90 -> 70 (2026-09-15): the Siege archetype (2 artillery) still beat Armor and Balanced 12:4 after
		# the scout counter; at 70 it's 10:6 against each (counterbalanced, 16 per pairing).
		# R7: 70 -> 90 and splash 8 -> 9: spotted artillery wins a matchup (vs IFVs 58%) instead of none.
		# X6 (round 3): 90 -> 140. Swept 140-320 (balance.md "Round 3"): at 200+ one burst kills a bunch of scouts
		# (140 + 80 effective), which flips scout > artillery from 79% to 0-33% and leaves scouts winning nothing; at
		# 140 artillery stays a spotted support unit that finishes what direct fire wears down.
		"damage": 140.0,
		"splash_radius": 9.0,
		"reload": 4.5,
		"aim_tolerance_deg": 3.0,
		# Rounds land with this much scatter (meters, standard deviation) plus scatter_per_meter x range.
		"scatter": 2.0,
		"scatter_per_meter": 0.02,
		# Horizontal speed: a 150 m shot is in the air for 3.75 s, so moving targets can dodge.
		"flight_speed": 40.0,
		# Finite (R8 kept it): a battery that shells all match long would be too strong; 24 rounds is ~2 minutes of
		# fire.
		"ammo": 24,
		"heat_per_shot": 0.0,
		"shield_multiplier": 1.0,
		# L2: a burst covers its whole 9 m splash, so a battery suppresses an AREA rather than a lane.
		"suppression": 3.0,
	},
	"flamethrower": {
		# K2 (round 3): profile v3.
		"fire_model": "stream",
		"reload_s": 0.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		# Fire deals damage_per_second while it touches; "damage" (per round) is 0 for it.
		"damage": 0.0,
		"spread_deg": 0.0,
		"penetration": 12.0,
		"splash_radius": 0.0,
		"kind": Kind.CONE,
		"range": 20.0,
		"preferred_min": 6.0,
		"preferred_max": 16.0,
		# 45 -> 20 (2026-09-15): since the 09-13 rebalance (70 m guns, 400 HP) five flamers crossed gun
		# range almost intact and won 36/36 vs five cannons (4 flamers vs 5 cannons: 20/20). At 20: 10/20,
		# counterbalanced. Still ~4x a cannon's damage per second once it arrives.
		# X2 first pass (round 3): 20 -> 55, keeping its ~4x-a-cannon ratio over the cannons new damage per second once
		# it arrives. X6 tunes it.
		"damage_per_second": 55.0,
		"cone_deg": 30.0,
		"reload": 0.0,
		"aim_tolerance_deg": 12.0,
		# G6: fire burns through shields quickly (the flamethrower's niche: finish what it reaches).
		"shield_multiplier": 1.5,
		# L2: per SECOND (a cone, not rounds). Being on fire is the most suppressive thing in the arena.
		"suppression": 1.5,
	},
	# ---- L3 (round 4): the faction weapons -------------------------------------------------------------------
	# One shared mechanics vocabulary (game_design.md *Factions*): a faction's identity is the COMBINATION it gets,
	# not a new rule per faction. Reused as-is where the hull carries the identity: the gang and Law scouts take the
	# machine gun, the Law's APC the 25 mm, and the Syndicate's special the laser.

	# Road gangs: salvage. Loud, short-ranged, and there is a lot of it.
	"twin_mg": {
		"fire_model": "stream",
		# Two salvaged guns on one mount: 14 rounds/s of 3 damage. 1.26 suppression per second is the most in the
		# game — the gangs' whole plan is to bury a position in fire and drive at it.
		"reload_s": 0.07,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"penetration": 2.5,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		"fx": "fx.tracer",
		"range": 35.0,
		"preferred_min": 10.0,
		"preferred_max": 28.0,
		"damage": 3.0,
		"reload": 0.07,
		"aim_tolerance_deg": 4.5,
		"spread_deg": 2.5,
		"heat_per_shot": 0.0,
		"shield_multiplier": 0.6,
		"suppression": 0.09,
	},
	"scrap_cannon": {
		"fire_model": "shell",
		# A naval gun bolted to a fuel tanker: nearly a dozer's punch, faster to reload, and it cannot hit anything
		# far away (2 deg of spread at 50 m is a 1.7 m circle).
		"reload_s": 4.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 60.0,
		"penetration": 8.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		"range": 50.0,
		"preferred_min": 14.0,
		"preferred_max": 36.0,
		"damage": 260.0,
		"reload": 4.0,
		"aim_tolerance_deg": 3.0,
		"spread_deg": 2.0,
		"heat_per_shot": 0.0,
		"shield_multiplier": 0.8,
		"suppression": 1.0,
	},
	"catapult": {
		"fire_model": "arc",
		# Flaming barrels from a tow wrecker: the widest burst in the game, half a mortar's reach, and scatter you
		# can see from orbit. Area denial, not marksmanship.
		"reload_s": 5.5,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 30.0,
		"penetration": 8.0,
		"kind": Kind.ARC,
		"range": 120.0,
		"min_range": 30.0,
		"preferred_min": 45.0,
		"preferred_max": 105.0,
		"damage": 110.0,
		"splash_radius": 12.0,
		"reload": 5.5,
		"aim_tolerance_deg": 4.0,
		"spread_deg": 0.0,
		"scatter": 4.0,
		"scatter_per_meter": 0.03,
		"flight_speed": 30.0,
		"ammo": 20,
		"heat_per_shot": 0.0,
		"shield_multiplier": 1.2,
		"suppression": 3.5,
	},
	"fuel_spray": {
		"fire_model": "stream",
		# The resupply tanker's own hose. Shorter than a fire truck's flamethrower and less fierce, but it is why a
		# support vehicle is not free food.
		"reload_s": 0.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"damage": 0.0,
		"spread_deg": 0.0,
		"penetration": 10.0,
		"splash_radius": 0.0,
		"kind": Kind.CONE,
		"range": 14.0,
		"preferred_min": 5.0,
		"preferred_max": 12.0,
		"damage_per_second": 40.0,
		"cone_deg": 34.0,
		"reload": 0.0,
		"aim_tolerance_deg": 14.0,
		"shield_multiplier": 1.5,
		"suppression": 1.2,
	},

	# The Law: information and control. Their guns are reliable rather than fierce; their support is what hurts.
	"assault_gun": {
		"fire_model": "shell",
		# The 8x8's gun: two thirds of a dozer shell every 3.2 s instead of a full one every 5, 10 m more reach, and
		# accurate enough to use it. It out-works a dozer and loses a straight duel with one.
		"reload_s": 3.2,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 90.0,
		"penetration": 9.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		"range": 80.0,
		"preferred_min": 26.0,
		"preferred_max": 62.0,
		"damage": 200.0,
		"reload": 3.2,
		"aim_tolerance_deg": 2.5,
		"spread_deg": 0.7,
		"heat_per_shot": 0.0,
		"shield_multiplier": 0.8,
		"suppression": 0.9,
	},
	"gas_rockets": {
		"fire_model": "arc",
		# Tear gas and smoke, not high explosive: 55 damage over 14 m, and 5.0 suppression a burst — by far the most
		# in the game. A Law battery does not kill a position, it shuts it down so the assault guns can walk in.
		"reload_s": 6.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 45.0,
		"penetration": 6.0,
		"kind": Kind.ARC,
		"range": 150.0,
		"min_range": 40.0,
		"preferred_min": 60.0,
		"preferred_max": 135.0,
		"damage": 55.0,
		"splash_radius": 14.0,
		"reload": 6.0,
		"aim_tolerance_deg": 3.5,
		"spread_deg": 0.0,
		"scatter": 3.0,
		"scatter_per_meter": 0.02,
		"flight_speed": 45.0,
		"ammo": 18,
		"heat_per_shot": 0.0,
		"shield_multiplier": 1.0,
		"suppression": 5.0,
	},
	"sonic_emitter": {
		"fire_model": "stream",
		# The riot truck's cone (the lead's pick for the Law's special). 18 damage a second is nothing; 4.0
		# suppression a second is everything it can reach heads-down and shooting wide.
		"reload_s": 0.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"damage": 0.0,
		"spread_deg": 0.0,
		"penetration": 14.0,
		"splash_radius": 0.0,
		"kind": Kind.CONE,
		"range": 32.0,
		"preferred_min": 12.0,
		"preferred_max": 28.0,
		"damage_per_second": 18.0,
		"cone_deg": 40.0,
		"reload": 0.0,
		"aim_tolerance_deg": 14.0,
		"shield_multiplier": 1.4,
		"suppression": 4.0,
	},

	# The Syndicate: energy instead of ammunition. Nothing runs out; everything runs hot.
	"railgun": {
		"fire_model": "beam",
		# The product demo. 420 damage and 16 penetration at 110 m, instantly, every 6 s — and 40 heat a shot off a
		# 100 capacity, so it fires twice and then waits. Its counter is anything that reaches it before the third.
		"reload_s": 6.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"penetration": 16.0,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		"fx": "fx.laser_beam",
		"range": 110.0,
		"preferred_min": 60.0,
		"preferred_max": 104.0,
		"damage": 420.0,
		"reload": 6.0,
		"aim_tolerance_deg": 1.5,
		"spread_deg": 0.25,
		"heat_per_shot": 40.0,
		"shield_multiplier": 1.2,
		"suppression": 1.4,
	},
	"pulse_cannon": {
		"fire_model": "burst",
		# Three energy bolts a pull. Between the 25 mm and a cannon, strips shields well, and heat limits how long
		# it can keep it up.
		"reload_s": 2.0,
		"burst_count": 3,
		"burst_interval_s": 0.1,
		"projectile_speed_mps": 220.0,
		"penetration": 6.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		"range": 70.0,
		"preferred_min": 18.0,
		"preferred_max": 55.0,
		"damage": 26.0,
		"reload": 2.0,
		"aim_tolerance_deg": 2.5,
		"spread_deg": 0.9,
		"heat_per_shot": 12.0,
		"shield_multiplier": 1.1,
		"suppression": 0.4,
	},
	"pulse_repeater": {
		"fire_model": "stream",
		# The skimmer's gun: a machine gun's job done with energy — a little more damage and reach, and it strips
		# shields instead of pinging off them, but it suppresses less than salvaged iron.
		"reload_s": 0.15,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 0.0,
		"penetration": 3.5,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		"fx": "fx.tracer",
		"range": 55.0,
		"preferred_min": 15.0,
		"preferred_max": 45.0,
		"damage": 4.5,
		"reload": 0.15,
		"aim_tolerance_deg": 3.5,
		"spread_deg": 1.6,
		"heat_per_shot": 0.0,
		"shield_multiplier": 1.1,
		"suppression": 0.08,
	},
	"guided_missiles": {
		"fire_model": "arc",
		# Fires only at what somebody has eyes on: 0.8 m of scatter at any range when the target is spotted, and the
		# usual x3 blind penalty turns that into a wasted salvo. The Syndicate's artillery is a sniper with a scout.
		"reload_s": 5.0,
		"burst_count": 1,
		"burst_interval_s": 0.0,
		"projectile_speed_mps": 55.0,
		"penetration": 14.0,
		"kind": Kind.ARC,
		"range": 170.0,
		"min_range": 50.0,
		"preferred_min": 70.0,
		"preferred_max": 155.0,
		"damage": 150.0,
		"splash_radius": 7.0,
		"reload": 5.0,
		"aim_tolerance_deg": 3.0,
		"spread_deg": 0.0,
		"scatter": 0.8,
		"scatter_per_meter": 0.004,
		"flight_speed": 55.0,
		"ammo": 16,
		"heat_per_shot": 0.0,
		"shield_multiplier": 1.2,
		"suppression": 2.5,
	},
}


## L2: suppression one round of this weapon lays down (per second for cones). 0 for anything that doesn't
## suppress.
static func suppression(weapon: Dictionary) -> float:
	return float(weapon.get("suppression", 0.0))


## Shells a weapon carries, or -1 when it never runs out.
static func max_ammo(weapon: Dictionary) -> int:
	return int(weapon.get("ammo", -1))


static func exists(weapon_id: String) -> bool:
	return PROFILES.has(weapon_id)


## Experiment overrides ("weapon.key" -> value); see Units.apply_tuning. Empty in normal play.
static var tuning := {}


static func profile(weapon_id: String) -> Dictionary:
	var id := weapon_id if PROFILES.has(weapon_id) else DEFAULT
	if tuning.is_empty():
		return PROFILES[id]
	var tuned: Dictionary = PROFILES[id].duplicate(true)
	for key: String in tuning:
		if key.begins_with(id + "."):
			tuned[key.trim_prefix(id + ".")] = tuning[key]
	return tuned


## True if `target` lies within a cone from `origin` along `direction`
## (horizontal plane only).
static func in_cone(origin: Vector3, direction: Vector3, target: Vector3, max_range: float,
		cone_deg: float) -> bool:
	var offset := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	if offset.length() > max_range:
		return false
	if offset.length_squared() < 0.01:
		return true
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	return absf(flat_direction.signed_angle_to(offset, Vector3.UP)) <= deg_to_rad(cone_deg / 2.0)
