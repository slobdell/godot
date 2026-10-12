// Round 27 (native, stage 1 E5): OrderController.compute_command as ONE native call per crew per tick -- the seam at its
// top (BrainSwitches.native_exec). On the common path (a living hull, no reflexes, not giving way, a move_to order) the
// whole execute step runs here: Movement.bind, Gunnery.held_aim_point and the command, _sense's reset, the drive
// (drive_native.cpp), Movement.unstick (E4), Gunnery.apply (gun_native.cpp, E3) and Movement.note_decision. Any other case
// answers NIL before writing anything, and the GDScript compute_command runs as it always has.
//
// The crew's state is either the live GDScript members (ObjectView) or a C++-owned ExecState (StructView: pulled at the
// start, the changed fields pushed at the end; the callbacks still left sync it in between).
#include "execute_native.h"

#include "exec_view.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

namespace {

struct EN {
	StringName movement{ "movement" }, gunnery{ "gunnery" }, tank{ "tank" }, alive{ "alive" }, reflexes{ "reflexes" },
			_registry{ "_registry" }, turret{ "turret" }, new_{ "new" }, visible_enemy_names{ "visible_enemy_names" },
			move_order{ "move_order" }, type{ "type" }, _apply_move{ "_apply_move" }, _step{ "_step" },
			driver_ticks{ "driver_ticks" }, decided{ "decided" }, direct{ "direct" }, throttle{ "throttle" }, turn{ "turn" },
			lazy_path{ "lazy_path" }, driver{ "driver" }, deflected{ "deflected" }, steer_to{ "steer_to" }, why{ "why" },
			leg{ "leg" }, path{ "path" }, path_all{ "path_all" }, path_from{ "path_from" }, profile_detail{ "profile_detail" },
			order_controller{ "OrderController" };
};
const EN &en_() {
	static const EN names;
	return names;
}

template <class V>
struct Exec {
	const ExecConfig &x;
	const EN &k;
	Object *ctl, *mover, *gunnery;
	Node3D *tank = nullptr;
	V v;

	Exec(const ExecConfig &p_x, Object *p_ctl, Object *p_mover, Object *p_gunnery, const V &p_v) :
			x(p_x), k(en_()), ctl(p_ctl), mover(p_mover), gunnery(p_gunnery), v(p_v) {}

	// Movement.bind(): `if _registry.get(id) != self: _registry[id] = self`
	void bind_registry() {
		Object *script = mover->get_script();
		Dictionary registry = script != nullptr ? (Dictionary)script->get(k._registry) : Dictionary();
		const int64_t id = tank->get_instance_id();
		if (registry.get(id, Variant()).get_validated_object() != mover) {
			registry[id] = mover;
		}
	}

	// Gunnery.held_aim_point(): `if _held_aim == ZERO: _held_aim = tank.turret_forward()`; `tank.gp + _held_aim * D`
	Vector3 held_aim_point() {
		if (v.g__held_aim() == Vector3()) {
			Node3D *turret = Object::cast_to<Node3D>(tank->get(k.turret).get_validated_object());
			const Vector3 forward = -turret->get_global_transform().basis.get_column(2);
			v.set_g__held_aim(Vector3(forward.x, 0, forward.z).normalized());
		}
		return tank->get_global_position() + v.g__held_aim() * (real_t)x.gun->HELD_AIM_DISTANCE;
	}

