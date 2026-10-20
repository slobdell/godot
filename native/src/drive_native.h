// Round 24 (native, N3c): Movement.drive (game/ai/movement.gd) as ONE native call per tank per tick.
//
// The GDScript Movement keeps owning the mover's state: this code reads and writes its members in place (a member read
// from C++ costs 0.03 usec, native-bench at c8da555e), so everything else that touches a mover keeps working, and any
// branch not ported here is a CALLBACK into the live GDScript method with the state already where that method reads
// it. What is ported is a line-by-line port with the GDScript's widths (_agents/native.md, hazard 1), proven against
// the live drive from the same state (tests/test_native_drive.gd: the command, every member, every static).
//
// It runs only in the default configuration: no `--nav-off=` switch (Movement._off empty) and no diagnosis log
// (reverse_log), which the seam checks (NativeDrive.usable); every opt-in branch of drive then folds to a constant.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class NavNative;
struct AvoidanceTable;

struct DriveConfig {
	bool ready = false;
	// movement.gd constants (read from the live script by NativeDrive.configure, so an edit there is followed).
	double NEW_GOAL_JUMP, WAYPOINT_MIN_M, GIVE_WAY_PACE, STATION_RANGE, STATION_MIN_SPEED, ASK_SECONDS, ASK_EVERY_SECONDS,
			AVOID_ASK_PACE, BLOCKED_SECONDS, UNREACHABLE_AT_END, OFF_PATH_REPATH, REPATH_SECONDS, NO_PATH_MARGIN,
			STATION_STALE_SECONDS, STATION_STOPPED_SECONDS, WEDGED_SHARE, PATH_LOOKAHEAD, WHEELS_LOOKAHEAD_RADII,
			CARROT_ALIGNED_COS, WHEELS_LOOKAHEAD_MAX_RADII, CARROT_PULLBACK_0, CARROT_PULLBACK_1;
	int64_t GIVE_WAY_AFTER_TICKS, GIVE_WAY_TICKS, AVOID_GRACE_TICKS, WEDGED_WINDOW, TICK_RATE, FIRE_CHECK_TICKS;
	double AVOID_STEER_MIN, AVOID_STEER_MAX, AVOID_MESH_PROBE, AVOID_MESH_SLACK, AVOID_MIN_PACE;
	double ARRIVE_RADIUS; // OrderController
	// steering.gd
	double FULL_TURN_ERROR_DEG, TURN_IN_PLACE_DEG, SLOW_RADIUS, WHEELS_CIRCLE_MARGIN, WHEELS_FULL_LOCK_DEG,
			WHEELS_REVERSE_THROTTLE, WHEELS_MIN_THROTTLE;
	// The scripts whose statics are called (Pathing.enabled / is_ready / query, BrainLevers.chord_samples), the
	// TankCommand script (a k-turn's leg), and the navmesh index the chords are asked of.
	Object *pathing = nullptr;
	Object *levers = nullptr;
	Object *avoidance_script = nullptr; // Avoidance (its statics: the table's frame, the counters; refresh, solve)
	Object *switches = nullptr; // BrainSwitches (native_avoid, native_nav: the A/B flips them between ticks)
	const struct AvoidanceTable *avoidance = nullptr; // N1's native table (TankNative's)
	mutable HashMap<String, double> radius_of; // Avoidance.radius_of, a pure function of the unit
	mutable HashMap<String, double> settle_of; // Movement.settle_radius(unit), pure (Units' table)
	mutable HashMap<String, double> hull_length_of; // Movement.hull_box(unit)[2], pure (Units' table)
	mutable HashMap<String, double> hull_width_of; // Movement.hull_box(unit)[0]
	// BrainLevers.chord_samples / orca_neighbours per team, for one physics frame (they read the team's brain variant,
	// which nothing changes inside a tick); used only while BrainLevers.split is off (then they do not read the unit).
	mutable int64_t levers_frame = -1;
	mutable int64_t chord_samples_of[2] = { 0, 0 }, orca_of[2] = { 0, 0 }, kturn_check_of[2] = { 0, 0 };
	mutable bool chord_samples_known[2] = { false, false }, orca_known[2] = { false, false },
				 kturn_check_known[2] = { false, false };
	double CHORD_SLACK, CHORD_MARGIN;
	double APPROACH_RADII, APPROACH_MIN, APPROACH_MAX, APPROACH_ALIGNED_COS, MESH_GATE_SLACK, GATE_REACHED;
	double OFF_MESH_PROBES[3];
	double KTURN_THROTTLE, KTURN_SECONDS_PER_M, KTURN_INTO_WALL_COS, KTURN_ROLLING_SPEED, KTURN_BRAKE_HULL_M;
	int64_t KTURN_RETRY_TICKS;
	// Round 26 (perf, C26.2, manoeuvre M1): Movement._manoeuvre's per-tick gate natively; the decision (a new goal or a
	// gap in the drive ticks) is called back. BEHIND_GAP_TICKS < 0: this movement.gd has no _manoeuvre (no gate).
	int64_t BEHIND_GAP_TICKS = -1;
	mutable HashMap<String, double> braking_of; // Movement._braking() by unit: max(Units.stat(unit, "braking_mps2", 8), 0.1)
	// Round 29 (traffic T1, C29.2): the street hold. traffic_hold is false on a tree without it (Traffic has no hold_of):
	// then no gate and no callback, the drive as before. With it, _avoid's first lines call NativeTraffic.avoid_hold back
	// (Traffic.refresh + Traffic.hold_of: the table work stays traffic's GDScript) and the C29.3 gates read
	// Traffic.holding natively from its `_live` table.
	bool traffic_hold = false;
	// Round 29 (brains B5c, C29.2): Movement.gate_giveup_on() (ON by default since brains' flip; the native drive runs only
	// with no --nav-off, so the configure-time value is the one in force). False on a tree without it.
	bool gate_giveup = false;
	// Round 32 (brains B5c-v6): Movement.gate_side_on(), the planner's side gate for a goal first seen facing away.
	bool gate_side = false;
	// Round 33 (brains B5c-v6, R33.8): Movement.gate_inside_on(), a gate inside the hull's turning circle is latched.
	bool gate_inside = false;
	int64_t GATE_ROOM_POINTS = 8;
	// Round 30 (brains B5c-v4): the bounded come-round, the near rule, the turn-room ring.
	double GATE_TURN_SECONDS = 12.0, GATE_NEAR_DETOUR = 2.0;
	int64_t TURN_ROOM_POINTS = 12;
	// Round 31 (traffic T3b, C31.2): the crossing. traffic_shape is false on a tree without Traffic.shape; with it, _avoid
	// calls NativeTraffic.avoid_shape back once the route's wish is known (the verdicts stay traffic's GDScript).
	bool traffic_shape = false;
	// Round 31 (manoeuvre CP-H, C31.4): the consumers' defaults (each switch's ON = its DEFAULT, since the native drive
	// runs only with `Movement._off` empty). H1 `unstickback`: the honest stall reading and the escape (its event bodies
	// _escape_begin / _escape_step called back); H2 `kturnarc`: the leg measured by the arc signed by gear. Absent on a
	// tree without them: false, the drive as before.
	bool UNSTICK_BACK = false, KTURN_ARC = false;
	// Round 33 (manoeuvre C33.9): Manoeuvre.TURN_IN_DEFAULT (the native drive runs only with `Movement._off` empty, so the
	// default is the switch in force). With it, a `stop` on a fixed gun on wheels is handed back to the GDScript, whose
	// OrderController._stop_turn_in turns gunnery's swing in. False on a tree without it.
	bool TURN_IN = false;
	double UNSTICK_BLIND_MAX_LEN_M = 10.0;
	// Round 34 (traffic T6): Movement.UNDER_FIRE_S in ticks; -1 while the GDScript has no T6 (the switch is then off).
	int64_t UNDER_FIRE_TICKS = -1;
	double PASS_MAX_S = 6.0, PASS_BEYOND_M = 2.0, PASS_STEP_M = 2.0; // round 35 (traffic T7): Movement.PASS_*
	Ref<Script> tank_script; // Tank: `collider as Tank`
	// Round 31 (planner CP-P1, R31.2): the lattice planner's seam ON (PlannerSeam.PLANNER_DEFAULT; the native drive runs
	// only with `Movement._off` empty). A crew the seam holds (PlannerSeam._crews has it) always takes the
	// _planned_reverse callback, and the native unstick returns for it. False on a tree without the seam.
	bool planner_on = false;
	Object *planner_seam = nullptr;
	Variant keep_planner_seam;
	double HOLD_REACHED_M = 2.5, HOLD_SLOW_M = 16.0;
	int64_t LIVE_TICKS = 3;
	Object *traffic_script = nullptr, *native_traffic = nullptr;
	Variant keep_traffic, keep_native_traffic;
	Object *tank_command = nullptr;
	NavNative *nav = nullptr;
	Variant keep_pathing, keep_levers, keep_tank_command, keep_nav, keep_avoidance, keep_switches; // hold the references
	// N4: Movement._around_fire natively (BrainSwitches.native_fire): its constants, Match's and ThreatField's, and the
	// scripts it reads (Match: `fields is Match`; SuppressionFeed: source() and the non-Match answers; OrderController:
	// its counters; BrainVariants: avoid_beaten). fire_ready is false when any is missing: the callback runs then.
	bool fire_ready = false;
	double FIRE_LOOKAHEAD, FIRE_DETOUR_MARGIN, FIRE_DETOUR_REACHED, FIRE_KEEP_SHARE, BEATEN_ZONE_DENSITY, DRIVABLE_LIMIT,
			MARCH_FRACTION;
	double FIRE_DETOUR_STEPS[3];
	int64_t FIRE_DETOUR_TICKS, FIRE_AVOID_MAX, FIRE_DETOUR_COOLDOWN, FIRE_LEG_MIN_TICKS;
	Object *match_script = nullptr, *suppression_feed = nullptr, *order_controller = nullptr, *brain_variants = nullptr;
	Variant keep_match_script, keep_suppression_feed, keep_order_controller, keep_brain_variants;
	bool profile = false; // drive_profile's clocks run only when asked (--native-drive-profile)
	// Round 27 (stage 1 E2): Movement._keep_station natively (Pid.step_with_rate on the mover's station PID, read and
	// written in place); station_ready false (a missing script or constant) keeps the callback.
	bool station_ready = false;
	double STATION_LEAD_SECONDS = 0.0;
	Object *units = nullptr, *pid_script = nullptr, *control_gains = nullptr;
	Variant keep_units, keep_pid_script, keep_control_gains;
	mutable HashMap<String, String> faction_of; // String(Units.stat(unit, "faction", "")), pure
	// Round 27 (E2): Movement._blocker natively (blocker_ready false keeps the callback).
	bool blocker_ready = false;
	double BLOCKER_REACH = 0.0, BLOCKER_GAP_M = 0.0, BLOCKER_AHEAD_COS = 0.0;
	// Round 27 (E2): Pathing.query natively in the re-plan (query_ready false keeps the call into GDScript).
	bool query_ready = false;
	double MESH_EPSILON = 0.0;
	// Round 27 (E2): Movement._planned_reverse's look up to its cheap exits natively (kturn_look_ready false: the callback).
	bool kturn_look_ready = false;
	double KTURN_MIN_ERROR_DEG = 0.0, KTURN_CIRCLE_SPEED = 0.0;
	// Round 28 (N5): Movement._repair natively (SlotGround.for_unit called; repair_ready false: the callback).
	bool repair_ready = false;
	double REPAIR_MAX_M = 0.0;
	double NAV_AGENT_RADIUS = 0.0; // Round 28 (N5): Movement.bake_radius natively (0: the callback)
	Object *slot_ground = nullptr;
	Variant keep_slot_ground;
	// Round 27 (E5c): Movement.right_of_way natively (yield_ready false: handed back).
	bool yield_ready = false;
	double YIELD_REACHED = 0, YIELD_CLEAR = 0, YIELD_HOLD_SECONDS = 0;
	// Round 27 (E4): Movement.unstick natively (unstick_ready false: the GDScript).
	bool unstick_ready = false;
	double STUCK_SPEED = 0, STUCK_SECONDS = 0, UNSTICK_SECONDS = 0, UNSTICK_CLEARANCE = 0, PRESS_ESCAPE_THROTTLE = 0,
		   PRESS_BACKOFF_M = 0, PRESS_SECONDS = 0, PRESS_PROGRESS_M = 0, PRESS_ESCAPE_MAX_S = 0, THROTTLE_MIN = 0;
	Object *manoeuvre_census = nullptr; // ManoeuvreCensus (its trace_unit: a traced unit takes the GDScript, which prints)
	Variant keep_manoeuvre_census;
	// Round 33 (N5.M): Movement._manoeuvre's DECISION natively (BrainSwitches.native_manoeuvre; the gate is round 26's):
	// Manoeuvre.choose and its simulation over motion_step and NavNative::outline_ok. manoeuvre_ready false (a constant,
	// the Manoeuvre script or the motion model missing) keeps the callback. MAN_* are Manoeuvre's constants.
	bool manoeuvre_ready = false;
	double MAN_MAX_M = 0, MAN_BEHIND_DEG = 0, MAN_FACING_KEEP_DEG = 0, MAN_SIM_DT = 0, MAN_SIM_HORIZON_S = 0,
		   MAN_HULL_MARGIN_M = 0, KTURN_MARGIN_M = 0, CUSP_DEADBAND = 0;
	int64_t MAN_CHECK_EVERY = 1, REAIM_TICKS = 0;
	Object *manoeuvre_script = nullptr; // Manoeuvre (its statics `plans` / `refused`)
	Variant keep_manoeuvre_script;
	// Round 33 (N5.Y): _negotiate's body, ask and _begin_yield natively (BrainSwitches.native_yield). yield_port_ready false
	// (a constant missing) keeps the callback. yield_fit / yield_short / yield_clear / yield_hold are Movement's arms as
	// configured (the native drive runs only with no --nav-off: the values here are the ones in force).
	bool yield_port_ready = false, yield_fit = false, yield_short = false, yield_clear = false, yield_hold = false;
	double PRIORITY_MARGIN = 0, YIELD_MAX_SECONDS = 0, YIELD_LINE_MARGIN = 0, YIELD_SPOT_CLEARANCE = 0, YIELD_MESH_SLACK = 0,
		   YIELD_FIT_STEP_M = 0, YIELD_FIT_PIVOT_DEG = 0, YIELD_SHORT_MIN_M = 0, YIELD_SHORT_MARGIN_M = 0;
	int64_t YIELD_FIT_STEPS_PER_M = 0, YIELD_FIT_MIN_STEPS = 0;
	PackedVector2Array YIELD_SPOTS;
	PackedFloat64Array YIELD_BACK_UP;
	const struct MotionConfig *motion = nullptr; // TankMotion.step_in_place's model (TankNative's, NativeMotion.configure)
	mutable HashMap<String, Dictionary> state_stats_of; // TankMotion.state_for's Units.stat answers by unit (pure)
};

