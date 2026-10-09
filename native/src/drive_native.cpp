#include "drive_native.h"

#include "avoidance.h"
#include "nav_native.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <chrono>
#include <cmath>

namespace godot {

namespace {

const Vector3 V3_INF(INFINITY, INFINITY, INFINITY);

// Measurement only (drive_profile): microseconds spent inside each callback into GDScript, and the drives counted.
struct CallbackClock {
	HashMap<String, double> usec;
	int64_t drives = 0;
	double total = 0.0;
};
CallbackClock &clock_() {
	static CallbackClock c;
	return c;
}
struct Timed {
	const char *name;
	std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
	explicit Timed(const char *p_name) :
			name(p_name) {}
	~Timed() {
		const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count();
		const String key(name);
		double *v = clock_().usec.getptr(key);
		if (v) {
			*v += us;
		} else {
			clock_().usec.insert(key, us);
		}
	}
};

// Every member and static name drive touches, made once.
struct N {
	// Movement members
	StringName ctl{ "ctl" }, _repair_for{ "_repair_for" }, _repair_to{ "_repair_to" }, _goal{ "_goal" },
			_order_ticks{ "_order_ticks" }, arc_live{ "arc_live" }, _arrive{ "_arrive" }, _remaining{ "_remaining" },
			_deflected{ "_deflected" }, _give_way_left{ "_give_way_left" }, _blocked_ticks{ "_blocked_ticks" },
			give_ways{ "give_ways" }, _kturn_left_m{ "_kturn_left_m" }, _kturn_legs{ "_kturn_legs" },
			_ease_ticks{ "_ease_ticks" }, _ease_throttle{ "_ease_throttle" }, _circling{ "_circling" },
			_nose_at_end{ "_nose_at_end" }, steer_to{ "steer_to" }, pace_now{ "pace_now" }, stationed_now{ "stationed_now" },
			_station{ "_station" }, _goal_velocity{ "_goal_velocity" }, _reverse_why{ "_reverse_why" },
			stalled_ticks{ "stalled_ticks" }, _ask_left{ "_ask_left" }, _ticks{ "_ticks" }, _reissued{ "_reissued" },
			_goal_seen{ "_goal_seen" }, _goal_changed_at{ "_goal_changed_at" }, _deflect_window{ "_deflect_window" },
			_wedge_trail{ "_wedge_trail" }, wedged{ "wedged" }, wedge_moved_m{ "wedge_moved_m" },
			wedge_hull_m{ "wedge_hull_m" }, _progress_goal{ "_progress_goal" }, _progress_best{ "_progress_best" },
			phase{ "phase" }, blocked_by{ "blocked_by" }, _reachable{ "_reachable" }, _path{ "_path" },
			_path_index{ "_path_index" }, _blocker_left{ "_blocker_left" }, _repath_left{ "_repath_left" },
			_path_goal{ "_path_goal" }, last_replan{ "last_replan" }, _route_reading{ "_route_reading" },
			_chord_frame{ "_chord_frame" }, _chord_from{ "_chord_from" }, _chord_to{ "_chord_to" },
			_chord_answer{ "_chord_answer" }, _wheel_radius_unit{ "_wheel_radius_unit" },
			_wheel_radius_value{ "_wheel_radius_value" };
	// Movement statics (through the script)
	StringName leash_orders{ "leash_orders" }, avoidance_on{ "avoidance_on" }, station_on{ "station_on" },
			kturn_eased{ "kturn_eased" }, circle_reverse_ticks{ "circle_reverse_ticks" }, circle_reverses{ "circle_reverses" },
			wedged_units{ "wedged_units" }, a1_replans{ "a1_replans" }, a1_cadence_due{ "a1_cadence_due" },
			a1_by_cause{ "a1_by_cause" }, route_not_ready{ "route_not_ready" }, guard_rescues{ "guard_rescues" };
	// methods called back
	StringName _approach_gate{ "_approach_gate" }, _around_fire{ "_around_fire" }, _avoid{ "_avoid" },
			_planned_reverse{ "_planned_reverse" }, _kturn_end{ "_kturn_end" }, _keep_station{ "_keep_station" },
			reset{ "reset" }, _repair{ "_repair" }, _blocker{ "_blocker" }, _negotiate{ "_negotiate" },
			wheel_radius{ "wheel_radius" }, settle_radius{ "settle_radius" }, hull_box{ "hull_box" },
			_inflate_corners{ "_inflate_corners" }, _chord_slack{ "_chord_slack" }, is_ready{ "is_ready" },
			query{ "query" }, enabled{ "enabled" }, chord_samples{ "chord_samples" }, new_{ "new" }, clear{ "clear" };
	// others
	StringName tank{ "tank" }, tanks_root{ "tanks_root" }, _step{ "_step" }, unit_id{ "unit_id" }, _speed{ "_speed" },
			max_forward_speed{ "max_forward_speed" }, team{ "team" }, throttle{ "throttle" }, turn{ "turn" },
			x{ "x" }, z{ "z" }, leash{ "leash" }, direct{ "direct" }, speed{ "speed" }, arrive{ "arrive" },
			reverse{ "reverse" }, paced{ "paced" }, facing{ "facing" }, points{ "points" }, ready{ "ready" },
			reachable{ "reachable" }, goal_gap_m{ "goal_gap_m" }, goal_slid{ "goal_slid" }, goal_jumped{ "goal_jumped" },
			off_path{ "off_path" }, stalled{ "stalled" }, cadence{ "cadence" }, empty{ "" },
			// _avoid
			estimated_velocity{ "estimated_velocity" }, _table_root{ "_table_root" }, _table_frame{ "_table_frame" },
			refresh{ "refresh" }, solve{ "solve" }, solved{ "solved" }, deflected{ "deflected" },
			oriented_pairs{ "oriented_pairs" }, orca_neighbours{ "orca_neighbours" }, native_avoid{ "native_avoid" },
			native_nav{ "native_nav" }, closest_point{ "closest_point" }, avoid_site{ "avoid" }, radius_of{ "radius_of" },
			// fast paths
			game_match{ "game_match" }, tick{ "tick" }, think_offset{ "think_offset" }, _stride{ "_stride" },
			_fire_detour{ "_fire_detour" }, _fire_checked_tick{ "_fire_checked_tick" }, _kturn_check{ "_kturn_check" },
			_bake_radius{ "_bake_radius" }, split{ "split" },
			gates_offered{ "gates_offered" }, gates_aimed{ "gates_aimed" }, gates_refused{ "gates_refused" },
			gate_refusals{ "gate_refusals" }, gate_off_mesh_fit{ "gate_off_mesh_fit" }, gate_site{ "gate" },
			// the k-turn leg
			_kturn_rolling{ "_kturn_rolling" }, _kturn_gear{ "_kturn_gear" }, _kturn_from{ "_kturn_from" },
			_kturn_timeout{ "_kturn_timeout" }, _kturn_turn{ "_kturn_turn" }, _kturn_leg_no{ "_kturn_leg_no" },
			_kturn_plan_pose{ "_kturn_plan_pose" }, _kturn_looks{ "_kturn_looks" }, contact{ "contact" },
			touching{ "touching" }, decided{ "decided" }, point{ "point" }, normal{ "normal" },
			kturn_aborted{ "kturn_aborted" }, kturn_ticks{ "kturn_ticks" }, _braking{ "_braking" };
};
const N &n_() {
	static const N names;
	return names;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

// Movement._flat_distance
inline double flat_distance(const Vector3 &a, const Vector3 &b) {
	return (double)Vector2((real_t)((double)a.x - (double)b.x), (real_t)((double)a.z - (double)b.z)).length();
}

inline double deg_to_rad(double deg) {
	return deg * (Math::PI / 180.0); // Math::deg_to_rad(double)
}

// ---- steering.gd, line by line ----

Vector2 drive_toward(const DriveConfig &c, const Vector3 &position, const Vector3 &forward, const Vector3 &target,
		double arrive_radius, double remaining_distance, bool backward) {
	const Vector3 to_target((real_t)((double)target.x - (double)position.x), 0, (real_t)((double)target.z - (double)position.z));
	const double distance = to_target.length();
	if (distance <= arrive_radius) {
		return Vector2();
	}
	const double slow_for = remaining_distance >= 0.0 ? remaining_distance : distance;
	Vector3 flat_forward = Vector3(forward.x, 0, forward.z).normalized();
	if (backward) {
		flat_forward = -flat_forward; // reverse_toward: -Vector3(forward.x, 0, forward.z).normalized()
	}
	const double error = flat_forward.signed_angle_to(to_target, Vector3(0, 1, 0));
	const double turn = clampd(-error / deg_to_rad(c.FULL_TURN_ERROR_DEG), -1.0, 1.0);
	double throttle = 0.0;
	if (std::fabs(error) < deg_to_rad(c.TURN_IN_PLACE_DEG)) {
		throttle = std::cos(error) * clampd(slow_for / c.SLOW_RADIUS, 0.35, 1.0);
		if (backward) {
			throttle = -std::cos(error) * clampd(slow_for / c.SLOW_RADIUS, 0.35, 1.0);
		}
	}
	return Vector2((real_t)throttle, (real_t)turn);
}

Vector2 wheels(const DriveConfig &c, const Vector3 &position, const Vector3 &forward, const Vector3 &target,
		double arrive_radius, double min_turn_radius, double speed, double remaining_distance, double gear) {
	const Vector3 to_target((real_t)((double)target.x - (double)position.x), 0, (real_t)((double)target.z - (double)position.z));
	const double distance = to_target.length();
	if (distance <= arrive_radius) {
		return Vector2();
	}
	const double slow_for = remaining_distance >= 0.0 ? remaining_distance : distance;
	const Vector3 heading = Vector3(forward.x, 0, forward.z).normalized() * (real_t)gear;
	const double error = heading.signed_angle_to(to_target, Vector3(0, 1, 0));
	const double radius = MAX(min_turn_radius, 0.5);
	const Vector3 left(heading.z, 0, -heading.x);
	const double side = error >= 0.0 ? 1.0 : -1.0;
	const double from_center = (Vector3(position.x, 0, position.z) + left * (real_t)side * (real_t)radius)
									   .distance_to(Vector3(target.x, 0, target.z));
	const bool backing = speed * gear < -0.5;
	if (from_center < radius || (backing && from_center < radius + c.WHEELS_CIRCLE_MARGIN)) {
		return Vector2((real_t)(-c.WHEELS_REVERSE_THROTTLE * gear), (real_t)(-side));
	}
	const double pursuit = -2.0 * std::sin(error) / distance * radius;
	const double swing = -error / deg_to_rad(c.WHEELS_FULL_LOCK_DEG);
	const double turn = clampd(std::fabs(pursuit) > std::fabs(swing) ? pursuit : swing, -1.0, 1.0);
	const double throttle = clampd(slow_for / c.SLOW_RADIUS, c.WHEELS_MIN_THROTTLE, 1.0) * (1.0 - 0.25 * std::fabs(turn));
	return Vector2((real_t)(MAX(throttle, c.WHEELS_MIN_THROTTLE) * gear), (real_t)turn);
}

// ---- the mover, its tank and its statics ----

struct Drive {
	const DriveConfig &c;
	const N &k;
	Object *m; // the Movement
	Object *script; // its script (the statics)
	Object *ctl;
	Node3D *tank;
	Vector3 here; // tank.global_position (constant for the whole drive)
	Vector3 basis_z; // tank.global_basis.z
	int64_t step;
	int64_t frame = -1;
	bool ready_known = false, ready_value = false;
	// _chord_slack() (a pure function of the hull) and BrainLevers.chord_samples (fixed inside a tick): asked once a
	// drive, at the first chord computed, where the GDScript asks them at every chord.
	bool chord_known = false;
	double chord_slack = 0.0;
	PackedFloat64Array chord_samples;

	Drive(const DriveConfig &p_c, Object *p_m) :
			c(p_c), k(n_()), m(p_m) {}

	Variant get(const StringName &name) const { return m->get(name); }
	void set(const StringName &name, const Variant &v) { m->set(name, v); }
	Variant sget(const StringName &name) const { return script->get(name); }
	void sset(const StringName &name, const Variant &v) { script->set(name, v); }
	void sadd(const StringName &name, int64_t by) { script->set(name, (int64_t)script->get(name) + by); }

	// Pathing.enabled and Pathing.is_ready(tank): asked once a drive (the navmesh does not change inside a tick).
	bool pathing_ready() {
		if (!ready_known) {
			ready_known = true;
			ready_value = (bool)c.pathing->get(k.enabled) && (bool)c.pathing->call(k.is_ready, tank);
		}
		return ready_value;
	}

	double wheel_radius() {
		// Movement.wheel_radius(): its per-unit cache, filled by the GDScript the first time.
		const String unit = tank->get(k.unit_id);
		if (String(get(k._wheel_radius_unit)) == unit) {
			return get(k._wheel_radius_value);
		}
		return m->call(k.wheel_radius);
	}

	// Movement._chord_on_mesh (chord_memo on): the memo in the mover's members, as the GDScript keeps it.
	bool chord_on_mesh(const Vector3 &from, const Vector3 &to) {
		if (frame < 0) {
			frame = Engine_frames();
		}
		if ((int64_t)get(k._chord_frame) == frame && (Vector3)get(k._chord_from) == from && (Vector3)get(k._chord_to) == to) {
			return get(k._chord_answer);
		}
		const bool answer = chord_compute(from, to);
		set(k._chord_answer, answer);
		set(k._chord_frame, frame);
		set(k._chord_from, from);
		set(k._chord_to, to);
		return answer;
	}

	// Movement._chord_compute (hoisted slack): the sampling loop is N2b's native one (proven equal to it).
	bool chord_compute(const Vector3 &from, const Vector3 &to) {
		if (!pathing_ready()) {
			return true;
		}
		if (!chord_known) {
			Timed t("chord_slack+levers");
			chord_known = true;
			chord_slack = hull_chord_slack();
			if (lever(true) >= 2) {
				chord_samples.push_back(0.5);
			}
			chord_samples.push_back(1.0);
		}
		const RID map = tank->get_world_3d()->get_navigation_map();
		Timed t("chord_native");
		return c.nav->chord_on_mesh(map, from, to, chord_samples, chord_slack);
	}

	static int64_t Engine_frames();

	// ---- route helpers (Movement._closest_on_segment, _off_path, _along_route, _route_end, _corner_beyond,
	// _ahead_of_wheels, _remaining_path_distance), over the route as it is in the mover ----
	static Vector2 closest_on_segment(const Vector3 &p, const Vector3 &a, const Vector3 &b) {
		const Vector2 start(a.x, a.z);
		const Vector2 span((real_t)((double)b.x - (double)a.x), (real_t)((double)b.z - (double)a.z));
		const double length_sq = span.length_squared();
		if (length_sq < 0.0001) {
			return start;
		}
		const double t = clampd((double)(Vector2(p.x, p.z) - start).dot(span) / length_sq, 0.0, 1.0);
		return start + span * (real_t)t;
	}

	static double off_path(const PackedVector3Array &path, int64_t path_index, const Vector3 &p) {
		double best = INFINITY;
		const int64_t to = MIN(path_index + 2, (int64_t)path.size() - 1);
		for (int64_t segment = MAX(path_index - 1, (int64_t)0); segment < to; segment++) {
			best = MIN(best, (double)Vector2(p.x, p.z).distance_to(closest_on_segment(p, path[segment], path[segment + 1])));
		}
		return best;
	}

	static Vector3 along_route(const PackedVector3Array &path, int64_t path_index, const Vector2 &from, double distance) {
		double left = distance;
		Vector2 at = from;
		for (int64_t i = path_index; i < path.size(); i++) {
			const Vector2 corner(path[i].x, path[i].z);
			const double leg = at.distance_to(corner);
			if (leg >= left) {
				const Vector2 carrot = at + (corner - at) * (real_t)(left / leg);
				return Vector3(carrot.x, 0, carrot.y);
			}
			left -= leg;
			at = corner;
		}
		return V3_INF;
	}

	Vector3 route_end(const PackedVector3Array &path, const Vector3 &goal) const {
		if ((bool)get(k._reachable) || path.is_empty()) {
			return goal;
		}
		const Vector3 end = path[path.size() - 1];
		return Vector3(end.x, 0, end.z);
	}

	Vector3 corner_beyond(const PackedVector3Array &path, int64_t path_index, const Vector3 &goal) const {
		for (int64_t i = path_index; i < path.size(); i++) {
			if (flat_distance(path[i], here) >= c.WAYPOINT_MIN_M) {
				return Vector3(path[i].x, 0, path[i].z);
			}
		}
		return route_end(path, goal);
	}

	bool ahead_of_wheels(const Vector3 &point, double radius) const {
		const Vector2 forward = Vector2(-basis_z.x, -basis_z.z).normalized();
		const Vector2 to((real_t)((double)point.x - (double)here.x), (real_t)((double)point.z - (double)here.z));
		if ((double)to.dot(forward) <= 0.0) {
			return false;
		}
		const Vector2 left(forward.y, -forward.x);
		for (real_t side : { (real_t)1.0, (real_t)-1.0 }) {
			if ((double)(to - left * side * (real_t)radius).length() < radius) {
				return false;
			}
		}
		return true;
	}

	double remaining_path_distance(const Vector3 &goal) const {
		const PackedVector3Array path = get(k._path);
		const int64_t path_index = get(k._path_index);
		if (path_index >= path.size()) {
			return flat_distance(here, goal);
		}
		double total = flat_distance(here, path[path_index]);
		for (int64_t i = path_index; i < path.size() - 1; i++) {
			total += flat_distance(path[i], path[i + 1]);
		}
		return total;
	}

	// ---- Movement._avoid (grace, minpace at their defaults; oriented_on() the opt-in arm, off) -> [point, keep] ----
	void avoid(const Vector3 &waypoint, double speed_factor, double delta, Vector3 &out_point, double &out_keep) {
		out_point = waypoint;
		out_keep = 1.0;
		const Vector2 to((real_t)((double)waypoint.x - (double)here.x), (real_t)((double)waypoint.z - (double)here.z));
		const double distance = to.length();
		if (distance < 0.5) {
			return;
		}
		// Avoidance.refresh(ctl.tanks_root): a no-op when this tick's table is built (the usual case: the first mover
		// that avoided built it); otherwise the live GDScript builds it.
		Object *tanks_root = ctl->get(k.tanks_root).get_validated_object();
		Object *av = c.avoidance_script;
		if ((int64_t)av->get(k._table_root) != (int64_t)tanks_root->get_instance_id() ||
				(int64_t)av->get(k._table_frame) != Engine_frames()) {
			av->call(k.refresh, tanks_root);
		}
		const double slow = clampd((double)get(k._remaining) / c.SLOW_RADIUS, 0.35, 1.0);
		const double max_speed = tank->get(k.max_forward_speed);
		const double desired = max_speed * speed_factor * slow;
		const Vector2 preferred = to / (real_t)distance * (real_t)desired; // Vector2 / float, * float: scalars narrowed
		const String name = tank->get_name();
		const String unit = tank->get(k.unit_id);
		const double *known = c.radius_of.getptr(unit);
		double radius;
		if (known != nullptr) {
			radius = *known;
		} else {
			radius = av->call(k.radius_of, unit);
			c.radius_of.insert(unit, radius);
		}
		int64_t cap;
		{
			Timed t("orca_neighbours");
			cap = lever(false);
		}
		const Vector3 velocity3 = tank->get(k.estimated_velocity);
		const Vector2 position(here.x, here.z);
		const Vector2 velocity(velocity3.x, velocity3.z);
		Vector2 chosen;
		if ((bool)c.switches->get(k.native_avoid)) {
			// Avoidance.solve's native branch, with its counters.
			int near_count = 0, oriented_count = 0;
			Timed t("solve_native");
			const Vector2 result = c.avoidance->solve(name, position, velocity, preferred, max_speed, radius, delta, (int)cap,
					false, near_count, oriented_count);
			const int packed = (int)(real_t)(near_count + 16 * oriented_count); // int(r.z): the counters ride in a float32
			if (packed == 0) {
				chosen = preferred;
			} else {
				sadd_on(av, k.solved, 1);
				sadd_on(av, k.oriented_pairs, packed / 16);
				chosen = Vector2(result.x, result.y);
				if ((double)chosen.distance_squared_to(preferred) > 0.01) {
					sadd_on(av, k.deflected, 1);
				}
			}
		} else {
			chosen = av->call(k.solve, name, position, velocity, preferred, max_speed, radius, delta, cap);
		}
		if ((double)chosen.distance_squared_to(preferred) < 0.04) {
			return;
		}
		const double speed = chosen.length();
		double keep = clampd(speed / MAX(desired, 0.1), 0.0, 1.0);
		const bool starting = (int64_t)get(k._order_ticks) < c.AVOID_GRACE_TICKS;
		if (starting && (double)chosen.dot(preferred) > 0.0) {
			keep = MAX(keep, c.AVOID_MIN_PACE);
		}
		out_keep = keep;
		if (starting || speed < 0.3) {
			return;
		}
		const Vector2 direction = chosen / (real_t)speed;
		const Vector3 probe((real_t)((double)here.x + (double)direction.x * c.AVOID_MESH_PROBE), 0,
				(real_t)((double)here.z + (double)direction.y * c.AVOID_MESH_PROBE));
		if (pathing_ready()) {
			const RID map = tank->get_world_3d()->get_navigation_map();
			Vector3 on_mesh;
			if ((bool)c.switches->get(k.native_nav)) {
				on_mesh = c.nav->closest_point(map, probe); // Pathing.closest_point's native branch (N2a)
			} else {
				on_mesh = c.pathing->call(k.closest_point, map, probe, k.avoid_site);
			}
			if (flat_distance(on_mesh, probe) > c.AVOID_MESH_SLACK) {
				return;
			}
		}
		const double wheel = wheel_radius();
		const double reach = wheel * c.WHEELS_LOOKAHEAD_RADII;
		const double look = clampd(distance, MAX(c.AVOID_STEER_MIN, reach), MAX(c.AVOID_STEER_MAX, reach));
		const Vector3 point((real_t)((double)here.x + (double)direction.x * look), 0,
				(real_t)((double)here.z + (double)direction.y * look));
		if (wheel > 0.0 && !ahead_of_wheels(point, wheel)) {
			return;
		}
		out_point = point;
	}

	static void sadd_on(Object *script, const StringName &name, int64_t by) {
		script->set(name, (int64_t)script->get(name) + by);
	}

	// Movement._chord_slack() with the clearance arm off (the default): max(CHORD_SLACK, bake_radius(tank) -
	// hull_box(unit)[0] / 2.0 - CHORD_MARGIN), over the memoized bake radius; the GDScript while it is not known yet.
	double hull_chord_slack() {
		const double bake = script->get(k._bake_radius);
		if (bake < 0.0) {
			return m->call(k._chord_slack);
		}
		const String unit = tank->get(k.unit_id);
		const double *known = c.hull_width_of.getptr(unit);
		double width;
		if (known != nullptr) {
			width = *known;
		} else {
			const Array size = script->call(k.hull_box, unit);
			width = size[0];
			c.hull_width_of.insert(unit, width);
		}
		return MAX(c.CHORD_SLACK, bake - width / 2.0 - c.CHORD_MARGIN);
	}

	// BrainLevers.chord_samples (chord) or orca_neighbours (!chord) for this tank: per team for this physics frame
	// while the per-unit split is off, else asked of the GDScript.
	int64_t lever(bool chord) {
		const int64_t team = tank->get(k.team);
		if (team < 0 || team > 1 || (bool)c.levers->get(k.split)) {
			return c.levers->call(chord ? k.chord_samples : k.orca_neighbours, team, String(tank->get_name()));
		}
		const int64_t now = Engine_frames();
		if (c.levers_frame != now) {
			c.levers_frame = now;
			c.chord_samples_known[0] = c.chord_samples_known[1] = c.orca_known[0] = c.orca_known[1] = false;
		}
		bool *known = chord ? c.chord_samples_known : c.orca_known;
		int64_t *value = chord ? c.chord_samples_of : c.orca_of;
		if (!known[team]) {
			known[team] = true;
			value[team] = c.levers->call(chord ? k.chord_samples : k.orca_neighbours, team, String(tank->get_name()));
		}
		return value[team];
	}

	// ---- the k-turn leg (no reverse_log / kturn_log: _kturn_rec stays empty, so _kturn_end only clears the looks) ----
	double braking() {
		const String unit = tank->get(k.unit_id);
		const double *known = c.braking_of.getptr(unit);
		if (known != nullptr) {
			return *known;
		}
		const double value = m->call(k._braking);
		c.braking_of.insert(unit, value);
		return value;
	}

	// kturn_brake_on(): kturn on, kturnbrake not off (defaults) -> kturn_brake_all() (opt-in, off) or a long hull.
	bool kturn_brake_on() {
		const String unit = tank->get(k.unit_id);
		const double *known = c.hull_length_of.getptr(unit);
		double hull;
		if (known != nullptr) {
			hull = *known;
		} else {
			const Array size = script->call(k.hull_box, unit);
			hull = size[2];
			c.hull_length_of.insert(unit, hull);
		}
		return hull >= c.KTURN_BRAKE_HULL_M;
	}

	double kturn_stopping() {
		if (!kturn_brake_on()) {
			return 0.0;
		}
		const double speed = (double)tank->get(k._speed) * (double)(int64_t)get(k._kturn_gear);
		return speed > 0.0 ? speed * speed / (2.0 * braking()) : 0.0;
	}

	void kturn_end() {
		Array looks = get(k._kturn_looks);
		looks.clear();
	}

	void kturn_start_leg(const Vector2 &leg) {
		set(k._kturn_gear, (int64_t)leg.x);
		set(k._kturn_left_m, (double)leg.y);
		set(k._kturn_from, here);
		double timeout = (double)leg.y * c.KTURN_SECONDS_PER_M + 1.0;
		const double speed = tank->get(k._speed);
		const bool rolling = !kturn_brake_on() || speed * (double)leg.x > -c.KTURN_ROLLING_SPEED;
		set(k._kturn_rolling, rolling);
		if (!rolling) {
			timeout += std::fabs(speed) / braking();
		}
		set(k._kturn_timeout, timeout);
		set(k._kturn_leg_no, (int64_t)get(k._kturn_leg_no) + 1);
		set(k._kturn_plan_pose, Array());
	}

	// _planned_reverse while a leg is being driven (_kturn_left_m > 0): true and the leg's throttle/turn, or false
	// (the leg ended; the caller drives on as a normal tick).
	bool kturn_leg(double delta, Vector2 &out) {
		const int64_t gear = get(k._kturn_gear);
		if (!(bool)get(k._kturn_rolling)) {
			if ((double)tank->get(k._speed) * (double)gear > c.KTURN_ROLLING_SPEED) {
				set(k._kturn_rolling, true);
			}
			set(k._kturn_from, here);
		}
		const double backed = flat_distance(here, get(k._kturn_from));
		const double left = get(k._kturn_left_m);
		const bool reached = backed + kturn_stopping() >= left;
		const double timeout = (double)get(k._kturn_timeout) - delta;
		set(k._kturn_timeout, timeout);
		const Vector2 nose(-basis_z.x, -basis_z.z);
		Object *wall = get(k.contact).get_validated_object();
		bool lead_hit = false;
		if (wall != nullptr && (bool)wall->get(k.touching)) {
			const Dictionary decided_now = wall->get(k.decided);
			const Vector3 at = wall->get(k.point);
			if ((double)decided_now.get(k.throttle, 0.0) * (double)gear > 0.0 &&
					(double)Vector2((real_t)((double)at.x - (double)here.x), (real_t)((double)at.z - (double)here.z)).dot(nose) * (double)gear > 0.0) {
				const Vector3 wall_normal = wall->get(k.normal);
				lead_hit = (double)Vector2(wall_normal.x, wall_normal.z).dot(nose * (real_t)gear) < -c.KTURN_INTO_WALL_COS;
			}
		}
		Array legs = get(k._kturn_legs);
		if (reached && !legs.is_empty()) {
			kturn_end();
			const Vector2 next = legs.pop_front();
			kturn_start_leg(next);
		} else if (reached || timeout <= 0.0 || lead_hit) {
			kturn_end();
			set(k._kturn_check, 0);
			if (!reached) {
				sadd(k.kturn_aborted, 1);
				set(k._kturn_check, c.KTURN_RETRY_TICKS);
			}
			set(k._kturn_left_m, 0.0);
			legs.clear();
			set(k._repath_left, 0.0);
			return false;
		}
		const int64_t gear_now = get(k._kturn_gear);
		out = Vector2((real_t)(c.KTURN_THROTTLE * (double)gear_now), (real_t)(double)get(k._kturn_turn));
		sadd(k.kturn_ticks, step);
		return true;
	}

	// Pathing.closest_point(map, point, site): N2a's index while native_nav is on (its native branch), else the GDScript.
	Vector3 closest_point(const RID &map, const Vector3 &point, const StringName &site) {
		if ((bool)c.switches->get(k.native_nav)) {
			return c.nav->closest_point(map, point);
		}
		return c.pathing->call(k.closest_point, map, point, site);
	}

	void count_into(const StringName &dictionary, const String &key) {
		Dictionary d = sget(dictionary);
		d[key] = (int64_t)d.get(key, 0) + 1;
	}

	// Movement._gate_refused(reason, goal)
	Vector3 gate_refused(const char *reason, const Vector3 &goal) {
		sadd(k.gates_refused, 1);
		count_into(k.gate_refusals, String(reason));
		return goal;
	}

	// ---- Movement._approach_gate, A4 (the curved gate, opt-in) off: called only with a wheeled hull and a facing ----
	Vector3 approach_gate(const Vector3 &goal, const Dictionary &order, double radius) {
		sadd(k.gates_offered, 1);
		const Variant facing = order[k.facing];
		if (facing.get_type() != Variant::ARRAY || ((Array)facing).size() < 2) {
			return gate_refused("bad_facing", goal);
		}
		const Array f = facing;
		Vector2 direction((real_t)(double)f[0], (real_t)(double)f[1]);
		if ((double)direction.length_squared() < 0.0001) {
			return gate_refused("bad_facing", goal);
		}
		direction = direction.normalized();
		const double length = clampd(radius * c.APPROACH_RADII, c.APPROACH_MIN, c.APPROACH_MAX);
		const Vector3 gate((real_t)((double)goal.x - (double)direction.x * length), 0,
				(real_t)((double)goal.z - (double)direction.y * length));
		// _arrive_gate(): maxf(GATE_REACHED, settle_radius(unit))
		const String unit = tank->get(k.unit_id);
		const double *settle_known = c.settle_of.getptr(unit);
		double settle;
		if (settle_known != nullptr) {
			settle = *settle_known;
		} else {
			settle = script->call(k.settle_radius, unit);
			c.settle_of.insert(unit, settle);
		}
		if (flat_distance(here, gate) <= MAX(c.GATE_REACHED, settle)) {
			return gate_refused("reached", goal);
		}
		const Vector2 forward = Vector2(-basis_z.x, -basis_z.z).normalized();
		const Vector2 to_goal((real_t)((double)goal.x - (double)here.x), (real_t)((double)goal.z - (double)here.z));
		if ((double)to_goal.length() <= length && (double)forward.dot(direction) >= c.APPROACH_ALIGNED_COS) {
			return gate_refused("on_approach", goal);
		}
		const RID map = tank->get_world_3d()->get_navigation_map();
		if (flat_distance(closest_point(map, gate, k.gate_site), gate) > c.MESH_GATE_SLACK) {
			// _off_mesh_kind + _note_off_mesh: the longest shorter straight run-in that would fit, or "none".
			String kind("none");
			for (double share : c.OFF_MESH_PROBES) {
				const Vector3 shorter((real_t)((double)goal.x - (double)direction.x * length * share), 0,
						(real_t)((double)goal.z - (double)direction.y * length * share));
				if (flat_distance(closest_point(map, shorter, k.gate_site), shorter) <= c.MESH_GATE_SLACK) {
					kind = String("fits_at_") + String::num_int64((int64_t)(share * 100.0));
					break;
				}
			}
			count_into(k.gate_off_mesh_fit, kind);
			return gate_refused("off_mesh", goal);
		}
		sadd(k.gates_aimed, 1);
		return gate;
	}

	// ---- Movement._around_fire's off-tick return, natively ----
	// Every early return of _around_fire hands back the waypoint unchanged, and none of them changes the mover; so
	// when no detour is under way and this is not a fire-check tick (`(tick + think_offset) % FIRE_CHECK_TICKS != 0`
	// at stride 1, or fewer than FIRE_CHECK_TICKS since the last look under a stride) the answer is the waypoint,
	// whatever the earlier tests would have said. (The one thing skipped is the brain's lookup memo of the
	// suppression feed, `_suppression_fields`, which the next real check fills.) A plain OrderController (no
	// game_match) returns the waypoint too.
	bool fire_check_skips() {
		const Variant game_match_v = ctl->get(k.game_match);
		Object *game_match = game_match_v.get_type() == Variant::OBJECT ? game_match_v.get_validated_object() : nullptr;
		if (game_match == nullptr) {
			return true;
		}
		if (get(k._fire_detour).get_type() != Variant::NIL) {
			return false;
		}
		const int64_t tick = game_match->get(k.tick);
		const int64_t stride = ctl->get(k._stride);
		if (stride == 1) {
			const int64_t offset = ctl->get(k.think_offset);
			return (tick + offset) % c.FIRE_CHECK_TICKS != 0;
		}
		if (stride > 1) {
			return tick - (int64_t)get(k._fire_checked_tick) < c.FIRE_CHECK_TICKS;
		}
		return false;
	}

	// ---- Movement._track_goal ----
	void track_goal(const Vector3 &goal) {
		const int64_t ticks = (int64_t)get(k._ticks) + step;
		set(k._ticks, ticks);
		const bool reissued = get(k._reissued);
		set(k._reissued, false);
		const Vector3 seen = get(k._goal_seen);
		if (seen == V3_INF) {
			set(k._goal_seen, goal);
			set(k._goal_changed_at, ticks);
			set(k._goal_velocity, Vector2());
			return;
		}
		const Vector2 moved((real_t)((double)goal.x - (double)seen.x), (real_t)((double)goal.z - (double)seen.z));
		const double seconds = (double)(ticks - (int64_t)get(k._goal_changed_at)) / (double)c.TICK_RATE;
		if ((double)moved.length_squared() > 0.0001) {
			const Vector2 velocity = moved / (real_t)MAX(seconds, 1.0 / (double)c.TICK_RATE);
			const double max_speed = tank->get(k.max_forward_speed);
			set(k._goal_velocity, (double)velocity.length() > 2.0 * max_speed ? Vector2() : velocity);
			set(k._goal_seen, goal);
			set(k._goal_changed_at, ticks);
		} else if (seconds > c.STATION_STALE_SECONDS || (reissued && seconds > c.STATION_STOPPED_SECONDS)) {
			set(k._goal_velocity, Vector2());
		}
	}

	// ---- Movement._next_waypoint (a1, repath, notready, carrot, chord all at their defaults) ----
	Vector3 next_waypoint(const Vector3 &goal, double delta) {
		double repath_left = (double)get(k._repath_left) - delta;
		set(k._repath_left, repath_left);
		PackedVector3Array path = get(k._path);
		int64_t path_index = get(k._path_index);
		const bool is_off_path = path.size() >= 2 && off_path(path, path_index, here) > c.OFF_PATH_REPATH;
		const int64_t stalled_ticks = get(k.stalled_ticks);
		const int64_t blocked_every = (int64_t)(c.BLOCKED_SECONDS * (double)c.TICK_RATE);
		const bool stalled = stalled_ticks > 0 && stalled_ticks % blocked_every == 0;
		set(k.last_replan, k.empty);
		const bool cadence_due = repath_left <= 0.0;
		if (cadence_due) {
			sadd(k.a1_cadence_due, 1);
			repath_left = c.REPATH_SECONDS;
			set(k._repath_left, repath_left);
		}
		const bool drifted = cadence_due;
		const double goal_shift = flat_distance(goal, get(k._path_goal));
		const bool sliding = (double)((Vector2)get(k._goal_velocity)).length() >= c.STATION_MIN_SPEED;
		const double tolerance = 1.0;
		const bool goal_moved = goal_shift > tolerance;
		const bool event = goal_moved || is_off_path || stalled;
		if (drifted || event) {
			sadd(k.a1_replans, 1);
			Dictionary by_cause = sget(k.a1_by_cause);
			StringName key;
			if (goal_moved) {
				key = sliding ? k.goal_slid : k.goal_jumped;
			} else if (is_off_path) {
				key = k.off_path;
			} else if (stalled) {
				key = k.stalled;
			} else {
				key = k.cadence;
			}
			const String key_s = key;
			by_cause[key_s] = (int64_t)by_cause.get(key_s, 0) + 1;
			set(k.last_replan, key);
			set(k._repath_left, c.REPATH_SECONDS);
			set(k._path_goal, goal);
			Dictionary route;
			{
				Timed t("query");
				route = c.pathing->call(k.query, tank, here, goal);
			}
			{
				Timed t("inflate_corners");
				path = m->call(k._inflate_corners, route[k.points]);
			}
			set(k._path, path);
			const bool reachable = !(bool)route[k.ready] || path.size() < 2 ||
					((bool)route[k.reachable] && (double)route[k.goal_gap_m] <= c.NO_PATH_MARGIN);
			set(k._reachable, reachable);
			set(k._route_reading, route);
			path_index = path.size() >= 2 ? 1 : path.size();
			set(k._path_index, path_index);
			if (!(bool)route[k.ready]) {
				set(k._repath_left, 0.0);
				sadd(k.route_not_ready, 1);
			}
		}
		if (path.size() < 2) {
			set(k._path_index, (int64_t)path.size());
			return goal;
		}
		// Where am I along the route: the nearest point on the next few segments (never backwards).
		double best = INFINITY;
		int64_t best_segment = path_index - 1;
		Vector2 best_point(here.x, here.z);
		const int64_t to_segment = MIN(path_index + 2, (int64_t)path.size() - 1);
		for (int64_t segment = MAX(path_index - 1, (int64_t)0); segment < to_segment; segment++) {
			const Vector2 point = closest_on_segment(here, path[segment], path[segment + 1]);
			const double distance = Vector2(here.x, here.z).distance_squared_to(point);
			if (distance < best) {
				best = distance;
				best_segment = segment;
				best_point = point;
			}
		}
		path_index = best_segment + 1;
		set(k._path_index, path_index);
		const double radius = wheel_radius();
		const double look = MAX(c.PATH_LOOKAHEAD, radius * c.WHEELS_LOOKAHEAD_RADII);
		const Vector2 forward(-basis_z.x, -basis_z.z);
		const Vector2 toward((real_t)((double)path[path_index].x - (double)here.x),
				(real_t)((double)path[path_index].z - (double)here.z));
		if ((double)toward.length_squared() > 0.01 && (double)forward.normalized().dot(toward.normalized()) < c.CARROT_ALIGNED_COS) {
			for (int64_t i = path_index; i < path.size(); i++) {
				if (flat_distance(path[i], here) >= look && (radius <= 0.0 || ahead_of_wheels(path[i], radius))) {
					return Vector3(path[i].x, 0, path[i].z);
				}
			}
			return route_end(path, goal);
		}
		Vector3 point = along_route(path, path_index, best_point, look);
		if (point != V3_INF && !chord_on_mesh(here, point)) {
			point = V3_INF;
			for (double share : { c.CARROT_PULLBACK_0, c.CARROT_PULLBACK_1 }) {
				const Vector3 nearer = along_route(path, path_index, best_point, look * share);
				if (nearer != V3_INF && chord_on_mesh(here, nearer)) {
					point = nearer;
					break;
				}
			}
			if (point == V3_INF) {
				return corner_beyond(path, path_index, goal);
			}
			return point;
		}
		if (radius > 0.0) {
			const Vector3 carrot = point;
			double further = look;
			while (point != V3_INF && !ahead_of_wheels(point, radius) && further < look + c.WHEELS_LOOKAHEAD_MAX_RADII * radius) {
				further += radius;
				point = along_route(path, path_index, best_point, further);
			}
			if (point != V3_INF && point != carrot && !chord_on_mesh(here, point)) {
				point = carrot;
			}
		}
		return point != V3_INF ? point : route_end(path, goal);
	}

	// ---- Movement._guard_steer (guard, guardnear at their defaults) ----
	Vector3 guard_steer(const Vector3 &waypoint) {
		if (chord_on_mesh(here, waypoint)) {
			return waypoint;
		}
		const PackedVector3Array path = get(k._path);
		int64_t first = get(k._path_index);
		while (first < path.size() - 1 && flat_distance(path[first], here) < c.WAYPOINT_MIN_M) {
			first += 1;
		}
		if (first < path.size()) {
			const Vector3 corner(path[first].x, 0, path[first].z);
			if (chord_on_mesh(here, corner)) {
				return corner;
			}
		}
		sadd(k.guard_rescues, 1);
		return waypoint;
	}

	// ---- Movement._note_wedge ----
	void note_wedge(bool deflected) {
		Array window = get(k._deflect_window);
		Array trail = get(k._wedge_trail);
		window.append(deflected);
		trail.append(here);
		if (window.size() > c.WEDGED_WINDOW) {
			window.remove_at(0);
			trail.remove_at(0);
		}
		if (window.size() < c.WEDGED_WINDOW) {
			set(k.wedged, false);
			return;
		}
		int64_t hits = 0;
		for (int64_t i = 0; i < window.size(); i++) {
			hits += (bool)window[i] ? 1 : 0;
		}
		const double moved = flat_distance(trail[0], trail[trail.size() - 1]);
		const String unit = tank->get(k.unit_id);
		const double *known = c.hull_length_of.getptr(unit);
		double hull;
		if (known != nullptr) {
			hull = *known;
		} else {
			const Array size = script->call(k.hull_box, unit);
			hull = size[2];
			c.hull_length_of.insert(unit, hull);
		}
		const bool was = get(k.wedged);
		set(k.wedge_moved_m, moved);
		set(k.wedge_hull_m, hull);
		const bool wedged = (double)hits / (double)c.WEDGED_WINDOW > c.WEDGED_SHARE && moved < hull;
		set(k.wedged, wedged);
		if (wedged && !was) {
			sadd(k.wedged_units, 1);
		}
	}

	// ---- Movement._track_progress ----
	void track_progress(const Vector3 &goal, const Vector2 &drive_vector, double remaining) {
		if (flat_distance(goal, get(k._progress_goal)) > 2.0 || drive_vector == Vector2()) {
			set(k._progress_goal, goal);
			set(k._progress_best, remaining);
			set(k.stalled_ticks, 0);
		} else if (remaining < (double)get(k._progress_best) - 0.5) {
			set(k._progress_best, remaining);
			set(k.stalled_ticks, 0);
		} else {
			set(k.stalled_ticks, (int64_t)get(k.stalled_ticks) + step);
		}
	}

	// ---- Movement._update_phase ----
	void update_phase(const Vector3 &goal, const Vector2 &drive_vector, bool direct) {
		static const String arrived("arrived"), blocked("blocked"), no_path("no_path"), pathing("pathing"),
				driving("driving"), none("");
		const bool reachable = get(k._reachable);
		if (drive_vector == Vector2() && (flat_distance(here, goal) <= (double)get(k._arrive) + 0.5 ||
												 ((bool)get(k._nose_at_end) && reachable))) {
			set(k.phase, arrived);
			set(k.blocked_by, none);
			return;
		}
		const PackedVector3Array path = get(k._path);
		if (!reachable && !direct && !path.is_empty() && flat_distance(here, path[path.size() - 1]) <= c.UNREACHABLE_AT_END) {
			if ((bool)m->call(k._repair, goal)) {
				return;
			}
			set(k.phase, blocked);
			set(k.blocked_by, no_path);
			return;
		}
		if ((int64_t)get(k.stalled_ticks) >= (int64_t)(c.BLOCKED_SECONDS * (double)c.TICK_RATE)) {
			int64_t left = (int64_t)get(k._blocker_left) - step;
			set(k._blocker_left, left);
			if (String(get(k.phase)) != blocked || left <= 0) {
				set(k._blocker_left, c.TICK_RATE / 2);
				set(k.blocked_by, m->call(k._blocker, goal, direct));
			}
			set(k.phase, blocked);
			return;
		}
		set(k.blocked_by, none);
		if (!direct && (bool)c.pathing->get(k.enabled) && path.is_empty() && !(bool)c.pathing->call(k.is_ready, tank)) {
			set(k.phase, pathing);
		} else {
			set(k.phase, driving);
		}
	}

	bool run(Object *cmd, const Dictionary &order, double delta);
};

} // namespace
} // namespace godot

#include <godot_cpp/classes/engine.hpp>

namespace godot {
namespace {

int64_t Drive::Engine_frames() {
	return (int64_t)Engine::get_singleton()->get_physics_frames();
}

bool Drive::run(Object *cmd, const Dictionary &order, double delta) {
	static const String r_order("order"), r_station("station"), r_circle("circle"), r_other("other"), cancelled("cancelled");
	// var goal := Vector3(order["x"], 0.0, order["z"])
	Vector3 goal((real_t)(double)order[k.x], 0, (real_t)(double)order[k.z]);
	if (order.has(k.leash)) {
		sadd(k.leash_orders, step); // leash_on() is the opt-in arm: off here
	}
	const Vector3 repair_for = get(k._repair_for);
	if (repair_for != V3_INF) {
		if (flat_distance(goal, repair_for) > c.NEW_GOAL_JUMP) {
			set(k._repair_for, V3_INF);
			set(k._repair_to, V3_INF);
		} else {
			const Vector3 repair_to = get(k._repair_to);
			if (repair_to != V3_INF) {
				goal = repair_to;
			}
		}
	}
	const Vector3 old_goal = get(k._goal);
	if (old_goal == V3_INF || flat_distance(goal, old_goal) > c.NEW_GOAL_JUMP) {
		set(k._order_ticks, 0);
	}
	set(k._goal, goal);
	{
		Timed t("~track_goal");
		track_goal(goal);
	}
	const int64_t order_ticks = (int64_t)get(k._order_ticks) + step;
	set(k._order_ticks, order_ticks);
	const bool direct = order.get(k.direct, false);
	// _approach_gate: a tracked or hover hull, or an order with no facing, aims at the goal itself.
	double radius;
	{
		Timed t("~wheel_radius");
		radius = wheel_radius();
	}
	Vector3 aim = goal;
	if (radius > 0.0 && order.has(k.facing)) {
		Timed t("~approach_gate");
		aim = approach_gate(goal, order, radius);
	}
	set(k.arc_live, aim != goal);
	Vector3 routed;
	{
		Timed t("~next_waypoint");
		routed = direct ? aim : next_waypoint(aim, delta);
	}
	if (!direct && routed != aim && flat_distance(routed, here) < c.WAYPOINT_MIN_M) {
		const PackedVector3Array path = get(k._path);
		routed = corner_beyond(path, get(k._path_index), aim);
	}
	Vector3 around_fire = routed;
	if (!fire_check_skips()) {
		Timed t("around_fire");
		around_fire = m->call(k._around_fire, routed, goal, order);
	}
	Vector3 waypoint = around_fire;
	const double speed_factor = clampd((double)order.get(k.speed, 1.0), 0.2, 1.0);
	double settle = 0.0;
	if (radius > 0.0) {
		Timed t("~settle_radius");
		const String unit = tank->get(k.unit_id);
		const double *known = c.settle_of.getptr(unit);
		if (known != nullptr) {
			settle = *known;
		} else {
			settle = script->call(k.settle_radius, unit);
			c.settle_of.insert(unit, settle);
		}
	}
	const double arrive_order = clampd((double)order.get(k.arrive, c.ARRIVE_RADIUS), 0.5, 10.0);
	const double arrive_field = MAX(arrive_order, settle);
	set(k._arrive, arrive_field);
	double arrive = around_fire == goal ? arrive_field : 0.5;
	double remaining;
	{
		Timed t("~remaining");
		remaining = direct ? flat_distance(here, goal) : remaining_path_distance(goal);
	}
	set(k._remaining, remaining);
	double pace = 1.0;
	bool deflected = false;
	set(k._deflected, false);
	const bool reverse = order.get(k.reverse, false);
	if ((bool)sget(k.avoidance_on) && !reverse && ctl->get(k.tanks_root).get_type() == Variant::OBJECT &&
			ctl->get(k.tanks_root).get_validated_object() != nullptr && flat_distance(here, around_fire) > arrive) {
		Vector3 point;
		double keep;
		{
			Timed t("~avoid");
			avoid(waypoint, speed_factor, delta, point, keep);
		}
		if (point != waypoint) {
			arrive = 0.1;
			deflected = true;
			set(k._deflected, true);
		}
		waypoint = point;
		pace = keep;
	}
	if ((bool)order.get(k.paced, false)) {
		int64_t give_way_left = get(k._give_way_left);
		if (give_way_left > 0) {
			set(k._give_way_left, give_way_left - step);
			pace = MIN(pace, c.GIVE_WAY_PACE);
		} else if (deflected && pace < 0.95) {
			int64_t blocked_ticks = (int64_t)get(k._blocked_ticks) + step;
			set(k._blocked_ticks, blocked_ticks);
			if (blocked_ticks >= c.GIVE_WAY_AFTER_TICKS) {
				set(k._blocked_ticks, 0);
				set(k._give_way_left, c.GIVE_WAY_TICKS);
				set(k.give_ways, (int64_t)get(k.give_ways) + 1);
				pace = MIN(pace, c.GIVE_WAY_PACE);
			}
		} else {
			set(k._blocked_ticks, 0);
		}
	} else {
		set(k._blocked_ticks, 0);
		set(k._give_way_left, 0);
	}
	if (!direct && waypoint != goal) {
		Timed t("~guard");
		waypoint = guard_steer(waypoint);
	}
	Vector2 drive_vector;
	const Vector3 forward = -basis_z;
	const double speed = tank->get(k._speed);
	if (radius > 0.0) {
		if (reverse) {
			drive_vector = wheels(c, here, forward, waypoint, arrive, radius, speed, remaining, -1.0);
		} else {
			drive_vector = wheels(c, here, forward, waypoint, arrive, radius, speed, remaining, 1.0);
			if (!direct && drive_vector != Vector2() && pathing_ready()) {
				// kturn_on() (default) and circle_fit_on() (opt-in, off): the planned reverse.
				// TankCommand.new(): the Variant holds the only reference (a RefCounted), so it lives as long as `leg`.
				const Variant leg_ref = c.tank_command->call(k.new_);
				Object *leg = leg_ref;
				bool planned = false;
				const int64_t check_left = (int64_t)get(k._kturn_check) - step;
				if ((double)get(k._kturn_left_m) > 0.0) {
					Vector2 leg_vector;
					Timed t("~kturn_leg");
					if (kturn_leg(delta, leg_vector)) {
						planned = true;
						leg->set(k.throttle, (double)leg_vector.x);
						leg->set(k.turn, (double)leg_vector.y);
					}
				} else if (check_left > 0) {
					// _planned_reverse between checks: `_kturn_check -= ctl._step; if _kturn_check > 0: return false`.
					set(k._kturn_check, check_left);
				} else {
					Timed t("planned_reverse");
					planned = m->call(k._planned_reverse, leg_ref, waypoint, delta);
				}
				if (planned) {
					drive_vector = Vector2((real_t)(double)leg->get(k.throttle), (real_t)(double)leg->get(k.turn));
				}
			} else if ((double)get(k._kturn_left_m) > 0.0) {
				m->call(k._kturn_end, cancelled);
				set(k._kturn_left_m, 0.0);
				Array legs = get(k._kturn_legs);
				legs.clear();
			}
		}
	} else if (reverse) {
		drive_vector = drive_toward(c, here, forward, waypoint, arrive, remaining, true);
	} else {
		drive_vector = drive_toward(c, here, forward, waypoint, arrive, remaining, false);
	}
	double throttle = (double)drive_vector.x * speed_factor * pace;
	cmd->set(k.throttle, throttle);
	cmd->set(k.turn, (double)drive_vector.y);
	const double kturn_left = get(k._kturn_left_m);
	if (kturn_left > 0.0) {
		throttle = drive_vector.x;
		cmd->set(k.throttle, throttle);
		set(k._ease_ticks, 0);
	} else {
		const int64_t ease_ticks = get(k._ease_ticks);
		if (ease_ticks > 0) {
			set(k._ease_ticks, ease_ticks - step);
			const double ease_throttle = get(k._ease_throttle);
			if (throttle > ease_throttle) {
				throttle = ease_throttle;
				cmd->set(k.throttle, throttle);
				sadd(k.kturn_eased, step);
			}
		}
	}
	const bool circling = radius > 0.0 && !reverse && (double)drive_vector.x < 0.0 && kturn_left <= 0.0;
	if (circling) {
		sadd(k.circle_reverse_ticks, step);
		if (!(bool)get(k._circling)) {
			sadd(k.circle_reverses, 1);
		}
	}
	set(k._circling, circling);
	set(k._nose_at_end, false); // _nose_stop: nose_stop_on() is the opt-in arm, off here
	set(k.steer_to, waypoint);
	set(k.pace_now, pace);
	{
		Timed t("~note_wedge");
		note_wedge(pace < 0.999);
	}
	bool stationed = false;
	set(k.stationed_now, false);
	if ((bool)sget(k.station_on) && !direct && !reverse && pace >= 0.99 && waypoint == goal &&
			remaining <= c.STATION_RANGE && (double)((Vector2)get(k._goal_velocity)).length() >= c.STATION_MIN_SPEED) {
		{
			Timed t("keep_station");
			drive_vector = m->call(k._keep_station, cmd, goal, delta, (bool)order.get(k.paced, false) ? speed_factor : 1.0);
		}
		stationed = true;
		set(k.stationed_now, true);
	} else {
		const Variant station = get(k._station);
		if (station.get_type() == Variant::OBJECT && station.get_validated_object() != nullptr) {
			station.get_validated_object()->call(k.reset);
		}
	}
	if ((double)get(k._kturn_left_m) <= 0.0 && (double)cmd->get(k.throttle) < 0.0) {
		if (reverse) {
			set(k._reverse_why, r_order);
		} else if (stationed) {
			set(k._reverse_why, r_station);
		} else if (circling) {
			set(k._reverse_why, r_circle);
		} else {
			set(k._reverse_why, r_other);
		}
	}
	track_progress(goal, drive_vector, remaining);
	{
		Timed t("~update_phase");
		update_phase(goal, drive_vector, direct);
	}
	const bool held_back = pace < c.AVOID_ASK_PACE && order_ticks >= c.AVOID_GRACE_TICKS;
	const int64_t ask_after = (int64_t)(c.ASK_SECONDS * (double)c.TICK_RATE);
	const int64_t stalled_ticks = get(k.stalled_ticks);
	if (stalled_ticks >= ask_after || held_back) {
		int64_t ask_left = (int64_t)get(k._ask_left) - step;
		set(k._ask_left, ask_left);
		if (ask_left <= 0) {
			set(k._ask_left, (int64_t)(c.ASK_EVERY_SECONDS * (double)c.TICK_RATE));
			Timed t("negotiate");
			m->call(k._negotiate, goal, direct, stalled_ticks < ask_after);
		}
	} else {
		set(k._ask_left, 0);
	}
	return true;
}

} // namespace

bool drive_native(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta) {
	if (!config.ready || mover == nullptr || cmd == nullptr) {
		return false;
	}
	const auto t0 = std::chrono::steady_clock::now();
	struct Total {
		std::chrono::steady_clock::time_point t0;
		~Total() {
			clock_().total += std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count();
			clock_().drives++;
		}
	} total{ t0 };
	Drive d(config, mover);
	d.script = mover->get_script();
	d.ctl = mover->get(d.k.ctl);
	if (d.script == nullptr || d.ctl == nullptr) {
		return false;
	}
	d.tank = Object::cast_to<Node3D>((Object *)d.ctl->get(d.k.tank));
	if (d.tank == nullptr) {
		return false;
	}
	const Transform3D xform = d.tank->get_global_transform();
	d.here = xform.origin;
	d.basis_z = xform.basis.get_column(2);
	d.step = d.ctl->get(d.k._step);
	return d.run(cmd, order, delta);
}

Dictionary drive_profile(bool reset) {
	Dictionary out;
	CallbackClock &c = clock_();
	for (const KeyValue<String, double> &e : c.usec) {
		out[e.key] = e.value;
	}
	out["drives"] = c.drives;
	out["total"] = c.total;
	if (reset) {
		c.usec.clear();
		c.drives = 0;
		c.total = 0.0;
	}
	return out;
}

} // namespace godot
