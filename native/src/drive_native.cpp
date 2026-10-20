#include "drive_native.h"

#include "avoidance.h"
#include "exec_view.h"
#include "motion_native.h"
#include "nav_native.h"

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/navigation_mesh.hpp>
#include <godot_cpp/classes/navigation_region3d.hpp>
#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
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
// Round 33 (N5.M), measurement only (drive_owned_counts): `_manoeuvre` decisions the native drive made, and called back.
struct ManoeuvreCounts {
	int64_t native = 0, called_back = 0;
} manoeuvre_counts_;
// Round 33 (N5.Y), measurement only (drive_owned_counts): _negotiate bodies the native drive ran, and called back.
struct NegotiateCounts {
	int64_t native = 0, called_back = 0;
} negotiate_counts_;
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
	StringName _live{ "_live" }, _root{ "_root" }, _frame{ "_frame" }, avoid_hold{ "avoid_hold" }, avoid_shape{ "avoid_shape" }, _crews{ "_crews" }, live{ "live" };
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
			// Round 33 (N5.M): the decision
			native_manoeuvre{ "native_manoeuvre" }, kturn_cap{ "kturn_cap" }, behind_asked{ "behind_asked" },
			behind_reverses{ "behind_reverses" }, plans{ "plans" }, refused{ "refused" }, acceleration_mps2{ "acceleration_mps2" },
			braking_mps2{ "braking_mps2" }, lateral_grip{ "lateral_grip" }, position{ "position" }, forward{ "forward" },
			velocity{ "velocity" }, max_reverse_speed{ "max_reverse_speed" }, hull_turn_rate{ "hull_turn_rate" },
			hull_turn_rate_deg{ "hull_turn_rate_deg" }, _motion{ "_motion" }, yaw_rate{ "yaw_rate" },
			// Round 33 (N5.Y)
			native_yield{ "native_yield" }, deploy_ratio{ "deploy_ratio" }, weapon_order{ "weapon_order" }, engaged_target{ "engaged_target" },
			move_order{ "move_order" }, asks_refused{ "asks_refused" }, setup_refusals{ "setup_refusals" },
			parked_refusals{ "parked_refusals" }, yields_started{ "yields_started" }, yield_swaps{ "yield_swaps" },
			yield_swaps_shorter{ "yield_swaps_shorter" }, yield_spots_unfit{ "yield_spots_unfit" },
			yield_spots_shortened{ "yield_spots_shortened" }, yield_holds{ "yield_holds" }, neighbours{ "neighbours" },
			off{ "off" }, yield_log{ "yield_log" }, setup_log{ "setup_log" }, yield_site{ "yield" },
			// fast paths
			game_match{ "game_match" }, tick{ "tick" }, think_offset{ "think_offset" }, _stride{ "_stride" },
			_fire_detour{ "_fire_detour" }, _fire_checked_tick{ "_fire_checked_tick" }, _kturn_check{ "_kturn_check" },
			_bake_radius{ "_bake_radius" }, split{ "split" },
			gates_offered{ "gates_offered" }, gates_aimed{ "gates_aimed" }, gates_refused{ "gates_refused" },
			gate_refusals{ "gate_refusals" }, gate_off_mesh_fit{ "gate_off_mesh_fit" }, gate_site{ "gate" },
			gates_given_up{ "gates_given_up" }, gates_reached_latched{ "gates_reached_latched" },
			gates_shortened{ "gates_shortened" }, _gate_answer{ "_gate_answer" }, gates_turned{ "gates_turned" },
			gates_latched_away{ "gates_latched_away" }, gates_near{ "gates_near" }, gates_side{ "gates_side" }, gates_inside{ "gates_inside" }, side_gate{ "side_gate" },
			// the k-turn leg
			_kturn_rolling{ "_kturn_rolling" }, _kturn_gear{ "_kturn_gear" }, _kturn_from{ "_kturn_from" }, real_velocity{ "real_velocity" },
			_escape_step{ "_escape_step" }, _escape_begin{ "_escape_begin" },
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
			press_escapes{ "press_escapes" }, on{ "on" }, unstick_m{ "unstick" }, type{ "type" }, _end_yield{ "_end_yield" }, ready_memo{ "ready_memo" },
			_ready_map{ "_ready_map" }, _ready_iteration{ "_ready_iteration" }, _ready_answer{ "_ready_answer" },
			locomotion{ "locomotion" }, min_turn_radius_m{ "min_turn_radius_m" }, for_unit{ "for_unit" },
			goal_repairs{ "goal_repairs" }, goal_repairs_refused{ "goal_repairs_refused" },
			// Round 34 (traffic T6b, `underfire`: (a) the ask refusal, (b) the begin_yield gate; (c) the hit abort dropped, R34.17)
			ticks_since_hit{ "ticks_since_hit" }, underfire_refusals{ "underfire_refusals" },
			underfire_holds{ "underfire_holds" },
			// Round 35 (traffic T7, C35.8): refuse under fire only when the asker has a pass lane; the refused asker passes
			underfire_gives{ "underfire_gives" }, passes{ "passes" }, passes_done{ "passes_done" },
			passes_timeout{ "passes_timeout" }, pass_ticks{ "pass_ticks" }, _pass_lane{ "_pass_lane" }, is_alive{ "is_alive" };
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

