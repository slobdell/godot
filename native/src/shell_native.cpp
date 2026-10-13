// Round 28 (native N7.1c): Shell._fly in C++ (shell_native.h), line by line in the GDScript's widths.
#include "shell_native.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

namespace {

struct SN {
	StringName direction{ "direction" }, speed{ "speed" }, ray_start{ "ray_start" }, _first_step{ "_first_step" },
			simulate{ "simulate" }, exclude{ "exclude" }, hit_normal{ "hit_normal" }, hit{ "hit" }, expired{ "expired" },
			_travelled{ "_travelled" }, max_range{ "max_range" }, visible{ "visible" };
	String position{ "position" }, normal{ "normal" }, collider{ "collider" };
};
const SN &sn_() {
	static const SN names;
	return names;
}

} // namespace

void shell_fly(const ShellConfig &c, Object *shell_object, double delta) {
	const SN &k = sn_();
	Node3D *shell = Object::cast_to<Node3D>(shell_object);
	if (shell == nullptr) {
		return;
	}
	//   var step := direction * speed * delta
	const Vector3 direction = shell->get(k.direction);
	const Vector3 step = (direction * (real_t)(double)shell->get(k.speed)) * (real_t)delta;
	//   var from := ray_start if _first_step else global_position; _first_step = false
	const Vector3 from = (bool)shell->get(k._first_step) ? (Vector3)shell->get(k.ray_start) : shell->get_global_position();
	shell->set(k._first_step, false);
	const Vector3 to = shell->get_global_position() + step;
	const bool simulate = shell->get(k.simulate);
	if (simulate) {
		const TypedArray<RID> exclude = shell->get(k.exclude);
		Ref<PhysicsRayQueryParameters3D> query = PhysicsRayQueryParameters3D::create(from, to, c.HIT_MASK, exclude);
		const Dictionary result = shell->get_world_3d()->get_direct_space_state()->intersect_ray(query);
		if (!result.is_empty()) {
			const Vector3 at = result[k.position];
			shell->set_global_position(at);
			shell->set(k.hit_normal, result[k.normal]);
			shell->set_physics_process(false);
			shell->emit_signal(k.hit, shell, result[k.collider], at);
			return;
		}
	}
	shell->set_global_position(to);
	const double travelled = (double)shell->get(k._travelled) + (double)step.length();
	shell->set(k._travelled, travelled);
	if (travelled >= (double)shell->get(k.max_range)) {
		shell->set_physics_process(false);
		if (simulate) {
			shell->emit_signal(k.expired, shell);
		} else {
			shell->set(k.visible, false); // the server will despawn it shortly
		}
	}
}

} // namespace godot
