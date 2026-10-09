// Round 24 (native, N3a): the data the C++ owns for the per-vehicle tick. One record per living hull (the columns
// game/ai/native/native_record.gd fills ONCE a tick in one call) and one contacts table per team (the match's intel,
// one call per team). N3b/N3c read these instead of `ctl.tank.*` and Dictionaries; N3a only stores them and reads them
// back, so the test can hold every field equal to the live value it came from (tests/test_native_record.gd).
//
// Widths: what is float32 in the engine (Vector3 members) is stored float32; what is a GDScript `float` (tank.speed(),
// the command's throttle and turn, the hull's radii) is stored double. Nothing is converted on the way in, so a
// reader gets the bits the GDScript would have read.
#pragma once

#include "avoidance.h"

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

// The column layout. native_record.gd has the same numbers (NativeRecord.F32 / F64 / I32); `load` refuses a call
// whose sizes disagree, so the two cannot drift silently.
struct RecordLayout {
	// float32, per row: position, forward (-basis.z), estimated velocity, the last command's aim point, the turret's
	// forward.
	enum F32 { POS = 0, FWD = 3, VEL = 6, AIM = 9, TURRET = 12, F32_STRIDE = 15 };
	// double, per row: tank.speed(), the last command's throttle and turn, max_forward_speed, hull_turn_rate,
	// Avoidance.radius_of, the hull's half width and half length (Avoidance's halves), Movement.wheel_radius().
	enum F64 { SPEED = 0, THROTTLE, TURN, MAX_SPEED, TURN_RATE, RADIUS, HALF_W, HALF_L, WHEEL_R, F64_STRIDE };
	// int, per row: team, health, the last command's fire, the route's next point (Movement._path_index).
	enum I32 { TEAM = 0, HEALTH, FIRE, PATH_INDEX, I32_STRIDE };
};

struct TankRecords {
	PackedStringArray names, units;
	PackedFloat32Array f32;
	PackedFloat64Array f64;
	PackedInt32Array i32;
	// The routes, concatenated: row r's route is route_points[route_offsets[r] .. route_offsets[r + 1]).
	PackedVector3Array route_points;
	PackedInt32Array route_offsets;
	// The neighbour set: rows of this table, Avoidance.neighbours' answer (nearest first, ties by name), capped at
	// AvoidanceTable::MAX_NEIGHBOURS; row r's are neighbours[neighbour_offsets[r] .. neighbour_offsets[r + 1]).
	LocalVector<int32_t> neighbours;
	LocalVector<int32_t> neighbour_offsets;
	// The cover map's handle: the instance id of this arena's CoverNative (0 = none).
	int64_t cover = 0;
	HashMap<String, int32_t> index;
	// The command each row is given this tick (N3c writes it; `command_into` hands it to a TankCommand).
	LocalVector<double> out_throttle, out_turn;
	LocalVector<Vector3> out_aim;
	LocalVector<uint8_t> out_fire;

	int size() const { return names.size(); }
	// false (and nothing kept) when a column's size disagrees with the layout.
	bool load(const PackedStringArray &p_names, const PackedStringArray &p_units, const PackedFloat32Array &p_f32,
			const PackedFloat64Array &p_f64, const PackedInt32Array &p_i32, const PackedVector3Array &p_route_points,
			const PackedInt32Array &p_route_offsets, int64_t p_cover, const AvoidanceTable &avoidance);
	Dictionary row(int r) const;
};

// One team's contacts: the match's intel for that team, one row per contact in name order (AiTickCache.intel_names'
// order), the raw fields only. The per-team derived fields (gun_ready_in, the faded suppression) are built where
// the prototypes are, by think (N3d).
struct ContactLayout {
	enum F32 { POS = 0, VEL = 3, FWD = 6, TURRET = 9, F32_STRIDE = 12 };
	enum F64 { SUPPRESSION = 0, WEAPON_RANGE, F64_STRIDE };
	enum I32 { HEALTH = 0, SHIELD, VISIBLE, SEEN_TICK, I32_STRIDE };
};

struct ContactsTable {
	PackedStringArray names, units, weapons, roles;
	PackedFloat32Array f32;
	PackedFloat64Array f64;
	PackedInt32Array i32;
	HashMap<String, int32_t> index;

	int size() const { return names.size(); }
	bool load(const PackedStringArray &p_names, const PackedStringArray &p_units, const PackedStringArray &p_weapons,
			const PackedStringArray &p_roles, const PackedFloat32Array &p_f32, const PackedFloat64Array &p_f64,
			const PackedInt32Array &p_i32);
	Dictionary row(int r) const;
};

} // namespace godot
