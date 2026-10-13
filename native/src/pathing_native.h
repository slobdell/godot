// Round 28 (native N6.4): the nav wrappers in C++ -- Pathing.is_ready, Pathing.query and Pathing.find_path
// (game/ai/pathing.gd), the think side's entries to the navmesh (the drive's own copies are in drive_native.cpp since
// E2/N5). Line by line; the memo stays in Pathing's statics (one owner probe a map iteration), the closest point is
// Pathing.closest_point's (N2a's index while native_nav is on, else the GDScript with its frame memo). The detailed
// profile's laps are measurement only: with OrderController.profile_detail on the GDScript runs (NativePathing.usable).
#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class NavNative;

struct PathingConfig {
	bool ready = false;
	double MESH_EPSILON = 0.05;
	Object *pathing = nullptr, *switches = nullptr; // Pathing (enabled, the ready memo, closest_point), BrainSwitches
	NavNative *nav = nullptr; // NativeBridge.nav (N2a)
	Variant keep_pathing, keep_switches, keep_nav;
};

bool pathing_is_ready(const PathingConfig &config, Object *node);
Dictionary pathing_query(const PathingConfig &config, Object *node, const Vector3 &from, const Vector3 &to);
PackedVector3Array pathing_find_path(const PathingConfig &config, Object *node, const Vector3 &from, const Vector3 &to);

} // namespace godot
