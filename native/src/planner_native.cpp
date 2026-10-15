// PlannerNative (round 31, planner CP-P0): game/ai/planner/{planner,planner_world,planner_nav_world,planner_heuristic}.gd
// line by line. The comment above each function names the GDScript it is; the widths are noted where they matter.
#include "planner_native.h"

#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>
#include <cstdio>
#include <limits>

namespace godot {

namespace {

constexpr double INF = std::numeric_limits<double>::infinity();
constexpr float INF_F = std::numeric_limits<float>::infinity();
constexpr double PI_D = 3.14159265358979323846;
constexpr double TAU_D = 6.28318530717958647692;

// Planner's constants
constexpr double SUB_M = 0.5;
const double LEG_ENDS_M[] = { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 16.0, 20.0, 24.0 };
constexpr int64_t LEG_ENDS_N = 12;
constexpr double LEG_MAX_M = 24.0;
constexpr int64_t HEADING_BINS = 24;
constexpr int64_t FINE_BINS = 36;
constexpr double FINE_CELL_M = 0.5;
const double STEERS[] = { -1.0, -0.5, 0.0, 0.5, 1.0 }; // Planner.STEERS and PlannerHeuristic.STEERS (round 31: half lock)
constexpr double MARGIN_M = 0.4;
constexpr double EPSILON = 1.5;
constexpr double STEER_CHANGE_S = 0.8;
constexpr double BAND_M = 1.5;
constexpr double BAND_S_PER_M = 0.5;
constexpr double ROLL_SLACK_M = 0.5;
constexpr double CELL_M = 1.0;
// PlannerHeuristic's
constexpr double TABLE_CELL_M = 2.0;
constexpr int64_t TABLE_BINS = 12;
constexpr double TABLE_HALF_M = 32.0;
const double TABLE_LEGS[] = { 2.0, 4.0, 8.0, 16.0 };
constexpr int64_t TABLE_LEGS_N = 4;
constexpr double TABLE_SUB_M = 2.0;

inline double maxd(double a, double b) { return a > b ? a : b; }
inline double mind(double a, double b) { return a < b ? a : b; }
inline double absd(double a) { return a < 0.0 ? -a : a; }
// Math::fposmod(double, double), as the engine's GDScript `fposmod` is.
inline double fposmod(double x, double y) {
	double value = std::fmod(x, y);
	if (((value < 0) && (y > 0)) || ((value > 0) && (y < 0))) {
		value += y;
	}
	value += 0.0;
	return value;
}
inline double deg_to_rad(double d) { return d * (PI_D / 180.0); }
// int(floor(x)) in GDScript: floor to double, then truncate to int64.
inline int64_t ifloor(double x) { return (int64_t)std::floor(x); }

// Planner._wrap
inline double wrap(double a) { return fposmod(a + PI_D, TAU_D) - PI_D; }
// Planner._tan (the series; trig-free)
inline double tan_series(double a) {
	const double a2 = a * a;
	return a * (1.0 + a2 * (1.0 / 3.0 + a2 * (2.0 / 15.0 + a2 * 17.0 / 315.0)));
}
// Planner._effective_radius
inline double effective_radius(double radius, double v, double tick_s) {
	const double d = v * tick_s / radius;
	return radius / maxd(1.0 - d * d / 3.0, 0.5);
}
// Planner._key
inline int64_t key_of(double x, double z, double th, int64_t gear, double cell_m, int64_t bins) {
	const int64_t ix = ifloor(x / cell_m) + 4096;
	const int64_t iz = ifloor(z / cell_m) + 4096;
	const int64_t ib = ifloor(fposmod(th, TAU_D) / TAU_D * (double)bins) % bins;
	return ((ix * 8192 + iz) * 64 + ib) * 2 + (gear > 0 ? 1 : 0);
}
// PlannerHeuristic._n / _index
constexpr int64_t table_n() { return (int64_t)(TABLE_HALF_M * 2.0 / TABLE_CELL_M); }
inline int64_t table_index(double x, double z, double th, int64_t gear) {
	const int64_t n = table_n();
	const int64_t ix = ifloor((x + TABLE_HALF_M) / TABLE_CELL_M);
	const int64_t iz = ifloor((z + TABLE_HALF_M) / TABLE_CELL_M);
	if (ix < 0 || iz < 0 || ix >= n || iz >= n) {
		return -1;
	}
	const int64_t ib = ifloor(fposmod(th, TAU_D) / TAU_D * (double)TABLE_BINS) % TABLE_BINS;
	return ((ix * n + iz) * TABLE_BINS + ib) * 2 + (gear > 0 ? 1 : 0);
}
// PlannerHeuristic.lookup: table values are float32, the sum with cusp_s a double.
inline double table_lookup(const std::vector<float> &table, double dx, double dz, double th, int64_t gear_in, double cusp_s) {
	double best = INF;
	const int64_t leaving_gears[2] = { 1, -1 };
	for (int64_t leaving : leaving_gears) {
		const int64_t i = table_index(dx, dz, th, leaving);
		if (i < 0) {
			return INF;
		}
		double v = (double)table[(size_t)i];
		if (v == INF) {
			continue;
		}
		if (gear_in != 0 && leaving != gear_in) {
			v += cusp_s;
		}
		if (v < best) {
			best = v;
		}
	}
	return best;
}

// Planner._heap_push / _heap_pop on (float32 f, int32 id); ties by the lower id.
inline void heap_push(std::vector<float> &hf, std::vector<int32_t> &hid, double f, int32_t id) {
	hf.push_back((float)f);
	hid.push_back(id);
	size_t i = hf.size() - 1;
	while (i > 0) {
		const size_t p = (i - 1) >> 1;
		if (hf[p] < hf[i] || (hf[p] == hf[i] && hid[p] < hid[i])) {
			break;
		}
		const float tf = hf[p];
		hf[p] = hf[i];
		hf[i] = tf;
		const int32_t ti = hid[p];
		hid[p] = hid[i];
		hid[i] = ti;
		i = p;
	}
}
inline int32_t heap_pop(std::vector<float> &hf, std::vector<int32_t> &hid) {
	const int32_t top = hid[0];
	const size_t last = hf.size() - 1;
	hf[0] = hf[last];
	hid[0] = hid[last];
	hf.resize(last);
	hid.resize(last);
	const size_t n = last;
	size_t i = 0;
	while (true) {
		const size_t l = 2 * i + 1;
		const size_t r = l + 1;
		size_t m = i;
		if (l < n && (hf[l] < hf[m] || (hf[l] == hf[m] && hid[l] < hid[m]))) {
			m = l;
		}
		if (r < n && (hf[r] < hf[m] || (hf[r] == hf[m] && hid[r] < hid[m]))) {
			m = r;
		}
		if (m == i) {
			break;
		}
		const float tf = hf[m];
		hf[m] = hf[i];
		hf[i] = tf;
		const int32_t ti = hid[m];
		hid[m] = hid[i];
		hid[i] = ti;
		i = m;
	}
	return top;
}

// PlannerWorld._separated: Vector2 (real_t) math exactly where the GDScript spells a Vector2; the sums are doubles.
inline bool separated(double dx, double dz, double fax, double faz, double la, double wa, double fbx, double fbz, double lb, double wb) {
	const Vector2 axes[4] = { Vector2((real_t)fax, (real_t)faz), Vector2((real_t)(-faz), (real_t)fax),
		Vector2((real_t)fbx, (real_t)fbz), Vector2((real_t)(-fbz), (real_t)fbx) };
	const Vector2 a_f((real_t)fax, (real_t)faz);
	const Vector2 a_r((real_t)(-faz), (real_t)fax);
	const Vector2 b_f((real_t)fbx, (real_t)fbz);
	const Vector2 b_r((real_t)(-fbz), (real_t)fbx);
	const Vector2 d((real_t)dx, (real_t)dz);
	for (const Vector2 &axis : axes) {
		const double ra = la * absd((double)axis.dot(a_f)) + wa * absd((double)axis.dot(a_r));
		const double rb = lb * absd((double)axis.dot(b_f)) + wb * absd((double)axis.dot(b_r));
		if (absd((double)d.dot(axis)) > ra + rb) {
			return true;
		}
	}
	return false;
}

// Planner._swing_per_leg
double swing_per_leg(double room, double radius, double half_l, double half_w) {
	if (room >= radius + half_l) {
		return PI_D;
	}
	double lo = 0.0;
	double hi = PI_D * 0.5;
	for (int i = 0; i < 24; i++) {
		const double a = (lo + hi) * 0.5;
		const double a2 = a * a;
		const double one_minus_cos = a2 * 0.5 - a2 * a2 / 24.0;
		const double sin_a = a - a2 * a / 6.0;
		const double cos_a = 1.0 - one_minus_cos;
		const double need = radius * one_minus_cos + half_l * sin_a + half_w * cos_a;
		if (need <= room) {
			lo = a;
		} else {
			hi = a;
		}
	}
	return maxd(lo, 0.26);
}

const char *code_name(PlannerNative::Code c) {
	switch (c) {
		case PlannerNative::OK: return "OK";
		case PlannerNative::NO_PATH: return "NO_PATH";
		case PlannerNative::BUDGET: return "BUDGET";
		case PlannerNative::START_BLOCKED: return "START_BLOCKED";
		case PlannerNative::GOAL_BLOCKED: return "GOAL_BLOCKED";
		case PlannerNative::ALREADY_THERE: return "ALREADY_THERE";
		default: return "NONE";
	}
}

} // namespace

// ============================================================ the world ============================================

Ref<NavNative> &PlannerNative::World::index() {
	if (nav_index.is_null()) {
		nav_index.instantiate();
	}
	return nav_index;
}

PlannerNative::World::NavCache PlannerNative::World::nav_cache;

// PlannerWorld.prepare
void PlannerNative::World::prepare(double cx, double cz, double half) {
	field_n = (int64_t)std::ceil(half * 2.0 / CELL_M) + 3;
	field_x0 = ifloor((cx - half) / CELL_M) - 1;
	field_z0 = ifloor((cz - half) / CELL_M) - 1;
	field.assign((size_t)(field_n * field_n), (float)UNSET);
	spill.clear();
	if (nav) {
		const uint64_t iteration = (uint64_t)NavigationServer3D::get_singleton()->map_get_iteration_id(map);
		if (nav_cache.map_id != (uint64_t)map.get_id() || nav_cache.iteration != iteration || nav_cache.bake_radius != bake_radius) {
			nav_cache.chunks.clear();
			nav_cache.map_id = (uint64_t)map.get_id();
			nav_cache.iteration = iteration;
			nav_cache.bake_radius = bake_radius;
			nav_cache.hits = nav_cache.misses = 0;
		}
	}
}

// A navmesh cell from the shared cache (computed on its first read by any plan of the match).
float PlannerNative::World::cached_cell(int64_t ix, int64_t iz) {
	const int64_t cx = ix >= 0 ? ix / CHUNK : -((-ix - 1) / CHUNK) - 1;
	const int64_t cz = iz >= 0 ? iz / CHUNK : -((-iz - 1) / CHUNK) - 1;
	const int64_t key = (cx + 1048576) * 2097152 + (cz + 1048576);
	auto found = nav_cache.chunks.find(key);
	if (found == nav_cache.chunks.end()) {
		found = nav_cache.chunks.emplace(key, std::vector<float>((size_t)(CHUNK * CHUNK), (float)UNSET)).first;
	}
	std::vector<float> &chunk = found->second;
	const size_t i = (size_t)((ix - cx * CHUNK) * CHUNK + (iz - cz * CHUNK));
	float v = chunk[i];
	if ((double)v > UNSET_BELOW) {
		nav_cache.hits++;
		return v;
	}
	nav_cache.misses++;
	v = (float)wall_distance(((double)ix + 0.5) * CELL_M, ((double)iz + 0.5) * CELL_M);
	chunk[i] = v;
	return v;
}

// PlannerWorld._wall_distance (the rectangles) / PlannerNavWorld._wall_distance (the navmesh).
double PlannerNative::World::wall_distance(double x, double z) {
	wall_reads++;
	if (nav) {
		// var at := Vector3(x, 0.0, z)  (float32); closest = map_get_closest_point(map, at)
		// return bake_radius - Vector2(closest.x - x, closest.z - z).length()
		const Vector3 at((real_t)x, 0.0f, (real_t)z);
		const Vector3 closest = index()->closest_point(map, at); // = map_get_closest_point(map, at), bit for bit
		const Vector2 off((real_t)((double)closest.x - x), (real_t)((double)closest.z - z));
		return bake_radius - (double)off.length();
	}
	double best = FAR_M;
	for (const Wall &wall : walls) {
		const double fx = wall.fx;
		const double fz = wall.fz;
		const double dx = x - wall.cx;
		const double dz = z - wall.cz;
		const double along = dx * fx + dz * fz;
		const double across = -dx * fz + dz * fx;
		const double ox = absd(along) - wall.half_along;
		const double oz = absd(across) - wall.half_across;
		double d;
		if (ox > 0.0 && oz > 0.0) {
			d = std::sqrt(ox * ox + oz * oz);
		} else {
			d = maxd(ox, oz);
		}
		if (d < best) {
			best = d;
		}
	}
	return best;
}

// PlannerWorld._cell: a cell is the float32 the field stores, on its first read as on every later one (P6). A
// navmesh world reads the shared per-match cache; a rectangle world (the tests) its own window and spill.
// The window is the search's own flat array either way; a navmesh world fills a window cell from the shared cache on
// its FIRST read in this search (one hash lookup a cell a search, not one a read: the census on c158aecf read ~1700
// cells an expansion, ~170 us, with the cache hit 99.99 %; a flat read is the rectangle worlds' ~40 us). So the window
// holds exactly the cells this search read, as the GDScript's does, and the twin compares it two-sided.
double PlannerNative::World::cell(int64_t ix, int64_t iz) {
	const int64_t cx = ix - field_x0;
	const int64_t cz = iz - field_z0;
	if (cx >= 0 && cz >= 0 && cx < field_n && cz < field_n) {
		const size_t i = (size_t)(cx * field_n + cz);
		const float v = field[i];
		if ((double)v > UNSET_BELOW) {
			return (double)v;
		}
		field[i] = nav ? cached_cell(ix, iz) : (float)wall_distance(((double)ix + 0.5) * CELL_M, ((double)iz + 0.5) * CELL_M);
		return (double)field[i];
	}
	if (nav) {
		return (double)cached_cell(ix, iz); // outside the window: the cache is the spill
	}
	const int64_t key = (ix + 1048576) * 2097152 + (iz + 1048576);
	auto known = spill.find(key);
	if (known != spill.end()) {
		return (double)known->second;
	}
	const float d = (float)wall_distance(((double)ix + 0.5) * CELL_M, ((double)iz + 0.5) * CELL_M);
	spill[key] = d;
	return (double)d;
}

// PlannerWorld.clearance
double PlannerNative::World::clearance(double x, double z) {
	const double gx = x / CELL_M;
	const double gz = z / CELL_M;
	const int64_t ix = ifloor(gx);
	const int64_t iz = ifloor(gz);
	const double tx = gx - (double)ix;
	const double tz = gz - (double)iz;
	const double c00 = cell(ix, iz);
	const double c10 = cell(ix + 1, iz);
	const double c01 = cell(ix, iz + 1);
	const double c11 = cell(ix + 1, iz + 1);
	if (c00 >= FAR_M && c10 >= FAR_M && c01 >= FAR_M && c11 >= FAR_M) {
		return INF;
	}
	const double a = c00 + (c10 - c00) * tx;
	const double b = c01 + (c11 - c01) * tx;
	return a + (b - a) * tz - SAMPLE_SLACK_M;
}

// PlannerWorld._walk
double PlannerNative::World::walk(double ax, double az, double bx, double bz, double margin) {
	const double dx = bx - ax;
	const double dz = bz - az;
	const double length = std::sqrt(dx * dx + dz * dz);
	double least = INF;
	double t = 0.0;
	while (true) {
		const double c = length > 0.0 ? clearance(ax + dx * (t / length), az + dz * (t / length)) : clearance(ax, az);
		if (c < least) {
			least = c;
		}
		if (c < margin) {
			return least;
		}
		if (t >= length) {
			return least;
		}
		t += maxd(c - margin, CELL_M);
		if (t > length) {
			t = length;
		}
	}
}

// PlannerWorld.side_clearances (a PackedFloat32Array there: float32 out)
void PlannerNative::World::side_clearances(double x, double z, double fx, double fz, double half_w, double half_l, double margin, float out[4]) {
	const double rx = -fz;
	const double rz = fx;
	const double frx = x + fx * half_l + rx * half_w;
	const double frz = z + fz * half_l + rz * half_w;
	const double brx = x - fx * half_l + rx * half_w;
	const double brz = z - fz * half_l + rz * half_w;
	const double blx = x - fx * half_l - rx * half_w;
	const double blz = z - fz * half_l - rz * half_w;
	const double flx = x + fx * half_l - rx * half_w;
	const double flz = z + fz * half_l - rz * half_w;
	out[0] = (float)walk(flx, flz, frx, frz, margin);
	out[1] = (float)walk(frx, frz, brx, brz, margin);
	out[2] = (float)walk(brx, brz, blx, blz, margin);
	out[3] = (float)walk(blx, blz, flx, flz, margin);
}

// PlannerWorld.footprint
double PlannerNative::World::footprint(double x, double z, double fx, double fz, double half_w, double half_l, double margin, const float start[4]) {
	float sides[4];
	side_clearances(x, z, fx, fz, half_w, half_l, margin, sides);
	double least = INF;
	for (int i = 0; i < 4; i++) {
		const double c = (double)sides[i];
		if (c < margin && c < (double)start[i] - 0.05) {
			return -1.0;
		}
		if (c < least) {
			least = c;
		}
	}
	if (!hulls.empty() && hull_overlap(x, z, fx, fz, half_w, half_l, HULL_MARGIN_M)) {
		return -1.0;
	}
	return least;
}

// PlannerWorld._hull_overlap
bool PlannerNative::World::hull_overlap(double x, double z, double fx, double fz, double half_w, double half_l, double grow) const {
	for (const Hull &hull : hulls) {
		const double ox = hull.cx;
		const double oz = hull.cz;
		const double ofx = hull.fx;
		const double ofz = hull.fz;
		const double ohw = hull.half_w + grow;
		const double ohl = hull.half_l + grow;
		const double dx = ox - x;
		const double dz = oz - z;
		const double reach = half_l + ohl + half_w + ohw;
		if (dx * dx + dz * dz > reach * reach) {
			continue;
		}
		if (separated(dx, dz, fx, fz, half_l, half_w, ofx, ofz, ohl, ohw)) {
			continue;
		}
		return true;
	}
	return false;
}

// ============================================================ the table ============================================

// PlannerHeuristic._build
std::vector<float> PlannerNative::build_table(double radius, double v_fwd, double v_rev, double cusp_s) {
	const int64_t n = table_n();
	const size_t size = (size_t)(n * n * TABLE_BINS * 2);
	std::vector<float> table(size, INF_F);
	std::vector<float> nx, nz, nfx, nfz, nth, ng;
	std::vector<int32_t> ngear;
	std::vector<float> hf;
	std::vector<int32_t> hid;
	std::unordered_set<int64_t> closed;
	const int64_t gears[2] = { 1, -1 };
	for (int64_t gear : gears) {
		nx.push_back(0.0f);
		nz.push_back(0.0f);
		nfx.push_back(1.0f);
		nfz.push_back(0.0f);
		nth.push_back(0.0f);
		ng.push_back(0.0f);
		ngear.push_back((int32_t)gear);
		heap_push(hf, hid, 0.0, (int32_t)nx.size() - 1);
	}
	while (!hf.empty()) {
		const int32_t cur = heap_pop(hf, hid);
		const int64_t key = table_index((double)nx[cur], (double)nz[cur], (double)nth[cur], ngear[cur]);
		if (key < 0 || closed.count(key)) {
			continue;
		}
		closed.insert(key);
		table[(size_t)key] = ng[cur];
		const double px = (double)nx[cur];
		const double pz = (double)nz[cur];
		const double pfx = (double)nfx[cur];
		const double pfz = (double)nfz[cur];
		const double pth = (double)nth[cur];
		const double pg = (double)ng[cur];
		const int64_t pgear = ngear[cur];
		for (int64_t gear : gears) {
			const double leg_cost_per_m = 1.0 / (gear > 0 ? v_fwd : v_rev);
			const bool cusp = pgear != 0 && gear != pgear;
			for (double steer : STEERS) {
				double x = px;
				double z = pz;
				double fx = pfx;
				double fz = pfz;
				double th = pth;
				const double dth = -TABLE_SUB_M * steer / radius;
				double swept = 0.0;
				int64_t next_end = 0;
				while (swept < TABLE_LEGS[TABLE_LEGS_N - 1] - 0.001) {
					if (steer != 0.0) {
						const double tx = fx - fz * dth;
						const double tz = fz + fx * dth;
						const double inv = 1.0 / std::sqrt(tx * tx + tz * tz);
						fx = tx * inv;
						fz = tz * inv;
						th += dth;
					}
					x -= fx * TABLE_SUB_M * (double)gear;
					z -= fz * TABLE_SUB_M * (double)gear;
					swept += TABLE_SUB_M;
					if (next_end < TABLE_LEGS_N && swept >= TABLE_LEGS[next_end] - 0.001) {
						next_end += 1;
						const int64_t k = table_index(x, z, th, gear);
						if (k < 0) {
							break;
						}
						if (closed.count(k)) {
							continue;
						}
						const double g = pg + swept * leg_cost_per_m + (cusp ? cusp_s : 0.0);
						if (g >= (double)table[(size_t)k]) {
							continue;
						}
						table[(size_t)k] = (float)g;
						nx.push_back((float)x);
						nz.push_back((float)z);
						nfx.push_back((float)fx);
						nfz.push_back((float)fz);
						nth.push_back((float)th);
						ng.push_back((float)g);
						ngear.push_back((int32_t)gear);
						heap_push(hf, hid, g, (int32_t)nx.size() - 1);
					}
				}
			}
		}
	}
	return table;
}

std::unordered_map<std::string, std::vector<float>> PlannerNative::tables;
int64_t PlannerNative::last_table_build_usec = -1;
uint64_t PlannerNative::tables_built = 0;

// PlannerHeuristic.table_for: cached by the GDScript's key "%.2f|%.2f|%.2f|%.2f" of (radius, v_fwd, v_rev, cusp_s),
// built from the request's own (maxf'd) values the first time that key is seen.
const std::vector<float> &PlannerNative::table_for(const Request &r) {
	char key[128];
	std::snprintf(key, sizeof key, "%.2f|%.2f|%.2f|%.2f", r.radius, r.v_fwd, r.v_rev, r.cusp_s);
	auto found = tables.find(key);
	if (found != tables.end()) {
		return found->second;
	}
	const int64_t started = (int64_t)Time::get_singleton()->get_ticks_usec();
	std::vector<float> built = build_table(maxd(r.radius, 0.5), maxd(r.v_fwd, 0.1), maxd(r.v_rev, 0.1), r.cusp_s);
	last_table_build_usec = (int64_t)Time::get_singleton()->get_ticks_usec() - started; // measurement only
	tables_built++;
	return tables.emplace(std::string(key), std::move(built)).first->second;
}

// ============================================================ the request ==========================================

PlannerNative::Request PlannerNative::parse_request(const Dictionary &d) {
	Request r;
	r.start_x = (double)d.get("start_x", 0.0);
	r.start_z = (double)d.get("start_z", 0.0);
	r.start_fx = (double)d.get("start_fx", 0.0);
	r.start_fz = (double)d.get("start_fz", -1.0);
	r.goal_x = (double)d.get("goal_x", 0.0);
	r.goal_z = (double)d.get("goal_z", 0.0);
	r.goal_fx = (double)d.get("goal_fx", 0.0);
	r.goal_fz = (double)d.get("goal_fz", -1.0);
	r.tol_m = (double)d.get("tol_m", 1.0);
	r.tol_deg = (double)d.get("tol_deg", 8.0);
	r.arrive_gear = (int64_t)d.get("arrive_gear", 0);
	r.aim = (bool)d.get("aim", false);
	r.half_w = (double)d.get("half_w", 1.0);
	r.half_l = (double)d.get("half_l", 2.0);
	r.radius = (double)d.get("radius", 6.0);
	r.v_fwd = (double)d.get("v_fwd", 6.0);
	r.v_rev = (double)d.get("v_rev", 2.5);
	r.cusp_s = (double)d.get("cusp_s", 0.0);
	r.budget = (int64_t)d.get("budget", 1500);
	r.horizon_m = (double)d.get("horizon_m", 30.0);
	r.epsilon = (double)d.get("epsilon", 0.0);
	r.fine_retry = (bool)d.get("fine_retry", true);
	r.tick_s = (double)d.get("tick_s", 1.0 / 30.0);
	return r;
}

// PlannerWorld.native_view(): walls as [cx, cz, half_along, half_across, fx, fz] x n, hulls as [cx, cz, fx, fz,
// half_w, half_l] x n (PackedFloat64Array: the GDScript's doubles arrive unchanged), map + bake_radius for a nav world.
void PlannerNative::parse_world(const Dictionary &d, World &w) {
	w.walls.clear();
	w.hulls.clear();
	w.nav = false;
	w.wall_reads = 0;
	const PackedFloat64Array walls = d.get("walls", PackedFloat64Array());
	for (int64_t i = 0; i + 5 < walls.size(); i += 6) {
		w.walls.push_back({ walls[i], walls[i + 1], walls[i + 2], walls[i + 3], walls[i + 4], walls[i + 5] });
	}
	const PackedFloat64Array hulls = d.get("hulls", PackedFloat64Array());
	for (int64_t i = 0; i + 5 < hulls.size(); i += 6) {
		w.hulls.push_back({ hulls[i], hulls[i + 1], hulls[i + 2], hulls[i + 3], hulls[i + 4], hulls[i + 5] });
	}
	if (d.has("map")) {
		w.nav = true;
		w.map = (RID)d["map"];
		w.bake_radius = (double)d.get("bake_radius", 2.0);
		if (d.has("nav")) {
			NavNative *shared = Object::cast_to<NavNative>((Object *)d["nav"]);
			if (shared != nullptr) {
				w.nav_index = Ref<NavNative>(shared); // the game's one index (NativeBridge.nav): no second build
			}
		}
	}
}

// ============================================================ the search ===========================================

// Planner._at_goal
bool PlannerNative::at_goal(double x, double z, double th, int64_t gear) {
	const double dx = x - req.goal_x;
	const double dz = z - req.goal_z;
	const double d2 = dx * dx + dz * dz;
	if (d2 <= req.tol_m * req.tol_m) {
		if (req.arrive_gear != 0 && gear != req.arrive_gear) {
			return false;
		}
		return absd(wrap(th - search.goal_theta)) <= search.tol_rad;
	}
	if (!req.aim) {
		return false;
	}
	// AIM (Planner._at_goal, round 31): pointing at the goal within the tolerance with a clear straight run to it.
	if (absd(wrap(th - std::atan2(-dz, -dx))) > search.tol_rad) {
		return false;
	}
	return straight_clear(x, z, std::cos(th), std::sin(th), std::sqrt(d2));
}

// Planner._straight_clear
bool PlannerNative::straight_clear(double x, double z, double fx, double fz, double dist) {
	const Search &s = search;
	double swept = 0.0;
	while (swept < dist - 0.001) {
		swept += SUB_M;
		if (world.footprint(x + fx * swept, z + fz * swept, fx, fz, s.half_w, s.half_l, MARGIN_M, s.start_offs) < 0.0) {
			return false;
		}
	}
	return true;
}

// Planner._heuristic
double PlannerNative::heuristic(double x, double z, double th, int64_t gear) const {
	const Search &s = search;
	const double dx = x - req.goal_x;
	const double dz = z - req.goal_z;
	const double d = std::sqrt(dx * dx + dz * dz);
	const double turn = absd(wrap(th - s.goal_theta));
	double h = maxd(d, s.radius * turn) / maxd(req.v_fwd, 0.1);
	const double along = dx * s.gfx + dz * s.gfz;
	const double across = -dx * s.gfz + dz * s.gfx;
	const double tabled = table_lookup(*s.table, along, across, th - s.goal_theta, gear, s.cusp_s);
	if (tabled < INF && tabled > h) {
		h = tabled;
	}
	if (turn > 0.3 && s.swing < PI_D) {
		const double legs = std::ceil(turn / s.swing);
		if (legs > 1.0) {
			h = maxd(h, maxd(d, s.radius * turn) / maxd(req.v_fwd, 0.1) + s.cusp_s * (legs - 1.0));
		}
	}
	return h;
}

// Planner._roll_clear
bool PlannerNative::roll_clear(double x, double z, double fx, double fz, int64_t gear, double steer) {
	if (gear == 0) {
		return true;
	}
	const Search &s = search;
	double mx = fx;
	double mz = fz;
	if (steer != 0.0) {
		const double dth = ROLL_SLACK_M * steer / s.radius;
		const double dth_t = tan_series(dth);
		const double tx = fx - fz * dth_t;
		const double tz = fz + fx * dth_t;
		const double inv = 1.0 / std::sqrt(tx * tx + tz * tz);
		fx = tx * inv;
		fz = tz * inv;
		const double lagged = tan_series(-dth * 0.5 - steer * (gear > 0 ? s.lag_fwd : s.lag_rev) * 0.5);
		const double lx = fx - fz * lagged;
		const double lz = fz + fx * lagged;
		const double linv = 1.0 / std::sqrt(lx * lx + lz * lz);
		mx = lx * linv;
		mz = lz * linv;
	}
	x += mx * ROLL_SLACK_M * (double)gear;
	z += mz * ROLL_SLACK_M * (double)gear;
	return world.footprint(x, z, fx, fz, req.half_w, req.half_l, MARGIN_M, s.start_offs) >= 0.0;
}

// Planner._search, from its top to the first pop. False: the answer is already in search.code (no loop to run).
bool PlannerNative::start_search(double cell_m, int64_t bins) {
	search = Search();
	Search &s = search;
	s.cell_m = cell_m;
	s.bins = bins;
	s.half_w = req.half_w;
	s.half_l = req.half_l;
	s.radius = maxd(req.radius, 0.5);
	world.prepare(req.start_x, req.start_z, req.horizon_m + s.half_l + 2.0);
	world.side_clearances(req.start_x, req.start_z, req.start_fx, req.start_fz, s.half_w, s.half_l, MARGIN_M, s.start_offs);
	const float strict[4] = { INF_F, INF_F, INF_F, INF_F };
	s.lag_fwd = req.v_fwd * req.tick_s / s.radius;
	s.lag_rev = req.v_rev * req.tick_s / s.radius;
	s.radius_fwd = effective_radius(s.radius, req.v_fwd, req.tick_s);
	s.radius_rev = effective_radius(s.radius, req.v_rev, req.tick_s);
	s.theta0 = std::atan2(req.start_fz, req.start_fx);
	s.goal_theta = std::atan2(req.goal_fz, req.goal_fx);
	s.tol_rad = deg_to_rad(req.tol_deg);
	if (world.hull_overlap(req.start_x, req.start_z, req.start_fx, req.start_fz, s.half_w, s.half_l, 0.0)) {
		s.code = START_BLOCKED;
		s.finished = true;
		return false;
	}
	if (world.footprint(req.goal_x, req.goal_z, req.goal_fx, req.goal_fz, s.half_w, s.half_l, MARGIN_M, strict) < 0.0) {
		s.code = GOAL_BLOCKED;
		s.finished = true;
		return false;
	}
	if (at_goal(req.start_x, req.start_z, s.theta0, 0)) {
		s.code = ALREADY_THERE;
		s.finished = true;
		return false;
	}
	s.nx.push_back((float)req.start_x);
	s.nz.push_back((float)req.start_z);
	s.nfx.push_back((float)req.start_fx);
	s.nfz.push_back((float)req.start_fz);
	s.nth.push_back((float)s.theta0);
	s.ng.push_back(0.0f);
	s.nparent.push_back(-1);
	s.ngear.push_back(0);
	s.nsteer.push_back(0.0f);
	s.nlen.push_back(0.0f);
	s.cusp_s = req.cusp_s;
	s.epsilon = req.epsilon > 0.0 ? req.epsilon : EPSILON;
	s.table = &table_for(req);
	s.gfx = req.goal_fx;
	s.gfz = req.goal_fz;
	s.room = world.clearance(req.start_x, req.start_z);
	s.swing = swing_per_leg(s.room, s.radius, s.half_l, s.half_w);
	heap_push(s.heap_f, s.heap_id, s.epsilon * heuristic(req.start_x, req.start_z, s.theta0, 0), 0);
	s.best_g[key_of(req.start_x, req.start_z, s.theta0, 0, cell_m, bins)] = 0.0;
	s.v_fwd = maxd(req.v_fwd, 0.1);
	s.v_rev = maxd(req.v_rev, 0.1);
	s.horizon2 = req.horizon_m * req.horizon_m;
	s.expansions = 0;
	s.goal_id = -1;
	s.best_cost = INF;
	s.first_at = 0;
	return true;
}

// Planner._search's loop. Pauses only at the top of an iteration (after `slice` expansions), so a sliced run and a
// whole run take the same steps in the same order.
bool PlannerNative::run_search(int64_t slice) {
	Search &s = search;
	const int64_t gears[2] = { 1, -1 };
	int64_t done_here = 0;
	while (!s.heap_f.empty()) {
		if (done_here >= slice) {
			return false;
		}
		const double heap_f_last = (double)s.heap_f[0];
		const int32_t cur = heap_pop(s.heap_f, s.heap_id);
		if (s.goal_id >= 0) {
			const double bound = (double)s.ng[cur] + (heap_f_last - (double)s.ng[cur]) / s.epsilon;
			if (bound >= s.best_cost) {
				break;
			}
		}
		const int64_t ckey = key_of((double)s.nx[cur], (double)s.nz[cur], (double)s.nth[cur], s.ngear[cur], s.cell_m, s.bins);
		if (s.closed.count(ckey)) {
			continue;
		}
		s.closed.insert(ckey);
		if (s.expansions >= req.budget) {
			if (s.goal_id < 0) {
				s.code = BUDGET;
			}
			break;
		}
		s.expansions += 1;
		done_here += 1;
		if (at_goal((double)s.nx[cur], (double)s.nz[cur], (double)s.nth[cur], s.ngear[cur])) {
			if (roll_clear((double)s.nx[cur], (double)s.nz[cur], (double)s.nfx[cur], (double)s.nfz[cur], s.ngear[cur], (double)s.nsteer[cur])) {
				if ((double)s.ng[cur] < s.best_cost) {
					s.best_cost = (double)s.ng[cur];
					s.goal_id = cur;
					if (s.first_at == 0) {
						s.first_at = s.expansions;
					}
				}
			}
			continue;
		}
		const double px = (double)s.nx[cur];
		const double pz = (double)s.nz[cur];
		const double pfx = (double)s.nfx[cur];
		const double pfz = (double)s.nfz[cur];
		const double pth = (double)s.nth[cur];
		const double pg = (double)s.ng[cur];
		const int64_t pgear = s.ngear[cur];
		const double psteer = (double)s.nsteer[cur];
		for (int64_t gear : gears) {
			const bool cusp = pgear != 0 && gear != pgear;
			if (cusp) {
				auto known = s.roll_ok.find(cur);
				bool ok;
				if (known == s.roll_ok.end()) {
					ok = roll_clear(px, pz, pfx, pfz, pgear, psteer);
					s.roll_ok[cur] = ok;
				} else {
					ok = known->second;
				}
				if (!ok) {
					continue;
				}
			}
			const double v = gear > 0 ? s.v_fwd : s.v_rev;
			const double lag = gear > 0 ? s.lag_fwd : s.lag_rev;
			const double r_gear = gear > 0 ? s.radius_fwd : s.radius_rev;
			for (double steer : STEERS) {
				double x = px;
				double z = pz;
				double fx = pfx;
				double fz = pfz;
				double th = pth;
				const double dth = SUB_M * steer / r_gear;
				const double dth_t = tan_series(dth);
				const double lagged = tan_series(-dth * 0.5 - steer * lag * 0.5);
				double swept = 0.0;
				double band = 0.0;
				int64_t next_end = 0;
				double g_leg = pg;
				if (cusp) {
					g_leg += s.cusp_s;
				} else if (pgear != 0 && steer != psteer) {
					g_leg += STEER_CHANGE_S;
				}
				while (swept < LEG_MAX_M - 0.001) {
					double mx = fx;
					double mz = fz;
					if (steer != 0.0) {
						const double tx = fx - fz * dth_t;
						const double tz = fz + fx * dth_t;
						const double inv = 1.0 / std::sqrt(tx * tx + tz * tz);
						fx = tx * inv;
						fz = tz * inv;
						th += dth;
						const double lx = fx - fz * lagged;
						const double lz = fz + fx * lagged;
						const double linv = 1.0 / std::sqrt(lx * lx + lz * lz);
						mx = lx * linv;
						mz = lz * linv;
					}
					x += mx * SUB_M * (double)gear;
					z += mz * SUB_M * (double)gear;
					swept += SUB_M;
					const double c = world.footprint(x, z, fx, fz, s.half_w, s.half_l, MARGIN_M, s.start_offs);
					if (c < 0.0) {
						break;
					}
					if (c < BAND_M) {
						band += BAND_S_PER_M * (BAND_M - c) * SUB_M;
					}
					const double ddx = x - req.start_x;
					const double ddz = z - req.start_z;
					if (ddx * ddx + ddz * ddz > s.horizon2) {
						break;
					}
					const bool at_end = next_end < LEG_ENDS_N && swept >= LEG_ENDS_M[next_end] - 0.001;
					if (at_end) {
						next_end += 1;
					}
					if (!at_end && (swept < 1.0 - 0.001 || !at_goal(x, z, th, gear))) {
						continue;
					}
					const double g = g_leg + swept / v + band;
					const int64_t key = key_of(x, z, th, gear, s.cell_m, s.bins);
					if (s.closed.count(key)) {
						continue;
					}
					auto known = s.best_g.find(key);
					if (known != s.best_g.end() && known->second <= g) {
						continue;
					}
					s.best_g[key] = g;
					const int32_t id = (int32_t)s.nx.size();
					s.nx.push_back((float)x);
					s.nz.push_back((float)z);
					s.nfx.push_back((float)fx);
					s.nfz.push_back((float)fz);
					s.nth.push_back((float)th);
					s.ng.push_back((float)g);
					s.nparent.push_back(cur);
					s.ngear.push_back((int32_t)gear);
					s.nsteer.push_back((float)steer);
					s.nlen.push_back((float)swept);
					heap_push(s.heap_f, s.heap_id, g + s.epsilon * heuristic(x, z, th, gear), id);
				}
			}
		}
	}
	finish_search();
	return true;
}

// Planner._search after its loop: the code, and the path merged into legs.
void PlannerNative::finish_search() {
	Search &s = search;
	s.finished = true;
	if (s.goal_id < 0) {
		if (s.code != BUDGET) {
			s.code = NO_PATH;
		}
		return;
	}
	s.code = OK;
}

// ============================================================ the session ==========================================

bool PlannerNative::begin(const Dictionary &request) {
	req = parse_request(request);
	parse_world(request.get("world", Dictionary()), world);
	session_live = true;
	phase = 0;
	coarse_expansions = -1;
	out_code = NONE;
	out_legs = Array();
	out_cost = 0.0;
	out_expansions = 0;
	out_first_at = 0;
	start_search(CELL_M, HEADING_BINS);
	return true;
}

// Planner.plan's two searches, `slice` expansions at a time; true when the plan is final.
bool PlannerNative::step(int64_t slice) {
	if (!session_live) {
		return true;
	}
	if (slice < 1) {
		slice = 1; // a zero slice would never finish (native's note 1)
	}
	while (true) {
		if (!search.finished) {
			if (!run_search(slice)) {
				return false;
			}
		}
		// This search is finished: its code is final, or the fine retry begins.
		last_expansions = search.expansions;
		last_nodes = (int64_t)search.nx.size();
		if (phase == 0 && (search.code == NO_PATH || search.code == BUDGET) && req.fine_retry) {
			coarse_expansions = search.expansions;
			phase = 1;
			start_search(FINE_CELL_M, FINE_BINS);
			continue;
		}
		break;
	}
	Search &s = search;
	out_code = s.code;
	out_cell_m = s.cell_m;
	out_bins = s.bins;
	out_expansions = s.expansions + (coarse_expansions >= 0 ? coarse_expansions : 0);
	out_first_at = s.first_at;
	out_legs = Array();
	out_cost = 0.0;
	if (s.code == OK) {
		std::vector<int32_t> chain;
		int32_t at = (int32_t)s.goal_id;
		while (at > 0) {
			chain.push_back(at);
			at = s.nparent[at];
		}
		// legs: Array[Vector3] (float32 components); `legs[-1].z += nlen[id]` is a float32 += float32
		std::vector<Vector3> legs;
		for (auto it = chain.rbegin(); it != chain.rend(); ++it) {
			const int32_t id = *it;
			const int64_t gear = s.ngear[id];
			const float steer = s.nsteer[id];
			if (!legs.empty() && (int64_t)legs.back().x == gear && legs.back().y == steer) {
				legs.back().z = (float)((double)legs.back().z + (double)s.nlen[id]);
			} else {
				legs.push_back(Vector3((real_t)(double)gear, steer, s.nlen[id]));
			}
		}
		for (const Vector3 &leg : legs) {
			out_legs.push_back(leg);
		}
		out_cost = (double)s.ng[s.goal_id];
	}
	session_live = false;
	return true;
}

void PlannerNative::cancel() {
	session_live = false;
	search = Search();
	out_code = NONE;
	out_legs = Array();
}

Dictionary PlannerNative::result() const {
	Dictionary d;
	d["code"] = String(code_name(out_code));
	d["legs"] = out_legs;
	d["cost_s"] = out_cost;
	d["expansions"] = out_expansions;
	d["last_expansions"] = last_expansions;
	d["nodes"] = last_nodes;
	d["first_at"] = out_first_at;
	d["coarse_expansions"] = coarse_expansions;
	d["cell_m"] = out_cell_m;
	d["bins"] = out_bins;
	d["budget"] = req.budget;
	d["horizon_m"] = req.horizon_m;
	d["wall_reads"] = (int64_t)world.wall_reads;
	return d;
}

Dictionary PlannerNative::plan(const Dictionary &request) {
	// A whole plan on an instance whose sliced session is live would clobber that session (native's note 1): the
	// GDScript keeps whole plans and sessions on separate instances; this guard says so if a caller does not.
	if (session_live) {
		Dictionary refused;
		refused["code"] = String("NONE");
		refused["why"] = String("a sliced session is live on this instance");
		refused["legs"] = Array();
		refused["cost_s"] = 0.0;
		refused["expansions"] = (int64_t)0;
		refused["last_expansions"] = (int64_t)0;
		refused["nodes"] = (int64_t)0;
		refused["first_at"] = (int64_t)0;
		refused["coarse_expansions"] = (int64_t)-1;
		refused["cell_m"] = 0.0;
		refused["bins"] = (int64_t)0;
		refused["budget"] = (int64_t)0;
		refused["horizon_m"] = 0.0;
		refused["wall_reads"] = (int64_t)0;
		return refused;
	}
	begin(request);
	step(std::numeric_limits<int64_t>::max());
	return result();
}

PackedFloat32Array PlannerNative::table(const Dictionary &request) {
	const Request r = parse_request(request);
	const std::vector<float> &t = table_for(r);
	PackedFloat32Array out;
	out.resize((int64_t)t.size());
	for (size_t i = 0; i < t.size(); i++) {
		out[(int64_t)i] = t[i];
	}
	return out;
}

Dictionary PlannerNative::nav_cache_stats() const {
	Dictionary d;
	d["chunks"] = (int64_t)World::nav_cache.chunks.size();
	d["cells"] = (int64_t)(World::nav_cache.chunks.size() * (size_t)(World::CHUNK * World::CHUNK));
	d["hits"] = (int64_t)World::nav_cache.hits;
	d["misses"] = (int64_t)World::nav_cache.misses;
	d["bake_radius"] = World::nav_cache.bake_radius;
	return d;
}

void PlannerNative::nav_cache_clear() {
	World::nav_cache.chunks.clear();
	World::nav_cache.map_id = 0;
	World::nav_cache.iteration = 0;
	World::nav_cache.bake_radius = -1.0;
	World::nav_cache.hits = World::nav_cache.misses = 0;
}

Dictionary PlannerNative::debug_field() const {
	Dictionary d;
	PackedFloat32Array cells;
	cells.resize((int64_t)world.field.size());
	for (size_t i = 0; i < world.field.size(); i++) {
		cells[(int64_t)i] = world.field[i];
	}
	d["field"] = cells;
	d["x0"] = world.field_x0;
	d["z0"] = world.field_z0;
	d["n"] = world.field_n;
	d["spill"] = (int64_t)world.spill.size(); // a navmesh world's spill is the shared cache: not counted
	d["shared"] = world.nav;
	return d;
}

void PlannerNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("plan", "request"), &PlannerNative::plan);
	ClassDB::bind_method(D_METHOD("begin", "request"), &PlannerNative::begin);
	ClassDB::bind_method(D_METHOD("step", "expansions"), &PlannerNative::step);
	ClassDB::bind_method(D_METHOD("result"), &PlannerNative::result);
	ClassDB::bind_method(D_METHOD("live"), &PlannerNative::live);
	ClassDB::bind_method(D_METHOD("cancel"), &PlannerNative::cancel);
	ClassDB::bind_method(D_METHOD("table", "request"), &PlannerNative::table);
	ClassDB::bind_method(D_METHOD("table_build_usec"), &PlannerNative::table_build_usec);
	ClassDB::bind_method(D_METHOD("tables_count"), &PlannerNative::tables_count);
	ClassDB::bind_method(D_METHOD("wall_reads"), &PlannerNative::wall_reads);
	ClassDB::bind_method(D_METHOD("debug_field"), &PlannerNative::debug_field);
	ClassDB::bind_method(D_METHOD("nav_cache_stats"), &PlannerNative::nav_cache_stats);
	ClassDB::bind_method(D_METHOD("nav_cache_clear"), &PlannerNative::nav_cache_clear);
}

} // namespace godot
