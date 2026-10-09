#include "nav_native.h"

#include <godot_cpp/classes/navigation_mesh.hpp>
#include <godot_cpp/classes/navigation_region3d.hpp>
#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include <algorithm>
#include <cfloat>
#include <cmath>

namespace godot {

void NavNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("closest_point", "map", "point"), &NavNative::closest_point);
	ClassDB::bind_method(D_METHOD("closest_point_scan", "map", "point"), &NavNative::closest_point_scan);
	ClassDB::bind_method(D_METHOD("chord_on_mesh", "map", "from", "to", "samples", "slack"), &NavNative::chord_on_mesh);
	ClassDB::bind_method(D_METHOD("outline_ok", "map", "half_w", "half_l", "clear", "at", "heading", "start", "lazy_at", "lazy_heading"),
			&NavNative::outline_ok);
	ClassDB::bind_method(D_METHOD("arc_hit", "map", "half_w", "half_l", "clear", "at", "heading", "turn", "target", "start", "cap",
			"radius", "lazy_at", "lazy_heading"), &NavNative::arc_hit);
	ClassDB::bind_method(D_METHOD("polygon_count"), &NavNative::polygon_count);
	ClassDB::bind_method(D_METHOD("region_count"), &NavNative::region_count);
	ClassDB::bind_method(D_METHOD("stats"), &NavNative::stats);
}

static inline int32_t cell_of(double v, double cell) {
	return (int32_t)std::floor(v / cell);
}

// The map's polygons as NavMapBuilder3D / NavRegionBuilder3D hold them: regions in the map's order
// (map_get_regions is that list), each region's navmesh polygons in order, each vertex `transform.xform(v)` in
// float; polygons under three vertices are kept empty there and never match (they are skipped here).
bool NavNative::rebuild(const RID &map, uint64_t iteration) {
	NavigationServer3D *server = NavigationServer3D::get_singleton();
	index = Index();
	index.map = map;
	index.iteration = iteration;
	rebuilds++;
	const TypedArray<RID> regions = server->map_get_regions(map);
	index.regions = (uint32_t)regions.size();
	last_no_owner = last_no_mesh = last_empty_mesh = last_bounds_differ = 0;
	float lo_x = FLT_MAX, lo_z = FLT_MAX, hi_x = -FLT_MAX, hi_z = -FLT_MAX;
	for (int64_t r = 0; r < regions.size(); r++) {
		const RID region = regions[r];
		const Transform3D transform = server->region_get_transform(region);
		Object *owner = ObjectDB::get_instance(server->region_get_owner_id(region));
		NavigationRegion3D *node = Object::cast_to<NavigationRegion3D>(owner);
		if (node == nullptr) {
			last_no_owner++;
			index.fallback = true;
			continue;
		}
		const Ref<NavigationMesh> mesh = node->get_navigation_mesh();
		if (mesh.is_null()) {
			last_no_mesh++;
			index.fallback = true;
			continue;
		}
		if (mesh->get_polygon_count() == 0) {
			last_empty_mesh++;
		}
		const PackedVector3Array vertices = mesh->get_vertices();
		const int64_t vertex_count = vertices.size();
		const int64_t polygon_count = mesh->get_polygon_count();
		// The region's synced bounds (NavRegionBuilder3D: the first vertex, then expand_to) against the live mesh's: a
		// mesh re-baked since the sync, or another resource, shows here.
		AABB live_bounds;
		bool first_vertex = true;
		for (int64_t p = 0; p < polygon_count; p++) {
			const PackedInt32Array indices = mesh->get_polygon(p);
			Polygon polygon;
			polygon.region = (uint32_t)r;
			if (indices.size() >= 3) {
				bool valid = true;
				polygon.vertices.resize(indices.size());
				for (int64_t j = 0; j < indices.size(); j++) {
					const int32_t vi = indices[j];
					if (vi < 0 || vi >= vertex_count) {
						valid = false;
						break;
					}
					polygon.vertices[j] = transform.xform(vertices[vi]);
					if (first_vertex) {
						first_vertex = false;
						live_bounds.position = polygon.vertices[j];
					} else {
						live_bounds.expand_to(polygon.vertices[j]);
					}
				}
				if (!valid) {
					polygon.vertices.clear();
				}
			}
			if (polygon.vertices.size() >= 3) {
				polygon.min_x = polygon.max_x = polygon.vertices[0].x;
				polygon.min_y = polygon.max_y = polygon.vertices[0].y;
				polygon.min_z = polygon.max_z = polygon.vertices[0].z;
				for (uint32_t j = 1; j < polygon.vertices.size(); j++) {
					const Vector3 &v = polygon.vertices[j];
					polygon.min_x = std::min(polygon.min_x, v.x);
					polygon.max_x = std::max(polygon.max_x, v.x);
					polygon.min_y = std::min(polygon.min_y, v.y);
					polygon.max_y = std::max(polygon.max_y, v.y);
					polygon.min_z = std::min(polygon.min_z, v.z);
					polygon.max_z = std::max(polygon.max_z, v.z);
				}
				lo_x = std::min(lo_x, polygon.min_x);
				hi_x = std::max(hi_x, polygon.max_x);
				lo_z = std::min(lo_z, polygon.min_z);
				hi_z = std::max(hi_z, polygon.max_z);
			}
			index.polygons.push_back(polygon);
		}
		const AABB synced_bounds = server->region_get_bounds(region);
		if (!first_vertex && !(synced_bounds.position.is_equal_approx(live_bounds.position) && synced_bounds.size.is_equal_approx(live_bounds.size))) {
			last_bounds_differ++;
			index.fallback = true;
		}
	}
	// A cell near the typical polygon size keeps the ring walk short; the bound is exact whatever the cell.
	const double span = std::max((double)(hi_x - lo_x), (double)(hi_z - lo_z));
	index.cell = index.polygons.size() > 0 && span > 0.0 ? std::max(4.0, span / 48.0) : 8.0;
	for (uint32_t i = 0; i < index.polygons.size(); i++) {
		const Polygon &polygon = index.polygons[i];
		if (polygon.vertices.size() < 3) {
			continue;
		}
		const int32_t cx0 = cell_of(polygon.min_x, index.cell), cx1 = cell_of(polygon.max_x, index.cell);
		const int32_t cz0 = cell_of(polygon.min_z, index.cell), cz1 = cell_of(polygon.max_z, index.cell);
		for (int32_t cx = cx0; cx <= cx1; cx++) {
			for (int32_t cz = cz0; cz <= cz1; cz++) {
				index.grid[Vector2i(cx, cz)].push_back(i);
			}
		}
	}
	marked.clear();
	marked.resize(index.polygons.size());
	for (uint32_t i = 0; i < marked.size(); i++) {
		marked[i] = 0;
	}
	stamp = 0;
	return true;
}