inline double rad_to_deg(double rad) {
	return rad * (180.0 / Math::PI); // Math::rad_to_deg(double), as tank_drive_native.cpp
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
	String gate_answer; // Movement._gate_answer for this drive
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

	// Round 29 (traffic T1): Traffic.holding(String(tank.name)), read from its `_live` table natively. Asked once a drive
	// and kept until _avoid's hold callback (the only place in a drive where this crew's entry can change: hold_of writes
	// it, refresh's _forget empties the table).
	int8_t hold_state = -1;
	bool holding() {
		if (!c.traffic_hold) {
			return false;
		}
		if (hold_state < 0) {
			hold_state = traffic_holding() ? 1 : 0;
		}
		return hold_state == 1;
	}
	// PlannerSeam.live(name) = on() and _crews.has(name): a Dictionary lookup on the seam's static table.
	bool seam_live() {
		if (!c.planner_on) {
			return false;
		}
		const Dictionary crews = c.planner_seam->get(k._crews);
		if (crews.is_empty()) {
			return false;
		}
		const String name = String(tank->get_name());
		Object *crew = crews.get(name, Variant()).get_validated_object();
		if (crew == nullptr) {
			return false;
		}
		// PlannerSeam.live: a crew whose hull is freed (or queued for it) is released and is no hold. That rare case
		// (a disposed match's hull, its name reused) is called back, so the release is the GDScript's own.
		Node *hull = Object::cast_to<Node>(crew->get(k.tank).get_validated_object());
		if (hull == nullptr || hull->is_queued_for_deletion()) {
			return (bool)c.planner_seam->call(k.live, name);
		}
		return true;
	}

	bool traffic_holding() {
		Object *t = c.traffic_script;
		const Dictionary live = t->get(k._live);
		if (live.is_empty()) {
			return false;
		}
		const Variant seen = live.get(String(tank->get_name()), Variant());
		if (seen.get_type() == Variant::NIL) {
			return false;
		}
		// `var frame := Engine.get_physics_frames() if _root != -1 else _frame`
		const int64_t frame = (int64_t)t->get(k._root) != -1 ? Engine_frames() : (int64_t)t->get(k._frame);
		const int64_t at = seen;
		return frame - at <= c.LIVE_TICKS && frame >= at;
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
			ready_value = (bool)c.pathing->get(k.enabled) && (cb_on ? pathing_is_ready() : (bool)gd(c.pathing, k.is_ready, tank));
		}
		return ready_value;
	}

	// Pathing.is_ready(tank) (round 28, N5), line by line, with its memo in Pathing's statics (ready_memo on: one owner
	// probe a map iteration; off: every call); the profile_detail laps are measurement only and not kept.
	bool pathing_is_ready() {
		NavigationServer3D *server = NavigationServer3D::get_singleton();
		const RID map = tank->get_world_3d()->get_navigation_map();
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

	double wheel_radius() {
		// Movement.wheel_radius(): its per-unit cache, filled by the GDScript the first time.
		const String unit = tank->get(k.unit_id);
		if (String(v._wheel_radius_unit()) == unit) {
			return v._wheel_radius_value();
		}
		if (!cb_on) {
			return cb(k.wheel_radius);
		}
		// Movement.wheel_radius()'s cache fill (round 28, N5): `_wheel_radius_value = 0.0; if locomotion == "wheels":
		// maxf(float(min_turn_radius_m), 0.5)` -- Units.stat's answers (GDScript statics, read-only).
		static const String wheels("wheels"), tracks("tracks");
		v.set__wheel_radius_unit(unit);
		double value = 0.0;
		if (String(c.units->call(k.stat, unit, k.locomotion, tracks)) == wheels) {
			value = MAX((double)c.units->call(k.stat, unit, k.min_turn_radius_m, 0.0), 0.5);
		}
		v.set__wheel_radius_value(value);
		return value;
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
	void avoid(const Vector3 &waypoint, double speed_factor, double delta, Vector3 &out_point, double &out_keep,
			bool held = false) {
		// Round 29 (traffic T1, his call: TAKE TURNS): a crew of a squad waiting for another to come through a street
		// drives to its spot beside the mouth and stops there facing its way. NativeTraffic.avoid_hold is
		// `if not Traffic.off("hold"): Traffic.refresh(ctl.tanks_root); hold = Traffic.hold_of(name)` (the members it
		// reads pushed first; it writes none).
		if (!held && c.traffic_hold) {
			const Array hold = gd(c.native_traffic, k.avoid_hold, String(tank->get_name()), ctl->get(k.tanks_root));
			hold_state = -1;
			if (!hold.is_empty()) {
				// Round 35 (traffic T7): a street-mouth hold outranks a pass.
				if (!String(v._pass_by()).is_empty()) {
					pass_end();
				}
				const Vector2 face = hold[1];
				if ((bool)hold[2]) {
					out_point = Vector3(face.x, 0.0, face.y);
					out_keep = 0.0;
					return;
				}
				const Vector2 spot = hold[0];
				const double approach = clampd(((double)Vector2(here.x, here.z).distance_to(spot) - c.HOLD_REACHED_M) /
								c.HOLD_SLOW_M, 0.15, 1.0);
				Vector3 toward;
				double keep;
				avoid(Vector3(spot.x, 0.0, spot.y), speed_factor * approach, delta, toward, keep, true);
				out_point = toward;
				out_keep = MIN(keep, approach);
				return;
			}
		}
		// Round 35 (traffic T7): passing a crew under fire that refused me: steer by its lane (ORCA still shapes it).
		Vector3 steer = waypoint;
		if (!held && !String(v._pass_by()).is_empty()) {
			const Vector3 lane = pass_point();
			if (lane != V3_INF) {
				steer = lane;
			}
		}
		out_point = steer;
		out_keep = 1.0;
		const Vector2 to((real_t)((double)steer.x - (double)here.x), (real_t)((double)steer.z - (double)here.z));
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
		const Vector2 route_preferred = to / (real_t)distance * (real_t)desired; // Vector2 / float, * float: narrowed
		const String name = tank->get_name();
		// Round 31 (traffic T3b, his call: TAKE TURNS): two friendly squads crossing take turns; Traffic.shape slows the
		// yielding squad's wish and ORCA keeps everyone clear of it (NativeTraffic.avoid_shape: off("turns"), refresh,
		// shape).
		Vector2 preferred = route_preferred;
		if (!held && c.traffic_shape) {
			preferred = gd(c.native_traffic, k.avoid_shape, name, ctl->get(k.tanks_root), route_preferred);
		}
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
		if ((double)chosen.distance_squared_to(route_preferred) < 0.04) {
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
		double bake = script->get(k._bake_radius);
		if (bake < 0.0) {
			if (!cb_on || c.NAV_AGENT_RADIUS <= 0.0) {
				return cb(k._chord_slack);
			}
			bake = bake_radius();
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
		if (speed <= 0.0) {
			return 0.0;
		}
		if (arc_here()) {
			// Round 30/31 (manoeuvre kturnarc, H2): the plant brakes in discrete ticks: v^2/2b - v*dt/2.
			return MAX(speed * speed / (2.0 * braking()) - speed * 0.5 / (double)c.TICK_RATE, 0.0);
		}
		return speed * speed / (2.0 * braking());
	}

	// Movement._arc_here() (manoeuvre 0cf72ba7): the arc rule only for the braked hulls (kturn_brake_on: >= KTURN_BRAKE_HULL_M
	// or kturnbrakeall); a short hull keeps round 14's chord bit for bit.
	bool arc_here() {
		return c.KTURN_ARC && kturn_brake_on();
	}

	void kturn_end() {
		Array looks = v._kturn_looks();
		looks.clear();
	}

	void kturn_start_leg(const Vector2 &leg) {
		v.set__kturn_gear((int64_t)leg.x);
		v.set__kturn_left_m((double)leg.y);
		v.set__kturn_from(here);
		v.set__kturn_arc_m(0.0); // a leg must not inherit the last leg's arc (round 30's review)
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
			v.set__kturn_arc_m(0.0);
		} else if (arc_here()) {
			// Round 31 (manoeuvre H2, `kturnarc`): the arc driven in the leg's gear, the last tick's real motion along the
			// nose in the leg's gear.
			const Vector3 nose_now = Vector3((real_t)(-basis_z.x), 0.0f, (real_t)(-basis_z.z)).normalized();
			const Vector3 real_velocity = tank->get(k.real_velocity);
			// manoeuvre 9013a519: motion against the leg's gear counts nothing (a roll-out is not progress, nor negative)
			v.set__kturn_arc_m((double)v._kturn_arc_m() + MAX(0.0, (double)real_velocity.dot(nose_now) * (double)gear) * delta);
		}
		const double backed = arc_here() ? (double)v._kturn_arc_m() : flat_distance(here, v._kturn_from());
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
	Vector3 gate_refused(const char *reason, const Vector3 &goal) { return gate_refused(String(reason), goal); }
	Vector3 gate_refused(const String &reason, const Vector3 &goal) {
		gate_answer = reason; // v4's static _gate_answer (written once a drive, below)
		sadd(k.gates_refused, 1);
		count_into(k.gate_refusals, reason);
		return goal;
	}

	// ---- Movement._gate_has_room / _roomy_gate / _roomy_gate_memo (brains B5c v3): a gate a car can turn onto its line
	// at (every point of a ring one turning radius round it on the navmesh), else the longest shorter run-in, else INF ----
	bool gate_has_room(const RID &map, const Vector3 &gate, double radius) { return gate_has_room(map, gate, radius, c.GATE_ROOM_POINTS); }
	bool gate_has_room(const RID &map, const Vector3 &gate, double radius, int64_t points) {
		for (int64_t i = 0; i < points; i++) {
			// var a := TAU * k / points; var point := gate + Vector3(cos(a), 0.0, sin(a)) * radius
			const double a = 6.2831853071795864769252867666 /* GDScript TAU */ * (double)i / (double)points;
			const Vector3 point = gate + Vector3((real_t)cos(a), 0, (real_t)sin(a)) * (real_t)radius;
			if (flat_distance(closest_point(map, point, k.gate_site), point) > c.MESH_GATE_SLACK) {
				return false;
			}
		}
		return true;
	}

	Vector3 roomy_gate(const RID &map, const Vector3 &goal, const Vector2 &direction, double length, double radius) {
		double shares[4] = { 1.0, c.OFF_MESH_PROBES[0], c.OFF_MESH_PROBES[1], c.OFF_MESH_PROBES[2] };
		for (double share : shares) {
			const Vector3 gate((real_t)((double)goal.x - (double)direction.x * length * share), 0,
					(real_t)((double)goal.z - (double)direction.y * length * share));
			if (gate_has_room(map, gate, radius)) {
				return gate;
			}
		}
		return V3_INF;
	}

	Vector3 roomy_gate_memo(const RID &map, const Vector3 &goal, const Vector2 &direction, double length, double radius) {
		Array key;
		key.push_back(goal);
		key.push_back(direction);
		key.push_back(length);
		key.push_back(radius);
		if (key != v._roomy_key()) {
			v.set__roomy_key(key);
			v.set__roomy_value(roomy_gate(map, goal, direction, length, radius));
		}
		return v._roomy_value();
	}

	// ---- v4: Movement._gate_latch / _turn_room / _turn_room_memo (brains B5c-v4) ----
	Vector3 gate_latch(const Vector3 &goal, const String &why) {
		v.set__gate_dropped_for(goal);
		v.set__gate_dropped_why(why);
		return gate_refused(why, goal);
	}

	bool turn_room(const RID &map, const Vector3 &gate, const Vector2 &direction, double radius) {
		const double sides[2] = { 1.0, -1.0 };
		for (double side : sides) {
			// var centre := gate + Vector3(-direction.y, 0.0, direction.x) * radius * side
			const Vector3 centre = gate + Vector3(-direction.y, 0, direction.x) * (real_t)radius * (real_t)side;
			if (gate_has_room(map, centre, radius, c.TURN_ROOM_POINTS)) {
				return true;
			}
		}
		return false;
	}

	bool turn_room_memo(const RID &map, const Vector3 &gate, const Vector2 &direction, double radius) {
		Array key;
		key.push_back(gate);
		key.push_back(direction);
		key.push_back(radius);
		if (key != v._turn_room_key()) {
			v.set__turn_room_key(key);
			v.set__turn_room_value(turn_room(map, gate, direction, radius));
		}
		return v._turn_room_value();
	}

	// Movement._arrive_gate(): maxf(GATE_REACHED, settle_radius(unit)), the settle radius memoised per unit.
	double arrive_gate() {
		const String unit = tank->get(k.unit_id);
		const double *settle_known = c.settle_of.getptr(unit);
		double settle;
		if (settle_known != nullptr) {
			settle = *settle_known;
		} else {
			settle = script->call(k.settle_radius, unit);
			c.settle_of.insert(unit, settle);
		}
		return MAX(c.GATE_REACHED, settle);
	}

	// ---- v6 (R33.8): Movement.inside_turning_circle, pure: `gate` strictly inside a circle of `radius` beside the hull ----
	static bool inside_turning_circle(const Vector3 &at3, const Vector2 &forward, const Vector3 &gate, double radius) {
		const Vector2 right(-forward.y, forward.x);
		const Vector2 at(at3.x, at3.z);
		const Vector2 point(gate.x, gate.z);
		return (double)at.distance_to(point) > 0.0 && ((double)point.distance_to(at + right * (real_t)radius) < radius ||
				(double)point.distance_to(at - right * (real_t)radius) < radius);
	}

	// ---- Movement._approach_gate, A4 (the curved gate, opt-in) off: called only with a wheeled hull and a facing ----
	Vector3 approach_gate(const Vector3 &goal, const Dictionary &order, double radius) {
		sadd(k.gates_offered, 1);
		bool turning = false;
		// Round 29 (brains B5c): a gate this hull stalled against (or reached) is given up for this goal.
		if (c.gate_giveup) {
			const Vector3 dropped = v._gate_dropped_for();
			if (dropped != V3_INF && flat_distance(goal, dropped) <= c.NEW_GOAL_JUMP) {
				return gate_refused(v._gate_dropped_why(), goal);
			}
			static const String blocked("blocked"), stalled("stalled"), no_path("no_path"), turn_blocked("turn_blocked"),
					turn_capped("turn_capped");
			const Vector3 turning_for = v._gate_turning_for();
			turning = turning_for != V3_INF && flat_distance(goal, turning_for) <= c.NEW_GOAL_JUMP;
			if (turning) {
				// v4: coming round is bounded: stuck on terrain or a hull (not "no_path": circling), or out of time.
				const bool stuck = v.phase() == blocked && v.blocked_by() != no_path;
				if (stuck || v._order_ticks() - v._gate_turning_tick() > (int64_t)(c.GATE_TURN_SECONDS * (double)c.TICK_RATE)) {
					return gate_latch(goal, stuck ? turn_blocked : turn_capped);
				}
			} else if (v.arc_live() && v.phase() == blocked) {
				v.set__gate_dropped_for(goal);
				v.set__gate_dropped_why(stalled);
				sadd(k.gates_given_up, 1);
				return gate_refused(stalled, goal);
			}
		}
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
		double length = clampd(radius * c.APPROACH_RADII, c.APPROACH_MIN, c.APPROACH_MAX);
		Vector3 gate((real_t)((double)goal.x - (double)direction.x * length), 0,
				(real_t)((double)goal.z - (double)direction.y * length));
		if (c.gate_giveup && flat_distance(goal, v._gate_seen_for()) > c.NEW_GOAL_JUMP) {
			// v4 near: judged on the nominal approach (before the roomy rule shortens it), once per new goal.
			v.set__gate_seen_for(goal);
			const double straight = flat_distance(here, goal);
			if (straight <= length && flat_distance(here, gate) + length > c.GATE_NEAR_DETOUR * straight) {
				sadd(k.gates_near, 1);
				static const String near("near");
				return gate_latch(goal, near);
			}
			// v6 (brains B5c-v6, C32.4): pointed away from the heading, the planner's side gate (once per goal; called
			// back: PlannerSeam.side_gate reads the C++ clearances itself, so both arms take one answer).
			v.set__gate_side_for(goal);
			v.set__gate_side(V3_INF);
			const Vector2 ahead = Vector2(-basis_z.x, -basis_z.z).normalized();
			// Round 33 (R4): only where v4's come-round has no turning circle beside the (nominal) rear gate.
			if (c.gate_side && c.planner_seam != nullptr && (double)ahead.dot(direction) < 0.0 &&
					!turn_room_memo(tank->get_world_3d()->get_navigation_map(), gate, direction, radius)) {
				const Vector3 side = c.planner_seam->call(k.side_gate, goal, Vector3(direction.x, 0, direction.y),
						String(tank->get(k.unit_id)), tank->get_world_3d()->get_navigation_map(), here);
				if (side != Vector3()) {
					v.set__gate_side(Vector3(side.x, 0, side.z));
					sadd(k.gates_side, 1);
				}
			}
		}
		if (c.gate_side && v._gate_side() != V3_INF && flat_distance(goal, v._gate_side_for()) <= c.NEW_GOAL_JUMP) {
			if (flat_distance(here, v._gate_side()) <= arrive_gate()) {
				static const String side_latched("side_latched");
				return gate_latch(goal, side_latched);
			}
			if (c.gate_inside && !turning &&
					inside_turning_circle(here, Vector2(-basis_z.x, -basis_z.z).normalized(), v._gate_side(), radius)) {
				sadd(k.gates_inside, 1);
				static const String inside_circle("inside_circle");
				return gate_latch(goal, inside_circle);
			}
			sadd(k.gates_aimed, 1);
			return v._gate_side();
		}
		if (c.gate_giveup) {
			const Vector3 roomy = roomy_gate_memo(tank->get_world_3d()->get_navigation_map(), goal, direction, length, radius);
			if (roomy == V3_INF) {
				return gate_refused("cramped", goal);
			}
			if (roomy != gate) {
				sadd(k.gates_shortened, 1);
				length = flat_distance(roomy, goal);
				gate = roomy;
			}
		}
		const Vector2 forward = Vector2(-basis_z.x, -basis_z.z).normalized();
		if (flat_distance(here, gate) <= arrive_gate()) {
			if (c.gate_giveup) {
				if ((double)forward.dot(direction) < 0.0) {
					// Reached pointing away from the heading: it comes round the gate first, where a turning circle fits
					// beside it (v4); else latched facing away.
					if (turning) {
						return gate_refused("reached_facing_away", goal);
					}
					if (turn_room_memo(tank->get_world_3d()->get_navigation_map(), gate, direction, radius)) {
						v.set__gate_turning_for(goal);
						v.set__gate_turning_tick(v._order_ticks());
						sadd(k.gates_turned, 1);
						return gate_refused("reached_facing_away", goal);
					}
					sadd(k.gates_latched_away, 1);
					static const String latched_away("latched_away");
					return gate_latch(goal, latched_away);
				}
				static const String latched("latched");
				sadd(k.gates_reached_latched, 1);
				return gate_latch(goal, latched);
			}
			return gate_refused("reached", goal);
		}
		const Vector2 to_goal((real_t)((double)goal.x - (double)here.x), (real_t)((double)goal.z - (double)here.z));
		if ((double)to_goal.length() <= length && (double)forward.dot(direction) >= c.APPROACH_ALIGNED_COS) {
			return gate_refused("on_approach", goal);
		}
		if (c.gate_inside && !turning && inside_turning_circle(here, forward, gate, radius)) {
			sadd(k.gates_inside, 1);
			static const String inside_circle("inside_circle");
			return gate_latch(goal, inside_circle);
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
		if (holding()) {
			return; // round 29 (traffic T1): waiting at a street mouth on purpose; nobody to ask
		}
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
		// Round 33 (N5.Y): past the early-outs (nothing above writes), the body natively; else the GDScript from the top.
		if (!yield_native_on()) {
			negotiate_counts_.called_back++;
			cb(k._negotiate, goal, direct, still_only);
			return;
		}
		negotiate_counts_.native++;
		negotiate_body(goal, direct, Object::cast_to<Node3D>(other), mover);
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
		if (holding()) {
			return; // round 29 (traffic T1, C29.3): waiting at a street mouth on purpose
		}
		if (seam_live()) {
			return; // round 31 (planner, R31.2): a planner-held hull is never unstuck under its plan
		}
		if (c.UNSTICK_BACK && (int64_t)v._esc_stage() != 0) {
			// Round 31 (manoeuvre H1): an escape under way (_esc_stage only leaves ESC_NONE with `unstickback` on).
			cb(k._escape_step, cmd, order, delta);
			return;
		}
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
		// Round 31 (manoeuvre H1, `unstickback`): under a routed goal the stall is read from Tank.real_velocity when
		// _honest_blocker names what pins the hull, and the escape is _escape_begin's (called back: ask, the give-way
		// and the outline sweep are GDScript).
		Object *pinned_on = c.UNSTICK_BACK ? honest_blocker(order) : nullptr;
		const bool honest = pinned_on != nullptr;
		const double throttle = cmd->get(k.throttle);
		const Vector3 velocity = tank->get(honest ? k.real_velocity : k.estimated_velocity);
		if (std::fabs(throttle) > 0.5 && (double)velocity.length() < c.STUCK_SPEED) {
			const double stuck = v._stuck_time() + delta;
			v.set__stuck_time(stuck);
			if (stuck >= c.STUCK_SECONDS && honest) {
				v.set__stuck_time(0.0);
				cb(k._escape_begin, cmd, order, pinned_on);
				return;
			}
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

	// Movement._honest_blocker(order): what pins the hull (a Tank, or the hull itself for "terrain"), or null for round
	// 29's rule. Only a routed `move_to`; a hull longer than UNSTICK_BLIND_MAX_LEN_M only on a HULL with no wall touched.
	Object *honest_blocker(const Dictionary &order) {
		static const String move_to("move_to");
		if (String(order.get(k.type, String())) != move_to || (bool)order.get(k.direct, false)) {
			return nullptr;
		}
		CharacterBody3D *body = Object::cast_to<CharacterBody3D>(tank);
		Object *hull = nullptr;
		if (body != nullptr) {
			const int n = body->get_slide_collision_count();
			for (int i = 0; i < n; i++) {
				// `hull = get_slide_collision(i).get_collider() as Tank; if hull != null: break`
				Ref<KinematicCollision3D> hit = body->get_slide_collision(i);
				Object *collider = hit->get_collider();
				if (is_tank(collider)) {
					hull = collider;
					break;
				}
			}
		}
		if (hull_length(String(tank->get(k.unit_id))) <= c.UNSTICK_BLIND_MAX_LEN_M) {
			return hull != nullptr ? hull : (Object *)tank;
		}
		Object *wall = v.contact().get_validated_object();
		const bool touching = wall != nullptr && (bool)wall->get(k.touching);
		return hull != nullptr && !touching ? hull : nullptr;
	}

	bool is_tank(Object *o) const {
		if (o == nullptr) {
			return false;
		}
		Ref<Script> s = o->get_script();
		while (s.is_valid()) {
			if (s == c.tank_script) {
				return true;
			}
			s = s->get_base_script();
		}
		return false;
	}

	bool pressing_escape(Object *cmd, double delta) {
		if (!v.g_engaged_target().is_empty() || holding()) {
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

	// ---- Movement.right_of_way (round 27, stage 1 E5c), line by line; `_end_yield` natively unless its diagnosis record
	// is open (yield_log: then the GDScript, which writes it). 1: giving way (cmd filled), 0: not (or it just ended). ----
	int right_of_way(Object *cmd) {
		static const String yielding("yielding"), arrived("arrived");
		const String yield_to = v.yield_to();
		if (yield_to.is_empty()) {
			return 0;
		}
		v.set__yield_left(v._yield_left() - step);
		Node *root = Object::cast_to<Node>(ctl->get(k.tanks_root).get_validated_object());
		Node *asker_node = root != nullptr ? root->get_node_or_null(NodePath(yield_to)) : nullptr;
		Node3D *asker = asker_node != nullptr && asker_node->get(k.alive).get_type() == Variant::BOOL ?
				Object::cast_to<Node3D>(asker_node) : nullptr;
		const Vector3 yield_point = v._yield_point();
		const double stop_m = v._yield_stop_m();
		const bool there = flat_distance(here, yield_point) <= c.YIELD_REACHED ||
				(stop_m > 0.0 && flat_distance(here, v._yield_from()) >= stop_m);
		if (there) {
			v.set__yield_held(v._yield_held() + step);
		}
		bool passed = asker == nullptr || !(bool)asker->get(k.alive);
		if (!passed) {
			const Vector3 at = asker->get_global_position();
			passed = flat_distance(here, at) > c.YIELD_CLEAR ||
					(double)Vector2((real_t)((double)at.x - (double)here.x), (real_t)((double)at.z - (double)here.z))
									.dot(v._yield_dir()) > 0.0;
		}
		Object *asker_mover = asker != nullptr ? mover_of(asker) : nullptr;
		if (asker_mover != nullptr && String(asker_mover->get(k.phase)) == arrived) {
			passed = true;
		}
		if (v._yield_left() <= 0 || (passed && (there || v._yield_held() >= (int64_t)(c.YIELD_HOLD_SECONDS * (double)c.TICK_RATE)))) {
			end_yield(yield_to);
			return 0;
		}
		v.set_phase(yielding);
		v.set_blocked_by(yield_to);
		if (!there) {
			const Vector3 forward = -basis_z;
			const double arrive = c.YIELD_REACHED * 0.5;
			Vector2 drive_vector = drive_toward(c, here, forward, yield_point, arrive, -1.0, false);
			const double radius = wheel_radius();
			if (radius > 0.0) {
				const double speed = tank->get(k._speed);
				drive_vector = wheels(c, here, forward, yield_point, arrive, radius, speed, -1.0,
						straight_behind(yield_point) ? -1.0 : 1.0);
			} else if (straight_behind(yield_point)) {
				drive_vector = drive_toward(c, here, forward, yield_point, arrive, -1.0, true);
			}
			cmd->set(k.throttle, (double)drive_vector.x * 0.7);
			cmd->set(k.turn, (double)drive_vector.y);
		}
		return 1;
	}

	// Movement._end_yield: natively unless its diagnosis record is open (yield_log: then the GDScript, which writes it).
	void end_yield(const String &yield_to) {
		static const String driving("driving");
		if (!v._yield_rec().is_empty()) {
			cb(k._end_yield);
			return;
		}
		v.set__last_yielded_to(yield_to);
		v.set_yield_to(String());
		v.set__yield_point(V3_INF);
		v.set_blocked_by(String());
		v.set_phase(driving);
		v.set_stalled_ticks(0);
		v.set__progress_goal(V3_INF);
		v.set__repath_left(0.0);
	}

	// Round 34 (traffic T6, R34.15): Movement.underfire_on(), the switch (`--traffic-on=underfire`); off while the
	// GDScript has no T6 (UNDER_FIRE_TICKS -1: Movement.UNDER_FIRE_S absent).
	bool underfire_on() {
		static const String underfire("underfire");
		return c.UNDER_FIRE_TICKS >= 0 && c.traffic_script != nullptr && !traffic_off(underfire);
	}

	// Movement.under_fire(): hit within UNDER_FIRE_S, with the switch on.
	bool under_fire() {
		return underfire_on() && (int64_t)tank->get(k.ticks_since_hit) <= c.UNDER_FIRE_TICKS;
	}

	// Movement._straight_behind(point)
	bool straight_behind(const Vector3 &point) const {
		const Vector2 to((real_t)((double)point.x - (double)here.x), (real_t)((double)point.z - (double)here.z));
		const Vector2 back(basis_z.x, basis_z.z);
		return (double)to.length_squared() > 0.01 && (double)back.normalized().dot(to.normalized()) >= 0.9;
	}

	// Movement.bake_radius(tank) (round 28, N5): the navmesh's baked agent radius, from the NavigationRegion3D on THIS hull's
	// navigation map, memoised in Movement._bake_radius; NAV_AGENT_RADIUS (not memoised) when there is none; an ERROR when
	// the bake and the constant disagree (the GDScript's own message).
	double bake_radius() {
		const double known = script->get(k._bake_radius);
		if (known >= 0.0) {
			return known;
		}
		double found = -1.0;
		if (tank->is_inside_tree()) {
			const RID my_map = tank->get_world_3d()->get_navigation_map();
			const TypedArray<Node> regions = tank->get_tree()->get_root()->find_children("*", "NavigationRegion3D", true, false);
			for (int64_t i = 0; i < regions.size(); i++) {
				NavigationRegion3D *region = Object::cast_to<NavigationRegion3D>(regions[i].get_validated_object());
				if (region == nullptr || region->get_navigation_mesh().is_null()) {
					continue;
				}
				if (my_map.is_valid() && region->get_navigation_map() != my_map) {
					continue;
				}
				found = region->get_navigation_mesh()->get_agent_radius();
				break;
			}
		}
		if (found < 0.0) {
			return c.NAV_AGENT_RADIUS;
		}
		if (std::fabs(found - c.NAV_AGENT_RADIUS) > 0.001) {
			UtilityFunctions::push_error(vformat("the navmesh bakes at agent_radius %.2f but movement.gd expects %.2f. Routing uses the BAKED value; update NAV_AGENT_RADIUS so the cross-check means something again.",
					found, c.NAV_AGENT_RADIUS));
		}
		script->set(k._bake_radius, found);
		return found;
	}

	// ---- Movement._repair(goal) (round 28, N5), line by line; repair_on() is true in the native drive's configuration ----
	//   if _repair_for != INF: return false
	//   _repair_for = goal; _repair_to = INF; fixed := SlotGround.for_unit(tank, goal, tank.unit_id)
	//   moved := _flat_distance(fixed, goal); if moved < 0.5 or moved > REPAIR_MAX_M: goal_repairs_refused += 1; false
	//   route := Pathing.query(tank, tank.global_position, fixed)
	//   if not ready or not reachable or goal_gap_m > NO_PATH_MARGIN: goal_repairs_refused += 1; false
	//   _repair_to = fixed; _repath_left = 0.0; goal_repairs += 1; true
	bool repair(const Vector3 &goal) {
		if (v._repair_for() != V3_INF) {
			return false;
		}
		v.set__repair_for(goal);
		v.set__repair_to(V3_INF);
		const Vector3 fixed = gd(c.slot_ground, k.for_unit, tank, goal, String(tank->get(k.unit_id)));
		const double moved = flat_distance(fixed, goal);
		if (moved < 0.5 || moved > c.REPAIR_MAX_M) {
			sadd(k.goal_repairs_refused, 1);
			return false;
		}
		const Dictionary route = path_query(here, fixed);
		if (!(bool)route[k.ready] || !(bool)route[k.reachable] || (double)route[k.goal_gap_m] > c.NO_PATH_MARGIN) {
			sadd(k.goal_repairs_refused, 1);
			return false;
		}
		v.set__repair_to(fixed);
		v.set__repath_left(0.0);
		sadd(k.goal_repairs, 1);
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
		if (flat_distance(goal, v._progress_goal()) > 2.0 || drive_vector == Vector2() || holding()) {
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
			if (cb_on && c.repair_ready ? repair(goal) : (bool)cb(k._repair, goal)) {
				return;
			}
			v.set_phase(blocked);
			v.set_blocked_by(no_path);
			return;
		}
		if ((int64_t)v.stalled_ticks() >= (int64_t)(c.BLOCKED_SECONDS * (double)c.TICK_RATE) && !holding()) {
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

	// ---- Round 33 (N5.M): `_manoeuvre`'s decision and Manoeuvre's choose / behind / simulate, line by line ----
	struct Sim {
		bool arrived = false, clear = true;
		double seconds = 0.0, metres = 0.0;
		int64_t legs = 0;
		String blocked;
	};
	struct Other {
		double x, z, reach;
		bool friendly;
	};
	bool manoeuvre_native_on();
	void manoeuvre_decide(const Dictionary &order, const Vector3 &goal, int64_t tick, bool gap);
	String man_choose(const Vector3 &goal, const Dictionary &order, double arrive);
	bool man_behind(const Vector3 &goal, double radius);
	Sim man_simulate(const Vector3 &goal, double arrive, int gear);
	LocalVector<Other> man_others();
	Dictionary man_state_of();
	void man_note(const StringName &table, const String &key);
	double hull_width_of(const String &unit);
	double settle_of(const String &unit);
	// ---- Round 33 (N5.Y): _negotiate's body, ask, _begin_yield and the give-way's spot tests, line by line ----
	bool yield_native_on();
	void negotiate_body(const Vector3 &goal, bool direct, Node3D *other, Object *mover);
	bool ask(const String &asker, const Vector3 &from, const Vector2 &direction, const String &via);
	bool begin_yield(const String &other, const Vector3 &from, const Vector2 &direction, const String &via);
	void start_yield(const String &other, const Vector3 &point, const Vector2 &along, const String &spot);
	bool free_spot(const Vector3 &point, const String &me, const String &other);
	bool yield_fits(const Vector3 &point);
	bool yield_run_ok(const RID &map, const Vector3 &point, LocalVector<Vector3> &poses);
	Vector3 yield_shorten(const Vector3 &point);
	Vector2 travel_direction(const Vector3 &goal, bool direct);
	// ---- Round 35 (traffic T7, C35.8): the pass ----
	double pass_lane(const String &passer, const Vector3 &from, const Vector2 &direction);
	bool pass_start(const String &refuser, double side, const Vector2 &way);
	void pass_end(bool timed_out = false);
	Vector3 pass_point();
	bool on_fire_post();
	bool traffic_off(const String &name);
	double avoid_radius(const String &unit);
	void refresh_avoidance();
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
		if (!manoeuvre_native_on()) {
			manoeuvre_counts_.called_back++;
			return cb(k._manoeuvre, order); // nothing written above: the GDScript decides from the same state
		}
		manoeuvre_counts_.native++;
		manoeuvre_decide(order, goal, tick, gap); // writes _behind_tick with the rest
	} else {
		v.set__behind_tick(tick);
	}
	if (String(v._behind_plan()) != r_reverse_plan) {
		return order;
	}
	Dictionary reversed = order.duplicate();
	reversed[k.reverse] = true;
	reversed.erase(k.facing);
	return reversed;
}

// Round 33 (N5.Y): _negotiate's body natively while BrainSwitches.native_yield and native_cb are on, the arms the port
// mirrors are the ones in force (yield_clear's turning-room probe is not ported: opt-in, called back), the measurement
// logs are off (yield_log, setup_log: rows the GDScript writes), and the sweep asks the same geometry (native_nav: N2a's
// closest points; kturn_cap: the outline rule).
template <class V>
bool Drive<V>::yield_native_on() {
	return c.yield_port_ready && cb_on && !c.yield_clear && c.traffic_script != nullptr &&
			(bool)c.switches->get(k.native_yield) && (bool)c.switches->get(k.native_nav) &&
			(bool)c.switches->get(k.kturn_cap) && !(bool)sget(k.yield_log) && !(bool)sget(k.setup_log);
}

// Traffic.off(name): asked live, as the GDScript does (a static of traffic's: its command line, parsed once).
template <class V>
bool Drive<V>::traffic_off(const String &name) {
	return c.traffic_script->call(k.off, name);
}

// Avoidance.radius_of(unit): a pure function of the unit, memoised in DriveConfig (as _avoid's).
template <class V>
double Drive<V>::avoid_radius(const String &unit) {
	const double *known = c.radius_of.getptr(unit);
	if (known != nullptr) {
		return *known;
	}
	const double radius = c.avoidance_script->call(k.radius_of, unit);
	c.radius_of.insert(unit, radius);
	return radius;
}

// Avoidance.refresh(ctl.tanks_root): a no-op when this tick's table is built; otherwise the live GDScript builds it.
template <class V>
void Drive<V>::refresh_avoidance() {
	Object *tanks_root = ctl->get(k.tanks_root).get_validated_object();
	Object *av = c.avoidance_script;
	if ((int64_t)av->get(k._table_root) != (int64_t)tanks_root->get_instance_id() ||
			(int64_t)av->get(k._table_frame) != Engine_frames()) {
		gd(av, k.refresh, tanks_root);
	}
}

// Movement._negotiate below its early-outs (the caller's `negotiate`: the same reads, nothing written above):
//   my_way := _travel_direction(goal, direct); i_give_way := false
//   mover.is_under_way(): difference := _remaining - mover._remaining
//       i_give_way = difference < -PRIORITY_MARGIN or (|difference| <= PRIORITY_MARGIN and String(tank.name) < name)
//   mover._last_yielded_to == String(tank.name): i_give_way = true
//   not i_give_way and mover.ask(me, here, my_way): return
//   not mover.is_under_way() and not Traffic.off("parked"): parked_refusals += 1; return
//   _last_yielded_to == name: return
//   its_way := mover._travel_direction(mover._goal, false) if mover.is_under_way() else ZERO; ZERO: here - other
//   _begin_yield(name, other.global_position, its_way): return
//   i_give_way and yield_fit_on() and _yield_unfit_last and mover.ask(me, here, my_way, "swap"):
//       yield_swaps += 1; hull_box(other)[2] < hull_box(tank)[2]: yield_swaps_shorter += 1
// The asked mover is driven through its own view of its live members (another Drive over an ObjectView): `ask` marks it
// native_stale first, as the GDScript does, so its next owned drive pulls what was written.
template <class V>
void Drive<V>::negotiate_body(const Vector3 &goal, bool direct, Node3D *other, Object *mover) {
	static const String arrived("arrived"), asked("asked"), self("self"), swap("swap"), parked("parked");
	// The callback pushed this crew's state before the GDScript ran (Avoidance.refresh reads every mover's phase): so here.
	v.push_out();
	const String me = tank->get_name();
	const String name = other->get_name();
	Drive<ObjectView> them(c, mover, ObjectView(mover));
	them.cb_on = cb_on;
	if (!them.bind()) {
		return;
	}
	const Vector2 my_way = travel_direction(goal, direct);
	bool i_give_way = false;
	if (String(them.v.phase()) != arrived) {
		const double difference = (double)v._remaining() - (double)them.v._remaining();
		i_give_way = difference < -c.PRIORITY_MARGIN || (std::fabs(difference) <= c.PRIORITY_MARGIN && me < name);
	}
	if (String(them.v._last_yielded_to()) == me) {
		i_give_way = true;
	}
	if (!i_give_way && them.ask(me, here, my_way, asked)) {
		return;
	}
	// Round 35 (traffic T7): refused by a crew under fire that found me a way round: I pass it.
	if (!i_give_way && pass_start(name, (double)them.v.pass_offer(), my_way)) {
		return;
	}
	if (String(them.v.phase()) == arrived && !traffic_off(parked)) {
		sadd(k.parked_refusals, 1);
		return;
	}
	if (String(v._last_yielded_to()) == name) {
		return;
	}
	const Vector3 there = other->get_global_position();
	Vector2 its_way = String(them.v.phase()) != arrived ? them.travel_direction(them.v._goal(), false) : Vector2();
	if (its_way == Vector2()) {
		its_way = Vector2((real_t)((double)here.x - (double)there.x), (real_t)((double)here.z - (double)there.z));
	}
	if (begin_yield(name, there, its_way, self)) {
		return;
	}
	if (i_give_way && c.yield_fit && v._yield_unfit_last()) {
		if (them.ask(me, here, my_way, swap)) {
			sadd(k.yield_swaps, 1);
			if (hull_length(String(other->get(k.unit_id))) < hull_length(String(tank->get(k.unit_id)))) {
				sadd(k.yield_swaps_shorter, 1);
			}
		} else {
			pass_start(name, (double)them.v.pass_offer(), my_way); // T7: refused under fire with a lane: pass it
		}
	}
}

// ---- Round 35 (traffic T7, C35.8; `--traffic-on=underfire`): the pass ----
// Movement._pass_lane(passer, from, direction): the side (+1 / -1) of my hull the passer can drive past me on, else 0. A
// GDScript call: it reads the navmesh, the Avoidance table and the two hulls only (never this crew's members; `gd` pushes
// first anyway), and it runs only when a crew under fire is asked (T6: ~19 a fight). The sweep is NavNative::outline_ok's
// bits in the GDScript already; a C++ port of it waits for T7's verdict (a parked rule's mirror is dead weight, R34.20).
template <class V>
double Drive<V>::pass_lane(const String &passer, const Vector3 &from, const Vector2 &direction) {
	return (double)gd(m, k._pass_lane, passer, from, direction);
}

// Movement._pass_start(refuser, side, way)
template <class V>
bool Drive<V>::pass_start(const String &refuser, double side, const Vector2 &way) {
	if (side == 0.0 || (double)way.length_squared() < 0.0001 || refuser == String(v._pass_failed_by())) {
		return false;
	}
	if (String(v._pass_by()) == refuser) {
		return true;
	}
	v.set__pass_by(refuser);
	v.set__pass_side(side);
	v.set__pass_way(way.normalized());
	v.set__pass_left((int64_t)(c.PASS_MAX_S * (double)c.TICK_RATE));
	sadd(k.passes, 1);
	return true;
}

// Movement._pass_end(timed_out)
template <class V>
void Drive<V>::pass_end(bool timed_out) {
	if (timed_out) {
		sadd(k.passes_timeout, 1);
		v.set__pass_failed_by(String(v._pass_by()));
	}
	v.set__pass_by(String());
	v.set__pass_side(0.0);
}

// Movement._pass_point(): the pass's steering point (INF = none), line by line (Vector2 maths in real_t where the
// GDScript's Vector2 is; the sums in double, narrowed into the Vector3 as its constructor does).
template <class V>
Vector3 Drive<V>::pass_point() {
	const String by = v._pass_by();
	if (by.is_empty()) {
		return V3_INF;
	}
	Node *root = Object::cast_to<Node>(ctl->get(k.tanks_root).get_validated_object());
	Node3D *refuser = root != nullptr ? Object::cast_to<Node3D>(root->get_node_or_null(NodePath(by))) : nullptr;
	v.set__pass_left((int64_t)v._pass_left() - step);
	if (refuser == nullptr || !(bool)refuser->call(k.is_alive)) {
		pass_end();
		return V3_INF;
	}
	if ((int64_t)v._pass_left() <= 0) {
		pass_end(true);
		return V3_INF;
	}
	const Vector3 there = refuser->get_global_position();
	const String refuser_unit = refuser->get(k.unit_id);
	const double half = hull_length(refuser_unit) * 0.5;
	const Vector2 way = v._pass_way();
	const double along = Vector2((real_t)((double)here.x - (double)there.x), (real_t)((double)here.z - (double)there.z)).dot(way);
	if (along >= half) {
		sadd(k.passes_done, 1);
		v.set__pass_failed_by(String());
		pass_end();
		return V3_INF;
	}
	sadd(k.pass_ticks, step);
	const double reach = avoid_radius(refuser_unit) + avoid_radius(String(tank->get(k.unit_id))) + c.YIELD_LINE_MARGIN;
	const Vector2 across = Vector2(-way.y, way.x) * (real_t)(double)v._pass_side() * (real_t)reach;
	const double ahead = along < -half ? 0.0 : half + hull_length(String(tank->get(k.unit_id))) * 0.5 + c.PASS_BEYOND_M;
	return Vector3((real_t)((double)there.x + (double)across.x + (double)way.x * ahead), 0.0,
			(real_t)((double)there.z + (double)across.y + (double)way.y * ahead));
}

// Movement._travel_direction(goal, direct)
template <class V>
Vector2 Drive<V>::travel_direction(const Vector3 &goal, bool direct) {
	const PackedVector3Array path = v._path();
	const int64_t index = v._path_index();
	const Vector3 toward = index < path.size() && !direct ? path[index] : goal;
	if (toward == V3_INF) {
		return Vector2();
	}
	const Vector2 flat((real_t)((double)toward.x - (double)here.x), (real_t)((double)toward.z - (double)here.z));
	return (double)flat.length_squared() > 0.0001 ? flat.normalized() : Vector2();
}

// Movement.on_fire_post(): deploy_ratio > 0, a weapon order that is not hold_fire, no move of its own under way, and (round
// 33 overnight, traffic item 4) a fire mission unless `--traffic-off=firemission`.
template <class V>
bool Drive<V>::on_fire_post() {
	static const String type("type"), hold_fire("hold_fire"), move_to("move_to"), arrived("arrived");
	if (!((double)tank->get(k.deploy_ratio) > 0.0)) {
		return false;
	}
	const Dictionary weapon = ctl->get(k.weapon_order);
	if (String(weapon.get(type, String())) == hold_fire) {
		return false;
	}
	const Dictionary move = ctl->get(k.move_order);
	if (!(String(move.get(type, String())) != move_to || String(v.phase()) == arrived)) {
		return false;
	}
	// Round 33 overnight (traffic item 4, `firemission`): and a fire mission, unless the switch is off.
	//   and (Traffic.off("firemission") or fire_mission())
	//   fire_mission(): weapon_order type "target" or "suppress", or ctl.engaged_target != ""
	static const String firemission("firemission"), target("target"), suppress("suppress");
	if (traffic_off(firemission)) {
		return true;
	}
	const String kind = weapon.get(type, String());
	return kind == target || kind == suppress || !String(ctl->get(k.engaged_target)).is_empty();
}

// Movement.ask(asker, from, direction, via): native_stale |= STALE_ALL; already giving way, or the same asker as last
// time: false; set up on a fire post (not --traffic-off=setup): setup_refusals += 1, false; under fire (round 34, T6):
// underfire_refusals += 1, false; _begin_yield, else asks_refused += 1.
template <class V>
bool Drive<V>::ask(const String &asker, const Vector3 &from, const Vector2 &direction, const String &via) {
	static const String setup("setup");
	v.set_native_stale(v.native_stale() | 1); // Movement.STALE_ALL
	v.set_pass_offer(0.0); // round 35 (T7)
	if (!String(v.yield_to()).is_empty() || asker == String(v._last_yielded_to())) {
		return false;
	}
	if (on_fire_post() && !traffic_off(setup)) {
		sadd(k.setup_refusals, 1);
		return false;
	}
	// Round 35 (traffic T7, C35.8): a crew under fire holds its lane ONLY when the asker has a pass lane beside it (after
	// the set-up rule, which counts first); it hands the side back. No lane: the give-way proceeds. Never for "behind".
	static const String behind("behind");
	if (under_fire() && via != behind) {
		const double side = pass_lane(asker, from, direction);
		if (side != 0.0) {
			sadd(k.underfire_refusals, 1);
			v.set_pass_offer(side);
			return false;
		}
		sadd(k.underfire_gives, 1);
	}
	if (begin_yield(asker, from, direction, via)) {
		return true;
	}
	sadd(k.asks_refused, 1);
	return false;
}

namespace {
inline double distance_to_ray(const Vector3 &point, const Vector3 &origin, const Vector2 &direction) {
	// Movement._distance_to_ray: the offset narrowed, t = max(offset . direction, 0), |offset - direction * t|.
	const Vector2 offset((real_t)((double)point.x - (double)origin.x), (real_t)((double)point.z - (double)origin.z));
	const double t = MAX((double)offset.dot(direction), 0.0);
	return (offset - direction * (real_t)t).length();
}

inline String spot_label(const char *kind, int64_t a, int64_t b) {
	return String(kind) + "(" + String::num_int64(a) + "," + String::num_int64(b) + ")";
}
} // namespace

// Movement._begin_yield(other, from, direction, via), line by line (`_off.has("backup")` is never true here: the native
// drive runs only with no --nav-off).
template <class V>
bool Drive<V>::begin_yield(const String &other, const Vector3 &from, const Vector2 &direction, const String &via) {
	static const String hold("hold"), self_via("self");
	// Round 34 (traffic T6), T7's gate: under fire, no step aside of its own (the self-yield in _negotiate) when the other
	// can pass me; with no lane I step aside as today. A hold is not "no spot fits": no swap ask follows it.
	if (via == self_via && under_fire() && pass_lane(other, from, direction) != 0.0) {
		sadd(k.underfire_holds, 1);
		v.set__yield_unfit_last(false);
		return false;
	}
	Vector2 along;
	if ((double)direction.length_squared() > 0.0001) {
		along = direction.normalized();
	} else {
		along = Vector2((real_t)((double)here.x - (double)from.x), (real_t)((double)here.z - (double)from.z)).normalized();
	}
	if (along == Vector2()) {
		return false;
	}
	const Vector2 across(-along.y, along.x);
	v.set__yield_unfit_last(false);
	Vector3 short_best = V3_INF;
	Vector3 short_target = V3_INF;
	String short_label;
	const Vector2 from_me((real_t)((double)here.x - (double)from.x), (real_t)((double)here.z - (double)from.z));
	const double side = (double)across.dot(from_me) >= 0.0 ? 1.0 : -1.0;
	Node *root = Object::cast_to<Node>(ctl->get(k.tanks_root).get_validated_object());
	Node *other_tank = root != nullptr ? root->get_node_or_null(NodePath(other)) : nullptr;
	if (other_tank != nullptr && Object::cast_to<Object>(other_tank)->get(k.unit_id).get_type() != Variant::STRING) {
		other_tank = nullptr; // `as Tank`: not a hull
	}
	const double other_radius = other_tank != nullptr ? avoid_radius(String(other_tank->get(k.unit_id))) : 1.8;
	const double line_clear = avoid_radius(String(tank->get(k.unit_id))) + other_radius + c.YIELD_LINE_MARGIN;
	refresh_avoidance();
	(void)via; // the yield log's (measurement; off here)
	const String me = tank->get_name();
	const double from_here = flat_distance(here, from);
	for (int64_t s = 0; s < c.YIELD_SPOTS.size(); s++) {
		const Vector2 spot = c.YIELD_SPOTS[s];
		const double flips[2] = { side, -side };
		const int n_flips = (double)spot.y != 0.0 ? 2 : 1;
		for (int f = 0; f < n_flips; f++) {
			const double flip = flips[f];
			const Vector2 offset = along * spot.x + across * (real_t)((double)spot.y * flip);
			const Vector3 point((real_t)((double)here.x + (double)offset.x), 0, (real_t)((double)here.z + (double)offset.y));
			if ((double)spot.y != 0.0 && distance_to_ray(point, from, along) < line_clear) {
				continue;
			}
			if (flat_distance(point, from) < from_here) {
				continue;
			}
			if (wheel_radius() > 0.0 && !ahead_of_wheels(point, wheel_radius()) && !straight_behind(point)) {
				continue;
			}
			if (!free_spot(point, me, other)) {
				continue;
			}
			const String label = spot_label("spot", (int64_t)(double)spot.x, (int64_t)((double)spot.y * flip));
			if (!yield_fits(point)) {
				const Vector3 shorter = c.yield_short ? yield_shorten(point) : V3_INF;
				if (shorter != V3_INF && (short_best == V3_INF || flat_distance(shorter, here) > flat_distance(short_best, here)) &&
						((double)spot.y == 0.0 || distance_to_ray(shorter, from, along) >= line_clear) &&
						flat_distance(shorter, from) >= from_here && free_spot(shorter, me, other)) {
					short_best = shorter;
					short_target = point;
					short_label = String("short:") + label;
				}
				continue;
			}
			start_yield(other, point, along, label);
			return true;
		}
	}
	// Last resort: back straight up along my own hull, as long as that isn't toward the unit being let past.
	const Vector2 back = Vector2(basis_z.x, basis_z.z).normalized();
	for (int64_t i = 0; i < c.YIELD_BACK_UP.size(); i++) {
		const double distance = c.YIELD_BACK_UP[i];
		const Vector3 point((real_t)((double)here.x + (double)back.x * distance), 0,
				(real_t)((double)here.z + (double)back.y * distance));
		if (flat_distance(point, from) < from_here) {
			continue;
		}
		if (!free_spot(point, me, other)) {
			continue;
		}
		const String label = String("back(") + String::num_int64((int64_t)distance) + ")";
		if (yield_fits(point)) {
			start_yield(other, point, along, label);
			return true;
		}
		const Vector3 shorter = c.yield_short ? yield_shorten(point) : V3_INF;
		if (shorter != V3_INF && (short_best == V3_INF || flat_distance(shorter, here) > flat_distance(short_best, here)) &&
				flat_distance(shorter, from) >= from_here && free_spot(shorter, me, other)) {
			short_best = shorter;
			short_target = point;
			short_label = String("short:") + label;
		}
	}
	if (short_best != V3_INF) {
		sadd(k.yield_spots_shortened, 1);
		start_yield(other, short_target, along, short_label);
		v.set__yield_stop_m(flat_distance(short_best, here));
		return true;
	}
	if (v._yield_unfit_last() && c.yield_fit && c.yield_hold) {
		sadd(k.yield_holds, 1);
		start_yield(other, here, along, hold);
		return true;
	}
	return false;
}

// Movement._start_yield (yield_log off: the gate)
template <class V>
void Drive<V>::start_yield(const String &other, const Vector3 &point, const Vector2 &along, const String &spot) {
	static const String yielding("yielding");
	v.set_yield_to(other);
	v.set_yield_spot(spot);
	v.set__yield_point(point);
	v.set__yield_from(here);
	v.set__yield_stop_m(0.0);
	v.set__yield_dir(along);
	v.set__yield_left((int64_t)(c.YIELD_MAX_SECONDS * (double)c.TICK_RATE));
	v.set__yield_held(0);
	v.set_phase(yielding);
	v.set_blocked_by(other);
	sadd(k.yields_started, 1);
}

// Movement._free_spot(point, me, other) (yield_clear off: the gate)
template <class V>
bool Drive<V>::free_spot(const Vector3 &point, const String &me, const String &other) {
	if (pathing_ready()) {
		const Vector3 on_mesh = closest_point(tank->get_world_3d()->get_navigation_map(), point, k.yield_site);
		if (flat_distance(on_mesh, point) > c.YIELD_MESH_SLACK) {
			return false;
		}
	}
	const Array rows = gd(c.avoidance_script, k.neighbours, me, (double)point.x, (double)point.z);
	for (int64_t i = 0; i < rows.size(); i++) {
		const Array row = rows[i];
		if (String(row[1]) != other && std::sqrt((double)row[0]) < c.YIELD_SPOT_CLEARANCE) {
			return false;
		}
	}
	return true;
}

// Movement._yield_fits(point) (yield_log off: the gate)
template <class V>
bool Drive<V>::yield_fits(const Vector3 &point) {
	if (!c.yield_fit || !pathing_ready()) {
		return true;
	}
	LocalVector<Vector3> poses;
	if (yield_run_ok(tank->get_world_3d()->get_navigation_map(), point, poses)) {
		return true;
	}
	sadd(k.yield_spots_unfit, 1);
	v.set__yield_unfit_last(true);
	return false;
}

// Movement._yield_run_ok(map, point, poses): the drive right_of_way() makes to `point`, stepped, the whole outline swept
// at every pose (_outline_offs / _outline_ok: N2a's points, the kturn_cap rule, as N5.M's simulation).
template <class V>
bool Drive<V>::yield_run_ok(const RID &map, const Vector3 &point, LocalVector<Vector3> &poses) {
	const String unit = tank->get(k.unit_id);
	const double half_w = hull_width_of(unit) * 0.5;
	const double half_l = hull_length(unit) * 0.5;
	const double clear = bake_radius() - c.KTURN_MARGIN_M;
	Vector3 at(here.x, 0, here.z);
	Vector3 heading = Vector3(-basis_z.x, 0, -basis_z.z).normalized();
	const PackedFloat32Array start = c.nav->outline_offs(map, half_w, half_l, at, heading);
	const bool behind = straight_behind(point);
	const double radius = wheel_radius();
	const double reach = c.YIELD_REACHED * 0.5;
	const Vector3 target(point.x, 0, point.z);
	const int64_t steps = c.YIELD_FIT_MIN_STEPS + (int64_t)((double)at.distance_to(target) * (double)c.YIELD_FIT_STEPS_PER_M);
	double rolling = 0.0;
	for (int64_t i = 0; i < steps; i++) {
		if ((double)Vector2((real_t)((double)target.x - (double)at.x), (real_t)((double)target.z - (double)at.z)).length() <= reach) {
			return true;
		}
		Vector2 drive;
		if (radius > 0.0) {
			drive = wheels(c, at, heading, target, reach, radius, rolling, -1.0, behind ? -1.0 : 1.0);
		} else {
			drive = drive_toward(c, at, heading, target, reach, -1.0, behind);
		}
		if (drive == Vector2()) {
			return true;
		}
		const double gear = (double)drive.x > 0.0 ? 1.0 : ((double)drive.x < 0.0 ? -1.0 : 0.0);
		if (gear == 0.0) {
			const double turn_sign = (double)drive.y > 0.0 ? 1.0 : ((double)drive.y < 0.0 ? -1.0 : 0.0);
			heading = heading.rotated(Vector3(0, 1, 0), (real_t)(-turn_sign * deg_to_rad(c.YIELD_FIT_PIVOT_DEG)));
		} else {
			const double yaw = radius > 0.0 ? c.YIELD_FIT_STEP_M * (double)drive.y / radius
											: (double)drive.y * deg_to_rad(c.YIELD_FIT_PIVOT_DEG);
			heading = motion_turn_heading(heading, yaw);
			at += heading * (real_t)c.YIELD_FIT_STEP_M * (real_t)gear;
		}
		rolling = gear;
		if (!c.nav->outline_ok(map, half_w, half_l, clear, at, heading, start, Vector3(), Vector3())) {
			return false;
		}
		poses.push_back(at);
	}
	return false;
}

// Movement._yield_shorten(point)
template <class V>
Vector3 Drive<V>::yield_shorten(const Vector3 &point) {
	if (!pathing_ready()) {
		return V3_INF;
	}
	LocalVector<Vector3> poses;
	yield_run_ok(tank->get_world_3d()->get_navigation_map(), point, poses);
	if (poses.is_empty()) {
		return V3_INF;
	}
	const double furthest = flat_distance(poses[poses.size() - 1], here);
	for (int64_t i = (int64_t)poses.size() - 1; i >= 0; i--) {
		const Vector3 pose = poses[i];
		if (flat_distance(pose, here) <= furthest - c.YIELD_SHORT_MARGIN_M) {
			return flat_distance(pose, here) >= c.YIELD_SHORT_MIN_M ? pose : V3_INF;
		}
	}
	return V3_INF;
}

// Round 33 (N5.M): the decision natively while BrainSwitches.native_manoeuvre and native_cb are on and the GDScript arm
// would ask the same geometry: native_nav (its outline's closest points are N2a's index) and kturn_cap (the outline rule).
template <class V>
bool Drive<V>::manoeuvre_native_on() {
	return c.manoeuvre_ready && cb_on && (bool)c.switches->get(k.native_manoeuvre) && (bool)c.switches->get(k.native_nav) &&
			(bool)c.switches->get(k.kturn_cap);
}

// Movement._manoeuvre below the gate (its early-outs and goal are the gate's):
//   _behind_tick = tick
//   reaimed := not gap and _behind_goal != INF and tick - _behind_since < REAIM_TICKS
//   _behind_since = tick; _behind_goal = goal; behind_asked += 1
//   arrive := maxf(clampf(float(order.get("arrive", ARRIVE_RADIUS)), 0.5, 10.0), settle_radius(unit) if wheel_radius() > 0 else 0)
//   reaimed: _behind_plan = "route"; _note(refused, "reaimed")
//   else: _behind_plan = Manoeuvre.choose(...) if Pathing.enabled and Pathing.is_ready(tank) else "route"
//   has_facing := facing is Array and size >= 2 and Vector2(f0, f1).length_squared() > 1e-6
//   _kept_goal = goal if not reaimed and not has_facing and Manoeuvre.behind(tank, goal, wheel_radius()) else INF
//   _kept_from = tank.global_position; _note(plans, _behind_plan); reverse: behind_reverses += 1
template <class V>
void Drive<V>::manoeuvre_decide(const Dictionary &order, const Vector3 &goal, int64_t tick, bool gap) {
	static const String route("route"), reverse_plan("reverse"), reaimed_key("reaimed");
	v.set__behind_tick(tick);
	const bool reaimed = !gap && (Vector3)v._behind_goal() != V3_INF && tick - (int64_t)v._behind_since() < c.REAIM_TICKS;
	v.set__behind_since(tick);
	v.set__behind_goal(goal);
	sadd(k.behind_asked, 1);
	const double radius = wheel_radius();
	const double settle = radius > 0.0 ? settle_of(tank->get(k.unit_id)) : 0.0;
	const double arrive = MAX(clampd((double)order.get(k.arrive, c.ARRIVE_RADIUS), 0.5, 10.0), settle);
	String plan;
	if (reaimed) {
		plan = route;
		man_note(k.refused, reaimed_key);
	} else {
		plan = pathing_ready() ? man_choose(goal, order, arrive) : route;
	}
	v.set__behind_plan(plan);
	const Variant drawn = order.get(k.facing, Variant());
	bool has_facing = false;
	if (drawn.get_type() == Variant::ARRAY) {
		const Array a = drawn;
		has_facing = a.size() >= 2 && (double)Vector2((real_t)(double)a[0], (real_t)(double)a[1]).length_squared() > 1e-6;
	}
	v.set__kept_goal(!reaimed && !has_facing && man_behind(goal, wheel_radius()) ? goal : V3_INF);
	v.set__kept_from(here);
	man_note(k.plans, plan);
	if (plan == reverse_plan) {
		sadd(k.behind_reverses, 1);
	}
}

// Manoeuvre.choose(mover, goal, order, arrive)
template <class V>
String Drive<V>::man_choose(const Vector3 &goal, const Dictionary &order, double arrive) {
	static const String route("route"), reverse_plan("reverse"), facing_nose("facing_nose"), no_arrival("no_arrival"),
			route_faster("route_faster");
	const double radius = wheel_radius();
	if (!man_behind(goal, radius)) {
		return route;
	}
	const Vector2 nose = Vector2(-basis_z.x, -basis_z.z).normalized();
	bool want_tail = false;
	bool want_nose = false;
	const Variant facing = order.get(k.facing, Variant());
	if (facing.get_type() == Variant::ARRAY) {
		const Array a = facing;
		if (a.size() >= 2) {
			const Vector2 f((real_t)(double)a[0], (real_t)(double)a[1]);
			if ((double)f.length_squared() > 1e-6) {
				want_tail = std::fabs((double)nose.angle_to(f)) <= deg_to_rad(c.MAN_FACING_KEEP_DEG);
				want_nose = !want_tail;
			}
		}
	}
	if (want_nose) {
		man_note(k.refused, facing_nose);
		return route;
	}
	const Sim reverse = man_simulate(goal, arrive, -1);
	if (!reverse.clear) {
		man_note(k.refused, reverse.blocked);
		return route;
	}
	if (!reverse.arrived) {
		man_note(k.refused, no_arrival);
		return route;
	}
	if (want_tail) {
		return reverse_plan;
	}
	const Sim forward = man_simulate(goal, arrive, 1);
	if (forward.arrived && forward.seconds <= reverse.seconds) {
		man_note(k.refused, route_faster);
		return route;
	}
	return reverse_plan;
}

// Manoeuvre.behind(tank, goal, radius)
template <class V>
bool Drive<V>::man_behind(const Vector3 &goal, double radius) {
	const Vector2 to((real_t)((double)goal.x - (double)here.x), (real_t)((double)goal.z - (double)here.z));
	const double d = to.length();
	if (d > c.MAN_MAX_M || d < 0.5) {
		return false;
	}
	const Vector2 nose = Vector2(-basis_z.x, -basis_z.z).normalized();
	if (std::fabs((double)nose.angle_to(to)) >= deg_to_rad(c.MAN_BEHIND_DEG)) {
		return true;
	}
	if (radius > 0.0) {
		// Inside the forward turning circle on the goal's side: no forward arc reaches it.
		const Vector2 left(nose.y, -nose.x);
		const double side = (double)nose.angle_to(to) <= 0.0 ? 1.0 : -1.0;
		const Vector2 centre = Vector2(here.x, here.z) - left * (real_t)side * (real_t)radius;
		return (double)centre.distance_to(Vector2(goal.x, goal.z)) < radius;
	}
	return false;
}

// Manoeuvre.simulate(mover, goal, arrive, gear): the plant (TankMotion.step_in_place = motion_step, N6.1's same bits)
// driven by the steering law that will drive it, every CHECK_EVERY steps the outline (Movement._outline_ok, kturn_cap,
// a start pose: NavNative::outline_ok, N2b's same bits) and the hull discs (_hull_hit).
template <class V>
typename Drive<V>::Sim Drive<V>::man_simulate(const Vector3 &goal, double arrive, int gear) {
	static const String static_kind("static"), friendly("friendly"), enemy("enemy");
	const double radius = wheel_radius();
	Dictionary state = man_state_of();
	const RID map = tank->get_world_3d()->get_navigation_map();
	// _kturn_frame(tank): [hull_box[0] * 0.5, hull_box[2] * 0.5, bake_radius(tank) - KTURN_MARGIN_M]
	const String unit = tank->get(k.unit_id);
	const double half_w = hull_width_of(unit) * 0.5;
	const double half_l = hull_length(unit) * 0.5;
	const double clear = bake_radius() - c.KTURN_MARGIN_M;
	const PackedFloat32Array start = c.nav->outline_offs(map, half_w, half_l, here, (Vector3)state[k.forward]);
	const LocalVector<Other> others = man_others();
	double t = 0.0;
	int64_t legs = 0;
	int64_t last_gear = 0;
	double metres = 0.0;
	int64_t steps = 0;
	Sim out;
	out.seconds = c.MAN_SIM_HORIZON_S;
	while (t < c.MAN_SIM_HORIZON_S) {
		const Vector3 at = state[k.position];
		const Vector3 forward = state[k.forward];
		const double speed = state[k.speed];
		const double remaining = Vector2((real_t)((double)goal.x - (double)at.x), (real_t)((double)goal.z - (double)at.z)).length();
		Vector2 drive;
		if (radius > 0.0) {
			drive = wheels(c, at, forward, goal, arrive, radius, speed, remaining, gear > 0 ? 1.0 : -1.0);
		} else {
			drive = drive_toward(c, at, forward, goal, arrive, remaining, gear < 0);
		}
		if (drive == Vector2()) {
			out.arrived = true;
			// The hull still has to stop: count the braking from here (v / braking), as the order completes at rest.
			t += std::fabs(speed) / MAX((double)state[k.braking_mps2], 0.1);
			break;
		}
		motion_step(*c.motion, state, (double)drive.x, (double)drive.y, c.MAN_SIM_DT);
		t += c.MAN_SIM_DT;
		steps += 1;
		const Vector3 moved = state[k.position];
		metres += (double)Vector2((real_t)((double)moved.x - (double)at.x), (real_t)((double)moved.z - (double)at.z)).length();
		const double now = state[k.speed];
		const int64_t g = std::fabs(now) <= c.CUSP_DEADBAND ? 0 : (now > 0.0 ? 1 : -1);
		if (g != 0 && g != last_gear) {
			legs += 1;
			last_gear = g;
		}
		if (steps % c.MAN_CHECK_EVERY == 0) {
			if (!c.nav->outline_ok(map, half_w, half_l, clear, moved, (Vector3)state[k.forward], start, Vector3(), Vector3())) {
				out.clear = false;
				out.blocked = static_kind;
				break;
			}
			// _hull_hit(moved, frame, others, tank.global_position): a disc of half the hull's length beyond the reach,
			// and only nearer than the start was.
			bool hit = false;
			for (const Other &row : others) {
				const double d = Vector2((real_t)(row.x - (double)moved.x), (real_t)(row.z - (double)moved.z)).length();
				if (d < row.reach + half_l * 0.5) {
					const double d0 = Vector2((real_t)(row.x - (double)here.x), (real_t)(row.z - (double)here.z)).length();
					if (d < d0 - 0.25) {
						out.clear = false;
						out.blocked = row.friendly ? friendly : enemy;
						hit = true;
						break;
					}
				}
			}
			if (hit) {
				break;
			}
		}
	}
	out.seconds = t;
	out.legs = legs;
	out.metres = metres;
	return out;
}

// Manoeuvre._others(mover): every other living hull as [x, z, (mine[0] + theirs[0]) * 0.5 + HULL_MARGIN_M, kind]
template <class V>
LocalVector<typename Drive<V>::Other> Drive<V>::man_others() {
	LocalVector<Other> out;
	Node *tanks_root = Object::cast_to<Node>(ctl->get(k.tanks_root).get_validated_object());
	if (tanks_root == nullptr) {
		return out;
	}
	const double mine = hull_width_of(tank->get(k.unit_id));
	const int64_t my_team = tank->get(k.team);
	const int count = tanks_root->get_child_count();
	for (int i = 0; i < count; i++) {
		Node3D *other = Object::cast_to<Node3D>(tanks_root->get_child(i));
		if (other == nullptr || other == tank) {
			continue;
		}
		const Variant alive = other->get(k.alive);
		if (alive.get_type() != Variant::BOOL || !(bool)alive) {
			continue; // not a Tank (no `alive`), or a dead one
		}
		const double theirs = hull_width_of(other->get(k.unit_id));
		const Vector3 at = other->get_global_position();
		out.push_back(Other{ (double)at.x, (double)at.z, (mine + theirs) * 0.5 + c.MAN_HULL_MARGIN_M,
				(int64_t)other->get(k.team) == my_team });
	}
	return out;
}

// TankMotion.state_of(tank): state_for(unit, position, -basis.z, tank.speed()) with the live tank's speeds, turn rate,
// estimated velocity and yaw rate. state_for's Units.stat answers are a pure function of the unit (memoized).
template <class V>
Dictionary Drive<V>::man_state_of() {
	static const String tracks("tracks");
	const String unit = tank->get(k.unit_id);
	const Dictionary *known = c.state_stats_of.getptr(unit);
	Dictionary stats;
	if (known != nullptr) {
		stats = *known;
	} else {
		stats[k.locomotion] = String(c.units->call(k.stat, unit, k.locomotion, tracks));
		stats[k.acceleration_mps2] = (double)c.units->call(k.stat, unit, k.acceleration_mps2, 14.0);
		stats[k.braking_mps2] = (double)c.units->call(k.stat, unit, k.braking_mps2, 14.0);
		stats[k.min_turn_radius_m] = (double)c.units->call(k.stat, unit, k.min_turn_radius_m, 0.0);
		stats[k.lateral_grip] = (double)c.units->call(k.stat, unit, k.lateral_grip, 1.0);
		c.state_stats_of.insert(unit, stats);
	}
	const Vector3 back = -basis_z;
	const Vector3 flat = Vector3(back.x, 0, back.z).normalized();
	Dictionary state;
	state[k.position] = here;
	state[k.forward] = flat;
	state[k.speed] = (double)tank->get(k._speed);
	state[k.velocity] = tank->get(k.estimated_velocity);
	state[k.locomotion] = stats[k.locomotion];
	state[k.max_forward_speed] = (double)tank->get(k.max_forward_speed);
	state[k.max_reverse_speed] = (double)tank->get(k.max_reverse_speed);
	state[k.hull_turn_rate_deg] = rad_to_deg((double)tank->get(k.hull_turn_rate));
	state[k.acceleration_mps2] = stats[k.acceleration_mps2];
	state[k.braking_mps2] = stats[k.braking_mps2];
	state[k.min_turn_radius_m] = stats[k.min_turn_radius_m];
	state[k.lateral_grip] = stats[k.lateral_grip];
	const Variant live = tank->get(k._motion);
	if (live.get_type() == Variant::DICTIONARY) {
		state[k.yaw_rate] = (double)((Dictionary)live).get(k.yaw_rate, 0.0);
	}
	return state;
}

// Manoeuvre._note(table, key): table[key] = int(table.get(key, 0)) + 1, on Manoeuvre's static Dictionary in place.
template <class V>
void Drive<V>::man_note(const StringName &table, const String &key) {
	Dictionary d = c.manoeuvre_script->get(table);
	d[key] = (int64_t)d.get(key, 0) + 1;
}

// Movement.hull_box(unit)[0], memoized by unit (a pure function of the roster).
template <class V>
double Drive<V>::hull_width_of(const String &unit) {
	const double *known = c.hull_width_of.getptr(unit);
	if (known != nullptr) {
		return *known;
	}
	const Array size = script->call(k.hull_box, unit);
	const double width = size[0];
	c.hull_width_of.insert(unit, width);
	return width;
}

// Movement.settle_radius(unit), memoized by unit (a pure function of the roster).
template <class V>
double Drive<V>::settle_of(const String &unit) {
	const double *known = c.settle_of.getptr(unit);
	if (known != nullptr) {
		return *known;
	}
	const double settle = script->call(k.settle_radius, unit);
	c.settle_of.insert(unit, settle);
	return settle;
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
	// v4 (brains B5c-v4): `_gate_answer = "aimed"` then the gate's refusal reason, if any (Movement's static, which
	// only --gate-trace reads; the trace itself is the GDScript drive's).
	static const String aimed("aimed");
	gate_answer = aimed;
	if (radius > 0.0 && order.has(k.facing)) {
		Timed t("~approach_gate");
		aim = approach_gate(goal, order, radius);
	}
	sset(k._gate_answer, gate_answer);
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
				if (seam_live()) {
					// Round 31 (planner CP-P1): PlannerSeam.hold() opens _planned_reverse for a crew the seam holds.
					Timed t("planned_reverse");
					planned = cb(k._planned_reverse, leg_ref, waypoint, delta);
				} else if ((double)v._kturn_left_m() > 0.0) {
					Vector2 leg_vector;
					Timed t("~kturn_leg");
					if (kturn_leg(delta, leg_vector)) {
						planned = true;
						leg->set(k.throttle, (double)leg_vector.x);
						leg->set(k.turn, (double)leg_vector.y);
					}
				} else if (holding()) {
					// round 29 (traffic T1, C29.3): no k-turn while waiting at a mouth (before `_kturn_check -= ctl._step`)
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
				// Movement._kturn_end("cancelled"): its looks cleared; the rest writes the diagnosis record, empty in the
				// native drive's configuration (no kturn_log / reverse_log) (round 28, N5).
				if (cb_on) {
					kturn_end();
				} else {
					cb(k._kturn_end, cancelled);
				}
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

int right_of_way_with(const DriveConfig &config, Object *mover, Object *cmd, ExecState *state) {
	if (!config.ready || !config.yield_ready || mover == nullptr || cmd == nullptr) {
		return -1;
	}
	if (state == nullptr) {
		Drive<ObjectView> d(config, mover, ObjectView(mover));
		return d.bind() ? d.right_of_way(cmd) : -1;
	}
	Drive<StructView> d(config, mover, StructView(mover, state));
	return d.bind() ? d.right_of_way(cmd) : -1;
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
	out["manoeuvre_native"] = manoeuvre_counts_.native;
	out["manoeuvre_called_back"] = manoeuvre_counts_.called_back;
	out["negotiate_native"] = negotiate_counts_.native;
	out["negotiate_called_back"] = negotiate_counts_.called_back;
	if (reset) {
		owned_counts_ = OwnedCounts();
		manoeuvre_counts_ = ManoeuvreCounts();
		negotiate_counts_ = NegotiateCounts();
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
