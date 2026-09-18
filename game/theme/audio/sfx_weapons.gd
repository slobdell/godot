class_name SfxWeapons
extends RefCounted
## What each weapon sounds like, when its fire model is not the whole answer (round 5, after the lead played the
## Syndicate: *"the sound effects were no good they sounded like a cheesy cartoon"*).
##
## `WeaponFx.FAMILIES` picks sounds by **fire model**, which is right for the Condemned — a cannon is a cannon — and
## wrong for a faction whose weapons only share the model's shape. Playing the Syndicate you heard a machine gun from
## a plasma repeater, a mortar tube from guided missiles, and the same ray-gun zap from both the railgun and the
## laser. This table overrides the family per weapon id; anything not listed keeps its family's sound.
##
## Audio owns the mapping; `game/theme/fx/weapon_fx.gd` (render's) asks it for the id it already has in the event.

## weapon id -> {fire, hit, loop} (any key may be missing: the family's sound is used instead).
const BY_WEAPON := {
	# The Syndicate: high-energy, expensive and frightening, never a pitch-swept zap.
	"railgun": {"fire": "railgun_shot", "hit": "energy_hit"},
	"laser": {"fire": "energy_beam", "hit": "energy_hit"},
	"pulse_repeater": {"loop": "plasma_loop", "hit": "energy_hit"},
	"pulse_cannon": {"fire": "pulse_shot", "hit": "energy_hit"},
	"guided_missiles": {"fire": "missile_launch"},
	# The Law's sonic emitter is a stream, but nothing about it is a machine gun.
	"sonic_emitter": {"loop": "sonic_loop", "hit": ""},
}


## The sound for `slot` ("fire", "hit", "loop") of this weapon, or `fallback` (the fire model's) when it has none.
static func sound_for(weapon_id: String, slot: String, fallback: String) -> String:
	var weapon: Dictionary = BY_WEAPON.get(weapon_id, {})
	return String(weapon[slot]) if weapon.has(slot) else fallback


## Every sound this table names (so a test can check they all exist).
static func named_sounds() -> Array:
	var names: Array = []
	for weapon in BY_WEAPON:
		for slot in BY_WEAPON[weapon]:
			var sound := String(BY_WEAPON[weapon][slot])
			if sound != "" and not sound in names:
				names.append(sound)
	return names
