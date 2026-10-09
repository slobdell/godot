#include "tank_native.h"

#include "nav_native.h"

#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/version.hpp>

#ifndef TANK_NATIVE_BUILD_HOST
#define TANK_NATIVE_BUILD_HOST "unknown"
#endif
#ifndef TANK_NATIVE_FLAGS
#define TANK_NATIVE_FLAGS "unknown"
#endif
#ifndef TANK_NATIVE_GODOTCPP
#define TANK_NATIVE_GODOTCPP "unknown"
#endif
#define TANK_NATIVE_REAL_T_BITS 32
static_assert(sizeof(real_t) * 8 == TANK_NATIVE_REAL_T_BITS, "single-precision godot-cpp: real_t is float32, like the engine binary");

namespace godot {

void TankNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("build_info"), &TankNative::build_info);
	ClassDB::bind_method(D_METHOD("closest_approach", "here", "velocity", "round_position", "round_velocity", "seconds"),
			&TankNative::closest_approach);
	ClassDB::bind_method(D_METHOD("would_be_hit", "here", "now", "planned", "incoming", "turn_seconds", "acceleration",
			"tick_rate"), &TankNative::would_be_hit);
	ClassDB::bind_method(D_METHOD("avoidance_load", "names", "xs", "zs", "vxs", "vzs", "radii", "half_w", "half_l", "fxs",
			"fzs", "still"), &TankNative::avoidance_load);
	ClassDB::bind_method(D_METHOD("avoidance_gather", "tanks_root", "registry", "units"), &TankNative::avoidance_gather);
	ClassDB::bind_method(D_METHOD("avoidance_columns"), &TankNative::avoidance_columns);
	ClassDB::bind_method(D_METHOD("avoidance_solve", "me", "position", "velocity", "preferred", "max_speed", "radius", "dt",
			"cap", "oriented"), &TankNative::avoidance_solve);
	ClassDB::bind_method(D_METHOD("record_gather", "tanks_root", "registry", "hulls", "cover"), &TankNative::record_gather);
	ClassDB::bind_method(D_METHOD("record_size"), &TankNative::record_size);
	ClassDB::bind_method(D_METHOD("record_find", "name"), &TankNative::record_find);
	ClassDB::bind_method(D_METHOD("record_row", "row"), &TankNative::record_row);
	ClassDB::bind_method(D_METHOD("record_neighbours", "row"), &TankNative::record_neighbours);
	ClassDB::bind_method(D_METHOD("record_name", "row"), &TankNative::record_name);
	ClassDB::bind_method(D_METHOD("record_set_command", "row", "throttle", "turn", "aim", "fire"),
			&TankNative::record_set_command);
	ClassDB::bind_method(D_METHOD("command_into", "row", "cmd"), &TankNative::command_into);
	ClassDB::bind_method(D_METHOD("contacts_gather", "team", "intel", "ranges"), &TankNative::contacts_gather);
	ClassDB::bind_method(D_METHOD("contacts_size", "team"), &TankNative::contacts_size);
	ClassDB::bind_method(D_METHOD("contacts_row", "team", "row"), &TankNative::contacts_row);
	ClassDB::bind_method(D_METHOD("record_layout"), &TankNative::record_layout);
	ClassDB::bind_method(D_METHOD("scan_nearest", "row", "reach", "sector", "sector_cos", "seen_mode", "sight_radius", "space"),
			&TankNative::scan_nearest);
	ClassDB::bind_method(D_METHOD("scan_rays"), &TankNative::scan_rays);
	ClassDB::bind_method(D_METHOD("follow_route", "here", "basis_z", "path", "path_index", "goal", "wheel_radius", "flags",
			"slack", "map", "memo_from", "memo_to", "nav"), &TankNative::follow_route);
	ClassDB::bind_method(D_METHOD("route_constants"), &TankNative::route_constants);
	ClassDB::bind_method(D_METHOD("drive_configure", "config"), &TankNative::drive_configure);
	ClassDB::bind_method(D_METHOD("drive", "mover", "cmd", "order", "delta"), &TankNative::drive);
	ClassDB::bind_method(D_METHOD("drive_profile", "reset"), &TankNative::drive_profile);
	ClassDB::bind_method(D_METHOD("situation_core", "brain", "my_position", "my_name", "squad_name", "all_allies", "intel",
			"names", "prototypes", "choice_target", "order_target", "tick", "flank_reach", "cover_map", "constants", "ai_cache",
			"game_match", "switches"),
			&TankNative::situation_core);
	ClassDB::bind_method(D_METHOD("matchups_for", "s", "units", "weapons", "constants"), &TankNative::matchups_for);
	ClassDB::bind_method(D_METHOD("matchups_constants"), &TankNative::matchups_constants);
	ClassDB::bind_method(D_METHOD("decide_configure", "config"), &TankNative::decide_configure);
	ClassDB::bind_method(D_METHOD("decide", "s", "current"), &TankNative::decide);
	ClassDB::bind_method(D_METHOD("tq_configure", "config"), &TankNative::tq_configure);
	ClassDB::bind_method(D_METHOD("tq_find_cover", "map", "request", "count"), &TankNative::tq_find_cover);
	ClassDB::bind_method(D_METHOD("tq_find_cover_fire", "map", "request"), &TankNative::tq_find_cover_fire);
	ClassDB::bind_method(D_METHOD("bench_members", "object", "names", "rounds", "write"), &TankNative::bench_members);
	ClassDB::bind_method(D_METHOD("line_of_sight", "space", "from", "to"), &TankNative::line_of_sight);
}

