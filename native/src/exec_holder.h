// Round 27 (native, stage 1 E5b): a crew's C++-owned execute state, held by its Movement (`native_state`), so it lives
// exactly as long as the mover and is freed while the engine is up (a process-wide registry freed its Variants after the
// engine at exit: E1's lesson). Nothing to call on it from GDScript.
#pragma once

#include "exec_state.h"

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class NativeExecState : public RefCounted {
	GDCLASS(NativeExecState, RefCounted)

protected:
	static void _bind_methods() {}

public:
	ExecState state;
	bool fresh = false; // pulled at least once
};

} // namespace godot
