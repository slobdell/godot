#include "cover_native.h"

#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <vector>

#include <cmath>
#include <limits>

namespace godot {


void CoverNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load", "centers", "axes", "halves", "heights", "eye_height"), &CoverNative::load);
	ClassDB::bind_method(D_METHOD("clear_line", "a", "b"), &CoverNative::clear_line);
	ClassDB::bind_method(D_METHOD("clear_line_coarse", "a", "b"), &CoverNative::clear_line_coarse);
	ClassDB::bind_method(D_METHOD("segment_hits", "index", "a", "b", "grow"), &CoverNative::segment_hits);
	ClassDB::bind_method(D_METHOD("path_blocked", "a", "b", "grow"), &CoverNative::path_blocked);
	ClassDB::bind_method(D_METHOD("memo_size"), &CoverNative::memo_size);
	ClassDB::bind_method(D_METHOD("low_screen", "center", "forward", "toward", "hull"), &CoverNative::low_screen);
	ClassDB::bind_method(D_METHOD("low_features_near", "center", "radius"), &CoverNative::low_features_near);
	ClassDB::bind_static_method("CoverNative", D_METHOD("cover_roll", "projectile_id"), &CoverNative::cover_roll);
}

// cover_map.gd `_index`: each feature's grown corners (float32 math), their bounds, the cells they cover.
void CoverNative::load(const PackedVector2Array &centers, const PackedVector2Array &axes, const PackedVector2Array &halves,
		const PackedFloat64Array &heights, double p_eye_height) {
	f_center = centers;
	f_axis = axes;
	f_half = halves;
	f_height = heights;
	eye_height = p_eye_height;
	grid.clear();
	memo_fine.clear();
	memo_coarse.clear();
	const int64_t n = f_center.size();
	stamp.clear();
	stamp.resize(n);
	for (int64_t i = 0; i < n; i++) {
		stamp[i] = 0;
	}
	stamp_id = 0;
	for (int64_t index = 0; index < n; index++) {
		const Vector2 axis = f_axis[index];
		const Vector2 across(-axis.y, axis.x);
		// feature["half"] + Vector2(grow, grow): the Vector2 constructor narrows MAX_GROW, then float32 adds.
		const Vector2 half = f_half[index] + Vector2((real_t)MAX_GROW, (real_t)MAX_GROW);
		const Vector2 center = f_center[index];
		const Vector2 corners[4] = {
			center + axis * half.x + across * half.y,
			center - axis * half.x + across * half.y,
			center - axis * half.x - across * half.y,
			center + axis * half.x - across * half.y,
		};
		Vector2 low = corners[0];
		Vector2 high = corners[0];
		for (int c = 0; c < 4; c++) {
			low = low.min(corners[c]);
			high = high.max(corners[c]);
		}
		const int32_t cx0 = (int32_t)std::floor((double)low.x / CELL);
		const int32_t cx1 = (int32_t)std::floor((double)high.x / CELL);
		const int32_t cz0 = (int32_t)std::floor((double)low.y / CELL);
		const int32_t cz1 = (int32_t)std::floor((double)high.y / CELL);
		for (int32_t cx = cx0; cx <= cx1; cx++) {
			for (int32_t cz = cz0; cz <= cz1; cz++) {
				grid[Vector2i(cx, cz)].push_back((int32_t)index);
			}
		}
	}
}

// `_features_along`: Amanatides-Woo over the grid; `t_max` and `t_delta` are a Vector2 in the GDScript (float32),
// `boundary` and the divisions double before each store narrows. Returns false when there are no features.
bool CoverNative::features_along(const Vector2 &a, const Vector2 &b, LocalVector<int32_t> &found) {
	found.clear();
	if (f_center.size() == 0) {
		return false;
	}
	stamp_id += 1;
	Vector2i cell((int32_t)std::floor((double)a.x / CELL), (int32_t)std::floor((double)a.y / CELL));
	const Vector2i last((int32_t)std::floor((double)b.x / CELL), (int32_t)std::floor((double)b.y / CELL));
	const Vector2 direction = b - a;
	const Vector2i step(direction.x > 0.0f ? 1 : -1, direction.y > 0.0f ? 1 : -1);
	const real_t inf = std::numeric_limits<real_t>::infinity();
	Vector2 t_max(inf, inf);
	Vector2 t_delta(inf, inf);
	for (int k = 0; k < 2; k++) {
		if (std::fabs((double)direction[k]) > 1e-9) {
			const double boundary = (double)(cell[k] + (step[k] > 0 ? 1 : 0)) * CELL;
			t_max[k] = (real_t)((boundary - (double)a[k]) / (double)direction[k]);
			t_delta[k] = (real_t)(CELL / std::fabs((double)direction[k]));
		}
	}
	int guard = 0;
	while (true) {
		const LocalVector<int32_t> *list = grid.getptr(cell);
		if (list != nullptr) {
			for (uint32_t i = 0; i < list->size(); i++) {
				const int32_t index = (*list)[i];
				if (stamp[index] != stamp_id) {
					stamp[index] = stamp_id;
					found.push_back(index);
				}
			}
		}
		if (cell == last || guard > 64) {
			break;
		}
		guard += 1;
		if (t_max.x < t_max.y) {
			cell.x += step.x;
			t_max.x += t_delta.x;
		} else {
			cell.y += step.y;
			t_max.y += t_delta.y;
		}
	}
	return true;
}