#define TN_STR2(x) #x
#define TN_STR(x) TN_STR2(x)

String TankNative::build_info() const {
	return String("godot-cpp " TANK_NATIVE_GODOTCPP " | api " TN_STR(GODOT_VERSION_MAJOR) "." TN_STR(GODOT_VERSION_MINOR) "."
			TN_STR(GODOT_VERSION_PATCH) " | "
#if defined(__clang__)
			"clang " __clang_version__
#elif defined(__GNUC__)
			"gcc " __VERSION__
#else
			"compiler ?"
#endif
			" | " TANK_NATIVE_FLAGS " | built on " TANK_NATIVE_BUILD_HOST " | real_t " TN_STR(TANK_NATIVE_REAL_T_BITS) " bits");
}

// The GDScript, line by line (incoming_fire.gd `closest_approach`), with each width where GDScript has it:
//   var offset := Vector3(here.x - round_position.x, 0.0, here.z - round_position.z)
//       -> the members are float32, the subtraction a GDScript float (double), the constructor stores float32.
//          Double rounding of a float32 subtraction done in double is the float32 subtraction (53 >= 2*24 + 2).
//   var relative := Vector3(velocity.x - round_velocity.x, 0.0, velocity.z - round_velocity.z)     (the same)
//   var speed_squared := relative.length_squared()           -> real_t, widened to double
//   var t := 0.0 if speed_squared < 1e-6 else clampf(-offset.dot(relative) / speed_squared, 0.0, seconds)
//       -> dot in real_t, negated and divided in double, clamped in double
//   return (offset + relative * t).length()                  -> t narrowed to real_t for the scale, length in real_t
double TankNative::closest_approach(const Vector3 &here, const Vector3 &velocity, const Vector3 &round_position,
		const Vector3 &round_velocity, double seconds) const {
	const Vector3 offset(
			(real_t)((double)here.x - (double)round_position.x), (real_t)0.0,
			(real_t)((double)here.z - (double)round_position.z));
	const Vector3 relative(
			(real_t)((double)velocity.x - (double)round_velocity.x), (real_t)0.0,
			(real_t)((double)velocity.z - (double)round_velocity.z));
	const double speed_squared = (double)relative.length_squared();
	double t = 0.0;
	if (!(speed_squared < 1e-6)) {
		const double along = -(double)offset.dot(relative) / speed_squared;
		t = along < 0.0 ? 0.0 : (along > seconds ? seconds : along);
	}
	return (double)(offset + relative * (real_t)t).length();
}

