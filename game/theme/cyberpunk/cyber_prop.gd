extends Node3D
## Base for cyberpunk props and dressing: registers wet-floor reflection streaks under this prop's
## lights with the shared StreakSystem (one batched draw for the whole arena) and removes them when
## the prop leaves the tree. No-op on headless peers.

var _streak_ids: Array[int] = []


## A reflection streak under a light at `local` (this node's space).
func add_streak(local: Vector3, color: Color, length := 9.0, width := 1.6, intensity := 0.6) -> void:
	var fx := FxWorld.get_instance()
	if fx != null:
		_streak_ids.append(fx.streaks.add(to_global(local), color, length, width, intensity))


func _exit_tree() -> void:
	var fx := FxWorld.existing()
	if fx != null:
		for id in _streak_ids:
			fx.streaks.remove(id)
	_streak_ids.clear()
