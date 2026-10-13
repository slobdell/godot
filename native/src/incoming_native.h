// Round 28 (native N7.1): Match.incoming_projectiles (contract K2, game/match/match.gd) in C++: the rounds in flight
// that will reach a unit if it holds still, soonest first, with their damage estimates (Match._damage_estimate over
// combat_native's terms). Pure geometry over the shells and the lobbed rounds, line by line in the GDScript's widths.
// tests/test_native_incoming.gd holds it to the live function; native-proof `incoming` the match.
#pragma once

#include "combat_native.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct IncomingConfig {
	bool ready = false;
	double INCOMING_MARGIN = 1.0, ARC_HEIGHT = 6.0, TICK_RATE = 30.0;
	String SITE = "incoming", DEFAULT_WEAPON = "cannon";
	Object *units = nullptr, *weapons = nullptr; // Units (stat, hull_disc_at), Weapons (profile)
	Variant shell_script, tank_script; // the Shell and Tank classes: `node as Shell`, `as Tank`
	Callable order; // the threats' sort (Match's own comparator, so Godot's sort orders them)
	const CombatConfig *combat = nullptr;
	Variant keep_units, keep_weapons;
};

Array incoming_projectiles(const IncomingConfig &config, Object *game_match, Object *unit);

} // namespace godot