// combat_motion.gd `would_be_hit`, line by line (its constants HIT_RADIUS 2.8, DODGE_STEP 0.1, PIVOT_SECONDS 0.75):
//   var seconds := float(entry.get("eta_ticks", SimClock.TICK_RATE / 2)) / SimClock.TICK_RATE + 0.25   (double; int / int first)
//   while t < seconds: step := minf(DODGE_STEP, seconds - t)                                           (double)
//     closest_approach(position, velocity, round_at + round_velocity * t, round_velocity, step) < HIT_RADIUS (t narrowed)
//     position += velocity * step; t += step                                                          (step narrowed; t double)
//     goal := planned if t >= turn_seconds else (ZERO if turn_seconds > PIVOT_SECONDS else velocity)
//     velocity = velocity.move_toward(goal, acceleration * step)                                       (the delta narrowed)
bool TankNative::would_be_hit(const Vector3 &here, const Vector3 &now, const Vector3 &planned, const Array &incoming,
		double turn_seconds, double acceleration, int tick_rate) const {
	constexpr double HIT_RADIUS = 2.8;
	constexpr double DODGE_STEP = 0.1;
	constexpr double PIVOT_SECONDS = 0.75;
	const int64_t n = incoming.size();
	for (int64_t k = 0; k < n; k++) {
		const Dictionary entry = incoming[k];
		const Vector3 round_at = entry["position"];
		const Vector3 round_velocity = entry["velocity"];
		const Variant eta = entry.get("eta_ticks", tick_rate / 2);
		const double seconds = (double)eta / (double)tick_rate + 0.25;
		double t = 0.0;
		Vector3 position = here;
		Vector3 velocity = now;
		while (t < seconds) {
			const double remaining = seconds - t;
			const double step = DODGE_STEP < remaining ? DODGE_STEP : remaining;
			if (closest_approach(position, velocity, round_at + round_velocity * (real_t)t, round_velocity, step) < HIT_RADIUS) {
				return true;
			}
			position += velocity * (real_t)step;
			t += step;
			const Vector3 goal = t >= turn_seconds ? planned : (turn_seconds > PIVOT_SECONDS ? Vector3() : velocity);
			velocity = velocity.move_toward(goal, (real_t)(acceleration * step));
		}
	}
	return false;
}

void TankNative::avoidance_load(const PackedStringArray &names, const PackedFloat32Array &xs, const PackedFloat32Array &zs,
		const PackedFloat32Array &vxs, const PackedFloat32Array &vzs, const PackedFloat32Array &radii,
		const PackedFloat32Array &half_w, const PackedFloat32Array &half_l, const PackedFloat32Array &fxs,
		const PackedFloat32Array &fzs, const PackedByteArray &still) {
	avoidance.load(names, xs, zs, vxs, vzs, radii, half_w, half_l, fxs, fzs, still);
}

Vector3 TankNative::avoidance_solve(const String &me, const Vector2 &position, const Vector2 &velocity, const Vector2 &preferred,
		double max_speed, double radius, double dt, int cap, bool oriented) const {
	int near_count = 0;
	int oriented_count = 0;
	const Vector2 result = avoidance.solve(me, position, velocity, preferred, max_speed, radius, dt, cap, oriented, near_count, oriented_count);
	return Vector3(result.x, result.y, (real_t)(near_count + 16 * oriented_count));
}

