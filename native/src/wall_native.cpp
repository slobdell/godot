// Round 29 (native N7.4): the wall-contact observer's scan (wall_native.h).
#include "wall_native.h"

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>

namespace godot {

namespace {

struct WN {
	StringName alive{ "alive" }, command{ "command" }, throttle{ "throttle" }, turn{ "turn" }, _speed{ "_speed" },
			estimated_velocity{ "estimated_velocity" }, WALL_NORMAL_MAX_Y{ "WALL_NORMAL_MAX_Y" },
			tank_script{ "tank_script" };
};
const WN &wn_() {
	static const WN names;
	return names;
}

// `x is Tank`: the object's script is Tank's or extends it.
bool is_tank(const WallConfig &c, Object *o) {
	if (o == nullptr) {
		return false;
	}
	Ref<Script> s = o->get_script();
	while (s.is_valid()) {
		if (s == c.tank_script) {
			return true;
		}
		s = s->get_base_script();
	}
	return false;
}

} // namespace

bool wall_configure(WallConfig &c, const Dictionary &config) {
	const WN &k = wn_();
	c.WALL_NORMAL_MAX_Y = config.get(k.WALL_NORMAL_MAX_Y, c.WALL_NORMAL_MAX_Y);
	c.tank_script = config.get(k.tank_script, Variant());
	c.ready = c.tank_script.is_valid();
	return c.ready;
}

int64_t wall_scan(const WallConfig &c, Object *tank_obj) {
	const WN &k = wn_();
	CharacterBody3D *tank = Object::cast_to<CharacterBody3D>(tank_obj);
	// `not tank.is_inside_tree() or not tank.is_alive()`
	if (tank == nullptr || !tank->is_inside_tree() || !(bool)tank->get(k.alive)) {
		return -1;
	}
	// `tank.command == null or tank.is_parked(tank.command)`: the command's throttle and turn, the plant's speed,
	// velocity and estimated velocity all exactly zero.
	Object *cmd = tank->get(k.command);
	if (cmd == nullptr) {
		return -1;
	}
	if ((double)cmd->get(k.throttle) == 0.0 && (double)cmd->get(k.turn) == 0.0 && (double)tank->get(k._speed) == 0.0 &&
			tank->get_velocity() == Vector3() && (Vector3)tank->get(k.estimated_velocity) == Vector3()) {
		return -1;
	}
	int64_t wall = -1;
	double wall_depth = 0.0;
	bool hull_hit = false;
	const int n = tank->get_slide_collision_count();
	for (int i = 0; i < n; i++) {
		Ref<KinematicCollision3D> hit = tank->get_slide_collision(i);
		if (is_tank(c, hit->get_collider())) {
			hull_hit = true;
			continue;
		}
		if (std::fabs((double)hit->get_normal().y) > c.WALL_NORMAL_MAX_Y) {
			continue;
		}
		// `wall == null or hit.get_depth() > wall.get_depth()`
		const double depth = hit->get_depth();
		if (wall < 0 || depth > wall_depth) {
			wall = i;
			wall_depth = depth;
		}
	}
	return ((wall + 1) << 1) | (hull_hit ? 1 : 0);
}

} // namespace godot
