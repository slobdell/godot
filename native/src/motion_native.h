// Round 28 (native N6.1): TankMotion.step_in_place in C++ (motion_native.cpp).
#pragma once

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct MotionConfig {
	bool ready = false;
	// TankMotion's constants and the two of Movement's it reads (handed over from the live scripts: NativeMotion.configure).
	double WHEEL_CREEP_THROTTLE = 0.5, CREEP_REVERSE_SPEED = 0.5, CREEP_DRIFT_M = 1.0, WHEELS_SETTLE_RADII = 0.6,
		   WHEELS_SETTLE_MAX = 6.0;
	int64_t CREEP_LEG_TICKS = 15;
	static constexpr double YAW_RAMP_SECONDS = 0.25; // checked against the script at configure
	Object *movement = nullptr; // the Movement script: switched_off("creepbound") is asked live, as the GDScript does
	Variant keep_movement;
};

// TankMotion.step_in_place(state, throttle, turn, delta): `state` updated in place (Dictionaries are shared references).
void motion_step(const MotionConfig &config, Dictionary state, double throttle, double turn, double delta);

} // namespace godot
