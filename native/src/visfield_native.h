// Round 48 (native, R48.8): VisibilityField.look_from's ray fan in C++ (visfield_native.cpp).
#pragma once

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

// [reach: PackedFloat32Array, fan: PackedVector2Array]: look_from's loop's answer for `viewer`'s world.
Array visfield_rays(Object *viewer, const Vector3 &eye, double radius, const PackedVector3Array &directions, int64_t mask);

} // namespace godot