	// Movement.note_decision(cmd, order), line by line.
	void note_decision(Object *cmd, const Dictionary &order) {
		static const String yielding("yielding"), yield_d("yield"), press("press"), unstick("unstick"), kturn("kturn"),
				move_to("move_to"), direct_d("direct"), route("route"), stop("stop");
		String driver = String(order.get(k.type, stop));
		if (v.phase() == yielding && !v.yield_to().is_empty()) {
			driver = yield_d;
		} else if (v._unstick_left() > 0.0) {
			driver = v._escape_gear() != 0.0 ? press : unstick;
		} else if (v._kturn_left_m() > 0.0) {
			driver = kturn;
		} else if (driver == move_to) {
			driver = (bool)order.get(k.direct, false) ? direct_d : route;
		}
		Object *script = mover->get_script();
		Dictionary driver_ticks = script->get(k.driver_ticks);
		driver_ticks[driver] = (int64_t)driver_ticks.get(driver, 0) + (int64_t)ctl->get(k._step);
		const String why = driver == route ? v._reverse_why() : String();
		v.set__reverse_why(String());
		const PackedVector3Array path = v._path();
		const int64_t path_index = v._path_index();
		const bool on_route = driver == route && path_index < path.size();
		Dictionary decided;
		decided[k.driver] = driver;
		decided[k.throttle] = cmd->get(k.throttle);
		decided[k.turn] = cmd->get(k.turn);
		decided[k.deflected] = v._deflected() && (driver == route || driver == direct_d);
		const Vector3 steer_to = v.steer_to();
		decided[k.steer_to] = steer_to != Vector3(INFINITY, INFINITY, INFINITY) ? Variant(steer_to) : Variant();
		decided[k.why] = why;
		decided[k.leg] = v._kturn_left_m() > 0.0;
		if (!(bool)x.drive->switches->get(k.lazy_path)) {
			decided[k.path] = on_route ? path.slice(MAX(path_index - 1, (int64_t)0)) : PackedVector3Array();
		} else if (on_route) {
			decided[k.path_all] = path;
			decided[k.path_from] = MAX(path_index - 1, (int64_t)0);
		}
		Object *contact = v.contact().get_validated_object();
		contact->set(k.decided, decided);
	}

	// The common path of compute_command; NIL (and nothing written) when it is not this tick's case.
	Variant run(double delta) {
		static const String move_to("move_to");
		const Dictionary move_order = ctl->get(k.move_order);
		if (!(bool)tank->get(k.alive) || !((Array)ctl->get(k.reflexes)).is_empty() || !v.yield_to().is_empty() ||
				move_order.get(k.type, Variant()) != Variant(move_to)) {
			return Variant();
		}
		bind_registry();
		const Variant cmd_ref = x.drive->tank_command->call(k.new_, 0.0, 0.0, held_aim_point());
		Object *cmd = cmd_ref;
		// _sense: visible_enemy_names = PackedStringArray(); then nothing (no reflexes). _apply_reflexes: nothing.
		ctl->set(k.visible_enemy_names, PackedStringArray());
		// _apply_move: right_of_way is false (not giving way); the order is move_to: movement.drive.
		ExecState *state = state_of();
		drive_with(*x.drive, mover, cmd, move_order, delta, state);
		unstick_with(*x.drive, mover, cmd, move_order, delta, state);
		const double seconds = (double)(int64_t)ctl->get(k._step) / (double)x.drive->TICK_RATE;
		gun_with(*x.gun, *x.drive, gunnery, cmd, seconds, state);
		note_decision(cmd, move_order);
		return cmd_ref;
	}

	ExecState *state_of();
};

template <>
ExecState *Exec<ObjectView>::state_of() {
	return nullptr;
}
template <>
ExecState *Exec<StructView>::state_of() {
	return v.s;
}

// Measurement: executes answered natively and handed back.
struct ExecCounts {
	int64_t native = 0, handed_back = 0;
} exec_counts_;

} // namespace

Variant execute_native(const ExecConfig &config, Object *ctl, double delta, bool owned) {
	if (config.drive == nullptr || config.gun == nullptr || !config.drive->ready || !config.gun->ready ||
			!config.drive->unstick_ready || ctl == nullptr) {
		return Variant();
	}
	const EN &k = en_();
	Object *mover = ctl->get(k.movement).get_validated_object();
	Object *gunnery = ctl->get(k.gunnery).get_validated_object();
	Node3D *tank = Object::cast_to<Node3D>(ctl->get(k.tank).get_validated_object());
	if (mover == nullptr || gunnery == nullptr || tank == nullptr) {
		return Variant();
	}
	Variant answer;
	if (!owned) {
		ObjectView view(mover);
		view.bind_gunnery();
		Exec<ObjectView> e(config, ctl, mover, gunnery, view);
		e.tank = tank;
		answer = e.run(delta);
	} else {
		ExecState local;
		local.pull(mover);
		Exec<StructView> e(config, ctl, mover, gunnery, StructView(mover, &local));
		e.tank = tank;
		answer = e.run(delta);
		local.push(mover, false);
	}
	if (answer.get_type() == Variant::NIL) {
		exec_counts_.handed_back++;
	} else {
		exec_counts_.native++;
	}
	return answer;
}

Dictionary execute_counts(bool reset) {
	Dictionary out;
	out["native"] = exec_counts_.native;
	out["handed_back"] = exec_counts_.handed_back;
	if (reset) {
		exec_counts_ = ExecCounts();
	}
	return out;
}

} // namespace godot
