// Round 29 (native, C29.2 scaffold for traffic's T1): the street hold as a record the native execute reads. Traffic
// decides a hold in GDScript (Traffic.holding(crew): the waiting squad's crews stop at a spot short of the street mouth);
// it writes the hold here through NativeHold (game/ai/native/native_hold.gd), one call when a hold starts and one when it
// ends, so the execute reads it per crew without a crossing. Until T1's drive is ported, a holding crew's execute is
// handed back to the GDScript (reason "holding"); with no hold written the execute is unchanged.
//
// No godot type is stored (a static holding Variants outlives the engine: E5b's exit-time heap corruption): the key is
// the mover's instance id, the spot three floats (a Vector3 is float32), the start a double (a GDScript float).
#pragma once

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

void hold_set(Object *mover, const Vector3 &spot, double since);
void hold_clear(Object *mover);
// Every hold dropped (a new match, the tests).
void hold_clear_all();
bool hold_has(Object *mover);
// [spot, since] or NIL.
Variant hold_of(Object *mover);
int hold_count();

} // namespace godot
