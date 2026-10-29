// Round 45 (native N2): RtsControls.gate_width with crosses_or_edge(crosses_on) and drive_on, natively (gate_width_native.h).
#include "gate_width_native.h"

#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>
#include <vector>

namespace godot {

namespace {

struct Box {
	double x0, z0, x1, z1;
};

// SlotGround.near_deck(point, 0.0): inside any deck's box (reach 0)
bool near_deck(const std::vector<Box> &decks, const Vector3 &point) {
	const double x = point.x, z = point.z;
	for (const Box &b : decks) {
		if (x >= b.x0 - 0.0 && x <= b.x1 + 0.0 && z >= b.z0 - 0.0 && z <= b.z1 + 0.0) {
			return true;
		}
	}
	return false;
}

// Vector2(a.x - b.x, a.z - b.z).length(): the differences in doubles, narrowed to the Vector2 (as pathing_native's flat_gap)
double flat_gap(const Vector3 &a, const Vector3 &b) {
	return Vector2((real_t)((double)a.x - (double)b.x), (real_t)((double)a.z - (double)b.z)).length();
}

// SelectionSquads.crosses_on(node)'s body after its near_deck(from) test, on `path` (find_path(node, from, to))
bool path_crosses(const std::vector<Box> &decks, PackedVector3Array path, const Vector3 &from, const Vector3 &to) {
	if (path.size() < 2) {
		path = PackedVector3Array();
		path.push_back(from);
		path.push_back(to);
	}
	for (int64_t i = 1; i < path.size(); i++) {
		const Vector3 a(path[i - 1].x, 0.0f, path[i - 1].z);
		const Vector3 b(path[i].x, 0.0f, path[i].z);
		const int64_t steps = std::max<int64_t>(1, (int64_t)std::ceil((double)a.distance_to(b) / 2.0));
		for (int64_t k = 0; k < steps + 1; k++) {
			if (near_deck(decks, a.lerp(b, (real_t)((double)k / (double)steps)))) {
				return true;
			}
		}
	}
	return false;
}

// SlotGround.path_length(node, from, to) on `path`
double path_length(const PackedVector3Array &path, const Vector3 &from, const Vector3 &to) {
	if (path.size() < 2) {
		return flat_gap(to, from);
	}
	double length = 0.0;
	for (int64_t i = 1; i < path.size(); i++) {
		length += flat_gap(path[i], path[i - 1]);
	}
	return length;
}

} // namespace

//   for side in [-1, 1]: reach := 0; k := 1
//     while k * STEP <= scan + 0.001: d := k * STEP; p := flat_click + across * (side * d)
//       if crosses(flat_click, p): break           -- crosses_or_edge: off the arena (clamp moves it > 0.5 m), or a deck on the way
//       by_ground := drive(flat_click, p)
//       if by_ground < 0 or by_ground > DETOUR * d + 1: if d - reach > past_posts: break
//       else: reach = d
//       k += 1
//     out.append(reach)
Array gate_width_edge(const PathingConfig &pathing, const GateConsts &c, Object *node, const Vector3 &click,
		const Vector3 &across, double scan, double past_posts, const Array &deck_array, const Callable &clamp) {
	std::vector<Box> decks;
	decks.reserve(deck_array.size());
	for (int64_t i = 0; i < deck_array.size(); i++) {
		const Array box = deck_array[i];
		decks.push_back(Box{ (double)box[0], (double)box[1], (double)box[2], (double)box[3] });
	}
	const Vector3 flat_click(click.x, 0.0f, click.z);
	// crosses_on's opening: `if near_deck(from, 0.0): return false` (from is the click for every step)
	const bool click_on_deck = near_deck(decks, flat_click);
	Array out;
	const double sides[2] = { -1.0, 1.0 };
	for (const double side : sides) {
		double reach = 0.0;
		int64_t k = 1;
		while ((double)k * c.step <= scan + 0.001) {
			const double d = (double)k * c.step;
			const Vector3 p = flat_click + across * (real_t)(side * d);
			// crosses_or_edge: Orders.clamp_to_arena(flat).distance_to(flat) > 0.5 or crosses(from, to)
			const Vector3 flat(p.x, 0.0f, p.z);
			const Vector3 clamped = clamp.call(flat);
			if ((double)clamped.distance_to(flat) > 0.5) {
				break;
			}
			// one navmesh query serves crosses_on and drive_on: both are Pathing.find_path(node, flat_click, p)
			const PackedVector3Array path = pathing_find_path(pathing, node, flat_click, p);
			if (!click_on_deck && path_crosses(decks, path, flat_click, p)) {
				break;
			}
			const double by_ground = path_length(path, flat_click, p);
			if (by_ground < 0.0 || by_ground > c.detour * d + 1.0) {
				if (d - reach > past_posts) {
					break;
				}
			} else {
				reach = d;
			}
			k += 1;
		}
		out.push_back(reach);
	}
	return out;
}

} // namespace godot
