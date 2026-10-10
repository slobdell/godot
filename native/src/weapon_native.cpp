// Round 25/26 (native N7, `native_weapon`): Gunnery's aim solution after the scan, as one call. Every line is a PORT
// of the GDScript (gunnery.gd `_aim_solution`, Ballistics.lead_point, Difficulty.aim_offset, Ballistics.aim_error) and
// must give the SAME BITS (_agents/native.md, "The proof"); tests/test_native_weapon.gd asks the live functions.

#include "tank_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>

namespace godot {

namespace {

// Ballistics.lead_point, line by line:
//   var offset := target - shooter                               -> float32 members
//   var a := target_velocity.dot(target_velocity) - projectile_speed * projectile_speed  -> dot real_t, widened; double
//   var b := 2.0 * offset.dot(target_velocity)                   -> double
//   var c := offset.dot(offset)                                  -> double
//   the root search in double; `target + target_velocity * t`    -> t narrowed to real_t for the scale
Vector3 lead_point(const Vector3 &shooter, const Vector3 &target, const Vector3 &target_velocity, double projectile_speed) {
	const Vector3 offset = target - shooter;
	const double a = (double)target_velocity.dot(target_velocity) - projectile_speed * projectile_speed;
	const double b = 2.0 * (double)offset.dot(target_velocity);
	const double c = (double)offset.dot(offset);
	double t = -1.0;
	if (std::fabs(a) < 1e-6) {
		if (std::fabs(b) > 1e-6) {
			t = -c / b;
		}
	} else {
		const double discriminant = b * b - 4.0 * a * c;
		if (discriminant >= 0.0) {
			const double root = std::sqrt(discriminant);
			const double candidates[2] = { (-b - root) / (2.0 * a), (-b + root) / (2.0 * a) };
			for (double candidate : candidates) {
				if (candidate > 0.0 && (t <= 0.0 || candidate < t)) {
					t = candidate;
				}
			}
		}
	}
	if (t <= 0.0) {
		return target;
	}
	return target + target_velocity * (real_t)t;
}

// Difficulty.aim_offset: eight points round a square of half-size `wander`, a step every `period` ticks.
Vector3 aim_offset(double wander, int64_t tick, int64_t slot, int64_t period) {
	if (wander <= 0.0) {
		return Vector3();
	}
	static const Vector2 pattern[8] = { Vector2(1, 0), Vector2(-1, -1), Vector2(0, 1), Vector2(1, -1), Vector2(-1, 0),
		Vector2(1, 1), Vector2(0, -1), Vector2(-1, 1) };
	// GDScript's int `/` and `%` truncate toward zero, as C++'s do.
	const int64_t step = (tick / period + slot * 3) % 8;
	const Vector2 point = pattern[step] * (real_t)wander;
	return Vector3(point.x, 0.0, point.y);
}

// Ballistics.aim_error: the horizontal angle between `forward` and the way to `point` (radians, >= 0).
double aim_error(const Vector3 &origin, const Vector3 &forward, const Vector3 &point) {
	const Vector3 flat_forward(forward.x, 0.0, forward.z);
	const Vector3 to_point((real_t)((double)point.x - (double)origin.x), 0.0, (real_t)((double)point.z - (double)origin.z));
	if ((double)flat_forward.length_squared() < 1e-8 || (double)to_point.length_squared() < 1e-8) {
		return 0.0;
	}
	return std::fabs((double)flat_forward.signed_angle_to(to_point, Vector3(0, 1, 0)));
}

// Engagement's constants, read from the live script by NativeWeapon (weapon_engage_configure), in this order.
struct EngageConsts {
	double near_seconds = 0.0, far_seconds = 0.0, suppression_penalty = 0.0, designated_scale = 0.0, scout_scale = 0.0,
		   crossing_penalty = 0.0, crossing_reference = 1.0, crossing_max = 0.0, release_factor = 0.0, return_fire = 0.0;
	bool ready = false;
};
EngageConsts engage_consts;

// Engagement.crossing_rate: the contact's speed across the sight line, radians a second.
double crossing_rate(const Vector3 &here, const Vector3 &there, const Vector3 &target_velocity, double distance) {
	if (distance <= 0.5) {
		return 0.0;
	}
	Vector3 sight_line = there - here;
	sight_line.y = 0.0;
	if ((double)sight_line.length_squared() <= 0.0) {
		return 0.0;
	}
	sight_line = sight_line.normalized();
	Vector3 velocity = target_velocity;
	velocity.y = 0.0;
	// `velocity.dot(sight_line)` is a GDScript float; `sight_line * it` narrows it back to real_t.
	const double along = (double)velocity.dot(sight_line);
	return (double)(velocity - sight_line * (real_t)along).length() / distance;
}

} // namespace

void TankNative::weapon_engage_configure(const PackedFloat64Array &values) {
	ERR_FAIL_COND(values.size() != 10);
	engage_consts.near_seconds = values[0];
	engage_consts.far_seconds = values[1];
	engage_consts.suppression_penalty = values[2];
	engage_consts.designated_scale = values[3];
	engage_consts.scout_scale = values[4];
	engage_consts.crossing_penalty = values[5];
	engage_consts.crossing_reference = values[6];
	engage_consts.crossing_max = values[7];
	engage_consts.release_factor = values[8];
	engage_consts.return_fire = values[9];
	engage_consts.ready = true;
}

// Engagement.Lay.engage (gates 2 and 3) from the lay's state, AFTER the caller reset it for a new target:
// [progress, firing (0/1), may fire (0/1), counter (0 none, 1 held by acquisition, 2 held by discipline)].
// Engagement.acquire_seconds and crossing_rate inline, line for line, in the GDScript's widths (doubles; the vector
// math in real_t).
PackedFloat64Array TankNative::weapon_engage(double progress, bool firing, const Vector3 &here, const Vector3 &there,
		const Vector3 &target_velocity, double distance, double seconds, double sight_radius, double suppression,
		double designated_seconds, bool scout, double effective_range, double weapon_range, bool ordered,
		bool acquisition, bool crossing) const {
	const EngageConsts &k = engage_consts;
	PackedFloat64Array out;
	out.resize(4);
	if (!acquisition) {
		progress = INFINITY;
	} else {
		const double sight = std::fmax(sight_radius, 1.0);
		const double reach = CLAMP(distance / sight, 0.0, 1.0);
		double needed = k.near_seconds + (k.far_seconds - k.near_seconds) * reach;
		needed *= 1.0 + k.suppression_penalty * CLAMP(suppression, 0.0, 1.0);
		if (crossing) {
			const double rate = crossing_rate(here, there, target_velocity, distance) / k.crossing_reference;
			needed *= 1.0 + k.crossing_penalty * CLAMP(rate, 0.0, k.crossing_max);
		}
		if (scout) {
			needed *= k.scout_scale;
		}
		if (designated_seconds > 0.0) {
			needed *= k.designated_scale;
		}
		progress = std::fmin(progress + seconds, needed);
		if (progress < needed) {
			out.set(0, progress);
			out.set(1, 0.0);
			out.set(2, 0.0);
			out.set(3, 1.0);
			return out;
		}
	}
	double limit = effective_range;
	if (ordered || suppression >= k.return_fire) {
		limit = weapon_range;
	} else if (firing) {
		limit *= k.release_factor;
	}
	firing = distance <= limit;
	out.set(0, progress);
	out.set(1, firing ? 1.0 : 0.0);
	out.set(2, firing ? 1.0 : 0.0);
	out.set(3, firing ? 0.0 : 2.0);
	return out;
}

// Gunnery._aim_solution's answer: [aim.x, aim.y, aim.z, distance (muzzle to aim), aim error (radians)].
// `round_speed` <= 0 = not a projectile (no lead); `wander` <= 0 or `period` <= 0 = no Difficulty offset.
PackedFloat64Array TankNative::weapon_aim(const Vector3 &muzzle, const Vector3 &target, const Vector3 &target_velocity,
		double round_speed, double wander, int64_t tick, int64_t slot, int64_t period, const Vector3 &turret_forward) const {
	Vector3 aim = target;
	if (round_speed > 0.0) {
		aim = lead_point(muzzle, target, target_velocity, round_speed);
	}
	if (period > 0) {
		aim += aim_offset(wander, tick, slot, period);
	}
	PackedFloat64Array out;
	out.resize(5);
	out.set(0, aim.x);
	out.set(1, aim.y);
	out.set(2, aim.z);
	out.set(3, (double)muzzle.distance_to(aim));
	out.set(4, aim_error(muzzle, turret_forward, aim));
	return out;
}

} // namespace godot
