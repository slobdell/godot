// Round 29 (native N7.4): the wall-contact observer's per-tick scan in C++ (game/ai/wall_contact.gd `observe`, its first
// half): is there a slide to read (the hull in the tree and alive, a command, not parked: Tank.is_parked), and which of
// the last slide's collisions is the wall (not a Tank, a horizontal normal, the deepest; the first on a tie) and was a
// hull touched. A tick that touched a wall (a few % of unit-ticks) is classified by the GDScript as before, on the
// collision this returns. tests/test_native_wall.gd holds it to the live GDScript; native-proof `wall`.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

struct WallConfig {
	bool ready = false;
	double WALL_NORMAL_MAX_Y = 0.5;
	// Tank's script: a collider "is Tank" when its script is this one or extends it.
	Ref<Script> tank_script;
};

bool wall_configure(WallConfig &c, const Dictionary &config);
// -1: no slide to read (nothing counted). Otherwise bit 0 = a hull was touched, and (code >> 1) - 1 is the wall's index
// in the slide collisions (-1: no wall).
int64_t wall_scan(const WallConfig &c, Object *tank);

} // namespace godot
