// Round 28 (native N7.2): the suppression field in C++ (threat_native.h), line by line in the GDScript's widths (doubles
// for its floats, float32 for its vectors and the density array: native.md hazard 1).
#include "threat_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>

namespace godot {

namespace {

struct TN {
	StringName cell_size{ "cell_size" }, cols{ "cols" }, rows{ "rows" }, origin{ "origin" }, density{ "density" },
			_active{ "_active" }, _is_active{ "_is_active" }, alive{ "alive" }, team{ "team" },
			suppression{ "suppression" }, sight_radius{ "sight_radius" }, hull_turn_rate{ "hull_turn_rate" },
			_calm_sight{ "_calm_sight" }, _calm_hull_turn{ "_calm_hull_turn" }, _shown_sight{ "_shown_sight" },
			_shown_hull_turn{ "_shown_hull_turn" }, global_position{ "global_position" };
	String suppression_samples{ "suppression_samples" }, suppression_total{ "suppression_total" },
			pinned_samples{ "pinned_samples" };
};
const TN &tn_() {
	static const TN names;
	return names;
}

// One ThreatField's state, taken out of the object for the call and put back after. The object's arrays are swapped for
// empty ones while we hold them, so ours are the only reference and writing them never copies (copy-on-write).
struct Field {
	Object *object = nullptr;
	double cell_size = 6.0;
	int64_t cols = 0, rows = 0;
	Vector3 origin;
	PackedFloat32Array density;
	PackedInt32Array active;
	PackedByteArray is_active;
	bool writes = false;

	Field(Object *p_object, bool p_writes) : object(p_object), writes(p_writes) {
		const TN &k = tn_();
		cell_size = object->get(k.cell_size);
		cols = object->get(k.cols);
		rows = object->get(k.rows);
		origin = object->get(k.origin);
		density = object->get(k.density);
		if (writes) {
			active = object->get(k._active);
			is_active = object->get(k._is_active);
			object->set(k.density, PackedFloat32Array());
			object->set(k._active, PackedInt32Array());
			object->set(k._is_active, PackedByteArray());
		}
	}
	~Field() {
		if (writes) {
			const TN &k = tn_();
			object->set(k.density, density);
			object->set(k._active, active);
			object->set(k._is_active, is_active);
		}
	}

