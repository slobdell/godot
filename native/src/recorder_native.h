// Round 28 (native N7.6): the black box's per-tick work in C++ -- MatchRecorder._physics_process
// (game/match/match_recorder.gd): the squad tasks written when they change (_record_tasks), the once-a-second census
// (census_row per living unit) and their rows written and flushed (_write). The event rows (order, hit, dead, end) stay
// GDScript signal handlers. tests/test_native_recorder.gd holds the bytes to the live GDScript.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

struct RecorderConfig {
	bool ready = false;
	double CENSUS_S = 1.0, TICK_RATE = 30.0;
	int64_t GREEN = 0, RUST = 1;
	Ref<Script> tank_script, movement_script;
};

bool recorder_configure(RecorderConfig &c, const Dictionary &config);
void recorder_tick(const RecorderConfig &c, Object *recorder);

} // namespace godot
