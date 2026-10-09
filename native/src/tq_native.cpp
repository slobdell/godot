// Round 24 (native, C24.6): TacticalQuery.find_cover and find_cover_fire (game/ai/tactical_query.gd, brains' file;
// the grant covers the two seams) as ONE call each, with hull_hidden, peek_from, _peek_spot, _cover, _candidates,
// _threats, _spacing, _best and UtilityCurves' linear / smooth / band ported line by line. The map's own columns are
// read in place (CoverMap.points, _point_grid, _grid and the feature columns for inside_any); its sight lines and
// path checks are the CoverNative twin's (N1b), with CoverMap's counters bumped as CoverMap.clear_line bumps them.
// tests/test_native_tq.gd asks the live functions on tests/test_ai_tactical_query.gd's kind of cases and on requests
// seeded from real situations.
#include "tank_native.h"

#include "cover_native.h"
#include "tq_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <algorithm>
#include <cmath>

namespace godot {

namespace {

struct QN {
	StringName position{ "position" }, threats{ "threats" }, search_radius{ "search_radius" }, target{ "target" },
			range{ "range" }, anchor{ "anchor" }, anchor_radius{ "anchor_radius" }, friends{ "friends" }, weight{ "weight" },
			points{ "points" }, _point_grid{ "_point_grid" }, _grid{ "_grid" }, _f_center{ "_f_center" }, _f_axis{ "_f_axis" },
			_f_half{ "_f_half" }, _native{ "_native" }, los_queries{ "los_queries" }, los_computed{ "los_computed" },
			point{ "point" }, score{ "score" }, cover{ "cover" }, hide{ "hide" }, peek{ "peek" };
};
const QN &qn_() {
	static const QN n;
	return n;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double snapped(double value, double step) {
	return step != 0.0 ? std::floor(value / step + 0.5) * step : value;
}
// UtilityCurves.linear / smooth / band
double linear(double x, double from, double to) {
	if (Math::is_equal_approx(from, to)) {
		return x >= to ? 1.0 : 0.0;
	}
	return clampd((x - from) / (to - from), 0.0, 1.0);
}
double smooth(double x, double from, double to) {
	const double t = linear(x, from, to);
	return t * t * (3.0 - 2.0 * t);
}
double band(double x, double low, double high, double soft) {
	if (x < low) {
		return smooth(x, low - soft, low);
	}
	if (x > high) {
		return 1.0 - smooth(x, high, high + soft);
	}
	return 1.0;
}
inline double flat_distance(const Vector3 &a, const Vector3 &b) {
	return (double)Vector2((real_t)((double)a.x - (double)b.x), (real_t)((double)a.z - (double)b.z)).length();
}

// One query's view of the map.
struct Map {
	const TqConsts &c;
	const QN &k;
	Object *map;
	Object *script;
	CoverNative *twin;
	PackedVector2Array points;
	Dictionary point_grid, grid;
	PackedVector2Array f_center, f_axis, f_half;

	Map(const TqConsts &p_c, Object *p_map, CoverNative *p_twin) :
			c(p_c), k(qn_()), map(p_map), script(p_map->get_script()), twin(p_twin) {
		points = map->get(k.points);
		point_grid = map->get(k._point_grid);
		grid = map->get(k._grid);
		f_center = map->get(k._f_center);
		f_axis = map->get(k._f_axis);
		f_half = map->get(k._f_half);
	}

	// CoverMap.clear_line on the native twin, with its counters
	bool clear_line(const Vector3 &a, const Vector3 &b) {
		script->set(k.los_queries, (int64_t)script->get(k.los_queries) + 1);
		const int code = twin->clear_line(a, b);
		if (code & 2) {
			script->set(k.los_computed, (int64_t)script->get(k.los_computed) + 1);
		}
		return (code & 1) == 1;
	}

	// CoverMap.inside_any(point, grow)
	bool inside_any(const Vector2 &p, double grow) const {
		const Vector2i cell((int32_t)std::floor((double)p.x / c.CELL), (int32_t)std::floor((double)p.y / c.CELL));
		const PackedInt32Array members = grid.get(cell, PackedInt32Array());
		for (int64_t m = 0; m < members.size(); m++) {
			const int32_t index = members[m];
			const Vector2 offset = p - f_center[index];
			const Vector2 axis = f_axis[index];
			const Vector2 half = f_half[index];
			if ((double)std::fabs(offset.dot(axis)) <= (double)half.x + grow &&
					(double)std::fabs(offset.dot(Vector2(-axis.y, axis.x))) <= (double)half.y + grow) {
				return true;
			}
		}
		return false;
	}

	// CoverMap.points_near(center, radius): within radius, nearest first, ties by index
	void points_near(const Vector2 &center, double radius, LocalVector<int32_t> &out) const {
		struct P {
			double d;
			int32_t i;
		};
		LocalVector<P> pairs;
		const double limit = radius * radius;
		const int32_t x0 = (int32_t)std::floor(((double)center.x - radius) / c.CELL);
		const int32_t x1 = (int32_t)std::floor(((double)center.x + radius) / c.CELL);
		const int32_t z0 = (int32_t)std::floor(((double)center.y - radius) / c.CELL);
		const int32_t z1 = (int32_t)std::floor(((double)center.y + radius) / c.CELL);
		for (int32_t cx = x0; cx <= x1; cx++) {
			for (int32_t cz = z0; cz <= z1; cz++) {
				const PackedInt32Array members = point_grid.get(Vector2i(cx, cz), PackedInt32Array());
				for (int64_t m = 0; m < members.size(); m++) {
					const int32_t i = members[m];
					const double d = center.distance_squared_to(points[i]);
					if (d <= limit) {
						pairs.push_back(P{ d, i });
					}
				}
			}
		}
		std::sort(pairs.ptr(), pairs.ptr() + pairs.size(), [](const P &a, const P &b) { return a.d < b.d || (a.d == b.d && a.i < b.i); });
		out.clear();
		for (const P &p : pairs) {
			out.push_back(p.i);
		}
	}

	// TacticalQuery.hull_hidden(viewer, point)
	bool hull_hidden(const Vector3 &viewer, const Vector3 &point) {
		if (clear_line(viewer, point)) {
			return false;
		}
		Vector3 across((real_t)((double)point.z - (double)viewer.z), 0, (real_t)((double)viewer.x - (double)point.x));
		if ((double)across.length_squared() < 0.01) {
			return true;
		}
		across = across.normalized() * (real_t)c.HULL_MARGIN;
		return !clear_line(viewer, point + across) && !clear_line(viewer, point - across);
	}

	// TacticalQuery._cover(point, threats)
	double cover(const Vector3 &point, const Array &threats) {
		double total = 0.0;
		double hidden = 0.0;
		for (int64_t i = 0; i < threats.size(); i++) {
			const Dictionary threat = threats[i];
			const double weight = threat.get(k.weight, 1.0);
			total += weight;
			const Vector3 at = threat[k.position];
			if (i == 0 ? hull_hidden(at, point) : !clear_line(at, point)) {
				hidden += weight;
			}
		}
		return total > 0.0 ? hidden / total : 1.0;
	}

	// TacticalQuery._candidates(request, radius)
	void candidates(const Dictionary &request, double radius, LocalVector<int32_t> &out) const {
		const Vector3 me = request[k.position];
		const Variant anchor = request.get(k.anchor, Variant());
		const double anchor_radius = request.get(k.anchor_radius, 0.0);
		const Array friends = request.get(k.friends, Array());
		Vector2 anchor_flat;
		if (anchor.get_type() != Variant::NIL) {
			const Vector3 a = anchor;
			anchor_flat = Vector2(a.x, a.z);
		}
		LocalVector<Vector2> friend_flat;
		for (int64_t f = 0; f < friends.size(); f++) {
			const Vector3 fr = friends[f];
			friend_flat.push_back(Vector2(fr.x, fr.z));
		}
		LocalVector<int32_t> near;
		points_near(Vector2(me.x, me.z), radius, near);
		out.clear();
		for (int32_t index : near) {
			const Vector2 point = points[index];
			if (anchor.get_type() != Variant::NIL && anchor_radius > 0.0 && (double)point.distance_to(anchor_flat) > anchor_radius) {
				continue;
			}
			bool crowded = false;
			for (const Vector2 &fr : friend_flat) {
				if ((double)point.distance_to(fr) < c.FRIEND_SPACING) {
					crowded = true;
					break;
				}
			}
			if (crowded) {
				continue;
			}
			out.push_back(index);
			if ((int64_t)out.size() >= c.MAX_CANDIDATES) {
				break;
			}
		}
	}

	// TacticalQuery._peek_spot(start, direction, distance, target, reach): a Vector3, or `found` false
	bool peek_spot(const Vector2 &start, const Vector2 &direction, double distance, const Vector3 &target, double reach,
			Vector3 &out) {
		const Vector2 flat = start + direction * (real_t)distance;
		if (std::fabs((double)flat.x) > c.EDGE || std::fabs((double)flat.y) > c.EDGE) {
			return false;
		}
		if (inside_any(flat, c.STAND_CLEARANCE) || twin->path_blocked(start, flat, c.DRIVE_CLEARANCE)) {
			return false;
		}
		const Vector3 peek(flat.x, 0, flat.y);
		if (flat_distance(peek, target) > reach - 2.0 || !clear_line(peek, target)) {
			return false;
		}
		out = peek;
		return true;
	}

	// TacticalQuery.peek_from(hide, target, reach)
	bool peek_from(const Vector3 &hide, const Vector3 &target, double reach, Vector3 &out) {
		Vector2 bearing((real_t)((double)target.x - (double)hide.x), (real_t)((double)target.z - (double)hide.z));
		if ((double)bearing.length_squared() < 1.0) {
			return false;
		}
		bearing = bearing.normalized();
		const Vector2 start(hide.x, hide.z);
		for (double distance : c.PEEK_STEPS) {
			for (const TqConsts::Rotation &rotation : c.PEEK_ROTATIONS) {
				for (double side : { 1.0, -1.0 }) {
					const double cc = rotation.c;
					const double sn = rotation.s * side;
					const Vector2 direction((real_t)((double)bearing.x * cc - (double)bearing.y * sn),
							(real_t)((double)bearing.x * sn + (double)bearing.y * cc));
					Vector3 peek;
					if (!peek_spot(start, direction, distance, target, reach, peek)) {
						continue;
					}
					Vector3 further;
					out = peek_spot(start, direction, distance + c.PEEK_MARGIN, target, reach, further) ? further : peek;
					return true;
				}
			}
		}
		return false;
	}
};

Array threats_of(const TqConsts &c, const QN &k, const Dictionary &request) {
	const Array threats = request.get(k.threats, Array());
	return threats.slice(0, c.MAX_THREATS);
}

} // namespace

bool TankNative::tq_configure(const Dictionary &config) {
	TqConsts &c = tq_consts;
	const char *names[] = { "SEARCH_RADIUS", "FRIEND_SPACING", "PEEK_MAX", "DRIVE_CLEARANCE", "STAND_CLEARANCE",
		"HULL_MARGIN", "PEEK_MARGIN", "EDGE", "CELL" };
	double *fields[] = { &c.SEARCH_RADIUS, &c.FRIEND_SPACING, &c.PEEK_MAX, &c.DRIVE_CLEARANCE, &c.STAND_CLEARANCE,
		&c.HULL_MARGIN, &c.PEEK_MARGIN, &c.EDGE, &c.CELL };
	for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
		if (!config.has(names[i])) {
			c.ready = false;
			return false;
		}
		*fields[i] = config[names[i]];
	}
	c.MAX_THREATS = config.get("MAX_THREATS", 6);
	c.MAX_CANDIDATES = config.get("MAX_CANDIDATES", 16);
	c.MAX_DEEP = config.get("MAX_DEEP", 8);
	c.PEEK_STEPS.clear();
	const Array steps = config.get("PEEK_STEPS", Array());
	for (int64_t i = 0; i < steps.size(); i++) {
		c.PEEK_STEPS.push_back(steps[i]);
	}
	c.PEEK_ROTATIONS.clear();
	const Array rotations = config.get("PEEK_ROTATIONS", Array());
	for (int64_t i = 0; i < rotations.size(); i++) {
		const Array r = rotations[i];
		// float(rotation[0]) and float(rotation[1]): GDScript floats, so doubles here too.
		c.PEEK_ROTATIONS.push_back(TqConsts::Rotation{ (double)r[0], (double)r[1] });
	}
	c.ready = !c.PEEK_STEPS.is_empty() && !c.PEEK_ROTATIONS.is_empty();
	return c.ready;
}

Array TankNative::tq_find_cover(Object *map_object, const Dictionary &request, int count) const {
	const TqConsts &c = tq_consts;
	const QN &k = qn_();
	Array result;
	CoverNative *twin = Object::cast_to<CoverNative>(map_object->get(k._native).get_validated_object());
	Map map(c, map_object, twin);
	const Vector3 me = request[k.position];
	const Array threats = threats_of(c, k, request);
	if (threats.is_empty()) {
		return result;
	}
	const double radius = request.get(k.search_radius, c.SEARCH_RADIUS);
	const Vector3 main_threat = ((Dictionary)threats[0])[k.position];
	const double my_threat_distance = flat_distance(me, main_threat);
	const Array friends = request.get(k.friends, Array());
	struct Scored {
		Vector3 point;
		double score, cover;
		int64_t order;
	};
	LocalVector<Scored> scored;
	LocalVector<int32_t> candidates;
	map.candidates(request, radius, candidates);
	for (int32_t index : candidates) {
		const Vector2 flat = map.points[index];
		const Vector3 point(flat.x, 0, flat.y);
		const double cover = map.cover(point, threats);
		if (cover < 0.5) {
			continue;
		}
		const double travel = 1.0 - flat_distance(me, point) / radius;
		const double toward = linear(my_threat_distance - flat_distance(point, main_threat), 0.0, 15.0);
		// _spacing(point, request)
		double nearest = INFINITY;
		for (int64_t f = 0; f < friends.size(); f++) {
			nearest = MIN(nearest, flat_distance(point, friends[f]));
		}
		const double spacing = nearest == INFINITY ? 1.0 : smooth(nearest, c.FRIEND_SPACING, 14.0);
		const double score = (0.6 * cover + 0.25 * travel + 0.15 * spacing) * (1.0 - 0.5 * toward);
		scored.push_back(Scored{ point, snapped(score, 0.0001), cover, (int64_t)scored.size() });
	}
	std::sort(scored.ptr(), scored.ptr() + scored.size(), [](const Scored &a, const Scored &b) {
		return a.score > b.score || (a.score == b.score && a.order < b.order);
	});
	for (int64_t i = 0; i < (int64_t)scored.size() && i < count; i++) {
		Dictionary entry;
		entry[k.point] = scored[i].point;
		entry[k.score] = scored[i].score;
		entry[k.cover] = scored[i].cover;
		result.push_back(entry);
	}
	return result;
}

Dictionary TankNative::tq_find_cover_fire(Object *map_object, const Dictionary &request) const {
	const TqConsts &c = tq_consts;
	const QN &k = qn_();
	Dictionary best;
	const Variant target_v = request.get(k.target, Variant());
	if (target_v.get_type() == Variant::NIL) {
		return best;
	}
	CoverNative *twin = Object::cast_to<CoverNative>(map_object->get(k._native).get_validated_object());
	Map map(c, map_object, twin);
	const Vector3 me = request[k.position];
	const Vector3 target = target_v;
	Array band_default;
	band_default.push_back(20.0);
	band_default.push_back(45.0);
	band_default.push_back(70.0);
	const Array band_a = request.get(k.range, band_default);
	const double band0 = band_a[0], band1 = band_a[1], band2 = band_a[2];
	const double radius = request.get(k.search_radius, c.SEARCH_RADIUS);
	const Array threats = threats_of(c, k, request);
	struct Short {
		Vector3 point;
		double pre, fit, travel;
		int64_t order;
	};
	LocalVector<Short> shortlist;
	LocalVector<int32_t> candidates;
	map.candidates(request, radius, candidates);
	for (int32_t index : candidates) {
		const Vector2 flat = map.points[index];
		const Vector3 point(flat.x, 0, flat.y);
		const double to_target = flat_distance(point, target);
		if (to_target > band2 - 4.0 || to_target < 8.0) {
			continue;
		}
		if (!map.hull_hidden(target, point)) {
			continue;
		}
		const double travel = 1.0 - flat_distance(me, point) / radius;
		const double fit = band(to_target, band0, band1, 20.0);
		shortlist.push_back(Short{ point, 0.55 * fit + 0.45 * travel, fit, travel, (int64_t)shortlist.size() });
	}
	std::sort(shortlist.ptr(), shortlist.ptr() + shortlist.size(), [](const Short &a, const Short &b) {
		return a.pre > b.pre || (a.pre == b.pre && a.order < b.order);
	});
	double best_score = 0.0;
	bool have_best = false;
	for (int64_t i = 0; i < (int64_t)shortlist.size() && i < c.MAX_DEEP; i++) {
		const Vector3 hide = shortlist[i].point;
		Vector3 peek;
		if (!map.peek_from(hide, target, band2, peek)) {
			continue;
		}
		const double others = !threats.is_empty() ? map.cover(hide, threats) : 1.0;
		const Vector2 out((real_t)((double)peek.x - (double)hide.x), (real_t)((double)peek.z - (double)hide.z));
		const double facing = out.normalized().dot(
				Vector2((real_t)((double)target.x - (double)hide.x), (real_t)((double)target.z - (double)hide.z)).normalized());
		const double peek_quality = 0.5 * (1.0 - (double)out.length() / c.PEEK_MAX) + 0.5 * facing;
		const double score = 0.35 * shortlist[i].fit + 0.25 * shortlist[i].travel + 0.25 * others + 0.15 * peek_quality;
		if (!have_best || score > best_score) {
			have_best = true;
			best_score = snapped(score, 0.0001);
			best = Dictionary();
			best[k.hide] = hide;
			best[k.peek] = peek;
			best[k.score] = best_score;
		}
	}
	return best;
}

} // namespace godot