	// ThreatField.index_of
	int64_t index_of(const Vector3 &point) const {
		const int64_t col = (int64_t)std::floor(((double)point.x - (double)origin.x) / cell_size);
		const int64_t row = (int64_t)std::floor(((double)point.z - (double)origin.z) / cell_size);
		if (col < 0 || col >= cols || row < 0 || row >= rows) {
			return -1;
		}
		return row * cols + col;
	}
	// ThreatField.at
	double at(const Vector3 &point) const {
		const int64_t index = index_of(point);
		return index >= 0 ? (double)density[index] : 0.0;
	}
	// density[index] += weight; _mark(index)
	void add(int64_t index, double weight) {
		density.set(index, (float)((double)density[index] + weight));
		if (is_active[index] == 0) {
			is_active.set(index, 1);
			active.push_back((int32_t)index);
		}
	}
	// ThreatField.cell_center
	Vector3 cell_center(int64_t col, int64_t row) const {
		return Vector3((real_t)((double)origin.x + ((double)col + 0.5) * cell_size), 0,
				(real_t)((double)origin.z + ((double)row + 0.5) * cell_size));
	}
};

void stamp_point(Field &f, const Vector3 &point, double weight) {
	const int64_t index = f.index_of(point);
	if (index >= 0) {
		f.add(index, weight);
	}
}

} // namespace

bool threat_configure(ThreatConfig &c, const Dictionary &config) {
	const char *names[] = { "MARCH_FRACTION", "EPSILON", "HALF_LIFE_SECONDS", "TICK_RATE", "SUPPRESSION_FULL_DENSITY",
		"PINNED_SUPPRESSION", "SUPPRESSION_RISE_PER_SECOND", "SUPPRESSION_RECOVER_PER_SECOND",
		"SUPPRESSION_SIGHT_PENALTY", "SUPPRESSION_HULL_TURN_PENALTY" };
	for (const char *name : names) {
		if (!config.has(name)) {
			c.ready = false;
			return false;
		}
	}
	c.MARCH_FRACTION = config["MARCH_FRACTION"];
	c.EPSILON = config["EPSILON"];
	c.HALF_LIFE_SECONDS = config["HALF_LIFE_SECONDS"];
	c.TICK_RATE = config["TICK_RATE"];
	c.SUPPRESSION_FULL_DENSITY = config["SUPPRESSION_FULL_DENSITY"];
	c.PINNED_SUPPRESSION = config["PINNED_SUPPRESSION"];
	c.SUPPRESSION_RISE_PER_SECOND = config["SUPPRESSION_RISE_PER_SECOND"];
	c.SUPPRESSION_RECOVER_PER_SECOND = config["SUPPRESSION_RECOVER_PER_SECOND"];
	c.SUPPRESSION_SIGHT_PENALTY = config["SUPPRESSION_SIGHT_PENALTY"];
	c.SUPPRESSION_HULL_TURN_PENALTY = config["SUPPRESSION_HULL_TURN_PENALTY"];
	c.ready = true;
	return true;
}

void threat_stamp_point(const ThreatConfig &, Object *field, const Vector3 &point, double weight) {
	if (field == nullptr) {
		return;
	}
	Field f(field, true);
	stamp_point(f, point, weight);
}

// ThreatField.stamp_segment
void threat_stamp_segment(const ThreatConfig &c, Object *field, const Vector3 &from, const Vector3 &to, double weight) {
	if (field == nullptr) {
		return;
	}
	Field f(field, true);
	const Vector2 span((real_t)((double)to.x - (double)from.x), (real_t)((double)to.z - (double)from.z));
	const double length = span.length();
	if (length < 0.01) {
		stamp_point(f, from, weight);
		return;
	}
	const double step = f.cell_size * c.MARCH_FRACTION;
	const int64_t steps = (int64_t)(length / step) + 1;
	int64_t last = -1;
	for (int64_t i = 0; i < steps + 1; i++) {
		const double travelled = MIN(length, (double)i * step);
		const Vector3 spot((real_t)((double)from.x + (double)span.x / length * travelled), 0,
				(real_t)((double)from.z + (double)span.y / length * travelled));
		const int64_t index = f.index_of(spot);
		if (index >= 0 && index != last) {
			f.add(index, weight);
		}
		last = index;
	}
}

// ThreatField.stamp_burst
void threat_stamp_burst(const ThreatConfig &, Object *field, const Vector3 &center, double radius, double weight) {
	if (field == nullptr) {
		return;
	}
	Field f(field, true);
	const double cs = f.cell_size;
	const int64_t min_col = MAX((int64_t)0, (int64_t)std::floor(((double)center.x - radius - (double)f.origin.x) / cs));
	const int64_t max_col = MIN(f.cols - 1, (int64_t)std::floor(((double)center.x + radius - (double)f.origin.x) / cs));
	const int64_t min_row = MAX((int64_t)0, (int64_t)std::floor(((double)center.z - radius - (double)f.origin.z) / cs));
	const int64_t max_row = MIN(f.rows - 1, (int64_t)std::floor(((double)center.z + radius - (double)f.origin.z) / cs));
	for (int64_t row = min_row; row < max_row + 1; row++) {
		for (int64_t col = min_col; col < max_col + 1; col++) {
			const Vector3 spot = f.cell_center(col, row);
			const Vector2 off((real_t)((double)spot.x - (double)center.x), (real_t)((double)spot.z - (double)center.z));
			if ((double)off.length() <= radius) {
				f.add(row * f.cols + col, weight);
			}
		}
	}
}

// ThreatField.decay
void threat_decay(const ThreatConfig &c, Object *field, int64_t ticks) {
	if (field == nullptr || ticks <= 0) {
		return;
	}
	Field f(field, true);
	const double factor = std::pow(0.5, (double)ticks / c.TICK_RATE / c.HALF_LIFE_SECONDS);
	int64_t kept = 0;
	const int64_t count = f.active.size();
	for (int64_t n = 0; n < count; n++) {
		const int32_t i = f.active[n];
		const double value = (double)f.density[i] * factor;
		if (value > c.EPSILON) {
			f.density.set(i, (float)value);
			f.active.set(kept, i);
			kept++;
		} else {
			f.density.set(i, 0.0f);
			f.is_active.set(i, 0);
		}
	}
	f.active.resize(kept);
}

// Match._update_suppression after the decay (the GDScript seam decays first, through threat_decay or its own), and
// Tank.settle_suppression / _apply_suppression_effects / is_pinned.
void suppression_update(const ThreatConfig &c, const Array &fields, const Array &tanks, const Dictionary &stats,
		int64_t sample_ticks) {
	const TN &k = tn_();
	if (fields.size() < 2) {
		return;
	}
	Object *f0 = fields[0];
	Object *f1 = fields[1];
	if (f0 == nullptr || f1 == nullptr) {
		return;
	}
	const Field field[2] = { Field(f0, false), Field(f1, false) };
	const double seconds = (double)sample_ticks / c.TICK_RATE;
	Array samples = stats[k.suppression_samples];
	Array totals = stats[k.suppression_total];
	Array pinned = stats[k.pinned_samples];
	const int64_t count = tanks.size();
	for (int64_t n = 0; n < count; n++) {
		Object *tank = tanks[n];
		if (tank == nullptr || !(bool)tank->get(k.alive)) {
			continue;
		}
		const int64_t team = tank->get(k.team);
		const double density = field[team].at(tank->get(k.global_position));
		const double target = CLAMP(density / c.SUPPRESSION_FULL_DENSITY, 0.0, 1.0);
		// settle_suppression
		double suppression = tank->get(k.suppression);
		if (target > suppression) {
			suppression = MIN(target, suppression + c.SUPPRESSION_RISE_PER_SECOND * seconds);
		} else if (suppression > target) {
			suppression = MAX(target, suppression - c.SUPPRESSION_RECOVER_PER_SECOND * seconds);
		}
		if (suppression < 0.001) {
			suppression = 0.0;
		}
		tank->set(k.suppression, suppression);
		// _apply_suppression_effects
		const double sight = tank->get(k.sight_radius);
		const double hull_turn = tank->get(k.hull_turn_rate);
		double calm_sight = tank->get(k._calm_sight);
		double calm_hull_turn = tank->get(k._calm_hull_turn);
		if (sight != (double)tank->get(k._shown_sight)) {
			calm_sight = sight;
			tank->set(k._calm_sight, calm_sight);
		}
		if (hull_turn != (double)tank->get(k._shown_hull_turn)) {
			calm_hull_turn = hull_turn;
			tank->set(k._calm_hull_turn, calm_hull_turn);
		}
		const double shown_sight = calm_sight * (1.0 - c.SUPPRESSION_SIGHT_PENALTY * suppression);
		const double shown_hull_turn = calm_hull_turn * (1.0 - c.SUPPRESSION_HULL_TURN_PENALTY * suppression);
		tank->set(k.sight_radius, shown_sight);
		tank->set(k.hull_turn_rate, shown_hull_turn);
		tank->set(k._shown_sight, shown_sight);
		tank->set(k._shown_hull_turn, shown_hull_turn);
		// the stats
		samples[team] = (int64_t)samples[team] + 1;
		totals[team] = (double)totals[team] + suppression;
		if (suppression >= c.PINNED_SUPPRESSION) {  // is_pinned(): alive and suppression >= PINNED_SUPPRESSION
			pinned[team] = (int64_t)pinned[team] + 1;
		}
	}
}

} // namespace godot
