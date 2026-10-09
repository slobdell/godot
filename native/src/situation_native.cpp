// Round 24 (native, N3d): the first three steps of TankBrain.build_situation (game/ai/tank_brain.gd) as ONE call: the
// allies list (s.allies), which contacts to look at (s.select: the MAX_CONTACTS nearest plus the target, the ordered
// target and mortars), and each contact's entry (s.contacts: the team's shared prototype duplicated, then the fields
// that depend on where I am). The team-shared memos stay calls into the live GDScript (AiTickCache.faced_by through
// _faces_someone_else; CoverMap.clear_line_coarse with its counters), so their state is what the GDScript leaves.
// Line by line with the GDScript's widths (_agents/native.md, hazard 1); tests/test_native_situation.gd asks
// build_situation() both ways on real brains in a fight.
#include "tank_native.h"

#include "cover_native.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>

#include <algorithm>
#include <cmath>

namespace godot {

namespace {

struct SN {
	StringName name{ "name" }, squad{ "squad" }, position{ "position" }, weapon{ "weapon" }, target{ "target" },
			visible{ "visible" }, age{ "age" }, seen_tick{ "seen_tick" }, exposed_face{ "exposed_face" },
			forward{ "forward" }, facing_ally{ "facing_ally" }, aiming_at_me{ "aiming_at_me" },
			turret_forward{ "turret_forward" }, watching_me{ "watching_me" }, threatens_me{ "threatens_me" },
			weapon_range{ "weapon_range" }, pinned{ "pinned" }, suppression{ "suppression" },
			faces_someone_else{ "_faces_someone_else" }, clear_line_coarse{ "clear_line_coarse" },
			// AiTickCache.faced_by's memo and CoverMap's counters, kept where the GDScript keeps them
			_facing_bucket_match{ "_facing_bucket_match" }, _facing_bucket{ "_facing_bucket" },
			_facing_cache{ "_facing_cache" }, team_tanks{ "team_tanks" }, tick{ "tick" }, alive{ "alive" },
			_native{ "_native" }, los_queries{ "los_queries" }, los_computed{ "los_computed" },
			native_cover{ "native_cover" };
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

// AiTickCache.faced_by(game_match, team, contact_name, known), its per-intel-refresh memo in AiTickCache's statics.
Array faced_by(const SN &k, Object *ai_cache, Object *game_match, int64_t team, const String &contact_name,
		const Dictionary &known, int64_t intel_every, double cos_30) {
	const int64_t bucket = (int64_t)game_match->get(k.tick) / intel_every;
	const int64_t match_id = (int64_t)game_match->get_instance_id();
	if ((int64_t)ai_cache->get(k._facing_bucket_match) != match_id || (int64_t)ai_cache->get(k._facing_bucket) != bucket) {
		ai_cache->set(k._facing_bucket_match, match_id);
		ai_cache->set(k._facing_bucket, bucket);
		Array fresh;
		fresh.push_back(Dictionary());
		fresh.push_back(Dictionary());
		ai_cache->set(k._facing_cache, fresh);
	}
	const Array cache = ai_cache->get(k._facing_cache);
	Dictionary table = cache[team];
	if (table.has(contact_name)) {
		return table[contact_name];
	}
	const Vector3 position = known[k.position];
	const Vector3 known_forward = known[k.forward];
	Vector2 forward(known_forward.x, known_forward.z);
	Array faced;
	if ((double)forward.length_squared() > 1e-6) {
		forward = forward.normalized();
		const Array tanks = ai_cache->call(k.team_tanks, game_match, team);
		for (int64_t i = 0; i < tanks.size(); i++) {
			Node3D *ally = Object::cast_to<Node3D>((Object *)tanks[i]);
			if (ally == nullptr || !(bool)ally->get(k.alive)) {
				continue;
			}
			const Vector3 at = ally->get_global_transform().origin;
			const double dx = (double)at.x - (double)position.x;
			const double dz = (double)at.z - (double)position.z;
			const double distance_squared = dx * dx + dz * dz;
			if (distance_squared >= 6400.0 || distance_squared < 1e-6) {
				continue;
			}
			if ((double)forward.x * dx + (double)forward.y * dz >= cos_30 * std::sqrt(distance_squared)) {
				faced.push_back(String(ally->get_name()));
			}
		}
	}
	table[contact_name] = faced;
	return faced;
}

// CoverMap.clear_line_coarse(a, b) on its native twin (native and native_cover on), with CoverMap's counters.
bool clear_line_coarse(const SN &k, Object *cover_map, Object *switches, const Vector3 &a, const Vector3 &b) {
	const Variant twin_v = cover_map->get(k._native);
	CoverNative *twin = twin_v.get_type() == Variant::OBJECT ? Object::cast_to<CoverNative>(twin_v.get_validated_object()) : nullptr;
	if (twin == nullptr || switches == nullptr || !(bool)switches->get(k.native_cover)) {
		return cover_map->call(k.clear_line_coarse, a, b);
	}
	Object *script = cover_map->get_script();
	script->set(k.los_queries, (int64_t)script->get(k.los_queries) + 1);
	const int code = twin->clear_line_coarse(a, b);
	if (code & 2) {
		script->set(k.los_computed, (int64_t)script->get(k.los_computed) + 1);
	}
	return (code & 1) == 1;
}

struct ByDistance {
	double d;
	String name;
};

} // namespace

// constants: [MAX_CONTACTS, COS_AIMED_AT_ME, COS_WATCHING, COS_ARMOR_ARC, PINNED_SUPPRESSION, Match.INTEL_EVERY_TICKS,
// AiTickCache.COS_30]; ai_cache / game_match / switches: AiTickCache, the match, BrainSwitches (the native lookups).
// Returns [allies, squad_positions, contacts], the three arrays build_situation goes on with.
Array TankNative::situation_core(Object *brain, const Vector3 &my_position, const String &my_name, const Variant &squad_name,
		const Array &all_allies, const Dictionary &intel, const Array &names, const Dictionary &prototypes,
		const Variant &choice_target, const Variant &order_target, int64_t tick, double flank_reach, Object *cover_map,
		const PackedFloat64Array &constants, Object *ai_cache, Object *game_match, Object *switches) const {
	const SN &k = sn_();
	Array out;
	if (brain == nullptr || constants.size() < 7) {
		return out;
	}
	const int64_t max_contacts = (int64_t)constants[0];
	const double cos_aimed = constants[1];
	const double cos_watching = constants[2];
	const double cos_armor_arc = constants[3];
	const double pinned_at = constants[4];
	const int64_t intel_every = (int64_t)constants[5];
	const double cos_30 = constants[6];
	const int64_t my_team = brain->get("tank").get_validated_object()->get("team");
	const bool native_lookups = ai_cache != nullptr && game_match != nullptr;
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
		// _faces_someone_else: a name in AiTickCache.faced_by(...) other than mine
		bool facing_ally = false;
		if ((double)offset.length() <= flank_reach) {
			if (native_lookups) {
				const Array faced = faced_by(k, ai_cache, game_match, my_team, contact_name, known, intel_every, cos_30);
				for (int64_t f = 0; f < faced.size(); f++) {
					if (String(faced[f]) != my_name) {
						facing_ally = true;
						break;
					}
				}
			} else {
				facing_ally = brain->call(k.faces_someone_else, known, contact_name, my_name);
			}
		}
		contact[k.facing_ally] = facing_ally;
		const Vector3 turret = contact[k.turret_forward];
		contact[k.aiming_at_me] = visible && points_at(turret, -offset, cos_aimed);
		contact[k.watching_me] = points_at(turret, -offset, cos_watching);
		contact[k.threatens_me] = visible &&
				(double)my_position.distance_to(position) <= (double)contact[k.weapon_range] + 5.0 &&
				(native_lookups ? clear_line_coarse(k, cover_map, switches, position, my_position) :
								  (bool)cover_map->call(k.clear_line_coarse, position, my_position));
		contact[k.pinned] = (double)contact.get(k.suppression, 0.0) >= pinned_at;
		contacts.push_back(contact);
	}
	out.push_back(allies);
	out.push_back(squad_positions);
	out.push_back(contacts);
	return out;
}

} // namespace godot
