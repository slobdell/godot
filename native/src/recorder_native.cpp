// Round 28 (native N7.6): MatchRecorder._physics_process in C++ (recorder_native.h), line by line: the same rows, the
// same key order (JSON writes a row's keys in insertion order), the same bytes.
#include "recorder_native.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

namespace {

struct RN {
	StringName game_match{ "game_match" }, orders{ "orders" }, elements{ "elements" }, _file{ "_file" },
			_next_census{ "_next_census" }, _seen_tasks{ "_seen_tasks" }, tick{ "tick" }, tanks{ "tanks" },
			of_team{ "of_team" }, task{ "task" }, id{ "id" }, element_name{ "element_name" }, formation{ "formation" },
			reason{ "reason" }, alive{ "alive" }, team{ "team" }, health{ "health" }, shield{ "shield" },
			current{ "current" }, of{ "of" }, phase{ "phase" }, blocked_by{ "blocked_by" };
	String t{ "t" }, task_s{ "task" }, tick_s{ "tick" }, element{ "element" }, team_s{ "team" }, formation_s{ "formation" },
			why{ "why" }, census{ "census" }, units{ "units" }, n{ "n" }, pos{ "pos" }, hp{ "hp" }, shield_s{ "shield" },
			order{ "order" }, src{ "src" }, phase_s{ "phase" }, blocked{ "blocked" }, verb{ "verb" }, source{ "source" },
			empty{ "" }, blocked_phase{ "blocked" }, yielding{ "yielding" };
};
const RN &rn_() {
	static const RN names;
	return names;
}

// _write: one JSON line, flushed every row.
void write_row(FileAccess *file, const Dictionary &row) {
	file->store_line(JSON::stringify(row));
	file->flush();
}

// MatchRecorder.census_row
Dictionary census_row(const RecorderConfig &c, Node3D *tank, Object *orders) {
	const RN &k = rn_();
	const String name = tank->get_name();
	Dictionary order;
	if (orders != nullptr) {
		order = orders->call(k.current, name);
	}
	String phase;
	String blocked;
	Object *mover = c.movement_script.is_valid() ? (Object *)c.movement_script->call(k.of, tank) : nullptr;
	if (mover != nullptr) {
		phase = String(mover->get(k.phase));
		if (phase == k.blocked_phase || phase == k.yielding) {
			blocked = String(mover->get(k.blocked_by));
		}
	}
	const Vector3 at = tank->get_global_position();
	Array pos;
	pos.push_back(Math::snapped((double)at.x, 0.1));
	pos.push_back(Math::snapped((double)at.z, 0.1));
	const Variant shield = tank->get(k.shield);
	Dictionary row;
	row[k.n] = name;
	row[k.team_s] = tank->get(k.team);
	row[k.pos] = pos;
	row[k.hp] = Math::snapped((double)tank->get(k.health), 0.1);
	row[k.shield_s] = Math::snapped(shield.get_type() == Variant::NIL ? 0.0 : (double)shield, 0.1);
	row[k.order] = String(order.get(k.verb, k.empty));
	row[k.src] = String(order.get(k.source, k.empty));
	row[k.phase_s] = phase;
	row[k.blocked] = blocked;
	return row;
}

// MatchRecorder._record_tasks
void record_tasks(const RecorderConfig &c, Object *recorder, Object *elements, int64_t tick, FileAccess *file) {
	const RN &k = rn_();
	if (elements == nullptr || !elements->has_method(k.of_team)) {
		return;
	}
	Dictionary seen = recorder->get(k._seen_tasks);
	const int64_t teams[2] = { c.GREEN, c.RUST };
	for (const int64_t team : teams) {
		const Array of_team = elements->call(k.of_team, team);
		const int64_t count = of_team.size();
		for (int64_t i = 0; i < count; i++) {
			const Variant element = of_team[i];
			const Variant task = element.get(k.task);
			// "%s|%s" % [element.get("id"), JSON.stringify(task)]
			const String key = String(element.get(k.id)) + "|" + JSON::stringify(task);
			if (seen.has(key)) {
				continue;
			}
			seen[key] = true;
			Dictionary row;
			row[k.t] = k.task_s;
			row[k.tick_s] = tick;
			row[k.element] = String(element.get(k.element_name));
			row[k.team_s] = team;
			row[k.task_s] = task;
			row[k.formation_s] = String(element.get(k.formation));
			row[k.why] = String(element.get(k.reason));
			write_row(file, row);
		}
	}
}

} // namespace

bool recorder_configure(RecorderConfig &c, const Dictionary &config) {
	const char *names[] = { "CENSUS_S", "TICK_RATE", "GREEN", "RUST", "tank", "movement" };
	for (const char *name : names) {
		if (!config.has(name)) {
			c.ready = false;
			return false;
		}
	}
	c.CENSUS_S = config["CENSUS_S"];
	c.TICK_RATE = config["TICK_RATE"];
	c.GREEN = config["GREEN"];
	c.RUST = config["RUST"];
	c.tank_script = config["tank"];
	c.movement_script = config["movement"];
	c.ready = c.tank_script.is_valid() && c.movement_script.is_valid();
	return c.ready;
}

void recorder_tick(const RecorderConfig &c, Object *recorder) {
	const RN &k = rn_();
	if (recorder == nullptr) {
		return;
	}
	FileAccess *file = Object::cast_to<FileAccess>((Object *)recorder->get(k._file));
	Object *game_match = recorder->get(k.game_match);
	if (file == nullptr || game_match == nullptr) {
		return;
	}
	const int64_t tick = game_match->get(k.tick);
	record_tasks(c, recorder, recorder->get(k.elements), tick, file);
	const double now = (double)tick / c.TICK_RATE;
	if (now < (double)recorder->get(k._next_census)) {
		return;
	}
	recorder->set(k._next_census, now + c.CENSUS_S);
	Object *orders = recorder->get(k.orders);
	Node *tanks = Object::cast_to<Node>((Object *)game_match->get(k.tanks));
	Array units;
	if (tanks != nullptr) {
		const int64_t count = tanks->get_child_count();
		for (int64_t i = 0; i < count; i++) {
			Node3D *tank = Object::cast_to<Node3D>(tanks->get_child(i));
			// `child as Tank`, then is_alive()
			if (tank == nullptr || tank->get_script() != Variant(c.tank_script) || !(bool)tank->get(k.alive)) {
				continue;
			}
			units.push_back(census_row(c, tank, orders));
		}
	}
	Dictionary row;
	row[k.t] = k.census;
	row[k.tick_s] = tick;
	row[k.units] = units;
	write_row(file, row);
}

} // namespace godot
