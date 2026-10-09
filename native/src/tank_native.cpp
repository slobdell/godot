#include "tank_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
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
	ClassDB::bind_method(D_METHOD("would_be_hit", "here", "now", "planned", "incoming", "turn_seconds", "acceleration",
			"tick_rate"), &TankNative::would_be_hit);
	ClassDB::bind_method(D_METHOD("avoidance_load", "names", "xs", "zs", "vxs", "vzs", "radii", "half_w", "half_l", "fxs",
			"fzs", "still"), &TankNative::avoidance_load);
	ClassDB::bind_method(D_METHOD("avoidance_solve", "me", "position", "velocity", "preferred", "max_speed", "radius", "dt",
			"cap", "oriented"), &TankNative::avoidance_solve);
	ClassDB::bind_method(D_METHOD("record_load", "names", "units", "f32", "f64", "i32", "route_points", "route_offsets",
			"cover"), &TankNative::record_load);
	ClassDB::bind_method(D_METHOD("record_size"), &TankNative::record_size);
	ClassDB::bind_method(D_METHOD("record_find", "name"), &TankNative::record_find);
	ClassDB::bind_method(D_METHOD("record_row", "row"), &TankNative::record_row);
	ClassDB::bind_method(D_METHOD("record_set_command", "row", "throttle", "turn", "aim", "fire"),
			&TankNative::record_set_command);
	ClassDB::bind_method(D_METHOD("command_into", "row", "cmd"), &TankNative::command_into);
	ClassDB::bind_method(D_METHOD("contacts_load", "team", "names", "units", "weapons", "roles", "f32", "f64", "i32"),
			&TankNative::contacts_load);
	ClassDB::bind_method(D_METHOD("contacts_size", "team"), &TankNative::contacts_size);
	ClassDB::bind_method(D_METHOD("contacts_row", "team", "row"), &TankNative::contacts_row);
	ClassDB::bind_method(D_METHOD("record_layout"), &TankNative::record_layout);
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

// combat_motion.gd `would_be_hit`, line by line (its constants HIT_RADIUS 2.8, DODGE_STEP 0.1, PIVOT_SECONDS 0.75):
//   var seconds := float(entry.get("eta_ticks", SimClock.TICK_RATE / 2)) / SimClock.TICK_RATE + 0.25   (double; int / int first)
//   while t < seconds: step := minf(DODGE_STEP, seconds - t)                                           (double)
//     closest_approach(position, velocity, round_at + round_velocity * t, round_velocity, step) < HIT_RADIUS (t narrowed)
//     position += velocity * step; t += step                                                          (step narrowed; t double)
//     goal := planned if t >= turn_seconds else (ZERO if turn_seconds > PIVOT_SECONDS else velocity)
//     velocity = velocity.move_toward(goal, acceleration * step)                                       (the delta narrowed)
bool TankNative::would_be_hit(const Vector3 &here, const Vector3 &now, const Vector3 &planned, const Array &incoming,
		double turn_seconds, double acceleration, int tick_rate) const {
	constexpr double HIT_RADIUS = 2.8;
	constexpr double DODGE_STEP = 0.1;
	constexpr double PIVOT_SECONDS = 0.75;
	const int64_t n = incoming.size();
	for (int64_t k = 0; k < n; k++) {
		const Dictionary entry = incoming[k];
		const Vector3 round_at = entry["position"];
		const Vector3 round_velocity = entry["velocity"];
		const Variant eta = entry.get("eta_ticks", tick_rate / 2);
		const double seconds = (double)eta / (double)tick_rate + 0.25;
		double t = 0.0;
		Vector3 position = here;
		Vector3 velocity = now;
		while (t < seconds) {
			const double remaining = seconds - t;
			const double step = DODGE_STEP < remaining ? DODGE_STEP : remaining;
			if (closest_approach(position, velocity, round_at + round_velocity * (real_t)t, round_velocity, step) < HIT_RADIUS) {
				return true;
			}
			position += velocity * (real_t)step;
			t += step;
			const Vector3 goal = t >= turn_seconds ? planned : (turn_seconds > PIVOT_SECONDS ? Vector3() : velocity);
			velocity = velocity.move_toward(goal, (real_t)(acceleration * step));
		}
	}
	return false;
}

