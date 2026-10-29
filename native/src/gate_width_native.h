// Round 45 (native N2, C45.4): RtsControls.gate_width (game/control/rts_controls.gd) in C++, for the one caller that reads it on
// a hull's navmesh with SelectionSquads.crosses_or_edge(crosses_on(ground)) and drive_on(ground): the group click's column lay.
// A right click on 30 units / 6 squads spent 10.5 of its 29 ms there (laptop, native off, 0b62c4900: 1 call, 100 steps, ~200
// Pathing.find_path); natively each step asks the navmesh ONCE (crosses' path and drive's path are the same query) and the deck
// test is a loop over boxes. Line by line with the GDScript: the same float32 vector arithmetic, the same double accumulators.
// tests/test_native_gate_width.gd holds it to the live GDScript; RtsControls.gate_width_edge_on is the seam.
#pragma once

#include "pathing_native.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

struct GateConsts {
	double step = 2.0;   // RtsControls.GATE_STEP_M
	double detour = 1.5; // RtsControls.GATE_DETOUR
};

// [left, right] clear metres. `decks` = SlotGround.deck_boxes() ([min_x, min_z, max_x, max_z] each); `clamp` =
// Orders.clamp_to_arena (called back once a step: the arena's shape lives in GDScript).
Array gate_width_edge(const PathingConfig &pathing, const GateConsts &consts, Object *node, const Vector3 &click,
		const Vector3 &across, double scan, double past_posts, const Array &decks, const Callable &clamp);

} // namespace godot
