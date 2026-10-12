#include "drive_native.h"

#include "avoidance.h"
#include "exec_view.h"
#include "nav_native.h"

#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <chrono>
#include <cmath>
#include <initializer_list>

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
// The clocks run only while DriveConfig.profile is on (set by drive_configure; the drive's own entry sets it here).
bool profiling_ = false;
struct Timed {
	const char *name;
	std::chrono::steady_clock::time_point t0;
	explicit Timed(const char *p_name) :
			name(p_name) {
		if (profiling_) {
			t0 = std::chrono::steady_clock::now();
		}
	}
	~Timed() {
		if (!profiling_) {
			return;
		}
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
			// Round 26 (manoeuvre M1)
			_manoeuvre{ "_manoeuvre" }, _behind_tick{ "_behind_tick" }, _behind_goal{ "_behind_goal" },
			_behind_plan{ "_behind_plan" },
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
			kturn_aborted{ "kturn_aborted" }, kturn_ticks{ "kturn_ticks" }, _braking{ "_braking" },
			// _around_fire (N4)
			native_fire{ "native_fire" }, direct_calls{ "direct_calls" }, to_safety{ "to_safety" },
			avoid_beaten{ "avoid_beaten" }, for_team{ "for_team" }, _fields{ "_fields" }, _fields_match{ "_fields_match" },
			source{ "source" }, _threat{ "_threat" }, threat_field{ "threat_field" }, cell_size{ "cell_size" },
			cols{ "cols" }, rows{ "rows" }, origin{ "origin" }, density{ "density" }, beaten{ "beaten" },
			along{ "along" }, _fire_since{ "_fire_since" }, _fire_detour_since{ "_fire_detour_since" },
			_fire_detour_until{ "_fire_detour_until" }, _fire_detour_again{ "_fire_detour_again" },
			fire_detours{ "fire_detours" }, fire_no_way_round{ "fire_no_way_round" },
			// _keep_station (round 27, E2): Units.stat, Pid.new, ControlGains.for_loop and the PID's members
			stat{ "stat" }, faction{ "faction" }, for_loop{ "for_loop" }, station_loop{ "station" }, kp{ "kp" },
			ki{ "ki" }, kd{ "kd" }, integral_limit{ "integral_limit" }, output_limit{ "output_limit" },
			integral{ "integral" }, _primed{ "_primed" }, alive{ "alive" }, _registry{ "_registry" },
			yield_to{ "yield_to" }, goal_on_mesh{ "goal_on_mesh" }, end_gap_m{ "end_gap_m" },
			kturn_check_ticks{ "kturn_check_ticks" }, trace_unit{ "trace_unit" }, native_cb{ "native_cb" },
			_hull_within{ "_hull_within" }, _ask_behind{ "_ask_behind" }, unstick_fires{ "unstick_fires" },
			press_escapes{ "press_escapes" }, on{ "on" }, unstick_m{ "unstick" }, type{ "type" };
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

// Round 27 (stage 1 E1c): the drive over a view of the crew's state (exec_view.h): ObjectView = the live GDScript members
// (the drive as it always was), StructView = the C++-owned ExecState. Every member read or write goes through `v`; a call
// into GDScript that may READ this crew's members goes through `gd` (the struct's changes pushed first), a callback that
// may WRITE them through `cb` (pushed first, pulled back after). Under ObjectView both are plain calls.
template <class V>
struct Drive {
	const DriveConfig &c;
	const N &k;
	Object *m; // the Movement
	V v; // its state
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

	Drive(const DriveConfig &p_c, Object *p_m, const V &p_v) :
			c(p_c), k(n_()), m(p_m), v(p_v) {}

	template <typename... Args>
	Variant gd(Object *object, const StringName &method, const Args &...args) {
		v.push_out();
		return object->call(method, args...);
	}
	template <typename... Args>
	Variant cb(const StringName &method, const Args &...args) {
		v.push_out();
		const Variant answer = m->call(method, args...);
		v.pull_in();
		return answer;
	}

	// The mover's script, controller, hull and this tick's pose; false when one is missing.
	bool bind() {
		script = m->get_script();
		ctl = m->get(k.ctl);
		if (script == nullptr || ctl == nullptr) {
			return false;
		}
		tank = Object::cast_to<Node3D>((Object *)ctl->get(k.tank));
		if (tank == nullptr) {
			return false;
		}
		const Transform3D xform = tank->get_global_transform();
		here = xform.origin;
		basis_z = xform.basis.get_column(2);
		step = ctl->get(k._step);
		return true;
	}

	Variant sget(const StringName &name) const { return script->get(name); }
	void sset(const StringName &name, const Variant &v) { script->set(name, v); }
	void sadd(const StringName &name, int64_t by) { script->set(name, (int64_t)script->get(name) + by); }

	// Pathing.enabled and Pathing.is_ready(tank): asked once a drive (the navmesh does not change inside a tick).
	bool pathing_ready() {
		if (!ready_known) {
			ready_known = true;
			ready_value = (bool)c.pathing->get(k.enabled) && (bool)gd(c.pathing, k.is_ready, tank);
		}
		return ready_value;
	}

	double wheel_radius() {
		// Movement.wheel_radius(): its per-unit cache, filled by the GDScript the first time.
		const String unit = tank->get(k.unit_id);
		if (String(v._wheel_radius_unit()) == unit) {
			return v._wheel_radius_value();
		}
		return cb(k.wheel_radius);
	}

	// Movement._chord_on_mesh (chord_memo on): the memo in the mover's members, as the GDScript keeps it.
	bool chord_on_mesh(const Vector3 &from, const Vector3 &to) {
		if (frame < 0) {
			frame = Engine_frames();
		}
		if ((int64_t)v._chord_frame() == frame && (Vector3)v._chord_from() == from && (Vector3)v._chord_to() == to) {
			return v._chord_answer();
		}
		const bool answer = chord_compute(from, to);
		v.set__chord_answer(answer);
		v.set__chord_frame(frame);
		v.set__chord_from(from);
		v.set__chord_to(to);
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
		if ((bool)v._reachable() || path.is_empty()) {
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
		const PackedVector3Array path = v._path();
		const int64_t path_index = v._path_index();
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
			gd(av, k.refresh, tanks_root);
		}
		const double slow = clampd((double)v._remaining() / c.SLOW_RADIUS, 0.35, 1.0);
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
			chosen = gd(av, k.solve, name, position, velocity, preferred, max_speed, radius, delta, cap);
		}
		if ((double)chosen.distance_squared_to(preferred) < 0.04) {
			return;
		}
		const double speed = chosen.length();
		double keep = clampd(speed / MAX(desired, 0.1), 0.0, 1.0);
		const bool starting = (int64_t)v._order_ticks() < c.AVOID_GRACE_TICKS;
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
			return cb(k._chord_slack);
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
	enum Lever { L_CHORD = 0, L_ORCA = 1, L_KTURN_CHECK = 2 };
	int64_t lever(bool chord) { return lever_of(chord ? L_CHORD : L_ORCA); }
	// BrainLevers.chord_samples / orca_neighbours / kturn_check_ticks for this tank: per team for this physics frame while
	// the per-unit split is off (then they do not read the unit), else asked of the GDScript.
	int64_t lever_of(Lever which) {
		const StringName &method = which == L_CHORD ? k.chord_samples : (which == L_ORCA ? k.orca_neighbours : k.kturn_check_ticks);
		const int64_t team = tank->get(k.team);
		if (team < 0 || team > 1 || (bool)c.levers->get(k.split)) {
			return c.levers->call(method, team, String(tank->get_name()));
		}
		const int64_t now = Engine_frames();
		if (c.levers_frame != now) {
			c.levers_frame = now;
			c.chord_samples_known[0] = c.chord_samples_known[1] = c.orca_known[0] = c.orca_known[1] = false;
			c.kturn_check_known[0] = c.kturn_check_known[1] = false;
		}
		bool *known = which == L_CHORD ? c.chord_samples_known : (which == L_ORCA ? c.orca_known : c.kturn_check_known);
		int64_t *value = which == L_CHORD ? c.chord_samples_of : (which == L_ORCA ? c.orca_of : c.kturn_check_of);
		if (!known[team]) {
			known[team] = true;
			value[team] = c.levers->call(method, team, String(tank->get_name()));
		}
		return value[team];
	}

	// ---- Movement._planned_reverse's look, up to its cheap exits (round 27, stage 1 E2) ----
	// Reached where the drive calls _planned_reverse with no leg under way and the check due (_kturn_check - step <= 0):
	//   _kturn_check -= ctl._step  (not > 0 here);  _kturn_check = BrainLevers.kturn_check_ticks(tank.team, name)
	//   forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized(); to := Vector3(waypoint.x - here.x, 0, waypoint.z - here.z)
	//   if to.length() < 0.5: return false
	//   error := forward.signed_angle_to(to, Vector3.UP)          (reverse_log: off in the native drive)
	//   if ManoeuvreCensus.trace_unit == name: print a trace     (-> the GDScript, which prints it)
	//   if circle_plan_on() and _away_here() and absf(speed) < KTURN_CIRCLE_SPEED and _inside_circle(...): _plan_circle
	//   if absf(error) < deg_to_rad(KTURN_MIN_ERROR_DEG): return false
	// circle_plan_on() is away_on() is kturn_on(): true with Movement._off empty; _away_here() is a long hull. True when it
	// answered (false, `_kturn_check` written); false when the live GDScript must run _planned_reverse from the top (nothing
	// has been written).
	bool planned_reverse_cheap(const Vector3 &waypoint) {
		const String name = tank->get_name();
		if (String(c.manoeuvre_census->get(k.trace_unit)) == name) {
			return false;
		}
		const Vector3 forward = Vector3(-basis_z.x, 0, -basis_z.z).normalized();
		const Vector3 to((real_t)((double)waypoint.x - (double)here.x), 0, (real_t)((double)waypoint.z - (double)here.z));
		bool answered = false;
		if ((double)to.length() < 0.5) {
			answered = true;
		} else {
			const double error = forward.signed_angle_to(to, Vector3(0, 1, 0));
			const bool away_here = hull_length(tank->get(k.unit_id)) >= c.KTURN_BRAKE_HULL_M;
			if (away_here && std::fabs((double)tank->get(k._speed)) < c.KTURN_CIRCLE_SPEED && inside_circle(forward, waypoint)) {
				return false; // a circle plan to try: the GDScript
			}
			answered = std::fabs(error) < deg_to_rad(c.KTURN_MIN_ERROR_DEG);
		}
		if (answered) {
			v.set__kturn_check(lever_of(L_KTURN_CHECK));
		}
		return answered;
	}

	// Movement._inside_circle(here, forward, point)
	bool inside_circle(const Vector3 &forward, const Vector3 &point) {
		const double radius = wheel_radius();
		const Vector3 to((real_t)((double)point.x - (double)here.x), 0, (real_t)((double)point.z - (double)here.z));
		const double side = (double)forward.signed_angle_to(to, Vector3(0, 1, 0)) >= 0.0 ? 1.0 : -1.0;
		const Vector3 left(forward.z, 0, -forward.x);
		const Vector3 centre = Vector3(here.x, 0, here.z) + left * (real_t)side * (real_t)radius;
		return (double)centre.distance_to(Vector3(point.x, 0, point.z)) < radius;
	}

	// ---- the k-turn leg (no reverse_log / kturn_log: _kturn_rec stays empty, so _kturn_end only clears the looks) ----
	double braking() {
		const String unit = tank->get(k.unit_id);
		const double *known = c.braking_of.getptr(unit);
		if (known != nullptr) {
			return *known;
		}
		const double value = cb(k._braking);
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
		const double speed = (double)tank->get(k._speed) * (double)(int64_t)v._kturn_gear();
		return speed > 0.0 ? speed * speed / (2.0 * braking()) : 0.0;
	}

	void kturn_end() {
		Array looks = v._kturn_looks();
		looks.clear();
	}

	void kturn_start_leg(const Vector2 &leg) {
		v.set__kturn_gear((int64_t)leg.x);
		v.set__kturn_left_m((double)leg.y);
		v.set__kturn_from(here);
		double timeout = (double)leg.y * c.KTURN_SECONDS_PER_M + 1.0;
		const double speed = tank->get(k._speed);
		const bool rolling = !kturn_brake_on() || speed * (double)leg.x > -c.KTURN_ROLLING_SPEED;
		v.set__kturn_rolling(rolling);
		if (!rolling) {
			timeout += std::fabs(speed) / braking();
		}
		v.set__kturn_timeout(timeout);
		v.set__kturn_leg_no((int64_t)v._kturn_leg_no() + 1);
		v.set__kturn_plan_pose(Array());
	}

	// _planned_reverse while a leg is being driven (_kturn_left_m > 0): true and the leg's throttle/turn, or false
	// (the leg ended; the caller drives on as a normal tick).
	bool kturn_leg(double delta, Vector2 &out) {
		const int64_t gear = v._kturn_gear();
		if (!(bool)v._kturn_rolling()) {
			if ((double)tank->get(k._speed) * (double)gear > c.KTURN_ROLLING_SPEED) {
				v.set__kturn_rolling(true);
			}
			v.set__kturn_from(here);
		}
		const double backed = flat_distance(here, v._kturn_from());
		const double left = v._kturn_left_m();
		const bool reached = backed + kturn_stopping() >= left;
		const double timeout = (double)v._kturn_timeout() - delta;
		v.set__kturn_timeout(timeout);
		const Vector2 nose(-basis_z.x, -basis_z.z);
		Object *wall = v.contact().get_validated_object();
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
		Array legs = v._kturn_legs();
		if (reached && !legs.is_empty()) {
			kturn_end();
			const Vector2 next = legs.pop_front();
			kturn_start_leg(next);
		} else if (reached || timeout <= 0.0 || lead_hit) {
			kturn_end();
			v.set__kturn_check(0);
			if (!reached) {
				sadd(k.kturn_aborted, 1);
				v.set__kturn_check(c.KTURN_RETRY_TICKS);
			}
			v.set__kturn_left_m(0.0);
			legs.clear();
			v.set__repath_left(0.0);
			return false;
		}
		const int64_t gear_now = v._kturn_gear();
		out = Vector2((real_t)(c.KTURN_THROTTLE * (double)gear_now), (real_t)(double)v._kturn_turn());
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
		if (v._fire_detour().get_type() != Variant::NIL) {
			return false;
		}
		const int64_t tick = game_match->get(k.tick);
		const int64_t stride = ctl->get(k._stride);
		if (stride == 1) {
			const int64_t offset = ctl->get(k.think_offset);
			return (tick + offset) % c.FIRE_CHECK_TICKS != 0;
		}
		if (stride > 1) {
			return tick - (int64_t)v._fire_checked_tick() < c.FIRE_CHECK_TICKS;
		}
		return false;
	}

	// ---- Movement._around_fire (N4), line by line, with ThreatField's reads ----
	// One team's incoming-fire grid (ThreatField's members, read in place) and the two questions L2 asks of it.
	struct Field {
		double cell_size = 6.0, march = 0.5;
		int64_t cols = 0, rows = 0;
		Vector3 origin;
		PackedFloat32Array density;
		mutable LocalVector<float> samples;

		// ThreatField.index_of
		int64_t index_of(const Vector3 &point) const {
			const int64_t col = (int64_t)std::floor(((double)point.x - (double)origin.x) / cell_size);
			const int64_t row = (int64_t)std::floor(((double)point.z - (double)origin.z) / cell_size);
			if (col < 0 || col >= cols || row < 0 || row >= rows) {
				return -1;
			}
			return row * cols + col;
		}
		// ThreatField._samples_along
		void samples_along(const Vector3 &from, const Vector3 &to) const {
			samples.clear();
			const Vector2 span((real_t)((double)to.x - (double)from.x), (real_t)((double)to.z - (double)from.z));
			const double length = span.length();
			if (length < 0.01) {
				const int64_t index = index_of(from);
				samples.push_back(index >= 0 ? density[index] : 0.0f);
				return;
			}
			const double step = cell_size * march;
			const int64_t steps = (int64_t)(length / step) + 1;
			int64_t last = -1;
			for (int64_t i = 0; i < steps + 1; i++) {
				const double travelled = MIN(length, (double)i * step);
				const Vector3 spot((real_t)((double)from.x + (double)span.x / length * travelled), 0,
						(real_t)((double)from.z + (double)span.y / length * travelled));
				const int64_t index = index_of(spot);
				if (index != last) {
					samples.push_back(index >= 0 ? density[index] : 0.0f);
				}
				last = index;
			}
		}
		// ThreatField.peak_along
		double peak_along(const Vector3 &from, const Vector3 &to) const {
			samples_along(from, to);
			double worst = 0.0;
			for (uint32_t i = 0; i < samples.size(); i++) {
				worst = MAX(worst, (double)samples[i]);
			}
			return worst;
		}
		// ThreatField.mean_along
		double mean_along(const Vector3 &from, const Vector3 &to) const {
			samples_along(from, to);
			if (samples.is_empty()) {
				return 0.0;
			}
			double total = 0.0;
			for (uint32_t i = 0; i < samples.size(); i++) {
				total += (double)samples[i];
			}
			return total / (double)samples.size();
		}
	};

	static bool script_is(Object *object, Object *script) {
		if (object == nullptr || script == nullptr) {
			return false;
		}
		Script *s = Object::cast_to<Script>((Object *)object->get_script());
		while (s != nullptr) {
			if (s == script) {
				return true;
			}
			const Ref<Script> base = s->get_base_script();
			s = base.ptr();
		}
		return false;
	}

	// SuppressionFeed.beaten / along for one team: the match's own field read here when SuppressionFeed would call the
	// match directly (BrainSwitches.direct_calls and `fields is Match`), else SuppressionFeed's own answer.
	struct FireReader {
		const DriveConfig &c;
		const N &k;
		Object *fields;
		int64_t team;
		bool direct = false;
		Field field;

		FireReader(const DriveConfig &p_c, const N &p_k, Object *p_fields, int64_t p_team) :
				c(p_c), k(p_k), fields(p_fields), team(p_team) {
			if (!(bool)c.switches->get(k.direct_calls) || !script_is(fields, c.match_script)) {
				return;
			}
			const Array threat = fields->get(k._threat);
			const Variant field_v = threat.is_empty() ? fields->call(k.threat_field, team) : threat[team];
			Object *f = field_v.get_validated_object();
			if (f == nullptr) {
				return;
			}
			field.cell_size = f->get(k.cell_size);
			field.cols = f->get(k.cols);
			field.rows = f->get(k.rows);
			field.origin = f->get(k.origin);
			field.density = f->get(k.density);
			field.march = c.MARCH_FRACTION;
			direct = true;
		}
		bool beaten(const Vector3 &from, const Vector3 &to) const {
			if (direct) {
				return field.peak_along(from, to) >= c.BEATEN_ZONE_DENSITY;
			}
			return c.suppression_feed->call(k.beaten, fields, team, from, to);
		}
		double along(const Vector3 &from, const Vector3 &to) const {
			if (direct) {
				return MAX(field.mean_along(from, to), 0.0);
			}
			return c.suppression_feed->call(k.along, fields, team, from, to);
		}
	};

	void oc_add(const StringName &name, int64_t by) {
		c.order_controller->set(name, (int64_t)c.order_controller->get(name) + by);
	}

	// The brain's memo of the suppression feed (OrderController._suppression_fields).
	Object *suppression_fields(Object *game_match) {
		const int64_t id = (int64_t)game_match->get_instance_id();
		if ((int64_t)ctl->get(k._fields_match) != id) {
			ctl->set(k._fields_match, id);
			ctl->set(k._fields, c.suppression_feed->call(k.source, game_match));
		}
		const Variant fields = ctl->get(k._fields);
		return fields.get_type() == Variant::OBJECT ? fields.get_validated_object() : nullptr;
	}

	// `ctl as TankBrain`: only a brain has a `game_match` (fire_check_skips reads it the same way).
	Vector3 around_fire(const Vector3 &waypoint, const Vector3 &goal, const Dictionary &order) {
		const Variant game_match_v = ctl->get(k.game_match);
		Object *game_match = game_match_v.get_type() == Variant::OBJECT ? game_match_v.get_validated_object() : nullptr;
		if (game_match == nullptr) {
			return waypoint;
		}
		const int64_t team = tank->get(k.team);
		const Dictionary variant = c.brain_variants->call(k.for_team, team);
		if (!(bool)variant.get(k.avoid_beaten, true)) {
			return waypoint;
		}
		if ((bool)order.get(k.to_safety, false)) {
			return waypoint;
		}
		Object *fields = suppression_fields(game_match);
		if (fields == nullptr) {
			return waypoint;
		}
		const Vector3 to((real_t)((double)waypoint.x - (double)here.x), 0, (real_t)((double)waypoint.z - (double)here.z));
		const double distance = to.length();
		if (distance < 1.0) {
			return waypoint;
		}
		const Vector3 direction = to / (real_t)distance;
		const double reach = MIN(c.FIRE_LOOKAHEAD, MAX(flat_distance(here, goal), 1.0));
		const int64_t tick = game_match->get(k.tick);
		const int64_t stride = ctl->get(k._stride);
		const Variant detour = v._fire_detour();
		if (detour.get_type() == Variant::NIL) {
			if (stride == 1 && (tick + (int64_t)ctl->get(k.think_offset)) % c.FIRE_CHECK_TICKS != 0) {
				return waypoint;
			}
			if (stride > 1 && tick - (int64_t)v._fire_checked_tick() < c.FIRE_CHECK_TICKS) {
				return waypoint;
			}
			v.set__fire_checked_tick(tick);
		}
		const FireReader fire(c, k, fields, team);
		const Vector3 ahead = here + direction * (real_t)reach;
		const bool ahead_beaten = fire.beaten(here, ahead);
		const double straight = fire.along(here, ahead);
		const bool still_swept = straight >= c.BEATEN_ZONE_DENSITY * c.FIRE_KEEP_SHARE;
		if (detour.get_type() != Variant::NIL) {
			const Vector3 leg = detour;
			const int64_t fire_since = v._fire_since();
			if (!still_swept && tick - (int64_t)v._fire_detour_since() >= c.FIRE_LEG_MIN_TICKS) {
				v.set__fire_detour(Variant());
				v.set__fire_since(-1);
			} else if (fire_since >= 0 && tick - fire_since >= c.FIRE_AVOID_MAX) {
				v.set__fire_detour(Variant());
				v.set__fire_since(-1);
				v.set__fire_detour_again(tick + c.FIRE_DETOUR_COOLDOWN);
			} else if (tick >= (int64_t)v._fire_detour_until() || flat_distance(here, leg) <= c.FIRE_DETOUR_REACHED) {
				v.set__fire_detour(Variant());
			} else {
				oc_add(k.fire_detours, step);
				return leg;
			}
		}
		if (!still_swept) {
			v.set__fire_since(-1);
		}
		if (!ahead_beaten || tick < (int64_t)v._fire_detour_again()) {
			return waypoint;
		}
		const Vector3 across(-direction.z, 0, direction.x);
		const double limit = c.DRIVABLE_LIMIT - 4.0;
		bool found = false;
		Vector3 best;
		double best_threat = straight * c.FIRE_DETOUR_MARGIN;
		for (double side_step : c.FIRE_DETOUR_STEPS) {
			for (double side : { 1.0, -1.0 }) {
				Vector3 beside = here + across * (real_t)(side * side_step);
				beside.x = (real_t)clampd(beside.x, -limit, limit);
				beside.z = (real_t)clampd(beside.z, -limit, limit);
				const double threat = MAX(fire.along(here, beside), fire.along(beside, beside + direction * (real_t)reach));
				if (threat < best_threat) {
					best_threat = threat;
					best = beside;
					found = true;
				}
			}
		}
		if (found) {
			v.set__fire_detour(best);
			v.set__fire_detour_until(tick + c.FIRE_DETOUR_TICKS);
			v.set__fire_detour_since(tick);
			if ((int64_t)v._fire_since() < 0) {
				v.set__fire_since(tick);
			}
			oc_add(k.fire_detours, step);
			return best;
		}
		oc_add(k.fire_no_way_round, 1);
		v.set__fire_since(-1);
		v.set__fire_detour_again(tick + c.FIRE_DETOUR_COOLDOWN);
		return waypoint;
	}

	// ---- Movement._keep_station (X6), round 27 (stage 1 E2): line by line, with Pid.step_with_rate (game/ai/pid.gd) on the
	// mover's station PID, whose members are read and written in place (it stays a GDScript object: the station PID is
	// made by Pid.new(ControlGains.for_loop("station", faction)) when there is none or the faction changed) ----
	//   var faction := String(Units.stat(tank.unit_id, "faction", ""))
	//   if _station == null or faction != _station_faction: _station = Pid.new(ControlGains.for_loop("station", faction)); ...
	//   forward := Vector2(-basis.z.x, -basis.z.z).normalized(); gap := Vector2(goal.x - here.x, goal.z - here.z)
	//   along := gap.dot(forward); feed_forward := _goal_velocity.dot(forward); my_speed := tank.speed()
	//   correction := _station.step_with_rate(along, my_speed - feed_forward, delta); wanted := feed_forward + correction
	//   ahead := Vector3(goal.x + _goal_velocity.x * LEAD, 0, goal.z + _goal_velocity.y * LEAD)
	//   drive_vector := Steering.drive_toward(here, -basis.z, ahead, 0.3); cmd.turn = drive_vector.y
	//   cmd.throttle = cap if cap < 0.999 else clampf(wanted / maxf(tank.max_forward_speed, 0.1), -0.5, 1.0)
	//   return Vector2(cmd.throttle, cmd.turn)
	Vector2 keep_station(Object *cmd, const Vector3 &goal, double delta, double cap) {
		const String unit = tank->get(k.unit_id);
		const String *known = c.faction_of.getptr(unit);
		String faction;
		if (known != nullptr) {
			faction = *known;
		} else {
			faction = String(c.units->call(k.stat, unit, k.faction, String()));
			c.faction_of.insert(unit, faction);
		}
		Variant station = v._station();
		if (station.get_type() != Variant::OBJECT || station.get_validated_object() == nullptr || faction != v._station_faction()) {
			station = c.pid_script->call(k.new_, c.control_gains->call(k.for_loop, String(k.station_loop), faction));
			v.set__station(station);
			v.set__station_faction(faction);
		}
		Object *pid = station.get_validated_object();
		const Vector2 forward = Vector2(-basis_z.x, -basis_z.z).normalized();
		const Vector2 gap((real_t)((double)goal.x - (double)here.x), (real_t)((double)goal.z - (double)here.z));
		const double along = gap.dot(forward);
		const Vector2 goal_velocity = v._goal_velocity();
		const double feed_forward = goal_velocity.dot(forward);
		const double my_speed = tank->get(k._speed);
		const double correction = pid_step_with_rate(pid, along, my_speed - feed_forward, delta);
		const double wanted = feed_forward + correction;
		const Vector3 ahead((real_t)((double)goal.x + (double)goal_velocity.x * c.STATION_LEAD_SECONDS), 0,
				(real_t)((double)goal.z + (double)goal_velocity.y * c.STATION_LEAD_SECONDS));
		const Vector2 drive_vector = drive_toward(c, here, -basis_z, ahead, 0.3, -1.0, false);
		const double turn = drive_vector.y;
		cmd->set(k.turn, turn);
		const double max_speed = tank->get(k.max_forward_speed);
		const double throttle = cap < 0.999 ? cap : clampd(wanted / MAX(max_speed, 0.1), -0.5, 1.0);
		cmd->set(k.throttle, throttle);
		return Vector2((real_t)throttle, (real_t)turn);
	}

	// Pid.step_with_rate(error, measurement_rate, dt) on a PID object's members (game/ai/pid.gd):
	//   unclamped := kp * error + ki * integral - kd * measurement_rate
	//   saturated_same_way := (unclamped >= output_limit and error > 0.0) or (unclamped <= -output_limit and error < 0.0)
	//   if not saturated_same_way: integral = clampf(integral + error * dt, -integral_limit, integral_limit)
	//   return clampf(kp * error + ki * integral - kd * measurement_rate, -output_limit, output_limit)
	double pid_step_with_rate(Object *pid, double error, double measurement_rate, double dt) {
		const double kp = pid->get(k.kp), ki = pid->get(k.ki), kd = pid->get(k.kd);
		const double integral_limit = pid->get(k.integral_limit), output_limit = pid->get(k.output_limit);
		double integral = pid->get(k.integral);
		const double unclamped = kp * error + ki * integral - kd * measurement_rate;
		const bool saturated_same_way = (unclamped >= output_limit && error > 0.0) || (unclamped <= -output_limit && error < 0.0);
		if (!saturated_same_way) {
			integral = clampd(integral + error * dt, -integral_limit, integral_limit);
			pid->set(k.integral, integral);
		}
		return clampd(kp * error + ki * integral - kd * measurement_rate, -output_limit, output_limit);
	}

	// Movement.hull_box(unit)[2], memoized by unit (a pure function of the roster).
	double hull_length(const String &unit) {
		const double *known = c.hull_length_of.getptr(unit);
		if (known != nullptr) {
			return *known;
		}
		const Array size = script->call(k.hull_box, unit);
		const double length = size[2];
		c.hull_length_of.insert(unit, length);
		return length;
	}

	// ---- Movement._blocker (round 27, stage 1 E2), with `blockreach` not switched off (the native drive's config) ----
	//   toward := (_path[_path_index] if _path_index < _path.size() and not direct else goal) - here; toward.y = 0.0
	//   if toward.length_squared() < 0.01: toward = -tank.global_basis.z
	//   toward = toward.normalized(); my_half := float(hull_box(tank.unit_id)[2]) * 0.5
	//   for other in ctl.tanks_root.get_children(): (a living Tank, not me)
	//     offset := hull.global_position - here; offset.y = 0.0; distance := offset.length()
	//     reach := maxf(BLOCKER_REACH, my_half + float(hull_box(hull.unit_id)[2]) * 0.5 + BLOCKER_GAP_M)
	//     if distance >= reach or distance >= best_distance or distance < 0.01: continue
	//     if offset.dot(toward) / distance < BLOCKER_AHEAD_COS: continue
	//     best = String(hull.name); best_distance = distance
	//   best, else "no_path" (an unfinished route), else "terrain"
	// The reach is only worked out for a hull at least BLOCKER_REACH away: nearer than that it cannot reach past it.
	String blocker(const Vector3 &goal, bool direct) {
		static const String no_path("no_path"), terrain("terrain");
		const PackedVector3Array path = v._path();
		const int64_t path_index = v._path_index();
		Vector3 toward = (path_index < path.size() && !direct ? path[path_index] : goal) - here;
		toward.y = 0;
		if ((double)toward.length_squared() < 0.01) {
			toward = -basis_z;
		}
		toward = toward.normalized();
		String best;
		double best_distance = INFINITY;
		const double my_half = hull_length(tank->get(k.unit_id)) * 0.5;
		Object *root = ctl->get(k.tanks_root).get_validated_object();
		Node *tanks_root = Object::cast_to<Node>(root);
		if (tanks_root != nullptr) {
			const int count = tanks_root->get_child_count();
			for (int i = 0; i < count; i++) {
				Node3D *hull = Object::cast_to<Node3D>(tanks_root->get_child(i));
				if (hull == nullptr || hull == tank) {
					continue;
				}
				const Variant alive = hull->get(k.alive);
				if (alive.get_type() != Variant::BOOL || !(bool)alive) {
					continue; // not a Tank (no `alive`), or a dead one
				}
				Vector3 offset = hull->get_global_position() - here;
				offset.y = 0;
				const double distance = offset.length();
				if (distance >= best_distance || distance < 0.01) {
					continue;
				}
				if (distance >= c.BLOCKER_REACH) {
					const double reach = MAX(c.BLOCKER_REACH, my_half + hull_length(hull->get(k.unit_id)) * 0.5 + c.BLOCKER_GAP_M);
					if (distance >= reach) {
						continue;
					}
				}
				if ((double)offset.dot(toward) / distance < c.BLOCKER_AHEAD_COS) {
					continue;
				}
				best = hull->get_name();
				best_distance = distance;
			}
		}
		if (!best.is_empty()) {
			return best;
		}
		if (!direct && !path.is_empty() && flat_distance(path[path.size() - 1], goal) > c.NO_PATH_MARGIN) {
			return no_path;
		}
		return terrain;
	}

	// Movement.of(unit): the registry's mover for this hull, if it is still that hull's.
	Dictionary registry;
	bool registry_known = false;
	Object *mover_of(Node *unit) {
		if (unit == nullptr) {
			return nullptr;
		}
		if (!registry_known) {
			registry = script->get(k._registry);
			registry_known = true;
		}
		Object *mover = registry.get((int64_t)unit->get_instance_id(), Variant()).get_validated_object();
		if (mover == nullptr) {
			return nullptr;
		}
		Object *its_ctl = mover->get(k.ctl).get_validated_object();
		if (its_ctl == nullptr || its_ctl->get(k.tank).get_validated_object() != unit) {
			return nullptr;
		}
		return mover;
	}

	// ---- Movement._negotiate's early returns (round 27, stage 1 E2) ----
	//   if _off.has("yield"): return                       (never, in the native drive's configuration)
	//   name := _hull_ahead(goal, direct)                   (_blocker, with "no_path" and "terrain" read as "")
	//   if name == "": return
	//   other := tanks_root.get_node_or_null(name) as Tank; if other == null or other.team != tank.team: return
	//   mover := Movement.of(other); if mover == null or mover.yield_to != "": return
	//   if still_only and mover.is_under_way(): return
	// Past them (a friend's mover ahead that could be asked), the live GDScript runs _negotiate from the top: nothing
	// above writes, so it reads the same state and takes the same early-outs, then decides who gives way.
	void negotiate(const Vector3 &goal, bool direct, bool still_only) {
		static const String no_path("no_path"), terrain("terrain"), arrived("arrived");
		const String name = blocker(goal, direct);
		if (name.is_empty() || name == no_path || name == terrain) {
			return;
		}
		Node *root = Object::cast_to<Node>(ctl->get(k.tanks_root).get_validated_object());
		Node *other = root != nullptr ? root->get_node_or_null(NodePath(name)) : nullptr;
		if (other == nullptr || other->get(k.alive).get_type() != Variant::BOOL ||
				(int64_t)other->get(k.team) != (int64_t)tank->get(k.team)) {
			return;
		}
		Object *mover = mover_of(other);
		if (mover == nullptr || !String(mover->get(k.yield_to)).is_empty()) {
			return;
		}
		if (still_only && String(mover->get(k.phase)) != arrived) {
			return;
		}
		cb(k._negotiate, goal, direct, still_only);
	}

	// ---- Pathing.query(tank, from, to) (round 27, stage 1 E2), line by line; `is_ready` is the drive's own answer (asked
	// once a drive: Pathing.enabled and is_ready(tank), the same expression query opens with), the path is the engine's
	// own query, the closest point Pathing.closest_point's (native_nav: N2a's index). The result is the same Dictionary,
	// keys in the same order: the mover keeps it as `_route_reading`. ----
	Dictionary path_query(const Vector3 &from, const Vector3 &to) {
		Dictionary result;
		result[k.points] = PackedVector3Array();
		result[k.ready] = false;
		result[k.reachable] = false;
		result[k.goal_on_mesh] = false;
		result[k.end_gap_m] = INFINITY;
		result[k.goal_gap_m] = INFINITY;
		if (!pathing_ready()) {
			return result;
		}
		const RID map = tank->get_world_3d()->get_navigation_map();
		const PackedVector3Array points = NavigationServer3D::get_singleton()->map_get_path(map, from, to, true);
		const Vector3 nearest = closest_point(map, to, k.query);
		const double goal_gap = Vector2((real_t)((double)to.x - (double)nearest.x), (real_t)((double)to.z - (double)nearest.z)).length();
		double end_gap = INFINITY;
		if (points.size() > 0) {
			const Vector3 end = points[points.size() - 1];
			end_gap = Vector2((real_t)((double)end.x - (double)nearest.x), (real_t)((double)end.z - (double)nearest.z)).length();
		}
		result[k.points] = points;
		result[k.ready] = true;
		result[k.goal_gap_m] = goal_gap;
		result[k.end_gap_m] = end_gap;
		result[k.reachable] = end_gap <= c.MESH_EPSILON;
		result[k.goal_on_mesh] = goal_gap <= c.MESH_EPSILON;
		return result;
	}

	// ---- Movement.unstick / _unstick / _pressing_escape (round 27, stage 1 E4), line by line; `_off` empty (the native
	// drive's configuration): press_on() true, `unstick` not switched off. The rare stuck event's two neighbour questions
	// (_hull_within, _ask_behind: Avoidance's table) are the live GDScript. ----
	void unstick(Object *cmd, const Dictionary &order, double delta) {
		const double left = v._unstick_left();
		if (left > 0.0) {
			const double now_left = left - delta;
			v.set__unstick_left(now_left);
			const double gear = v._escape_gear();
			if (gear != 0.0) {
				cmd->set(k.throttle, gear * c.PRESS_ESCAPE_THROTTLE);
				cmd->set(k.turn, v._escape_turn());
				if (now_left <= 0.0 || flat_distance(here, v._press_from()) >= c.PRESS_BACKOFF_M) {
					v.set__escape_gear(0.0);
					v.set__unstick_left(0.0);
				}
				return;
			}
			if (v._unstick_pivot()) {
				cmd->set(k.throttle, 0.0);
			} else {
				cmd->set(k.throttle, (bool)order.get(k.reverse, false) ? 1.0 : -1.0);
			}
			cmd->set(k.turn, 1.0);
			return;
		}
		static const String move_to("move_to");
		if (String(order.get(k.type, String())) == move_to && !(bool)order.get(k.direct, false) && pressing_escape(cmd, delta)) {
			return;
		}
		const double throttle = cmd->get(k.throttle);
		const Vector3 velocity = tank->get(k.estimated_velocity);
		if (std::fabs(throttle) > 0.5 && (double)velocity.length() < c.STUCK_SPEED) {
			const double stuck = v._stuck_time() + delta;
			v.set__stuck_time(stuck);
			if (stuck >= c.STUCK_SECONDS) {
				v.set__stuck_time(0.0);
				const double backing = (bool)order.get(k.reverse, false) ? 1.0 : -1.0;
				const Vector2 direction = Vector2(-basis_z.x, -basis_z.z) * (real_t)backing;
				const bool pivot = cb(k._hull_within, direction, c.UNSTICK_CLEARANCE);
				v.set__unstick_pivot(pivot);
				if (!pivot || wheel_radius() <= 0.0) {
					v.set__unstick_left(c.UNSTICK_SECONDS);
					sadd(k.unstick_fires, 1);
				} else {
					cb(k._ask_behind, direction);
				}
			}
		} else {
			v.set__stuck_time(0.0);
		}
	}

	bool pressing_escape(Object *cmd, double delta) {
		if (!v.g_engaged_target().is_empty()) {
			v.set__press_time(0.0);
			return false;
		}
		const double throttle = cmd->get(k.throttle), turn = cmd->get(k.turn);
		const bool asked = std::fabs(throttle) >= c.THROTTLE_MIN || std::fabs(turn) >= 0.05;
		Object *wall = v.contact().get_validated_object();
		if (!(wall != nullptr && (bool)wall->get(k.touching) && asked)) {
			v.set__press_time(0.0);
			return false;
		}
		if (v._press_time() == 0.0) {
			v.set__press_from(here);
		}
		const double press_time = v._press_time() + delta;
		v.set__press_time(press_time);
		if (press_time < c.PRESS_SECONDS) {
			return false;
		}
		const double moved = flat_distance(here, v._press_from());
		v.set__press_time(0.0);
		if (moved >= c.PRESS_PROGRESS_M) {
			return false;
		}
		const Vector2 forward = Vector2(-basis_z.x, -basis_z.z).normalized();
		const Vector3 normal = wall->get(k.normal), point = wall->get(k.point);
		const Vector2 away(normal.x, normal.z);
		const Vector2 r((real_t)((double)point.x - (double)here.x), (real_t)((double)point.z - (double)here.z));
		const double along = forward.dot(away);
		const double gear = std::fabs(along) > 0.2 ? (along > 0.0 ? 1.0 : (along < 0.0 ? -1.0 : 0.0)) :
													  ((double)forward.dot(r) > 0.0 ? -1.0 : 1.0);
		// WallContact.swing_of(centre, at, 1.0): Vector2(-r.y, r.x) * signf(1.0)
		const Vector2 swing = Vector2(-r.y, r.x) * (real_t)1.0;
		const double escape_turn = (double)swing.dot(away) > 0.0 ? 1.0 : -1.0;
		v.set__escape_gear(gear);
		v.set__escape_turn(escape_turn);
		v.set__unstick_left(c.PRESS_ESCAPE_MAX_S);
		v.set__press_from(here);
		v.set__repath_left(0.0);
		sadd(k.press_escapes, 1);
		cmd->set(k.throttle, gear * c.PRESS_ESCAPE_THROTTLE);
		cmd->set(k.turn, escape_turn);
		return true;
	}

	// ---- Movement._track_goal ----
	void track_goal(const Vector3 &goal) {
		const int64_t ticks = (int64_t)v._ticks() + step;
		v.set__ticks(ticks);
		const bool reissued = v._reissued();
		v.set__reissued(false);
		const Vector3 seen = v._goal_seen();
		if (seen == V3_INF) {
			v.set__goal_seen(goal);
			v.set__goal_changed_at(ticks);
			v.set__goal_velocity(Vector2());
			return;
		}
		const Vector2 moved((real_t)((double)goal.x - (double)seen.x), (real_t)((double)goal.z - (double)seen.z));
		const double seconds = (double)(ticks - (int64_t)v._goal_changed_at()) / (double)c.TICK_RATE;
		if ((double)moved.length_squared() > 0.0001) {
			const Vector2 velocity = moved / (real_t)MAX(seconds, 1.0 / (double)c.TICK_RATE);
			const double max_speed = tank->get(k.max_forward_speed);
			v.set__goal_velocity((double)velocity.length() > 2.0 * max_speed ? Vector2() : velocity);
			v.set__goal_seen(goal);
			v.set__goal_changed_at(ticks);
		} else if (seconds > c.STATION_STALE_SECONDS || (reissued && seconds > c.STATION_STOPPED_SECONDS)) {
			v.set__goal_velocity(Vector2());
		}
	}

	// ---- Movement._next_waypoint (a1, repath, notready, carrot, chord all at their defaults) ----
	Vector3 next_waypoint(const Vector3 &goal, double delta) {
		double repath_left = (double)v._repath_left() - delta;
		v.set__repath_left(repath_left);
		PackedVector3Array path = v._path();
		int64_t path_index = v._path_index();
		const bool is_off_path = path.size() >= 2 && off_path(path, path_index, here) > c.OFF_PATH_REPATH;
		const int64_t stalled_ticks = v.stalled_ticks();
		const int64_t blocked_every = (int64_t)(c.BLOCKED_SECONDS * (double)c.TICK_RATE);
		const bool stalled = stalled_ticks > 0 && stalled_ticks % blocked_every == 0;
		v.set_last_replan(k.empty);
		const bool cadence_due = repath_left <= 0.0;
		if (cadence_due) {
			sadd(k.a1_cadence_due, 1);
			repath_left = c.REPATH_SECONDS;
			v.set__repath_left(repath_left);
		}
		const bool drifted = cadence_due;
		const double goal_shift = flat_distance(goal, v._path_goal());
		const bool sliding = (double)((Vector2)v._goal_velocity()).length() >= c.STATION_MIN_SPEED;
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
			v.set_last_replan(key);
			v.set__repath_left(c.REPATH_SECONDS);
			v.set__path_goal(goal);
			Dictionary route;
			{
				Timed t("query");
				route = cb_on && c.query_ready ? path_query(here, goal) : (Dictionary)gd(c.pathing, k.query, tank, here, goal);
			}
			// Movement._inflate_corners(points): `if not inflate_on() ...: return path` -- inflate_on() is
			// switched_off("inflate"), and the native drive runs only with Movement._off empty (NativeDrive.usable), so the
			// route's points come back as they are (round 27, E2: no call into GDScript).
			if (cb_on) {
				path = route[k.points];
			} else {
				Timed t("inflate_corners");
				path = cb(k._inflate_corners, route[k.points]);
			}
			v.set__path(path);
			const bool reachable = !(bool)route[k.ready] || path.size() < 2 ||
					((bool)route[k.reachable] && (double)route[k.goal_gap_m] <= c.NO_PATH_MARGIN);
			v.set__reachable(reachable);
			v.set__route_reading(route);
			path_index = path.size() >= 2 ? 1 : path.size();
			v.set__path_index(path_index);
			if (!(bool)route[k.ready]) {
				v.set__repath_left(0.0);
				sadd(k.route_not_ready, 1);
			}
		}
		if (path.size() < 2) {
			v.set__path_index((int64_t)path.size());
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
		v.set__path_index(path_index);
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
		const PackedVector3Array path = v._path();
		int64_t first = v._path_index();
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
		Array window = v._deflect_window();
		Array trail = v._wedge_trail();
		window.append(deflected);
		trail.append(here);
		if (window.size() > c.WEDGED_WINDOW) {
			window.remove_at(0);
			trail.remove_at(0);
		}
		if (window.size() < c.WEDGED_WINDOW) {
			v.set_wedged(false);
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
		const bool was = v.wedged();
		v.set_wedge_moved_m(moved);
		v.set_wedge_hull_m(hull);
		const bool wedged = (double)hits / (double)c.WEDGED_WINDOW > c.WEDGED_SHARE && moved < hull;
		v.set_wedged(wedged);
		if (wedged && !was) {
			sadd(k.wedged_units, 1);
		}
	}

	// ---- Movement._track_progress ----
	void track_progress(const Vector3 &goal, const Vector2 &drive_vector, double remaining) {
		if (flat_distance(goal, v._progress_goal()) > 2.0 || drive_vector == Vector2()) {
			v.set__progress_goal(goal);
			v.set__progress_best(remaining);
			v.set_stalled_ticks(0);
		} else if (remaining < (double)v._progress_best() - 0.5) {
			v.set__progress_best(remaining);
			v.set_stalled_ticks(0);
		} else {
			v.set_stalled_ticks((int64_t)v.stalled_ticks() + step);
		}
	}

	// ---- Movement._update_phase ----
	void update_phase(const Vector3 &goal, const Vector2 &drive_vector, bool direct) {
		static const String arrived("arrived"), blocked("blocked"), no_path("no_path"), pathing("pathing"),
				driving("driving"), none("");
		const bool reachable = v._reachable();
		if (drive_vector == Vector2() && (flat_distance(here, goal) <= (double)v._arrive() + 0.5 ||
												 ((bool)v._nose_at_end() && reachable))) {
			v.set_phase(arrived);
			v.set_blocked_by(none);
			return;
		}
		const PackedVector3Array path = v._path();
		if (!reachable && !direct && !path.is_empty() && flat_distance(here, path[path.size() - 1]) <= c.UNREACHABLE_AT_END) {
			if ((bool)cb(k._repair, goal)) {
				return;
			}
			v.set_phase(blocked);
			v.set_blocked_by(no_path);
			return;
		}
		if ((int64_t)v.stalled_ticks() >= (int64_t)(c.BLOCKED_SECONDS * (double)c.TICK_RATE)) {
			int64_t left = (int64_t)v._blocker_left() - step;
			v.set__blocker_left(left);
			if (String(v.phase()) != blocked || left <= 0) {
				v.set__blocker_left(c.TICK_RATE / 2);
				v.set_blocked_by(cb_on && c.blocker_ready ? blocker(goal, direct) : String(cb(k._blocker, goal, direct)));
			}
			v.set_phase(blocked);
			return;
		}
		v.set_blocked_by(none);
		if (!direct && (bool)c.pathing->get(k.enabled) && path.is_empty() && !(bool)gd(c.pathing, k.is_ready, tank)) {
			v.set_phase(pathing);
		} else {
			v.set_phase(driving);
		}
	}

	// Round 27 (E2): BrainSwitches.native_cb, read once a drive (the A/B flips it between ticks): the ported callbacks
	// run natively only while it is on; off, each is called back as before.
	bool cb_on = false;
	bool run(Object *cmd, const Dictionary &order, double delta);
	Dictionary manoeuvre(const Dictionary &order);
};

} // namespace
} // namespace godot

#include <godot_cpp/classes/engine.hpp>

namespace godot {
namespace {

template <class V>
int64_t Drive<V>::Engine_frames() {
	return (int64_t)Engine::get_singleton()->get_physics_frames();
}

// Round 26 (manoeuvre M1, C26.2): `order = _manoeuvre(order)`, the first line of drive()'s GDScript body. The per-tick gate
// natively (the same reads and the one write, `_behind_tick`); the DECISION -- a new goal, or the same spot asked again
// after a gap in the drive ticks -- is the live GDScript (_manoeuvre does all of it from the top, writing every member and
// counter itself). In the native drive Movement._off is empty (NativeDrive.usable), so behind_on() is true here.
//   if not behind_on() or order.get("reverse") or order.get("direct") or wheel_radius() < 0.0: return order
//   goal := Vector3(float(order["x"]), 0, float(order["z"])); tick := Engine.get_physics_frames()
//   gap := tick - _behind_tick > BEHIND_GAP_TICKS; _behind_tick = tick
//   if gap or _behind_goal == INF or _flat_distance(goal, _behind_goal) > NEW_GOAL_JUMP: <the decision>
//   if _behind_plan != "reverse": return order
//   reversed := order.duplicate(); reversed["reverse"] = true; reversed.erase("facing"); return reversed
template <class V>
Dictionary Drive<V>::manoeuvre(const Dictionary &order) {
	static const String r_reverse_plan("reverse");
	if (c.BEHIND_GAP_TICKS < 0) {
		return order;
	}
	if ((bool)order.get(k.reverse, false) || (bool)order.get(k.direct, false) || wheel_radius() < 0.0) {
		return order;
	}
	const Vector3 goal((real_t)(double)order[k.x], 0, (real_t)(double)order[k.z]);
	const int64_t tick = Engine_frames();
	const bool gap = tick - (int64_t)v._behind_tick() > c.BEHIND_GAP_TICKS;
	const Vector3 behind_goal = v._behind_goal();
	if (gap || behind_goal == V3_INF || flat_distance(goal, behind_goal) > c.NEW_GOAL_JUMP) {
		Timed t("manoeuvre");
		return cb(k._manoeuvre, order); // nothing written above: the GDScript decides from the same state
	}
	v.set__behind_tick(tick);
	if (String(v._behind_plan()) != r_reverse_plan) {
		return order;
	}
	Dictionary reversed = order.duplicate();
	reversed[k.reverse] = true;
	reversed.erase(k.facing);
	return reversed;
}

template <class V>
bool Drive<V>::run(Object *cmd, const Dictionary &order_in, double delta) {
	static const String r_order("order"), r_station("station"), r_circle("circle"), r_other("other"), cancelled("cancelled");
	cb_on = (bool)c.switches->get(k.native_cb);
	const Dictionary order = manoeuvre(order_in);
	// var goal := Vector3(order["x"], 0.0, order["z"])
	Vector3 goal((real_t)(double)order[k.x], 0, (real_t)(double)order[k.z]);
	if (order.has(k.leash)) {
		sadd(k.leash_orders, step); // leash_on() is the opt-in arm: off here
	}
	const Vector3 repair_for = v._repair_for();
	if (repair_for != V3_INF) {
		if (flat_distance(goal, repair_for) > c.NEW_GOAL_JUMP) {
			v.set__repair_for(V3_INF);
			v.set__repair_to(V3_INF);
		} else {
			const Vector3 repair_to = v._repair_to();
			if (repair_to != V3_INF) {
				goal = repair_to;
			}
		}
	}
	const Vector3 old_goal = v._goal();
	if (old_goal == V3_INF || flat_distance(goal, old_goal) > c.NEW_GOAL_JUMP) {
		v.set__order_ticks(0);
	}
	v.set__goal(goal);
	{
		Timed t("~track_goal");
		track_goal(goal);
	}
	const int64_t order_ticks = (int64_t)v._order_ticks() + step;
	v.set__order_ticks(order_ticks);
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
	v.set_arc_live(aim != goal);
	Vector3 routed;
	{
		Timed t("~next_waypoint");
		routed = direct ? aim : next_waypoint(aim, delta);
	}
	if (!direct && routed != aim && flat_distance(routed, here) < c.WAYPOINT_MIN_M) {
		const PackedVector3Array path = v._path();
		routed = corner_beyond(path, v._path_index(), aim);
	}
	Vector3 around_fire = routed;
	if (!fire_check_skips()) {
		Timed t("around_fire");
		around_fire = c.fire_ready && (bool)c.switches->get(k.native_fire) ? this->around_fire(routed, goal, order) :
																			 (Vector3)cb(k._around_fire, routed, goal, order);
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
	v.set__arrive(arrive_field);
	double arrive = around_fire == goal ? arrive_field : 0.5;
	double remaining;
	{
		Timed t("~remaining");
		remaining = direct ? flat_distance(here, goal) : remaining_path_distance(goal);
	}
	v.set__remaining(remaining);
	double pace = 1.0;
	bool deflected = false;
	v.set__deflected(false);
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
			v.set__deflected(true);
		}
		waypoint = point;
		pace = keep;
	}
	if ((bool)order.get(k.paced, false)) {
		int64_t give_way_left = v._give_way_left();
		if (give_way_left > 0) {
			v.set__give_way_left(give_way_left - step);
			pace = MIN(pace, c.GIVE_WAY_PACE);
		} else if (deflected && pace < 0.95) {
			int64_t blocked_ticks = (int64_t)v._blocked_ticks() + step;
			v.set__blocked_ticks(blocked_ticks);
			if (blocked_ticks >= c.GIVE_WAY_AFTER_TICKS) {
				v.set__blocked_ticks(0);
				v.set__give_way_left(c.GIVE_WAY_TICKS);
				v.set_give_ways((int64_t)v.give_ways() + 1);
				pace = MIN(pace, c.GIVE_WAY_PACE);
			}
		} else {
			v.set__blocked_ticks(0);
		}
	} else {
		v.set__blocked_ticks(0);
		v.set__give_way_left(0);
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
				const int64_t check_left = (int64_t)v._kturn_check() - step;
				if ((double)v._kturn_left_m() > 0.0) {
					Vector2 leg_vector;
					Timed t("~kturn_leg");
					if (kturn_leg(delta, leg_vector)) {
						planned = true;
						leg->set(k.throttle, (double)leg_vector.x);
						leg->set(k.turn, (double)leg_vector.y);
					}
				} else if (check_left > 0) {
					// _planned_reverse between checks: `_kturn_check -= ctl._step; if _kturn_check > 0: return false`.
					v.set__kturn_check(check_left);
				} else {
					Timed t("planned_reverse");
					if (!cb_on || !c.kturn_look_ready || !planned_reverse_cheap(waypoint)) {
						planned = cb(k._planned_reverse, leg_ref, waypoint, delta);
					}
				}
				if (planned) {
					drive_vector = Vector2((real_t)(double)leg->get(k.throttle), (real_t)(double)leg->get(k.turn));
				}
			} else if ((double)v._kturn_left_m() > 0.0) {
				cb(k._kturn_end, cancelled);
				v.set__kturn_left_m(0.0);
				Array legs = v._kturn_legs();
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
	const double kturn_left = v._kturn_left_m();
	if (kturn_left > 0.0) {
		throttle = drive_vector.x;
		cmd->set(k.throttle, throttle);
		v.set__ease_ticks(0);
	} else {
		const int64_t ease_ticks = v._ease_ticks();
		if (ease_ticks > 0) {
			v.set__ease_ticks(ease_ticks - step);
			const double ease_throttle = v._ease_throttle();
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
		if (!(bool)v._circling()) {
			sadd(k.circle_reverses, 1);
		}
	}
	v.set__circling(circling);
	v.set__nose_at_end(false); // _nose_stop: nose_stop_on() is the opt-in arm, off here
	v.set_steer_to(waypoint);
	v.set_pace_now(pace);
	{
		Timed t("~note_wedge");
		note_wedge(pace < 0.999);
	}
	bool stationed = false;
	v.set_stationed_now(false);
	if ((bool)sget(k.station_on) && !direct && !reverse && pace >= 0.99 && waypoint == goal &&
			remaining <= c.STATION_RANGE && (double)((Vector2)v._goal_velocity()).length() >= c.STATION_MIN_SPEED) {
		{
			Timed t("keep_station");
			const double cap = (bool)order.get(k.paced, false) ? speed_factor : 1.0;
			drive_vector = cb_on && c.station_ready ? keep_station(cmd, goal, delta, cap) :
											 (Vector2)cb(k._keep_station, cmd, goal, delta, cap);
		}
		stationed = true;
		v.set_stationed_now(true);
	} else {
		const Variant station = v._station();
		if (station.get_type() == Variant::OBJECT && station.get_validated_object() != nullptr) {
			// Pid.reset() (round 27, E2: its two writes in place of a call into GDScript): integral = 0.0; _primed = false
			Object *pid = station.get_validated_object();
			if (cb_on) {
				pid->set(k.integral, 0.0);
				pid->set(k._primed, false);
			} else {
				pid->call(k.reset);
			}
		}
	}
	if ((double)v._kturn_left_m() <= 0.0 && (double)cmd->get(k.throttle) < 0.0) {
		if (reverse) {
			v.set__reverse_why(r_order);
		} else if (stationed) {
			v.set__reverse_why(r_station);
		} else if (circling) {
			v.set__reverse_why(r_circle);
		} else {
			v.set__reverse_why(r_other);
		}
	}
	track_progress(goal, drive_vector, remaining);
	{
		Timed t("~update_phase");
		update_phase(goal, drive_vector, direct);
	}
	const bool held_back = pace < c.AVOID_ASK_PACE && order_ticks >= c.AVOID_GRACE_TICKS;
	const int64_t ask_after = (int64_t)(c.ASK_SECONDS * (double)c.TICK_RATE);
	const int64_t stalled_ticks = v.stalled_ticks();
	if (stalled_ticks >= ask_after || held_back) {
		int64_t ask_left = (int64_t)v._ask_left() - step;
		v.set__ask_left(ask_left);
		if (ask_left <= 0) {
			v.set__ask_left((int64_t)(c.ASK_EVERY_SECONDS * (double)c.TICK_RATE));
			Timed t("negotiate");
			if (cb_on && c.blocker_ready) {
				negotiate(goal, direct, stalled_ticks < ask_after);
			} else {
				cb(k._negotiate, goal, direct, stalled_ticks < ask_after);
			}
		}
	} else {
		v.set__ask_left(0);
	}
	return true;
}

} // namespace

namespace {
// Round 27 (E1c): the drives run on the owned state, and the transition's syncs they made (the pulls after callbacks and
// the pushes before GDScript reads; measurement: what is left of them is what E2-E4 have not ported yet).
struct OwnedCounts {
	int64_t drives = 0, pulls = 0, pushes = 0;
	// The price of the mirror (the orchestrator's condition on E1's design): the push at each drive's END, which is
	// what the owned execute keeps at E5 (the changed fields only), and the transition's pull at its start.
	int64_t end_push_fields = 0;
	double end_push_usec = 0.0, start_pull_usec = 0.0;
} owned_counts_;
} // namespace

Vector2 steering_drive_toward(const DriveConfig &c, const Vector3 &position, const Vector3 &forward, const Vector3 &target,
		double arrive_radius) {
	return drive_toward(c, position, forward, target, arrive_radius, -1.0, false);
}

bool drive_with(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta, ExecState *state) {
	if (!config.ready || mover == nullptr || cmd == nullptr) {
		return false;
	}
	profiling_ = config.profile;
	struct DriveTotal {
		std::chrono::steady_clock::time_point t0;
		DriveTotal() {
			if (profiling_) {
				t0 = std::chrono::steady_clock::now();
			}
		}
		~DriveTotal() {
			if (profiling_) {
				clock_().total += std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count();
				clock_().drives++;
			}
		}
	} total;
	if (state == nullptr) {
		Drive<ObjectView> d(config, mover, ObjectView(mover));
		return d.bind() && d.run(cmd, order, delta);
	}
	Drive<StructView> d(config, mover, StructView(mover, state));
	return d.bind() && d.run(cmd, order, delta);
}

bool unstick_with(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta,
		ExecState *state) {
	if (!config.ready || !config.unstick_ready || mover == nullptr || cmd == nullptr) {
		return false;
	}
	const N &k = n_();
	if (config.manoeuvre_census != nullptr && (bool)config.manoeuvre_census->get(k.on)) {
		if (state != nullptr) {
			StructView(mover, state).push_out();
		}
		mover->call(k.unstick_m, cmd, order, delta); // the census observes every unstick: the GDScript, as it is
		if (state != nullptr) {
			state->pull(mover);
		}
		return true;
	}
	if (state == nullptr) {
		ObjectView view(mover);
		view.bind_gunnery();
		Drive<ObjectView> d(config, mover, view);
		if (!d.bind()) {
			return false;
		}
		d.unstick(cmd, order, delta);
		return true;
	}
	Drive<StructView> d(config, mover, StructView(mover, state));
	if (!d.bind()) {
		return false;
	}
	d.unstick(cmd, order, delta);
	return true;
}

bool drive_native(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta, bool owned) {
	if (!config.ready || mover == nullptr || cmd == nullptr) {
		return false;
	}
	profiling_ = config.profile;
	if (!owned) {
		return drive_with(config, mover, cmd, order, delta, nullptr);
	}
	// The owned state: pulled whole at the start while the drive still calls GDScript back (E2-E4), pushed at the end.
	// A local state while the drive still calls GDScript back (it is pulled whole at the start anyway): no reference
	// outlives the drive. (A registry held across ticks freed its Variants after the engine at exit: "corrupted size vs.
	// prev_size" in every owned run. E5's persistent state is tied to the mover's lifetime.)
	ExecState local;
	ExecState *state = &local;
	const auto p0 = std::chrono::steady_clock::now();
	state->pull(mover);
	owned_counts_.start_pull_usec += std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - p0).count();
	Drive<StructView> d(config, mover, StructView(mover, state));
	if (!d.bind()) {
		return false;
	}
	const bool done = d.run(cmd, order, delta);
	owned_counts_.end_push_fields += state->m_dirty.count() + state->g_dirty.count() + state->l_dirty.count();
	const auto e0 = std::chrono::steady_clock::now();
	d.v.push_out();
	owned_counts_.end_push_usec += std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - e0).count();
	owned_counts_.drives++;
	owned_counts_.pulls += d.v.pulls + 1;
	owned_counts_.pushes += d.v.pushes;
	return done;
}

bool unstick_native(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta, bool owned) {
	if (!owned) {
		return unstick_with(config, mover, cmd, order, delta, nullptr);
	}
	ExecState local;
	local.pull(mover);
	const bool done = unstick_with(config, mover, cmd, order, delta, &local);
	local.push(mover, false);
	return done;
}

Dictionary drive_owned_counts(bool reset) {
	Dictionary out;
	out["drives"] = owned_counts_.drives;
	out["pulls"] = owned_counts_.pulls;
	out["pushes"] = owned_counts_.pushes;
	out["end_push_fields"] = owned_counts_.end_push_fields;
	out["end_push_usec"] = owned_counts_.end_push_usec;
	out["start_pull_usec"] = owned_counts_.start_pull_usec;
	if (reset) {
		owned_counts_ = OwnedCounts();
	}
	return out;
}

Vector3 drive_around_fire(const DriveConfig &config, Object *mover, const Vector3 &waypoint, const Vector3 &goal,
		const Dictionary &order) {
	Drive<ObjectView> d(config, mover, ObjectView(mover));
	if (!config.ready || !config.fire_ready || mover == nullptr || !d.bind()) {
		return waypoint;
	}
	return d.around_fire(waypoint, goal, order);
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
