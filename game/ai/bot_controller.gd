class_name BotController
extends OrderController
## The dumbest reasonable opponent: head for the nearest enemy, stop and shoot
## once it's in sight and in range. Runs on the server only.
##
## It deliberately "knows" where hidden enemies are (it has no scouting or
## memory). It exists as the baseline to beat: smoke tests and the agent bridge
## play against it today, and experiment E3's "random/naive doctrine" will look
## a lot like it. Real AI replaces `think()` (M4).

const THINK_INTERVAL := 0.5
## Stop advancing once a visible enemy is this close.
const PREFERRED_RANGE := 45.0

var _think_left := 0.0


func think(delta: float) -> void:
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = THINK_INTERVAL
	weapon_order = {"type": "fire_at_will"}
	var enemy := Perception.nearest_enemy(tank, tanks_root, false)
	if enemy == null:
		move_order = {"type": "stop"}
		return
	var distance := tank.global_position.distance_to(enemy.global_position)
	if distance <= PREFERRED_RANGE and Perception.has_line_of_sight(tank, enemy):
		move_order = {"type": "stop"}
	else:
		move_order = {"type": "move_to", "x": enemy.global_position.x, "z": enemy.global_position.z}
