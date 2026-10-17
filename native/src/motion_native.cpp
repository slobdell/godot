// Round 28 (native N6.1): TankMotion.step_in_place (game/tank/tank_motion.gd) in C++, line by line in the GDScript's
// widths (doubles for its floats, float32 for its vectors: native.md hazard 1). The state is the same Dictionary, updated
// in place (the Tank keeps one and steps it every tick; manoeuvre's and combat_motion's planners roll copies).
// tests/test_native_motion.gd holds it to the live GDScript over seeded states of every locomotion.
#include "motion_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>

namespace godot {

namespace {

// String keys, as the GDScript's dictionary literals have (a key this code INSERTS, creep_dir / creep_ticks /
// creep_anchor / yaw_rate, must be the same type the GDScript inserts).
struct MN {
	String forward{ "forward" }, speed{ "speed" }, velocity{ "velocity" }, position{ "position" },
			hull_turn_rate_deg{ "hull_turn_rate_deg" }, locomotion{ "locomotion" }, creep_dir{ "creep_dir" },
			creep_ticks{ "creep_ticks" }, creep_anchor{ "creep_anchor" }, min_turn_radius_m{ "min_turn_radius_m" },
			max_forward_speed{ "max_forward_speed" }, max_reverse_speed{ "max_reverse_speed" },
			acceleration_mps2{ "acceleration_mps2" }, braking_mps2{ "braking_mps2" }, lateral_grip{ "lateral_grip" },
			hull_turn_accel_deg_s2{ "hull_turn_accel_deg_s2" }, yaw_rate{ "yaw_rate" };
};
const MN &mn_() {
	static const MN names;
	return names;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
// Math::move_toward(double): abs(to - from) <= delta ? to : from + SIGN(to - from) * delta
inline double move_toward(double from, double to, double delta) {
	const double diff = to - from;
	if (std::fabs(diff) <= delta) {
		return to;
	}
	return from + (diff > 0.0 ? 1.0 : (diff < 0.0 ? -1.0 : 0.0)) * delta;
}
inline double deg_to_rad(double deg) {
	return deg * (Math::PI / 180.0);
}

// TankMotion.next_speed_braking
double next_speed_braking(double speed, double throttle, double max_forward, double max_reverse, double acceleration,
		double braking, double delta) {
	const double target = throttle * (throttle >= 0.0 ? max_forward : max_reverse);
	const bool slowing = std::fabs(target) < std::fabs(speed) || target * speed < 0.0;
	return move_toward(speed, target, (slowing ? braking : acceleration) * delta);
}

// TankMotion.turn_heading: (forward + right * radians).normalized(), radians narrowed to float32 for the scale.
Vector3 turn_heading(const Vector3 &forward, double radians) {
	if (radians == 0.0) {
		return forward;
	}
	const Vector3 right(-forward.z, 0, forward.x);
	return (forward + right * (real_t)radians).normalized();
}

// TankMotion._ramped_yaw
double ramped_yaw(Dictionary &state, double wanted, double max_rate, double delta) {
	const MN &k = mn_();
	double accel = deg_to_rad((double)state.get(k.hull_turn_accel_deg_s2, 0.0));
	if (accel <= 0.0) {
		accel = max_rate / MotionConfig::YAW_RAMP_SECONDS;
	}
	const double rate = move_toward((double)state.get(k.yaw_rate, 0.0), wanted, accel * delta);
	state[k.yaw_rate] = rate;
	return rate;
}

} // namespace

// Round 33 (N5.Y): TankMotion.turn_heading for the give-way's sweep (drive_native.cpp yield_run_ok).
Vector3 motion_turn_heading(const Vector3 &forward, double radians) {
	return turn_heading(forward, radians);
}

void motion_step(const MotionConfig &c, Dictionary state, double throttle, double turn, double delta) {
	static const String wheels("wheels"), hover("hover");
	const MN &k = mn_();
	double throttle_c = clampd(throttle, -1.0, 1.0);
	const double turn_c = clampd(turn, -1.0, 1.0);
	Vector3 forward = state[k.forward];
	double speed = state[k.speed];
	Vector3 velocity;
	const double max_rate = deg_to_rad((double)state[k.hull_turn_rate_deg]);
	const String locomotion = state[k.locomotion];
	if (locomotion == wheels) {
		const double creep = c.WHEEL_CREEP_THROTTLE * std::fabs(turn_c);
		if (std::fabs(throttle_c) < creep) {
			int64_t direction = state.get(k.creep_dir, 0);
			int64_t leg = state.get(k.creep_ticks, 0);
			if (direction == 0) {
				direction = (throttle_c < 0.0 || (throttle_c == 0.0 && speed < -c.CREEP_REVERSE_SPEED)) ? -1 : 1;
				leg = 0;
				state[k.creep_anchor] = state.get(k.position, Vector3(INFINITY, INFINITY, INFINITY));
			} else if (leg >= c.CREEP_LEG_TICKS) {
				direction = -direction;
				leg = 0;
				const Vector3 anchor = state.get(k.creep_anchor, Vector3(INFINITY, INFINITY, INFINITY));
				// Movement.switched_off("creepbound") asked LIVE, where the GDScript asks it (tests switch Movement._off at
				// run time; a value read once at configure was stale for them: the full suite's catch).
				if (anchor != Vector3(INFINITY, INFINITY, INFINITY) && state.has(k.position) &&
						!(c.movement != nullptr ? (bool)c.movement->call(StringName("switched_off"), String("creepbound")) : false)) {
					Vector3 back = anchor - (Vector3)state[k.position];
					back.y = 0;
					const double allowance = clampd((double)state.get(k.min_turn_radius_m, 0.0) * c.WHEELS_SETTLE_RADII,
							c.CREEP_DRIFT_M, c.WHEELS_SETTLE_MAX);
					if ((double)back.length() > allowance) {
						direction = (double)back.dot(forward) >= 0.0 ? 1 : -1;
					}
				}
			}
			state[k.creep_dir] = direction;
			state[k.creep_ticks] = leg + 1;
			throttle_c = creep * (double)direction;
		} else {
			state[k.creep_dir] = 0;
			state[k.creep_ticks] = 0;
		}
		const double radius = MAX((double)state[k.min_turn_radius_m], 0.1);
		const double yaw_rate = clampd(std::fabs(speed) * turn_c / radius, -max_rate, max_rate);
		forward = turn_heading(forward, yaw_rate * delta);
		const Vector3 right(-forward.z, 0, forward.x);
		const Vector3 carried = state[k.velocity];
		const double along = next_speed_braking(carried.dot(forward), throttle_c, state[k.max_forward_speed],
				state[k.max_reverse_speed], state[k.acceleration_mps2], state[k.braking_mps2], delta);
		double sideways = carried.dot(right);
		sideways *= std::pow(1.0 - clampd((double)state[k.lateral_grip], 0.0, 1.0), delta * 60.0);
		speed = along;
		velocity = forward * (real_t)along + right * (real_t)sideways;
	} else if (locomotion == hover) {
		forward = turn_heading(forward, ramped_yaw(state, turn_c * max_rate, max_rate, delta) * delta);
		const Vector3 right(-forward.z, 0, forward.x);
		const Vector3 carried = state[k.velocity];
		const double along = next_speed_braking(carried.dot(forward), throttle_c, state[k.max_forward_speed],
				state[k.max_reverse_speed], state[k.acceleration_mps2], state[k.braking_mps2], delta);
		double sideways = carried.dot(right);
		sideways *= std::pow(1.0 - clampd((double)state[k.lateral_grip], 0.0, 1.0), delta * 60.0);
		speed = along;
		velocity = forward * (real_t)along + right * (real_t)sideways;
	} else {
		forward = turn_heading(forward, ramped_yaw(state, turn_c * max_rate, max_rate, delta) * delta);
		speed = next_speed_braking(speed, throttle_c, state[k.max_forward_speed], state[k.max_reverse_speed],
				state[k.acceleration_mps2], state[k.braking_mps2], delta);
		velocity = forward * (real_t)speed;
	}
	state[k.forward] = forward;
	state[k.speed] = speed;
	state[k.velocity] = Vector3(velocity.x, 0, velocity.z);
	state[k.position] = (Vector3)state[k.position] + velocity * (real_t)delta;
}

} // namespace godot
