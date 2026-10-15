// Round 30 (native N7.5): ElementFeed's two builders natively (feed_native.h). Line by line with
// game/ai/element_feed.gd: every dictionary key is a String (as the GDScript's literals), inserted in the GDScript's
// order; text is Variant::stringify (GDScript's str()); the sector's trig in double on float32 vectors.
#include "feed_native.h"
#include "gun_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>

namespace godot {

namespace {

Variant feed_point(const Variant &value) {
	return order_feed_point(value); // OrderFeed.point (gun_native.cpp)
}

// The keys, as Strings: a dictionary built here must hold the same key type the GDScript's literals do.
struct FK {
	String leader{ "leader" }, id{ "id" }, transit{ "transit" }, velocity{ "velocity" }, state{ "state" },
			members{ "members" }, technique{ "technique" }, drill{ "drill" }, task{ "task" }, verb{ "verb" },
			formation{ "formation" }, pitch{ "pitch" }, slots{ "slots" }, position{ "position" }, facing{ "facing" },
			sectors{ "sectors" }, heading{ "heading" }, role{ "role" }, roles{ "roles" }, moving{ "moving" },
			maneuver{ "maneuver" }, is_leader{ "is_leader" }, slot{ "slot" }, relocating{ "relocating" }, pace{ "pace" },
			station{ "station" }, station_velocity{ "station_velocity" }, stations{ "stations" }, key{ "key" },
			empty{ "" }, bar{ "|" }, support_by_fire{ "support_by_fire" }, bounding_overwatch{ "bounding_overwatch" },
			move{ "move" }, attack_move{ "attack_move" }, hold{ "hold" }, stop{ "stop" }, bound{ "bound" },
			overwatch{ "overwatch" }, base_of_fire{ "base_of_fire" };
	StringName s_leader{ "leader" }, s_id{ "id" }, s_members{ "members" }, s_heading{ "heading" },
			s_feed_state{ "feed_state" }, s_state{ "state" };
};
const FK &fk_() {
	static const FK keys;
	return keys;
}

// ElementFeed._text: "" for null, else str().
String text(const Variant &value) {
	return value.get_type() == Variant::NIL ? String() : value.stringify();
}

// `Array(raw)` for the shapes a member list arrives in.
Array as_array(const Variant &raw) {
	switch (raw.get_type()) {
		case Variant::ARRAY:
			return raw;
		case Variant::PACKED_STRING_ARRAY:
			return Array(PackedStringArray(raw));
		case Variant::PACKED_INT32_ARRAY:
			return Array(PackedInt32Array(raw));
		case Variant::PACKED_INT64_ARRAY:
			return Array(PackedInt64Array(raw));
		case Variant::PACKED_FLOAT32_ARRAY:
			return Array(PackedFloat32Array(raw));
		case Variant::PACKED_FLOAT64_ARRAY:
			return Array(PackedFloat64Array(raw));
		default:
			return Array();
	}
}

// ElementFeed._direction: a flat unit vector, or NIL.
Variant direction(const Variant &value) {
	const Variant point = feed_point(value);
	if (point.get_type() == Variant::NIL) {
		return Variant();
	}
	const Vector3 flat = point;
	if ((double)flat.length_squared() < 0.0001) {
		return Variant();
	}
	return flat.normalized();
}

PackedStringArray members_of(const FK &k, const Dictionary &state, Object *element) {
	Variant raw = state.get(k.members, Variant());
	if (raw.get_type() == Variant::NIL) {
		raw = element->get(k.s_members); // NIL when the element has no such property, as `"members" in element` false
	}
	if (raw.get_type() == Variant::NIL) {
		const Variant slots = state.get(k.slots, Variant());
		raw = slots.get_type() == Variant::DICTIONARY ? Variant(Dictionary(slots).keys()) : Variant(Array());
	}
	PackedStringArray names;
	const Array list = as_array(raw);
	for (int64_t i = 0; i < list.size(); i++) {
		names.append(text(list[i]));
	}
	names.sort();
	return names;
}

Variant pitch_of(const FK &k, const Dictionary &state) {
	const Variant raw = state.get(k.pitch, Variant());
	if (raw.get_type() != Variant::ARRAY) {
		return Variant();
	}
	const Array list = raw;
	if (list.size() != 2) {
		return Variant();
	}
	return Vector2((real_t)(double)list[0], (real_t)(double)list[1]);
}

String task_verb(const FK &k, const Variant &raw) {
	if (raw.get_type() == Variant::DICTIONARY) {
		return text(Dictionary(raw).get(k.verb, Variant()));
	}
	return text(raw);
}

Dictionary slot_of(const FK &k, const Dictionary &state, const String &unit_name, const PackedStringArray &members) {
	const Variant slots = state.get(k.slots, Variant());
	Variant mine;
	if (slots.get_type() == Variant::DICTIONARY) {
		mine = Dictionary(slots).get(unit_name, Variant());
	} else if (slots.get_type() == Variant::ARRAY) {
		const Array list = slots;
		const int64_t index = members.find(unit_name);
		if (index >= 0 && index < list.size()) {
			mine = list[index];
		}
	}
	if (mine.get_type() == Variant::DICTIONARY) {
		return mine;
	}
	Dictionary out;
	if (mine.get_type() != Variant::NIL && feed_point(mine).get_type() != Variant::NIL) {
		out[k.position] = mine;
	}
	return out;
}

Variant sector(const FK &k, const Dictionary &state, Object *element, const String &unit_name, const Dictionary &mine) {
	const Variant explicit_facing = direction(mine.get(k.facing, Variant()));
	if (explicit_facing.get_type() != Variant::NIL) {
		return explicit_facing;
	}
	const Variant sectors = state.get(k.sectors, Variant());
	if (sectors.get_type() != Variant::DICTIONARY || !Dictionary(sectors).has(unit_name)) {
		return Variant();
	}
	const Variant value = Dictionary(sectors)[unit_name];
	const Variant as_direction = direction(value);
	if (as_direction.get_type() != Variant::NIL) {
		return as_direction;
	}
	if ((value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) || !std::isfinite((double)value)) {
		return Variant();
	}
	Variant heading = direction(state.get(k.heading, Variant()));
	if (heading.get_type() == Variant::NIL) {
		heading = direction(element->get(k.s_heading));
	}
	if (heading.get_type() == Variant::NIL) {
		return Variant();
	}
	const Vector3 forward = heading;
	const double radians = Math::deg_to_rad((double)value);
	return (forward * (real_t)std::cos(radians) + Vector3(-forward.z, 0.0, forward.x) * (real_t)std::sin(radians)).normalized();
}

PackedStringArray names_of(const Variant &raw) {
	PackedStringArray names;
	if (raw.get_type() != Variant::ARRAY && raw.get_type() != Variant::PACKED_STRING_ARRAY) {
		return names;
	}
	const Array list = as_array(raw);
	for (int64_t i = 0; i < list.size(); i++) {
		names.append(text(list[i]));
	}
	return names;
}

String role_of(const FeedConfig &c, const FK &k, const Dictionary &mine, const Dictionary &state, const String &unit_name,
		const String &technique, const String &drill, const String &task, const String &order_verb) {
	const String named = text(mine.get(k.role, Variant()));
	if (c.ROLES.has(named)) {
		return named;
	}
	const Variant roles = state.get(k.roles, Variant());
	if (roles.get_type() == Variant::DICTIONARY) {
		const String given = text(Dictionary(roles).get(unit_name, Variant()));
		if (c.ROLES.has(given)) {
			return given;
		}
	}
	const PackedStringArray moving = names_of(state.get(k.moving, state.get(k.maneuver, Variant())));
	const bool supporting = drill == k.support_by_fire || task == k.support_by_fire;
	if (!moving.is_empty()) {
		const bool i_move = moving.has(unit_name);
		if (supporting) {
			return i_move ? k.maneuver : k.base_of_fire;
		}
		return i_move ? k.bound : k.overwatch;
	}
	if (!supporting && technique != k.bounding_overwatch) {
		return k.empty;
	}
	if (order_verb == k.move || order_verb == k.attack_move) {
		return supporting ? k.maneuver : k.bound;
	}
	if (order_verb == k.hold || order_verb == k.stop) {
		return supporting ? k.base_of_fire : k.overwatch;
	}
	return supporting ? k.base_of_fire : k.empty;
}

} // namespace

bool feed_configure(FeedConfig &c, const Dictionary &from) {
	c.ready = from.has("TECHNIQUES") && from.has("DRILLS") && from.has("TASKS") && from.has("ROLES");
	if (c.ready) {
		c.TECHNIQUES = from["TECHNIQUES"];
		c.DRILLS = from["DRILLS"];
		c.TASKS = from["TASKS"];
		c.ROLES = from["ROLES"];
	}
	return c.ready;
}

Dictionary feed_shared(const FeedConfig &c, Object *element, bool use_feed_state) {
	const FK &k = fk_();
	if (element == nullptr) {
		return Dictionary();
	}
	const Variant raw = use_feed_state && element->has_method(k.s_feed_state) ? element->call(k.s_feed_state)
																			  : element->call(k.s_state);
	if (raw.get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	const Dictionary state = raw;
	String leader = text(state.get(k.leader, Variant()));
	if (leader.is_empty()) {
		leader = text(element->get(k.s_leader));
	}
	Variant id_value = state.get(k.id, Variant());
	if (id_value.get_type() == Variant::NIL) {
		id_value = element->get(k.s_id);
	}
	const Variant transit = state.get(k.transit, Variant());
	Dictionary shared;
	shared[k.state] = state;
	shared[k.members] = members_of(k, state, element);
	shared[k.leader] = leader;
	shared[k.technique] = text(state.get(k.technique, Variant()));
	shared[k.drill] = text(state.get(k.drill, Variant()));
	shared[k.task] = task_verb(k, state.get(k.task, state.get(k.verb, k.empty)));
	shared[k.id] = text(id_value);
	shared[k.formation] = text(state.get(k.formation, Variant()));
	shared[k.pitch] = pitch_of(k, state);
	shared[k.velocity] = transit.get_type() == Variant::DICTIONARY && Dictionary(transit).has(k.velocity)
			? feed_point(Dictionary(transit)[k.velocity])
			: Variant();
	return shared;
}

Dictionary feed_normalize(const FeedConfig &c, Object *element, const String &unit_name, const String &order_verb,
		const Dictionary &shared_in, bool use_feed_state, bool slide_off) {
	const FK &k = fk_();
	Dictionary shared = shared_in;
	if (shared.is_empty()) {
		shared = feed_shared(c, element, use_feed_state);
		if (shared.is_empty()) {
			return Dictionary();
		}
	}
	const Dictionary state = shared[k.state];
	const PackedStringArray members = shared[k.members];
	const String leader = shared[k.leader];
	const String technique = shared[k.technique];
	const String drill = shared[k.drill];
	const String task = shared[k.task];
	const Dictionary mine = slot_of(k, state, unit_name, members);
	Dictionary context;
	context[k.id] = shared[k.id];
	context[k.leader] = leader;
	context[k.is_leader] = !leader.is_empty() && leader == unit_name;
	context[k.formation] = shared[k.formation];
	context[k.technique] = c.TECHNIQUES.has(technique) ? technique : k.empty;
	context[k.drill] = c.DRILLS.has(drill) ? drill : k.empty;
	context[k.task] = c.TASKS.has(task) ? task : k.empty;
	const Variant slot = feed_point(mine.get(k.position, Variant()));
	context[k.slot] = slot;
	context[k.facing] = sector(k, state, element, unit_name, mine);
	context[k.pitch] = shared[k.pitch];
	const String role = role_of(c, k, mine, state, unit_name, technique, drill, task, order_verb);
	context[k.role] = role;
	context[k.members] = members;
	context[k.relocating] = (bool)state.get(k.relocating, false);
	const Variant paces = state.get(k.pace, Variant());
	context[k.pace] = paces.get_type() == Variant::DICTIONARY
			? CLAMP((double)Dictionary(paces).get(unit_name, 1.0), 0.0, 1.0)
			: 1.0;
	context[k.station] = Variant();
	context[k.station_velocity] = Variant();
	const Variant stations = state.get(k.stations, Variant());
	if (stations.get_type() == Variant::DICTIONARY && Dictionary(stations).has(unit_name)) {
		context[k.station] = feed_point(Dictionary(stations)[unit_name]);
		context[k.station_velocity] = shared[k.velocity];
	}
	// "%s|%s|%s|%s|%s[|%s]" % [id, technique, drill, task, role(, slot)]: %s is the value's str().
	String key = text(context[k.id]) + k.bar + String(context[k.technique]) + k.bar + String(context[k.drill]) + k.bar +
			String(context[k.task]) + k.bar + role;
	if (slide_off) {
		key += k.bar + slot.stringify();
	}
	context[k.key] = key;
	return context;
}

} // namespace godot
