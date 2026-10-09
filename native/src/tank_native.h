// Tank Squad native (round 23, stream native): the vehicle brain's hot loop in C++ through godot-cpp.
//
// Every function here is a PORT of a GDScript function and must give the SAME BITS (_agents/native.md, "The proof"):
// `real_t` (float32) where GDScript has Vector math, `double` where it has `float`, and the same rounding points in
// the same order. Nothing here may change a decision: the switch `BrainSwitches.native` runs either path and the
// match hash is the proof.
#pragma once

#include "avoidance.h"
#include "decide_native.h"
#include "drive_native.h"
#include "el_native.h"
#include "tq_native.h"
#include "tank_record.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class NavNative;

class TankNative : public RefCounted {
	GDCLASS(TankNative, RefCounted)

protected:
	static void _bind_methods();

public:
	TankNative() = default;
	~TankNative() override = default;

	// What this library is: godot-cpp version, compiler, flags and the host it was built on (make doctor, the test).
	String build_info() const;

	// IncomingFire.closest_approach (game/ai/incoming_fire.gd): where a unit at `here` driving at `velocity` would be
	// closest to a round (position, velocity) within `seconds`, in meters. The no-op of N0: the call's own price.
	double closest_approach(const Vector3 &here, const Vector3 &velocity, const Vector3 &round_position,
			const Vector3 &round_velocity, double seconds) const;

	// CombatMotion.would_be_hit (N0b): the whole dodge loop as ONE call (every incoming round, every DODGE_STEP, the
	// closest approach inside each step), where N0 showed one call per step costs more than the step.
	bool would_be_hit(const Vector3 &here, const Vector3 &now, const Vector3 &planned, const Array &incoming,
			double turn_seconds, double acceleration, int tick_rate) const;

	// Avoidance (N1): `Avoidance.refresh` / `load_rows` load this tick's columns; `Avoidance.solve` asks per mover.
	// The answer is (x, y) of the Vector3; z packs the probe counters: neighbours solved against + 16 * oriented pairs.
	void avoidance_load(const PackedStringArray &names, const PackedFloat32Array &xs, const PackedFloat32Array &zs,
			const PackedFloat32Array &vxs, const PackedFloat32Array &vzs, const PackedFloat32Array &radii,
			const PackedFloat32Array &half_w, const PackedFloat32Array &half_l, const PackedFloat32Array &fxs,
			const PackedFloat32Array &fzs, const PackedByteArray &still);
	// Round 24: Avoidance.refresh's table gathered by the C++ (the same hulls, order and widths as the GDScript build):
	// `units` {unit_id: PackedFloat64Array[radius_of, half_w, half_l]}; returns the unit ids missing from it (the caller
	// adds them and gathers again). `avoidance_columns` hands the columns back for the GDScript readers.
	PackedStringArray avoidance_gather(Node *tanks_root, const Dictionary &registry, const Dictionary &units);
	Dictionary avoidance_columns() const;
	Vector3 avoidance_solve(const String &me, const Vector2 &position, const Vector2 &velocity, const Vector2 &preferred,
			double max_speed, double radius, double dt, int cap, bool oriented) const;

	// N3a (round 24): the per-tank record and the per-team contacts table, filled once a tick by
	// game/ai/native/native_record.gd (one call each) and read by the ported execute step. `record_row` /
	// `contacts_row` read a row back for the test; `command_into` writes a row's command into a TankCommand.
	// The record gathered by the C++ (a member read is 0.03 usec from here): returns the unit ids whose hull numbers
	// NativeRecord must add to `hulls` before gathering again (empty: the record is complete).
	PackedStringArray record_gather(Node *tanks_root, const Dictionary &registry, const Dictionary &hulls, int64_t cover);
	int record_size() const { return records.size(); }
	int record_find(const String &name) const;
	Dictionary record_row(int r) const { return records.row(r); }
	PackedStringArray record_neighbours(int r) const;
	String record_name(int r) const { return (r < 0 || r >= records.size()) ? String() : records.names[r]; }
	void record_set_command(int r, double throttle, double turn, const Vector3 &aim, bool fire);
	void command_into(int r, Object *cmd) const;
	// One team's contacts from its intel Dictionary: returns the weapon ids NativeRecord must add to `ranges`.
	PackedStringArray contacts_gather(int team, const Dictionary &intel, const Dictionary &ranges);
	int contacts_size(int team) const;
	Dictionary contacts_row(int team, int r) const;
	// N3b (weapon.scan): Gunnery._nearest_shootable over the record, as ONE call: the shooter's row, its weapon's
	// reach, the order's sector (Vector3.ZERO = none) and sector_cos, how "seen" is judged (0 acquisition off, 1 the
	// team's intel: Match.is_visible_to over this tick's contacts table, 2 the shooter's own sight radius), and the
	// physics space for the sight line (Perception.has_line_of_sight's ray, cast through the same engine call).
	// Returns the picked row (-1: none); `scan_rays()` says how many rays the last scan cast.
	int scan_nearest(int row, double reach, const Vector3 &sector, double sector_cos, int seen_mode, double sight_radius,
			const RID &space);
	int scan_rays() const { return last_scan_rays; }
	bool line_of_sight(const RID &space, const Vector3 &from, const Vector3 &to) const;

