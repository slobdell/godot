// Round 28 (native N6.2): combat resolution's rules in C++ -- what Match._land_hit_result computes before the hit lands
// (Armor.facing, the weak spot, Armor.penetration_multiplier over Units.armor, the shield factor) and Tank.take_hit's
// arithmetic (Armor.split_shield, the shield, the damage accumulator). Line by line in the GDScript's widths
// (game/combat/armor.gd, game/match/match.gd, game/tank/tank.gd). Kept GDScript: Units.armor's lookup (its tuning),
// Armor.no_damage_on, apply_damage and _publish_state (they emit signals), every stat, score and announcement.
// tests/test_native_combat.gd holds both to the live functions; native-proof `combat` the match.
#include "combat_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>

namespace godot {

namespace {

struct CN {
	StringName kind{ "kind" }, penetration{ "penetration" }, shield_multiplier{ "shield_multiplier" }, armor{ "armor" },
			unit_id{ "unit_id" }, alive{ "alive" }, shield{ "shield" }, ticks_since_hit{ "ticks_since_hit" },
			damage_accumulator{ "damage_accumulator" }, health{ "health" }, apply_damage{ "apply_damage" },
			_publish_state{ "_publish_state" }, no_damage_on{ "no_damage_on" };
	String front{ "front" }, side{ "side" }, rear{ "rear" }, r_shield{ "shield" }, r_hull{ "hull" }, r_killed{ "killed" };
};
const CN &cn_() {
	static const CN names;
	return names;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double deg_to_rad(double deg) {
	return deg * (Math::PI / 180.0);
}

// Armor.facing: 0 FRONT, 1 SIDE, 2 REAR
int facing(const CombatConfig &c, const Vector3 &hull_forward, const Vector3 &shell_direction) {
	const Vector3 forward = Vector3(hull_forward.x, 0, hull_forward.z).normalized();
	const Vector3 toward_shooter = Vector3(-shell_direction.x, 0, -shell_direction.z).normalized();
	const double alignment = forward.dot(toward_shooter);
	const double arc = std::cos(deg_to_rad(c.ARC_DEG));
	if (alignment >= arc) {
		return 0;
	}
	if (alignment <= -arc) {
		return 2;
	}
	return 1;
}

// Armor.is_weak_spot
bool is_weak_spot(const CombatConfig &c, const Vector3 &hull_forward, const Vector3 &shell_direction) {
	const Vector3 forward = Vector3(hull_forward.x, 0, hull_forward.z).normalized();
	const Vector3 travel = Vector3(shell_direction.x, 0, shell_direction.z).normalized();
	return (double)forward.dot(travel) >= std::cos(deg_to_rad(c.WEAK_SPOT_ARC_DEG));
}

// Armor.penetration_multiplier
double penetration_multiplier(const CombatConfig &c, double penetration, double thickness) {
	if (thickness <= 0.0) {
		return c.PENETRATION_CAP;
	}
	if (penetration <= 0.0) {
		return c.PENETRATION_FLOOR;
	}
	return clampd(0.5 * std::log(1.6 * penetration / thickness) / std::log(2.0), c.PENETRATION_FLOOR, c.PENETRATION_CAP);
}

// Armor.split_shield -> Vector2 (float32, as the GDScript returns it)
Vector2 split_shield(double raw, double shield, double shield_multiplier, double armor_multiplier) {
	const double against_shield = raw * shield_multiplier;
	if (shield <= 0.0 || against_shield <= 0.0) {
		return Vector2(0.0f, (real_t)(raw * armor_multiplier));
	}
	if (against_shield <= shield) {
		return Vector2((real_t)against_shield, 0.0f);
	}
	const double absorbed_fraction = shield / against_shield;
	return Vector2((real_t)shield, (real_t)(raw * (1.0 - absorbed_fraction) * armor_multiplier));
}

} // namespace

CombatTerms combat_terms(const CombatConfig &c, Node3D *victim, const Dictionary &weapon, const Vector3 &direction,
		bool force_side) {
	const CN &k = cn_();
	CombatTerms t;
	//   forward := -victim.global_basis.z; face := FACING_NAMES[Armor.facing(forward, direction)]
	//   force_side -- weapon["kind"] == ARC (the hit's terms) / `arcing` (_damage_estimate): face = "side", no weak spot
	//   weak := is_weak_spot_hit(weapon, forward, direction)    (not ARC, not CONE, Armor.is_weak_spot)
	//   through := weak_spot_multiplier(weapon, unit) if weak else armor_multiplier(weapon, unit, face)
	//   shield factor := float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[face])
	const Vector3 forward = -victim->get_global_transform().basis.get_column(2);
	const int64_t kind = weapon.get(k.kind, -1);
	t.face_index = force_side ? 1 : facing(c, forward, direction);
	t.weak = !force_side && kind != c.KIND_ARC && kind != c.KIND_CONE && is_weak_spot(c, forward, direction);
	const String unit = victim->get(k.unit_id);
	const double penetration = weapon.get(k.penetration, 0.0);
	if (t.weak) {
		t.through = penetration_multiplier(c, penetration, (double)c.units->call(k.armor, unit, k.rear) * c.WEAK_SPOT_ARMOR_FRACTION);
	} else {
		t.through = penetration_multiplier(c, penetration, c.units->call(k.armor, unit, face_name(t.face_index)));
	}
	t.shield_factor = (double)weapon.get(k.shield_multiplier, 1.0) * c.SHIELD_FACING[t.face_index];
	return t;
}

const String &face_name(int face_index) {
	const CN &k = cn_();
	return face_index == 0 ? k.front : (face_index == 1 ? k.side : k.rear);
}

Array combat_hit_terms(const CombatConfig &c, Object *victim_object, const Dictionary &weapon, const Vector3 &direction) {
	Array out;
	Node3D *victim = Object::cast_to<Node3D>(victim_object);
	if (!c.ready || victim == nullptr) {
		return out;
	}
	const CombatTerms t = combat_terms(c, victim, weapon, direction, (int64_t)weapon[cn_().kind] == c.KIND_ARC);
	out.push_back(face_name(t.face_index));
	out.push_back(t.weak);
	out.push_back(t.through);
	out.push_back(t.shield_factor);
	return out;
}

// Match._damage_estimate(unit, raw, weapon, direction, arcing): shield + hull points, no state change.
double combat_damage_estimate(const CombatConfig &c, Node3D *unit, double raw, const Dictionary &weapon,
		const Vector3 &direction, bool arcing) {
	const CombatTerms t = combat_terms(c, unit, weapon, direction, arcing);
	const Vector2 split = split_shield(raw, unit->get(cn_().shield), t.shield_factor, t.through);
	return (double)split.x + (double)split.y;
}

Dictionary combat_take_hit(const CombatConfig &c, Object *tank, double raw, double shield_multiplier, double armor_multiplier) {
	const CN &k = cn_();
	Dictionary result;
	//   if not alive or raw <= 0.0 or Armor.no_damage_on(): return {"shield": 0.0, "hull": 0, "killed": false}
	if (!(bool)tank->get(k.alive) || raw <= 0.0 || (bool)c.armor->call(k.no_damage_on)) {
		result[k.r_shield] = 0.0;
		result[k.r_hull] = 0;
		result[k.r_killed] = false;
		return result;
	}
	tank->set(k.ticks_since_hit, 0);
	const double shield_now = tank->get(k.shield);
	const Vector2 split = split_shield(raw, shield_now, shield_multiplier, armor_multiplier);
	double shield = shield_now - (double)split.x;
	if (shield < 0.01) {
		shield = 0.0;
	}
	tank->set(k.shield, shield);
	double accumulator = (double)tank->get(k.damage_accumulator) + (double)split.y;
	const int64_t whole = (int64_t)(accumulator + 0.0001);
	accumulator = MAX(0.0, accumulator - (double)whole);
	tank->set(k.damage_accumulator, accumulator);
	const int64_t health = tank->get(k.health);
	const int64_t hull = MIN(whole, health);
	bool killed = false;
	if (whole > 0) {
		killed = tank->call(k.apply_damage, whole);
	} else {
		tank->call(k._publish_state);
	}
	result[k.r_shield] = (double)split.x;
	result[k.r_hull] = hull;
	result[k.r_killed] = killed;
	return result;
}

} // namespace godot
