// Round 47 (native N2): TacticsFormation.place natively (place_native.h). Each function below names the GDScript it mirrors;
// a GDScript `float` is a double here and a Vector component a real_t, rounded where the GDScript rounds (a Vector2(...) built
// from doubles narrows each argument; Vector * float narrows the scalar).
#include "place_native.h"

#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace godot {

namespace {

const double INF_D = std::numeric_limits<double>::infinity();
const double TAU_D = 6.283185307179586476925286766559;
const double PI_D = 3.1415926535897932384626433833;
const double CMP_EPS = 0.00001;

// TacticsFormation's constants (tests/test_native_place.gd compares the answers, so a changed constant there reads as mismatches)
const double DEFAULT_SPACING = 12.0;
const double DIAGONAL_SIDE = 0.9;
const double HERRINGBONE_SIDE = 0.55;
const double HERRINGBONE_FACING = 90.0;
const double SWARM_SPREAD = 1.9;
const double SWARM_STAGGER = 0.8;
const double RING_RADIUS = 2.4;
const double HULL_CLEAR_M = 2.0;
const double DRESS_MARGIN_M = 0.30;
const double SEAT_ORDER_PER_RANK = 3.0;
const double SEAT_LAST_REAR_TIE_M = 4.0;
const double SEAT_BOUND_HULLS = 1.5;
const double SEAT_BOUND_MIN_M = 18.0;
const int ROW_WIDTH = 5;
const int LINE_WIDTH = 8;
const int PLATOON = 5;
const double FRONT_EXPOSURE = 1.5;
const double TIER_TOLERANCE = 0.5;
const double TIER_COST = 100000.0;
const double TRAVEL_ORDER_TIE = 1.0e-4;
const double STABLE_MARGIN = 0.5;
const double PINNED = 1.0e9;
const double SHORT_SWAP_M = 8.0;
const double PAST_M = 6.0;
const double PAST_COST = 1.0e7;

const char *NAMES[] = { "column", "wedge", "vee", "line", "echelon_left", "echelon_right", "herringbone", "coil", "swarm", "ring" };

struct Flags {
	bool seat_bound = false;
	bool seat_order = false;
	bool seat_last_open = false;
	bool travel_sum_first = true;
	bool short_swap = false;
	bool squared_along_route = true;
	bool nearest = true;
	String lateral_floor = "dressing";
};

typedef std::vector<Vector2> Shape;

double maxf(double a, double b) { return a > b ? a : b; } // Math::max (GDScript maxf): a NaN compares false either way
double minf(double a, double b) { return a < b ? a : b; }

bool is_equal_approx(double a, double b) { // Math::is_equal_approx(double, double)
	if (a == b) {
		return true;
	}
	double tolerance = CMP_EPS * std::abs(a);
	if (tolerance < CMP_EPS) {
		tolerance = CMP_EPS;
	}
	return std::abs(a - b) < tolerance;
}

bool is_name(const String &formation) {
	for (const char *n : NAMES) {
		if (formation == n) {
			return true;
		}
	}
	return false;
}

// flat(direction)
Vector3 flat(const Vector3 &direction) {
	const Vector3 forward(direction.x, 0.0f, direction.z);
	return (double)forward.length_squared() < 1e-6 ? Vector3(0, 0, -1) : forward.normalized();
}

// rotate(heading, radians)
Vector3 rotate(const Vector3 &heading, double radians) {
	const Vector3 forward = flat(heading);
	return (forward * (real_t)std::cos(radians) + Vector3(-forward.z, 0.0f, forward.x) * (real_t)std::sin(radians)).normalized();
}

// to_world(anchor, heading, slot)
Vector3 to_world(const Vector3 &anchor, const Vector3 &heading, const Vector2 &slot) {
	const Vector3 forward = flat(heading);
	const Vector3 right(-forward.z, 0.0f, forward.x);
	return Vector3(anchor.x, 0.0f, anchor.z) + right * slot.x - forward * slot.y;
}

// turning_pitch(extent, rule)
double turning_pitch(const Vector2 &extent, const String &rule) {
	const double half_diagonal = 0.5 * (double)extent.length();
	if (rule == "one_turning") {
		return half_diagonal + 0.5 * (double)extent.x;
	}
	if (rule == "both_turning") {
		return 2.0 * half_diagonal;
	}
	if (rule == "dressing") {
		return 2.0 * half_diagonal + DRESS_MARGIN_M;
	}
	return 0.0;
}

// hull_floor(members, rule) from hull_extent(members)
Vector2 hull_floor(const Vector2 &extent, const String &rule, const Flags &f) {
	if (extent == Vector2()) {
		return Vector2();
	}
	const Vector2 floor_v = extent + Vector2((real_t)HULL_CLEAR_M, (real_t)HULL_CLEAR_M);
	return Vector2((real_t)maxf(floor_v.x, turning_pitch(extent, rule != "" ? rule : f.lateral_floor)), floor_v.y);
}

// pitch(members, spacing, rule)
Vector2 pitch_of(const Vector2 &extent, double spacing, const String &rule, const Flags &f) {
	const double s = maxf(spacing, 1.0);
	const Vector2 floor_v = hull_floor(extent, rule, f);
	return Vector2((real_t)maxf(s, floor_v.x), (real_t)maxf(s, floor_v.y));
}

// seat_bound(members)
double seat_bound(const Vector2 &extent, const Flags &f) {
	if (extent == Vector2()) {
		return INF_D;
	}
	return maxf(SEAT_BOUND_MIN_M, SEAT_BOUND_HULLS * (double)extent.y + (double)hull_floor(extent, "", f).y);
}

// rows(count, width, spacing)
Shape rows(int count, int width, double spacing) {
	Shape result;
	if (count <= 0) {
		return result;
	}
	if (width <= 0) {
		width = count <= ROW_WIDTH * 2 ? std::min(ROW_WIDTH, count) : (int)std::ceil(std::sqrt(count * 2.0));
	}
	for (int i = 0; i < count; i++) {
		const int row = i / width;
		const int in_row = std::min(width, count - row * width);
		const int column = i - row * width;
		result.push_back(Vector2((real_t)(((double)column - (double)(in_row - 1) * 0.5) * spacing), (real_t)((double)row * spacing)));
	}
	return result;
}

// offset(formation, i, count, spacing)
Vector2 offset(const String &formation, int i, int count, double spacing) {
	const double s = maxf(spacing, 1.0);
	const double side = i % 2 == 1 ? -1.0 : 1.0;
	const double rank = (double)((i + 1) / 2);
	if (formation == "column") {
		return Vector2(0.0f, (real_t)((double)i * s));
	}
	if (formation == "wedge") {
		return i == 0 ? Vector2() : Vector2((real_t)(side * rank * s * DIAGONAL_SIDE), (real_t)(rank * s));
	}
	if (formation == "vee") {
		return i == 0 ? Vector2() : Vector2((real_t)(side * rank * s * DIAGONAL_SIDE), (real_t)(-rank * s));
	}
	if (formation == "line") {
		return i == 0 ? Vector2() : Vector2((real_t)(side * rank * s), 0.0f);
	}
	if (formation == "echelon_right") {
		return Vector2((real_t)((double)i * s * DIAGONAL_SIDE), (real_t)((double)i * s));
	}
	if (formation == "echelon_left") {
		return Vector2((real_t)(-(double)i * s * DIAGONAL_SIDE), (real_t)((double)i * s));
	}
	if (formation == "herringbone") {
		return Vector2((real_t)(side * s * HERRINGBONE_SIDE), (real_t)((double)i * s * 0.8));
	}
	if (formation == "coil") {
		const double angle = TAU_D * (double)i / (double)std::max(count, 1);
		const double radius = s * (count <= 3 ? 0.7 : 0.9) * std::sqrt(maxf((double)count, 1.0) / 4.0);
		return Vector2((real_t)(std::sin(angle) * radius), (real_t)(-std::cos(angle) * radius));
	}
	if (formation == "swarm") {
		const double rank_out = (double)((i + 1) / 2);
		const double stagger = (double)((i * 7) % 5) - 2.0;
		return Vector2((real_t)(side * rank_out * s * SWARM_SPREAD), (real_t)(stagger * s * SWARM_STAGGER));
	}
	if (formation == "ring") {
		const double step = TAU_D * (double)i / (double)std::max(count, 1);
		return Vector2((real_t)(std::sin(step) * s * RING_RADIUS), (real_t)(-std::cos(step) * s * RING_RADIUS));
	}
	return Vector2();
}

// offsets(formation, count, spacing)
Shape offsets(const String &formation, int count, double spacing) {
	if (formation == "rows") {
		return rows(count, 0, spacing);
	}
	Shape result;
	for (int i = 0; i < std::max(count, 0); i++) {
		result.push_back(offset(formation, i, count, spacing));
	}
	return result;
}

// group_offsets(formation, count, spacing)
Shape group_offsets(const String &formation, int count, double spacing) {
	if (formation == "single" || count <= 1) {
		return Shape(1, Vector2());
	}
	if (formation == "line" && count > LINE_WIDTH) {
		return rows(count, LINE_WIDTH, spacing);
	}
	if (formation == "block") {
		return rows(count, (int)std::ceil(std::sqrt((double)count)), spacing);
	}
	return offsets(formation, count, spacing);
}

// offsets_at(formation, count, pitch_v)
Shape offsets_at(const String &formation, int count, const Vector2 &pitch_v) {
	Shape raw = group_offsets(formation, count, pitch_v.y);
	if (pitch_v.y <= 0.0f || is_equal_approx(pitch_v.x, pitch_v.y)) {
		return raw;
	}
	const double ratio = (double)pitch_v.x / (double)pitch_v.y;
	Shape result;
	for (const Vector2 &slot : raw) {
		result.push_back(Vector2((real_t)((double)slot.x * ratio), slot.y));
	}
	return result;
}

// offsets_deformed(formation, count, fit) with fit_to_corridor's open answer (file 0; DEFORM_ENABLED is the seam's)
Shape offsets_deformed(const String &formation, int count, const Vector2 &pitch_v, double shear) {
	if (std::abs(shear) < CMP_EPS) {
		return offsets_at(formation, count, pitch_v);
	}
	Shape result;
	for (const Vector2 &slot : group_offsets(formation, count, 1.0)) {
		result.push_back(Vector2((real_t)((double)slot.x * (double)pitch_v.x + (double)slot.y * shear),
				(real_t)((double)slot.y * (double)pitch_v.y)));
	}
	return result;
}

// centered(raw)
Shape centered(const Shape &raw) {
	if (raw.empty()) {
		return raw;
	}
	Vector2 middle;
	for (const Vector2 &slot : raw) {
		middle += slot;
	}
	middle /= (real_t)(double)raw.size();
	Shape result;
	for (const Vector2 &slot : raw) {
		result.push_back(slot - middle);
	}
	return result;
}

// reach_of(shape)
double reach_of(const Shape &shape) {
	double reach = 0.0;
	for (const Vector2 &slot : shape) {
		reach = maxf(reach, slot.length());
	}
	return reach;
}

// bounded(shape, bound, floor_v)
Shape bounded(const Shape &shape, double bound, const Vector2 &floor_v, const Flags &f) {
	const double reach = reach_of(shape);
	if (!std::isfinite(bound) || reach <= bound || reach <= 0.0) {
		return shape;
	}
	double scale = bound / reach;
	double least = 0.0;
	for (size_t i = 0; i < shape.size(); i++) {
		for (size_t j = i + 1; j < shape.size(); j++) {
			const Vector2 apart = (shape[i] - shape[j]).abs();
			const double across = apart.x > 0.001 ? (double)floor_v.x / (double)apart.x : INF_D;
			const double along = apart.y > 0.001 ? (double)floor_v.y / (double)apart.y : INF_D;
			least = maxf(least, minf(across, along));
		}
	}
	scale = maxf(scale, minf(least, 1.0));
	if (scale >= 1.0) {
		return shape;
	}
	Shape result;
	for (const Vector2 &slot : shape) {
		result.push_back(slot * (real_t)scale);
	}
	if (f.seat_last_open && shape.size() >= 3) {
		size_t deepest = 0;
		for (size_t i = 0; i < shape.size(); i++) {
			if (shape[i].y > shape[deepest].y) {
				deepest = i;
			}
		}
		if (shape[deepest].y > 0.0f) {
			result[deepest] = Vector2((real_t)((double)shape[deepest].x * scale), shape[deepest].y);
		}
	}
	return result;
}

// sectors(formation, count)
std::vector<double> sectors(const String &formation, int count) {
	std::vector<double> result;
	if (count <= 0) {
		return result;
	}
	for (int i = 0; i < count; i++) {
		double v = 0.0;
		if (formation == "column" || formation == "herringbone") {
			const double flank = formation == "column" ? 90.0 : HERRINGBONE_FACING;
			if (i == 0) {
				v = 0.0;
			} else if (i == count - 1 && count > 2) {
				v = 180.0;
			} else {
				v = i % 2 == 0 ? flank : -flank;
			}
		} else if (formation == "wedge" || formation == "vee") {
			if (i != 0) {
				const double side = i % 2 == 1 ? -1.0 : 1.0;
				const double rank = (double)((i + 1) / 2);
				v = side * minf(45.0 + 45.0 * (rank - 1.0), 135.0);
			}
		} else if (formation == "line") {
			v = count <= 1 ? 0.0 : ((double)i / (double)(count - 1) - 0.5) * 60.0;
		} else if (formation == "echelon_right") {
			v = i == 0 ? 0.0 : minf(45.0 + 45.0 * (double)(i - 1), 135.0);
		} else if (formation == "echelon_left") {
			v = i == 0 ? 0.0 : -minf(45.0 + 45.0 * (double)(i - 1), 135.0);
		} else if (formation == "coil" || formation == "ring") {
			const double a = TAU_D * (double)i / (double)count;
			v = a * (180.0 / PI_D) - (a > PI_D ? 360.0 : 0.0);
		} else if (formation == "swarm") {
			v = count <= 1 ? 0.0 : ((double)i / (double)(count - 1) - 0.5) * 120.0;
		}
		result.push_back(v);
	}
	return result;
}

// _strict_rank(values): ascending, ties (within 1e-9) by index
std::vector<int> strict_rank(const std::vector<double> &values) {
	std::vector<int> order(values.size());
	for (size_t k = 0; k < order.size(); k++) {
		order[k] = (int)k;
	}
	std::sort(order.begin(), order.end(), [&](int a, int b) {
		if (std::abs(values[a] - values[b]) > 1e-9) {
			return values[a] < values[b];
		}
		return a < b;
	});
	std::vector<int> ranks(values.size());
	for (size_t k = 0; k < order.size(); k++) {
		ranks[order[k]] = (int)k;
	}
	return ranks;
}

// _dense_rank(values, descending)
std::vector<int> dense_rank(const std::vector<double> &values, bool descending) {
	std::vector<int> order(values.size());
	for (size_t k = 0; k < order.size(); k++) {
		order[k] = (int)k;
	}
	std::sort(order.begin(), order.end(), [&](int a, int b) {
		const double va = values[a], vb = values[b];
		if (std::abs(va - vb) > 1e-9) {
			return descending ? va > vb : va < vb;
		}
		return a < b;
	});
	std::vector<int> tiers(values.size());
	int tier = 0;
	double last = 0.0;
	for (size_t k = 0; k < order.size(); k++) {
		const double value = values[order[k]];
		if (k > 0 && std::abs(value - last) > TIER_TOLERANCE) {
			tier += 1;
			last = value;
		} else if (k == 0) {
			last = value;
		}
		tiers[order[k]] = tier;
	}
	return tiers;
}

// _hungarian(cost): row -> column
std::vector<int> hungarian(const std::vector<std::vector<double>> &cost) {
	const int n = (int)cost.size();
	std::vector<double> u(n + 1, 0.0), v(n + 1, 0.0);
	std::vector<int> p(n + 1, 0), way(n + 1, 0);
	for (int i = 1; i <= n; i++) {
		p[0] = i;
		int j0 = 0;
		std::vector<double> minv(n + 1, INF_D);
		std::vector<char> used(n + 1, 0);
		while (true) {
			used[j0] = 1;
			const int i0 = p[j0];
			double delta = INF_D;
			int j1 = 0;
			const std::vector<double> &row = cost[i0 - 1];
			for (int j = 1; j <= n; j++) {
				if (used[j] == 0) {
					const double cur = row[j - 1] - u[i0] - v[j];
					if (cur < minv[j]) {
						minv[j] = cur;
						way[j] = j0;
					}
					if (minv[j] < delta) {
						delta = minv[j];
						j1 = j;
					}
				}
			}
			for (int j = 0; j <= n; j++) {
				if (used[j] == 1) {
					u[p[j]] += delta;
					v[j] -= delta;
				} else {
					minv[j] -= delta;
				}
			}
			j0 = j1;
			if (p[j0] == 0) {
				break;
			}
		}
		while (true) {
			const int j1 = way[j0];
			p[j0] = p[j1];
			j0 = j1;
			if (j0 == 0) {
				break;
			}
		}
	}
	std::vector<int> result(n, 0);
	for (int j = 1; j <= n; j++) {
		if (p[j] > 0) {
			result[p[j] - 1] = j - 1;
		}
	}
	return result;
}

// _valid_seating(previous, members, slot_count)
bool valid_seating(const Dictionary &previous, const std::vector<String> &names, int slot_count) {
	if (previous.size() < (int64_t)names.size()) {
		return false;
	}
	std::vector<char> taken(std::max(slot_count, 0), 0);
	for (const String &name : names) {
		const int index = (int)previous.get(name, -1);
		if (index < 0 || index >= slot_count || taken[index]) {
			return false;
		}
		taken[index] = 1;
	}
	return true;
}

// _passes_set_up(from, seat, set_up_at)
bool passes_set_up(const Vector3 &from, const Vector3 &seat, const Array &set_up_at) {
	const Vector2 a(from.x, from.z);
	const Vector2 b(seat.x, seat.z);
	const Vector2 ab = b - a;
	const double length_sq = ab.length_squared();
	if (length_sq < 1e-6) {
		return false;
	}
	for (int64_t k = 0; k < set_up_at.size(); k++) {
		const Vector3 point = set_up_at[k];
		const Vector2 p(point.x, point.z);
		if ((double)p.distance_to(b) <= PAST_M || (double)p.distance_to(a) <= 0.5) {
			continue;
		}
		const double t = std::clamp((double)(p - a).dot(ab) / length_sq, 0.0, 1.0);
		if (t > 0.0 && t < 1.0 && (double)p.distance_to(a + ab * (real_t)t) < PAST_M) {
			return true;
		}
	}
	return false;
}

// Vector2(a.x - b.x, a.z - b.z).length(): the differences in doubles, narrowed to the Vector2
double flat_gap(const Vector3 &a, const Vector3 &b) {
	return Vector2((real_t)((double)a.x - (double)b.x), (real_t)((double)a.z - (double)b.z)).length();
}

// Vector3(at.x - anchor.x, 0.0, at.z - anchor.z).dot(axis)
double flat_dot(const Vector3 &at, const Vector3 &anchor, const Vector3 &axis) {
	return Vector3((real_t)((double)at.x - (double)anchor.x), 0.0f, (real_t)((double)at.z - (double)anchor.z)).dot(axis);
}

// seat(members, offsets, anchor, heading, opts) -> {name: slot index}, here one index per member (members' order)
std::vector<int> seat(const Array &members, const std::vector<String> &names, const Shape &offs, const Vector3 &anchor,
		const Vector3 &heading, const Dictionary &opts, const PackedFloat64Array &tough, const Flags &f) {
	const int count = (int)members.size();
	if (count == 0 || offs.empty()) {
		return std::vector<int>();
	}
	const int n_offs = (int)offs.size();
	const int slot_count = std::max(n_offs, count);
	const String policy = opts.get("policy", "front");
	const String leader = opts.get("leader", "");
	const double spacing = opts.get("spacing", DEFAULT_SPACING);
	std::vector<double> tough_v(count);
	for (int i = 0; i < count; i++) {
		tough_v[i] = tough[i];
	}
	const std::vector<int> member_tier = dense_rank(tough_v, true);
	std::vector<double> exposure;
	for (const Vector2 &slot : offs) {
		exposure.push_back(policy == "exposure" ? (double)slot.length() + FRONT_EXPOSURE * maxf(-(double)slot.y, 0.0) : -(double)slot.y);
	}
	const std::vector<int> slot_tier = dense_rank(exposure, true);
	int deepest = 0;
	for (int tier : slot_tier) {
		deepest = std::max(deepest, tier);
	}
	std::vector<Dictionary> m(count);
	bool driving = false;
	for (int i = 0; i < count; i++) {
		m[i] = members[i];
		driving = driving || m[i].has("position");
	}
	driving = driving && !(bool)opts.get("layout", false);
	const bool nearest = f.nearest && driving;
	const bool halted = opts.has("halted") ? (bool)opts["halted"] : (bool)opts.get("halt", false);
	double tier_weight = TIER_COST;
	if (f.short_swap && nearest && !halted) {
		int deepest_member = 0;
		for (int tier : member_tier) {
			deepest_member = std::max(deepest_member, tier);
		}
		tier_weight = SHORT_SWAP_M / (double)std::max(deepest_member * deepest, 1);
	}
	bool pin = false;
	for (int i = 0; i < count; i++) {
		pin = pin || (leader != "" && String(m[i].get("name", "")) == leader);
	}
	const Dictionary keep = opts.get("keep", Dictionary());
	const Array set_up_at = opts.get("set_up_at", Array());
	const Array via = nearest && !halted ? (Array)opts.get("via", Array()) : Array();
	const bool along_route = nearest && !halted && f.squared_along_route && opts.has("at");
	const Array placed_at = opts.get("at", Array());
	std::vector<Vector3> world;
	for (int j = 0; j < n_offs; j++) {
		if (j < placed_at.size() && placed_at[j].get_type() == Variant::VECTOR3) {
			world.push_back(placed_at[j]);
		} else {
			world.push_back(to_world(anchor, heading, offs[j]));
		}
	}
	const bool seat_bound_opt = opts.has("seat_bound") ? (bool)opts["seat_bound"] : !halted;
	bool last_open = f.seat_last_open && f.seat_bound && nearest && !halted && seat_bound_opt && n_offs >= 3 && count >= 3;
	int deep_slot = -1;
	int rear_member = -1;
	if (last_open) {
		const Vector3 fwd_l = flat(heading);
		for (int j = 0; j < n_offs; j++) {
			if (deep_slot < 0 || offs[j].y > offs[deep_slot].y) {
				deep_slot = j;
			}
		}
		double least_ahead = INF_D;
		std::vector<double> aheads;
		for (int i = 0; i < count; i++) {
			if (!m[i].has("position")) {
				aheads.push_back(INF_D);
				continue;
			}
			const double ahead = flat_dot(m[i]["position"], anchor, fwd_l);
			aheads.push_back(ahead);
			least_ahead = minf(least_ahead, ahead);
		}
		const Vector3 right_l(-fwd_l.z, 0.0f, fwd_l.x);
		const double deep_lateral = flat_dot(world[deep_slot], anchor, right_l);
		double nearest_side = INF_D;
		for (int i = 0; i < count; i++) {
			if (aheads[i] > least_ahead + SEAT_LAST_REAR_TIE_M) {
				continue;
			}
			const double side = std::abs(flat_dot(m[i]["position"], anchor, right_l) - deep_lateral);
			if (side < nearest_side) {
				nearest_side = side;
				rear_member = i;
			}
		}
		const Dictionary held = opts.get("previous", Dictionary());
		if (valid_seating(held, names, n_offs)) {
			for (int i = 0; i < count; i++) {
				if ((int)held[names[i]] == deep_slot && m[i].has("position")) {
					rear_member = i;
				}
			}
		}
		if (offs[deep_slot].y <= 0.0f || rear_member < 0) {
			last_open = false;
		}
	}
	const bool ordered = f.seat_order && nearest && !halted && (bool)opts.get("seat_order", false);
	std::vector<int> member_rank, slot_rank;
	if (ordered) {
		const Vector3 fwd = flat(heading);
		const Vector3 right(-fwd.z, 0.0f, fwd.x);
		std::vector<double> laterals;
		for (int i = 0; i < count; i++) {
			const Vector3 at = m[i].get("position", anchor);
			laterals.push_back(last_open && i == rear_member ? INF_D : flat_dot(at, anchor, right));
		}
		member_rank = strict_rank(laterals);
		std::vector<double> slot_laterals;
		for (int j = 0; j < n_offs; j++) {
			if (last_open) {
				slot_laterals.push_back(j == deep_slot ? INF_D : (double)offs[j].x);
			} else {
				slot_laterals.push_back(flat_dot(world[j], anchor, right));
			}
		}
		slot_rank = strict_rank(slot_laterals);
	}
	std::vector<std::vector<double>> cost(slot_count, std::vector<double>(slot_count, 0.0));
	for (int i = 0; i < slot_count; i++) {
		std::vector<double> &row = cost[i];
		for (int j = 0; j < slot_count; j++) {
			if (i >= count || j >= n_offs) {
				row[j] = i >= count ? 0.0 : PINNED;
				continue;
			}
			const Dictionary &member = m[i];
			double value = 0.0;
			const bool has_position = member.has("position");
			if (has_position) {
				const Vector3 at = member["position"];
				value = flat_gap(at, world[j]);
				if (via.size() == 2) {
					const Vector3 entry = via[0];
					const Vector3 exit = via[1];
					value = flat_gap(at, entry) + flat_gap(exit, world[j]);
					value = value * value / maxf(spacing, 1.0);
				} else if (along_route) {
					value = value * value / maxf(spacing, 1.0);
				} else if (policy == "travel") {
					const double squared = value * value / maxf(spacing, 1.0);
					value = f.travel_sum_first ? value + TRAVEL_ORDER_TIE * squared : squared;
				}
			}
			if (policy != "travel") {
				value += tier_weight * (double)member_tier[i] * (double)(deepest - slot_tier[j]);
			}
			if (ordered) {
				value += SEAT_ORDER_PER_RANK * maxf(spacing, 1.0) * (double)std::abs(member_rank[i] - slot_rank[j]);
			}
			if (last_open && ((j == deep_slot) != (i == rear_member))) {
				value += SEAT_ORDER_PER_RANK * maxf(spacing, 1.0) * 3.0;
			}
			const String name = member.get("name", "");
			if (pin) {
				const bool is_leader = name == leader;
				if (is_leader != (j == 0)) {
					value += PINNED;
				}
			}
			if (!set_up_at.is_empty() && has_position && !keep.has(name) && passes_set_up(member["position"], world[j], set_up_at)) {
				value += PAST_COST;
			}
			if (keep.has(name) && (int)keep[name] != j) {
				value += PINNED;
			}
			row[j] = value;
		}
	}
	const std::vector<int> best = hungarian(cost);
	std::vector<int> chosen(count);
	double best_cost = 0.0;
	for (int i = 0; i < count; i++) {
		chosen[i] = best[i];
		best_cost += cost[i][best[i]];
	}
	const Dictionary previous = opts.get("previous", Dictionary());
	if (valid_seating(previous, names, n_offs)) {
		double previous_cost = 0.0;
		for (int i = 0; i < count; i++) {
			previous_cost += cost[i][(int)previous[names[i]]];
		}
		if ((bool)opts.get("fixed", false) || previous_cost <= best_cost + STABLE_MARGIN * spacing) {
			std::vector<int> kept(count);
			for (int i = 0; i < count; i++) {
				kept[i] = (int)previous[names[i]];
			}
			return kept;
		}
	}
	return chosen;
}

} // namespace

