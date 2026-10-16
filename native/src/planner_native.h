// PlannerNative (round 31, stream planner, CP-P0): the lattice planner of game/ai/planner/ in C++, the SAME BITS as the
// GDScript (_agents/native.md "The proof"): Planner._search (the hybrid-A* over whole legs), PlannerWorld (the lazy
// float32 clearance field, the sphere walk along each hull side, the OBB squadmate test), PlannerNavWorld (the navmesh
// at the bake radius) and PlannerHeuristic._build (the free-space table). Every width is the GDScript's: the node
// columns, the heap and the field are PackedFloat32Arrays there (float here), every sweep and distance a GDScript
// `float` (double here), Vector2 math in real_t where the GDScript spells a Vector2. tests/test_native_planner.gd holds
// every fixture to the GDScript plan: legs, code, cost, expansions, nodes, the table bit for bit.
//
// The search is a SESSION (P6, the per-tick slice): `begin(req)` builds it, `step(n)` runs at most n expansions and
// says whether it is done, `result()` is the plan. `plan(req)` is begin + step(everything) + result, so a sliced plan
// is the whole plan by construction: the loop only ever pauses at the top of an iteration, where no local lives.
// Nothing here reads the clock; a budget is a count of expansions (orientation trip-up 28).
#pragma once

#include "nav_native.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/rid.hpp>

#include <cstdint>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace godot {

class PlannerNative : public RefCounted {
	GDCLASS(PlannerNative, RefCounted)

public:
	// ---- PlannerWorld / PlannerNavWorld ----
	struct Wall {
		double cx, cz, half_along, half_across, fx, fz;
	};
	struct Hull {
		double cx, cz, fx, fz, half_w, half_l;
	};
	struct World {
		static constexpr double CELL_M = 0.5;
		static constexpr double SAMPLE_SLACK_M = 0.15;
		static constexpr double HULL_MARGIN_M = 0.5;
		static constexpr double FAR_M = 50.0;
		static constexpr double UNSET = -1.0e30;
		static constexpr double UNSET_BELOW = -1.0e29;

		std::vector<Wall> walls;
		std::vector<Hull> hulls;
		bool nav = false; // PlannerNavWorld: the navmesh instead of the rectangles
		RID map;
		// The navmesh's closest point through NavNative's polygon index (round 23 N2a: the engine's own per-polygon
		// code over a grid, equal bit for bit, tests/test_native_navmesh.gd): the game's own index (NativeBridge.nav,
		// handed in through the world's view as "nav") when there is one, else this instance's; the GDScript world asks
		// the engine directly and the twin test holds the two to the same plan. A cell read on the engine's
		// linear scan cost ~4 ms an expansion on the Terminus (builder0, 0c2d30c4); the index is the fix.
		// Held PER INSTANCE (a C++ static Ref outlives the engine's ObjectDB and segfaults at exit: builder0, ad1d1f3d).
		Ref<NavNative> nav_index;
		Ref<NavNative> &index();
		double bake_radius = 2.0;
		std::vector<float> field; // the lazy window (UNSET until read), cx * n + cz
		int64_t field_x0 = 0, field_z0 = 0, field_n = 0;
		std::unordered_map<int64_t, float> spill;
		uint64_t wall_reads = 0; // measurement: _wall_distance calls (navmesh queries in play)
		// Round 31 (P6): a NAVMESH's cells outlive one search. The walls do not move within a map's iteration, so a
		// cell's clearance is one float32 for the whole match: computed once by whichever plan first reads it, read by
		// every plan and every instance after (the cold-start cost of a plan -- ~1 ms an expansion on the Terminus at
		// a3755e37 against ~50 us warm -- is paid once per cell per match, not once per plan). Keyed by the map, its
		// iteration id and the bake radius; dropped when any of them moves. Chunks of CHUNK x CHUNK cells. Plain data
		// (no godot Ref, no godot builtin: a static RID's constructor calls a binding not yet set when the library's
		// statics are built at load -- builder0 segfaulted at --import on d373af4e) so a static is safe. The rectangle
		// worlds of the tests keep the per-search window.
		static constexpr int64_t CHUNK = 64;
		struct NavCache {
			uint64_t map_id = 0; // RID::get_id()
			uint64_t iteration = 0;
			double bake_radius = -1.0;
			std::unordered_map<int64_t, std::vector<float>> chunks;
			uint64_t hits = 0, misses = 0;
		};
		// ASSUMPTION (native's review of d373af4e, note 1): the iteration id is checked at a SEARCH'S START (prepare),
		// not every slice; a sliced session that spans a rebake keeps reading pre-bake cells. No arena rebakes in play
		// today; the GDScript twin's own window would be as stale within one search.
		static NavCache nav_cache;
		float cached_cell(int64_t ix, int64_t iz);

		void prepare(double cx, double cz, double half);
		double wall_distance(double x, double z);
		double cell(int64_t ix, int64_t iz);
		double clearance(double x, double z);
		double walk(double ax, double az, double bx, double bz, double margin);
		void side_clearances(double x, double z, double fx, double fz, double half_w, double half_l, double margin, float out[4]);
		double footprint(double x, double z, double fx, double fz, double half_w, double half_l, double margin, const float start[4]);
		bool hull_overlap(double x, double z, double fx, double fz, double half_w, double half_l, double grow) const;
	};

