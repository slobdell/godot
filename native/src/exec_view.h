// Round 27 (native, stage 1 E1c): ONE way for the execute code to read and write a crew's state, two places it can live.
//
// The execute ports (drive_native.cpp, and every E2-E4 port after it) are written against a view `V` with a typed getter
// and setter per member of the table (exec_fields.h): `v._goal()`, `v.set__goal(x)`, `v.g_engaged_target()`,
// `v.set_l_progress(p)`. Two views:
//
// - ObjectView: the live GDScript members, through Object::get/set -- what the native drive has always done. The
//   GDScript owns the state; a callback into a GDScript method needs nothing.
// - StructView: the C++-owned ExecState (exec_state.h). A setter marks the field dirty; `push_out` writes the dirty
//   fields to the members (before any call into GDScript that may READ this crew's members, and when the execute ends);
//   `pull_in` reads them all back (after a GDScript callback that may WRITE them). While the execute step still calls
//   GDScript (E2-E4) this is the slow, exact transition; at E5 nothing is called back and only the end's push is left.
//
// The two views give the same bits: the setter converts to the member's type exactly where Object::set would, and a
// getter returns what the member holds (tests/test_native_drive.gd runs the drive through both).
#pragma once

#include "exec_state.h"

#include <godot_cpp/core/object.hpp>

#include <cstring>
#include <type_traits>

namespace godot {

struct ObjectView {
	Object *m = nullptr; // the Movement
	Object *gun = nullptr; // its controller's Gunnery (resolved once, at bind)
	Object *lay = nullptr; // that Gunnery's Lay (re-read through the Gunnery when it may have been replaced)

	explicit ObjectView(Object *p_mover) :
			m(p_mover) {}
	Object *object() const { return m; }
	void bind_gunnery() {
		const ExecNames &k = exec_names();
		Object *ctl = m->get(k.m.ctl).get_validated_object();
		gun = ctl != nullptr ? ctl->get(k.gunnery).get_validated_object() : nullptr;
		lay = gun != nullptr ? gun->get(k.g.engagement_lay).get_validated_object() : nullptr;
	}
	void push_out() {}
	void pull_in() {}

#define EXEC_OV_M(t, vt, n)                                                                       \
	t n() const { return static_cast<t>(m->get(exec_names().m.n)); }                              \
	void set_##n(const t &value) { m->set(exec_names().m.n, Variant(value)); }
#define EXEC_OV_G(t, vt, n)                                                                       \
	t g_##n() const { return static_cast<t>(gun->get(exec_names().g.n)); }                        \
	void set_g_##n(const t &value) { gun->set(exec_names().g.n, Variant(value)); }
#define EXEC_OV_L(t, vt, n)                                                                       \
	t l_##n() const { return static_cast<t>(lay->get(exec_names().l.n)); }                        \
	void set_l_##n(const t &value) { lay->set(exec_names().l.n, Variant(value)); }
	EXEC_MOVER_FIELDS(EXEC_OV_M)
	EXEC_GUNNERY_FIELDS(EXEC_OV_G)
	EXEC_LAY_FIELDS(EXEC_OV_L)
#undef EXEC_OV_M
#undef EXEC_OV_G
#undef EXEC_OV_L
};

// A setter marks a field dirty only when the value changes, for the types whose == is a plain compare; a container, a
// packed array or an untyped Variant is marked whenever it is set (its compare walks it).
template <class T>
struct ExecCheapEq {
	static constexpr bool value = false;
};
#define EXEC_CHEAP(T)                                                                             \
	template <>                                                                                   \
	struct ExecCheapEq<T> {                                                                       \
		static constexpr bool value = true;                                                       \
	};
EXEC_CHEAP(bool)
EXEC_CHEAP(int64_t)
EXEC_CHEAP(double)
EXEC_CHEAP(String)
EXEC_CHEAP(StringName)
EXEC_CHEAP(Vector2)
EXEC_CHEAP(Vector3)
EXEC_CHEAP(RID)
#undef EXEC_CHEAP

// Floats and vectors compare BITWISE: -0.0 == 0.0 would skip a write that changes the member's bits (and NaN != NaN
// would mark one that does not).
template <class T>
inline bool exec_same(const T &a, const T &b) {
	if constexpr (std::is_same_v<T, double> || std::is_same_v<T, Vector2> || std::is_same_v<T, Vector3>) {
		return std::memcmp(&a, &b, sizeof(T)) == 0;
	} else {
		return a == b;
	}
}

template <class T>
inline bool exec_assign(T &field, const T &value) {
	if constexpr (ExecCheapEq<T>::value) {
		if (exec_same(field, value)) {
			return false;
		}
	}
	field = value;
	return true;
}

struct StructView {
	Object *m = nullptr; // the Movement (pushes and pulls go to it)
	ExecState *s = nullptr;
	int64_t pushes = 0, pulls = 0; // the transition's syncs (measurement: they go to zero by E5)

	StructView(Object *p_mover, ExecState *p_state) :
			m(p_mover), s(p_state) {}
	Object *object() const { return m; }
	void bind_gunnery() {}
	// The dirty fields to the members (before GDScript may read them).
	void push_out() {
		if (s->m_dirty.count() + s->g_dirty.count() + s->l_dirty.count() > 0) {
			s->push(m, false);
			pushes++;
		}
	}
	// Every member back into the struct (after GDScript may have written them).
	void pull_in() {
		s->pull(m);
		pulls++;
	}

#define EXEC_SV_M(t, vt, n)                                                                       \
	const t &n() const { return s->m.n; }                                                         \
	void set_##n(const t &value) { \
		if (exec_assign(s->m.n, value)) { \
			s->m_dirty.mark(MF::n); \
		} \
	}
#define EXEC_SV_G(t, vt, n)                                                                       \
	const t &g_##n() const { return s->g.n; }                                                     \
	void set_g_##n(const t &value) { \
		if (exec_assign(s->g.n, value)) { \
			s->g_dirty.mark(GF::n); \
		} \
	}
#define EXEC_SV_L(t, vt, n)                                                                       \
	const t &l_##n() const { return s->l.n; }                                                     \
	void set_l_##n(const t &value) { \
		if (exec_assign(s->l.n, value)) { \
			s->l_dirty.mark(LF::n); \
		} \
	}
	EXEC_MOVER_FIELDS(EXEC_SV_M)
	EXEC_GUNNERY_FIELDS(EXEC_SV_G)
	EXEC_LAY_FIELDS(EXEC_SV_L)
#undef EXEC_SV_M
#undef EXEC_SV_G
#undef EXEC_SV_L
};

} // namespace godot
