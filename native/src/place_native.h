// Round 47 (native N2, R46.16): TacticsFormation.place (game/tactics/tactics_formation.gd) in C++: the formation's slots for an
// element's members at an anchor along a heading, seated. ElementPlan.build was 1.05 ms a tick on his Crossing (builder3 light,
// probe 128f9b2a9, native ON, n 1) and place 0.39 of it (3.8 calls a tick, 0.10 ms a call; seat 0.21): the one body inside build
// that is hot on its own. Line by line with the GDScript: pitch / hull_floor / turning_pitch, offsets_deformed (no deformation:
// the seam steps aside under DEFORM_ENABLED), group_offsets / offsets / offset / rows, centered, bounded, sectors, seat (its tiers,
// the S v5 open last seat, the seat order, the cost matrix and _hungarian, the stable previous) and the entries. The same float32
// vector arithmetic and double accumulators. What reads the unit catalogue stays in GDScript and arrives as data (`extent` =
// hull_extent(members), `tough` = toughness_of per member, `roles` = the entry's role per member), as do the static switches
// (`flags`). tests/test_native_place.gd holds it to the live GDScript; NativePlace (game/ai/native/native_place.gd) is the seam.
#pragma once

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

// flags, in NativePlace.flags()'s order: SEAT_BOUND, SEAT_ORDER, SEAT_LAST_OPEN, TRAVEL_SUM_FIRST, SHORT_SWAP_ENABLED,
// SQUARED_ALONG_ROUTE, NEAREST_ENABLED. `lateral_floor` = TacticsFormation.LATERAL_FLOOR.
Array formation_place(const Array &members, const String &formation, const Vector3 &anchor, const Vector3 &heading, double spacing,
		const Dictionary &opts, const Vector2 &extent, const PackedFloat64Array &tough, const PackedStringArray &roles,
		const PackedInt32Array &flags, const String &lateral_floor);

} // namespace godot