	// N3b (move.path): the route-following tail of Movement._next_waypoint as one call (route_native.cpp).
	PackedFloat32Array follow_route(const Vector3 &here, const Vector3 &basis_z, const PackedVector3Array &path,
			int path_index, const Vector3 &goal, double wheel_radius, int flags, double slack, const RID &map,
			const Vector3 &memo_from, const Vector3 &memo_to, Object *nav);
	PackedFloat64Array route_constants() const;
	struct RouteChord {
		class NavNative *nav = nullptr;
		RID map;
		bool ready = false, valid = false, answer = true;
		Vector3 memo_from, memo_to;
		double slack = 0.0;
		PackedFloat64Array samples;
		int computed = 0;
		bool on_mesh(const Vector3 &from, const Vector3 &to);
	};

	// N3c: Movement.drive as one call (drive_native.cpp). `drive_configure` takes the live constants and scripts once
	// (NativeDrive.configure); `drive` runs one tick's drive on the mover's members, false if not configured.
	bool drive_configure(const Dictionary &config);
	bool drive(Object *mover, Object *cmd, const Dictionary &order, double delta) const;
	Dictionary drive_profile(bool reset) const;
	Vector3 drive_around_fire(Object *mover, const Vector3 &waypoint, const Vector3 &goal, const Dictionary &order) const;
	bool drive_fire_ready() const;

	// N3d: build_situation's allies, contact selection and contact entries as one call (situation_native.cpp).
	Array situation_core(Object *brain, const Vector3 &my_position, const String &my_name, const Variant &squad_name,
			const Array &all_allies, const Dictionary &intel, const Array &names, const Dictionary &prototypes,
			const Variant &choice_target, const Variant &order_target, int64_t tick, double flank_reach, Object *cover_map,
			const PackedFloat64Array &constants, Object *ai_cache, Object *game_match, Object *switches) const;

	// N3d: TankBrain.matchups_for with Matchups' and Armor.facing's math (matchups_native.cpp).
	Dictionary matchups_for(const Dictionary &s, Object *units, Object *weapons, const PackedFloat64Array &constants) const;
	PackedFloat64Array matchups_constants() const;

	// N3d: TankBrain.decide (decide_native.cpp), the default arm (flat commitment, no switch probe).
	bool decide_configure(const Dictionary &config);
	Dictionary decide(const Dictionary &s, const Dictionary &current) const;

	// C24.6: TacticalQuery.find_cover / find_cover_fire (tq_native.cpp) over a CoverMap with its native twin.
	bool tq_configure(const Dictionary &config);
	Array tq_find_cover(Object *map, const Dictionary &request, int count) const;
	Dictionary tq_find_cover_fire(Object *map, const Dictionary &request) const;

	// C24.8: SlotGround's water rules (el_native.cpp) over the terrain handed over by el_terrain: `boxes` four floats
	// a rectangle (ArenaTerrain.bounds), `kinds` bit 0 carves, bit 1 deck; `steps` [WET_STEP_M, DRY_MARGIN_M,
	// MOUTH_CLEAR_M].
	void el_terrain(const PackedFloat32Array &boxes, const PackedByteArray &kinds, const PackedFloat64Array &steps);
	Vector3 el_on_anchor_side(const Vector3 &slot, const Vector3 &anchor) const;
	Vector3 el_pulled_dry(const Vector3 &point, const Vector3 &toward) const;
	// ...and SlotGround.standable_for over NavNative `nav` (its guards are NativeEl's): `consts` [TOLERANCE_M,
	// PROBE_TOLERANCE_M, CLEARANCE_PROBES, CLEARANCE_ITERATIONS, FIT_RINGS, GROUND_MEMO_LIMIT].
	bool el_configure(const PackedFloat64Array &consts);
	Vector3 el_standable_for(Object *nav, const RID &map, int64_t iteration, const Vector3 &point, double clearance,
			double bake_radius);

	// Bench only (make native-bench): read every named member of `object` `rounds` times through Object::get, and
	// write it back through Object::set; returns a checksum so nothing is optimised away. Sizes N3c's state sync.
	double bench_members(Object *object, const PackedStringArray &names, int rounds, bool write) const;

	// The column strides, so native_record.gd can assert its constants against the library it talks to.
	Dictionary record_layout() const;

private:
	AvoidanceTable avoidance;
	TankRecords records;
	ContactsTable contacts[2];
	int last_scan_rays = 0;
	DriveConfig drive_config;
	DecideConsts decide_consts;
	TqConsts tq_consts;
	ElTerrain el_terrain_table;
	ElGround el_ground;
};

} // namespace godot
