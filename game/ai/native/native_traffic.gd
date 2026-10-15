class_name NativeTraffic
extends RefCounted
## Round 29 (native, C29.2: traffic's T1 street hold in the native drive; round 31: T3b's crossing, `avoid_shape`). The hold's table work (Traffic.refresh, the
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
			"HOLD_SLOW_M": float(consts["HOLD_SLOW_M"]), "LIVE_TICKS": int(consts["LIVE_TICKS"]),
			"traffic_shape": methods.has("shape")}


## Movement._avoid's first lines (when not `held`): `if not Traffic.off("hold"): Traffic.refresh(ctl.tanks_root);
## return Traffic.hold_of(name)`; [] = no hold.
static func avoid_hold(crew: String, tanks_root: Node) -> Array:
	if Traffic.off("hold"):
		return []
	var script: Script = Traffic
	script.call("refresh", tanks_root)
	return script.call("hold_of", crew)


## Round 31 (traffic T3b, C31.2: the crossing in the native drive). Movement._avoid, once the route's wish is known (when
## not `held`): `if not Traffic.off("turns"): Traffic.refresh(ctl.tanks_root); preferred = Traffic.shape(name,
## route_preferred)`. The crossing's table work and verdicts stay traffic's GDScript, as the hold's do.
static func avoid_shape(crew: String, tanks_root: Node, route_preferred: Vector2) -> Vector2:
	if Traffic.off("turns"):
		return route_preferred
	var script: Script = Traffic
	script.call("refresh", tanks_root)
	return script.call("shape", crew, route_preferred)
