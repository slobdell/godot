// NavNative (round 23, N2a): NavigationServer3D.map_get_closest_point, re-implemented over an index of the map's
// polygons. The engine's query (4.7.2 modules/navigation_3d/3d/nav_mesh_queries_3d.cpp,
// map_iteration_get_closest_point_info) is a linear scan of every polygon of every region: the first strict minimum
// in region-then-polygon order, float math, with a per-region early break on a near-zero in-plane hit. This keeps
// that loop LINE FOR LINE and only changes which polygons it visits: a grid over polygon bounds yields a superset of
// every polygon within the best distance (plus a margin), visited in the engine's order, so the first strict minimum
// is the same polygon and the same point. Rebuilt when the map's iteration id changes (a bake, a region added).
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>

namespace godot {

class NavNative : public RefCounted {
	GDCLASS(NavNative, RefCounted)

	struct Polygon {
		LocalVector<Vector3> vertices;
		uint32_t region = 0; // the map's region order
		float min_x = 0, max_x = 0, min_y = 0, max_y = 0, min_z = 0, max_z = 0;
	};
	struct Index {
		RID map;
		uint64_t iteration = 0;
		LocalVector<Polygon> polygons; // in the engine's order: region by region, polygon by polygon
		uint32_t regions = 0;
		double cell = 8.0;
		HashMap<Vector2i, LocalVector<uint32_t>> grid; // xz cell -> polygon indices
		// The synced map holds polygons this side cannot read back exactly (a region whose node is gone, whose mesh
		// is re-baked but not yet synced, or whose live bounds differ from the synced bounds): every query goes to the
		// engine's own scan until the map's iteration moves. Exact by construction, no gain in that window.
		bool fallback = false;
	};
	Index index;
	LocalVector<uint32_t> candidates;
	LocalVector<uint32_t> marked; // the query stamp a polygon was last probed in
	uint32_t stamp = 0;
	uint64_t queries = 0, rebuilds = 0, candidates_total = 0;
	uint32_t last_no_owner = 0, last_no_mesh = 0, last_empty_mesh = 0, last_bounds_differ = 0;
	uint64_t fallback_queries = 0;

	bool rebuild(const RID &map, uint64_t iteration);
	static Vector3 scan(const LocalVector<Polygon> &polygons, const LocalVector<uint32_t> &order, const Vector3 &point,
			uint32_t regions);
	static double evaluate(const Polygon &polygon, const Vector3 &point); // the polygon's distance squared, the engine's way

protected:
	static void _bind_methods();

public:
	// The same answer as NavigationServer3D.map_get_closest_point(map, point); the index is rebuilt when the map's
	// iteration id (NavigationServer3D.map_get_iteration_id, asked here) moves: a bake, a region added or removed.
	Vector3 closest_point(const RID &map, const Vector3 &point);
	// The engine's own scan over the index's polygons (no grid): the reference the test holds the grid to.
	Vector3 closest_point_scan(const RID &map, const Vector3 &point);
	int polygon_count() const { return (int)index.polygons.size(); }
	int region_count() const { return (int)index.regions; }
	String stats() const;
};

} // namespace godot
