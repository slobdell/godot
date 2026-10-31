// Round 47 (native, R47.36, mapkit P3): Perception.eye_mask() for the C++ eye rays: WORLD_MASK | ArenaKit.SIGHT_LAYER while
// ArenaKit.sight_on (read live; a tree without the sight class, or the switch off: the world mask alone). A sight screen is on
// SIGHT_LAYER only, and no shipped map has one, so every shipped map's rays are byte-identical. The script is looked up by its
// ObjectID, never held (a static Ref outlives the engine at exit).
#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

inline uint32_t eye_mask_live(uint32_t world_mask) {
	static const uint32_t SIGHT_LAYER = 16; // ArenaKit.SIGHT_LAYER (test_native_eye_mask compares the answer)
	static ObjectID kit_id;
	static bool tried = false;
	Object *kit = kit_id.is_valid() ? ObjectDB::get_instance(kit_id) : nullptr;
	if (kit == nullptr && !tried) {
		tried = true;
		static const String path("res://game/arena/arena_kit.gd");
		if (ResourceLoader::get_singleton()->exists(path)) {
			const Ref<Resource> loaded = ResourceLoader::get_singleton()->load(path);
			if (loaded.is_valid()) {
				kit_id = ObjectID(loaded->get_instance_id());
				kit = loaded.ptr();
			}
		}
	}
	if (kit == nullptr) {
		return world_mask;
	}
	static const StringName sight_on("sight_on");
	const Variant on = kit->get(sight_on);
	return on.get_type() == Variant::BOOL && (bool)on ? (world_mask | SIGHT_LAYER) : world_mask;
}

} // namespace godot
