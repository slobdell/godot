// Round 28 (native N6.2): combat resolution's rules in C++ (combat_native.cpp).
#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct CombatConfig {
	bool ready = false;
	double ARC_DEG = 45.0, WEAK_SPOT_ARC_DEG = 25.0, WEAK_SPOT_ARMOR_FRACTION = 0.5, PENETRATION_FLOOR = 0.05,
		   PENETRATION_CAP = 1.5;
	double SHIELD_FACING[3] = { 0.7, 1.0, 1.4 }; // front, side, rear
	int64_t KIND_ARC = 3, KIND_CONE = 1;
	Object *units = nullptr, *armor = nullptr; // Units (armor), Armor (no_damage_on)
	Variant keep_units, keep_armor;
};

struct CombatTerms {
	int face_index = 1; // 0 front, 1 side, 2 rear
	bool weak = false;
	double through = 1.0, shield_factor = 1.0;
};
// The terms both a landing hit and an estimate use (force_side: _damage_estimate's `arcing`).
CombatTerms combat_terms(const CombatConfig &config, Node3D *victim, const Dictionary &weapon, const Vector3 &direction,
		bool force_side);
const String &face_name(int face_index);
// Match._damage_estimate.
double combat_damage_estimate(const CombatConfig &config, Node3D *unit, double raw, const Dictionary &weapon,
		const Vector3 &direction, bool arcing);
// Match._land_hit_result's terms before take_hit: [face (String), weak (bool), through armor, shield factor].
Array combat_hit_terms(const CombatConfig &config, Object *victim, const Dictionary &weapon, const Vector3 &direction);
// Tank.take_hit(raw, shield_multiplier, armor_multiplier) on that tank: {"shield", "hull", "killed"}.
Dictionary combat_take_hit(const CombatConfig &config, Object *tank, double raw, double shield_multiplier,
		double armor_multiplier);

} // namespace godot
