class_name NativeFeed
extends RefCounted
## Round 30 (native N7.5): ElementFeed's two builders natively (native/src/feed_native.cpp): `_shared` (the element-wide
## half of a crew's context) and `_normalize` (the crew's own context), from the element's feed_state(). The memo
## (ElementFeed._ctx_memo, keyed by Element.feed_key) stays GDScript: measured on builder0 (foundry 25 a side) nearly
## every normalize call is a build (~10 a tick, ~22 us each in GDScript) because every Element.update bumps the key.
## BrainSwitches.native_feed. tests/test_native_feed.gd holds both builders to the GDScript.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_feed and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("feed")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.feed_configure({"TECHNIQUES": ElementFeed.TECHNIQUES, "DRILLS": ElementFeed.DRILLS,
			"TASKS": ElementFeed.TASKS, "ROLES": ElementFeed.ROLES})
	return _ok


static func shared(element: Object) -> Dictionary:
	return NativeBridge.impl.feed_shared(element, ElementFeed.FEED_CACHE)


static func normalize(element: Object, unit_name: String, order_verb: String, shared_half: Dictionary) -> Dictionary:
	return NativeBridge.impl.feed_normalize(element, unit_name, order_verb, shared_half, ElementFeed.FEED_CACHE,
			Traffic.off("slide"))