Array formation_place(const Array &members, const String &formation, const Vector3 &anchor, const Vector3 &heading, double spacing,
		const Dictionary &opts, const Vector2 &extent, const PackedFloat64Array &tough, const PackedStringArray &roles,
		const PackedInt32Array &flag_bits, const String &lateral_floor) {
	Array result;
	if (members.is_empty()) {
		return result;
	}
	Flags f;
	f.seat_bound = flag_bits[0] != 0;
	f.seat_order = flag_bits[1] != 0;
	f.seat_last_open = flag_bits[2] != 0;
	f.travel_sum_first = flag_bits[3] != 0;
	f.short_swap = flag_bits[4] != 0;
	f.squared_along_route = flag_bits[5] != 0;
	f.nearest = flag_bits[6] != 0;
	f.lateral_floor = lateral_floor;
	const int n = (int)members.size();
	std::vector<String> names(n);
	for (int i = 0; i < n; i++) {
		names[i] = String(((Dictionary)members[i])["name"]);
	}
	const int count = std::max((int)opts.get("count", -1), n);
	const String floor_rule = opts.get("floor_rule", "");
	const Vector2 pitch_v = pitch_of(extent, spacing, floor_rule, f);
	const double shear = opts.get("shear", 0.0);
	const Shape raw = offsets_deformed(formation, count, pitch_v, shear);
	const bool is_centered = opts.get("centered", true);
	Shape shape = is_centered ? centered(raw) : raw;
	const bool halt = opts.get("halt", false);
	const bool seat_bound_opt = opts.has("seat_bound") ? (bool)opts["seat_bound"] : !halt;
	if (f.seat_bound && count <= PLATOON && is_centered && seat_bound_opt) {
		shape = bounded(shape, seat_bound(extent, f), hull_floor(extent, floor_rule, f), f);
	}
	const std::vector<double> sector_list = sectors(is_name(formation) ? formation : String("line"), count);
	Dictionary seat_opts = opts.duplicate();
	seat_opts["spacing"] = maxf(pitch_v.x, pitch_v.y);
	const std::vector<int> seats = seat(members, names, shape, anchor, heading, seat_opts, tough, f);
	const Vector3 forward = flat(heading);
	// by_index: {index: member} (a later member on the same index replaces an earlier one), then the indices ascending
	std::vector<int> by_index(std::max((int)shape.size(), count) + 1, -1);
	for (int i = 0; i < n; i++) {
		const int index = seats[i];
		if (index >= (int)by_index.size()) {
			by_index.resize(index + 1, -1);
		}
		by_index[index] = i;
	}
	for (int index = 0; index < (int)by_index.size(); index++) {
		const int i = by_index[index];
		if (i < 0) {
			continue;
		}
		const double sector = index < (int)sector_list.size() ? sector_list[index] : 0.0;
		const Vector3 facing = halt ? rotate(forward, sector * (PI_D / 180.0)) : forward;
		Dictionary entry;
		entry["unit"] = names[i];
		entry["to"] = to_world(anchor, forward, shape[index]);
		entry["facing"] = facing;
		entry["role"] = roles[i];
		entry["index"] = index;
		entry["offset"] = shape[index];
		entry["sector"] = sector;
		entry["pitch"] = pitch_v;
		entry["file"] = 0.0;
		entry["fits"] = true;
		result.push_back(entry);
	}
	return result;
}

} // namespace godot
