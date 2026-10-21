extends Node3D
## Round 36 (native, E4b): the first-tick sync repro's two bodies, its driver, and its main-scene arm (`main_ready`: the bodies
## built in a main scene's _ready, where real play's `--skirmish` spawns its squads). first_tick_sync.gd runs the other arms.
##
## Two CharacterBody3D boxes 4 m wide, 1 m overlapped, placed by `global_position =` AFTER add_child, then driven at rest by
## move_and_slide in a node's _physics_process. A placement reaches the physics server only at the SceneTree's next transform
## flush, so what the space holds at the bodies' FIRST tick depends on where the setup ran, not on any engine state:
##   synced -- the space holds the placement (B.x 3.00) and the pair separates once, to -0.871 / 3.871, and stays;
##   stale  -- the space still holds the add-time origin (B.x 0.00) and penetration recovery throws them over each other.

class Driver:
	extends Node
	var a: CharacterBody3D
	var b: CharacterBody3D
	var ticks := 0
	var line := ""

	func _physics_process(_delta: float) -> void:
		if ticks == 0:
			var held: Transform3D = PhysicsServer3D.body_get_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
			line += "first-tick space B.x=%.2f |" % held.origin.x
		a.move_and_slide()
		b.move_and_slide()
		line += " t%d A.x=%.3f B.x=%.3f" % [ticks, a.global_position.x, b.global_position.x]
		ticks += 1


var _driver: Driver
var _frames := 0


static func body(parent: Node, body_name: String, x: float) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.name = body_name
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 2, 6)
	collision.shape = box
	b.add_child(collision)
	parent.add_child(b)
	b.global_position = Vector3(x, 1, 0)
	return b


static func build(parent: Node) -> Driver:
	var driver := Driver.new()
	driver.a = body(parent, "A", 0.0)
	driver.b = body(parent, "B", 3.0)
	parent.add_child(driver)
	return driver


static func context() -> String:
	return "physics=%d process=%d in_physics=%s" % [Engine.get_physics_frames(), Engine.get_process_frames(),
			Engine.is_in_physics_frame()]


static func report(arm: String, at: String, driver: Driver) -> void:
	var synced := driver.line.begins_with("first-tick space B.x=3.00")
	print("FIRST_TICK_SYNC %-14s %-6s (setup at %s) %s" % [arm, "synced" if synced else "stale", at, driver.line])


var _at := ""


func _ready() -> void:
	_at = context()
	_driver = build(self)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 8:
		report("main_ready", _at, _driver)
		get_tree().quit()
