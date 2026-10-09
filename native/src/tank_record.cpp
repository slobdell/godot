#include "tank_record.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

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

// ---- the native gather (round 24, N3a after the price) ----

namespace {
struct Names {
	StringName alive{ "alive" }, estimated_velocity{ "estimated_velocity" }, command{ "command" }, aim_point{ "aim_point" },
			throttle{ "throttle" }, turn{ "turn" }, fire{ "fire" }, turret{ "turret" }, speed{ "_speed" },
			max_forward_speed{ "max_forward_speed" }, hull_turn_rate{ "hull_turn_rate" }, team{ "team" }, health{ "health" },
			unit_id{ "unit_id" }, ctl{ "ctl" }, tank{ "tank" }, path{ "_path" }, path_index{ "_path_index" },
			position{ "position" }, velocity{ "velocity" }, forward{ "forward" }, turret_forward{ "turret_forward" },
			suppression{ "suppression" }, weapon{ "weapon" }, unit{ "unit" }, role{ "role" }, shield{ "shield" },
			visible{ "visible" }, seen_tick{ "seen_tick" };
};
const Names &names_() {
	static const Names n;
	return n;
}
} // namespace

bool TankRecords::gather(Node *root, const Dictionary &registry, const Dictionary &hulls, int64_t p_cover,
		PackedStringArray &missing) {
	const Names &k = names_();
	missing.clear();
	if (root == nullptr) {
		return false;
	}
	const int children = root->get_child_count();
	LocalVector<Node3D *> rows;
	rows.reserve(children);
	for (int i = 0; i < children; i++) {
		Node *child = root->get_child(i);
		// `child as Tank` and `is_alive()`: a Tank is the node with the bool `alive`; is_alive() returns it.
		const Variant alive = child->get(k.alive);
		if (alive.get_type() != Variant::BOOL || !(bool)alive) {
			continue;
		}
		Node3D *hull = Object::cast_to<Node3D>(child);
		if (hull != nullptr) {
			rows.push_back(hull);
		}
	}
	const int n = rows.size();
	names.resize(n);
	units.resize(n);
	f32.resize(n * RecordLayout::F32_STRIDE);
	f64.resize(n * RecordLayout::F64_STRIDE);
	i32.resize(n * RecordLayout::I32_STRIDE);
	route_offsets.resize(n + 1);
	route_points.clear();
	float *pf = f32.ptrw();
	double *pd = f64.ptrw();
	int32_t *pi = i32.ptrw();
	int32_t *po = route_offsets.ptrw();
	po[0] = 0;
	index.clear();
	index.reserve(n);
	for (int r = 0; r < n; r++) {
		Node3D *tank = rows[r];
		const String name = tank->get_name();
		names.set(r, name);
		index.insert(name, r);
		const String unit = tank->get(k.unit_id);
		units.set(r, unit);
		const Transform3D xform = tank->get_global_transform();
		const Vector3 forward = -xform.basis.get_column(2); // -tank.global_basis.z
		const Vector3 velocity = tank->get(k.estimated_velocity);
		Object *command = tank->get(k.command);
		Vector3 aim;
		double throttle = 0.0, turn = 0.0;
		bool fire = false;
		if (command != nullptr) {
			aim = command->get(k.aim_point);
			throttle = command->get(k.throttle);
			turn = command->get(k.turn);
			fire = command->get(k.fire);
		}
		// tank.turret_forward(): -turret.global_basis.z, flattened and normalised in float32.
		Vector3 turret_forward;
		Node3D *turret = Object::cast_to<Node3D>((Object *)tank->get(k.turret));
		if (turret != nullptr) {
			const Vector3 f = -turret->get_global_transform().basis.get_column(2);
			turret_forward = Vector3(f.x, 0, f.z).normalized();
		}
		float *a = pf + r * RecordLayout::F32_STRIDE;
		const Vector3 cols[5] = { xform.origin, forward, velocity, aim, turret_forward };
		for (int c = 0; c < 5; c++) {
			a[c * 3] = cols[c].x;
			a[c * 3 + 1] = cols[c].y;
			a[c * 3 + 2] = cols[c].z;
		}
		double *b = pd + r * RecordLayout::F64_STRIDE;
		b[RecordLayout::SPEED] = tank->get(k.speed);
		b[RecordLayout::THROTTLE] = throttle;
		b[RecordLayout::TURN] = turn;
		b[RecordLayout::MAX_SPEED] = tank->get(k.max_forward_speed);
		b[RecordLayout::TURN_RATE] = tank->get(k.hull_turn_rate);
		const Variant hull = hulls.get(unit, Variant());
		if (hull.get_type() == Variant::PACKED_FLOAT64_ARRAY) {
			const PackedFloat64Array h = hull;
			b[RecordLayout::RADIUS] = h[0];
			b[RecordLayout::HALF_W] = h[1];
			b[RecordLayout::HALF_L] = h[2];
			b[RecordLayout::WHEEL_R] = h[3];
		} else {
			b[RecordLayout::RADIUS] = b[RecordLayout::HALF_W] = b[RecordLayout::HALF_L] = b[RecordLayout::WHEEL_R] = 0.0;
			if (!missing.has(unit)) {
				missing.push_back(unit);
			}
		}
		int32_t *c = pi + r * RecordLayout::I32_STRIDE;
		c[RecordLayout::TEAM] = (int64_t)tank->get(k.team);
		c[RecordLayout::HEALTH] = (int64_t)tank->get(k.health);
		c[RecordLayout::FIRE] = fire ? 1 : 0;
		// Movement.of(tank): the registry's mover whose controller is valid and drives this tank.
		int32_t path_index = 0;
		const Variant mover_v = registry.get((int64_t)tank->get_instance_id(), Variant());
		// get_validated_object(): null for a freed object, as is_instance_valid() is false.
		Object *mover = mover_v.get_type() == Variant::OBJECT ? mover_v.get_validated_object() : nullptr;
		if (mover != nullptr) {
			const Variant ctl_v = mover->get(k.ctl);
			Object *ctl = ctl_v.get_type() == Variant::OBJECT ? ctl_v.get_validated_object() : nullptr;
			if (ctl == nullptr || (Object *)ctl->get(k.tank) != tank) {
				mover = nullptr;
			}
		}
		if (mover != nullptr) {
			path_index = (int64_t)mover->get(k.path_index);
			route_points.append_array(mover->get(k.path));
		}
		c[RecordLayout::PATH_INDEX] = path_index;
		route_offsets.set(r + 1, route_points.size());
	}
	cover = p_cover;
	out_throttle.resize(n);
	out_turn.resize(n);
	out_aim.resize(n);
	out_fire.resize(n);
	for (int r = 0; r < n; r++) {
		out_throttle[r] = pd[r * RecordLayout::F64_STRIDE + RecordLayout::THROTTLE];
		out_turn[r] = pd[r * RecordLayout::F64_STRIDE + RecordLayout::TURN];
		const float *aim = pf + r * RecordLayout::F32_STRIDE + RecordLayout::AIM;
		out_aim[r] = Vector3(aim[0], aim[1], aim[2]);
		out_fire[r] = pi[r * RecordLayout::I32_STRIDE + RecordLayout::FIRE] != 0;
	}
	return true;
}

