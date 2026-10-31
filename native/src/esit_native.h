// Round 47 (native N4, R47.19): ElementSituation.build's member and contact loops in C++ (esit_native.cpp).
#pragma once

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

struct EsitConsts {
	int64_t FIRE_TICKS = 45;       // ElementSituation.FIRE_TICKS
	double HOLD_THROTTLE = 0.05;   // ElementSituation.HOLD_THROTTLE
	double HOLD_SPEED_MPS = 0.3;   // ElementSituation.HOLD_SPEED_MPS
	double KNOWN_M = 190.0;        // ElementSituation.KNOWN_M
};

// {members, contacts, center, heading, strength, enemy_strength, taking_fire, known}: ElementSituation._entries' answer.
Dictionary esit_entries(Object *game_match, int64_t team, const PackedStringArray &member_names, const Vector3 &heading_in,
		const Dictionary &was_known, const Dictionary &roles, const EsitConsts &c);

} // namespace godot
