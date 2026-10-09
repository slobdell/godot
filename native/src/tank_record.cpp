#include "tank_record.h"

#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

bool TankRecords::load(const PackedStringArray &p_names, const PackedStringArray &p_units, const PackedFloat32Array &p_f32,
		const PackedFloat64Array &p_f64, const PackedInt32Array &p_i32, const PackedVector3Array &p_route_points,
		const PackedInt32Array &p_route_offsets, int64_t p_cover) {
	const int n = p_names.size();
	if (p_units.size() != n || p_f32.size() != n * RecordLayout::F32_STRIDE || p_f64.size() != n * RecordLayout::F64_STRIDE ||
			p_i32.size() != n * RecordLayout::I32_STRIDE || p_route_offsets.size() != n + 1 ||
			p_route_offsets[0] != 0 || p_route_offsets[n] != p_route_points.size()) {
		UtilityFunctions::push_error("TankNative.record_load: the columns disagree with the layout (native_record.gd and tank_record.h must match)");
		return false;
	}
	for (int r = 0; r < n; r++) {
		if (p_route_offsets[r] > p_route_offsets[r + 1]) {
			UtilityFunctions::push_error("TankNative.record_load: route offsets must not decrease");
			return false;
		}
	}
	// Packed arrays are copy-on-write: these hold the caller's buffers, no copy.
	names = p_names;
	units = p_units;
	f32 = p_f32;
	f64 = p_f64;
	i32 = p_i32;
	route_points = p_route_points;
	route_offsets = p_route_offsets;
	cover = p_cover;
	index.clear();
	index.reserve(n);
	for (int r = 0; r < n; r++) {
		index.insert(names[r], r);
	}
	out_throttle.resize(n);
	out_turn.resize(n);
	out_aim.resize(n);
	out_fire.resize(n);
	const float *pf = f32.ptr();
	const double *pd = f64.ptr();
	const int32_t *pi = i32.ptr();
	for (int r = 0; r < n; r++) {
		// Until N3c writes it, this tick's command is the last one (what the tank holds).
		out_throttle[r] = pd[r * RecordLayout::F64_STRIDE + RecordLayout::THROTTLE];
		out_turn[r] = pd[r * RecordLayout::F64_STRIDE + RecordLayout::TURN];
		const float *aim = pf + r * RecordLayout::F32_STRIDE + RecordLayout::AIM;
		out_aim[r] = Vector3(aim[0], aim[1], aim[2]);
		out_fire[r] = pi[r * RecordLayout::I32_STRIDE + RecordLayout::FIRE] != 0;
	}
	return true;
}

void TankRecords::neighbours(int r, const AvoidanceTable &avoidance, int cap, LocalVector<int32_t> &out) const {
	out.clear();
	if (r < 0 || r >= size()) {
		return;
	}
	LocalVector<AvoidanceTable::Near> found;
	const float *pf = f32.ptr() + r * RecordLayout::F32_STRIDE + RecordLayout::POS;
	// Avoidance.neighbours(name, position.x, position.z): the float32 members read as GDScript floats.
	avoidance.neighbours(names[r], (double)pf[0], (double)pf[2], cap, found);
	for (uint32_t k = 0; k < found.size(); k++) {
		const int32_t *row = index.getptr(found[k].name);
		out.push_back(row != nullptr ? *row : -1);
	}
}

static Vector3 vec3_at(const PackedFloat32Array &column, int at) {
	return Vector3(column[at], column[at + 1], column[at + 2]);
}

Dictionary TankRecords::row(int r) const {
	Dictionary d;
	if (r < 0 || r >= size()) {
		return d;
	}
	const int a = r * RecordLayout::F32_STRIDE;
	const int b = r * RecordLayout::F64_STRIDE;
	const int c = r * RecordLayout::I32_STRIDE;
	d["name"] = names[r];
	d["unit"] = units[r];
	d["position"] = vec3_at(f32, a + RecordLayout::POS);
	d["forward"] = vec3_at(f32, a + RecordLayout::FWD);
	d["velocity"] = vec3_at(f32, a + RecordLayout::VEL);
	d["aim"] = vec3_at(f32, a + RecordLayout::AIM);
	d["turret_forward"] = vec3_at(f32, a + RecordLayout::TURRET);
	d["speed"] = f64[b + RecordLayout::SPEED];
	d["throttle"] = f64[b + RecordLayout::THROTTLE];
	d["turn"] = f64[b + RecordLayout::TURN];
	d["max_speed"] = f64[b + RecordLayout::MAX_SPEED];
	d["turn_rate"] = f64[b + RecordLayout::TURN_RATE];
	d["radius"] = f64[b + RecordLayout::RADIUS];
	d["half_w"] = f64[b + RecordLayout::HALF_W];
	d["half_l"] = f64[b + RecordLayout::HALF_L];
	d["wheel_radius"] = f64[b + RecordLayout::WHEEL_R];
	d["team"] = i32[c + RecordLayout::TEAM];
	d["health"] = i32[c + RecordLayout::HEALTH];
	d["fire"] = i32[c + RecordLayout::FIRE] != 0;
	d["path_index"] = i32[c + RecordLayout::PATH_INDEX];
	d["route"] = route_points.slice(route_offsets[r], route_offsets[r + 1]);
	d["cover"] = cover;
	return d;
}

bool ContactsTable::load(const PackedStringArray &p_names, const PackedStringArray &p_units, const PackedStringArray &p_weapons,
		const PackedStringArray &p_roles, const PackedFloat32Array &p_f32, const PackedFloat64Array &p_f64,
		const PackedInt32Array &p_i32) {
	const int n = p_names.size();
	if (p_units.size() != n || p_weapons.size() != n || p_roles.size() != n ||
			p_f32.size() != n * ContactLayout::F32_STRIDE || p_f64.size() != n * ContactLayout::F64_STRIDE ||
			p_i32.size() != n * ContactLayout::I32_STRIDE) {
		UtilityFunctions::push_error("TankNative.contacts_load: the columns disagree with the layout (native_record.gd and tank_record.h must match)");
		return false;
	}
	names = p_names;
	units = p_units;
	weapons = p_weapons;
	roles = p_roles;
	f32 = p_f32;
	f64 = p_f64;
	i32 = p_i32;
	index.clear();
	index.reserve(n);
	for (int r = 0; r < n; r++) {
		index.insert(names[r], r);
	}
	return true;
}

Dictionary ContactsTable::row(int r) const {
	Dictionary d;
	if (r < 0 || r >= size()) {
		return d;
	}
	const int a = r * ContactLayout::F32_STRIDE;
	const int b = r * ContactLayout::F64_STRIDE;
	const int c = r * ContactLayout::I32_STRIDE;
	d["name"] = names[r];
	d["unit"] = units[r];
	d["weapon"] = weapons[r];
	d["role"] = roles[r];
	d["position"] = vec3_at(f32, a + ContactLayout::POS);
	d["velocity"] = vec3_at(f32, a + ContactLayout::VEL);
	d["forward"] = vec3_at(f32, a + ContactLayout::FWD);
	d["turret_forward"] = vec3_at(f32, a + ContactLayout::TURRET);
	d["suppression"] = f64[b + ContactLayout::SUPPRESSION];
	d["weapon_range"] = f64[b + ContactLayout::WEAPON_RANGE];
	d["health"] = i32[c + ContactLayout::HEALTH];
	d["shield"] = i32[c + ContactLayout::SHIELD];
	d["visible"] = i32[c + ContactLayout::VISIBLE] != 0;
	d["seen_tick"] = i32[c + ContactLayout::SEEN_TICK];
	return d;
}

} // namespace godot
