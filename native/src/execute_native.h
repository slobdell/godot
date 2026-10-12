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

// The crew's TankCommand for this tick, or NIL when this tick is not the common path (nothing written: the GDScript
// compute_command runs). `owned`: on a C++-owned ExecState (pulled at the start, the changed fields pushed at the end).
Variant execute_native(const ExecConfig &config, Object *ctl, double delta, bool owned);
// Measurement: executes answered natively and handed back.
Dictionary execute_counts(bool reset);

} // namespace godot
