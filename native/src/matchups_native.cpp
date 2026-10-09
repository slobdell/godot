// Round 24 (native, N3d): TankBrain.matchups_for (game/ai/tank_brain.gd) as ONE call, with the pure math it runs per
// contact ported line by line: Matchups.time_to_kill / effective_dps / penetration_multiplier / hit_chance / tracking /
// prior / is_weak_spot / deck_gain / duel_advantage (game/ai/matchups.gd) and Armor.facing (game/combat/armor.gd).
// 70 % of decide's cost (121 usec a decide, matchups_for 85; builder0, 1175 real situations). The unit and weapon
// tables are read in place (Units.PROFILES; Weapons.PROFILES while no tuning is set, else Weapons.profile is asked);
// tests/test_native_matchups.gd holds the result to the live matchups_for on real situations, so an edit to any of
// those functions that this file does not follow fails the check.
#include "tank_native.h"

#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/variant/array.hpp>

#include <cmath>

namespace godot {

namespace {

struct MN {
	StringName self{ "self" }, unit{ "unit" }, weapon{ "weapon" }, position{ "position" }, forward{ "forward" },
			velocity{ "velocity" }, health{ "health" }, shield{ "shield" }, mount{ "mount" }, fire_arc_deg{ "fire_arc_deg" },
			max_forward_speed{ "max_forward_speed" }, contacts{ "contacts" }, name{ "name" }, orbiting{ "orbiting" },
			age{ "age" }, exposed_face{ "exposed_face" }, range{ "range" }, min_range{ "min_range" }, reload{ "reload" },
			damage{ "damage" }, burst_count{ "burst_count" }, damage_per_second{ "damage_per_second" },
			shield_multiplier{ "shield_multiplier" }, penetration{ "penetration" }, armor{ "armor" }, rear{ "rear" },
			spread_deg{ "spread_deg" }, splash_radius{ "splash_radius" }, kind{ "kind" },
			hull_turn_rate_deg{ "hull_turn_rate_deg" }, turret_turn_rate_deg{ "turret_turn_rate_deg" }, role{ "role" },
			class_{ "class" }, good_vs{ "good_vs" }, weak_vs{ "weak_vs" }, features{ "features" },
			weak_spots{ "weak_spots" }, kill_rate{ "kill_rate" }, advantage{ "advantage" }, orbit{ "orbit" },
			PROFILES{ "PROFILES" }, DEFAULT{ "DEFAULT" }, tuning{ "tuning" }, profile{ "profile" };
	String fixed{ "fixed" }, turret{ "turret" }, front{ "front" }, side{ "side" }, rear_s{ "rear" };
};
const MN &mn_() {
	static const MN n;
	return n;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double deg_to_rad(double d) {
	return d * (Math::PI / 180.0);
}
inline double rad_to_deg(double r) {
	return r * (180.0 / Math::PI);
}

// Matchups' constants (matchups.gd), checked against the live script by the test (matchups_constants()).
constexpr double PENETRATION_FLOOR = 0.05, PENETRATION_CAP = 1.5, WEAK_SPOT_COS = 0.906307787,
				 WEAK_SPOT_ARMOR_FRACTION = 0.5, TARGET_HALF_WIDTH = 1.2, GOOD_VS = 1.25, WEAK_VS = 0.8,
				 OUT_OF_ARC = 0.3, NEVER = 1.0e9, SHIELD_FRONT = 0.7, SHIELD_SIDE = 1.0, SHIELD_REAR = 1.4;
constexpr int64_t KIND_ARC = 3; // Weapons.Kind.ARC
constexpr double ARMOR_ARC_DEG = 45.0; // Armor.ARC_DEG

struct Geometry {
	double distance = 30.0;
	String face;
	double angular_speed_deg = 0.0;
	bool weak_spot = false;
	bool in_arc = true;
};

double num(const Dictionary &d, const StringName &key, double fallback) {
	const Variant v = d.get(key, fallback);
	return (double)v;
}

// Matchups.penetration_multiplier
double penetration_multiplier(double penetration, double thickness) {
	if (thickness <= 0.0) {
		return PENETRATION_CAP;
	}
	if (penetration <= 0.0) {
		return PENETRATION_FLOOR;
	}
	return clampd(0.5 * std::log(1.6 * penetration / thickness) / std::log(2.0), PENETRATION_FLOOR, PENETRATION_CAP);
}

// Matchups.hit_chance
double hit_chance(const MN &k, const Dictionary &weapon, double distance) {
	const double spread = deg_to_rad(num(weapon, k.spread_deg, 0.0));
	if (spread <= 0.0 || num(weapon, k.splash_radius, 0.0) > 0.0) {
		return 1.0;
	}
	return clampd((TARGET_HALF_WIDTH / MAX(distance, 1.0)) / (1.5 * spread), 0.15, 1.0);
}

// Matchups.tracking
double tracking(const MN &k, const Dictionary &attacker, const Dictionary &weapon, const Geometry &g) {
	const double omega = std::fabs(g.angular_speed_deg);
	if ((int64_t)weapon.get(k.kind, -1) == KIND_ARC) {
		return omega < 5.0 ? 1.0 : 0.6;
	}
	const bool fixed = String(attacker.get(k.mount, k.turret)) == k.fixed;
	const double rate = num(attacker, fixed ? k.hull_turn_rate_deg : k.turret_turn_rate_deg, 110.0);
	double result = rate <= 0.0 ? 1.0 : clampd(1.0 - (omega - 0.5 * rate) / (0.5 * rate), 0.1, 1.0);
	if (fixed && !g.in_arc) {
		result *= OUT_OF_ARC;
	}
	return result;
}

// Matchups.effective_dps
double effective_dps(const MN &k, const Dictionary &attacker, const Dictionary &weapon, const Dictionary &defender,
		const Geometry &g, bool on_shield) {
	const double distance = g.distance;
	if (distance > num(weapon, k.range, 0.0) || distance < num(weapon, k.min_range, 0.0)) {
		return 0.0;
	}
	const double reload = MAX(num(weapon, k.reload, 1.0), 0.05);
	const double per_pull = num(weapon, k.damage, 0.0) * MAX(num(weapon, k.burst_count, 1), 1.0);
	double dps = weapon.has(k.damage_per_second) ? (double)weapon[k.damage_per_second] : per_pull / reload;
	const String &face = g.face;
	if (on_shield) {
		const double facing = face == k.front ? SHIELD_FRONT : (face == k.side ? SHIELD_SIDE : (face == k.rear_s ? SHIELD_REAR : 1.0));
		dps *= num(weapon, k.shield_multiplier, 1.0) * facing;
	} else if (weapon.has(k.penetration) && defender.has(k.armor)) {
		const Dictionary armor = defender[k.armor];
		double thickness = num(armor, face, 1.0);
		if (face == k.rear_s && g.weak_spot) {
			thickness *= WEAK_SPOT_ARMOR_FRACTION;
		}
		dps *= penetration_multiplier((double)weapon[k.penetration], thickness);
	} else if (weapon.has(k.armor)) {
		const Dictionary armor = weapon[k.armor];
		dps *= num(armor, face, 1.0);
	}
	return dps * hit_chance(k, weapon, distance) * tracking(k, attacker, weapon, g);
}

// Matchups.prior
double prior(const MN &k, const Dictionary &attacker, const Dictionary &defender) {
	const String role = defender.get(k.role, defender.get(k.class_, String()));
	if (((Array)attacker.get(k.good_vs, Array())).has(role)) {
		return GOOD_VS;
	}
	if (((Array)attacker.get(k.weak_vs, Array())).has(role)) {
		return WEAK_VS;
	}
	return 1.0;
}

// Matchups.time_to_kill
double time_to_kill(const MN &k, const Dictionary &attacker, const Dictionary &weapon, const Dictionary &defender,
		const Geometry &g, double health, double shield) {
	const double hull_dps = effective_dps(k, attacker, weapon, defender, g, false) * prior(k, attacker, defender);
	if (hull_dps <= 0.0) {
		return NEVER;
	}
	double seconds = health / hull_dps;
	if (shield > 0.0) {
		const double shield_dps = effective_dps(k, attacker, weapon, defender, g, true) * prior(k, attacker, defender);
		seconds += shield_dps <= 0.0 ? NEVER : shield / shield_dps;
	}
	return MIN(seconds, NEVER);
}

// Matchups.duel_advantage
double duel_advantage(double mine, double theirs) {
	if (mine >= NEVER && theirs >= NEVER) {
		return 1.0;
	}
	if (mine >= NEVER) {
		return 0.25;
	}
	return clampd(theirs / mine, 0.25, 4.0);
}

// Matchups.deck_gain
double deck_gain(const MN &k, const Dictionary &weapon, const Dictionary &defender) {
	if (!weapon.has(k.penetration) || !defender.has(k.armor) || (int64_t)weapon.get(k.kind, -1) == KIND_ARC) {
		return 1.0;
	}
	const double penetration = weapon[k.penetration];
	const double rear = num((Dictionary)defender[k.armor], k.rear, 1.0);
	return penetration_multiplier(penetration, rear * WEAK_SPOT_ARMOR_FRACTION) / penetration_multiplier(penetration, rear);
}

// Armor.facing -> its FACING_NAMES string
const String &armor_face(const MN &k, const Vector3 &hull_forward, const Vector3 &shell_direction) {
	const Vector3 forward = Vector3(hull_forward.x, 0, hull_forward.z).normalized();
	const Vector3 toward_shooter = Vector3(-shell_direction.x, 0, -shell_direction.z).normalized();
	const double alignment = forward.dot(toward_shooter);
	const double arc = std::cos(deg_to_rad(ARMOR_ARC_DEG));
	if (alignment >= arc) {
		return k.front;
	}
	if (alignment <= -arc) {
		return k.rear_s;
	}
	return k.side;
}

// Matchups.is_weak_spot
bool is_weak_spot(const Vector3 &hull_forward, const Vector3 &shell_direction) {
	const Vector2 forward = Vector2(hull_forward.x, hull_forward.z).normalized();
	return (double)forward.dot(Vector2(shell_direction.x, shell_direction.z).normalized()) >= WEAK_SPOT_COS;
}

} // namespace

PackedFloat64Array TankNative::matchups_constants() const {
	PackedFloat64Array c;
	for (double v : { PENETRATION_FLOOR, PENETRATION_CAP, WEAK_SPOT_COS, WEAK_SPOT_ARMOR_FRACTION, TARGET_HALF_WIDTH,
				 GOOD_VS, WEAK_VS, OUT_OF_ARC, NEVER, SHIELD_FRONT, SHIELD_SIDE, SHIELD_REAR, (double)KIND_ARC, ARMOR_ARC_DEG }) {
		c.push_back(v);
	}
	return c;
}

// constants: [ORBIT_RADIUS, ORBIT_MEMORY_TICKS, CONTACT_FRESH_TICKS, DECK_SEEK_GAIN]; units / weapons: the Units and
// Weapons scripts (their PROFILES, Weapons' DEFAULT and tuning, and Weapons.profile when tuning is set).
Dictionary TankNative::matchups_for(const Dictionary &s, Object *units, Object *weapons, const PackedFloat64Array &constants) const {
	const MN &k = mn_();
	Dictionary result;
	if (units == nullptr || weapons == nullptr || constants.size() < 4) {
		return result;
	}
	const double ORBIT_RADIUS = constants[0];
	const int64_t ORBIT_MEMORY_TICKS = (int64_t)constants[1];
	const int64_t CONTACT_FRESH_TICKS = (int64_t)constants[2];
	const double DECK_SEEK_GAIN = constants[3];
	const Dictionary unit_profiles = units->get(k.PROFILES);
	const Dictionary me = s[k.self];
	const Dictionary my_profile = unit_profiles.get(String(me.get(k.unit, String())), Dictionary());
	if (my_profile.is_empty()) {
		return result;
	}
	const Dictionary weapon_profiles = weapons->get(k.PROFILES);
	const bool tuned = !((Dictionary)weapons->get(k.tuning)).is_empty();
	const String default_weapon = weapons->get(k.DEFAULT);
	const Dictionary weapon = me[k.weapon];
	const Vector3 my_position = me[k.position];
	const Vector3 my_forward = me[k.forward];
	const Vector3 my_velocity = me.get(k.velocity, Vector3());
	const double my_health = me[k.health];
	const double my_shield = me.get(k.shield, 0.0);
	const bool fixed = String(my_profile.get(k.mount, k.turret)) == k.fixed;
	const double half_arc_cos = 1.0 - 0.5 * std::pow(deg_to_rad(num(my_profile, k.fire_arc_deg, 360.0) / 2.0), 2.0);
	const double orbit_rate_deg = rad_to_deg(num(my_profile, k.max_forward_speed, 0.0) / ORBIT_RADIUS);
	const String orbiting = s.get(k.orbiting, String());
	const Dictionary features = s.get(k.features, Dictionary());
	const Array contacts = s[k.contacts];
	for (int64_t i = 0; i < contacts.size(); i++) {
		const Dictionary c = contacts[i];
		const Dictionary their_profile = unit_profiles.get(String(c.get(k.unit, String())), Dictionary());
		const int64_t fresh = String(c[k.name]) == orbiting ? ORBIT_MEMORY_TICKS : CONTACT_FRESH_TICKS;
		if (their_profile.is_empty() || (int64_t)c[k.age] > fresh) {
			continue;
		}
		const Vector3 position = c[k.position];
		const Vector3 offset((real_t)((double)position.x - (double)my_position.x), 0,
				(real_t)((double)position.z - (double)my_position.z));
		const double distance = MAX((double)offset.length(), 0.1);
		const Vector3 bearing = offset / (real_t)distance;
		const Vector3 relative = (Vector3)c[k.velocity] - my_velocity;
		const double omega_deg = rad_to_deg(std::fabs((double)relative.x * (double)bearing.z - (double)relative.z * (double)bearing.x) / distance);
		const Vector3 their_forward = c[k.forward];
		Geometry mine;
		mine.distance = distance;
		mine.face = c[k.exposed_face];
		mine.angular_speed_deg = omega_deg;
		mine.weak_spot = is_weak_spot(their_forward, bearing);
		mine.in_arc = !fixed || (double)Vector2(my_forward.x, my_forward.z).normalized().dot(Vector2(bearing.x, bearing.z)) >= half_arc_cos;
		const double their_arc_cos = 1.0 - 0.5 * std::pow(deg_to_rad(num(their_profile, k.fire_arc_deg, 360.0) / 2.0), 2.0);
		Geometry theirs;
		theirs.distance = distance;
		theirs.face = armor_face(k, my_forward, bearing);
		theirs.angular_speed_deg = omega_deg;
		theirs.in_arc = String(their_profile.get(k.mount, k.turret)) != k.fixed ||
				(double)Vector2(their_forward.x, their_forward.z).normalized().dot(Vector2(-bearing.x, -bearing.z)) >= their_arc_cos;
		// Weapons.profile(String(c.get("weapon", their_profile.get("weapon", "")))): the table entry (or DEFAULT's)
		// while no tuning is set; the live function otherwise.
		const String their_weapon_id = c.get(k.weapon, their_profile.get(k.weapon, String()));
		Dictionary their_weapon;
		if (tuned) {
			their_weapon = weapons->call(k.profile, their_weapon_id);
		} else {
			their_weapon = weapon_profiles.get(weapon_profiles.has(their_weapon_id) ? their_weapon_id : default_weapon, Dictionary());
		}
		const double c_health = c[k.health];
		const double c_shield = c.get(k.shield, 0.0);
		double my_ttk = time_to_kill(k, my_profile, weapon, their_profile, mine, c_health, c_shield);
		const bool orbit = fixed && String(their_profile.get(k.mount, k.turret)) == k.turret &&
				num(their_profile, k.turret_turn_rate_deg, 360.0) < orbit_rate_deg * 0.8 &&
				(int64_t)their_weapon.get(k.kind, -1) != KIND_ARC && distance <= (double)weapon[k.range] + 25.0;
		if (orbit) {
			const double close = MIN(distance, ORBIT_RADIUS + 5.0);
			const bool deck = (bool)features.get(k.weak_spots, false) && deck_gain(k, weapon, their_profile) >= DECK_SEEK_GAIN;
			Geometry orbiting_geometry;
			orbiting_geometry.distance = close;
			orbiting_geometry.face = (String(c[k.exposed_face]) == k.rear_s || deck) ? k.rear_s : k.side;
			orbiting_geometry.angular_speed_deg = orbit_rate_deg;
			orbiting_geometry.in_arc = true;
			orbiting_geometry.weak_spot = deck;
			theirs.distance = close;
			theirs.face = k.side;
			theirs.angular_speed_deg = orbit_rate_deg;
			my_ttk = time_to_kill(k, my_profile, weapon, their_profile, orbiting_geometry, c_health, c_shield);
		}
		const double their_ttk = time_to_kill(k, their_profile, their_weapon, my_profile, theirs, my_health, my_shield);
		const double advantage = duel_advantage(my_ttk, their_ttk);
		Dictionary entry;
		entry[k.kill_rate] = my_ttk >= NEVER ? 0.0 : 1.0 / my_ttk;
		entry[k.advantage] = advantage;
		entry[k.orbit] = orbit;
		result[c[k.name]] = entry;
	}
	return result;
}

} // namespace godot
