class_name NativeTraffic
extends RefCounted
## Round 29 (native, C29.2: traffic's T1 street hold in the native drive). The hold's table work (Traffic.refresh, the
## street meeting's look, the waits and spots in Traffic.hold_of) stays traffic's GDScript; the native drive
## (drive_native.cpp) calls `avoid_hold` back once at the top of _avoid, where the GDScript asks it, and reads
## Traffic.holding natively from Traffic's `_live` table. On a tree without the hold (no Traffic.hold_of) the drive's
## configuration leaves it out and the drive is as before. Traffic is reached by name (call / constant map) so this file
## parses on either tree.


## The keys drive_configure reads for the hold, or {} when Traffic has none.
static func drive_config() -> Dictionary:
	var consts := (Traffic as Script).get_script_constant_map()
	var methods := {}
	for method: Dictionary in (Traffic as Script).get_script_method_list():
		methods[String(method["name"])] = true
	if not (methods.has("hold_of") and methods.has("refresh") and consts.has("HOLD_REACHED_M")
			and consts.has("HOLD_SLOW_M") and consts.has("LIVE_TICKS")):
		return {}
	return {"traffic": Traffic, "native_traffic": NativeTraffic, "HOLD_REACHED_M": float(consts["HOLD_REACHED_M"]),
			"HOLD_SLOW_M": float(consts["HOLD_SLOW_M"]), "LIVE_TICKS": int(consts["LIVE_TICKS"])}


## Movement._avoid's first lines (when not `held`): `if not Traffic.off("hold"): Traffic.refresh(ctl.tanks_root);
## return Traffic.hold_of(name)`; [] = no hold.
static func avoid_hold(crew: String, tanks_root: Node) -> Array:
	if Traffic.off("hold"):
		return []
	Traffic.call("refresh", tanks_root)
	return Traffic.call("hold_of", crew)