void TankNative::avoidance_load(const PackedStringArray &names, const PackedFloat32Array &xs, const PackedFloat32Array &zs,
		const PackedFloat32Array &vxs, const PackedFloat32Array &vzs, const PackedFloat32Array &radii,
		const PackedFloat32Array &half_w, const PackedFloat32Array &half_l, const PackedFloat32Array &fxs,
		const PackedFloat32Array &fzs, const PackedByteArray &still) {
	avoidance.load(names, xs, zs, vxs, vzs, radii, half_w, half_l, fxs, fzs, still);
}

Vector3 TankNative::avoidance_solve(const String &me, const Vector2 &position, const Vector2 &velocity, const Vector2 &preferred,
		double max_speed, double radius, double dt, int cap, bool oriented) const {
	int near_count = 0;
	int oriented_count = 0;
	const Vector2 result = avoidance.solve(me, position, velocity, preferred, max_speed, radius, dt, cap, oriented, near_count, oriented_count);
	return Vector3(result.x, result.y, (real_t)(near_count + 16 * oriented_count));
}

// ---- N3a: the per-tank record and the contacts table (tank_record.h) ----

bool TankNative::record_load(const PackedStringArray &names, const PackedStringArray &units, const PackedFloat32Array &f32,
		const PackedFloat64Array &f64, const PackedInt32Array &i32, const PackedVector3Array &route_points,
		const PackedInt32Array &route_offsets, int64_t cover) {
	return records.load(names, units, f32, f64, i32, route_points, route_offsets, cover, avoidance);
}

int TankNative::record_find(const String &name) const {
	const int32_t *row = records.index.getptr(name);
	return row != nullptr ? *row : -1;
}

void TankNative::record_set_command(int r, double throttle, double turn, const Vector3 &aim, bool fire) {
	if (r < 0 || r >= records.size()) {
		return;
	}
	records.out_throttle[r] = throttle;
	records.out_turn[r] = turn;
	records.out_aim[r] = aim;
	records.out_fire[r] = fire;
}

// TankCommand built natively: the row's command written into the controller's TankCommand (four property sets in
// C++, one call from GDScript), the same values a GDScript `cmd.throttle = ...` would store.
void TankNative::command_into(int r, Object *cmd) const {
	if (cmd == nullptr || r < 0 || r >= records.size()) {
		return;
	}
	static const StringName throttle("throttle"), turn("turn"), aim_point("aim_point"), fire("fire");
	cmd->set(throttle, records.out_throttle[r]);
	cmd->set(turn, records.out_turn[r]);
	cmd->set(aim_point, records.out_aim[r]);
	cmd->set(fire, records.out_fire[r] != 0);
}

bool TankNative::contacts_load(int team, const PackedStringArray &names, const PackedStringArray &units,
		const PackedStringArray &weapons, const PackedStringArray &roles, const PackedFloat32Array &f32,
		const PackedFloat64Array &f64, const PackedInt32Array &i32) {
	if (team < 0 || team > 1) {
		return false;
	}
	return contacts[team].load(names, units, weapons, roles, f32, f64, i32);
}

int TankNative::contacts_size(int team) const {
	return (team < 0 || team > 1) ? 0 : contacts[team].size();
}

Dictionary TankNative::contacts_row(int team, int r) const {
	return (team < 0 || team > 1) ? Dictionary() : contacts[team].row(r);
}

Dictionary TankNative::record_layout() const {
	Dictionary d;
	d["f32"] = (int)RecordLayout::F32_STRIDE;
	d["f64"] = (int)RecordLayout::F64_STRIDE;
	d["i32"] = (int)RecordLayout::I32_STRIDE;
	d["contact_f32"] = (int)ContactLayout::F32_STRIDE;
	d["contact_f64"] = (int)ContactLayout::F64_STRIDE;
	d["contact_i32"] = (int)ContactLayout::I32_STRIDE;
	return d;
}

} // namespace godot
