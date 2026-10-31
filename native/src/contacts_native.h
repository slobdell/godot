// Round 48 (native N2): AiTickCache.contact_prototypes' table rebuild in C++ (contacts_native.cpp).
#pragma once

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

struct ContactsInput {
	Dictionary intel;            // game_match.intel[side]
	Array names;                 // AiTickCache.intel_names(game_match, side): sorted
	Dictionary by_name;          // AiTickCache._by_name (tanks_by_name)
	Dictionary fired;            // AiTickCache._fired: instance id -> physics frame
	Dictionary seen;             // AiTickCache._seen_suppression[side]: WRITTEN for every visible contact
	Dictionary weapon_ranges;    // weapon id -> float(Weapons.profile(id)["range"]) for every PROFILES id
	double default_range = 0.0;  // Weapons.profile(<unknown id>)["range"] (the DEFAULT profile's)
	int64_t tick = 0;            // game_match.tick
	int64_t physics_frames = 0;  // Engine.get_physics_frames()
	bool reload_windows = false; // BrainVariants.for_team(side).reload_windows
	bool pinned_exposed = false; // BrainVariants.for_team(side).pinned_exposed
	double slow_gun_reload = 1.5;          // TankBrain.SLOW_GUN_RELOAD
	double recover_per_second = 0.3;       // Tank.SUPPRESSION_RECOVER_PER_SECOND
	double tick_rate = 30.0;               // SimClock.TICK_RATE
};

// {contact name: prototype entry}: AiTickCache._contact_table's answer, key for key and in the same order.
Dictionary contact_table(const ContactsInput &in);

} // namespace godot