	// ---- PlanRequest, the fields the search reads ----
	struct Request {
		double start_x = 0, start_z = 0, start_fx = 0, start_fz = -1;
		double goal_x = 0, goal_z = 0, goal_fx = 0, goal_fz = -1;
		double tol_m = 1, tol_deg = 8;
		int64_t arrive_gear = 0;
		bool aim = false; // PlanRequest.aim: pointing at the goal with a clear straight run counts (the k-turn's goal)
		// PlanRequest.keep (round 31, the face's slot law): every pose within keep_all_m of (keep_x, keep_z), the goal
		// pose within keep_end_m; KEEP_NONE (the GDScript's INF arrives as inf, which is >= KEEP_NONE) = no circle.
		double keep_x = 0, keep_z = 0, keep_all_m = 1e30, keep_end_m = 1e30;
		double half_w = 1, half_l = 2, radius = 6, v_fwd = 6, v_rev = 2.5;
		double cusp_s = 0; // PlanRequest.cusp_seconds(), computed by the GDScript
		int64_t budget = 1500;
		double horizon_m = 30, epsilon = 0;
		bool fine_retry = true;
		double tick_s = 1.0 / 30.0; // SimClock.TICK_SECONDS, handed over
	};

	enum Code { OK, NO_PATH, BUDGET, START_BLOCKED, GOAL_BLOCKED, ALREADY_THERE, NONE };

	// ---- one Planner._search, resumable ----
	struct Search {
		// the request's derived constants
		double cell_m = 1, radius = 6, half_w = 1, half_l = 2;
		int64_t bins = 24;
		float start_offs[4] = { 0, 0, 0, 0 };
		double lag_fwd = 0, lag_rev = 0, radius_fwd = 6, radius_rev = 6, theta0 = 0, goal_theta = 0, tol_rad = 0;
		double cusp_s = 0, epsilon = 1.5, gfx = 0, gfz = 0, room = 0, swing = 0, v_fwd = 6, v_rev = 2.5, horizon2 = 900;
		const std::vector<float> *table = nullptr;
		// the node columns (float32, as the PackedFloat32Arrays)
		std::vector<float> nx, nz, nfx, nfz, nth, ng, nsteer, nlen;
		std::vector<int32_t> nparent, ngear;
		std::vector<float> heap_f;
		std::vector<int32_t> heap_id;
		std::unordered_set<int64_t> closed;
		std::unordered_map<int64_t, double> best_g;
		std::unordered_map<int32_t, bool> roll_ok;
		int64_t expansions = 0, goal_id = -1, first_at = 0;
		double best_cost = 0;
		Code code = NONE;
		bool finished = false;
	};

private:
	// The free-space tables, ONE cache for every instance (native's review of 7c286000, note 1: a seam's session
	// instance and the whole-plan instance must not each build the catalog's tables); single-threaded, like the engine.
	static std::unordered_map<std::string, std::vector<float>> tables;
	static int64_t last_table_build_usec;
	static uint64_t tables_built;

	// the session
	bool session_live = false;
	Request req;
	World world;
	Search search;
	int phase = 0; // 0 coarse, 1 fine
	int64_t coarse_expansions = -1;
	int64_t last_expansions = 0, last_nodes = 0;
	// the finished plan
	Code out_code = NONE;
	Array out_legs;
	double out_cost = 0;
	int64_t out_expansions = 0, out_first_at = 0;
	double out_cell_m = 1;
	int64_t out_bins = 24;

	static const std::vector<float> &table_for(const Request &r);
	static std::vector<float> build_table(double radius, double v_fwd, double v_rev, double cusp_s);
	static Request parse_request(const Dictionary &d);
	static void parse_world(const Dictionary &d, World &w);
	// Planner._search up to its first pop (the blocked / already-there answers); false when the search need not run.
	bool start_search(double cell_m, int64_t bins);
	// The loop: at most `slice` expansions; true when this search is finished (search.code holds its answer).
	bool run_search(int64_t slice);
	void finish_search();
	bool at_goal(double x, double z, double th, int64_t gear);
	bool straight_clear(double x, double z, double fx, double fz, double dist);
	double heuristic(double x, double z, double th, int64_t gear) const;
	bool roll_clear(double x, double z, double fx, double fz, int64_t gear, double steer);

protected:
	static void _bind_methods();

public:
	// Planner.plan(req): the whole plan in one call (begin + every expansion + result).
	Dictionary plan(const Dictionary &request);
	// The slice: begin, then step(n) until it says done, then result().
	bool begin(const Dictionary &request);
	bool step(int64_t expansions);
	Dictionary result() const;
	bool live() const { return session_live; }
	// Drop a live session (a crew died, its order changed): nothing is kept.
	void cancel();
	// PlannerHeuristic.table_for(req) bit for bit (the cache key is the GDScript's "%.2f|%.2f|%.2f|%.2f").
	PackedFloat32Array table(const Dictionary &request);
	int64_t table_build_usec() const { return last_table_build_usec; }
	int64_t tables_count() const { return (int64_t)tables_built; }
	int64_t wall_reads() const { return (int64_t)world.wall_reads; }
	// The shared navmesh cache: cells held, hits and misses since the map's iteration (measurement).
	Dictionary nav_cache_stats() const;
	// Drop the shared cache (measurement: a cold-start price in a process that has planned before; note 2).
	void nav_cache_clear();
	// The last session's lazy field as the GDScript world holds it after its plan (`_field`, `_field_x0`, `_field_z0`,
	// `_field_n`, the spill's size): the twin test compares the cells bit for bit.
	Dictionary debug_field() const;
};

} // namespace godot
