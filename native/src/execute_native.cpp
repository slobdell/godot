// Round 27 (native, stage 1 E5): OrderController.compute_command as ONE native call per crew per tick -- the seam at its
// top (BrainSwitches.native_exec). On the common path (a living hull, no reflexes, not giving way, a move_to order) the
// whole execute step runs here: Movement.bind, Gunnery.held_aim_point and the command, _sense's reset, the drive
// (drive_native.cpp), Movement.unstick (E4), Gunnery.apply (gun_native.cpp, E3) and Movement.note_decision. Any other case
// answers NIL before writing anything, and the GDScript compute_command runs as it always has.
//
// The crew's state is either the live GDScript members (ObjectView) or a C++-owned ExecState (StructView: pulled at the
// start, the changed fields pushed at the end; the callbacks still left sync it in between).
#include "execute_native.h"

#include "exec_holder.h"
#include "exec_view.h"

#include <godot_cpp/classes/engine.hpp>

#include <chrono>
#include <cmath>
#include <string>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

namespace {

struct EN {
	StringName movement{ "movement" }, gunnery{ "gunnery" }, tank{ "tank" }, alive{ "alive" }, reflexes{ "reflexes" },
			_registry{ "_registry" }, turret{ "turret" }, new_{ "new" }, visible_enemy_names{ "visible_enemy_names" },
			move_order{ "move_order" }, type{ "type" }, _apply_move{ "_apply_move" }, _step{ "_step" },
			driver_ticks{ "driver_ticks" }, decided{ "decided" }, direct{ "direct" }, throttle{ "throttle" }, turn{ "turn" },
			lazy_path{ "lazy_path" }, driver{ "driver" }, deflected{ "deflected" }, steer_to{ "steer_to" }, why{ "why" },
			leg{ "leg" }, path{ "path" }, path_all{ "path_all" }, path_from{ "path_from" }, profile_detail{ "profile_detail" }, yield_to{ "yield_to" }, from{ "from" }, x{ "x" }, z{ "z" },
			_wheel_radius_unit{ "_wheel_radius_unit" }, _wheel_radius_value{ "_wheel_radius_value" }, unit_id{ "unit_id" },
			order_controller{ "OrderController" };
};
const EN &en_() {
	static const EN names;
	return names;
}

void note_hand_back(int reason, const Variant &type);

// Measurement only (--native-exec-profile): microseconds a native execute spends in each part, summed; one clock at a
// time is open (a part's time excludes nothing: the parts are sequential).
struct ExecProfile {
	bool on = false;
	double usec[12] = {};
	int64_t executes = 0;
};
ExecProfile &exec_profile() {
	static ExecProfile p;
	return p;
}
enum ProfilePart { P_PRECHECK = 0, P_STATE, P_BIND, P_COMMAND, P_DRIVE, P_UNSTICK, P_GUN, P_NOTE, P_PUSH, P_GUN_GD,
	P_GUN_RAY, P_GUN_SPOTTER, P_SEAM_COUNT };
const char *const PROFILE_NAMES[P_SEAM_COUNT] = { "precheck", "state", "bind", "command", "drive", "unstick", "gun", "note",
	"push", "gun.gdscript_calls", "gun.rays", "gun.spotter" };
struct PartClock {
	std::chrono::steady_clock::time_point t0;
	PartClock() {
		if (exec_profile().on) {
			t0 = std::chrono::steady_clock::now();
		}
	}
	void lap(int part) {
		if (!exec_profile().on) {
			return;
		}
		const auto now = std::chrono::steady_clock::now();
		exec_profile().usec[part] += std::chrono::duration<double, std::micro>(now - t0).count();
		t0 = now;
	}
};

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
	// Movement.idle() (its GDScript `native_stale = true` is the GDScript's own bookkeeping: here the C++ writes).
	void idle() {
		static const String arrived("arrived");
		v.set_yield_to(String());
		v.set_arc_live(false);
		v.set__deflected(false);
		v.set_stalled_ticks(0);
		v.set_phase(arrived);
		v.set_blocked_by(String());
		v.set__goal(Vector3(INFINITY, INFINITY, INFINITY));
		v.set__remaining(0.0);
	}

