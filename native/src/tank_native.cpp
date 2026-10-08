#include "tank_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/version.hpp>

#ifndef TANK_NATIVE_BUILD_HOST
#define TANK_NATIVE_BUILD_HOST "unknown"
#endif
#ifndef TANK_NATIVE_FLAGS
#define TANK_NATIVE_FLAGS "unknown"
#endif
#ifndef TANK_NATIVE_GODOTCPP
#define TANK_NATIVE_GODOTCPP "unknown"
#endif
#define TANK_NATIVE_REAL_T_BITS 32
static_assert(sizeof(real_t) * 8 == TANK_NATIVE_REAL_T_BITS, "single-precision godot-cpp: real_t is float32, like the engine binary");

namespace godot {

void TankNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("build_info"), &TankNative::build_info);
	ClassDB::bind_method(D_METHOD("closest_approach", "here", "velocity", "round_position", "round_velocity", "seconds"),
			&TankNative::closest_approach);
}

#define TN_STR2(x) #x
#define TN_STR(x) TN_STR2(x)

String TankNative::build_info() const {
	return String("godot-cpp " TANK_NATIVE_GODOTCPP " | api " TN_STR(GODOT_VERSION_MAJOR) "." TN_STR(GODOT_VERSION_MINOR) "."
			TN_STR(GODOT_VERSION_PATCH) " | "
#if defined(__clang__)
			"clang " __clang_version__
#elif defined(__GNUC__)
			"gcc " __VERSION__
#else
			"compiler ?"
#endif
			" | " TANK_NATIVE_FLAGS " | built on " TANK_NATIVE_BUILD_HOST " | real_t " TN_STR(TANK_NATIVE_REAL_T_BITS) " bits");
}

// The GDScript, line by line (incoming_fire.gd `closest_approach`), with each width where GDScript has it:
//   var offset := Vector3(here.x - round_position.x, 0.0, here.z - round_position.z)
//       -> the members are float32, the subtraction a GDScript float (double), the constructor stores float32.
//          Double rounding of a float32 subtraction done in double is the float32 subtraction (53 >= 2*24 + 2).
//   var relative := Vector3(velocity.x - round_velocity.x, 0.0, velocity.z - round_velocity.z)     (the same)
//   var speed_squared := relative.length_squared()           -> real_t, widened to double
//   var t := 0.0 if speed_squared < 1e-6 else clampf(-offset.dot(relative) / speed_squared, 0.0, seconds)
//       -> dot in real_t, negated and divided in double, clamped in double
//   return (offset + relative * t).length()                  -> t narrowed to real_t for the scale, length in real_t
double TankNative::closest_approach(const Vector3 &here, const Vector3 &velocity, const Vector3 &round_position,
		const Vector3 &round_velocity, double seconds) const {
	const Vector3 offset(
			(real_t)((double)here.x - (double)round_position.x), (real_t)0.0,
			(real_t)((double)here.z - (double)round_position.z));
	const Vector3 relative(
			(real_t)((double)velocity.x - (double)round_velocity.x), (real_t)0.0,
			(real_t)((double)velocity.z - (double)round_velocity.z));
	const double speed_squared = (double)relative.length_squared();
	double t = 0.0;
	if (!(speed_squared < 1e-6)) {
		const double along = -(double)offset.dot(relative) / speed_squared;
		t = along < 0.0 ? 0.0 : (along > seconds ? seconds : along);
	}
	return (double)(offset + relative * (real_t)t).length();
}

} // namespace godot
