// Round 24 (native, N4 under grant C24.8): SlotGround's grounding (game/tactics/slot_ground.gd) natively. First the
// water rules (round 24 R1, his bridge): wet, over_water, leg_wet, dry_leg_end, pulled_dry, on_anchor_side, over the
// arena's terrain rectangles handed over once per terrain list (NativeEl). Line by line with the GDScript's widths
// (_agents/native.md, hazard 1): ArenaTerrain.bounds is a PackedFloat32Array, Vector2 lengths and lerps are float32,
// the step arithmetic double. tests/test_native_el.gd asks the live functions on every arena with water.
#pragma once

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <cstring>

namespace godot {

struct ElTerrain {
	struct Box {
		float b[4]; // [min_x, min_z, max_x, max_z] (ArenaTerrain.bounds)
		bool carves, deck;
	};
	LocalVector<Box> boxes;
	double WET_STEP_M = 1.0, DRY_MARGIN_M = 4.0, MOUTH_CLEAR_M = 2.0;

	bool wet(const Vector3 &point) const;
	bool over_water(const Vector3 &point) const;
	bool leg_wet(const Vector3 &from, const Vector3 &to) const;
	Vector3 dry_leg_end(const Vector3 &from, const Vector3 &to, double margin, bool strict) const;
	Vector3 pulled_dry(const Vector3 &point, const Vector3 &toward) const;
	Vector3 on_anchor_side(const Vector3 &slot, const Vector3 &anchor) const;
};

class NavNative;

// SlotGround.standable_for's body (the hull's clearance pushes, the fit test, the rings) over NavNative's closest
// point, memoised for the map's iteration and keyed exactly (the point's three floats, the clearance's double), as
// SlotGround's own `_ground_memo` is: a pure function of the map, so the memo is invisible in the answers.
struct ElGround {
	double TOLERANCE_M = 1.0, PROBE_TOLERANCE_M = 0.25;
	int64_t CLEARANCE_PROBES = 8, CLEARANCE_ITERATIONS = 3, FIT_RINGS = 2, MEMO_LIMIT = 4096;
	bool ready = false;

	struct Key {
		uint32_t bits[5];
		bool operator==(const Key &o) const { return std::memcmp(bits, o.bits, sizeof(bits)) == 0; }
	};
	struct KeyHasher {
		static uint32_t hash(const Key &k) {
			uint32_t h = 2166136261u;
			for (uint32_t b : k.bits) {
				h = (h ^ b) * 16777619u;
			}
			return h;
		}
	};
	HashMap<Key, Vector3, KeyHasher> memo;
	RID memo_map;
	int64_t memo_iteration = -1;

	Vector3 standable_for(NavNative *nav, const RID &map, int64_t iteration, const Vector3 &point, double clearance,
			double bake_radius);

private:
	Vector3 standable(NavNative *nav, const RID &map, const Vector3 &point) const;
	Vector3 off_mesh(NavNative *nav, const RID &map, const Vector3 &at, double need, int64_t k) const;
	Vector3 settle(NavNative *nav, const RID &map, Vector3 at, double need) const;
	bool fits(NavNative *nav, const RID &map, const Vector3 &at, double need) const;
	Vector3 compute(NavNative *nav, const RID &map, const Vector3 &point, double clearance, double bake_radius) const;
};

} // namespace godot
