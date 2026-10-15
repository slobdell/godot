// Round 28 (native N6.1): Tank._drive (game/tank/tank.gd) as one native call per tank per tick: the motion state read and
// written in place (the Tank's `_motion` Dictionary), TankMotion.step_in_place natively with no crossing
// (motion_native.cpp), the basis and the velocity set, the engine's move_and_slide called from here, the slide's result
// read back. Called back (GDScript): the motion state's first build (TankMotion.state_for, once a hull), the yaw-fit test
// when the hull touched something (`_fitting_forward`: shape queries), the off-floor note (once), and SimProfile's parked
// count while profiling. The drive-trace instrument (`Tank.drive_trace`) runs the GDScript (NativeTank.usable).
// Proven by the match hash on and off (native-proof `tank`), the thirteen sim lines and determinism.
#include "tank_drive_native.h"

#include "motion_native.h"

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>

namespace godot {

namespace {

struct TN {
	StringName _placed_settle{ "_placed_settle" }, _motion{ "_motion" }, unit_id{ "unit_id" }, _speed{ "_speed" },
			throttle{ "throttle" }, turn{ "turn" }, estimated_velocity{ "estimated_velocity" },
			max_forward_speed{ "max_forward_speed" }, max_reverse_speed{ "max_reverse_speed" },
			hull_turn_rate{ "hull_turn_rate" }, acceleration{ "acceleration" }, braking{ "braking" },
			locomotion{ "locomotion" }, min_turn_radius{ "min_turn_radius" }, lateral_grip{ "lateral_grip" },
			_fitting_forward{ "_fitting_forward" }, _yaw_push{ "_yaw_push" }, yaw_refused_ticks{ "yaw_refused_ticks" },
			_off_floor_said{ "_off_floor_said" }, _note_off_floor{ "_note_off_floor" }, state_for{ "state_for" },
			enabled{ "enabled" }, add{ "add" }, real_velocity{ "real_velocity" }, real_velocity_on{ "real_velocity_on" };
	// the motion state's keys: String, as the GDScript's literals (a key inserted must be the GDScript's type)
	String position{ "position" }, forward{ "forward" }, speed{ "speed" }, velocity{ "velocity" },
			m_max_forward_speed{ "max_forward_speed" }, m_max_reverse_speed{ "max_reverse_speed" },
			hull_turn_rate_deg{ "hull_turn_rate_deg" }, acceleration_mps2{ "acceleration_mps2" },
			braking_mps2{ "braking_mps2" }, m_locomotion{ "locomotion" }, min_turn_radius_m{ "min_turn_radius_m" },
			m_lateral_grip{ "lateral_grip" }, creep_dir{ "creep_dir" }, creep_ticks{ "creep_ticks" },
			tracks{ "tracks" }, drive_parked{ "tank/drive_parked" };
};
const TN &tn_() {
	static const TN names;
	return names;
}

inline double rad_to_deg(double rad) {
	return rad * (180.0 / Math::PI);
}

} // namespace

bool tank_drive_native(const TankDriveConfig &c, Object *tank_object, Object *cmd, double delta) {
	CharacterBody3D *tank = Object::cast_to<CharacterBody3D>(tank_object);
	if (!c.ready || c.motion == nullptr || !c.motion->ready || tank == nullptr || cmd == nullptr) {
		return false;
	}
	const TN &k = tn_();
	//   if _placed_settle: _placed_settle = false; _motion = {}; return
	if ((bool)tank->get(k._placed_settle)) {
		tank->set(k._placed_settle, false);
		tank->set(k._motion, Dictionary());
		return true;
	}
	Dictionary motion = tank->get(k._motion);
	const Vector3 position = tank->get_global_position();
	const Vector3 basis_z = tank->get_global_transform().basis.get_column(2);
	const double throttle = cmd->get(k.throttle), turn = cmd->get(k.turn);
	if (motion.is_empty()) {
		//   _motion = TankMotion.state_for(unit_id, global_position, -global_basis.z, _speed)
		motion = c.tank_motion->call(k.state_for, tank->get(k.unit_id), position, -basis_z, tank->get(k._speed));
		tank->set(k._motion, motion);
	} else if (throttle == 0.0 && turn == 0.0 && (double)tank->get(k._speed) == 0.0 && tank->get_velocity() == Vector3() &&
			(Vector3)tank->get(k.estimated_velocity) == Vector3()) {
		// is_parked(cmd): `_motion["position"] = global_position`, the creep reset, return (SimProfile's count while profiling)
		if ((bool)c.sim_profile->get(k.enabled)) {
			c.sim_profile->call(k.add, k.drive_parked, (int64_t)Time::get_singleton()->get_ticks_usec());
		}
		motion[k.position] = position;
		if (motion.has(k.creep_dir)) {
			motion[k.creep_dir] = 0;
			motion[k.creep_ticks] = 0;
		}
		return true;
	}
	motion[k.position] = position;
	const Vector3 facing = -basis_z;
	const Vector3 facing_flat = Vector3(facing.x, 0, facing.z).normalized();
	motion[k.forward] = facing_flat;
	const double speed_before = tank->get(k._speed);
	motion[k.speed] = speed_before;
	motion[k.m_max_forward_speed] = tank->get(k.max_forward_speed);
	motion[k.m_max_reverse_speed] = tank->get(k.max_reverse_speed);
	motion[k.hull_turn_rate_deg] = rad_to_deg((double)tank->get(k.hull_turn_rate));
	motion[k.acceleration_mps2] = tank->get(k.acceleration);
	motion[k.braking_mps2] = tank->get(k.braking);
	const String locomotion = tank->get(k.locomotion);
	motion[k.m_locomotion] = locomotion;
	motion[k.min_turn_radius_m] = tank->get(k.min_turn_radius);
	motion[k.m_lateral_grip] = tank->get(k.lateral_grip);
	motion_step(*c.motion, motion, throttle, turn, delta);
	Vector3 forward = motion[k.forward];
	if (forward != facing_flat) {
		// _fitting_forward(have, wanted): `if not yaw_fit_on() or (get_slide_collision_count() == 0 and yaw_refused_ticks
		// == 0): return wanted` -- both sides of that `or` answer `wanted`, so with no contact and no refusal running the
		// answer is `wanted` whatever yaw_fit_on() says (its one side effect, Units' env read, is idempotent and done at
		// start). Otherwise the GDScript (its shape queries).
		if (tank->get_slide_collision_count() != 0 || (int64_t)tank->get(k.yaw_refused_ticks) != 0) {
			forward = tank->call(k._fitting_forward, facing_flat, forward);
		}
		if (forward != facing_flat) {
			tank->set_global_basis(Basis::looking_at(forward, Vector3(0, 1, 0)));
			motion[k.forward] = forward;
			const Vector3 push = tank->get(k._yaw_push);
			if (push != Vector3()) {
				tank->set_global_position(tank->get_global_position() + push);
				tank->set(k._yaw_push, Vector3());
			}
		}
	}
	tank->set(k._speed, (double)motion[k.speed]);
	const Vector3 planar = motion[k.velocity];
	Vector3 velocity = tank->get_velocity();
	velocity.x = planar.x;
	velocity.z = planar.z;
	velocity.y = 0;
	tank->set_velocity(velocity);
	tank->move_and_slide();
	if (std::fabs((double)tank->get_global_position().y) > c.OFF_FLOOR_M && !(bool)tank->get(k._off_floor_said)) {
		tank->call(k._note_off_floor);
	}
	const Vector3 after = tank->get_velocity();
	const Vector3 estimated(after.x, 0, after.z);
	tank->set(k.estimated_velocity, estimated);
	// Round 30 (manoeuvre M4b, C30.6): Tank._real_planar_velocity(): the real flat displacement over dt (the slide's
	// get_real_velocity), capped at the planar velocity asked; estimated_velocity with --tank-off=real_velocity (the
	// static is asked per call, as the GDScript does).
	Vector3 real_velocity = estimated;
	const Ref<Script> tank_script = tank->get_script();
	if (tank_script.is_valid() && (bool)tank_script->get(k.real_velocity_on)) {
		const Vector3 real = tank->get_real_velocity();
		const Vector3 flat(real.x, 0, real.z);
		const double asked = (double)Vector2(after.x, after.z).length();
		const double made = (double)flat.length();
		if (made > asked) {
			real_velocity = made > 0.0 ? flat * (real_t)(asked / made) : Vector3();
		} else {
			real_velocity = flat;
		}
	}
	tank->set(k.real_velocity, real_velocity);
	motion[k.velocity] = estimated;
	if (locomotion != k.tracks) {
		tank->set(k._speed, (double)estimated.dot(forward));
	}
	return true;
}

} // namespace godot
