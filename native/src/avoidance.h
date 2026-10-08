// Avoidance (ORCA) native: the port of game/ai/avoidance.gd `neighbours` + `solve` + `_program1/2/3` (round 23, N1).
// The GDScript stays as the reference; `Avoidance.refresh` / `load_rows` hand this table the same columns once a tick
// and `Avoidance.solve` routes here while BrainSwitches.native is on. Same bits: Vector2 math in real_t (float32)
// where GDScript has Vector2 math, double where GDScript has `float` (every scalar, and `_det`, whose products are
// of float32 members read as doubles).
#pragma once

#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>

namespace godot {

struct AvoidanceTable {
	// Avoidance.gd's constants, verbatim.
	static constexpr double TIME_HORIZON = 2.0;
	static constexpr int MAX_NEIGHBOURS = 6;
	static constexpr double NEIGHBOUR_RADIUS = 14.0;
	static constexpr double CELL = 8.0;
	static constexpr double RADIUS_MARGIN = 0.25;
	static constexpr double EPSILON = 0.00001;

	PackedStringArray names;
	PackedFloat32Array xs, zs, vxs, vzs, radii, half_w, half_l, fxs, fzs;
	PackedByteArray still;
	HashMap<Vector2i, LocalVector<int32_t>> grid; // cell -> row indices, in table order (like _grid's PackedInt32Array)
	HashMap<String, int32_t> index;

	struct Near {
		double d;
		String name;
		int32_t i;
	};

	void load(const PackedStringArray &p_names, const PackedFloat32Array &p_xs, const PackedFloat32Array &p_zs,
			const PackedFloat32Array &p_vxs, const PackedFloat32Array &p_vzs, const PackedFloat32Array &p_radii,
			const PackedFloat32Array &p_half_w, const PackedFloat32Array &p_half_l, const PackedFloat32Array &p_fxs,
			const PackedFloat32Array &p_fzs, const PackedByteArray &p_still);
	// Avoidance.neighbours with BrainSwitches.avoid_neighbours (the insertion form; the same list the sort gave).
	void neighbours(const String &me, double x, double z, int cap, LocalVector<Near> &found) const;
	double pair_radius(int a, int b, const Vector2 &d) const;
	double support(int i, const Vector2 &d) const;
	// Avoidance.solve; `near_count` reports how many neighbours it solved against (0 = `preferred` returned untouched)
	// and `oriented_count` how many pairs took the oriented radius (Avoidance.oriented_pairs, a probe counter).
	Vector2 solve(const String &me, const Vector2 &position, const Vector2 &velocity, const Vector2 &preferred,
			double max_speed, double radius, double dt, int cap, bool oriented, int &near_count, int &oriented_count) const;

	static double det(const Vector2 &a, const Vector2 &b) {
		// GDScript: a.x * b.y - a.y * b.x, each member read as a float (double).
		return (double)a.x * (double)b.y - (double)a.y * (double)b.x;
	}
	static bool program1(const LocalVector<Vector2> &points, const LocalVector<Vector2> &directions, int n,
			double radius, const Vector2 &optimal, bool direction_opt, Vector2 &holder);
	static int program2(const LocalVector<Vector2> &points, const LocalVector<Vector2> &directions, double radius,
			const Vector2 &optimal, bool direction_opt, Vector2 &holder);
	static Vector2 program3(const LocalVector<Vector2> &points, const LocalVector<Vector2> &directions, int begin,
			double radius, Vector2 result);
};

} // namespace godot
