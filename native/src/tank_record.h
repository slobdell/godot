// Round 24 (native, N3a): the data the C++ owns for the per-vehicle tick. One record per living hull (the columns
// the C++ gathers ONCE a tick: TankNative.record_gather, called by game/ai/native/native_record.gd) and one contacts table per team (the match's intel,
// one call per team). N3b/N3c read these instead of `ctl.tank.*` and Dictionaries; N3a only stores them and reads them
// back, so the test can hold every field equal to the live value it came from (tests/test_native_record.gd).
//
// Widths: what is float32 in the engine (Vector3 members) is stored float32; what is a GDScript `float` (tank.speed(),
// the command's throttle and turn, the hull's radii) is stored double. Nothing is converted on the way in, so a
// reader gets the bits the GDScript would have read.
#pragma once

#include "avoidance.h"

#include <godot_cpp/classes/node.hpp>
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
	// The cover map's handle: the instance id of this arena's CoverNative (0 = none).
	int64_t cover = 0;
	HashMap<String, int32_t> index;
	// The command each row is given this tick (N3c writes it; `command_into` hands it to a TankCommand).
	LocalVector<double> out_throttle, out_turn;
	LocalVector<Vector3> out_aim;
	LocalVector<uint8_t> out_fire;

	int size() const { return names.size(); }
	Dictionary row(int r) const;
	// The same columns gathered by the C++ itself (round 24: GDScript packing cost ~12 usec a row; a member read from
	// C++ is 0.03 usec): every living Tank under `root` in scene order (Avoidance.refresh's filter), each read the way
	// the GDScript reads it. `registry` is Movement._registry (Movement.of's lookup), `hulls` {unit_id:
	// PackedFloat64Array[radius, half_w, half_l, wheel_radius]} from NativeRecord (a unit id not in it is returned in
	// `missing` and its row's hull numbers are 0: the caller adds it and gathers again).
	bool gather(Node *root, const Dictionary &registry, const Dictionary &hulls, int64_t p_cover, PackedStringArray &missing);
	// The neighbour set of row r, asked when it is needed (as the GDScript asks Avoidance.neighbours): the avoidance
	// table's answer at that moment, nearest first, ties by name, as rows of this table (-1: not in this table).
	void neighbours(int r, const AvoidanceTable &avoidance, int cap, LocalVector<int32_t> &out) const;
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
	// From the match's intel Dictionary directly, in name order; `ranges` {weapon id: float range} from NativeRecord
	// (a weapon id not in it is returned in `missing`, its range 0: the caller adds it and gathers again).
	void gather(const Dictionary &intel, const Dictionary &ranges, PackedStringArray &missing);
	Dictionary row(int r) const;
};

} // namespace godot
