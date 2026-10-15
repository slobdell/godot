#include "gun_native.h"

#include "exec_view.h"
#include "execute_native.h"

#include <chrono>

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>

namespace godot {

namespace {

struct GN {
	StringName ctl{ "ctl" }, movement{ "movement" }, tank{ "tank" }, tanks_root{ "tanks_root" }, _step{ "_step" },
			weapon{ "weapon" }, kind{ "kind" }, weapon_order{ "weapon_order" }, move_order{ "move_order" }, type{ "type" },
			x{ "x" }, z{ "z" }, name{ "name" }, fallback{ "fallback" }, sector{ "sector" }, sector_cos{ "sector_cos" },
			turret{ "turret" }, projectile_speed_mps{ "projectile_speed_mps" }, game_match{ "game_match" }, tick{ "tick" },
			slot{ "slot" }, mount{ "mount" }, range{ "range" }, preferred_max{ "preferred_max" },
			aim_tolerance_deg{ "aim_tolerance_deg" }, long_shot{ "long_shot" }, estimated_velocity{ "estimated_velocity" },
			alive{ "alive" }, team{ "team" }, aim_point{ "aim_point" }, fire{ "fire" }, turn{ "turn" },
			ammo_fraction{ "ammo_fraction" }, ready_to_fire{ "ready_to_fire" }, sight_radius{ "sight_radius" },
			suppression{ "suppression" }, designated_seconds{ "designated_seconds" }, unit_id{ "unit_id" },
			effective_range{ "effective_range" }, acquisition_enabled{ "acquisition_enabled" },
			crossing_enabled{ "crossing_enabled" }, held_by_acquisition{ "held_by_acquisition" },
			held_by_discipline{ "held_by_discipline" }, held_for_friends{ "held_for_friends" }, for_shot{ "for_shot" },
			for_team{ "for_team" }, aim_wander_m{ "aim_wander_m" }, enemy_columns{ "enemy_columns" }, enemies{ "enemies" },
			tanks_by_name{ "tanks_by_name" }, tanks{ "tanks" }, _apply_indirect{ "_apply_indirect" },
			_nearest_shootable{ "_nearest_shootable" }, native{ "native" }, native_scan{ "native_scan" },
			enemies_of{ "enemies_of" }, perception{ "Perception" }, stop{ "stop" }, fixed{ "fixed" }, aim{ "aim" },
			suppress{ "suppress" }, fire_at_will{ "fire_at_will" }, target{ "target" }, get_parent{ "get_parent" }, simulate{ "simulate" }, ammo{ "ammo" },
			sync_ammo{ "sync_ammo" }, heat_capacity{ "heat_capacity" }, heat{ "heat" }, sync_heat{ "sync_heat" },
			_reload_ticks{ "_reload_ticks" }, sync_reload{ "sync_reload" }, heat_per_shot{ "heat_per_shot" },
			max_ammo{ "max_ammo" }, min_range{ "min_range" }, flight_speed{ "flight_speed" };
};
const GN &gn_() {
	static const GN names;
	return names;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double deg_to_rad(double deg) {
	return deg * (Math::PI / 180.0);
}

// Ballistics.lead_point (proven in round 25's N7 slice, tag n7-weapon-slices).
Vector3 lead_point(const Vector3 &shooter, const Vector3 &target, const Vector3 &target_velocity, double projectile_speed) {
	const Vector3 offset = target - shooter;
	const double a = (double)target_velocity.dot(target_velocity) - projectile_speed * projectile_speed;
	const double b = 2.0 * (double)offset.dot(target_velocity);
	const double c = (double)offset.dot(offset);
	double t = -1.0;
	if (std::fabs(a) < 1e-6) {
		if (std::fabs(b) > 1e-6) {
			t = -c / b;
		}
	} else {
		const double discriminant = b * b - 4.0 * a * c;
		if (discriminant >= 0.0) {
			const double root = std::sqrt(discriminant);
			const double candidates[2] = { (-b - root) / (2.0 * a), (-b + root) / (2.0 * a) };
			for (double candidate : candidates) {
				if (candidate > 0.0 && (t <= 0.0 || candidate < t)) {
					t = candidate;
				}
			}
		}
	}
	if (t <= 0.0) {
		return target;
	}
	return target + target_velocity * (real_t)t;
}

// Difficulty.aim_offset (N7 slice).
Vector3 aim_offset(double wander, int64_t tick, int64_t slot, int64_t period) {
	if (wander <= 0.0) {
		return Vector3();
	}
	static const Vector2 pattern[8] = { Vector2(1, 0), Vector2(-1, -1), Vector2(0, 1), Vector2(1, -1), Vector2(-1, 0),
		Vector2(1, 1), Vector2(0, -1), Vector2(-1, 1) };
	const int64_t step = (tick / period + slot * 3) % 8;
	const Vector2 point = pattern[step] * (real_t)wander;
	return Vector3(point.x, 0.0, point.y);
}

// Ballistics.aim_error (N7 slice).
double aim_error(const Vector3 &origin, const Vector3 &forward, const Vector3 &point) {
	const Vector3 flat_forward(forward.x, 0.0, forward.z);
	const Vector3 to_point((real_t)((double)point.x - (double)origin.x), 0.0, (real_t)((double)point.z - (double)origin.z));
	if ((double)flat_forward.length_squared() < 1e-8 || (double)to_point.length_squared() < 1e-8) {
		return 0.0;
	}
	return std::fabs((double)flat_forward.signed_angle_to(to_point, Vector3(0, 1, 0)));
}

// OrderFeed._number / OrderFeed.point: a sector or a point as a flat Vector3, or NIL.
bool number(const Variant &v) {
	return (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) && std::isfinite((double)v);
}
Variant feed_point(const Variant &value) {
	switch (value.get_type()) {
		case Variant::VECTOR3: {
			const Vector3 p = value;
			return Vector3(p.x, 0.0, p.z);
		}
		case Variant::VECTOR2: {
			const Vector2 p = value;
			return Vector3(p.x, 0.0, p.y);
		}
		case Variant::ARRAY:
		case Variant::PACKED_FLOAT32_ARRAY:
		case Variant::PACKED_FLOAT64_ARRAY: {
			const Array list = value.get_type() == Variant::ARRAY ? (Array)value : Array(value);
			if (list.size() == 2 && number(list[0]) && number(list[1])) {
				return Vector3((real_t)(double)list[0], 0.0, (real_t)(double)list[1]);
			}
			if (list.size() == 3 && number(list[0]) && number(list[2])) {
				return Vector3((real_t)(double)list[0], 0.0, (real_t)(double)list[2]);
			}
		} break;
		default:
			break;
	}
	return Variant();
}

// `object is <script>` (the script or one inheriting it).
bool script_is(Object *object, Object *script) {
	if (object == nullptr || script == nullptr) {
		return false;
	}
	Script *s = Object::cast_to<Script>((Object *)object->get_script());
	while (s != nullptr) {
		if (s == script) {
			return true;
		}
		const Ref<Script> base = s->get_base_script();
		s = base.ptr();
	}
	return false;
}

// Measurement only (the native execute's profile): one part's microseconds while it is on.
struct GunTimed {
	int part;
	bool on;
	std::chrono::steady_clock::time_point t0;
	explicit GunTimed(int p_part) :
			part(p_part), on(execute_profile_is_on()) {
		if (on) {
			t0 = std::chrono::steady_clock::now();
		}
	}
	~GunTimed() {
		if (on) {
			execute_profile_add(part, std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count());
		}
	}
};

template <class V>
struct Gun {
	const GunConfig &g;
	const DriveConfig &dc;
	const GN &k;
	Object *gunnery;
	V v;
	Object *ctl = nullptr;
	Node3D *tank = nullptr;
	Node *tanks_root = nullptr;
	Object *game_match = nullptr; // `ctl as TankBrain`'s game_match (an OrderController has none)
	Dictionary weapon;
	Dictionary weapon_order;
	int64_t step = 1;
	Vector3 here;

	Gun(const GunConfig &p_g, const DriveConfig &p_dc, Object *p_gunnery, const V &p_v) :
			g(p_g), dc(p_dc), k(gn_()), gunnery(p_gunnery), v(p_v) {}

	bool bind() {
		ctl = gunnery->get(k.ctl).get_validated_object();
		if (ctl == nullptr) {
			return false;
		}
		tank = Object::cast_to<Node3D>(ctl->get(k.tank).get_validated_object());
		if (tank == nullptr) {
			return false;
		}
		tanks_root = Object::cast_to<Node>(ctl->get(k.tanks_root).get_validated_object());
		const Variant m = ctl->get(k.game_match);
		game_match = m.get_type() == Variant::OBJECT ? m.get_validated_object() : nullptr;
		step = ctl->get(k._step);
		here = tank->get_global_position();
		return true;
	}

	// A call into GDScript that may read this crew's state (the owned view pushes its changes first) and one that may
	// write it (pushed first, pulled after).
	template <typename... Args>
	Variant gd(Object *object, const StringName &method, const Args &...args) {
		GunTimed t(9);
		v.push_out();
		return object->call(method, args...);
	}
	template <typename... Args>
	Variant cb(const StringName &method, const Args &...args) {
		GunTimed t(9);
		v.push_out();
		const Variant answer = gunnery->call(method, args...);
		v.pull_in();
		return answer;
	}

	void sadd(Object *script, const StringName &name, int64_t by) {
		script->set(name, (int64_t)script->get(name) + by);
	}

	Vector3 turret_forward() const {
		Node3D *turret = Object::cast_to<Node3D>(tank->get(k.turret).get_validated_object());
		const Vector3 forward = -turret->get_global_transform().basis.get_column(2);
		return Vector3(forward.x, 0, forward.z).normalized();
	}
	Vector3 muzzle() const {
		return Object::cast_to<Node3D>(tank->get(k.turret).get_validated_object())->get_global_position();
	}
	// Tank.shells_left / ready_to_fire / ammo_fraction (game/tank/tank.gd), read off the hull's members (round 27: a call
	// into GDScript each was most of the gun's remaining cost; test_native_gun and native-proof hold them to the live ones):
	//   shells_left: ammo if simulate else sync_ammo
	//   ready_to_fire: current_heat := heat if simulate else sync_heat * heat_capacity
	//                  reloaded := _reload_ticks <= 1 if simulate else sync_reload >= 1.0
	//                  reloaded and shells_left() != 0 and current_heat + float(weapon.get("heat_per_shot", 0.0)) <= heat_capacity + 0.001
	//   ammo_fraction: 1.0 if max_ammo <= 0 else float(maxi(shells_left(), 0)) / max_ammo
	int64_t shells_left() {
		return (bool)tank->get(k.simulate) ? (int64_t)tank->get(k.ammo) : (int64_t)tank->get(k.sync_ammo);
	}
	bool ready_to_fire() {
		const bool simulate = tank->get(k.simulate);
		const double heat_capacity = tank->get(k.heat_capacity);
		const double current_heat = simulate ? (double)tank->get(k.heat) : (double)tank->get(k.sync_heat) * heat_capacity;
		const bool reloaded = simulate ? (int64_t)tank->get(k._reload_ticks) <= 1 : (double)tank->get(k.sync_reload) >= 1.0;
		if (!reloaded || shells_left() == 0) {
			return false;
		}
		const Dictionary w = tank->get(k.weapon);
		return current_heat + (double)w.get(k.heat_per_shot, 0.0) <= heat_capacity + 0.001;
	}
	double ammo_fraction() {
		const int64_t max_ammo = tank->get(k.max_ammo);
		return max_ammo <= 0 ? 1.0 : (double)MAX(shells_left(), (int64_t)0) / (double)max_ammo;
	}

	// Gunnery._cover(point, cmd)
	void cover(const Vector3 &point, Object *cmd) {
		cmd->set(k.aim_point, point);
		const Vector3 flat((real_t)((double)point.x - (double)here.x), 0, (real_t)((double)point.z - (double)here.z));
		if ((double)flat.length_squared() > 0.25) {
			v.set_g__held_aim(flat.normalized());
		}
	}

	// Perception.has_line_of_sight(viewer, target): the same engine ray.
	bool line_of_sight(Node3D *viewer, Node3D *target) {
		GunTimed t(10);
		PhysicsDirectSpaceState3D *space = viewer->get_world_3d()->get_direct_space_state();
		const Vector3 up = Vector3(0, 1, 0) * (real_t)g.EYE_HEIGHT;
		Ref<PhysicsRayQueryParameters3D> query = PhysicsRayQueryParameters3D::create(viewer->get_global_position() + up,
				target->get_global_position() + up, (uint32_t)g.WORLD_MASK);
		return space->intersect_ray(query).is_empty();
	}

	// Engagement.is_seen(tank, enemy, spotter)
	bool is_seen(Node3D *enemy) {
		if (!(bool)g.engagement->get(k.acquisition_enabled)) {
			return true;
		}
		const Callable spotter = v.g_spotter();
		if (spotter.is_valid()) {
			GunTimed t(11);
			v.push_out();
			return spotter.call(enemy);
		}
		return (double)here.distance_to(enemy->get_global_position()) <= (double)tank->get(k.sight_radius);
	}

	// Gunnery._shootable(enemy)
	bool shootable(Node3D *enemy) {
		if ((double)here.distance_to(enemy->get_global_position()) > (double)weapon[k.range]) {
			return false;
		}
		if (!is_seen(enemy)) {
			return false;
		}
		return line_of_sight(tank, enemy);
	}

	bool brain_owns_root() const {
		return game_match != nullptr && game_match->get(k.tanks).get_validated_object() == tanks_root;
	}

	// Gunnery._nearest_shootable: the native scan's seam goes back to the GDScript (which runs N3b); otherwise the loop.
	Variant nearest_shootable() {
		if ((bool)g.switches->get(k.native) && (bool)g.switches->get(k.native_scan) && tanks_root != nullptr &&
				script_is(tanks_root->get_parent(), g.match_script)) {
			return cb(k._nearest_shootable);
		}
		Node3D *best = nullptr;
		double best_distance = INFINITY;
		Node3D *in_sector = nullptr;
		double in_sector_distance = INFINITY;
		Vector3 sector;
		double sector_cos = -1.0;
		const Variant facing = weapon_order.get(k.sector, Variant());
		if (facing.get_type() != Variant::NIL) {
			const Variant point = feed_point(facing);
			if (point.get_type() != Variant::NIL && (double)((Vector3)point).length_squared() > 0.0001) {
				sector = ((Vector3)point).normalized();
				sector_cos = weapon_order.get(k.sector_cos, 0.5);
			}
		}
		const int64_t team = tank->get(k.team);
		Array columns;
		Array enemies;
		if (brain_owns_root()) {
			columns = gd(g.ai_tick_cache, k.enemy_columns, game_match, team);
			enemies = columns[0];
		} else {
			enemies = gd(g.perception, k.enemies_of, tank, tanks_root);
		}
		const double reach = weapon[k.range];
		PackedFloat32Array xs, ys, zs;
		const bool have_columns = !columns.is_empty();
		if (have_columns) {
			xs = columns[1];
			ys = columns[2];
			zs = columns[3];
		}
		for (int64_t index = 0; index < enemies.size(); index++) {
			Node3D *enemy = Object::cast_to<Node3D>(enemies[index].get_validated_object());
			if (enemy == nullptr) {
				continue;
			}
			const Vector3 there = have_columns ? Vector3(xs[index], ys[index], zs[index]) : enemy->get_global_position();
			const double distance = here.distance_to(there);
			if (distance >= best_distance && (sector == Vector3() || distance >= in_sector_distance)) {
				continue;
			}
			if (distance > reach || !shootable(enemy)) {
				continue;
			}
			if (distance < best_distance) {
				best = enemy;
				best_distance = distance;
			}
			if (sector != Vector3() && distance < in_sector_distance) {
				Vector3 toward = there - here;
				toward.y = 0;
				if ((double)toward.length_squared() > 0.01 && (double)toward.normalized().dot(sector) >= sector_cos) {
					in_sector = enemy;
					in_sector_distance = distance;
				}
			}
		}
		Node3D *pick = in_sector != nullptr ? in_sector : best;
		return pick != nullptr ? Variant(pick) : Variant();
	}

	// Gunnery._scanned_shootable()
	Node3D *scanned_shootable() {
		int64_t scan_left = v.g__scan_left() - step;
		v.set_g__scan_left(scan_left);
		Node3D *pick = Object::cast_to<Node3D>(v.g__scan_pick().get_validated_object());
		const bool pick_alive = pick != nullptr && (bool)pick->get(k.alive);
		if (pick_alive && !ready_to_fire()) {
			if (scan_left <= 0) {
				v.set_g__scan_left(g.SCAN_EVERY_TICKS);
			}
			return pick;
		}
		if (scan_left > 0 && pick_alive && shootable(pick)) {
			return pick;
		}
		v.set_g__scan_left(g.SCAN_EVERY_TICKS);
		const Variant found = nearest_shootable();
		v.set_g__scan_pick(found);
		return Object::cast_to<Node3D>(found.get_validated_object());
	}

	// Gunnery._named_tank(name)
	Node3D *named_tank(const String &name) {
		// AiTickCache.tanks_by_name(match) is Match.tanks_by_name(): every hull under match.tanks keyed by its name, the
		// same node get_node_or_null finds when match.tanks is tanks_root (brain_owns_root); the cache's per-tick refresh
		// is the think step's (it runs before this crew's execute). Only a Tank counts (`as Tank`): one with `alive`.
		Node3D *found = Object::cast_to<Node3D>(tanks_root->get_node_or_null(NodePath(name)));
		return found != nullptr && found->get(k.alive).get_type() == Variant::BOOL ? found : nullptr;
	}

	// Gunnery._clear_to_fire(would_fire, aim)
	bool clear_to_fire(bool would_fire, const Vector3 &aim) {
		if (!would_fire) {
			return false;
		}
		if (!v.g_hold_for_friends()) {
			return true;
		}
		const int64_t hold_left = v.g__lane_hold_left();
		if (hold_left > 0) {
			v.set_g__lane_hold_left(hold_left - step);
			v.set_g_lane_blocked_ticks(v.g_lane_blocked_ticks() + step);
			sadd(g.order_controller, k.held_for_friends, 1);
			return false;
		}
		const Array blockers = gd(g.fire_lanes, k.for_shot, tanks_root, tank, aim);
		if (blockers.is_empty()) {
			v.set_g_lane_blocked_ticks(0);
			v.set_g_lane_blocker(String());
			return true;
		}
		v.set_g_lane_blocked_ticks(v.g_lane_blocked_ticks() + step);
		v.set_g_lane_blocker(String(blockers[0]));
		sadd(g.order_controller, k.held_for_friends, 1);
		v.set_g__lane_hold_left(g.LANE_RECHECK_TICKS - 1);
		return false;
	}

	bool is_scout() {
		const String unit = tank->get(k.unit_id);
		const bool *known = g.scout_of.getptr(unit);
		if (known != nullptr) {
			return *known;
		}
		static const String scout("scout");
		const bool value = String(g.units->call(StringName("role_of"), unit)) == scout;
		g.scout_of.insert(unit, value);
		return value;
	}

	// Engagement.crossing_rate(tank, target, distance)
	double crossing_rate(Node3D *target, double distance) {
		if (distance <= 0.5) {
			return 0.0;
		}
		Vector3 sight_line = target->get_global_position() - here;
		sight_line.y = 0.0;
		if ((double)sight_line.length_squared() <= 0.0) {
			return 0.0;
		}
		sight_line = sight_line.normalized();
		Vector3 velocity = target->get(k.estimated_velocity);
		velocity.y = 0.0;
		const double along = (double)velocity.dot(sight_line);
		return (double)(velocity - sight_line * (real_t)along).length() / distance;
	}

	// Engagement.acquire_seconds(tank, target, distance)
	double acquire_seconds(Node3D *target, double distance) {
		const double sight = MAX((double)tank->get(k.sight_radius), 1.0);
		const double reach = clampd(distance / sight, 0.0, 1.0);
		double seconds = g.ACQUIRE_NEAR_SECONDS + (g.ACQUIRE_FAR_SECONDS - g.ACQUIRE_NEAR_SECONDS) * reach;
		seconds *= 1.0 + g.SUPPRESSION_ACQUIRE_PENALTY * clampd((double)tank->get(k.suppression), 0.0, 1.0);
		if (target != nullptr && (bool)g.engagement->get(k.crossing_enabled)) {
			const double crossing = crossing_rate(target, distance) / g.CROSSING_REFERENCE_RATE;
			seconds *= 1.0 + g.CROSSING_ACQUIRE_PENALTY * clampd(crossing, 0.0, g.CROSSING_ACQUIRE_MAX);
		}
		if (is_scout()) {
			seconds *= g.SCOUT_ACQUIRE_SCALE;
		}
		if (target != nullptr && (double)target->get(k.designated_seconds) > 0.0) {
			seconds *= g.DESIGNATED_ACQUIRE_SCALE;
		}
		return seconds;
	}

	// Engagement.Lay.engage(tank, contact, distance, seconds, ordered) on the crew's lay
	bool engage(Node3D *contact, double distance, double seconds, bool ordered) {
		const String target_name = contact != nullptr ? String(contact->get_name()) : String();
		if (target_name != v.l_target()) {
			v.set_l_target(target_name);
			v.set_l_progress(0.0);
			v.set_l_firing(false);
		}
		if (!(bool)g.engagement->get(k.acquisition_enabled)) {
			v.set_l_progress(INFINITY);
		} else {
			const double needed = acquire_seconds(contact, distance);
			const double progress = MIN(v.l_progress() + seconds, needed);
			v.set_l_progress(progress);
			if (progress < needed) {
				v.set_l_firing(false);
				sadd(g.engagement, k.held_by_acquisition, 1);
				return false;
			}
		}
		const double reach = weapon.get(k.range, 0.0);
		double limit = weapon.get(k.effective_range, reach);
		if (ordered || (double)tank->get(k.suppression) >= g.RETURN_FIRE_SUPPRESSION) {
			limit = weapon.get(k.range, limit);
		} else if (v.l_firing()) {
			limit *= g.RELEASE_FACTOR;
		}
		const bool firing = distance <= limit;
		v.set_l_firing(firing);
		if (!firing) {
			sadd(g.engagement, k.held_by_discipline, 1);
		}
		return firing;
	}

	// Engagement.Lay.lose(seconds)
	void lose(double seconds) {
		v.set_l_firing(false);
		v.set_l_progress(MAX(0.0, v.l_progress() - seconds * g.LOST_LAY_DECAY));
	}

	double wander(int64_t team) {
		if (team < 0 || team > 1) {
			const Dictionary level = g.difficulty->call(k.for_team, team);
			return level[k.aim_wander_m];
		}
		const int64_t now = (int64_t)Engine::get_singleton()->get_physics_frames();
		if (g.wander_frame != now) {
			g.wander_frame = now;
			g.wander_known[0] = g.wander_known[1] = false;
		}
		if (!g.wander_known[team]) {
			const Dictionary level = g.difficulty->call(k.for_team, team);
			g.wander_of[team] = level[k.aim_wander_m];
			g.wander_known[team] = true;
		}
		return g.wander_of[team];
	}

	void fixed_mount_swing(Object *cmd, const Vector3 &aim) {
		static const String fixed("fixed"), stop("stop");
		const Dictionary move_order = ctl->get(k.move_order);
		if (String(tank->get(k.mount)) == fixed && String(move_order[k.type]) == stop) {
			const Vector3 forward = -tank->get_global_transform().basis.get_column(2);
			cmd->set(k.turn, (double)steering_drive_toward(dc, here, forward, aim, 0.0).y);
		}
	}

	// Gunnery._apply_suppress(cmd)
	void apply_suppress(Object *cmd) {
		Vector3 aim((real_t)(double)weapon_order[k.x], 0.0, (real_t)(double)weapon_order[k.z]);
		const Vector3 muzzle_at = muzzle();
		aim.y = muzzle_at.y;
		cover(aim, cmd);
		fixed_mount_swing(cmd, aim);
		bool in_range = (double)muzzle_at.distance_to(aim) <= (double)weapon[k.range];
		const double ammo = ammo_fraction(); // asked twice by the GDScript: a pure read
		if (ammo >= 0.0 && ammo <= g.LOW_AMMO_FRACTION) {
			in_range = false;
		}
		const bool aimed = aim_error(muzzle_at, turret_forward(), aim) <= deg_to_rad((double)weapon[k.aim_tolerance_deg]);
		cmd->set(k.fire, clear_to_fire(in_range && aimed && ready_to_fire(), aim));
	}

	// Gunnery._apply_indirect(cmd) (round 27: was the gun's last whole callback), line by line:
	//   if tanks_root == null or type in ["hold_fire", "aim"]: aim -> _cover(spot); elif watch_point: _cover(watch); return
	//   sees := spotter if spotter.is_valid() else Perception.has_line_of_sight(tank, other)
	//   in_window := d >= weapon["min_range"] and d <= weapon["range"]   (d: hull to hull)
	//   target: a named target (alive, an enemy, seen, in the window); else under fire_at_will or a fallback the nearest
	//   enemy (_enemies(), in order) in the window and seen; none -> engaged_target = "", cover the watch point, return
	//   flight := d / weapon["flight_speed"]; aim := target + velocity * flight; _cover(aim)
	//   cmd.fire = _clear_to_fire(aim_error(muzzle, turret_forward, aim) <= tolerance and ready_to_fire(), aim)
	bool sees(Node3D *other) {
		const Callable spotter = v.g_spotter();
		if (spotter.is_valid()) {
			GunTimed t(11);
			v.push_out();
			return spotter.call(other);
		}
		return line_of_sight(tank, other);
	}
	bool in_window(Node3D *other) {
		const double d = here.distance_to(other->get_global_position());
		return d >= (double)weapon[k.min_range] && d <= (double)weapon[k.range];
	}
	void apply_indirect(Object *cmd) {
		static const String hold_fire("hold_fire"), t_aim("aim"), t_target("target"), t_fire_at_will("fire_at_will");
		weapon_order = ctl->get(k.weapon_order);
		const Variant type = weapon_order[k.type];
		if (tanks_root == nullptr || type == Variant(hold_fire) || type == Variant(t_aim)) {
			if (type == Variant(t_aim)) {
				cover(Vector3((real_t)(double)weapon_order[k.x], 0.0, (real_t)(double)weapon_order[k.z]), cmd);
			} else if (v.g_watch_point().get_type() != Variant::NIL) {
				cover((Vector3)v.g_watch_point(), cmd);
			}
			return;
		}
		Node3D *target = nullptr;
		if (type == Variant(t_target)) {
			Node3D *named = named_tank(String(weapon_order[k.name]));
			if (named != nullptr && (bool)named->get(k.alive) && (int64_t)named->get(k.team) != (int64_t)tank->get(k.team) &&
					sees(named) && in_window(named)) {
				target = named;
			}
		}
		if (target == nullptr && (type == Variant(t_fire_at_will) || (bool)weapon_order.get(k.fallback, false))) {
			double best_distance = INFINITY;
			const Array enemies = brain_owns_root() ? (Array)gd(g.ai_tick_cache, k.enemies, game_match, tank->get(k.team)) :
													  (Array)gd(g.perception, k.enemies_of, tank, tanks_root);
			for (int64_t i = 0; i < enemies.size(); i++) {
				Node3D *enemy = Object::cast_to<Node3D>(enemies[i].get_validated_object());
				if (enemy == nullptr) {
					continue;
				}
				const double d = here.distance_to(enemy->get_global_position());
				if (d < best_distance && in_window(enemy) && sees(enemy)) {
					best_distance = d;
					target = enemy;
				}
			}
		}
		if (target == nullptr) {
			v.set_g_engaged_target(String());
			if (v.g_watch_point().get_type() != Variant::NIL) {
				cover((Vector3)v.g_watch_point(), cmd);
			}
			return;
		}
		v.set_g_engaged_target(String(target->get_name()));
		const Vector3 target_at = target->get_global_position();
		const double flight = (double)here.distance_to(target_at) / (double)weapon[k.flight_speed];
		const Vector3 velocity = target->get(k.estimated_velocity);
		const Vector3 aim = target_at + velocity * (real_t)flight;
		cover(aim, cmd);
		const bool aimed = aim_error(muzzle(), turret_forward(), aim) <= deg_to_rad((double)weapon[k.aim_tolerance_deg]);
		cmd->set(k.fire, clear_to_fire(aimed && ready_to_fire(), aim));
	}

	// Gunnery._apply_weapon(cmd)
	void apply_weapon(Object *cmd) {
		static const String t_aim("aim"), t_suppress("suppress"), t_fire_at_will("fire_at_will"), t_target("target");
		v.set_g_engaged_target(String());
		weapon = tank->get(k.weapon);
		if ((int64_t)weapon[k.kind] == g.KIND_ARC) {
			apply_indirect(cmd);
			return;
		}
		weapon_order = ctl->get(k.weapon_order);
		Node3D *target = nullptr;
		const Variant type = weapon_order[k.type];
		if (type == Variant(t_aim)) {
			cover(Vector3((real_t)(double)weapon_order[k.x], 0.0, (real_t)(double)weapon_order[k.z]), cmd);
			return;
		} else if (type == Variant(t_suppress)) {
			apply_suppress(cmd);
			return;
		} else if (type == Variant(t_fire_at_will)) {
			if (tanks_root != nullptr) {
				target = scanned_shootable();
			}
		} else if (type == Variant(t_target)) {
			if (tanks_root != nullptr) {
				Node3D *named = named_tank(String(weapon_order[k.name]));
				if (named != nullptr && (bool)named->get(k.alive) && (int64_t)named->get(k.team) != (int64_t)tank->get(k.team) &&
						shootable(named)) {
					target = named;
				} else if ((bool)weapon_order.get(k.fallback, false)) {
					target = scanned_shootable();
				}
			}
		}
		const double seconds = v.g__seconds();
		if (target == nullptr) {
			lose(seconds);
			const Variant watch = v.g_watch_point();
			if (watch.get_type() != Variant::NIL) {
				cover((Vector3)watch, cmd);
			} else if (weapon_order.get(k.sector, Variant()).get_type() != Variant::NIL) {
				const Variant sector = feed_point(weapon_order[k.sector]);
				if (sector.get_type() == Variant::VECTOR3 && (double)((Vector3)sector).length_squared() > 0.0001) {
					cover(here + ((Vector3)sector).normalized() * (real_t)g.HELD_AIM_DISTANCE, cmd);
				}
			}
			return;
		}
		v.set_g_engaged_target(String(target->get_name()));
		const Vector3 muzzle_at = muzzle();
		const Vector3 target_at = target->get_global_position();
		Vector3 aim = target_at;
		if ((int64_t)weapon[k.kind] == g.KIND_PROJECTILE) {
			const double round_speed = weapon.get(k.projectile_speed_mps, 0.0);
			aim = lead_point(muzzle_at, target_at, target->get(k.estimated_velocity), round_speed > 0.0 ? round_speed : g.SHELL_SPEED);
		}
		if (game_match != nullptr) {
			aim += aim_offset(wander(tank->get(k.team)), game_match->get(k.tick), tank->get(k.slot), g.WANDER_PERIOD_TICKS);
		}
		cover(aim, cmd);
		fixed_mount_swing(cmd, aim);
		const double distance = muzzle_at.distance_to(aim);
		bool in_range = distance <= (double)weapon[k.range];
		if (ammo_fraction() <= g.LOW_AMMO_FRACTION && distance > (double)weapon[k.preferred_max]) {
			in_range = false;
		}
		const bool aimed = aim_error(muzzle_at, turret_forward(), aim) <= deg_to_rad((double)weapon[k.aim_tolerance_deg]);
		const bool envelope = engage(target, here.distance_to(target_at), seconds, weapon_order.get(k.long_shot, false));
		cmd->set(k.fire, clear_to_fire(envelope && in_range && aimed && ready_to_fire(), aim));
	}

	// Gunnery.apply(cmd, seconds)
	void apply(Object *cmd, double seconds) {
		v.set_g__seconds(seconds);
		v.set_g_ticks_since_fire(v.g_ticks_since_fire() + step);
		apply_weapon(cmd);
		if ((bool)cmd->get(k.fire)) {
			v.set_g_ticks_since_fire(0);
		}
	}
};

} // namespace

Variant order_feed_point(const Variant &value) {
	return feed_point(value);
}

bool gun_configure(GunConfig &c, const Dictionary &config) {
	c.ready = false;
	const char *ints[] = { "SCAN_EVERY_TICKS", "LANE_RECHECK_TICKS", "WANDER_PERIOD_TICKS", "KIND_PROJECTILE", "KIND_ARC",
		"WORLD_MASK" };
	int64_t *int_targets[] = { &c.SCAN_EVERY_TICKS, &c.LANE_RECHECK_TICKS, &c.WANDER_PERIOD_TICKS, &c.KIND_PROJECTILE,
		&c.KIND_ARC, &c.WORLD_MASK };
	for (size_t i = 0; i < sizeof(ints) / sizeof(ints[0]); i++) {
		if (!config.has(ints[i])) {
			return false;
		}
		*int_targets[i] = config[ints[i]];
	}
	const char *doubles[] = { "LOW_AMMO_FRACTION", "HELD_AIM_DISTANCE", "SHELL_SPEED", "EYE_HEIGHT", "ACQUIRE_NEAR_SECONDS",
		"ACQUIRE_FAR_SECONDS", "SUPPRESSION_ACQUIRE_PENALTY", "DESIGNATED_ACQUIRE_SCALE", "SCOUT_ACQUIRE_SCALE",
		"CROSSING_ACQUIRE_PENALTY", "CROSSING_REFERENCE_RATE", "CROSSING_ACQUIRE_MAX", "LOST_LAY_DECAY", "RELEASE_FACTOR",
		"RETURN_FIRE_SUPPRESSION" };
	double *targets[] = { &c.LOW_AMMO_FRACTION, &c.HELD_AIM_DISTANCE, &c.SHELL_SPEED, &c.EYE_HEIGHT, &c.ACQUIRE_NEAR_SECONDS,
		&c.ACQUIRE_FAR_SECONDS, &c.SUPPRESSION_ACQUIRE_PENALTY, &c.DESIGNATED_ACQUIRE_SCALE, &c.SCOUT_ACQUIRE_SCALE,
		&c.CROSSING_ACQUIRE_PENALTY, &c.CROSSING_REFERENCE_RATE, &c.CROSSING_ACQUIRE_MAX, &c.LOST_LAY_DECAY, &c.RELEASE_FACTOR,
		&c.RETURN_FIRE_SUPPRESSION };
	for (size_t i = 0; i < sizeof(doubles) / sizeof(doubles[0]); i++) {
		if (!config.has(doubles[i])) {
			return false;
		}
		*targets[i] = config[doubles[i]];
	}
	c.keep_engagement = config.get("engagement", Variant());
	c.keep_order_controller = config.get("order_controller", Variant());
	c.keep_difficulty = config.get("difficulty", Variant());
	c.keep_ai_tick_cache = config.get("ai_tick_cache", Variant());
	c.keep_fire_lanes = config.get("fire_lanes", Variant());
	c.keep_units = config.get("units", Variant());
	c.keep_switches = config.get("switches", Variant());
	c.keep_perception = config.get("perception", Variant());
	c.keep_match_script = config.get("match_script", Variant());
	c.engagement = c.keep_engagement.get_validated_object();
	c.order_controller = c.keep_order_controller.get_validated_object();
	c.difficulty = c.keep_difficulty.get_validated_object();
	c.ai_tick_cache = c.keep_ai_tick_cache.get_validated_object();
	c.fire_lanes = c.keep_fire_lanes.get_validated_object();
	c.units = c.keep_units.get_validated_object();
	c.switches = c.keep_switches.get_validated_object();
	c.perception = c.keep_perception.get_validated_object();
	c.match_script = c.keep_match_script.get_validated_object();
	c.scout_of.clear();
	c.wander_frame = -1;
	c.ready = c.engagement && c.order_controller && c.difficulty && c.ai_tick_cache && c.fire_lanes && c.units &&
			c.switches && c.perception && c.match_script;
	return c.ready;
}

bool gun_apply(const GunConfig &gun, const DriveConfig &drive, Object *gunnery, Object *cmd, double seconds, bool owned) {
	if (!gun.ready || !drive.ready || gunnery == nullptr || cmd == nullptr) {
		return false;
	}
	const GN &k = gn_();
	Object *ctl = gunnery->get(k.ctl).get_validated_object();
	Object *mover = ctl != nullptr ? ctl->get(k.movement).get_validated_object() : nullptr;
	if (mover == nullptr) {
		return false;
	}
	if (!owned) {
		return gun_with(gun, drive, gunnery, cmd, seconds, nullptr);
	}
	ExecState local;
	local.pull(mover);
	const bool done = gun_with(gun, drive, gunnery, cmd, seconds, &local);
	local.push(mover, false);
	return done;
}

bool gun_with(const GunConfig &gun, const DriveConfig &drive, Object *gunnery, Object *cmd, double seconds, ExecState *state) {
	if (!gun.ready || !drive.ready || gunnery == nullptr || cmd == nullptr) {
		return false;
	}
	const GN &k = gn_();
	Object *ctl = gunnery->get(k.ctl).get_validated_object();
	Object *mover = ctl != nullptr ? ctl->get(k.movement).get_validated_object() : nullptr;
	if (mover == nullptr) {
		return false;
	}
	if (state == nullptr) {
		ObjectView view(mover);
		view.bind_gunnery();
		Gun<ObjectView> g(gun, drive, gunnery, view);
		if (!g.bind()) {
			return false;
		}
		g.apply(cmd, seconds);
		return true;
	}
	Gun<StructView> g(gun, drive, gunnery, StructView(mover, state));
	if (!g.bind()) {
		return false;
	}
	g.apply(cmd, seconds);
	return true;
}

} // namespace godot
