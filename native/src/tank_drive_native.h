// Round 28 (native N6.1): Tank._drive natively (tank_drive_native.cpp).
#pragma once

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct MotionConfig;

struct TankDriveConfig {
	bool ready = false;
	double OFF_FLOOR_M = 0.5;
	Object *tank_motion = nullptr, *sim_profile = nullptr; // TankMotion (state_for), SimProfile (enabled, add)
	Variant keep_tank_motion, keep_sim_profile;
	const MotionConfig *motion = nullptr;
};

// One tank's _drive(cmd, delta); false (nothing done) when not configured or not a CharacterBody3D.
bool tank_drive_native(const TankDriveConfig &config, Object *tank, Object *cmd, double delta);

} // namespace godot
