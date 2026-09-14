class_name Units
extends RefCounted
## The unit catalog: vehicle classes as DATA (like Weapons.PROFILES). Schema v0, written
## 2026-09-14 so the gameplay and garage streams share one vocabulary from the start.
##
## Owned by the gameplay stream (_agents/streams/gameplay.md, directive set 2), which will
## grow it (scout, artillery, components, real costs) and wire it into Tank/Match. Nothing in
## the simulation reads it yet. The garage stream reads it to build army/loadout UI.
##
## Keep existing keys stable. Renaming or removing one is a contract change (_agents/workstreams.md).

const SCHEMA_VERSION := 0

## Points a player spends on an army per match (placeholder until gameplay tunes it).
const DEFAULT_BUDGET := 1000

const PROFILES := {
	"tank": {
		"display_name": "Tank",
		"cost": 200,
		# Mirrors today's Tank exports and Match constants; gameplay makes these authoritative.
		"max_health": 400,
		"max_shield": 0,
		"max_forward_speed": 9.0,
		"hull_turn_rate_deg": 80.0,
		"sight_radius": 75.0,
		# Each hardpoint lists the weapon ids (Weapons.PROFILES) it accepts.
		"hardpoints": [{"id": "main", "accepts": ["cannon", "flamethrower"]}],
		# Component slots (heat sinks, extra ammo, shield boosters…) arrive with directive set 2.
		"component_slots": 0,
	},
}


static func exists(unit_id: String) -> bool:
	return PROFILES.has(unit_id)


static func profile(unit_id: String) -> Dictionary:
	return PROFILES.get(unit_id, {})
