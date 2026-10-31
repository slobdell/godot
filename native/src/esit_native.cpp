// Round 47 (native N4, R47.19): ElementSituation.build's member loop and intel-contact loop (game/tactics/element_situation.gd) as
// ONE call. His Crossing (builder3 light, probe c22464f11, n 1): build 0.54 ms a tick, ~0.3 of it these two loops (a dictionary of
// ~20 Tank reads per crew, one per known contact, the sort). Line by line with the GDScript: Vector3 / Vector2 math in real_t, the
// GDScript's floats in double, the same keys in the same order. Units.role_of arrives as a unit -> role table (NativeEsit builds it
// once). The rest of build (shots_into, terrain, the lambdas) stays GDScript. tests/test_native_esit.gd and TANK_NATIVE_ESIT_VERIFY
// hold it to the live GDScript; NativeEsit (game/ai/native/native_esit.gd) is the seam.
#include "esit_native.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

namespace godot {

namespace {

struct EK {
	StringName tanks{ "tanks" }, intel{ "intel" }, tick{ "tick" }, alive{ "alive" }, ticks_since_hit{ "ticks_since_hit" },
			health{ "health" }, max_health{ "max_health" }, shield{ "shield" }, max_shield{ "max_shield" }, unit_id{ "unit_id" },
			max_forward_speed{ "max_forward_speed" }, weapon{ "weapon" }, sight_radius{ "sight_radius" },
			suppression{ "suppression" }, deploy_ratio{ "deploy_ratio" }, command{ "command" }, throttle{ "throttle" },
			real_velocity{ "real_velocity" }, intent{ "intent" };
	String name{ "name" }, position{ "position" }, forward{ "forward" }, role{ "role" }, unit{ "unit" }, speed{ "speed" },
			range{ "range" }, effective_range{ "effective_range" }, preferred_min{ "preferred_min" }, sight{ "sight" },
			health_k{ "health" }, suppression_k{ "suppression" }, taking_fire{ "taking_fire" }, deployed{ "deployed" },
			since_hit{ "since_hit" }, left{ "left" }, holding{ "holding" }, intent_k{ "intent" }, visible{ "visible" },
			age{ "age" }, distance{ "distance" }, bearing_deg{ "bearing_deg" }, strength{ "strength" }, velocity{ "velocity" },
			seen_tick{ "seen_tick" }, shield_k{ "shield" }, tank{ "tank" }, members{ "members" }, contacts{ "contacts" },
			center{ "center" }, heading{ "heading" }, enemy_strength{ "enemy_strength" }, known{ "known" };
};
const EK &ek() {
	static const EK k;
	return k;
}

double clampd(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
double maxd(double a, double b) { return a > b ? a : b; }

Vector3 flat_point(const Vector3 &p) { return Vector3(p.x, 0.0f, p.z); } // ElementSituation._flat

// TacticsFormation.flat
Vector3 flat_dir(const Vector3 &d) {
	const Vector3 f(d.x, 0.0f, d.z);
	return (double)f.length_squared() < 1e-6 ? Vector3(0, 0, -1) : f.normalized();
}

// ElementSituation.bearing_deg(heading, offset)
double bearing_deg(const Vector3 &heading, const Vector3 &offset) {
	const Vector3 forward = flat_dir(heading);
	const Vector3 right(-forward.z, 0.0f, forward.x);
	const Vector3 flat_offset = flat_point(offset);
	if ((double)flat_offset.length_squared() < 1e-6) {
		return 0.0;
	}
	return std::atan2((double)flat_offset.dot(right), (double)flat_offset.dot(forward)) * (180.0 / 3.1415926535897932384626433833);
}

} // namespace

Dictionary esit_entries(Object *game_match, int64_t team, const PackedStringArray &member_names, const Vector3 &heading_in,
		const Dictionary &was_known, const Dictionary &roles, const EsitConsts &c) {
	const EK &k = ek();
	Dictionary out;
	Array members;
	Vector3 center;
	Vector3 heading = heading_in;
	double strength = 0.0;
	bool taking_fire = false;
	Node *tanks = Object::cast_to<Node>(game_match->get(k.tanks).get_validated_object());
	std::vector<Vector3> forwards;
	for (int64_t i = 0; i < member_names.size(); i++) {
		const String unit_name = member_names[i];
		if (tanks == nullptr) {
			continue;
		}
		Node3D *tank = Object::cast_to<Node3D>(tanks->get_node_or_null(NodePath(unit_name)));
		if (tank == nullptr || !(bool)tank->get(k.alive)) {
			continue;
		}
		const int64_t since = tank->get(k.ticks_since_hit);
		const bool hit_recently = since < c.FIRE_TICKS;
		taking_fire = taking_fire || hit_recently;
		const double health = (double)tank->get(k.health);
		const double max_health = (double)tank->get(k.max_health);
		const double shield_pts = (double)tank->get(k.shield);
		const double max_shield = (double)tank->get(k.max_shield);
		const double hull = health / maxd(max_health, 1.0);
		const double shield = max_shield > 0.0 ? shield_pts / maxd(max_shield, 1.0) : 0.0;
		const Dictionary weapon = tank->get(k.weapon);
		const Variant unit_id = tank->get(k.unit_id);
		const Vector3 position = flat_point(tank->get_global_position());
		const Vector3 forward = flat_dir(-tank->get_global_transform().basis.get_column(2));
		Object *command = tank->get(k.command).get_validated_object();
		const double throttle = command != nullptr ? (double)command->get(k.throttle) : 0.0;
		const Vector3 real_velocity = tank->get(k.real_velocity);
		Dictionary m;
		m[k.name] = unit_name;
		m[k.position] = position;
		m[k.forward] = forward;
		m[k.role] = roles.get(unit_id, String());
		m[k.unit] = unit_id;
		m[k.speed] = tank->get(k.max_forward_speed);
		m[k.range] = (double)weapon.get(k.range, 60.0);
		m[k.effective_range] = (double)weapon.get(k.effective_range, weapon.get(k.range, 60.0));
		m[k.preferred_min] = (double)weapon.get(k.preferred_min, 0.0);
		m[k.sight] = tank->get(k.sight_radius);
		m[k.health_k] = clampd((hull + shield) * 0.5 + hull * 0.5, 0.0, 1.0);
		m[k.suppression_k] = clampd((double)tank->get(k.suppression), 0.0, 1.0);
		m[k.taking_fire] = hit_recently;
		m[k.deployed] = (double)tank->get(k.deploy_ratio) >= 1.0;
		m[k.since_hit] = since;
		m[k.left] = clampd((health + shield_pts) / maxd(max_health + max_shield, 1.0), 0.0, 1.0);
		m[k.holding] = std::abs(throttle) < c.HOLD_THROTTLE &&
				(double)Vector2(real_velocity.x, real_velocity.z).length() < c.HOLD_SPEED_MPS;
		m[k.intent_k] = tank->get(k.intent);
		members.push_back(m);
		forwards.push_back(forward);
		center += position;
		strength += health + shield_pts;
	}
	if (!members.is_empty()) {
		center /= (real_t)(double)members.size();
	}
	if (members.size() > 1) {
		Vector3 sum;
		for (const Vector3 &f : forwards) {
			sum += f;
		}
		if ((double)sum.length_squared() > 1e-6) {
			heading = flat_dir(sum);
		}
	}

	struct Entry {
		Dictionary d;
		double distance;
		String name;
	};
	std::vector<Entry> contacts;
	double enemy_strength = 0.0;
	const int64_t tick = game_match->get(k.tick);
	Dictionary known;
	const Array intel_all = game_match->get(k.intel);
	const Dictionary intel = intel_all[team];
	const Array names = intel.keys();
	for (int64_t i = 0; i < names.size(); i++) {
		const String contact_name = names[i];
		const Dictionary contact = intel[names[i]];
		const Vector3 position = flat_point(contact[k.position]);
		const double distance = center.distance_to(position);
		if (distance > c.KNOWN_M) {
			continue;
		}
		const int64_t first_seen = was_known.get(contact_name, tick);
		known[contact_name] = first_seen;
		const double contact_strength = (double)contact.get(k.health_k, 0) + (double)contact.get(k.shield_k, 0);
		enemy_strength += contact_strength;
		const Vector3 velocity = contact.get(k.velocity, Vector3());
		Dictionary e;
		e[k.name] = contact_name;
		e[k.position] = position;
		e[k.role] = String(contact.get(k.role, "tank"));
		e[k.unit] = String(contact.get(k.unit, ""));
		e[k.visible] = (bool)contact.get(k.visible, false);
		e[k.age] = tick - first_seen;
		e[k.distance] = distance;
		e[k.bearing_deg] = bearing_deg(heading, position - center);
		e[k.strength] = contact_strength;
		e[k.speed] = (double)Vector2(velocity.x, velocity.z).length();
		e[k.velocity] = Vector3(velocity.x, 0.0f, velocity.z);
		e[k.seen_tick] = (int64_t)contact.get(k.seen_tick, tick);
		contacts.push_back(Entry{ e, distance, contact_name });
	}
	// contacts.sort_custom: nearer first (beyond 0.001 m), else by name
	std::stable_sort(contacts.begin(), contacts.end(), [](const Entry &a, const Entry &b) {
		if (std::abs(a.distance - b.distance) > 0.001) {
			return a.distance < b.distance;
		}
		return a.name < b.name;
	});
	Array contact_list;
	for (const Entry &e : contacts) {
		contact_list.push_back(e.d);
	}
	out[k.members] = members;
	out[k.contacts] = contact_list;
	out[k.center] = center;
	out[k.heading] = heading;
	out[k.strength] = strength;
	out[k.enemy_strength] = enemy_strength;
	out["taking_fire"] = taking_fire;
	out[k.known] = known;
	return out;
}

} // namespace godot
