// Round 27 (native, stage 1 E1): a crew's EXECUTE STATE owned by the C++ -- its Movement's, Gunnery's and
// Engagement.Lay's script members as typed fields, generated from ONE table (exec_fields.h).
//
// The GDScript members stay, as the reference (the web build, NATIVE=off, the live-function proofs) and as a MIRROR:
// `pull` copies every member into the struct; `push` copies the struct back, every field (force) or only the fields the
// C++ changed through a setter (their dirty bits). With the execute step in C++ (E5), the C++ owns the state and pushes
// what it changed after each crew's execute, so every GDScript reader outside the execute step reads current members with
// no code change (native.md *Stage 1*, the mirror decision); GDScript that WRITES the state outside the execute step marks
// it for a pull.
//
// Widths: int 64-bit, float double, vectors float32, as the engine stores them (native.md hazard 1). Array and Dictionary
// members are shared references: the struct holds the very container the GDScript holds.
#pragma once

#include "exec_fields.h"

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>

namespace godot {

enum ExecOwner { EXEC_MOVER = 0, EXEC_GUNNERY = 1, EXEC_LAY = 2 };

#define EXEC_ENUM(t, vt, n) n,
struct MF {
	enum : int { EXEC_MOVER_FIELDS(EXEC_ENUM) COUNT };
};
struct GF {
	enum : int { EXEC_GUNNERY_FIELDS(EXEC_ENUM) COUNT };
};
struct LF {
	enum : int { EXEC_LAY_FIELDS(EXEC_ENUM) COUNT };
};
#undef EXEC_ENUM

#define EXEC_DECLARE(t, vt, n) t n{};
struct MoverFields {
	EXEC_MOVER_FIELDS(EXEC_DECLARE)
};
struct GunneryFields {
	EXEC_GUNNERY_FIELDS(EXEC_DECLARE)
};
struct LayFields {
	EXEC_LAY_FIELDS(EXEC_DECLARE)
};
#undef EXEC_DECLARE

// The member names, made once.
struct ExecNames {
#define EXEC_NAME(t, vt, n) StringName n{ #n };
	struct Mover {
		EXEC_MOVER_FIELDS(EXEC_NAME)
	} m;
	struct Gunnery {
		EXEC_GUNNERY_FIELDS(EXEC_NAME)
	} g;
	struct Lay {
		EXEC_LAY_FIELDS(EXEC_NAME)
	} l;
#undef EXEC_NAME
	StringName gunnery{ "gunnery" };
};
const ExecNames &exec_names();

// A fixed-size dirty bitset.
template <int N>
struct ExecDirty {
	uint64_t bits[(N + 63) / 64] = {};
	void mark(int f) { bits[f >> 6] |= (uint64_t)1 << (f & 63); }
	bool has(int f) const { return (bits[f >> 6] >> (f & 63)) & 1; }
	void clear() {
		for (uint64_t &b : bits) {
			b = 0;
		}
	}
	int count() const {
		int n = 0;
		for (uint64_t b : bits) {
			n += __builtin_popcountll(b);
		}
		return n;
	}
};

struct ExecState {
	ObjectID mover_id, gunnery_id, lay_id; // the objects the last pull read (lay_id: gunnery.engagement_lay then)
	MoverFields m;
	GunneryFields g;
	LayFields l;
	ExecDirty<MF::COUNT> m_dirty;
	ExecDirty<GF::COUNT> g_dirty;
	ExecDirty<LF::COUNT> l_dirty;
	int64_t pulls = 0, pushes = 0, pushed_fields = 0;
	bool fresh = false; // E5b: pulled at least once (the registry's states start empty)

	// Every member of `mover`, its controller's Gunnery and that Gunnery's Lay into the struct (dirty bits cleared).
	// Returns the members whose Variant type was not the table's (stored converted; the test asserts 0).
	int pull(Object *mover);
	// Part of a pull (E5b's stale bits): the Gunnery's and the Lay's members (the Gunnery found through `m.ctl`), or one
	// Movement member. Dirty bits are not touched for the mover's field (the caller pulls only what nothing has changed).
	int pull_gun();
	void pull_mover_field(Object *mover, int field);
	// The struct into the members: every field when `force`, else only the dirty ones (then cleared). Returns the
	// fields written. The Gunnery is the controller's (`m.ctl.gunnery`), the Lay the struct's `g.engagement_lay`.
	int push(Object *mover, bool force);
	// {"m:<name>" | "g:<name>" | "l:<name>": value} (the test compares it with the live members).
	Dictionary row() const;
	// Test only: set one field by its row key through the struct (marks it dirty). False for an unknown key.
	bool set_field(const String &key, const Variant &value);
	// Test only: write a DIFFERENT value of the same type into every member of the live objects (containers replaced by
	// new ones, objects by null); a push(force) after it must give back exactly the pulled state. Returns members changed.
	static int scramble(Object *mover);
};

// Every crew's state, keyed by its Movement's instance id (the owned execute's, the tests'). One per process. Its Variants
// hold references (the Lay, the station PID, Arrays), so it is emptied when the library is unloaded (register_types.cpp),
// while the engine is still up: a static destructor runs after the engine has gone and would free them into nothing (the
// segfault at exit that E1's first mirror run hit). E5b first held each state in an extension-class object on its mover
// (`native_state`): movers kept alive by GDScript statics are freed after the library unloads, and destroying an instance of
// an unloaded class corrupted the heap at exit ("corrupted size vs. prev_size"); so: this registry, swept every frame.
struct ExecStates {
	HashMap<uint64_t, ExecState *> by_mover;
	ExecState *of(Object *mover, bool create);
	// E5b: forget the states of movers that no longer exist (once a physics frame; the states' Variants hold references).
	int64_t swept_frame = -1;
	void sweep(int64_t frame);
	void forget(Object *mover);
	void clear();
	int size() const { return by_mover.size(); }
};
ExecStates &exec_states();

// [owner, name, Variant::Type] for every field of the table, in order (the drift test).
Array exec_field_table();

} // namespace godot
