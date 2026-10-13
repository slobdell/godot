// Round 28 (native N7.3): OrderController._physics_process in C++ (controller_native.h), line by line.
#include "controller_native.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

namespace {

struct CN {
	StringName tank{ "tank" }, movement{ "movement" }, observe_contact{ "observe_contact" }, _lap{ "_lap" },
			enabled{ "enabled" }, _sim_profiled{ "_sim_profiled" }, profiling{ "profiling" },
			profile_detail{ "profile_detail" }, split_on{ "split_on" }, _stride{ "_stride" }, game_match{ "game_match" },
			tick{ "tick" }, _last_command{ "_last_command" }, _last_run_tick{ "_last_run_tick" },
			wants_to_run{ "wants_to_run" }, think_offset{ "think_offset" }, command{ "command" },
			executed_held{ "executed_held" }, executed_full{ "executed_full" }, profile_usec{ "profile_usec" },
			charge_unit{ "charge_unit" }, census{ "census" }, team{ "team" }, stride_skips{ "stride_skips" },
			_step{ "_step" }, think{ "think" }, add_part{ "add_part" }, compute_command{ "compute_command" };
	String c_wall_contact{ "c.wall_contact" }, think_s{ "think" }, execute_s{ "execute" };
};
const CN &cn_() {
	static const CN names;
	return names;
}

inline int64_t now_usec() {
	return (int64_t)Time::get_singleton()->get_ticks_usec();
}

// `self as TankBrain`: the controller's script is TankBrain's or extends it.
bool is_script_or_extends(Object *object, const Ref<Script> &script) {
	Ref<Script> s = object->get_script();
	while (s.is_valid()) {
		if (s == script) {
			return true;
		}
		s = s->get_base_script();
	}
	return false;
}

} // namespace

bool controller_configure(ControllerConfig &c, const Dictionary &config) {
	const char *names[] = { "order_controller", "tank_brain", "sim_profile", "brains_ab" };
	for (const char *name : names) {
		if (!config.has(name)) {
			c.ready = false;
			return false;
		}
	}
	c.order_controller = config["order_controller"];
	c.tank_brain = config["tank_brain"];
	c.sim_profile = config["sim_profile"];
	c.brains_ab = config["brains_ab"];
	c.ready = c.order_controller.is_valid() && c.tank_brain.is_valid() && c.sim_profile.is_valid() &&
			c.brains_ab.is_valid();
	return c.ready;
}

void controller_tick(const ControllerConfig &c, Object *self, double delta) {
	// Every engine call from here crosses the extension boundary, which costs more than the same access inside the
	// GDScript VM (the first cut, a line-for-line copy, priced +0.75 % of the tick): so each static is read ONCE (nothing
	// between the reads can change a measurement static: think and execute never write them), _lap's body is inlined,
	// and the command is not read back (Tank.command has no setter).
	const CN &k = cn_();
	Script *oc = c.order_controller.ptr();
	Script *ab = c.brains_ab.ptr();
	//   if tank == null or not is_instance_valid(tank): return
	Object *tank = self->get(k.tank).get_validated_object();  // null for null and for a freed hull
	if (tank == nullptr) {
		return;
	}
	//   var contact_lap := Time.get_ticks_usec() if profile_detail else 0; movement.observe_contact(); _lap(...)
	const bool was_detail = oc->get(k.profile_detail);
	const int64_t contact_lap = was_detail ? now_usec() : 0;
	Object *movement = self->get(k.movement);
	movement->call(k.observe_contact);
	if (was_detail) {  // _lap: add_part(part, now - since) only while profile_detail
		oc->call(k.add_part, k.c_wall_contact, now_usec() - contact_lap);
	}
	//   if SimProfile.enabled != _sim_profiled: the three statics follow it
	bool sim_profiled = oc->get(k._sim_profiled);
	bool profiling;
	const bool sim_enabled = c.sim_profile->get(k.enabled);
	if (sim_enabled != sim_profiled) {
		sim_profiled = sim_enabled;
		profiling = sim_enabled;
		oc->set(k._sim_profiled, sim_enabled);
		oc->set(k.profiling, sim_enabled);
		oc->set(k.profile_detail, sim_enabled);
	} else {
		profiling = oc->get(k.profiling);
	}
	const bool split_on = ab->get(k.split_on);
	const int64_t started = (profiling || split_on) ? now_usec() : 0;
	const int64_t stride = self->get(k._stride);
	if (stride > 1 && is_script_or_extends(self, c.tank_brain)) {
		Object *game_match = self->get(k.game_match);
		if (game_match != nullptr) {
			const int64_t tick = game_match->get(k.tick);
			const Variant last_command = self->get(k._last_command);
			const int64_t last_run_tick = self->get(k._last_run_tick);
			// the GDScript's `and` chain, in its order (wants_to_run asked only when the first two hold)
			if (last_command.get_type() == Variant::OBJECT && (Object *)last_command != nullptr && last_run_tick >= 0 &&
					!(bool)self->call(k.wants_to_run) &&
					(tick + (int64_t)self->get(k.think_offset)) % stride != 0) {
				tank->set(k.command, last_command);
				if (profiling) {
					oc->set(k.executed_held, (int64_t)oc->get(k.executed_held) + 1);
					oc->set(k.profile_usec, (int64_t)oc->get(k.profile_usec) + now_usec() - started);
				}
				if (split_on) {
					ab->call(k.charge_unit, String(Object::cast_to<Node>(tank)->get_name()), now_usec() - started);
				}
				if ((bool)c.tank_brain->get(k.census)) {
					const int64_t team = tank->get(k.team);
					if (team >= 0 && team < 2) {
						Array skips = c.tank_brain->get(k.stride_skips);
						skips[team] = (int64_t)skips[team] + 1;
					}
				}
				return;
			}
			//   _step = clampi(tick - _last_run_tick, 1, _stride) if _last_run_tick >= 0 else 1
			const int64_t step = last_run_tick >= 0 ? CLAMP(tick - last_run_tick, (int64_t)1, stride) : (int64_t)1;
			self->set(k._step, step);
			self->set(k._last_run_tick, tick);
			delta *= (double)step;
		}
	}
	if (profiling) {
		oc->set(k.executed_full, (int64_t)oc->get(k.executed_full) + 1);
	}
	self->call(k.think, delta);
	if (sim_profiled) {
		oc->call(k.add_part, k.think_s, now_usec() - started);
	}
	const int64_t executing = sim_profiled ? now_usec() : 0;
	const Variant command = self->call(k.compute_command, delta);
	tank->set(k.command, command);
	self->set(k._last_command, command);
	if (sim_profiled) {
		oc->call(k.add_part, k.execute_s, now_usec() - executing);
	}
	if (profiling) {
		oc->set(k.profile_usec, (int64_t)oc->get(k.profile_usec) + now_usec() - started);
	}
	if (split_on) {
		ab->call(k.charge_unit, String(Object::cast_to<Node>(tank)->get_name()), now_usec() - started);
	}
}

} // namespace godot