// One polygon of the engine's loop: the distance squared it would compare (FLT_MAX when the polygon is empty). The
// point itself is recomputed by `scan`, which is the engine's loop verbatim; this is only the broadphase's probe.
double NavNative::evaluate(const Polygon &polygon, const Vector3 &p_point) {
	if (polygon.vertices.size() < 3) {
		return FLT_MAX;
	}
	const Vector3 plane_normal = (polygon.vertices[1] - polygon.vertices[0]).cross(polygon.vertices[2] - polygon.vertices[0]);
	Vector3 closest_on_polygon;
	real_t closest = FLT_MAX;
	bool inside = true;
	Vector3 previous = polygon.vertices[polygon.vertices.size() - 1];
	for (uint32_t point_id = 0; point_id < polygon.vertices.size(); ++point_id) {
		Vector3 edge = polygon.vertices[point_id] - previous;
		Vector3 to_point = p_point - previous;
		Vector3 edge_to_point_pormal = edge.cross(to_point);
		bool clockwise = edge_to_point_pormal.dot(plane_normal) > 0;
		if (!clockwise) {
			inside = false;
			real_t point_projected_on_edge = edge.dot(to_point);
			real_t edge_square = edge.length_squared();
			if (point_projected_on_edge > edge_square) {
				real_t distance = polygon.vertices[point_id].distance_squared_to(p_point);
				if (distance < closest) {
					closest_on_polygon = polygon.vertices[point_id];
					closest = distance;
				}
			} else if (point_projected_on_edge < 0.f) {
				real_t distance = previous.distance_squared_to(p_point);
				if (distance < closest) {
					closest_on_polygon = previous;
					closest = distance;
				}
			} else {
				real_t percent = point_projected_on_edge / edge_square;
				closest_on_polygon = previous + percent * edge;
				break;
			}
		}
		previous = polygon.vertices[point_id];
	}
	if (inside) {
		Vector3 plane_normalized = plane_normal.normalized();
		real_t distance = plane_normalized.dot(p_point - polygon.vertices[0]);
		return (double)(distance * distance);
	}
	return (double)closest_on_polygon.distance_squared_to(p_point);
}

