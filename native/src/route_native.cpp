// Round 24 (native, N3b `move.path`): the route-following tail of Movement._next_waypoint as ONE call (everything after
// the re-plan block: where the hull is along its route, the carrot, the chord pull-back, a car's look further on).
// Each line is the GDScript's with the width GDScript has there (_agents/native.md, hazard 1); the comments quote it.
// The constants are movement.gd's; `route_constants()` hands them back so the test holds them to the live ones.
#include "tank_native.h"

#include "nav_native.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

namespace {

// movement.gd: PATH_LOOKAHEAD, WHEELS_LOOKAHEAD_RADII, CARROT_ALIGNED_COS, WHEELS_LOOKAHEAD_MAX_RADII,
// CARROT_PULLBACK, WAYPOINT_MIN_M, CHORD_SAMPLES, CHORD_END.
constexpr double PATH_LOOKAHEAD = 5.0;
constexpr double WHEELS_LOOKAHEAD_RADII = 1.2;
constexpr double CARROT_ALIGNED_COS = 0.5;
constexpr double WHEELS_LOOKAHEAD_MAX_RADII = 4.0;
constexpr double CARROT_PULLBACK[2] = { 0.6, 0.3 };
constexpr double WAYPOINT_MIN_M = 1.5;

const Vector3 V3_INF(INFINITY, INFINITY, INFINITY);

// Movement._flat_distance: Vector2(a.x - b.x, a.z - b.z).length() -> float32 members subtracted as doubles and
// narrowed by the constructor (= the float32 subtraction), the length in real_t, widened.
inline double flat_distance(const Vector3 &a, const Vector3 &b) {
	return (double)Vector2((real_t)((double)a.x - (double)b.x), (real_t)((double)a.z - (double)b.z)).length();
}

struct Route {
	const Vector3 *path;
	int size;
	int path_index;
	Vector3 here;
	Vector2 forward_raw; // Vector2(-basis.z.x, -basis.z.z), not normalised (as _next_waypoint has it)
	double wheel_radius;
	bool reachable;

	// Movement._closest_on_segment
	static Vector2 closest_on_segment(const Vector3 &here, const Vector3 &a, const Vector3 &b) {
		const Vector2 start(a.x, a.z);
		const Vector2 span((real_t)((double)b.x - (double)a.x), (real_t)((double)b.z - (double)a.z));
		const double length_sq = (double)span.length_squared();
		if (length_sq < 0.0001) {
			return start;
		}
		double t = (double)(Vector2(here.x, here.z) - start).dot(span) / length_sq;
		t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
		return start + span * (real_t)t; // Vector2 * float narrows the scalar
	}

	// Movement._along_route(from, distance)
	Vector3 along_route(const Vector2 &from, double distance) const {
		double left = distance;
		Vector2 at = from;
		for (int i = path_index; i < size; i++) {
			const Vector2 corner(path[i].x, path[i].z);
			const double leg = (double)at.distance_to(corner);
			if (leg >= left) {
				const Vector2 carrot = at + (corner - at) * (real_t)(left / leg);
				return Vector3(carrot.x, 0, carrot.y);
			}
			left -= leg;
			at = corner;
		}
		return V3_INF;
	}

	// Movement._route_end(goal)
	Vector3 route_end(const Vector3 &goal) const {
		if (reachable || size == 0) {
			return goal;
		}
		const Vector3 &end = path[size - 1];
		return Vector3(end.x, 0, end.z);
	}

	// Movement._corner_beyond(here, goal)
	Vector3 corner_beyond(const Vector3 &goal) const {
		for (int i = path_index; i < size; i++) {
			if (flat_distance(path[i], here) >= WAYPOINT_MIN_M) {
				return Vector3(path[i].x, 0, path[i].z);
			}
		}
		return route_end(goal);
	}

	// Movement._ahead_of_wheels(point)
	bool ahead_of_wheels(const Vector3 &point) const {
		const Vector2 forward = forward_raw.normalized();
		const Vector2 to((real_t)((double)point.x - (double)here.x), (real_t)((double)point.z - (double)here.z));
		if ((double)to.dot(forward) <= 0.0) {
			return false;
		}
		const Vector2 left(forward.y, -forward.x);
		const double radius = wheel_radius;
		for (real_t side : { (real_t)1.0, (real_t)-1.0 }) {
			// (to - left * side * radius).length() < radius: each Vector2 * float narrows its scalar.
			if ((double)(to - left * side * (real_t)radius).length() < radius) {
				return false;
			}
		}
		return true;
	}
};

} // namespace

// Movement._chord_on_mesh with its per-frame memo (BrainSwitches.chord_memo, hoisted slack): the memo's state comes in
// and goes back out through `chord`, so the GDScript's later asks in the same tick (the guard) see it.
bool TankNative::RouteChord::on_mesh(const Vector3 &from, const Vector3 &to) {
	if (valid && from == memo_from && to == memo_to) {
		return answer;
	}
	bool result = true;
	if (ready && nav != nullptr) {
		result = nav->chord_on_mesh(map, from, to, samples, slack);
	}
	computed++;
	valid = true;
	memo_from = from;
	memo_to = to;
	answer = result;
	return result;
}

