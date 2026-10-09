// Round 24 (native, N3d): the first three steps of TankBrain.build_situation (game/ai/tank_brain.gd) as ONE call: the
// allies list (s.allies), which contacts to look at (s.select: the MAX_CONTACTS nearest plus the target, the ordered
// target and mortars), and each contact's entry (s.contacts: the team's shared prototype duplicated, then the fields
// that depend on where I am). The team-shared memos stay calls into the live GDScript (AiTickCache.faced_by through
// _faces_someone_else; CoverMap.clear_line_coarse with its counters), so their state is what the GDScript leaves.
// Line by line with the GDScript's widths (_agents/native.md, hazard 1); tests/test_native_situation.gd asks
// build_situation() both ways on real brains in a fight.
#include "tank_native.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>

#include <algorithm>

namespace godot {

namespace {

struct SN {
	StringName name{ "name" }, squad{ "squad" }, position{ "position" }, weapon{ "weapon" }, target{ "target" },
			visible{ "visible" }, age{ "age" }, seen_tick{ "seen_tick" }, exposed_face{ "exposed_face" },
			forward{ "forward" }, facing_ally{ "facing_ally" }, aiming_at_me{ "aiming_at_me" },
			turret_forward{ "turret_forward" }, watching_me{ "watching_me" }, threatens_me{ "threatens_me" },
			weapon_range{ "weapon_range" }, pinned{ "pinned" }, suppression{ "suppression" },
			faces_someone_else{ "_faces_someone_else" }, clear_line_coarse{ "clear_line_coarse" };
	String mortar{ "mortar" }, front{ "front" }, rear{ "rear" }, side{ "side" };
};
const SN &sn_() {
	static const SN n;
	return n;
}

// TankBrain.face_hit(hull_forward, shell_direction)
const String &face_hit(const SN &k, const Vector3 &hull_forward, const Vector3 &shell_direction, double cos_armor_arc) {
	const Vector2 forward(hull_forward.x, hull_forward.z);
	const Vector2 toward_shooter(-shell_direction.x, -shell_direction.z);
	const double lengths = (double)forward.length() * (double)toward_shooter.length();
	const double alignment = lengths > 1e-9 ? (double)forward.dot(toward_shooter) / lengths : 0.0;
	if (alignment >= cos_armor_arc) {
		return k.front;
	}
	if (alignment <= -cos_armor_arc) {
		return k.rear;
	}
	return k.side;
}

// TankBrain.points_at(forward, direction, min_cos)
bool points_at(const Vector3 &forward, const Vector3 &direction, double min_cos) {
	const Vector2 a(forward.x, forward.z);
	const Vector2 b(direction.x, direction.z);
	const double lengths = (double)a.length() * (double)b.length();
	return lengths < 1e-8 || (double)a.dot(b) >= min_cos * lengths;
}

struct ByDistance {
	double d;
	String name;
};

} // namespace

// constants: [MAX_CONTACTS, COS_AIMED_AT_ME, COS_WATCHING, COS_ARMOR_ARC, PINNED_SUPPRESSION]
// Returns [allies, squad_positions, contacts], the three arrays build_situation goes on with.
Array TankNative::situation_core(Object *brain, const Vector3 &my_position, const String &my_name, const Variant &squad_name,
		const Array &all_allies, const Dictionary &intel, const Array &names, const Dictionary &prototypes,
		const Variant &choice_target, const Variant &order_target, int64_t tick, double flank_reach, Object *cover_map,
		const PackedFloat64Array &constants) const {
	const SN &k = sn_();
	Array out;
	if (brain == nullptr || constants.size() < 5) {
		return out;
	}
	const int64_t max_contacts = (int64_t)constants[0];
	const double cos_aimed = constants[1];
	const double cos_watching = constants[2];
	const double cos_armor_arc = constants[3];
	const double pinned_at = constants[4];
	// s.allies: every living ally of my team but me (AiTickCache.allies), and my squad's positions.
	Array allies;
	Array squad_positions;
	for (int64_t i = 0; i < all_allies.size(); i++) {
		const Dictionary ally = all_allies[i];
		if (ally[k.name] == Variant(my_name)) {
			continue;
		}
		allies.push_back(ally);
		if (ally[k.squad] == squad_name) {
			squad_positions.push_back(ally[k.position]);
		}
	}
	// s.select: with more than MAX_CONTACTS names, keep the nearest MAX_CONTACTS plus the target, the ordered target and
	// mortars. `by_distance.sort()` sorts [distance, name] pairs: by distance, then by name (String's <).
	HashMap<String, bool> keep;
	if (names.size() > max_contacts) {
		LocalVector<ByDistance> by_distance;
		by_distance.reserve(names.size());
		for (int64_t i = 0; i < names.size(); i++) {
			const String contact_name = names[i];
			const Dictionary known = intel[contact_name];
			by_distance.push_back(ByDistance{ (double)my_position.distance_to(known[k.position]), contact_name });
		}
		std::sort(by_distance.ptr(), by_distance.ptr() + by_distance.size(), [](const ByDistance &a, const ByDistance &b) {
			return a.d < b.d || (a.d == b.d && a.name < b.name);
		});
		for (uint32_t i = 0; i < by_distance.size(); i++) {
			const String &contact_name = by_distance[i].name;
			const Dictionary known = intel[contact_name];
			if ((int64_t)i < max_contacts || Variant(contact_name) == choice_target || Variant(contact_name) == order_target ||
					String(known[k.weapon]) == k.mortar) {
				keep.insert(contact_name, true);
			}
		}
	}
	// s.contacts
	Array contacts;
	for (int64_t i = 0; i < names.size(); i++) {
		const String contact_name = names[i];
		if ((!keep.is_empty() && !keep.has(contact_name)) || !prototypes.has(contact_name)) {
			continue;
		}
		const Dictionary known = intel[contact_name];
		Dictionary contact = ((Dictionary)prototypes[contact_name]).duplicate();
		const Vector3 position = contact[k.position];
		const Vector3 offset = position - my_position;
		const bool visible = contact[k.visible];
		contact[k.age] = tick - (int64_t)contact[k.seen_tick];
		contact[k.exposed_face] = face_hit(k, contact[k.forward], offset, cos_armor_arc);
		contact[k.facing_ally] = (double)offset.length() <= flank_reach &&
				(bool)brain->call(k.faces_someone_else, known, contact_name, my_name);
		const Vector3 turret = contact[k.turret_forward];
		contact[k.aiming_at_me] = visible && points_at(turret, -offset, cos_aimed);
		contact[k.watching_me] = points_at(turret, -offset, cos_watching);
		contact[k.threatens_me] = visible &&
				(double)my_position.distance_to(position) <= (double)contact[k.weapon_range] + 5.0 &&
				(bool)cover_map->call(k.clear_line_coarse, position, my_position);
		contact[k.pinned] = (double)contact.get(k.suppression, 0.0) >= pinned_at;
		contacts.push_back(contact);
	}
	out.push_back(allies);
	out.push_back(squad_positions);
	out.push_back(contacts);
	return out;
}

} // namespace godot