// The engine's loop (nav_mesh_queries_3d.cpp, map_iteration_get_closest_point_info) over `order`, a list of polygon
// indices in the engine's own order; `break` leaves the REGION's loop there, so it is a skip to the next region here.
Vector3 NavNative::scan(const LocalVector<Polygon> &polygons, const LocalVector<uint32_t> &order, const Vector3 &p_point,
		uint32_t regions) {
	Vector3 result;
	real_t closest_point_distance_squared = FLT_MAX;
	uint32_t skip_region = regions; // a region whose loop the engine left early: none
	for (uint32_t k = 0; k < order.size(); k++) {
		const Polygon &polygon = polygons[order[k]];
		if (polygon.region == skip_region || polygon.vertices.size() < 3) {
			continue;
		}
		Vector3 plane_normal = (polygon.vertices[1] - polygon.vertices[0]).cross(polygon.vertices[2] - polygon.vertices[0]);
		Vector3 closest_on_polygon;
		real_t closest = FLT_MAX;
		bool inside = true;
		Vector3 previous = polygon.vertices[polygon.vertices.size() - 1];
		for (uint32_t point_id = 0; point_id < polygon.vertices.size(); ++point_id) {
			Vector3 edge = polygon.vertices[point_id] - previous;
			Vector3 to_point = p_point - previous;
			Vector3 edge_to_point_pormal = edge.cross(to_point);
			bool clockwise = edge_to_point_pormal.dot(plane_normal) > 0;
			// If we are not clockwise, the point will never be inside the polygon and so the closest point will be on an edge.
			if (!clockwise) {
				inside = false;
				real_t point_projected_on_edge = edge.dot(to_point);
				real_t edge_square = edge.length_squared();

				if (point_projected_on_edge > edge_square) {
					real_t distance = polygon.vertices[point_id].distance_squared_to(p_point);
					if (distance < closest) {
						closest_on_polygon = polygon.vertices[point_id];
						closest = distance;
					}
				} else if (point_projected_on_edge < 0.f) {
					real_t distance = previous.distance_squared_to(p_point);
					if (distance < closest) {
						closest_on_polygon = previous;
						closest = distance;
					}
				} else {
					// If we project on this edge, this will be the closest point.
					real_t percent = point_projected_on_edge / edge_square;
					closest_on_polygon = previous + percent * edge;
					break;
				}
			}
			previous = polygon.vertices[point_id];
		}

		if (inside) {
			Vector3 plane_normalized = plane_normal.normalized();
			real_t distance = plane_normalized.dot(p_point - polygon.vertices[0]);
			real_t distance_squared = distance * distance;
			if (distance_squared < closest_point_distance_squared) {
				closest_point_distance_squared = distance_squared;
				result = p_point - plane_normalized * distance;

				if (Math::is_zero_approx(distance)) {
					skip_region = polygon.region;
				}
			}
		} else {
			real_t distance = closest_on_polygon.distance_squared_to(p_point);
			if (distance < closest_point_distance_squared) {
				closest_point_distance_squared = distance;
				result = closest_on_polygon;
			}
		}
	}
	return result;
}

Vector3 NavNative::closest_point_scan(const RID &map, const Vector3 &point) {
	NavigationServer3D *server = NavigationServer3D::get_singleton();
	const uint64_t iteration = (uint64_t)server->map_get_iteration_id(map);
	if (index.map != map || index.iteration != iteration) {
		rebuild(map, iteration);
	}
	if (index.fallback) {
		return server->map_get_closest_point(map, point);
	}
	LocalVector<uint32_t> order;
	order.resize(index.polygons.size());
	for (uint32_t i = 0; i < order.size(); i++) {
		order[i] = i;
	}
	return scan(index.polygons, order, point, index.regions);
}

void NavNative::refresh(const RID &map) {
	NavigationServer3D *server = NavigationServer3D::get_singleton();
	const uint64_t iteration = (uint64_t)server->map_get_iteration_id(map);
	if (index.map != map || index.iteration != iteration) {
		rebuild(map, iteration);
	}
}

Vector3 NavNative::closest_point(const RID &map, const Vector3 &point) {
	refresh(map);
	return query(point);
}

