#include "exec_state.h"

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/local_vector.hpp>

#include <cmath>

namespace godot {

const ExecNames &exec_names() {
	static const ExecNames names;
	return names;
}

ExecStates &exec_states() {
	static ExecStates states;
	return states;
}

namespace {

inline bool type_ok(const Variant &v, Variant::Type want) {
	if (want == Variant::NIL) {
		return true; // an untyped `Variant` member holds anything
	}
	if (want == Variant::OBJECT) {
		return v.get_type() == Variant::OBJECT || v.get_type() == Variant::NIL;
	}
	return v.get_type() == want;
}

Object *gunnery_of(const Variant &ctl) {
	Object *c = ctl.get_validated_object();
	return c != nullptr ? c->get(exec_names().gunnery).get_validated_object() : nullptr;
}

bool finite2(const Vector2 &v) {
	return std::isfinite(v.x) && std::isfinite(v.y);
}
bool finite3(const Vector3 &v) {
	return std::isfinite(v.x) && std::isfinite(v.y) && std::isfinite(v.z);
}

// A different value of the same type (scramble); `changed` false when there is none to make (a null object, an empty RID).
Variant scrambled(const Variant &v, Variant::Type type, bool &changed) {
	changed = true;
	switch (type) {
		case Variant::BOOL: return !(bool)v;
		case Variant::INT: return (int64_t)v + 7919;
		case Variant::FLOAT: {
			const double d = v;
			return std::isfinite(d) ? d + 1.25 : 0.0;
		}
		case Variant::STRING: return String(v) + String("~");
		case Variant::STRING_NAME: return StringName(String(v) + String("~"));
		case Variant::VECTOR2: {
			const Vector2 a = v;
			return finite2(a) ? Vector2(a.x + 1.5f, a.y - 2.5f) : Vector2(1, 2);
		}
		case Variant::VECTOR3: {
			const Vector3 a = v;
			return finite3(a) ? Vector3(a.x + 1.5f, a.y - 2.5f, a.z + 0.75f) : Vector3(1, 2, 3);
		}
		case Variant::RID: {
			if (((RID)v).is_valid()) {
				return RID();
			}
			changed = false;
			return v;
		}
		case Variant::DICTIONARY: {
			Dictionary d;
			if (((Dictionary)v).is_empty()) {
				d["~"] = 1;
			}
			return d;
		}
		case Variant::ARRAY: {
			const Array a = v;
			Array out = a.is_typed() ? Array(Array(), a.get_typed_builtin(), a.get_typed_class_name(), a.get_typed_script()) :
									   Array();
			if (a.is_empty()) {
				switch (a.get_typed_builtin()) {
					case Variant::NIL: out.push_back(1); break;
					case Variant::BOOL: out.push_back(true); break;
					case Variant::VECTOR3: out.push_back(Vector3(1, 2, 3)); break;
					case Variant::VECTOR2: out.push_back(Vector2(1, 2)); break;
					default: break; // a new container is still a different one (the test compares identity)
				}
			}
			return out;
		}
		case Variant::PACKED_FLOAT32_ARRAY: {
			PackedFloat32Array p;
			if (((PackedFloat32Array)v).is_empty()) {
				p.push_back(1.5f);
			}
			return p;
		}
		case Variant::PACKED_VECTOR3_ARRAY: {
			PackedVector3Array p;
			if (((PackedVector3Array)v).is_empty()) {
				p.push_back(Vector3(1, 2, 3));
			}
			return p;
		}
		case Variant::CALLABLE: {
			if (((Callable)v).is_valid()) {
				return Callable();
			}
			changed = false;
			return v;
		}
		case Variant::OBJECT: {
			if (v.get_type() == Variant::OBJECT && v.get_validated_object() != nullptr) {
				return Variant();
			}
			changed = false;
			return v;
		}
		case Variant::NIL: {
			if (v.get_type() == Variant::NIL) {
				return Vector3(1, 2, 3);
			}
			return Variant();
		}
		default:
			changed = false;
			return v;
	}
}

} // namespace

int ExecState::pull(Object *mover) {
	const ExecNames &k = exec_names();
	int bad = 0;
	mover_id = ObjectID(mover->get_instance_id());
#define EXEC_PULL_M(t, vt, n)                       \
	{                                               \
		const Variant v = mover->get(k.m.n);        \
		bad += type_ok(v, Variant::vt) ? 0 : 1;     \
		m.n = static_cast<t>(v);                    \
	}
	EXEC_MOVER_FIELDS(EXEC_PULL_M)
#undef EXEC_PULL_M
	m_dirty.clear();
	bad += pull_gun();
	pulls++;
	return bad;
}

int ExecState::pull_gun() {
	const ExecNames &k = exec_names();
	int bad = 0;
	Object *gunnery = gunnery_of(m.ctl);
	gunnery_id = ObjectID(gunnery != nullptr ? gunnery->get_instance_id() : 0);
	if (gunnery != nullptr) {
#define EXEC_PULL_G(t, vt, n)                       \
	{                                               \
		const Variant v = gunnery->get(k.g.n);      \
		bad += type_ok(v, Variant::vt) ? 0 : 1;     \
		g.n = static_cast<t>(v);                    \
	}
		EXEC_GUNNERY_FIELDS(EXEC_PULL_G)
#undef EXEC_PULL_G
	}
	g_dirty.clear();
	Object *lay = gunnery != nullptr ? g.engagement_lay.get_validated_object() : nullptr;
	lay_id = ObjectID(lay != nullptr ? lay->get_instance_id() : 0);
	if (lay != nullptr) {
#define EXEC_PULL_L(t, vt, n)                       \
	{                                               \
		const Variant v = lay->get(k.l.n);          \
		bad += type_ok(v, Variant::vt) ? 0 : 1;     \
		l.n = static_cast<t>(v);                    \
	}
		EXEC_LAY_FIELDS(EXEC_PULL_L)
#undef EXEC_PULL_L
	}
	l_dirty.clear();
	return bad;
}

void ExecState::pull_mover_field(Object *mover, int field) {
	const ExecNames &k = exec_names();
	switch (field) {
#define EXEC_PULL_ONE(t, vt, n)                     \
	case MF::n:                                     \
		m.n = static_cast<t>(mover->get(k.m.n));    \
		break;
		EXEC_MOVER_FIELDS(EXEC_PULL_ONE)
#undef EXEC_PULL_ONE
		default:
			break;
	}
}

int ExecState::push(Object *mover, bool force) {
	const ExecNames &k = exec_names();
	int written = 0;
#define EXEC_PUSH_M(t, vt, n)                       \
	if (force || m_dirty.has(MF::n)) {              \
		mover->set(k.m.n, Variant(m.n));            \
		written++;                                  \
	}
	EXEC_MOVER_FIELDS(EXEC_PUSH_M)
#undef EXEC_PUSH_M
	m_dirty.clear();
	Object *gunnery = gunnery_of(m.ctl);
	if (gunnery != nullptr) {
#define EXEC_PUSH_G(t, vt, n)                       \
	if (force || g_dirty.has(GF::n)) {              \
		gunnery->set(k.g.n, Variant(g.n));          \
		written++;                                  \
	}
		EXEC_GUNNERY_FIELDS(EXEC_PUSH_G)
#undef EXEC_PUSH_G
	}
	g_dirty.clear();
	Object *lay = gunnery != nullptr ? g.engagement_lay.get_validated_object() : nullptr;
	if (lay != nullptr) {
#define EXEC_PUSH_L(t, vt, n)                       \
	if (force || l_dirty.has(LF::n)) {              \
		lay->set(k.l.n, Variant(l.n));              \
		written++;                                  \
	}
		EXEC_LAY_FIELDS(EXEC_PUSH_L)
#undef EXEC_PUSH_L
	}
	l_dirty.clear();
	pushes++;
	pushed_fields += written;
	return written;
}

Dictionary ExecState::row() const {
	Dictionary out;
#define EXEC_ROW_M(t, vt, n) out[String("m:" #n)] = Variant(m.n);
#define EXEC_ROW_G(t, vt, n) out[String("g:" #n)] = Variant(g.n);
#define EXEC_ROW_L(t, vt, n) out[String("l:" #n)] = Variant(l.n);
	EXEC_MOVER_FIELDS(EXEC_ROW_M)
	EXEC_GUNNERY_FIELDS(EXEC_ROW_G)
	EXEC_LAY_FIELDS(EXEC_ROW_L)
#undef EXEC_ROW_M
#undef EXEC_ROW_G
#undef EXEC_ROW_L
	return out;
}

bool ExecState::set_field(const String &key, const Variant &value) {
#define EXEC_SET_M(t, vt, n)                        \
	if (key == String("m:" #n)) {                   \
		m.n = static_cast<t>(value);                \
		m_dirty.mark(MF::n);                        \
		return true;                                \
	}
#define EXEC_SET_G(t, vt, n)                        \
	if (key == String("g:" #n)) {                   \
		g.n = static_cast<t>(value);                \
		g_dirty.mark(GF::n);                        \
		return true;                                \
	}
#define EXEC_SET_L(t, vt, n)                        \
	if (key == String("l:" #n)) {                   \
		l.n = static_cast<t>(value);                \
		l_dirty.mark(LF::n);                        \
		return true;                                \
	}
	EXEC_MOVER_FIELDS(EXEC_SET_M)
	EXEC_GUNNERY_FIELDS(EXEC_SET_G)
	EXEC_LAY_FIELDS(EXEC_SET_L)
#undef EXEC_SET_M
#undef EXEC_SET_G
#undef EXEC_SET_L
	return false;
}

int ExecState::scramble(Object *mover) {
	const ExecNames &k = exec_names();
	Object *gunnery = gunnery_of(mover->get(k.m.ctl));
	Object *lay = gunnery != nullptr ? gunnery->get(k.g.engagement_lay).get_validated_object() : nullptr;
	int changed_count = 0;
	bool changed = false;
	// The Lay first, then the Gunnery, then the mover: the objects were all found before any reference is nulled.
	if (lay != nullptr) {
#define EXEC_SCRAMBLE_L(t, vt, n)                                              \
	lay->set(k.l.n, scrambled(lay->get(k.l.n), Variant::vt, changed));         \
	changed_count += changed ? 1 : 0;
		EXEC_LAY_FIELDS(EXEC_SCRAMBLE_L)
#undef EXEC_SCRAMBLE_L
	}
	if (gunnery != nullptr) {
#define EXEC_SCRAMBLE_G(t, vt, n)                                              \
	gunnery->set(k.g.n, scrambled(gunnery->get(k.g.n), Variant::vt, changed)); \
	changed_count += changed ? 1 : 0;
		EXEC_GUNNERY_FIELDS(EXEC_SCRAMBLE_G)
#undef EXEC_SCRAMBLE_G
	}
#define EXEC_SCRAMBLE_M(t, vt, n)                                              \
	mover->set(k.m.n, scrambled(mover->get(k.m.n), Variant::vt, changed));     \
	changed_count += changed ? 1 : 0;
	EXEC_MOVER_FIELDS(EXEC_SCRAMBLE_M)
#undef EXEC_SCRAMBLE_M
	return changed_count;
}

ExecState *ExecStates::of(Object *mover, bool create) {
	if (mover == nullptr) {
		return nullptr;
	}
	const uint64_t id = mover->get_instance_id();
	ExecState **found = by_mover.getptr(id);
	if (found != nullptr) {
		return *found;
	}
	if (!create) {
		return nullptr;
	}
	ExecState *state = new ExecState();
	by_mover.insert(id, state);
	return state;
}

void ExecStates::forget(Object *mover) {
	if (mover == nullptr) {
		return;
	}
	const uint64_t id = mover->get_instance_id();
	ExecState **found = by_mover.getptr(id);
	if (found != nullptr) {
		delete *found;
		by_mover.erase(id);
	}
}

void ExecStates::sweep(int64_t frame) {
	if (frame == swept_frame) {
		return;
	}
	swept_frame = frame;
	LocalVector<uint64_t> gone;
	for (const KeyValue<uint64_t, ExecState *> &e : by_mover) {
		if (ObjectDB::get_instance(e.key) == nullptr) {
			gone.push_back(e.key);
		}
	}
	for (uint64_t id : gone) {
		delete by_mover[id];
		by_mover.erase(id);
	}
}

void ExecStates::clear() {
	for (KeyValue<uint64_t, ExecState *> &e : by_mover) {
		delete e.value;
	}
	by_mover.clear();
}

Array exec_field_table() {
	Array out;
#define EXEC_TABLE(owner, t, vt, n)                                                   \
	{                                                                                 \
		Array row;                                                                    \
		row.push_back(owner);                                                         \
		row.push_back(String(#n));                                                    \
		row.push_back((int64_t)Variant::vt);                                          \
		out.push_back(row);                                                           \
	}
#define EXEC_TABLE_M(t, vt, n) EXEC_TABLE(0, t, vt, n)
#define EXEC_TABLE_G(t, vt, n) EXEC_TABLE(1, t, vt, n)
#define EXEC_TABLE_L(t, vt, n) EXEC_TABLE(2, t, vt, n)
	EXEC_MOVER_FIELDS(EXEC_TABLE_M)
	EXEC_GUNNERY_FIELDS(EXEC_TABLE_G)
	EXEC_LAY_FIELDS(EXEC_TABLE_L)
#undef EXEC_TABLE_M
#undef EXEC_TABLE_G
#undef EXEC_TABLE_L
#undef EXEC_TABLE
	return out;
}

} // namespace godot
