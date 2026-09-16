extends Node3D
## `fx.shell` for the cyberpunk theme: no mesh of its own. It registers with the shared
## TracerSystem, which draws every shell in one batched tracer + ground-splat pass and lends it a pooled light when it
## deserves one. Colored by the shell's team and styled by its weapon's fire model (a tank shell is a fat glowing slug,
## an autocannon round a short bright tracer, an arcing mortar round in between).
##
## A shell that flies out of range without hitting anything fizzles into the dirt below where it gave out (the Shell just
## expires in mid-air and K2 reports nothing for it), so a miss still reads as a miss.


func _ready() -> void:
	var fx := FxWorld.get_instance()
	if fx == null:
		return
	var shell := _shell()
	var style := "arc" if _is_arc() else _fire_model(fx, shell)
	var tagged: Variant = _tagged("fire_model")
	if tagged != null and TracerSystem.STYLES.has(String(tagged)):
		style = String(tagged)  # the FX lab tags its stand-in rounds
	fx.add_tracer(self, GameTheme.team_glow(_team()), style)
	if shell != null and shell.has_signal("expired"):
		shell.connect("expired", _on_expired)


func _exit_tree() -> void:
	var fx := FxWorld.existing()
	if fx != null:
		fx.remove_tracer(self)


func _on_expired(_shell_node: Node) -> void:
	var fx := FxWorld.existing()
	# K2 reports nothing for a round that flies out of range, so the fizzle is drawn in both modes.
	if fx != null:
		var shell := _shell()
		fx.weapons.fizzle(global_position, -global_basis.z, _fire_model(fx, shell), shell.get("ray_start") if shell != null else null,
				String(shell.get("shooter_name")) if shell != null else "")


## The Shell this visual belongs to (VisualSlot → Shell), found by its shooter_name; read-only duck typing.
func _shell() -> Node:
	var node := get_parent()
	while node != null:
		if node.get("shooter_name") is String:
			return node
		node = node.get_parent()
	return null


func _is_arc() -> bool:
	var node := get_parent()
	while node != null:
		if node is ArcRoundVisual:
			return true
		node = node.get_parent()
	return false


func _fire_model(fx: FxWorld, shell: Node) -> String:
	if shell == null:
		return "default"
	var shooter := fx.link.find_unit(String(shell.get("shooter_name")))
	if shooter == null or not (shooter.get("weapon") is Dictionary):
		return "default"
	var model := K2Events.fire_model(shooter.get("weapon"))
	return model if TracerSystem.STYLES.has(model) else "default"


## The shell this visual belongs to (VisualSlot → Shell) knows its team; read-only duck typing.
func _team() -> int:
	var node := get_parent()
	while node != null:
		var team: Variant = node.get("team")
		if team is int:
			return team
		node = node.get_parent()
	var tagged: Variant = _tagged("team")
	return int(tagged) if tagged != null else 0


## A meta value on the nearest ancestor that has it (the FX lab's rounds), or null.
func _tagged(key: String) -> Variant:
	var node := get_parent()
	while node != null:
		if node.has_meta(key):
			return node.get_meta(key)
		node = node.get_parent()
	return null