void ContactsTable::gather(const Dictionary &intel, const Dictionary &ranges, PackedStringArray &missing) {
	const Names &k = names_();
	missing.clear();
	// `intel.keys()` then `sort()`: Array.sort orders Strings by String's operator<, as here.
	Array keys = intel.keys();
	keys.sort();
	const int n = keys.size();
	names.resize(n);
	units.resize(n);
	weapons.resize(n);
	roles.resize(n);
	f32.resize(n * ContactLayout::F32_STRIDE);
	f64.resize(n * ContactLayout::F64_STRIDE);
	i32.resize(n * ContactLayout::I32_STRIDE);
	float *pf = f32.ptrw();
	double *pd = f64.ptrw();
	int32_t *pi = i32.ptrw();
	index.clear();
	index.reserve(n);
	for (int r = 0; r < n; r++) {
		const String name = keys[r];
		const Dictionary known = intel[name];
		names.set(r, name);
		index.insert(name, r);
		const String weapon = known[k.weapon];
		units.set(r, String(known.get(k.unit, String())));
		weapons.set(r, weapon);
		roles.set(r, String(known.get(k.role, String())));
		const Vector3 cols[4] = { known[k.position], known[k.velocity], known[k.forward], known[k.turret_forward] };
		float *a = pf + r * ContactLayout::F32_STRIDE;
		for (int c = 0; c < 4; c++) {
			a[c * 3] = cols[c].x;
			a[c * 3 + 1] = cols[c].y;
			a[c * 3 + 2] = cols[c].z;
		}
		// float(known.get("suppression", 0.0)) and float(Weapons.profile(weapon)["range"])
		pd[r * ContactLayout::F64_STRIDE + ContactLayout::SUPPRESSION] = (double)known.get(k.suppression, 0.0);
		const Variant reach = ranges.get(weapon, Variant());
		if (reach.get_type() == Variant::NIL) {
			if (!missing.has(weapon)) {
				missing.push_back(weapon);
			}
		}
		pd[r * ContactLayout::F64_STRIDE + ContactLayout::WEAPON_RANGE] = reach.get_type() == Variant::NIL ? 0.0 : (double)reach;
		int32_t *c = pi + r * ContactLayout::I32_STRIDE;
		c[ContactLayout::HEALTH] = (int64_t)known[k.health];
		c[ContactLayout::SHIELD] = (int64_t)known.get(k.shield, 0);
		c[ContactLayout::VISIBLE] = (bool)known[k.visible] ? 1 : 0;
		c[ContactLayout::SEEN_TICK] = (int64_t)known[k.seen_tick];
	}
}

} // namespace godot
