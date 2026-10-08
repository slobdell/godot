#include "avoidance.h"

#include <cmath>

namespace godot {

// GDScript's minf/maxf/clampf are MIN/MAX/CLAMP: `a < b ? a : b` and friends, kept literally.
static inline double gd_minf(double a, double b) { return a < b ? a : b; }
static inline double gd_maxf(double a, double b) { return a > b ? a : b; }
static inline double gd_clampf(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
// floori(x / CELL): a double division, floored.
static inline int32_t cell_of(double v) { return (int32_t)std::floor(v / AvoidanceTable::CELL); }

void AvoidanceTable::load(const PackedStringArray &p_names, const PackedFloat32Array &p_xs, const PackedFloat32Array &p_zs,
		const PackedFloat32Array &p_vxs, const PackedFloat32Array &p_vzs, const PackedFloat32Array &p_radii,
		const PackedFloat32Array &p_half_w, const PackedFloat32Array &p_half_l, const PackedFloat32Array &p_fxs,
		const PackedFloat32Array &p_fzs, const PackedByteArray &p_still) {
	names = p_names;
	xs = p_xs;
	zs = p_zs;
	vxs = p_vxs;
	vzs = p_vzs;
	radii = p_radii;
	half_w = p_half_w;
	half_l = p_half_l;
	fxs = p_fxs;
	fzs = p_fzs;
	still = p_still;
	grid.clear();
	index.clear();
	const int64_t n = names.size();
	const float *px = xs.ptr();
	const float *pz = zs.ptr();
	for (int64_t i = 0; i < n; i++) {
		index[names[i]] = (int32_t)i;
		// refresh: Vector2i(floori(p.x / CELL), floori(p.z / CELL)) with p.x a float32 read as a double.
		const Vector2i cell(cell_of((double)px[i]), cell_of((double)pz[i]));
		grid[cell].push_back((int32_t)i);
	}
}

void AvoidanceTable::neighbours(const String &me, double x, double z, int cap, LocalVector<Near> &found) const {
	found.clear();
	const double reach_sq = NEIGHBOUR_RADIUS * NEIGHBOUR_RADIUS;
	const int span = (int)std::ceil(NEIGHBOUR_RADIUS / CELL);
	const int32_t cx = cell_of(x);
	const int32_t cz = cell_of(z);
	const float *px = xs.ptr();
	const float *pz = zs.ptr();
	for (int32_t gx = cx - span; gx <= cx + span; gx++) {
		for (int32_t gz = cz - span; gz <= cz + span; gz++) {
			const LocalVector<int32_t> *cell = grid.getptr(Vector2i(gx, gz));
			if (cell == nullptr) {
				continue;
			}
			for (uint32_t k = 0; k < cell->size(); k++) {
				const int32_t i = (*cell)[k];
				const double dx = (double)px[i] - x;
				const double dz = (double)pz[i] - z;
				const double d = dx * dx + dz * dz;
				if (d < reach_sq && names[i] != me) {
					// _insert_nearest: keep the `cap` nearest so far, ordered by (d, name), as each candidate arrives.
					const String name = names[i];
					uint32_t at = found.size();
					while (at > 0) {
						const Near &other = found[at - 1];
						if (other.d < d || (other.d == d && other.name < name)) {
							break;
						}
						at--;
					}
					if ((int)at >= cap) {
						continue;
					}
					found.insert(at, Near{ d, name, i });
					if ((int)found.size() > cap) {
						found.resize(cap);
					}
				}
			}
		}
	}
}

double AvoidanceTable::support(int i, const Vector2 &d) const {
	const Vector2 forward(fxs[i], fzs[i]);
	const Vector2 right(-forward.y, forward.x);
	// _half_w[i] * absf(d.dot(right)) + _half_l[i] * absf(d.dot(forward)): dots in float32, the rest double.
	return (double)half_w[i] * std::fabs((double)d.dot(right)) + (double)half_l[i] * std::fabs((double)d.dot(forward));
}

double AvoidanceTable::pair_radius(int a, int b, const Vector2 &d) const {
	return support(a, d) + support(b, d) + 2.0 * RADIUS_MARGIN;
}

Vector2 AvoidanceTable::solve(const String &me, const Vector2 &position, const Vector2 &velocity, const Vector2 &preferred,
		double max_speed, double radius, double dt, int cap, bool oriented, int &near_count, int &oriented_count) const {
	LocalVector<Near> near;
	neighbours(me, (double)position.x, (double)position.y, cap, near);
	near_count = (int)near.size();
	oriented_count = 0;
	if (near.is_empty()) {
		return preferred;
	}
	const int32_t *mine_ptr = index.getptr(me);
	const int32_t mine = mine_ptr ? *mine_ptr : -1;
	const double inv_horizon = 1.0 / TIME_HORIZON;
	LocalVector<Vector2> points;
	LocalVector<Vector2> directions;
	points.reserve(near.size());
	directions.reserve(near.size());
	for (uint32_t k = 0; k < near.size(); k++) {
		const int32_t i = near[k].i;
		// Vector2(_xs[i] - position.x, _zs[i] - position.y): float32 members read as doubles, narrowed by the constructor.
		const Vector2 relative_position((real_t)((double)xs[i] - (double)position.x), (real_t)((double)zs[i] - (double)position.y));
		const Vector2 other_velocity(vxs[i], vzs[i]);
		const Vector2 relative_velocity = velocity - other_velocity;
		const double distance_sq = (double)relative_position.length_squared();
		double combined = radius + (double)radii[i];
		if (oriented && mine >= 0 && distance_sq > 0.0001) {
			combined = pair_radius(mine, i, relative_position / (real_t)std::sqrt(distance_sq));
			oriented_count++;
		}
		const double combined_sq = combined * combined;
		Vector2 direction;
		Vector2 u;
		if (distance_sq > combined_sq) {
			const Vector2 w = relative_velocity - relative_position * (real_t)inv_horizon;
			const double w_length_sq = (double)w.length_squared();
			const double dot1 = (double)w.dot(relative_position);
			if (dot1 < 0.0 && dot1 * dot1 > combined_sq * w_length_sq) {
				const double w_length = std::sqrt(w_length_sq);
				const Vector2 unit_w = w / (real_t)w_length;
				direction = Vector2(unit_w.y, -unit_w.x);
				u = unit_w * (real_t)(combined * inv_horizon - w_length);
			} else {
				const double leg = std::sqrt(distance_sq - combined_sq);
				const double rx = (double)relative_position.x;
				const double ry = (double)relative_position.y;
				if (det(relative_position, w) > 0.0) {
					direction = Vector2((real_t)(rx * leg - ry * combined), (real_t)(rx * combined + ry * leg)) / (real_t)distance_sq;
				} else {
					direction = -Vector2((real_t)(rx * leg + ry * combined), (real_t)(-rx * combined + ry * leg)) / (real_t)distance_sq;
				}
				u = direction * relative_velocity.dot(direction) - relative_velocity;
			}
		} else {
			const double inv_dt = 1.0 / dt;
			const Vector2 w = relative_velocity - relative_position * (real_t)inv_dt;
			double w_length = (double)w.length();
			Vector2 unit_w = w_length > EPSILON ? w / (real_t)w_length : Vector2(0.0, 1.0);
			if (distance_sq < 0.01) {
				unit_w = me < names[i] ? Vector2(1.0, 0.0) : Vector2(-1.0, 0.0);
				w_length = 0.0;
			}
			direction = Vector2(unit_w.y, -unit_w.x);
			u = unit_w * (real_t)(combined * inv_dt - w_length);
		}
		const double share = still[i] ? 1.0 : 0.5;
		points.push_back(velocity + u * (real_t)share);
		directions.push_back(direction);
	}
	Vector2 holder;
	const int failed = program2(points, directions, max_speed, preferred, false, holder);
	Vector2 result = holder;
	if (failed < (int)points.size()) {
		result = program3(points, directions, failed, max_speed, result);
	}
	return result;
}

bool AvoidanceTable::program1(const LocalVector<Vector2> &points, const LocalVector<Vector2> &directions, int n,
		double radius, const Vector2 &optimal, bool direction_opt, Vector2 &holder) {
	const double dot = (double)points[n].dot(directions[n]);
	const double discriminant = dot * dot + radius * radius - (double)points[n].length_squared();
	if (discriminant < 0.0) {
		return false;
	}
	const double root = std::sqrt(discriminant);
	double t_left = -dot - root;
	double t_right = -dot + root;
	for (int i = 0; i < n; i++) {
		const double denominator = det(directions[n], directions[i]);
		const double numerator = det(directions[i], points[n] - points[i]);
		if (std::fabs(denominator) <= EPSILON) {
			if (numerator < 0.0) {
				return false;
			}
			continue;
		}
		const double t = numerator / denominator;
		if (denominator >= 0.0) {
			t_right = gd_minf(t_right, t);
		} else {
			t_left = gd_maxf(t_left, t);
		}
		if (t_left > t_right) {
			return false;
		}
	}
	if (direction_opt) {
		if ((double)optimal.dot(directions[n]) > 0.0) {
			holder = points[n] + directions[n] * (real_t)t_right;
		} else {
			holder = points[n] + directions[n] * (real_t)t_left;
		}
	} else {
		const double t = gd_clampf((double)directions[n].dot(optimal - points[n]), t_left, t_right);
		holder = points[n] + directions[n] * (real_t)t;
	}
	return true;
}

int AvoidanceTable::program2(const LocalVector<Vector2> &points, const LocalVector<Vector2> &directions, double radius,
		const Vector2 &optimal, bool direction_opt, Vector2 &holder) {
	if (direction_opt) {
		holder = optimal * (real_t)radius;
	} else if ((double)optimal.length_squared() > radius * radius) {
		holder = optimal.normalized() * (real_t)radius;
	} else {
		holder = optimal;
	}
	for (uint32_t i = 0; i < points.size(); i++) {
		if (det(directions[i], points[i] - holder) > 0.0) {
			const Vector2 before = holder;
			if (!program1(points, directions, (int)i, radius, optimal, direction_opt, holder)) {
				holder = before;
				return (int)i;
			}
		}
	}
	return (int)points.size();
}

Vector2 AvoidanceTable::program3(const LocalVector<Vector2> &points, const LocalVector<Vector2> &directions, int begin,
		double radius, Vector2 result) {
	double distance = 0.0;
	for (uint32_t i = (uint32_t)begin; i < points.size(); i++) {
		if (det(directions[i], points[i] - result) <= distance) {
			continue;
		}
		LocalVector<Vector2> projected_points;
		LocalVector<Vector2> projected_directions;
		for (uint32_t j = 0; j < i; j++) {
			const double determinant = det(directions[i], directions[j]);
			Vector2 point;
			if (std::fabs(determinant) <= EPSILON) {
				if ((double)directions[i].dot(directions[j]) > 0.0) {
					continue;
				}
				point = (points[i] + points[j]) * (real_t)0.5;
			} else {
				point = points[i] + directions[i] * (real_t)(det(directions[j], points[i] - points[j]) / determinant);
			}
			projected_points.push_back(point);
			projected_directions.push_back((directions[j] - directions[i]).normalized());
		}
		Vector2 holder = result;
		if (program2(projected_points, projected_directions, radius, Vector2(-directions[i].y, directions[i].x), true, holder) <
				(int)projected_points.size()) {
			holder = result;
		}
		result = holder;
		distance = det(directions[i], points[i] - result);
	}
	return result;
}

} // namespace godot
