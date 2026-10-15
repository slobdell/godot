// Round 27 (native, stage 1 E3): Gunnery.apply (game/ai/gunnery.gd) as ONE native call per crew per tick, over the crew's
// state through a view (exec_view.h: the live Gunnery/Lay members, or the C++-owned ExecState), the same bits as the
// GDScript (tests/test_native_gun.gd drives both from one snapshot).
//
// Ported line by line: apply, _apply_weapon, _apply_suppress, _scanned_shootable, _shootable, the scan loop of
// _nearest_shootable, _cover, _clear_to_fire's gate, Engagement.is_seen / acquire_seconds / crossing_rate / Lay.engage /
// Lay.lose, Ballistics.lead_point / aim_error, Difficulty.aim_offset, OrderFeed.point, Perception.has_line_of_sight (the
// same engine ray), Steering.drive_toward. Still CALLED (GDScript): ARC weapons' _apply_indirect, the native scan's
// seam (BrainSwitches.native_scan), AiTickCache (its per-tick refresh has side effects the GDScript order keeps), the
// brains' spotter Callable, Difficulty.for_team, FireLanes.for_shot (once a reload), Tank.ready_to_fire/ammo_fraction.
#pragma once

#include "drive_native.h"

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct GunConfig {
	bool ready = false;
	int64_t SCAN_EVERY_TICKS = 3, LANE_RECHECK_TICKS = 1, WANDER_PERIOD_TICKS = 10, KIND_PROJECTILE = 0, KIND_ARC = 3;
	int64_t WORLD_MASK = 1;
	double LOW_AMMO_FRACTION = 0.3, HELD_AIM_DISTANCE = 1000.0, SHELL_SPEED = 70.0, EYE_HEIGHT = 1.3;
	// Round 31 (manoeuvre H3, CP-H, `realspeed`): Manoeuvre.real_speed_on() at configure: the two aim leads read
	// Tank.real_velocity (Manoeuvre.lead_velocity), else estimated_velocity. False on a tree without it.
	bool REAL_SPEED = false;
	// Engagement's constants
	double ACQUIRE_NEAR_SECONDS = 0, ACQUIRE_FAR_SECONDS = 0, SUPPRESSION_ACQUIRE_PENALTY = 0, DESIGNATED_ACQUIRE_SCALE = 0,
		   SCOUT_ACQUIRE_SCALE = 0, CROSSING_ACQUIRE_PENALTY = 0, CROSSING_REFERENCE_RATE = 1, CROSSING_ACQUIRE_MAX = 0,
		   LOST_LAY_DECAY = 0, RELEASE_FACTOR = 0, RETURN_FIRE_SUPPRESSION = 0;
	// The scripts whose statics or functions are used.
	Object *engagement = nullptr, *order_controller = nullptr, *difficulty = nullptr, *ai_tick_cache = nullptr,
		   *fire_lanes = nullptr, *units = nullptr, *switches = nullptr, *perception = nullptr, *match_script = nullptr;
	Variant keep_engagement, keep_order_controller, keep_difficulty, keep_ai_tick_cache, keep_fire_lanes, keep_units,
			keep_switches, keep_perception, keep_match_script;
	mutable HashMap<String, bool> scout_of; // Units.role_of(unit) == "scout", pure
	// Difficulty.for_team(team)["aim_wander_m"], per team for one physics frame.
	mutable int64_t wander_frame = -1;
	mutable double wander_of[2] = { 0, 0 };
	mutable bool wander_known[2] = { false, false };
};

// One crew's Gunnery.apply(cmd, seconds), natively. `owned`: on the C++-owned state (pulled, run, changed fields pushed).
// False (nothing done) when the configuration is missing.
bool gun_apply(const GunConfig &gun, const DriveConfig &drive, Object *gunnery, Object *cmd, double seconds, bool owned);

// The same on a state the caller manages (null: the live members).
struct ExecState;
bool gun_with(const GunConfig &gun, const DriveConfig &drive, Object *gunnery, Object *cmd, double seconds, ExecState *state);
// From NativeGun.configure's Dictionary (the live constants and scripts); false when any is missing.
bool gun_configure(GunConfig &gun, const Dictionary &config);
// OrderFeed.point: a point or a direction as a flat Vector3, or NIL (shared with feed_native.cpp).
Variant order_feed_point(const Variant &value);

} // namespace godot
