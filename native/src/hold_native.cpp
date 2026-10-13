// Round 29 (native): the street hold's record (hold_native.h).
#include "hold_native.h"

#include <godot_cpp/variant/array.hpp>

#include <cstdint>
#include <unordered_map>

namespace godot {

namespace {

struct Hold {
	float x = 0.0f, y = 0.0f, z = 0.0f;
	double since = 0.0;
};

std::unordered_map<uint64_t, Hold> &holds() {
	static std::unordered_map<uint64_t, Hold> table;
	return table;
}

} // namespace

void hold_set(Object *mover, const Vector3 &spot, double since) {
	if (mover == nullptr) {
		return;
	}
	Hold h;
	h.x = spot.x;
	h.y = spot.y;
	h.z = spot.z;
	h.since = since;
	holds()[mover->get_instance_id()] = h;
}

void hold_clear(Object *mover) {
	if (mover != nullptr) {
		holds().erase(mover->get_instance_id());
	}
}

void hold_clear_all() {
	holds().clear();
}

bool hold_has(Object *mover) {
	// The execute asks every crew every tick: an empty table (every tick without a street meeting) costs one size check.
	const std::unordered_map<uint64_t, Hold> &table = holds();
	return mover != nullptr && !table.empty() && table.count(mover->get_instance_id()) != 0;
}

Variant hold_of(Object *mover) {
	if (mover == nullptr) {
		return Variant();
	}
	const auto it = holds().find(mover->get_instance_id());
	if (it == holds().end()) {
		return Variant();
	}
	Array out;
	out.push_back(Vector3(it->second.x, it->second.y, it->second.z));
	out.push_back(it->second.since);
	return out;
}

int hold_count() {
	return (int)holds().size();
}

} // namespace godot
