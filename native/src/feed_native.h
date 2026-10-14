// Round 30 (native N7.5): the brains' element feed natively -- ElementFeed._shared and ElementFeed._normalize
// (game/ai/element_feed.gd): the element-wide half of a crew's context and the crew's own context, built from the
// element's feed_state() dictionary. The memo (ElementFeed._ctx_memo, keyed by Element.feed_key) stays GDScript; these
// are its two builders, which are nearly every call (builder0 foundry 25 a side: ~10 context builds and ~3 element-wide
// builds a tick, ~10.4 normalize calls). The dictionaries come out with the GDScript's keys (String), values and
// insertion order. tests/test_native_feed.gd holds both to the live GDScript.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

struct FeedConfig {
	bool ready = false;
	// ElementFeed.TECHNIQUES / DRILLS / TASKS / ROLES, handed over once so the lists cannot drift.
	Array TECHNIQUES, DRILLS, TASKS, ROLES;
};

bool feed_configure(FeedConfig &config, const Dictionary &from);
// ElementFeed._shared(element): {} when the source publishes no state. `use_feed_state` is ElementFeed.FEED_CACHE.
Dictionary feed_shared(const FeedConfig &config, Object *element, bool use_feed_state);
// ElementFeed._normalize(element, unit_name, order_verb, shared): `shared` empty -> built here first ({} when the source
// publishes none). `slide_off` is Traffic.off("slide"), asked by the caller on every call.
Dictionary feed_normalize(const FeedConfig &config, Object *element, const String &unit_name, const String &order_verb,
		const Dictionary &shared, bool use_feed_state, bool slide_off);

} // namespace godot
