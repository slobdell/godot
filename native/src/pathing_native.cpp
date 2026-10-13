// Round 28 (native N6.4): Pathing's wrappers in C++ (pathing_native.h). tests/test_native_pathing.gd holds each to the
// live GDScript; native-proof `pathing` the match.
#include "pathing_native.h"

#include "nav_native.h"

#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>

namespace godot {

namespace {

struct PN {
	StringName enabled{ "enabled" }, ready_memo{ "ready_memo" }, native{ "native" }, native_nav{ "native_nav" },
			_ready_map{ "_ready_map" }, _ready_iteration{ "_ready_iteration" }, _ready_answer{ "_ready_answer" },
			closest_point{ "closest_point" };
	// the query's keys: String, as the GDScript's literal
	String points{ "points" }, ready{ "ready" }, reachable{ "reachable" }, goal_on_mesh{ "goal_on_mesh" },
			end_gap_m{ "end_gap_m" }, goal_gap_m{ "goal_gap_m" }, query_site{ "query" };
};
const PN &pn_() {
	static const PN names;
	return names;
}

RID map_of(Object *node) {
	Node3D *spatial = Object::cast_to<Node3D>(node);
	if (spatial == nullptr) {
		return RID();
	}
	const Ref<World3D> world = spatial->get_world_3d();
	return world.is_valid() ? world->get_navigation_map() : RID();
}

// `not enabled or not is_ready(node)`, the opening of find_path and query
bool usable_map(const PathingConfig &c, Object *node) {
	return (bool)c.pathing->get(pn_().enabled) && pathing_is_ready(c, node);
}

// Pathing.closest_point(map, point, "query"): N2a's index while native and native_nav are on, else the GDScript's
Vector3 closest_point(const PathingConfig &c, const RID &map, const Vector3 &point) {
	const PN &k = pn_();
	if (c.nav != nullptr && (bool)c.switches->get(k.native) && (bool)c.switches->get(k.native_nav)) {
		return c.nav->closest_point(map, point);
	}
	return c.pathing->call(k.closest_point, map, point, k.query_site);
}

// Vector2(a.x - b.x, a.z - b.z).length(): the differences in doubles (GDScript's floats), narrowed to the Vector2
double flat_gap(const Vector3 &a, const Vector3 &b) {
	return Vector2((real_t)((double)a.x - (double)b.x), (real_t)((double)a.z - (double)b.z)).length();
}

} // namespace

//   map := node.get_world_3d().navigation_map; iteration := map_get_iteration_id(map)
//   iteration > 0 and not ready_memo: owner probe every call; iteration > 0: the probe once a (map, iteration)
bool pathing_is_ready(const PathingConfig &c, Object *node) {
	const PN &k = pn_();
	NavigationServer3D *server = NavigationServer3D::get_singleton();
	const RID map = map_of(node);
	const int64_t iteration = server->map_get_iteration_id(map);
	if (iteration <= 0) {
		return false;
	}
	if (!(bool)c.switches->get(k.ready_memo)) {
		return server->map_get_closest_point_owner(map, Vector3()).is_valid();
	}
	if ((RID)c.pathing->get(k._ready_map) != map || (int64_t)c.pathing->get(k._ready_iteration) != iteration) {
		c.pathing->set(k._ready_map, map);
		c.pathing->set(k._ready_iteration, iteration);
		c.pathing->set(k._ready_answer, server->map_get_closest_point_owner(map, Vector3()).is_valid());
	}
	return c.pathing->get(k._ready_answer);
}

Dictionary pathing_query(const PathingConfig &c, Object *node, const Vector3 &from, const Vector3 &to) {
	const PN &k = pn_();
	Dictionary result;
	result[k.points] = PackedVector3Array();
	result[k.ready] = false;
	result[k.reachable] = false;
	result[k.goal_on_mesh] = false;
	result[k.end_gap_m] = INFINITY;
	result[k.goal_gap_m] = INFINITY;
	if (!usable_map(c, node)) {
		return result;
	}
	const RID map = map_of(node);
	const PackedVector3Array points = NavigationServer3D::get_singleton()->map_get_path(map, from, to, true);
	const Vector3 nearest = closest_point(c, map, to);
	const double goal_gap = flat_gap(to, nearest);
	double end_gap = INFINITY;
	if (points.size() > 0) {
		end_gap = flat_gap(points[points.size() - 1], nearest);
	}
	result[k.points] = points;
	result[k.ready] = true;
	result[k.goal_gap_m] = goal_gap;
	result[k.end_gap_m] = end_gap;
	result[k.reachable] = end_gap <= c.MESH_EPSILON;
	result[k.goal_on_mesh] = goal_gap <= c.MESH_EPSILON;
	return result;
}

PackedVector3Array pathing_find_path(const PathingConfig &c, Object *node, const Vector3 &from, const Vector3 &to) {
	if (!usable_map(c, node)) {
		return PackedVector3Array();
	}
	return NavigationServer3D::get_singleton()->map_get_path(map_of(node), from, to, true);
}

} // namespace godot
