// Round 28 (native N7.2): the suppression field in C++ -- ThreatField's stamps and decay (game/combat/threat_field.gd)
// and Match._update_suppression (the fade, then every living crew settled to the fire where it stands, Tank's
// settle_suppression and its sight / hull-turn effects, the stats). The field's state stays in the GDScript object's
// packed arrays (density float32, _active, _is_active), worked on in place. tests/test_native_threat.gd holds it to the
// live GDScript; native-proof `threat`.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

struct ThreatConfig {
	bool ready = false;
	double MARCH_FRACTION = 0.5, EPSILON = 0.0005, HALF_LIFE_SECONDS = 1.0, TICK_RATE = 30.0;
	double SUPPRESSION_FULL_DENSITY = 3.0, PINNED_SUPPRESSION = 0.6, SUPPRESSION_RISE_PER_SECOND = 0.6,
		   SUPPRESSION_RECOVER_PER_SECOND = 0.3, SUPPRESSION_SIGHT_PENALTY = 0.4, SUPPRESSION_HULL_TURN_PENALTY = 0.5;
};

bool threat_configure(ThreatConfig &c, const Dictionary &config);
void threat_stamp_point(const ThreatConfig &c, Object *field, const Vector3 &point, double weight);
void threat_stamp_segment(const ThreatConfig &c, Object *field, const Vector3 &from, const Vector3 &to, double weight);
void threat_stamp_burst(const ThreatConfig &c, Object *field, const Vector3 &center, double radius, double weight);
void threat_decay(const ThreatConfig &c, Object *field, int64_t ticks);
// Match._update_suppression after its first line: `fields` is [threat_field(0), threat_field(1)], `tanks` the sorted
// tanks, `stats` Match.stats.
void suppression_update(const ThreatConfig &c, const Array &fields, const Array &tanks, const Dictionary &stats,
		int64_t sample_ticks);

} // namespace godot