Vector3 NavNative::query(const Vector3 &point) {
	queries++;
	if (index.fallback) {
		fallback_queries++;
		return NavigationServer3D::get_singleton()->map_get_closest_point(index.map, point);
	}
	const uint32_t n = index.polygons.size();
	if (n == 0) {
		return Vector3();
	}
	stamp++;
	candidates.clear();
	const double cell = index.cell;
	const int32_t cx = cell_of((double)point.x, cell);
	const int32_t cz = cell_of((double)point.z, cell);
	// Rings outward until the ring's own lower bound exceeds the best distance found, then everything within that
	// bound (plus a margin, so a tie or a near-zero in-plane hit is never left out) goes to the engine's loop in order.
	double best = FLT_MAX;
	const double px = point.x, py = point.y, pz = point.z;
	auto bound = [&](const Polygon &polygon) -> double {
		const double dx = px < polygon.min_x ? polygon.min_x - px : (px > polygon.max_x ? px - polygon.max_x : 0.0);
		const double dy = py < polygon.min_y ? polygon.min_y - py : (py > polygon.max_y ? py - polygon.max_y : 0.0);
		const double dz = pz < polygon.min_z ? polygon.min_z - pz : (pz > polygon.max_z ? pz - polygon.max_z : 0.0);
		return dx * dx + dy * dy + dz * dz;
	};
	int32_t ring = 0;
	const int32_t ring_limit = 4096;
	while (ring <= ring_limit) {
		// The ring's cells: every polygon in them is probed; its bound tells whether it can matter at all.
		const double ring_floor = ring == 0 ? 0.0 : (double)(ring - 1) * cell; // nothing in this ring is nearer than this
		if (best < FLT_MAX && ring_floor * ring_floor > best * (1.0 + 1e-6) + 1e-8) {
			break;
		}
		bool any_cell = false;
		for (int32_t gx = cx - ring; gx <= cx + ring; gx++) {
			for (int32_t gz = cz - ring; gz <= cz + ring; gz++) {
				if (ring > 0 && gx != cx - ring && gx != cx + ring && gz != cz - ring && gz != cz + ring) {
					continue; // inside the ring: visited before
				}
				const LocalVector<uint32_t> *list = index.grid.getptr(Vector2i(gx, gz));
				if (list == nullptr) {
					continue;
				}
				any_cell = true;
				for (uint32_t k = 0; k < list->size(); k++) {
					const uint32_t i = (*list)[k];
					if (marked[i] == stamp) {
						continue;
					}
					marked[i] = stamp;
					const double d = evaluate(index.polygons[i], point);
					if (d < best) {
						best = d;
					}
					candidates.push_back(i);
				}
			}
		}
		ring++;
		if (ring > 64 && best == FLT_MAX && !any_cell) {
			// Far outside the mesh: fall back to the full scan rather than walk an empty grid for ever.
			candidates.clear();
			for (uint32_t i = 0; i < n; i++) {
				candidates.push_back(i);
			}
			break;
		}
	}
	// Keep what can still matter, in the engine's order.
	const double keep = best * (1.0 + 1e-6) + 1e-8;
	LocalVector<uint32_t> order;
	for (uint32_t k = 0; k < candidates.size(); k++) {
		const uint32_t i = candidates[k];
		if (bound(index.polygons[i]) <= keep) {
			order.push_back(i);
		}
	}
	std::sort(order.ptr(), order.ptr() + order.size());
	candidates_total += order.size();
	return scan(index.polygons, order, point, index.regions);
}


// movement.gd `_chord_compute`'s loop: probe = Vector3(lerpf(from.x, to.x, share), 0.0, lerpf(from.z, to.z, share))
// (lerpf in double: from + (to - from) * share; the constructor narrows), `_flat_distance(closest, probe)` =
// Vector2(a.x - b.x, a.z - b.z).length() (float32), compared with the double slack.
bool NavNative::chord_on_mesh(const RID &map, const Vector3 &from, const Vector3 &to, const PackedFloat64Array &samples, double slack) {
	refresh(map);
	const int64_t n = samples.size();
	for (int64_t k = 0; k < n; k++) {
		const double share = samples[k];
		const double px = (double)from.x + ((double)to.x - (double)from.x) * share;
		const double pz = (double)from.z + ((double)to.z - (double)from.z) * share;
		const Vector3 probe((real_t)px, (real_t)0.0, (real_t)pz);
		const Vector3 closest = query(probe);
		const Vector2 flat((real_t)((double)closest.x - (double)probe.x), (real_t)((double)closest.z - (double)probe.z));
		if ((double)flat.length() > slack) {
			return false;
		}
	}
	return true;
}

// movement.gd KTURN_OUTLINE, in order; `_outline_offs` / `_lazy_start_at`'s arithmetic for point i:
//   right := Vector3(-heading.z, 0.0, heading.x)
//   point := at + heading * (sample.x * half_l) + right * (sample.y * half_w)     (sample.x float32 read as double, the
//            product double, narrowed by Vector3 * float; then float32 adds)
//   off := Vector2(closest.x - point.x, closest.z - point.z).length()
static const float KTURN_OUTLINE[10][2] = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 }, { 1, 0 }, { -1, 0 }, { 0.5f, 1 }, { 0.5f, -1 }, { -0.5f, 1 }, { -0.5f, -1 } };

