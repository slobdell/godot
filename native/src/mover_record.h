// Round 26 (perf, stage-1 groundwork for round 27; OFF, nothing in the game calls it): the per-crew EXECUTE state --
// Movement's, Gunnery's and its Engagement.Lay's script members -- as typed C++ columns, gathered by the C++ from the
// same hulls, in the same order, as TankRecords (scene order, living hulls). Stage 1 moves this state into the record
// (native.md *Stage 1*); this first step only READS it, so a test can hold every field equal to the GDScript's own read
// (tests/native/test_native_mover_record.gd).
//
// Which fields: configured from the live scripts (the test hands over every member whose declared type is fixed: bool,
// int, float, String, StringName, Vector2, Vector3), so a member an owner adds is gathered without editing this file.
// Widths as the engine stores them: int 64-bit, float double, Vector2/Vector3 float32 (hazard 1 in native.md).
#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

struct MoverRecord {
	enum Owner { MOVER = 0, GUNNERY = 1, LAY = 2 };
	enum Kind { K_BOOL = 0, K_INT, K_FLOAT, K_STRING, K_VEC2, K_VEC3 };
	struct Field {
		Owner owner;
		Kind kind;
		StringName name;
		int offset; // into its kind's column block of a row
	};
	LocalVector<Field> fields;
	int strides[6] = { 0, 0, 0, 0, 0, 0 }; // per kind: slots a row (VEC2 2 floats, VEC3 3 floats)
	bool on = false; // the switch: OFF by default (BrainSwitches-free on purpose: native/** only this round)

	PackedStringArray names; // the rows' tank names
	LocalVector<uint8_t> present; // per row: 1 mover, 2 gunnery, 4 lay found
	LocalVector<uint8_t> bools;
	LocalVector<int64_t> ints;
	LocalVector<double> floats;
	LocalVector<String> strings;
	LocalVector<float> vecs; // VEC2 and VEC3 share one float32 block (VEC2 first)
	int64_t type_mismatches = 0; // a member whose Variant type was not the configured one (stored as the default)
	int64_t last_usec = 0;

	// spec: Array of [owner (0/1/2), name (String), Variant.Type (int)]; returns the fields accepted (unsupported types
	// are skipped and returned in `rejected`).
	int configure(const Array &spec, PackedStringArray &rejected);
	// Every living hull under `root` (TankRecords' filter and order); `registry` is Movement._registry
	// {tank instance id: Movement}. Returns the rows, or -1 while OFF.
	int gather(Node *root, const Dictionary &registry);
	int size() const { return names.size(); }
	// {"m:<name>" | "g:<name>" | "l:<name>": value} for the test, plus "name" and "present".
	Dictionary row(int r) const;
};

} // namespace godot
