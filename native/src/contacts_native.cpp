// Round 48 (native N2): AiTickCache.contact_prototypes' table rebuild (game/ai/ai_tick_cache.gd, _contact_table) in C++. Round 47's
// read (builder3 light, his Crossing at the cost cap, probe native-sitcb47): 0.156 ms a tick builder3 for both teams' tables, ~0.7 ms
// a frame on his laptop; the time is ~16 dictionary writes a contact plus three GDScript helper calls (_gun_ready_in, _suppression_seen,
// Weapons.profile). Line by line with the GDScript: the same keys in the same order, the GDScript's floats in double, Godot's
// MAX / CLAMP argument order (so a -0.0 comes out as the GDScript's does). The suppression memory (`seen`) is written exactly as
// _suppression_seen writes it. tests/test_native_contacts.gd and TANK_NATIVE_CONTACTS_VERIFY hold it to the live GDScript;
// NativeContacts (game/ai/native/native_contacts.gd) is the seam.
#include "contacts_native.h"

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

namespace {

// Keys held as Variants: a String key converts to a Variant through the extension interface on every insert (round 48's first
// price read the native table ~50 us a tick SLOWER than the GDScript, builder3, f0900328a).
struct CK {
	Variant name{ "name" }, position{ "position" }, velocity{ "velocity" }, forward{ "forward" }, health{ "health" },
			shield{ "shield" }, weapon{ "weapon" }, unit{ "unit" }, turret_forward{ "turret_forward" }, visible{ "visible" },
			seen_tick{ "seen_tick" }, gun_ready_in{ "gun_ready_in" }, weapon_range{ "weapon_range" }, suppression{ "suppression" },
			age{ "age" }, reload{ "reload" }, empty{ "" };
	Variant zero_i{ (int64_t)0 }, zero_f{ 0.0 };
	StringName weapon_prop{ "weapon" }, suppression_prop{ "suppression" };
};
const CK &ck() {
	static const CK k;
	return k;
}

// Godot's MAX(a, b) / CLAMP(v, lo, hi), argument order kept (maxf / clampf in GDScript).
double gd_max(double a, double b) { return a < b ? b : a; }
double gd_clamp(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }

Object *tank_of(const ContactsInput &in, const Variant &contact_name) {
	const Variant v = in.by_name.get(contact_name, Variant());
	return v.get_type() == Variant::OBJECT ? v.get_validated_object() : nullptr;
}

// AiTickCache._gun_ready_in + gun_ready_in.
double gun_ready(const ContactsInput &in, const Variant &contact_name) {
	const CK &k = ck();
	Object *enemy = tank_of(in, contact_name);
	if (enemy == nullptr) {
		return 0.0;
	}
	const Dictionary weapon = enemy->get(k.weapon_prop);
	if ((double)weapon.get(k.reload, 0.0) < in.slow_gun_reload) {
		return 0.0;
	}
	const Variant fired = in.fired.get((int64_t)enemy->get_instance_id(), Variant());
	if (fired.get_type() == Variant::NIL) {
		return 0.0;
	}
	const double reload = (double)weapon.get(k.reload, 0.0);
	return gd_max(0.0, reload - (double)(in.physics_frames - (int64_t)fired) / in.tick_rate);
}

// AiTickCache._suppression_seen (its match reset is the seam's).
double suppression_seen(const ContactsInput &in, const Variant &contact_name, const Dictionary &known) {
	const CK &k = ck();
	if ((bool)known[k.visible]) {
		double live = 0.0;
		Object *enemy = tank_of(in, contact_name);
		if (enemy != nullptr) {
			const Variant s = enemy->get(k.suppression_prop);
			live = s.get_type() == Variant::NIL ? 0.0 : gd_clamp((double)s, 0.0, 1.0);
		}
		Array pair;
		pair.push_back(live);
		pair.push_back(in.tick);
		Dictionary seen = in.seen; // shared reference: the write lands in AiTickCache's dictionary
		seen[contact_name] = pair;
		return live;
	}
	if (!in.pinned_exposed) {
		return 0.0;
	}
	const Variant seen = in.seen.get(contact_name, Variant());
	if (seen.get_type() == Variant::NIL) {
		return 0.0;
	}
	const Array pair = seen;
	const double faded = (double)pair[0] - in.recover_per_second * (double)(in.tick - (int64_t)pair[1]) / in.tick_rate;
	return gd_max(faded, 0.0);
}

} // namespace

Dictionary contact_table(const ContactsInput &in) {
	const CK &k = ck();
	Dictionary table;
	for (int64_t i = 0; i < in.names.size(); i++) {
		const Variant contact_name = String(in.names[i]); // the GDScript's `contact_name: String`, converted once
		const Dictionary known = in.intel[contact_name];
		const Variant weapon_id = String(known[k.weapon]);
		Dictionary e;
		e[k.name] = contact_name;
		e[k.position] = known[k.position];
		e[k.velocity] = known[k.velocity];
		e[k.forward] = known[k.forward];
		e[k.health] = known[k.health];
		e[k.shield] = known.get(k.shield, k.zero_i);
		e[k.weapon] = weapon_id;
		e[k.unit] = known.get(k.unit, k.empty);
		e[k.turret_forward] = known[k.turret_forward];
		e[k.visible] = known[k.visible];
		e[k.seen_tick] = (int64_t)known[k.seen_tick];
		e[k.gun_ready_in] = in.reload_windows ? Variant(gun_ready(in, contact_name)) : k.zero_f;
		const Variant range = in.weapon_ranges.get(weapon_id, Variant());
		e[k.weapon_range] = range.get_type() == Variant::NIL ? in.default_range : (double)range;
		e[k.suppression] = suppression_seen(in, contact_name, known);
		e[k.age] = k.zero_i;
		table[contact_name] = e;
	}
	return table;
}

} // namespace godot