// ---- Avoidance.refresh, gathered natively (round 24) ----
//   for child in tanks_root.get_children(): tank := child as Tank; skip null or not is_alive()
//   names, xs/zs (global_position, float32), vxs/vzs (estimated_velocity), radii (radius_of: a double stored float32),
//   half_w/half_l (the hull's halves), fxs/fzs (Vector2(-basis.z.x, -basis.z.z).normalized()), still (no mover, or
//   its phase is "arrived": not is_under_way()); the grid and the index are AvoidanceTable::load's.
PackedStringArray TankNative::avoidance_gather(Node *tanks_root, const Dictionary &registry, const Dictionary &units) {
	static const StringName alive("alive"), estimated_velocity("estimated_velocity"), unit_id("unit_id"), ctl("ctl"),
			tank_name("tank"), phase("phase");
	static const String arrived("arrived");
	PackedStringArray missing;
	if (tanks_root == nullptr) {
		return missing;
	}
	PackedStringArray names;
	PackedFloat32Array xs, zs, vxs, vzs, radii, half_w, half_l, fxs, fzs;
	PackedByteArray still;
	const int children = tanks_root->get_child_count();
	for (int i = 0; i < children; i++) {
		Node *child = tanks_root->get_child(i);
		const Variant is_alive = child->get(alive);
		if (is_alive.get_type() != Variant::BOOL || !(bool)is_alive) {
			continue;
		}
		Node3D *tank = Object::cast_to<Node3D>(child);
		if (tank == nullptr) {
			continue;
		}
		const String unit = tank->get(unit_id);
		const Variant row = units.get(unit, Variant());
		if (row.get_type() != Variant::PACKED_FLOAT64_ARRAY) {
			if (!missing.has(unit)) {
				missing.push_back(unit);
			}
			continue;
		}
		const PackedFloat64Array hull = row;
		const Transform3D xform = tank->get_global_transform();
		const Vector3 velocity = tank->get(estimated_velocity);
		const Vector3 z = xform.basis.get_column(2);
		const Vector2 heading = Vector2(-z.x, -z.z).normalized();
		names.push_back(tank->get_name());
		xs.push_back(xform.origin.x);
		zs.push_back(xform.origin.z);
		vxs.push_back(velocity.x);
		vzs.push_back(velocity.z);
		radii.push_back((float)(double)hull[0]);
		half_w.push_back((float)(double)hull[1]);
		half_l.push_back((float)(double)hull[2]);
		fxs.push_back(heading.x);
		fzs.push_back(heading.y);
		// Movement.of(tank): the registry's mover whose controller drives this tank; is_under_way() = phase != "arrived".
		bool is_still = true;
		const Variant mover_v = registry.get((int64_t)tank->get_instance_id(), Variant());
		Object *mover = mover_v.get_type() == Variant::OBJECT ? mover_v.get_validated_object() : nullptr;
		if (mover != nullptr) {
			const Variant ctl_v = mover->get(ctl);
			Object *controller = ctl_v.get_type() == Variant::OBJECT ? ctl_v.get_validated_object() : nullptr;
			if (controller != nullptr && (Object *)controller->get(tank_name) == tank) {
				is_still = String(mover->get(phase)) == arrived;
			}
		}
		still.push_back(is_still ? 1 : 0);
	}
	if (missing.is_empty()) {
		avoidance.load(names, xs, zs, vxs, vzs, radii, half_w, half_l, fxs, fzs, still);
	}
	return missing;
}

Dictionary TankNative::avoidance_columns() const {
	Dictionary d;
	d["names"] = avoidance.names;
	d["xs"] = avoidance.xs;
	d["zs"] = avoidance.zs;
	d["vxs"] = avoidance.vxs;
	d["vzs"] = avoidance.vzs;
	d["radii"] = avoidance.radii;
	d["half_w"] = avoidance.half_w;
	d["half_l"] = avoidance.half_l;
	d["fxs"] = avoidance.fxs;
	d["fzs"] = avoidance.fzs;
	d["still"] = avoidance.still;
	return d;
}

// ---- N3a: the per-tank record and the contacts table (tank_record.h) ----

PackedStringArray TankNative::record_gather(Node *tanks_root, const Dictionary &registry, const Dictionary &hulls,
		int64_t cover) {
	PackedStringArray missing;
	records.gather(tanks_root, registry, hulls, cover, missing);
	return missing;
}

PackedStringArray TankNative::record_neighbours(int r) const {
	LocalVector<int32_t> rows;
	records.neighbours(r, avoidance, AvoidanceTable::MAX_NEIGHBOURS, rows);
	PackedStringArray out;
	for (uint32_t k = 0; k < rows.size(); k++) {
		out.push_back(rows[k] >= 0 ? records.names[rows[k]] : String());
	}
	return out;
}

int TankNative::record_find(const String &name) const {
	const int32_t *row = records.index.getptr(name);
	return row != nullptr ? *row : -1;
}

void TankNative::record_set_command(int r, double throttle, double turn, const Vector3 &aim, bool fire) {
	if (r < 0 || r >= records.size()) {
		return;
	}
	records.out_throttle[r] = throttle;
	records.out_turn[r] = turn;
	records.out_aim[r] = aim;
	records.out_fire[r] = fire;
}

// TankCommand built natively: the row's command written into the controller's TankCommand (four property sets in
// C++, one call from GDScript), the same values a GDScript `cmd.throttle = ...` would store.
void TankNative::command_into(int r, Object *cmd) const {
	if (cmd == nullptr || r < 0 || r >= records.size()) {
		return;
	}
	static const StringName throttle("throttle"), turn("turn"), aim_point("aim_point"), fire("fire");
	cmd->set(throttle, records.out_throttle[r]);
	cmd->set(turn, records.out_turn[r]);
	cmd->set(aim_point, records.out_aim[r]);
	cmd->set(fire, records.out_fire[r] != 0);
}

