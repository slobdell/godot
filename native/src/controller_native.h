// Round 28 (native N7.3): the controllers' tick in C++ -- OrderController._physics_process (game/ai/order_controller.gd):
// the wall-contact observer's call, the stride hold (the last command kept on a crew's off tick), think (GDScript) then
// compute_command (the native execute since E5), and the measurement bookkeeping (the parts, SimProfile's sections,
// BrainsAB's charge, the stride census) -- every branch, so a profiled run measures the native path. Statics are read
// and written on their own scripts, live, as the GDScript reads them. tests/test_native_controller.gd holds it to the
// live GDScript; native-proof `controller`.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

struct ControllerConfig {
	bool ready = false;
	Ref<Script> order_controller, tank_brain, sim_profile, brains_ab;
};

bool controller_configure(ControllerConfig &c, const Dictionary &config);
void controller_tick(const ControllerConfig &c, Object *controller, double delta);

} // namespace godot