// Executes one drive: returns false (nothing done) when the configuration is missing. `owned` (round 27, E1c): on the
// C++-owned state (ExecState, exec_view.h's StructView) instead of the live members; the same bits either way.
bool drive_native(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta,
		bool owned = false);
// Round 27 (stage 1 E5): the drive and unstick on a state the CALLER manages (null: the live members; else the C++-owned
// state, which the caller pulled and will push: only callbacks into GDScript sync it inside).
struct ExecState;
bool drive_with(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta, ExecState *state);
bool unstick_with(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta,
		ExecState *state);
// Movement.right_of_way(cmd, delta): 1 giving way (cmd filled), 0 not, -1 not configured.
int right_of_way_with(const DriveConfig &config, Object *mover, Object *cmd, ExecState *state);
// Round 27 (stage 1 E4): Movement.unstick(cmd, order, delta) natively, on the live members or the owned state.
bool unstick_native(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta, bool owned);
// Steering.drive_toward(position, forward, target, arrive_radius) (remaining -1), for the other execute ports.
Vector2 steering_drive_toward(const DriveConfig &c, const Vector3 &position, const Vector3 &forward, const Vector3 &target,
		double arrive_radius);
// Measurement: owned drives, and the transition's pulls and pushes they made; round 33 (N5.M): `_manoeuvre` decisions
// made natively and called back. `reset` zeroes them.
Dictionary drive_owned_counts(bool reset);
// Measurement only: microseconds a callback took (by name), "drives", "total"; `reset` zeroes it.
Dictionary drive_profile(bool reset);
// Movement._around_fire(waypoint, goal, order) natively on this mover (the proof asks it beside the live GDScript).
// Round 35 (R35.8): Movement._pass_lane(passer, from, direction) natively on this mover (the twin asks it beside the live one).
double drive_pass_lane(const DriveConfig &config, Object *mover, const String &passer, const Vector3 &from, const Vector2 &direction);
Vector3 drive_around_fire(const DriveConfig &config, Object *mover, const Vector3 &waypoint, const Vector3 &goal,
		const Dictionary &order);

} // namespace godot
