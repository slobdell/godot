// Round 45 (native N2b): SelectionSquads.untangle_whole's search natively (untangle_native.h).
#include "untangle_native.h"

#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>
#include <map>
#include <vector>

namespace godot {

namespace {

using Perm = std::vector<int>;

// _build_permutations(n): the identity first; each n-1 ordering with n-1 inserted at rest.size() down to 0
std::vector<Perm> build_permutations(int n) {
	if (n <= 1) {
		return n == 1 ? std::vector<Perm>{ Perm{ 0 } } : std::vector<Perm>{ Perm{} };
	}
	std::vector<Perm> result;
	for (const Perm &rest : build_permutations(n - 1)) {
		for (int k = (int)rest.size(); k >= 0; k--) {
			Perm perm = rest;
			perm.insert(perm.begin() + k, n - 1);
			result.push_back(perm);
		}
	}
	return result;
}

const std::vector<Perm> &permutations(int n) {
	static std::map<int, std::vector<Perm>> memo;
	auto found = memo.find(n);
	if (found == memo.end()) {
		found = memo.emplace(n, build_permutations(n)).first;
	}
	return found->second;
}

int root_of(const std::vector<int> &family, int i) {
	while (family[i] != i) {
		i = family[i];
	}
	return i;
}

Vector2 xz(const Vector3 &p) {
	return Vector2(p.x, p.z);
}

// _pair_crosses: crossing pairs between two squads' crews, each straight from its start to its squad's place
int pair_crosses(const std::vector<Vector2> &a_starts, const Vector2 &at_a, const std::vector<Vector2> &b_starts,
		const Vector2 &at_b) {
	Geometry2D *geometry = Geometry2D::get_singleton();
	int count = 0;
	for (const Vector2 &a : a_starts) {
		for (const Vector2 &b : b_starts) {
			if (geometry->segment_intersects_segment(a, at_a, b, at_b).get_type() != Variant::NIL) {
				count += 1;
			}
		}
	}
	return count;
}

} // namespace

Dictionary untangle_whole(const Array &start_array, const Array &anchor_array, bool by_lead, const PackedFloat64Array &leads,
		const PackedFloat64Array &arcs, const PackedByteArray &misplaced, double slack) {
	const int n = (int)start_array.size();
	std::vector<std::vector<Vector2>> starts(n);
	std::vector<Vector3> anchors(n);
	for (int i = 0; i < n; i++) {
		const Array crews = start_array[i];
		for (int64_t c = 0; c < crews.size(); c++) {
			starts[i].push_back(crews[c]);
		}
		anchors[i] = anchor_array[i];
	}
	const bool has_misplaced = misplaced.size() == (int64_t)n * n;
	std::vector<int> family(n);
	for (int i = 0; i < n; i++) {
		family[i] = i;
	}
	for (int i = 0; i < n; i++) {
		for (int j = i + 1; j < n; j++) {
			if (root_of(family, i) != root_of(family, j) &&
					(by_lead || pair_crosses(starts[i], xz(anchors[i]), starts[j], xz(anchors[j])) > 0)) {
				family[root_of(family, i)] = root_of(family, j);
			}
		}
	}
	// groups: a Dictionary root -> members, in the order each root is first seen
	std::vector<int> roots;
	std::map<int, std::vector<int>> groups;
	for (int i = 0; i < n; i++) {
		const int root = root_of(family, i);
		if (groups.find(root) == groups.end()) {
			roots.push_back(root);
		}
		groups[root].push_back(i);
	}
	int moved = 0;
	int still_crossed = 0;
	std::vector<Vector3> out = anchors;
	for (const int root : roots) {
		const std::vector<int> &members = groups[root];
		const int m = (int)members.size();
		if (m < 2) {
			continue;
		}
		std::vector<Vector3> places(m);
		std::vector<double> place_arcs, member_leads;
		for (int a = 0; a < m; a++) {
			places[a] = anchors[members[a]];
			if (by_lead) {
				place_arcs.push_back(arcs[members[a]]);
				member_leads.push_back(leads[members[a]]);
			}
		}
		Perm best;
		double best_key[3] = { INFINITY, INFINITY, INFINITY };
		double best_wrong = INFINITY;
		std::vector<int> crossed((size_t)m * m * m * m, -1);
		std::vector<std::vector<double>> drives((size_t)m * m);
		for (int a = 0; a < m; a++) {
			for (int q = 0; q < m; q++) {
				for (const Vector2 &s : starts[members[a]]) {
					drives[a * m + q].push_back((double)s.distance_to(xz(places[q])));
				}
			}
		}
		std::vector<double> perm_arcs(m);
		for (const Perm &perm : permutations(m)) {
			int wrong = 0;
			if (has_misplaced) {
				for (int a = 0; a < m; a++) {
					// misplaced(members[a], places[perm[a]]): places[q] is anchors[members[q]]
					if (misplaced[(int64_t)members[a] * n + members[perm[a]]] != 0) {
						wrong += 1;
					}
				}
				if (wrong > best_wrong) {
					continue;
				}
			}
			int breaks = 0;
			if (by_lead) {
				for (int a = 0; a < m; a++) {
					perm_arcs[a] = place_arcs[perm[a]];
				}
				// lead_breaks(member_leads, arcs)
				for (int a = 0; a < m; a++) {
					for (int b = 0; b < m; b++) {
						if (member_leads[a] < member_leads[b] - slack && perm_arcs[a] > perm_arcs[b] + slack) {
							breaks += 1;
						}
					}
				}
				if (wrong == best_wrong && breaks > best_key[0]) {
					continue;
				}
			}
			const double bound = (wrong < best_wrong || breaks < best_key[0]) ? INFINITY : best_key[1];
			int crossings = 0;
			for (int a = 0; a < m; a++) {
				const int pa = perm[a];
				for (int b = a + 1; b < m; b++) {
					const int key = ((a * m + pa) * m + b) * m + perm[b];
					if (crossed[key] < 0) {
						crossed[key] = pair_crosses(starts[members[a]], xz(places[pa]), starts[members[b]], xz(places[perm[b]]));
					}
					crossings += crossed[key];
				}
				if (crossings > bound) {
					break;
				}
			}
			if (crossings > bound) {
				continue;
			}
			double drive = 0.0;
			for (int a = 0; a < m; a++) {
				for (const double d : drives[a * m + perm[a]]) {
					drive += d;
				}
			}
			if (wrong < best_wrong || breaks < best_key[0] ||
					(breaks == best_key[0] && (crossings < best_key[1] || (crossings == best_key[1] && drive < best_key[2] - 0.01)))) {
				best_wrong = wrong;
				best_key[0] = breaks;
				best_key[1] = crossings;
				best_key[2] = drive;
				best = perm;
			}
		}
		if (best_key[1] > 0) {
			still_crossed += 1;
		}
		for (int a = 0; a < m; a++) {
			if (best[a] != a) {
				moved += 1;
			}
			out[members[a]] = places[best[a]];
		}
	}
	Array result_anchors;
	for (int i = 0; i < n; i++) {
		result_anchors.push_back(out[i]);
	}
	Dictionary result;
	result["anchors"] = result_anchors;
	result["moved"] = moved;
	result["still_crossed"] = still_crossed;
	return result;
}

} // namespace godot
