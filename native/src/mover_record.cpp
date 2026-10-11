#include "mover_record.h"

#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

namespace {
struct MrNames {
	StringName alive{ "alive" }, ctl{ "ctl" }, gunnery{ "gunnery" }, engagement_lay{ "engagement_lay" };
};
const MrNames &mr_names_() {
	static const MrNames n;
	return n;
}
const char *const PREFIX[3] = { "m:", "g:", "l:" };
} // namespace

int MoverRecord::configure(const Array &spec, PackedStringArray &rejected) {
	fields.clear();
	for (int k = 0; k < 6; k++) {
		strides[k] = 0;
	}
	rejected.clear();
	for (int i = 0; i < spec.size(); i++) {
		const Array entry = spec[i];
		if (entry.size() < 3) {
			continue;
		}
		const int owner = entry[0];
		const String name = entry[1];
		const int type = entry[2];
		Kind kind;
		switch (type) {
			case Variant::BOOL: kind = K_BOOL; break;
			case Variant::INT: kind = K_INT; break;
			case Variant::FLOAT: kind = K_FLOAT; break;
			case Variant::STRING:
			case Variant::STRING_NAME: kind = K_STRING; break;
			case Variant::VECTOR2: kind = K_VEC2; break;
			case Variant::VECTOR3: kind = K_VEC3; break;
			default:
				rejected.push_back(name);
				continue;
		}
		if (owner < MOVER || owner > LAY) {
			rejected.push_back(name);
			continue;
		}
		const int width = kind == K_VEC2 ? 2 : (kind == K_VEC3 ? 3 : 1);
		fields.push_back(Field{ (Owner)owner, kind, StringName(name), strides[kind] });
		strides[kind] += width;
	}
	return (int)fields.size();
}

int MoverRecord::gather(Node *root, const Dictionary &registry) {
	if (!on) {
		return -1;
	}
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	const MrNames &k = mr_names_();
	LocalVector<Node *> rows;
	if (root != nullptr) {
		const int children = root->get_child_count();
		rows.reserve(children);
		for (int i = 0; i < children; i++) {
			Node *child = root->get_child(i);
			const Variant alive = child->get(k.alive);
			if (alive.get_type() == Variant::BOOL && (bool)alive) {
				rows.push_back(child);
			}
		}
	}
	const int n = rows.size();
	names.resize(n);
	present.resize(n);
	bools.resize(n * strides[K_BOOL]);
	ints.resize(n * strides[K_INT]);
	floats.resize(n * strides[K_FLOAT]);
	strings.resize(n * strides[K_STRING]);
	const int vec_stride = strides[K_VEC2] + strides[K_VEC3];
	vecs.resize(n * vec_stride);
	type_mismatches = 0;
	for (int r = 0; r < n; r++) {
		Node *tank = rows[r];
		names.set(r, tank->get_name());
		Object *owners[3] = { nullptr, nullptr, nullptr };
		owners[MOVER] = registry.get((int64_t)tank->get_instance_id(), Variant()).get_validated_object();
		if (owners[MOVER] != nullptr) {
			Object *ctl = owners[MOVER]->get(k.ctl).get_validated_object();
			if (ctl != nullptr) {
				owners[GUNNERY] = ctl->get(k.gunnery).get_validated_object();
			}
			if (owners[GUNNERY] != nullptr) {
				owners[LAY] = owners[GUNNERY]->get(k.engagement_lay).get_validated_object();
			}
		}
		present[r] = (owners[0] ? 1 : 0) | (owners[1] ? 2 : 0) | (owners[2] ? 4 : 0);
		for (uint32_t f = 0; f < fields.size(); f++) {
			const Field &field = fields[f];
			Object *owner = owners[field.owner];
			const Variant v = owner != nullptr ? owner->get(field.name) : Variant();
			switch (field.kind) {
				case K_BOOL: {
					const bool ok = v.get_type() == Variant::BOOL;
					type_mismatches += (owner != nullptr && !ok) ? 1 : 0;
					bools[r * strides[K_BOOL] + field.offset] = ok && (bool)v ? 1 : 0;
				} break;
				case K_INT: {
					const bool ok = v.get_type() == Variant::INT;
					type_mismatches += (owner != nullptr && !ok) ? 1 : 0;
					ints[r * strides[K_INT] + field.offset] = ok ? (int64_t)v : 0;
				} break;
				case K_FLOAT: {
					const bool ok = v.get_type() == Variant::FLOAT;
					type_mismatches += (owner != nullptr && !ok) ? 1 : 0;
					floats[r * strides[K_FLOAT] + field.offset] = ok ? (double)v : 0.0;
				} break;
				case K_STRING: {
					const bool ok = v.get_type() == Variant::STRING || v.get_type() == Variant::STRING_NAME;
					type_mismatches += (owner != nullptr && !ok) ? 1 : 0;
					strings[r * strides[K_STRING] + field.offset] = ok ? String(v) : String();
				} break;
				case K_VEC2: {
					const bool ok = v.get_type() == Variant::VECTOR2;
					type_mismatches += (owner != nullptr && !ok) ? 1 : 0;
					const Vector2 a = ok ? (Vector2)v : Vector2();
					float *slot = vecs.ptr() + r * vec_stride + field.offset;
					slot[0] = a.x;
					slot[1] = a.y;
				} break;
				case K_VEC3: {
					const bool ok = v.get_type() == Variant::VECTOR3;
					type_mismatches += (owner != nullptr && !ok) ? 1 : 0;
					const Vector3 a = ok ? (Vector3)v : Vector3();
					float *slot = vecs.ptr() + r * vec_stride + strides[K_VEC2] + field.offset;
					slot[0] = a.x;
					slot[1] = a.y;
					slot[2] = a.z;
				} break;
			}
		}
	}
	last_usec = (int64_t)(Time::get_singleton()->get_ticks_usec() - t0);
	return n;
}

Dictionary MoverRecord::row(int r) const {
	Dictionary out;
	if (r < 0 || r >= size()) {
		return out;
	}
	out["name"] = names[r];
	out["present"] = (int64_t)present[r];
	const int vec_stride = strides[K_VEC2] + strides[K_VEC3];
	for (uint32_t f = 0; f < fields.size(); f++) {
		const Field &field = fields[f];
		const String key = String(PREFIX[field.owner]) + String(field.name);
		switch (field.kind) {
			case K_BOOL: out[key] = bools[r * strides[K_BOOL] + field.offset] != 0; break;
			case K_INT: out[key] = ints[r * strides[K_INT] + field.offset]; break;
			case K_FLOAT: out[key] = floats[r * strides[K_FLOAT] + field.offset]; break;
			case K_STRING: out[key] = strings[r * strides[K_STRING] + field.offset]; break;
			case K_VEC2: {
				const float *slot = vecs.ptr() + r * vec_stride + field.offset;
				out[key] = Vector2(slot[0], slot[1]);
			} break;
			case K_VEC3: {
				const float *slot = vecs.ptr() + r * vec_stride + strides[K_VEC2] + field.offset;
				out[key] = Vector3(slot[0], slot[1], slot[2]);
			} break;
		}
	}
	return out;
}

} // namespace godot