// The tail of _next_waypoint, from "Where am I along the route" to its return. flags: 1 reachable, 2 skip the chord
// (`--nav-off=chord`), 4 the navmesh is ready (Pathing.enabled and is_ready), 8 the chord memo is this frame's, 16
// the memo's answer, 32 two chord samples (BrainLevers.chord_samples >= 2; else the end only).
// Returns [waypoint x, y, z, the new _path_index, memo valid, memo from x, y, z, memo to x, y, z, memo answer,
// chords computed].
PackedFloat32Array TankNative::follow_route(const Vector3 &here, const Vector3 &basis_z, const PackedVector3Array &path,
		int path_index, const Vector3 &goal, double wheel_radius, int flags, double slack, const RID &map,
		const Vector3 &memo_from, const Vector3 &memo_to, Object *nav_object) {
	Route r;
	r.path = path.ptr();
	r.size = path.size();
	r.here = here;
	r.forward_raw = Vector2(-basis_z.x, -basis_z.z);
	r.wheel_radius = wheel_radius;
	r.reachable = (flags & 1) != 0;
	RouteChord chord;
	chord.nav = Object::cast_to<NavNative>(nav_object);
	chord.map = map;
	chord.ready = (flags & 4) != 0;
	chord.valid = (flags & 8) != 0;
	chord.answer = (flags & 16) != 0;
	chord.memo_from = memo_from;
	chord.memo_to = memo_to;
	chord.slack = slack;
	if ((flags & 32) != 0) {
		chord.samples.push_back(0.5);
	}
	chord.samples.push_back(1.0);
	const bool skip_chord = (flags & 2) != 0;

	Vector3 result;
	// var best := INF; var best_segment := _path_index - 1; var best_point := Vector2(here.x, here.z)
	double best = INFINITY;
	int best_segment = path_index - 1;
	Vector2 best_point(here.x, here.z);
	const int from_segment = MAX(path_index - 1, 0);
	const int to_segment = MIN(path_index + 2, r.size - 1);
	for (int segment = from_segment; segment < to_segment; segment++) {
		const Vector2 point = Route::closest_on_segment(here, r.path[segment], r.path[segment + 1]);
		const double distance = (double)Vector2(here.x, here.z).distance_squared_to(point);
		if (distance < best) {
			best = distance;
			best_segment = segment;
			best_point = point;
		}
	}
	r.path_index = best_segment + 1;
	if (r.path_index >= r.size) {
		r.path_index = r.size - 1; // unreachable from the GDScript (it would index past the route); never taken
	}
	const double look = MAX(PATH_LOOKAHEAD, wheel_radius * WHEELS_LOOKAHEAD_RADII);
	const Vector2 forward = r.forward_raw;
	const Vector3 &next = r.path[r.path_index];
	const Vector2 toward((real_t)((double)next.x - (double)here.x), (real_t)((double)next.z - (double)here.z));
	bool done = false;
	if ((double)toward.length_squared() > 0.01 &&
			(double)forward.normalized().dot(toward.normalized()) < CARROT_ALIGNED_COS) {
		// Facing well away from the route: a fixed corner at least a lookahead away.
		result = r.route_end(goal);
		for (int i = r.path_index; i < r.size; i++) {
			if (flat_distance(r.path[i], here) >= look && (wheel_radius <= 0.0 || r.ahead_of_wheels(r.path[i]))) {
				result = Vector3(r.path[i].x, 0, r.path[i].z);
				break;
			}
		}
		done = true;
	}
	if (!done) {
		Vector3 point = r.along_route(best_point, look);
		if (point != V3_INF && !skip_chord && !chord.on_mesh(here, point)) {
			point = V3_INF;
			for (double share : CARROT_PULLBACK) {
				const Vector3 nearer = r.along_route(best_point, look * share);
				if (nearer != V3_INF && chord.on_mesh(here, nearer)) {
					point = nearer;
					break;
				}
			}
			result = point == V3_INF ? r.corner_beyond(goal) : point;
			done = true;
		}
		if (!done) {
			if (wheel_radius > 0.0) {
				const Vector3 carrot = point;
				double further = look;
				while (point != V3_INF && !r.ahead_of_wheels(point) &&
						further < look + WHEELS_LOOKAHEAD_MAX_RADII * wheel_radius) {
					further += wheel_radius;
					point = r.along_route(best_point, further);
				}
				if (point != V3_INF && point != carrot && !skip_chord && !chord.on_mesh(here, point)) {
					point = carrot;
				}
			}
			result = point != V3_INF ? point : r.route_end(goal);
		}
	}
	PackedFloat32Array out;
	out.resize(14);
	float *o = out.ptrw();
	o[0] = result.x;
	o[1] = result.y;
	o[2] = result.z;
	o[3] = (float)r.path_index;
	o[4] = chord.valid ? 1.0f : 0.0f;
	o[5] = chord.memo_from.x;
	o[6] = chord.memo_from.y;
	o[7] = chord.memo_from.z;
	o[8] = chord.memo_to.x;
	o[9] = chord.memo_to.y;
	o[10] = chord.memo_to.z;
	o[11] = chord.answer ? 1.0f : 0.0f;
	o[12] = (float)chord.computed;
	o[13] = 0.0f;
	return out;
}

PackedFloat64Array TankNative::route_constants() const {
	PackedFloat64Array c;
	for (double v : { PATH_LOOKAHEAD, WHEELS_LOOKAHEAD_RADII, CARROT_ALIGNED_COS, WHEELS_LOOKAHEAD_MAX_RADII,
				 CARROT_PULLBACK[0], CARROT_PULLBACK[1], WAYPOINT_MIN_M }) {
		c.push_back(v);
	}
	return c;
}

} // namespace godot
