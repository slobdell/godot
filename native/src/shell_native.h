// Round 28 (native N7.1c): Shell._fly (game/combat/shell.gd) in C++ -- one shell's tick of flight: the swept ray along
// its travel (the engine's intersect_ray, as the GDScript asks it), the hit (position, normal, the `hit` signal) or
// the step, the burn-out (`expired`). Called from the shell's own _physics_process, so every shell flies in the
// scene's order exactly as before. tests/test_native_shell.gd holds it to the live GDScript; native-proof `shell`.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <cstdint>

namespace godot {

struct ShellConfig {
	bool ready = false;
	uint32_t HIT_MASK = 3;
};

void shell_fly(const ShellConfig &config, Object *shell, double delta);

} // namespace godot
