class_name ArmyCatalogStub
extends RefCounted
## A stand-in for unit catalog v2 (contract C1 in _agents/workstreams.md) until the rules stream's R1
## lands at checkpoint 1. ArmyCatalog.from_game() uses it only while `Units.PROFILES` is still v1
## (chassis + hardpoints); once it's v2, the real catalog wins and this file can be deleted.
##
## The numbers are placeholders shaped like game_design.md's starting roster. Rules owns the real ones.

const PROFILES := {
	"scout": {
		"display_name": "Scout", "role": "scout", "unlock_tier": 0, "cost": 110,
		"blurb": "Armored rally truck with a machine gun welded to the hood. Fast, sees far, only hits what it points at.",
		"hull_size": [2.0, 1.4, 3.0], "max_health": 140, "max_shield": 80,
		"shield_recharge_delay": 3.0, "shield_recharge_rate": 40.0,
		"max_forward_speed": 14.0, "max_reverse_speed": 7.0, "hull_turn_rate_deg": 140.0, "sight_radius": 110.0,
		"weapon": "machine_gun", "mount": "fixed", "fire_arc_deg": 12.0, "muzzle_height": 1.1,
		"good_vs": ["artillery", "lancer"], "weak_vs": ["ifv"],
	},
	"ifv": {
		"display_name": "IFV", "role": "ifv", "unlock_tier": 0, "cost": 150,
		"blurb": "Up-armored garbage truck with a 30 mm autocannon on a fast turret. Shreds light armor.",
		"hull_size": [2.4, 1.8, 4.0], "max_health": 220, "max_shield": 110,
		"shield_recharge_delay": 4.0, "shield_recharge_rate": 45.0,
		"max_forward_speed": 11.0, "max_reverse_speed": 5.0, "hull_turn_rate_deg": 100.0, "sight_radius": 80.0,
		"weapon": "autocannon", "mount": "turret", "turret_turn_rate_deg": 150.0, "muzzle_height": 1.5,
		"good_vs": ["scout"], "weak_vs": ["tank"],
	},
	"tank": {
		"display_name": "Tank", "role": "tank", "unlock_tier": 0, "cost": 200,
		"blurb": "The prison-bus dozer: a heavy cannon on a slow turret. Nothing heavy survives its front.",
		"hull_size": [2.4, 1.6, 3.6], "max_health": 300, "max_shield": 150,
		"shield_recharge_delay": 4.0, "shield_recharge_rate": 50.0,
		"max_forward_speed": 9.0, "max_reverse_speed": 4.0, "hull_turn_rate_deg": 80.0, "sight_radius": 75.0,
		"weapon": "cannon", "mount": "turret", "turret_turn_rate_deg": 45.0, "muzzle_height": 1.26,
		"good_vs": ["ifv"], "weak_vs": ["scout"],
	},
	"artillery": {
		"display_name": "Artillery", "role": "artillery", "unlock_tier": 1, "cost": 220,
		"blurb": "Crane carrier with a mortar battery. Shells what teammates spot; helpless up close.",
		"hull_size": [2.6, 1.6, 4.0], "max_health": 200, "max_shield": 80,
		"shield_recharge_delay": 4.0, "shield_recharge_rate": 40.0,
		"max_forward_speed": 6.5, "max_reverse_speed": 3.5, "hull_turn_rate_deg": 60.0, "sight_radius": 60.0,
		"weapon": "mortar", "mount": "turret", "turret_turn_rate_deg": 70.0, "muzzle_height": 1.8,
		"good_vs": ["tank", "ifv"], "weak_vs": ["scout"],
	},
	"lancer": {
		"display_name": "Lancer", "role": "lancer", "unlock_tier": 2, "cost": 190,
		"blurb": "Converted power-utility truck with a long laser. Strips shields and burns tanks at range; runs hot.",
		"hull_size": [2.4, 1.8, 4.2], "max_health": 180, "max_shield": 100,
		"shield_recharge_delay": 4.0, "shield_recharge_rate": 45.0,
		"max_forward_speed": 10.0, "max_reverse_speed": 5.0, "hull_turn_rate_deg": 90.0, "sight_radius": 85.0,
		"weapon": "laser", "mount": "turret", "turret_turn_rate_deg": 90.0, "muzzle_height": 1.9,
		"heat_capacity": 100.0, "heat_dissipation": 14.0,
		"good_vs": ["tank"], "weak_vs": ["scout", "ifv"],
	},
}

## Weapons catalog v2 adds that Weapons.PROFILES doesn't have yet (display only).
const WEAPONS := {
	"autocannon": {"display_name": "30 mm autocannon", "range": 60.0, "damage": 9.0, "reload": 0.35,
			"ammo": 300, "penetration": 0.3},
}

## While the game still loads v1 doctrines, each v2 unit fights as this v1 chassis + weapon. Every stand-in
## costs no more (in v1 points) than the unit does, so a v2 army that fits a budget still fits it in v1.
const V1_STAND_INS := {
	"scout": {"unit": "scout", "weapon": "machine_gun"},
	"ifv": {"unit": "scout", "weapon": "machine_gun"},
	"tank": {"unit": "tank", "weapon": "cannon"},
	"artillery": {"unit": "artillery", "weapon": "mortar"},
	"lancer": {"unit": "scout", "weapon": "laser"},
}
