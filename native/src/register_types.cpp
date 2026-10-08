// The library's entry point: `tank_squad_native_init` is the `entry_symbol` of native/tank_squad.gdextension.in.
#include "register_types.h"

#include "cover_native.h"
#include "nav_native.h"
#include "tank_native.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_tank_native_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(TankNative);
	GDREGISTER_CLASS(CoverNative);
	GDREGISTER_CLASS(NavNative);
}

void uninitialize_tank_native_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT tank_squad_native_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_tank_native_module);
	init_obj.register_terminator(uninitialize_tank_native_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
