class_name NativeWall
extends RefCounted
## Round 29 (native N7.4): the wall-contact observer's per-tick scan natively (native/src/wall_native.cpp): whether there
## is a slide to read, the deepest wall among the last slide's collisions and whether a hull was touched. The seam is
## the top of WallContact.observe; a tick that touched a wall is classified by the GDScript, which stays the reference.
## BrainSwitches.native_wall.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_wall and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("wall")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.wall_configure({"WALL_NORMAL_MAX_Y": WallContact.WALL_NORMAL_MAX_Y,
			"tank_script": load("res://game/tank/tank.gd")})
	return _ok
