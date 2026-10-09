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
	mutable int64_t chord_samples_of[2] = { 0, 0 }, orca_of[2] = { 0, 0 };
	mutable bool chord_samples_known[2] = { false, false }, orca_known[2] = { false, false };
	double CHORD_SLACK, CHORD_MARGIN;
	double APPROACH_RADII, APPROACH_MIN, APPROACH_MAX, APPROACH_ALIGNED_COS, MESH_GATE_SLACK, GATE_REACHED;
	double OFF_MESH_PROBES[3];
	double KTURN_THROTTLE, KTURN_SECONDS_PER_M, KTURN_INTO_WALL_COS, KTURN_ROLLING_SPEED, KTURN_BRAKE_HULL_M;
	int64_t KTURN_RETRY_TICKS;
	mutable HashMap<String, double> braking_of; // Movement._braking() by unit: max(Units.stat(unit, "braking_mps2", 8), 0.1)
	Object *tank_command = nullptr;
	NavNative *nav = nullptr;
	Variant keep_pathing, keep_levers, keep_tank_command, keep_nav, keep_avoidance, keep_switches; // hold the references
};

// Executes one drive: returns false (nothing done) when the configuration is missing.
bool drive_native(const DriveConfig &config, Object *mover, Object *cmd, const Dictionary &order, double delta);
// Measurement only: microseconds a callback took (by name), "drives", "total"; `reset` zeroes it.
Dictionary drive_profile(bool reset);

} // namespace godot
