// Round 24 (native, N3d): TankBrain.decide's constants and the scripts it asks (decide_native.cpp), held by the
// TankNative instance so they are released with it (a function-static copy kept three scripts alive past shutdown).
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

// The constants, by name, from the live script (NativeDecide.configure).
struct DecideConsts {
	double HOT_FIREPOWER, PINNED_THREAT_FACTOR, PINNED_RETREAT_HP, CRITICAL_HP_MIN, CRITICAL_HP_MAX, RESUPPLY_TOP_UP,
			REPAIR_TOP_UP, PINNED_COVER, SHIELD_DOWN_BREAK_HP, RECHARGED, ORBIT_KEEP_ADVANTAGE, ORBIT_START_ADVANTAGE,
			FOCUS_BONUS, COVER_TEAMMATE_BONUS, FRAGILE_THREAT_BONUS, ORDER_WEIGHT, SUPPRESS_KILL_RATIO, PIN_HOLD_FRACTION,
			PINNED_SUPPRESSION, SUPPRESS_WEIGHT, PINNED_FLANK_BONUS, FLANKER_APPETITE, SCOUT_FIGHT, SCOUT_HUNT,
			SCOUT_HUNT_FLOOR, COVER_FIRE_RELOAD_FLOOR, PINNED_COVER_FIRE, SUPPRESS_UNDER_WINNABLE, COMMIT_BONUS,
			CLEAR_LANE_EDGE, SCOUT_STANDOFF, SLOT_TOLERANCE, COOLDOWN_FACTOR, REVISIT_S, REVISIT_FACTOR,
			ATTACK_MOVE_REACH_MARGIN, ATTACK_MOVE_FIGHT, ATTACK_MOVE_WEIGHT, LOW_AMMO_FRACTION, FULL_TANK_HEALTH;
	int64_t COVER_FIRE_MEMORY_TICKS, COVER_DENIED_MEMORY_TICKS, CONTACT_FRESH_TICKS, ORBIT_MEMORY_TICKS,
			LANE_BLOCKED_TICKS, TICK_RATE, KIND_ARC;
	double SUPPRESS_PENETRATION, SUPPRESSING_WEAPON;
	Dictionary ORDER_OPTIONS;
	Array FIGHT_OPTIONS;
	Object *brain_script = nullptr, *suppression_feed = nullptr, *element_feed = nullptr, *units = nullptr;
	Variant keep_brain, keep_suppression, keep_element, keep_units;
	bool ready = false;
};


} // namespace godot