	PartClock *clock = nullptr;
	void lap(int part) {
		if (clock != nullptr) {
			clock->lap(part);
		}
	}

	Variant run(double delta) {
		static const String move_to("move_to"), stop("stop");
		const Dictionary move_order = ctl->get(k.move_order);
		const Variant type = move_order.get(k.type, Variant());
		const bool moving = type == Variant(move_to); // the hand-back tests ran in execute_native, on the live members
		const Variant stop_v(stop);
		bind_registry();
		lap(P_BIND);
		const Variant cmd_ref = x.drive->tank_command->call(k.new_, 0.0, 0.0, held_aim_point());
		Object *cmd = cmd_ref;
		// _sense: visible_enemy_names = PackedStringArray(); then nothing (no reflexes). _apply_reflexes: nothing.
		ctl->set(k.visible_enemy_names, PackedStringArray());
		// _apply_move: right_of_way is false (not giving way); a move_to drives, a stop idles (and `match` does nothing).
		lap(P_COMMAND);
		ExecState *state = state_of();
		// _apply_move: `if movement.right_of_way(cmd, delta): return` -- giving way fills cmd and skips the order; a
		// give-way that just ended goes on with the order this same tick.
		if (right_of_way_with(*x.drive, mover, cmd, state) == 1) {
			// nothing more of _apply_move
		} else if (moving) {
			drive_with(*x.drive, mover, cmd, move_order, delta, state);
		} else {
			idle();
			if (type != stop_v) {
				// "face" (a tracked hull's plain facing): turn_only := Steering.drive_toward(here, -basis.z, spot, 0.0)
				// cmd.turn = turn_only.y if absf(turn_only.y) > 0.08 else 0.0
				const Vector3 spot((real_t)(double)move_order[k.x], 0, (real_t)(double)move_order[k.z]);
				const Vector3 forward = -tank->get_global_transform().basis.get_column(2);
				const Vector2 turn_only = steering_drive_toward(*x.drive, tank->get_global_position(), forward, spot, 0.0);
				cmd->set(k.turn, std::fabs((double)turn_only.y) > 0.08 ? (double)turn_only.y : 0.0);
			}
		}
		lap(P_DRIVE);
		unstick_with(*x.drive, mover, cmd, move_order, delta, state);
		lap(P_UNSTICK);
		const double seconds = (double)(int64_t)ctl->get(k._step) / (double)x.drive->TICK_RATE;
		gun_with(*x.gun, *x.drive, gunnery, cmd, seconds, state);
		lap(P_GUN);
		note_decision(cmd, move_order);
		lap(P_NOTE);
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

// Measurement: executes answered natively and handed back; in the persistent mode the pulls a stale state took, and in
// the verify mode the fields found different from a fresh pull (a door into the state that does not mark it stale).
// No godot type in a static: a namespace-scope global with a String in it is constructed when the library loads, before
// godot-cpp can make a String, and crashed Godot's --import (signal 11) on E5b's first build; one destroyed at exit
// would run after the engine. So the first mismatch is kept as UTF-8 in a std::string.
struct ExecCounts {
	int64_t native = 0, handed_back = 0, stale_pulls = 0, verified = 0, verify_mismatches = 0;
	int64_t part_pulls = 0;
	int64_t dead = 0, reflexes = 0, yielding = 0, face = 0, drive = 0, other_order = 0;
	std::string first_mismatch;
};
ExecCounts &exec_counts() {
	static ExecCounts counts;
	return counts;
}
#define exec_counts_ exec_counts()

void note_hand_back(int reason, const Variant &type) {
	ExecCounts &c = exec_counts();
	switch (reason) {
		case 0: c.dead++; break;
		case 1: c.reflexes++; break;
		case 2: c.yielding++; break;
		default: {
			const String t = type;
			if (t == String("face")) {
				c.face++;
			} else if (t == String("drive")) {
				c.drive++;
			} else {
				c.other_order++;
			}
		}
	}
}

const StringName &sn_native_state() {
	static const StringName n("native_state");
	return n;
}
const StringName &sn_native_stale() {
	static const StringName n("native_stale");
	return n;
}

// The mover's persistent state, pulled again when the GDScript has written it since (`native_stale`); with `verify`, a
// fresh pull is compared with it field by field first.
ExecState *persistent_state(Object *mover, bool verify) {
	NativeExecState *holder = Object::cast_to<NativeExecState>(mover->get(sn_native_state()).get_validated_object());
	if (holder == nullptr) {
		Ref<NativeExecState> made;
		made.instantiate();
		mover->set(sn_native_state(), made);
		holder = made.ptr();
	}
	ExecState &state = holder->state;
	// Movement.STALE_ALL / STALE_ORDER / STALE_GUN / STALE_STALL (movement.gd): what the GDScript wrote since.
	const int64_t stale = mover->get(sn_native_stale());
	if (!holder->fresh || (stale & 1)) {
		state.pull(mover);
		holder->fresh = true;
		exec_counts_.stale_pulls++;
	} else if (stale != 0) {
		if (stale & 2) {
			state.pull_mover_field(mover, MF::_repath_left);
			state.pull_mover_field(mover, MF::_reissued);
		}
		if (stale & 4) {
			state.pull_gun();
		}
		if (stale & 8) {
			state.pull_mover_field(mover, MF::stalled_ticks);
		}
		exec_counts_.part_pulls++;
	}
	if (stale != 0) {
		mover->set(sn_native_stale(), (int64_t)0);
	}
	if (verify && holder->fresh) {
		ExecState fresh;
		fresh.pull(mover);
		const Dictionary held = state.row(), now = fresh.row();
		const Array keys = now.keys();
		static const String skip("m:native_stale");
		exec_counts_.verified++;
		for (int64_t i = 0; i < keys.size(); i++) {
			const String key = keys[i];
			if (key == skip) {
				continue;
			}
			const Variant a = held[key], b = now[key];
			const bool same = a.get_type() == b.get_type() &&
					((a.get_type() == Variant::ARRAY || a.get_type() == Variant::DICTIONARY || a.get_type() == Variant::OBJECT) ?
									UtilityFunctions::is_same(a, b) :
									a == b);
			if (!same) {
				exec_counts_.verify_mismatches++;
				if (exec_counts_.first_mismatch.empty()) {
					exec_counts_.first_mismatch =
							(key + String(": held ") + String(a) + String(", members ") + String(b)).utf8().get_data();
				}
				// An engine ERROR, so a test or a check target run with verification fails on it: a door into the owned
				// state that does not mark native_stale (native.md *Stage 1 as built*, the doors).
				UtilityFunctions::push_error(String("NativeExec verify: the owned state differs from the members (a door that does not mark native_stale): ") +
						key + String(" held ") + String(a) + String(", members ") + String(b) + String(" on ") +
						String(((Node *)Object::cast_to<Node>(mover->get(StringName("ctl")).get_validated_object())) != nullptr ?
										Object::cast_to<Node>(mover->get(StringName("ctl")).get_validated_object())->get_name() :
										StringName("?")));
				state.pull(mover); // go on from the truth
				break;
			}
		}
	}
	return &state;
}

} // namespace

Variant execute_native(const ExecConfig &config, Object *ctl, double delta, int mode) {
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
	PartClock clock;
	// The hand-back tests first, on the live members (before an owned state is fetched: a dead hull fetched and pulled it
	// every tick for nothing, the first E5b run's 72 775 full pulls).
	{
		static const String move_to("move_to"), stop("stop");
		const Dictionary move_order = ctl->get(k.move_order);
		const Variant type = move_order.get(k.type, Variant());
		static const String face("face"), post("post");
		// A face order natively only on a tracked hull's plain facing: Movement.keeps_heading answers false (the order
		// is not "from" a post), face_turn false (no wheels), _wheel_hold off (opt-in): the turn toward the spot.
		const bool simple_face = type == Variant(face) && String(move_order.get(k.from, String())) != post &&
				String(mover->get(k._wheel_radius_unit)) == String(tank->get(k.unit_id)) &&
				(double)mover->get(k._wheel_radius_value) <= 0.0;
		const int reason = !(bool)tank->get(k.alive) ? 0 : (!((Array)ctl->get(k.reflexes)).is_empty() ? 1 :
				((!String(mover->get(k.yield_to)).is_empty() && !config.drive->yield_ready) ? 2 :
				((type != Variant(move_to) && type != Variant(stop) && !simple_face) ? 3 : -1)));
		if (reason >= 0) {
			note_hand_back(reason, type);
			if (mode != EXEC_LIVE) {
				mover->set(sn_native_stale(), (int64_t)mover->get(sn_native_stale()) | 1); // the GDScript executes
			}
			exec_counts_.handed_back++;
			return Variant();
		}
	}
	clock.lap(P_PRECHECK);
	Variant answer;
	if (mode == EXEC_LIVE) {
		ObjectView view(mover);
		view.bind_gunnery();
		Exec<ObjectView> e(config, ctl, mover, gunnery, view);
		e.tank = tank;
		e.clock = &clock;
		answer = e.run(delta);
		mover->set(sn_native_stale(), (int64_t)mover->get(sn_native_stale()) | 1); // written live: an owned state is stale
	} else {
		ExecState *state = persistent_state(mover, mode == EXEC_OWNED_VERIFY);
		clock.lap(P_STATE);
		Exec<StructView> e(config, ctl, mover, gunnery, StructView(mover, state));
		e.tank = tank;
		e.clock = &clock;
		answer = e.run(delta);
		if (answer.get_type() == Variant::NIL) {
			mover->set(sn_native_stale(), (int64_t)mover->get(sn_native_stale()) | 1); // the GDScript executes this tick
		} else {
			state->push(mover, false);
			clock.lap(P_PUSH);
		}
	}
	if (answer.get_type() == Variant::NIL) {
		exec_counts_.handed_back++;
	} else {
		exec_counts_.native++;
		exec_profile().executes++;
	}
	return answer;
}

// gun_native.cpp's clocks: inside the gun section, its calls into GDScript, its sight rays and its spotter calls.
void execute_profile_add(int part, double usec) {
	if (exec_profile().on && part >= 0 && part < P_SEAM_COUNT) {
		exec_profile().usec[part] += usec;
	}
}
bool execute_profile_is_on() {
	return exec_profile().on;
}

void execute_profile_on(bool on) {
	exec_profile().on = on;
}

Dictionary execute_profile(bool reset) {
	ExecProfile &p = exec_profile();
	Dictionary out;
	out["executes"] = p.executes;
	for (int i = 0; i < P_SEAM_COUNT; i++) {
		out[PROFILE_NAMES[i]] = p.usec[i];
	}
	if (reset) {
		const bool on = p.on;
		p = ExecProfile();
		p.on = on;
	}
	return out;
}

Dictionary execute_counts(bool reset) {
	Dictionary out;
	out["native"] = exec_counts_.native;
	out["handed_back"] = exec_counts_.handed_back;
	out["stale_pulls"] = exec_counts_.stale_pulls;
	out["verified"] = exec_counts_.verified;
	out["verify_mismatches"] = exec_counts_.verify_mismatches;
	out["part_pulls"] = exec_counts_.part_pulls;
	out["dead"] = exec_counts_.dead;
	out["reflexes"] = exec_counts_.reflexes;
	out["yielding"] = exec_counts_.yielding;
	out["face"] = exec_counts_.face;
	out["drive"] = exec_counts_.drive;
	out["other_order"] = exec_counts_.other_order;
	out["first_mismatch"] = String::utf8(exec_counts_.first_mismatch.c_str());
	if (reset) {
		exec_counts() = ExecCounts();
	}
	return out;
}

} // namespace godot
