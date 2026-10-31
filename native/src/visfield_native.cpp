// Round 48 (native, R48.8): VisibilityField.look_from's ray fan (game/match/visibility_field.gd, `_rays`) in C++. His laptop at the
// cost cap (lock held, Crossing seed 101, stream/native 4c01aa748, --native-tick-profile 8-40 s, 39->32 crews): visfield 0.466 ms
// a tick, rays 0.376 of it (~190 intersect_ray a look from GDScript), ~1.1 ms a frame at 2.9 ticks a frame. Line by line in the
// GDScript's widths: `eye + direction * radius` and `eye.distance_to(hit.position)` in float32 (Vector3 math), the distance held
// in a double, the fan point `eye.x + direction.x * distance` in double then narrowed into the Vector2; the query is
// PhysicsRayQueryParameters3D.new()'s defaults with the eye mask, `from` once, `to` per ray. tests/test_native_visfield.gd and
// TANK_NATIVE_VISFIELD_VERIFY hold it to the live GDScript; NativeVisfield (game/ai/native/native_visfield.gd) is the seam.
#include "visfield_native.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

Array visfield_rays(Object *viewer, const Vector3 &eye, double radius, const PackedVector3Array &directions, int64_t mask) {
	static const StringName position("position");
	Array out;
	Node3D *node = Object::cast_to<Node3D>(viewer);
	const Ref<World3D> world = node != nullptr ? node->get_world_3d() : Ref<World3D>();
	PhysicsDirectSpaceState3D *space = world.is_valid() ? world->get_direct_space_state() : nullptr;
	if (space == nullptr) {
		return out;
	}
	const int64_t ray_count = directions.size();
	PackedFloat32Array reach;
	reach.resize(ray_count);
	PackedVector2Array fan;
	fan.resize(ray_count + 1);
	fan.set(0, Vector2(eye.x, eye.z));
	Ref<PhysicsRayQueryParameters3D> query;
	query.instantiate();
	query->set_collision_mask((uint32_t)mask);
	query->set_from(eye);
	const real_t r_radius = (real_t)radius; // Vector3 * float: the scalar narrows to real_t
	for (int64_t r = 0; r < ray_count; r++) {
		const Vector3 direction = directions[r];
		query->set_to(eye + direction * r_radius);
		const Dictionary hit = space->intersect_ray(query);
		double distance = radius;
		if (!hit.is_empty()) {
			distance = (double)eye.distance_to((Vector3)hit[position]);
		}
		reach.set(r, (float)distance);
		fan.set(r + 1, Vector2((real_t)((double)eye.x + (double)direction.x * distance), (real_t)((double)eye.z + (double)direction.z * distance)));
	}
	out.push_back(reach);
	out.push_back(fan);
	return out;
}

} // namespace godot
