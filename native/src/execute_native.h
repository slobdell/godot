// Round 27 (native, stage 1 E5): OrderController.compute_command as one native call per crew (execute_native.cpp).
#pragma once

#include "drive_native.h"
#include "gun_native.h"

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

struct ExecConfig {
	const DriveConfig *drive = nullptr;
	const GunConfig *gun = nullptr;
};

// How the crew's state is held: the live GDScript members; the C++-owned state the mover holds (pulled only when
// `native_stale`, the changed fields pushed at the end); the same, with a fresh pull compared before every execute.
enum ExecMode { EXEC_LIVE = 0, EXEC_OWNED = 1, EXEC_OWNED_VERIFY = 2 };

// The crew's TankCommand for this tick, or NIL when this tick is not the common path (nothing written: the GDScript
// compute_command runs, and an owned state is marked stale).
Variant execute_native(const ExecConfig &config, Object *ctl, double delta, int mode);
// Measurement: executes answered natively and handed back.
Dictionary execute_counts(bool reset);

} // namespace godot