// `segment_hits`: a slab test in the feature's frame; the dots float32, the slab scalars double.
bool CoverNative::segment_hits(int index, const Vector2 &a, const Vector2 &b, double grow) const {
	const Vector2 center = f_center[index];
	const Vector2 axis = f_axis[index];
	const Vector2 across(-axis.y, axis.x);
	const Vector2 half = f_half[index];
	const Vector2 pa = a - center;
	const Vector2 pb = b - center;
	const Vector2 la(pa.dot(axis), pa.dot(across));
	const Vector2 d = Vector2(pb.dot(axis), pb.dot(across)) - la;
	double t0 = 0.0;
	double t1 = 1.0;
	for (int k = 0; k < 2; k++) {
		const double extent = (double)half[k] + grow;
		const double dk = (double)d[k];
		const double lak = (double)la[k];
		if (std::fabs(dk) < 1e-9) {
			if (std::fabs(lak) > extent) {
				return false;
			}
			continue;
		}
		double ta = (-extent - lak) / dk;
		double tb = (extent - lak) / dk;
		if (ta > tb) {
			const double swap = ta;
			ta = tb;
			tb = swap;
		}
		t0 = t0 > ta ? t0 : ta; // maxf
		t1 = t1 < tb ? t1 : tb; // minf
		if (t0 > t1) {
			return false;
		}
	}
	return true;
}

bool CoverNative::blocked(const Vector2 &a, const Vector2 &b) {
	LocalVector<int32_t> found;
	features_along(a, b, found);
	for (uint32_t i = 0; i < found.size(); i++) {
		const int32_t index = found[i];
		if (f_height[index] >= eye_height && segment_hits(index, a, b, 0.0)) {
			return true;
		}
	}
	return false;
}

bool CoverNative::path_blocked(const Vector2 &a, const Vector2 &b, double grow) {
	LocalVector<int32_t> found;
	features_along(a, b, found);
	for (uint32_t i = 0; i < found.size(); i++) {
		if (segment_hits(found[i], a, b, grow)) {
			return true;
		}
	}
	return false;
}

// `clear_line`: roundi(a.x / QUANTUM) on each member (float32 read as double), the pair ordered, the memo keyed on
// the four ints (packed 16 bits each here; the GDScript's Vector4i), the segment rebuilt from the key.
int CoverNative::clear(const Vector3 &a, const Vector3 &b, double quantum, std::unordered_map<uint64_t, bool> &memo) {
	int32_t qax = (int32_t)std::round((double)a.x / quantum);
	int32_t qay = (int32_t)std::round((double)a.z / quantum);
	int32_t qbx = (int32_t)std::round((double)b.x / quantum);
	int32_t qby = (int32_t)std::round((double)b.z / quantum);
	if (qbx < qax || (qbx == qax && qby < qay)) {
		const int32_t sx = qax, sy = qay;
		qax = qbx;
		qay = qby;
		qbx = sx;
		qby = sy;
	}
	const Vector2 pa = Vector2((real_t)qax, (real_t)qay) * (real_t)quantum;
	const Vector2 pb = Vector2((real_t)qbx, (real_t)qby) * (real_t)quantum;
	const int32_t lim = 32767;
	if (qax < -lim || qax > lim || qay < -lim || qay > lim || qbx < -lim || qbx > lim || qby < -lim || qby > lim) {
		return (blocked(pa, pb) ? 0 : 1) | 2;
	}
	const uint64_t key = ((uint64_t)(uint16_t)qax << 48) | ((uint64_t)(uint16_t)qay << 32) | ((uint64_t)(uint16_t)qbx << 16) |
			(uint64_t)(uint16_t)qby;
	auto it = memo.find(key);
	if (it != memo.end()) {
		return it->second ? 1 : 0;
	}
	const bool clear = !blocked(pa, pb);
	if ((int)memo.size() >= MEMO_LIMIT) {
		memo.clear();
	}
	memo[key] = clear;
	return (clear ? 1 : 0) | 2;
}