float NavNative::outline_off(int i, double half_w, double half_l, const Vector3 &at, const Vector3 &heading) {
	const Vector3 right(-heading.z, (real_t)0.0, heading.x);
	const Vector3 point = at + heading * (real_t)((double)KTURN_OUTLINE[i][0] * half_l) + right * (real_t)((double)KTURN_OUTLINE[i][1] * half_w);
	const Vector3 closest = query(point);
	return Vector2((real_t)((double)closest.x - (double)point.x), (real_t)((double)closest.z - (double)point.z)).length();
}

// `_outline_ok` with BrainSwitches.kturn_cap: per point, off > clear AND off > from_start + 0.05 -> not ok; from_start
// is start[i] (float32), or the lazy start pose's own outline point (computed and stored as float32 there, so rounded
// to float32 here too) when `start` is empty.
bool NavNative::outline_ok(const RID &map, double half_w, double half_l, double clear, const Vector3 &at, const Vector3 &heading,
		const PackedFloat32Array &start, const Vector3 &lazy_at, const Vector3 &lazy_heading) {
	refresh(map);
	const bool lazy = start.size() == 0;
	for (int i = 0; i < 10; i++) {
		const double off = (double)outline_off(i, half_w, half_l, at, heading);
		if (off > clear) {
			const float from_start = lazy ? outline_off(i, half_w, half_l, lazy_at, lazy_heading) : start[i];
			if (off > (double)from_start + 0.05) {
				return false;
			}
		}
	}
	return true;
}

// `_arc_hit`: limit := TAU * radius * KTURN_SWEEP_TURNS; while travelled < limit and < cap:
//   to := Vector3(target.x - at.x, 0.0, target.z - at.z); if absf(heading.signed_angle_to(to, UP)) <= deg_to_rad(20): INF
//   heading = TankMotion.turn_heading(heading, KTURN_STEP_M * turn / radius)   (right * radians narrowed; normalized)
//   at += heading * KTURN_STEP_M; travelled += KTURN_STEP_M; if not _outline_ok(...): travelled
double NavNative::arc_hit(const RID &map, double half_w, double half_l, double clear, const Vector3 &p_at, const Vector3 &p_heading,
		double turn, const Vector3 &target, const PackedFloat32Array &start, double cap, double radius,
		const Vector3 &lazy_at, const Vector3 &lazy_heading) {
	constexpr double KTURN_STEP_M = 1.0;
	constexpr double KTURN_SWEEP_TURNS = 0.75;
	constexpr double KTURN_ALIGNED_DEG = 20.0;
	const double aligned = KTURN_ALIGNED_DEG * (Math::PI / 180.0);
	const double inf = std::numeric_limits<double>::infinity();
	Vector3 at = p_at;
	Vector3 heading = p_heading;
	double travelled = 0.0;
	const double limit = Math::TAU * radius * KTURN_SWEEP_TURNS;
	while (travelled < limit && travelled < cap) {
		const Vector3 to((real_t)((double)target.x - (double)at.x), (real_t)0.0, (real_t)((double)target.z - (double)at.z));
		if (std::fabs((double)heading.signed_angle_to(to, Vector3(0, 1, 0))) <= aligned) {
			return inf;
		}
		const double radians = KTURN_STEP_M * turn / radius;
		if (radians != 0.0) {
			const Vector3 right(-heading.z, (real_t)0.0, heading.x);
			heading = (heading + right * (real_t)radians).normalized();
		}
		at += heading * (real_t)KTURN_STEP_M;
		travelled += KTURN_STEP_M;
		if (!outline_ok(map, half_w, half_l, clear, at, heading, start, lazy_at, lazy_heading)) {
			return travelled;
		}
	}
	return inf;
}

String NavNative::stats() const {
	return String("polygons ") + String::num_int64(index.polygons.size()) + " regions " + String::num_int64(index.regions) +
			" cell " + String::num(index.cell, 2) + " | queries " + String::num_int64(queries) + " rebuilds " +
			String::num_int64(rebuilds) + " candidates/query " +
			String::num(queries > 0 ? (double)candidates_total / (double)queries : 0.0, 1) + " | last rebuild: no owner " +
			String::num_int64(last_no_owner) + " no mesh " + String::num_int64(last_no_mesh) + " empty mesh " + String::num_int64(last_empty_mesh) +
			" bounds differ " + String::num_int64(last_bounds_differ) + (index.fallback ? " | FALLBACK (the engine's scan answers)" : "") +
			" | fallback queries " + String::num_int64(fallback_queries);
}

} // namespace godot
