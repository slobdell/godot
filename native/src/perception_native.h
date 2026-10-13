// Round 28 (native N6.3, perception only): what each crew can see, as one batched pass a team -- the line of sight
// and sight-range half of Match._update_intel (game/match/match.gd), Perception.has_line_of_sight's ray
// (game/ai/perception.gd) cast from here. Intel (the `known` contacts, their fields, seen_tick, forgetting) stays
// GDScript: this answers only WHO SEES WHOM. tests/test_native_perception.gd holds it to the live GDScript.
#pragma once

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <cstdint>

namespace godot {

struct PerceptionConfig {
	bool ready = false;
	double EYE_HEIGHT = 1.3;
	uint32_t WORLD_MASK = 1;
};

// For each enemy (in order): -2 when it is dead (intel forgets it), else the index of the FIRST viewer (in order) that
// is alive, within its sight_radius and has a clear line (Match._update_intel's inner loop), -1 for none. `rays` counts
// the lines cast (SimProfile's intel/los_queries).
PackedInt32Array perception_sight(const PerceptionConfig &config, const Array &viewers, const Array &enemies, int64_t &rays);
// For each viewer: alive, ready_to_fire and an enemy alive within float(weapon["range"]) on a clear line (the
// gun-ready sample's test); 1 or 0.
PackedByteArray perception_gun_ready(const PerceptionConfig &config, const Array &viewers, const Array &enemies, int64_t &rays);

} // namespace godot