PackedStringArray TankNative::contacts_gather(int team, const Dictionary &intel, const Dictionary &ranges) {
	PackedStringArray missing;
	if (team >= 0 && team <= 1) {
		contacts[team].gather(intel, ranges, missing);
	}
	return missing;
}

int TankNative::contacts_size(int team) const {
	return (team < 0 || team > 1) ? 0 : contacts[team].size();
}

Dictionary TankNative::contacts_row(int team, int r) const {
	return (team < 0 || team > 1) ? Dictionary() : contacts[team].row(r);
}

Dictionary TankNative::record_layout() const {
	Dictionary d;
	d["f32"] = (int)RecordLayout::F32_STRIDE;
	d["f64"] = (int)RecordLayout::F64_STRIDE;
	d["i32"] = (int)RecordLayout::I32_STRIDE;
	d["contact_f32"] = (int)ContactLayout::F32_STRIDE;
	d["contact_f64"] = (int)ContactLayout::F64_STRIDE;
	d["contact_i32"] = (int)ContactLayout::I32_STRIDE;
	return d;
}

// ---- N3b: weapon.scan (gunnery.gd _nearest_shootable / _shootable; perception.gd has_line_of_sight) ----

// Perception.has_line_of_sight: a ray between the two eye points against the static world (WORLD_MASK 1).
//   PhysicsRayQueryParameters3D.create(viewer + Vector3.UP * EYE_HEIGHT, target + Vector3.UP * EYE_HEIGHT, WORLD_MASK)
//   -> Vector3.UP * 1.3 narrows the scalar to float32 and the sum is float32: the same here. The query's other
//      parameters are create()'s defaults in both.
bool TankNative::line_of_sight(const RID &space, const Vector3 &from, const Vector3 &to) const {
	static const real_t EYE_HEIGHT = (real_t)1.3;
	PhysicsDirectSpaceState3D *state = PhysicsServer3D::get_singleton()->space_get_direct_state(space);
	if (state == nullptr) {
		return true;
	}
	const Vector3 up = Vector3(0, 1, 0) * EYE_HEIGHT;
	Ref<PhysicsRayQueryParameters3D> query = PhysicsRayQueryParameters3D::create(from + up, to + up, 1);
	return state->intersect_ray(query).is_empty();
}

// Gunnery._nearest_shootable, line by line (the record's rows of the other team are AiTickCache.enemy_columns: the
// living hulls under tanks_root in scene order):
//   var distance := here.distance_to(there)              -> real_t, widened to double
//   if distance >= best_distance and (sector == Vector3.ZERO or distance >= in_sector_distance): continue
//   if distance > reach or not _shootable(enemy): continue
//   (_shootable: the same distance > range; Engagement.is_seen; Perception.has_line_of_sight)
//   if distance < best_distance: best = enemy ...
//   if sector != ZERO and distance < in_sector_distance:
//       toward := there - here; toward.y = 0.0
//       if toward.length_squared() > 0.01 and toward.normalized().dot(sector) >= sector_cos: in_sector = enemy ...
int TankNative::scan_nearest(int row, double reach, const Vector3 &sector, double sector_cos, int seen_mode,
		double sight_radius, const RID &space) {
	last_scan_rays = 0;
	if (row < 0 || row >= records.size()) {
		return -1;
	}
	const float *pf = records.f32.ptr();
	const int32_t *pi = records.i32.ptr();
	const int fs = RecordLayout::F32_STRIDE;
	const int is = RecordLayout::I32_STRIDE;
	const Vector3 here(pf[row * fs + RecordLayout::POS], pf[row * fs + RecordLayout::POS + 1], pf[row * fs + RecordLayout::POS + 2]);
	const int32_t team = pi[row * is + RecordLayout::TEAM];
	const ContactsTable &intel = contacts[team == 0 ? 0 : 1];
	const bool has_sector = sector != Vector3();
	int best = -1;
	double best_distance = INFINITY;
	int in_sector = -1;
	double in_sector_distance = INFINITY;
	const int n = records.size();
	for (int e = 0; e < n; e++) {
		if (pi[e * is + RecordLayout::TEAM] == team) {
			continue;
		}
		const Vector3 there(pf[e * fs + RecordLayout::POS], pf[e * fs + RecordLayout::POS + 1], pf[e * fs + RecordLayout::POS + 2]);
		const double distance = (double)here.distance_to(there);
		if (distance >= best_distance && (!has_sector || distance >= in_sector_distance)) {
			continue;
		}
		if (distance > reach) {
			continue;
		}
		bool seen = true;
		if (seen_mode == 1) {
			// Match.is_visible_to(team, enemy): a living enemy whose intel entry says visible.
			const int32_t *c = intel.index.getptr(records.names[e]);
			seen = c != nullptr && intel.i32[*c * ContactLayout::I32_STRIDE + ContactLayout::VISIBLE] != 0;
		} else if (seen_mode == 2) {
			seen = distance <= sight_radius;
		}
		if (!seen) {
			continue;
		}
		last_scan_rays++;
		if (!line_of_sight(space, here, there)) {
			continue;
		}
		if (distance < best_distance) {
			best = e;
			best_distance = distance;
		}
		if (has_sector && distance < in_sector_distance) {
			Vector3 toward = there - here;
			toward.y = 0;
			if ((double)toward.length_squared() > 0.01 && (double)toward.normalized().dot(sector) >= sector_cos) {
				in_sector = e;
				in_sector_distance = distance;
			}
		}
	}
	return in_sector >= 0 ? in_sector : best;
}

