// CoverNative (round 23, N1b): the port of game/ai/cover_map.gd's line-of-sight (`clear_line`, `clear_line_coarse` ->
// `blocked` -> `_features_along` + `segment_hits`) with the feature columns, the broadphase grid and the quantised memo
// held natively. One instance per CoverMap (the GDScript owns it: `_native`), loaded once from the same columns.
// Same bits: Vector2 math in real_t where the GDScript has Vector2 math (including `t_max` / `t_delta`, which are a
// Vector2 there and so float32), double where it has `float`.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <unordered_map>

namespace godot {

class CoverNative : public RefCounted {
	GDCLASS(CoverNative, RefCounted)

	static constexpr double CELL = 12.0;
	static constexpr double MAX_GROW = 4.0;
	static constexpr int MEMO_LIMIT = 60000;

	PackedVector2Array f_center, f_axis, f_half;
	PackedFloat64Array f_height;
	double eye_height = 1.0;
	HashMap<Vector2i, LocalVector<int32_t>> grid;
	LocalVector<int32_t> stamp;
	int32_t stamp_id = 0;
	std::unordered_map<uint64_t, bool> memo_fine, memo_coarse;

	bool features_along(const Vector2 &a, const Vector2 &b, LocalVector<int32_t> &found);
	bool blocked(const Vector2 &a, const Vector2 &b);
	// clear_line / clear_line_coarse: bit 0 = clear, bit 1 = computed this call (CoverMap.los_computed), -1 = no memo
	// key fits (the answer is computed and not kept; never for an arena inside +-16 km).
	int clear(const Vector3 &a, const Vector3 &b, double quantum, std::unordered_map<uint64_t, bool> &memo);

protected:
	static void _bind_methods();

public:
	void load(const PackedVector2Array &centers, const PackedVector2Array &axes, const PackedVector2Array &halves,
			const PackedFloat64Array &heights, double p_eye_height);
	int clear_line(const Vector3 &a, const Vector3 &b);
	int clear_line_coarse(const Vector3 &a, const Vector3 &b);
	bool segment_hits(int index, const Vector2 &a, const Vector2 &b, double grow) const;
	bool path_blocked(const Vector2 &a, const Vector2 &b, double grow);
	int memo_size() const { return (int)(memo_fine.size() + memo_coarse.size()); }
};

} // namespace godot
