// Tank Squad native (round 23, stream native): the vehicle brain's hot loop in C++ through godot-cpp.
//
// Every function here is a PORT of a GDScript function and must give the SAME BITS (_agents/native.md, "The proof"):
// `real_t` (float32) where GDScript has Vector math, `double` where it has `float`, and the same rounding points in
// the same order. Nothing here may change a decision: the switch `BrainSwitches.native` runs either path and the
// match hash is the proof.
#pragma once

#include "avoidance.h"
#include "tank_record.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class TankNative : public RefCounted {
	GDCLASS(TankNative, RefCounted)

protected:
	static void _bind_methods();

public:
	TankNative() = default;
	~TankNative() override = default;

	// What this library is: godot-cpp version, compiler, flags and the host it was built on (make doctor, the test).
	String build_info() const;

	// IncomingFire.closest_approach (game/ai/incoming_fire.gd): where a unit at `here` driving at `velocity` would be
	// closest to a round (position, velocity) within `seconds`, in meters. The no-op of N0: the call's own price.
	double closest_approach(const Vector3 &here, const Vector3 &velocity, const Vector3 &round_position,
			const Vector3 &round_velocity, double seconds) const;

	// CombatMotion.would_be_hit (N0b): the whole dodge loop as ONE call (every incoming round, every DODGE_STEP, the
	// closest approach inside each step), where N0 showed one call per step costs more than the step.
	bool would_be_hit(const Vector3 &here, const Vector3 &now, const Vector3 &planned, const Array &incoming,
			double turn_seconds, double acceleration, int tick_rate) const;

	// Avoidance (N1): `Avoidance.refresh` / `load_rows` load this tick's columns; `Avoidance.solve` asks per mover.
	// The answer is (x, y) of the Vector3; z packs the probe counters: neighbours solved against + 16 * oriented pairs.
	void avoidance_load(const PackedStringArray &names, const PackedFloat32Array &xs, const PackedFloat32Array &zs,
			const PackedFloat32Array &vxs, const PackedFloat32Array &vzs, const PackedFloat32Array &radii,
			const PackedFloat32Array &half_w, const PackedFloat32Array &half_l, const PackedFloat32Array &fxs,
			const PackedFloat32Array &fzs, const PackedByteArray &still);
	Vector3 avoidance_solve(const String &me, const Vector2 &position, const Vector2 &velocity, const Vector2 &preferred,
			double max_speed, double radius, double dt, int cap, bool oriented) const;

	// N3a (round 24): the per-tank record and the per-team contacts table, filled once a tick by
	// game/ai/native/native_record.gd (one call each) and read by the ported execute step. `record_row` /
	// `contacts_row` read a row back for the test; `command_into` writes a row's command into a TankCommand.
	bool record_load(const PackedStringArray &names, const PackedStringArray &units, const PackedFloat32Array &f32,
			const PackedFloat64Array &f64, const PackedInt32Array &i32, const PackedVector3Array &route_points,
			const PackedInt32Array &route_offsets, int64_t cover);
	int record_size() const { return records.size(); }
	int record_find(const String &name) const;
	Dictionary record_row(int r) const { return records.row(r); }
	PackedStringArray record_neighbours(int r) const;
	void record_set_command(int r, double throttle, double turn, const Vector3 &aim, bool fire);
	void command_into(int r, Object *cmd) const;
	bool contacts_load(int team, const PackedStringArray &names, const PackedStringArray &units,
			const PackedStringArray &weapons, const PackedStringArray &roles, const PackedFloat32Array &f32,
			const PackedFloat64Array &f64, const PackedInt32Array &i32);
	int contacts_size(int team) const;
	Dictionary contacts_row(int team, int r) const;
	// The column strides, so native_record.gd can assert its constants against the library it talks to.
	Dictionary record_layout() const;

private:
	AvoidanceTable avoidance;
	TankRecords records;
	ContactsTable contacts[2];
};

} // namespace godot
