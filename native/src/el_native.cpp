#include "el_native.h"

#include "nav_native.h"

#include <godot_cpp/core/math.hpp>

#include <godot_cpp/variant/vector2.hpp>

#include <cmath>

namespace godot {

namespace {

inline bool inside(const float *b, const Vector3 &p) {
	return (double)p.x > (double)b[0] && (double)p.x < (double)b[2] && (double)p.z > (double)b[1] && (double)p.z < (double)b[3];
}

// maxi(1, ceili(Vector2(to.x - from.x, to.z - from.z).length() / step))
inline int64_t steps_of(double length, double step) {
	const int64_t n = (int64_t)std::ceil(length / step);
	return n > 1 ? n : 1;
}

inline double flat_length(const Vector3 &from, const Vector3 &to) {
	return (double)Vector2((real_t)((double)to.x - (double)from.x), (real_t)((double)to.z - (double)from.z)).length();
}

} // namespace

// SlotGround.wet
bool ElTerrain::wet(const Vector3 &point) const {
	for (const Box &entry : boxes) {
		if (!entry.carves) {
			continue;
		}
		if (inside(entry.b, point)) {
			for (const Box &deck : boxes) {
				if (deck.deck && inside(deck.b, point)) {
					return false;
				}
			}
			return true;
		}
	}
	return false;
}

// SlotGround.over_water
bool ElTerrain::over_water(const Vector3 &point) const {
	for (const Box &entry : boxes) {
		const double grow = entry.deck ? MOUTH_CLEAR_M : 0.0;
		if (!entry.carves && grow == 0.0) {
			continue;
		}
		if ((double)point.x > (double)entry.b[0] - grow && (double)point.x < (double)entry.b[2] + grow &&
				(double)point.z > (double)entry.b[1] - grow && (double)point.z < (double)entry.b[3] + grow) {
			return true;
		}
	}
	return false;
}

// SlotGround.leg_wet (with terrain)
bool ElTerrain::leg_wet(const Vector3 &from, const Vector3 &to) const {
	const int64_t steps = steps_of(flat_length(from, to), WET_STEP_M);
	for (int64_t i = 1; i < steps + 1; i++) {
		if (wet(from.lerp(to, (real_t)((double)i / (double)steps)))) {
			return true;
		}
	}
	return false;
}

// SlotGround.dry_leg_end (with terrain)
Vector3 ElTerrain::dry_leg_end(const Vector3 &from, const Vector3 &to, double margin, bool strict) const {
	const double length = flat_length(from, to);
	const int64_t steps = steps_of(length, WET_STEP_M);
	for (int64_t i = 1; i < steps + 1; i++) {
		const Vector3 probe = from.lerp(to, (real_t)((double)i / (double)steps));
		if (strict ? over_water(probe) : wet(probe)) {
			const double dry = length * (double)(i - 1) / (double)steps - margin;
			return dry <= 0.0 ? from : from.lerp(to, (real_t)(dry / length));
		}
	}
	return to;
}

// SlotGround.pulled_dry (WET_ENABLED on)
Vector3 ElTerrain::pulled_dry(const Vector3 &point, const Vector3 &toward) const {
	if (!over_water(point) || over_water(toward)) {
		return point;
	}
	const double length = flat_length(point, toward);
	const int64_t steps = steps_of(length, WET_STEP_M);
	for (int64_t i = 1; i < steps + 1; i++) {
		if (!over_water(point.lerp(toward, (real_t)((double)i / (double)steps)))) {
			const double at = length * (double)i / (double)steps + DRY_MARGIN_M;
			return at >= length ? toward : point.lerp(toward, (real_t)(at / length));
		}
	}
	return point;
}

// SlotGround.on_anchor_side (WET_ENABLED on, the terrain present)
Vector3 ElTerrain::on_anchor_side(const Vector3 &slot, const Vector3 &anchor) const {
	if (over_water(anchor) || !(over_water(slot) || leg_wet(anchor, slot))) {
		return slot;
	}
	const Vector3 at = dry_leg_end(anchor, slot, DRY_MARGIN_M, true);
	return Vector3(at.x, slot.y, at.z);
}

// ---- SlotGround.standable_for, line by line (the node's guards are NativeEl's, in GDScript) ----

// SlotGround.standable (the map ready)
Vector3 ElGround::standable(NavNative *nav, const RID &map, const Vector3 &point) const {
	const Vector3 closest = nav->closest_point(map, Vector3(point.x, 0, point.z));
	const Vector3 flat(closest.x, point.y, closest.z);
	if ((double)Vector2((real_t)((double)flat.x - (double)point.x), (real_t)((double)flat.z - (double)point.z)).length() <= TOLERANCE_M) {
		return point;
	}
	return flat;
}

// SlotGround._off_mesh
Vector3 ElGround::off_mesh(NavNative *nav, const RID &map, const Vector3 &at, double need, int64_t k) const {
	const double angle = Math::TAU * (double)k / (double)CLEARANCE_PROBES;
	const Vector3 probe((real_t)((double)at.x + std::cos(angle) * need), 0, (real_t)((double)at.z + std::sin(angle) * need));
	const Vector3 closest = nav->closest_point(map, probe);
	return Vector3((real_t)((double)closest.x - (double)probe.x), 0, (real_t)((double)closest.z - (double)probe.z));
}

// SlotGround._settle
Vector3 ElGround::settle(NavNative *nav, const RID &map, Vector3 at, double need) const {
	for (int64_t iteration = 0; iteration < CLEARANCE_ITERATIONS; iteration++) {
		Vector3 push;
		for (int64_t k = 0; k < CLEARANCE_PROBES; k++) {
			const Vector3 back = off_mesh(nav, map, at, need, k);
			if ((double)back.length() > PROBE_TOLERANCE_M) {
				push += back;
			}
		}
		if ((double)push.length() <= PROBE_TOLERANCE_M) {
			break;
		}
		at = standable(nav, map, at + push / (real_t)(double)CLEARANCE_PROBES * (real_t)2.0);
	}
	return at;
}

// SlotGround._fits
bool ElGround::fits(NavNative *nav, const RID &map, const Vector3 &at, double need) const {
	for (int64_t k = 0; k < CLEARANCE_PROBES; k++) {
		if ((double)off_mesh(nav, map, at, need, k).length() > TOLERANCE_M * 0.5) {
			return false;
		}
	}
	return true;
}

// SlotGround._standable_for (the map ready)
Vector3 ElGround::compute(NavNative *nav, const RID &map, const Vector3 &point, double clearance, double bake_radius) const {
	Vector3 at = standable(nav, map, point);
	const double need = clearance - bake_radius;
	if (need <= 0.0) {
		return at;
	}
	at = settle(nav, map, at, need);
	if (fits(nav, map, at, need)) {
		return at;
	}
	for (int64_t ring = 1; ring < FIT_RINGS + 1; ring++) {
		bool found = false;
		Vector3 best;
		double best_d = INFINITY;
		for (int64_t k = 0; k < CLEARANCE_PROBES; k++) {
			const double angle = Math::TAU * (double)k / (double)CLEARANCE_PROBES;
			const Vector3 around = at + Vector3((real_t)std::cos(angle), 0, (real_t)std::sin(angle)) * (real_t)need * (real_t)(double)ring;
			const Vector3 candidate = settle(nav, map, standable(nav, map, around), need);
			if (!fits(nav, map, candidate, need)) {
				continue;
			}
			const double d = Vector2((real_t)((double)candidate.x - (double)at.x), (real_t)((double)candidate.z - (double)at.z)).length();
			if (d < best_d) {
				best_d = d;
				best = candidate;
				found = true;
			}
		}
		if (found) {
			return best;
		}
	}
	return at;
}

// SlotGround.standable_for's memo (ground_memo on) and body.
Vector3 ElGround::standable_for(NavNative *nav, const RID &map, int64_t iteration, const Vector3 &point, double clearance,
		double bake_radius) {
	if (map != memo_map || iteration != memo_iteration || (int64_t)memo.size() >= MEMO_LIMIT) {
		memo_map = map;
		memo_iteration = iteration;
		memo.clear();
	}
	Key key;
	std::memcpy(&key.bits[0], &point.x, 4);
	std::memcpy(&key.bits[1], &point.y, 4);
	std::memcpy(&key.bits[2], &point.z, 4);
	std::memcpy(&key.bits[3], &clearance, 8);
	const Vector3 *known = memo.getptr(key);
	if (known != nullptr) {
		return *known;
	}
	const Vector3 answer = compute(nav, map, point, clearance, bake_radius);
	memo.insert(key, answer);
	return answer;
}

} // namespace godot
