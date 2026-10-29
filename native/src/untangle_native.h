// Round 45 (native N2b, R45.3): SelectionSquads.untangle_whole's search (game/control/selection_squads.gd) in C++. A right click
// on 30 units / 6 squads spent 13.8 of its 29-31 ms there (laptop, native off, 0b62c4900): the 720 permutations of a six-squad
// column, GDScript after R43.11's memo. The Callables (position, arc, misplaced) are read in GDScript first, every value they
// can be asked (NativeUntangle), so this is pure geometry: union-find, groups in first-seen order, the permutations in
// _build_permutations' order, the same keys and tie-breaks, the drive summed in doubles crew by crew, crossings by the
// engine's own Geometry2D.segment_intersects_segment. tests/test_native_untangle.gd holds it to the live GDScript.
#pragma once

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

namespace godot {

// `starts`: per squad, an Array of its crews' Vector2 starts (_xz of position); `anchors`: Vector3 per squad (at least);
// `by_lead`, `leads` / `arcs` (per squad: leads[i], arc(anchors[i])); `misplaced`: n*n bytes, [i * n + j] = misplaced(i,
// anchors[j]), empty when the Callable is not valid; `slack` = SelectionSquads.LEAD_SLACK_M.
// Returns {"anchors": Array (the first n, re-dealt), "moved": int, "still_crossed": int}.
Dictionary untangle_whole(const Array &starts, const Array &anchors, bool by_lead, const PackedFloat64Array &leads,
		const PackedFloat64Array &arcs, const PackedByteArray &misplaced, double slack);

} // namespace godot
