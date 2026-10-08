#include "cover_native.h"

#include <godot_cpp/core/class_db.hpp>

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

} // namespace godot
