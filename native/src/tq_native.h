// Round 24 (native, C24.6): TacticalQuery's constants (tq_native.cpp), from the live script at first use
// (NativeTq.configure), held by the TankNative instance.
#pragma once

#include <godot_cpp/templates/local_vector.hpp>

#include <cstdint>

namespace godot {

struct TqConsts {
	struct Rotation {
		double c, s;
	};
	double SEARCH_RADIUS, FRIEND_SPACING, PEEK_MAX, DRIVE_CLEARANCE, STAND_CLEARANCE, HULL_MARGIN, PEEK_MARGIN;
	double EDGE, CELL; // CoverMap's
	int64_t MAX_THREATS = 6, MAX_CANDIDATES = 16, MAX_DEEP = 8;
	LocalVector<double> PEEK_STEPS;
	LocalVector<Rotation> PEEK_ROTATIONS;
	bool ready = false;
};

} // namespace godot
