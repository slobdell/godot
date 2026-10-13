// Round 28 (native N6.3): perception's batched pass (perception_native.h). Line by line in the GDScript's widths:
// positions float32 (Vector3), distance_to a float32 widened to the double it is compared with, the eye points
// `global_position + Vector3.UP * EYE_HEIGHT` in float32, the ray the engine's intersect_ray with
// PhysicsRayQueryParameters3D.create's defaults (bodies, no areas, no exclusions).
#include "perception_native.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

namespace {

struct PeN {
	StringName alive{ "alive" }, sight_radius{ "sight_radius" }, weapon{ "weapon" }, ready_to_fire{ "ready_to_fire" };
	String range{ "range" }; // the weapon profile's key: a String, as its literal
};
const PeN &pen_() {
	static const PeN names;
	return names;
}

struct Hull {
	Node3D *node = nullptr;
	Vector3 position;
	bool alive = false;
};

LocalVector<Hull> hulls_of(const Array &tanks) {
	const PeN &k = pen_();
	LocalVector<Hull> out;
	out.resize(tanks.size());
	for (int64_t i = 0; i < tanks.size(); i++) {
		Node3D *node = Object::cast_to<Node3D>((Object *)tanks[i]);
		out[i].node = node;
		if (node != nullptr) {
			out[i].position = node->get_global_position();
			out[i].alive = node->get(k.alive); // Tank.is_alive(): `return alive`
		}
	}
	return out;
}

// Perception.has_line_of_sight(viewer, target)
bool clear_line(const PerceptionConfig &c, PhysicsDirectSpaceState3D *space, const Hull &viewer, const Hull &target) {
	const Vector3 up = Vector3(0, 1, 0) * (real_t)c.EYE_HEIGHT;
	Ref<PhysicsRayQueryParameters3D> query = PhysicsRayQueryParameters3D::create(viewer.position + up, target.position + up,
			c.WORLD_MASK);
	return space->intersect_ray(query).is_empty();
}

PhysicsDirectSpaceState3D *space_of(const LocalVector<Hull> &viewers) {
	for (const Hull &h : viewers) {
		if (h.node != nullptr) {
			const Ref<World3D> world = h.node->get_world_3d();
			return world.is_valid() ? world->get_direct_space_state() : nullptr;
		}
	}
	return nullptr;
}

} // namespace

PackedInt32Array perception_sight(const PerceptionConfig &c, const Array &viewers_in, const Array &enemies_in, int64_t &rays) {
	const PeN &k = pen_();
	PackedInt32Array out;
	rays = 0;
	const LocalVector<Hull> viewers = hulls_of(viewers_in), enemies = hulls_of(enemies_in);
	out.resize(enemies.size());
	PhysicsDirectSpaceState3D *space = space_of(viewers);
	LocalVector<double> sight;
	sight.resize(viewers.size());
	for (uint32_t v = 0; v < viewers.size(); v++) {
		sight[v] = viewers[v].node != nullptr ? (double)viewers[v].node->get(k.sight_radius) : 0.0;
	}
	for (uint32_t e = 0; e < enemies.size(); e++) {
		//   if not enemy.is_alive(): known.erase(...); continue
		if (!enemies[e].alive) {
			out.set(e, -2);
			continue;
		}
		int32_t seen_by = -1;
		for (uint32_t v = 0; v < viewers.size(); v++) {
			if (!viewers[v].alive) {
				continue;
			}
			if ((double)viewers[v].position.distance_to(enemies[e].position) > sight[v]) {
				continue;
			}
			rays++;
			if (space == nullptr || !clear_line(c, space, viewers[v], enemies[e])) {
				continue;
			}
			seen_by = (int32_t)v;
			break;
		}
		out.set(e, seen_by);
	}
	return out;
}

PackedByteArray perception_gun_ready(const PerceptionConfig &c, const Array &viewers_in, const Array &enemies_in, int64_t &rays) {
	const PeN &k = pen_();
	PackedByteArray out;
	rays = 0;
	const LocalVector<Hull> viewers = hulls_of(viewers_in), enemies = hulls_of(enemies_in);
	out.resize(viewers.size());
	PhysicsDirectSpaceState3D *space = space_of(viewers);
	for (uint32_t v = 0; v < viewers.size(); v++) {
		out.set(v, 0);
		//   if not viewer.is_alive() or not viewer.ready_to_fire(): continue
		if (!viewers[v].alive || !(bool)viewers[v].node->call(k.ready_to_fire)) {
			continue;
		}
		const double range = (double)((Dictionary)viewers[v].node->get(k.weapon))[k.range];
		for (uint32_t e = 0; e < enemies.size(); e++) {
			if (!enemies[e].alive || (double)viewers[v].position.distance_to(enemies[e].position) > range) {
				continue;
			}
			rays++;
			if (space != nullptr && clear_line(c, space, viewers[v], enemies[e])) {
				out.set(v, 1);
				break;
			}
		}
	}
	return out;
}

} // namespace godot