int CoverNative::clear_line(const Vector3 &a, const Vector3 &b) {
	return clear(a, b, 0.5, memo_fine);
}

int CoverNative::clear_line_coarse(const Vector3 &a, const Vector3 &b) {
	return clear(a, b, 2.0, memo_coarse);
}

// ---- Round 37 (native N2): cover's K2 / K3 (game/ai/cover_map.gd low_screen / low_features_near, game/combat/armor.gd
// cover_roll). Same widths as the GDScript: Vector2 math (and a Vector2 times a float, which narrows the float first) in
// real_t; `float` locals, Vector2 members read into them, and PackedFloat64Array cells in double.

namespace {
constexpr int HULLDOWN_SLICES = 32;
constexpr double HULLDOWN_REACH_M = 3.0;

// cover_map.gd `_corners(index, 0.0)`: feature["half"] + Vector2(0, 0), then the four float32 corners.
void corners_of(const PackedVector2Array &f_center, const PackedVector2Array &f_axis, const PackedVector2Array &f_half,
		int32_t index, Vector2 out[4]) {
	const Vector2 axis = f_axis[index];
	const Vector2 across(-axis.y, axis.x);
	const Vector2 half = f_half[index] + Vector2((real_t)0.0, (real_t)0.0);
	const Vector2 center = f_center[index];
	out[0] = center + axis * half.x + across * half.y;
	out[1] = center - axis * half.x + across * half.y;
	out[2] = center - axis * half.x - across * half.y;
	out[3] = center + axis * half.x - across * half.y;
}
} // namespace

Dictionary CoverNative::low_screen(const Vector2 &center, const Vector2 &forward, const Vector2 &toward,
		const Vector3 &hull) const {
	// String keys, as the GDScript literal has them (a caller indexes screen["fraction"]).
	static const String fraction_k("fraction"), point_k("point"), far_k("far");
	Dictionary none;
	none[fraction_k] = 0.0;
	none[point_k] = center;
	none[far_k] = 0.0;
	if ((double)hull.y <= 0.0 || (double)toward.length_squared() < 1e-9) {
		return none;
	}
	// along := absf(forward.dot(toward)); aside := absf(forward.x * toward.y - forward.y * toward.x) (members as floats)
	const double along = std::fabs((double)forward.dot(toward));
	const double aside = std::fabs((double)forward.x * (double)toward.y - (double)forward.y * (double)toward.x);
	const double width = (double)hull.x * along + (double)hull.z * aside;
	const double depth = (double)hull.z * 0.5 * along + (double)hull.x * 0.5 * aside;
	if (width <= 0.0) {
		return none;
	}
	const Vector2 across(-toward.y, toward.x);
	const double reach = depth + HULLDOWN_REACH_M;
	const Vector2 side = across * (real_t)width * (real_t)0.5;
	const Vector2 out = toward * (real_t)reach;
	const Vector2 corners[4] = { center + side, center - side, center + out + side, center + out - side };
	Vector2 low = corners[0];
	Vector2 high = corners[0];
	for (int c = 0; c < 4; c++) {
		low = low.min(corners[c]);
		high = high.max(corners[c]);
	}
	std::vector<int32_t> candidates;
	const int32_t cx0 = (int32_t)std::floor((double)low.x / CELL), cx1 = (int32_t)std::floor((double)high.x / CELL);
	const int32_t cz0 = (int32_t)std::floor((double)low.y / CELL), cz1 = (int32_t)std::floor((double)high.y / CELL);
	for (int32_t cx = cx0; cx <= cx1; cx++) {
		for (int32_t cz = cz0; cz <= cz1; cz++) {
			const LocalVector<int32_t> *list = grid.getptr(Vector2i(cx, cz));
			if (list != nullptr) {
				for (uint32_t i = 0; i < list->size(); i++) {
					candidates.push_back((*list)[i]);
				}
			}
		}
	}
	std::sort(candidates.begin(), candidates.end());
	candidates.erase(std::unique(candidates.begin(), candidates.end()), candidates.end());
	double cover[HULLDOWN_SLICES];
	for (int i = 0; i < HULLDOWN_SLICES; i++) {
		cover[i] = 0.0;
	}
	double near = std::numeric_limits<double>::infinity();
	double far = 0.0;
	for (const int32_t index : candidates) {
		const double height = f_height[index];
		if (height >= eye_height || height <= 0.0) {
			continue;
		}
		double a_min = std::numeric_limits<double>::infinity(), a_max = -std::numeric_limits<double>::infinity();
		double s_min = std::numeric_limits<double>::infinity(), s_max = -std::numeric_limits<double>::infinity();
		Vector2 fc[4];
		corners_of(f_center, f_axis, f_half, index, fc);
		for (int c = 0; c < 4; c++) {
			const Vector2 offset = fc[c] - center;
			a_min = std::min(a_min, (double)offset.dot(toward));
			a_max = std::max(a_max, (double)offset.dot(toward));
			s_min = std::min(s_min, (double)offset.dot(across));
			s_max = std::max(s_max, (double)offset.dot(across));
		}
		if (a_max < depth || a_min > reach) {
			continue;
		}
		const double hides = std::min(1.0, height / (double)hull.y);
		bool used = false;
		for (int slice = 0; slice < HULLDOWN_SLICES; slice++) {
			const double s = -width * 0.5 + width * ((double)slice + 0.5) / (double)HULLDOWN_SLICES;
			if (s >= s_min && s <= s_max && hides > cover[slice]) {
				cover[slice] = hides;
				used = true;
			}
		}
		if (used) {
			near = std::min(near, std::max(a_min, depth));
			far = std::max(far, a_max);
		}
	}
	double total = 0.0;
	for (int slice = 0; slice < HULLDOWN_SLICES; slice++) {
		total += cover[slice];
	}
	if (total <= 0.0) {
		return none;
	}
	Dictionary result;
	result[fraction_k] = total / (double)HULLDOWN_SLICES;
	result[point_k] = center + toward * (real_t)near;
	result[far_k] = far;
	return result;
}

