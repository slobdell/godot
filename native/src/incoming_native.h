// Round 28 (native N7.1): Match.incoming_projectiles (contract K2, game/match/match.gd) in C++: the rounds in flight
// that will reach a unit if it holds still, soonest first, with their damage estimates (Match._damage_estimate over
// combat_native's terms). Pure geometry over the shells and the lobbed rounds, line by line in the GDScript's widths.
// tests/test_native_incoming.gd holds it to the live function; native-proof `incoming` the match.
#pragma once

#include "combat_native.h"

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct IncomingConfig {
	bool ready = false;
	double INCOMING_MARGIN = 1.0, ARC_HEIGHT = 6.0, TICK_RATE = 30.0;
	double HORIZON_TICKS = 45.0, DANGER_RADIUS = 6.0; // IncomingFire's own filter (the count)
	String SITE = "incoming", COUNT_SITE = "squad_incoming", DEFAULT_WEAPON = "cannon";
	Object *units = nullptr, *weapons = nullptr; // Units (stat, hull_disc_at), Weapons (profile)
	Variant shell_script, tank_script; // the Shell and Tank classes: `node as Shell`, `as Tank`
	Callable order; // the threats' sort (Match's own comparator, so Godot's sort orders them)
	const CombatConfig *combat = nullptr;
	Variant keep_units, keep_weapons;
};

Array incoming_projectiles(const IncomingConfig &config, Object *game_match, Object *unit);
// IncomingFire._count_in_flight(game_match, unit) over the tick's shell columns (AiTickCache.flight): how many rounds
// are on their way at `unit`. `halves` caches each unit id's (half width, half length), a process constant.
int64_t incoming_count(const IncomingConfig &config, HashMap<String, Vector2> &halves, Object *unit, const Dictionary &columns);

} // namespace godot
