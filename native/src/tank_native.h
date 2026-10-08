// Tank Squad native (round 23, stream native): the vehicle brain's hot loop in C++ through godot-cpp.
//
// Every function here is a PORT of a GDScript function and must give the SAME BITS (_agents/native.md, "The proof"):
// `real_t` (float32) where GDScript has Vector math, `double` where it has `float`, and the same rounding points in
// the same order. Nothing here may change a decision: the switch `BrainSwitches.native` runs either path and the
// match hash is the proof.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>
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
};

} // namespace godot