PackedInt32Array CoverNative::low_features_near(const Vector2 &center, double radius) const {
	std::vector<int32_t> seen;
	const int32_t cx0 = (int32_t)std::floor(((double)center.x - radius) / CELL);
	const int32_t cx1 = (int32_t)std::floor(((double)center.x + radius) / CELL);
	const int32_t cz0 = (int32_t)std::floor(((double)center.y - radius) / CELL);
	const int32_t cz1 = (int32_t)std::floor(((double)center.y + radius) / CELL);
	for (int32_t cx = cx0; cx <= cx1; cx++) {
		for (int32_t cz = cz0; cz <= cz1; cz++) {
			const LocalVector<int32_t> *list = grid.getptr(Vector2i(cx, cz));
			if (list == nullptr) {
				continue;
			}
			for (uint32_t i = 0; i < list->size(); i++) {
				const int32_t index = (*list)[i];
				if (f_height[index] < eye_height && f_height[index] > 0.0) {
					seen.push_back(index);
				}
			}
		}
	}
	std::sort(seen.begin(), seen.end());
	seen.erase(std::unique(seen.begin(), seen.end()), seen.end());
	PackedInt32Array found;
	Geometry2D *geometry = Geometry2D::get_singleton();
	for (const int32_t index : seen) {
		Vector2 fc[4];
		corners_of(f_center, f_axis, f_half, index, fc);
		for (int k = 0; k < 4; k++) {
			// Geometry2D.get_closest_point_to_segment, the engine's own (the GDScript calls the same singleton).
			const Vector2 closest = geometry->get_closest_point_to_segment(center, fc[k], fc[(k + 1) % 4]);
			if ((double)closest.distance_to(center) <= radius) {
				found.push_back(index);
				break;
			}
		}
	}
	return found;
}

// Armor.cover_roll: GDScript ints are int64 with wrap-around; the multiply is done unsigned for the same bits.
double CoverNative::cover_roll(int64_t projectile_id) {
	const uint64_t mask = 0xFFFFFFFFull;
	uint64_t x = ((uint64_t)projectile_id * 2654435761ull + 0x9E3779B9ull) & mask;
	x = (((x >> 16) ^ x) * 0x45D9F3Bull) & mask;
	x = (((x >> 16) ^ x) * 0x45D9F3Bull) & mask;
	x = (x >> 16) ^ x;
	return (double)(x & 0xFFFFFFull) / 16777216.0;
}

} // namespace godot