double TankNative::bench_members(Object *object, const PackedStringArray &names, int rounds, bool write) const {
	if (object == nullptr) {
		return 0.0;
	}
	LocalVector<StringName> keys;
	for (int i = 0; i < names.size(); i++) {
		keys.push_back(StringName(names[i]));
	}
	double sum = 0.0;
	for (int r = 0; r < rounds; r++) {
		for (uint32_t i = 0; i < keys.size(); i++) {
			const Variant v = object->get(keys[i]);
			if (v.get_type() == Variant::FLOAT || v.get_type() == Variant::INT) {
				sum += (double)v;
			}
			if (write) {
				object->set(keys[i], v);
			}
		}
	}
	return sum;
}

bool TankNative::drive_configure(const Dictionary &config) {
	DriveConfig &c = drive_config;
	const char *doubles[] = { "NEW_GOAL_JUMP", "WAYPOINT_MIN_M", "GIVE_WAY_PACE", "STATION_RANGE", "STATION_MIN_SPEED",
		"ASK_SECONDS", "ASK_EVERY_SECONDS", "AVOID_ASK_PACE", "BLOCKED_SECONDS", "UNREACHABLE_AT_END", "OFF_PATH_REPATH",
		"REPATH_SECONDS", "NO_PATH_MARGIN", "STATION_STALE_SECONDS", "STATION_STOPPED_SECONDS", "WEDGED_SHARE",
		"PATH_LOOKAHEAD", "WHEELS_LOOKAHEAD_RADII", "CARROT_ALIGNED_COS", "WHEELS_LOOKAHEAD_MAX_RADII", "CARROT_PULLBACK_0",
		"CARROT_PULLBACK_1", "ARRIVE_RADIUS", "FULL_TURN_ERROR_DEG", "TURN_IN_PLACE_DEG", "SLOW_RADIUS",
		"WHEELS_CIRCLE_MARGIN", "WHEELS_FULL_LOCK_DEG", "WHEELS_REVERSE_THROTTLE", "WHEELS_MIN_THROTTLE", "AVOID_STEER_MIN",
		"AVOID_STEER_MAX", "AVOID_MESH_PROBE", "AVOID_MESH_SLACK", "AVOID_MIN_PACE", "CHORD_SLACK", "CHORD_MARGIN", "APPROACH_RADII", "APPROACH_MIN", "APPROACH_MAX",
		"APPROACH_ALIGNED_COS", "MESH_GATE_SLACK", "GATE_REACHED", "OFF_MESH_PROBE_0", "OFF_MESH_PROBE_1", "OFF_MESH_PROBE_2", "KTURN_THROTTLE", "KTURN_SECONDS_PER_M",
		"KTURN_INTO_WALL_COS", "KTURN_ROLLING_SPEED", "KTURN_BRAKE_HULL_M" };
	double *targets[] = { &c.NEW_GOAL_JUMP, &c.WAYPOINT_MIN_M, &c.GIVE_WAY_PACE, &c.STATION_RANGE, &c.STATION_MIN_SPEED,
		&c.ASK_SECONDS, &c.ASK_EVERY_SECONDS, &c.AVOID_ASK_PACE, &c.BLOCKED_SECONDS, &c.UNREACHABLE_AT_END,
		&c.OFF_PATH_REPATH, &c.REPATH_SECONDS, &c.NO_PATH_MARGIN, &c.STATION_STALE_SECONDS, &c.STATION_STOPPED_SECONDS,
		&c.WEDGED_SHARE, &c.PATH_LOOKAHEAD, &c.WHEELS_LOOKAHEAD_RADII, &c.CARROT_ALIGNED_COS, &c.WHEELS_LOOKAHEAD_MAX_RADII,
		&c.CARROT_PULLBACK_0, &c.CARROT_PULLBACK_1, &c.ARRIVE_RADIUS, &c.FULL_TURN_ERROR_DEG, &c.TURN_IN_PLACE_DEG,
		&c.SLOW_RADIUS, &c.WHEELS_CIRCLE_MARGIN, &c.WHEELS_FULL_LOCK_DEG, &c.WHEELS_REVERSE_THROTTLE, &c.WHEELS_MIN_THROTTLE,
		&c.AVOID_STEER_MIN, &c.AVOID_STEER_MAX, &c.AVOID_MESH_PROBE, &c.AVOID_MESH_SLACK, &c.AVOID_MIN_PACE, &c.CHORD_SLACK,
		&c.CHORD_MARGIN, &c.APPROACH_RADII, &c.APPROACH_MIN, &c.APPROACH_MAX, &c.APPROACH_ALIGNED_COS, &c.MESH_GATE_SLACK,
		&c.GATE_REACHED, &c.OFF_MESH_PROBES[0], &c.OFF_MESH_PROBES[1], &c.OFF_MESH_PROBES[2], &c.KTURN_THROTTLE,
		&c.KTURN_SECONDS_PER_M, &c.KTURN_INTO_WALL_COS, &c.KTURN_ROLLING_SPEED, &c.KTURN_BRAKE_HULL_M };
	for (size_t i = 0; i < sizeof(doubles) / sizeof(doubles[0]); i++) {
		if (!config.has(doubles[i])) {
			c.ready = false;
			return false;
		}
		*targets[i] = config[doubles[i]];
	}
	const char *ints[] = { "GIVE_WAY_AFTER_TICKS", "GIVE_WAY_TICKS", "AVOID_GRACE_TICKS", "WEDGED_WINDOW", "TICK_RATE",
		"FIRE_CHECK_TICKS", "KTURN_RETRY_TICKS" };
	int64_t *int_targets[] = { &c.GIVE_WAY_AFTER_TICKS, &c.GIVE_WAY_TICKS, &c.AVOID_GRACE_TICKS, &c.WEDGED_WINDOW, &c.TICK_RATE,
		&c.FIRE_CHECK_TICKS, &c.KTURN_RETRY_TICKS };
	for (size_t i = 0; i < sizeof(ints) / sizeof(ints[0]); i++) {
		if (!config.has(ints[i])) {
			c.ready = false;
			return false;
		}
		*int_targets[i] = config[ints[i]];
	}
	c.keep_pathing = config.get("pathing", Variant());
	c.keep_levers = config.get("levers", Variant());
	c.keep_tank_command = config.get("tank_command", Variant());
	c.keep_nav = config.get("nav", Variant());
	c.keep_avoidance = config.get("avoidance", Variant());
	c.keep_switches = config.get("switches", Variant());
	c.avoidance_script = c.keep_avoidance.get_validated_object();
	c.switches = c.keep_switches.get_validated_object();
	c.avoidance = &avoidance;
	c.radius_of.clear();
	c.settle_of.clear();
	c.hull_length_of.clear();
	c.hull_width_of.clear();
	c.braking_of.clear();
	c.levers_frame = -1;
	c.pathing = c.keep_pathing.get_validated_object();
	c.levers = c.keep_levers.get_validated_object();
	c.tank_command = c.keep_tank_command.get_validated_object();
	c.nav = Object::cast_to<NavNative>(c.keep_nav.get_validated_object());
	c.ready = c.pathing != nullptr && c.levers != nullptr && c.tank_command != nullptr && c.nav != nullptr &&
			c.avoidance_script != nullptr && c.switches != nullptr;
	return c.ready;
}

Dictionary TankNative::drive_profile(bool reset) const {
	return godot::drive_profile(reset);
}

bool TankNative::drive(Object *mover, Object *cmd, const Dictionary &order, double delta) const {
	return drive_native(drive_config, mover, cmd, order, delta);
}

} // namespace godot
