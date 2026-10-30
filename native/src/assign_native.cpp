// Round 45 (native, R45.16): SelectionSquads._assign's search natively (assign_native.h).
#include "assign_native.h"

#include <cmath>
#include <vector>

namespace godot {

namespace {

struct Search {
	int n = 0;
	std::vector<double> cost; // [i * n + j]
	std::vector<int> current;
	std::vector<bool> used;
	double best_total = INFINITY;
	std::vector<int> best;

	// _search(cost, current, used, total, best_total, best)
	void run(double total) {
		if (total >= best_total - 1e-6) {
			return;
		}
		if ((int)current.size() == n) {
			best_total = total;
			best = current;
			return;
		}
		const int i = (int)current.size();
		for (int j = 0; j < n; j++) {
			if (used[j]) {
				continue;
			}
			used[j] = true;
			current.push_back(j);
			run(total + cost[i * n + j]);
			current.pop_back();
			used[j] = false;
		}
	}
};

} // namespace

PackedInt32Array assign_least_total(const PackedVector3Array &centers, const PackedVector3Array &slots) {
	Search s;
	s.n = (int)centers.size();
	s.cost.resize((size_t)s.n * s.n);
	for (int i = 0; i < s.n; i++) {
		for (int j = 0; j < s.n; j++) {
			s.cost[i * s.n + j] = (double)centers[i].distance_to(slots[j]); // GDScript: a float from a real_t distance
		}
	}
	s.used.assign(s.n, false);
	s.run(0.0);
	PackedInt32Array out;
	for (const int j : s.best) {
		out.push_back(j);
	}
	return out;
}

} // namespace godot
