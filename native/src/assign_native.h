// Round 45 (native, R45.16): SelectionSquads._assign's exhaustive search (game/control/selection_squads.gd: _assign + _search) in
// C++. G2's 30-unit / 6-squad click spent 2.44 of its ~14 ms there (builder2, native ON, pair/native-g2 c7444d484 + timers): the
// least-total straight-line assignment of squads to seats by branch and bound, n <= SEARCH_LIMIT. The same costs (the Vector3
// distance, as a GDScript float), the same depth-first order (seat 0 first), the same prune (total >= best - 1e-6) and the same
// first-best-kept tie rule. tests/test_native_assign.gd holds it to the live GDScript.
#pragma once

#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

// The seat index for each of `centers` (the first centers.size() of `slots`), or the empty array when centers is empty.
PackedInt32Array assign_least_total(const PackedVector3Array &centers, const PackedVector3Array &slots);

} // namespace godot
