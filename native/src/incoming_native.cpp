// Round 28 (native N7.1): Match.incoming_projectiles in C++ (incoming_native.h).
#include "incoming_native.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>

namespace godot {

namespace {

struct IN {
	StringName alive{ "alive" }, unit_id{ "unit_id" }, stat{ "stat" }, hull_disc_at{ "hull_disc_at" }, shells{ "shells" },
			tanks{ "tanks" }, _rounds{ "_rounds" }, tick{ "tick" }, shooter_name{ "shooter_name" }, speed{ "speed" },
			direction{ "direction" }, max_range{ "max_range" }, _travelled{ "_travelled" }, projectile_id{ "projectile_id" },
			weapon{ "weapon" }, weapon_id{ "weapon_id" }, profile{ "profile" };
	// Dictionary keys: Strings, as the GDScript's literals
	String hull_size{ "hull_size" }, position{ "position" }, velocity{ "velocity" }, eta_ticks{ "eta_ticks" },
			k_projectile_id{ "projectile_id" }, k_weapon{ "weapon" }, damage_estimate{ "damage_estimate" }, damage{ "damage" },
			shooter{ "shooter" }, to{ "to" }, from{ "from" }, splash_radius{ "splash_radius" }, land_tick{ "land_tick" },
			fire_tick{ "fire_tick" }, k_weapon_id{ "weapon_id" }, x{ "x" }, z{ "z" }, dir_x{ "dir_x" }, dir_z{ "dir_z" },
			vx{ "vx" }, vz{ "vz" }, reach{ "reach" }, c_shooter{ "shooter" };
};
const IN &in_() {
	static const IN names;
	return names;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

// Units.hull_reach_of(half, hull_forward, direction, site), its disc answer asked once a query (hull_disc_at(site))
double hull_reach(bool disc, const Vector2 &half, const Vector3 &hull_forward, const Vector3 &direction) {
	if (disc) {
		return half.length();
	}
	Vector2 forward(hull_forward.x, hull_forward.z);
	forward = (double)forward.length_squared() > 0.0001 ? forward.normalized() : Vector2(0, -1);
	Vector2 axis(direction.x, direction.z);
	axis = (double)axis.length_squared() > 0.0001 ? axis.normalized() : Vector2(0, -1);
	const Vector2 right(-forward.y, forward.x);
	return (double)half.x * std::fabs((double)axis.dot(right)) + (double)half.y * std::fabs((double)axis.dot(forward));
}

// Units.hull_distance_of(half, hull_forward, hull_origin, line_origin, line_direction, site)
double hull_distance(bool disc, const Vector2 &half, const Vector3 &hull_forward, const Vector3 &hull_origin,
		const Vector3 &line_origin, const Vector3 &line_direction) {
	Vector2 along(line_direction.x, line_direction.z);
	along = (double)along.length_squared() > 0.0001 ? along.normalized() : Vector2(0, -1);
	const Vector2 normal(-along.y, along.x);
	const Vector2 offset((real_t)((double)hull_origin.x - (double)line_origin.x), (real_t)((double)hull_origin.z - (double)line_origin.z));
	return MAX(std::fabs((double)offset.dot(normal)) - hull_reach(disc, half, hull_forward, Vector3(normal.x, 0, normal.y)), 0.0);
}

// ArcRoundVisual.point_at(start, end, t)
Vector3 point_at(double arc_height, const Vector3 &start, const Vector3 &end, double t) {
	const double flat = Vector2((real_t)((double)end.x - (double)start.x), (real_t)((double)end.z - (double)start.z)).length();
	return start.lerp(end, (real_t)t) + Vector3(0, 1, 0) * (real_t)(4.0 * arc_height * flat * t * (1.0 - t));
}

} // namespace

Array incoming_projectiles(const IncomingConfig &c, Object *match_object, Object *unit_object) {
	const IN &k = in_();
	Array threats;
	Node *game_match = Object::cast_to<Node>(match_object);
	Node3D *unit = Object::cast_to<Node3D>(unit_object);
	//   if unit == null or not unit.is_alive(): return threats
	if (!c.ready || game_match == nullptr || unit == nullptr || !(bool)unit->get(k.alive)) {
		return threats;
	}
	const Vector3 unit_position = unit->get_global_position();
	const Vector2 here(unit_position.x, unit_position.z);
	const Array hull_size = c.units->call(k.stat, unit->get(k.unit_id), k.hull_size);
	const Vector2 half((real_t)((double)hull_size[0] * 0.5), (real_t)((double)hull_size[2] * 0.5));
	const Vector3 forward = -unit->get_global_transform().basis.get_column(2);
	const bool disc = c.units->call(k.hull_disc_at, c.SITE);
	const String name = unit->get_name();
	Node *shells = Object::cast_to<Node>((Object *)game_match->get(k.shells));
	Node *tanks = Object::cast_to<Node>((Object *)game_match->get(k.tanks));
	const int64_t tick = game_match->get(k.tick);
	if (shells != nullptr) {
		const int count = shells->get_child_count();
		for (int i = 0; i < count; i++) {
			Node3D *shell = Object::cast_to<Node3D>(shells->get_child(i));
			//   shell == null or not shell.in_flight() or shell.shooter_name == String(unit.name) or shell.speed <= 0.0
			if (shell == nullptr || shell->get_script() != c.shell_script) {
				continue;
			}
			if (!(shell->is_physics_processing() && !shell->is_queued_for_deletion())) {
				continue;
			}
			if (String(shell->get(k.shooter_name)) == name) {
				continue;
			}
			const double speed = shell->get(k.speed);
			if (speed <= 0.0) {
				continue;
			}
			const Vector3 shell_position = shell->get_global_position();
			const Vector3 shell_direction = shell->get(k.direction);
			const Vector2 from(shell_position.x, shell_position.z);
			const Vector2 direction = Vector2(shell_direction.x, shell_direction.z).normalized();
			const Vector2 offset = here - from;
			const double along = offset.dot(direction);
			const Vector3 flat_direction(direction.x, 0, direction.y);
			const double remaining = MAX(0.0, (double)shell->get(k.max_range) - (double)shell->get(k._travelled));
			const double reach = hull_reach(disc, half, forward, flat_direction);
			if (along <= 0.0 || along > remaining + reach) {
				continue;
			}
			if (hull_distance(disc, half, forward, unit_position, Vector3(from.x, 0, from.y), flat_direction) > c.INCOMING_MARGIN) {
				continue;
			}
			const String shooter_name = shell->get(k.shooter_name);
			Node *shooter = tanks != nullptr ? tanks->get_node_or_null(NodePath(shooter_name)) : nullptr;
			if (shooter != nullptr && shooter->get_script() != c.tank_script) {
				shooter = nullptr; // `as Tank`
			}
			const Dictionary weapon = shooter != nullptr ? (Dictionary)shooter->get(k.weapon)
														 : (Dictionary)c.weapons->call(k.profile, c.DEFAULT_WEAPON);
			Dictionary threat;
			threat[k.position] = shell_position;
			threat[k.velocity] = shell_direction * (real_t)speed;
			threat[k.eta_ticks] = (int64_t)std::ceil(MAX(0.0, along - reach) / speed * c.TICK_RATE);
			threat[k.k_projectile_id] = shell->get(k.projectile_id);
			threat[k.k_weapon] = shooter != nullptr ? (Variant)shooter->get(k.weapon_id) : (Variant)c.DEFAULT_WEAPON;
			threat[k.damage_estimate] = combat_damage_estimate(*c.combat, unit, (double)weapon[k.damage], weapon,
					shell_direction, false);
			threats.push_back(threat);
		}
	}
	const Array rounds = game_match->get(k._rounds);
	for (int64_t i = 0; i < rounds.size(); i++) {
		const Dictionary flying = rounds[i];
		if (String(flying[k.shooter]) == name) {
			continue;
		}
		const Dictionary weapon = flying[k.k_weapon];
		const Vector3 landing = flying[k.to];
		const double distance = here.distance_to(Vector2(landing.x, landing.z));
		const double splash = weapon[k.splash_radius];
		if (distance > splash + hull_reach(disc, half, forward,
										 Vector3((real_t)((double)unit_position.x - (double)landing.x), 0,
												 (real_t)((double)unit_position.z - (double)landing.z)))) {
			continue;
		}
		const Vector3 from = flying[k.from];
		const int64_t land_tick = flying[k.land_tick], fire_tick = flying[k.fire_tick];
		const int64_t flight = MAX((int64_t)1, land_tick - fire_tick);
		const double fraction = clampd((double)(tick - fire_tick) / (double)flight, 0.0, 1.0);
		const double t = clampd(distance / MAX(splash, 0.01), 0.0, 1.0);
		const double falloff = 1.0 + (0.3 - 1.0) * t; // lerpf(1.0, 0.3, t)
		Dictionary threat;
		threat[k.position] = point_at(c.ARC_HEIGHT, from, landing, fraction);
		threat[k.velocity] = Vector3((real_t)((double)landing.x - (double)from.x), 0, (real_t)((double)landing.z - (double)from.z)) /
				(real_t)((double)flight / c.TICK_RATE);
		threat[k.eta_ticks] = MAX((int64_t)0, land_tick - tick);
		threat[k.k_projectile_id] = (int64_t)flying.get(k.k_projectile_id, -1);
		threat[k.k_weapon] = String(flying.get(k.k_weapon_id, ""));
		threat[k.damage_estimate] = combat_damage_estimate(*c.combat, unit, (double)weapon[k.damage] * falloff, weapon,
				forward, true);
		threats.push_back(threat);
	}
	threats.sort_custom(c.order);
	return threats;
}

int64_t incoming_count(const IncomingConfig &c, HashMap<String, Vector2> &halves, Object *unit_object, const Dictionary &shells) {
	const IN &k = in_();
	Node3D *unit = Object::cast_to<Node3D>(unit_object);
	//   if not unit.is_alive(): return 0; xs := shells["x"]; if xs.is_empty(): return 0
	if (!c.ready || unit == nullptr || !(bool)unit->get(k.alive)) {
		return 0;
	}
	const PackedFloat32Array xs = shells[k.x];
	if (xs.is_empty()) {
		return 0;
	}
	const PackedFloat32Array zs = shells[k.z], dir_x = shells[k.dir_x], dir_z = shells[k.dir_z], vxs = shells[k.vx],
							 vzs = shells[k.vz];
	const PackedFloat64Array reach = shells[k.reach];
	const PackedStringArray shooters = shells[k.c_shooter];
	const String unit_id = unit->get(k.unit_id);
	Vector2 half;
	if (const Vector2 *known = halves.getptr(unit_id)) {
		half = *known;
	} else {
		const Array hull_size = c.units->call(k.stat, unit_id, k.hull_size);
		half = Vector2((real_t)((double)hull_size[0] * 0.5), (real_t)((double)hull_size[2] * 0.5));
		halves.insert(unit_id, half);
	}
	const bool disc = c.units->call(k.hull_disc_at, c.COUNT_SITE);
	const Vector3 forward = -unit->get_global_transform().basis.get_column(2);
	const String name = unit->get_name();
	const Vector3 position = unit->get_global_position();
	const double here_x = position.x, here_z = position.z;
	int64_t count = 0;
	for (int64_t i = 0; i < xs.size(); i++) {
		// Match.incoming_projectiles, in Vector2 math on the same float values.
		const Vector2 offset = Vector2((real_t)here_x, (real_t)here_z) - Vector2(xs[i], zs[i]);
		const Vector2 direction(dir_x[i], dir_z[i]);
		const double along = offset.dot(direction);
		const Vector3 flat_direction(direction.x, 0, direction.y);
		if (along <= 0.0 || along > reach[i] + hull_reach(disc, half, forward, flat_direction)) {
			continue;
		}
		if (shooters[i] == name || hull_distance(disc, half, forward, position, Vector3(xs[i], 0, zs[i]), flat_direction) >
										   c.INCOMING_MARGIN) {
			continue;
		}
		// for_unit's own filter, on the round's flat velocity.
		const Vector3 flat(vxs[i], 0, vzs[i]);
		const double speed_squared = flat.length_squared();
		if (speed_squared < 1.0) {
			continue;
		}
		const Vector3 offset3((real_t)(here_x - (double)xs[i]), 0, (real_t)(here_z - (double)zs[i]));
		const double seconds = (double)offset3.dot(flat) / speed_squared;
		if (seconds <= 0.0 || seconds * c.TICK_RATE > c.HORIZON_TICKS) {
			continue;
		}
		if ((double)(offset3 - flat * (real_t)seconds).length() > c.DANGER_RADIUS) {
			continue;
		}
		count++;
	}
	return count;
}

} // namespace godot
