class_name FormationFit
extends RefCounted
## Round 18 (picker, stretch b): does a formation FIT where the squad stands? The one adapter between the Formation
## panel and the seating code (lesson 247: the badge is what the game does, not a proxy). It asks
## `Orders.preview_group` for the orders a player's move to the squad's own centre in that formation would seat --
## the same `_resolve_group` that issues them: the formation the group really takes, each goal grounded by
## `SlotGround.for_unit` (its hull's envelope clear of walls) and kept apart by `SlotGround.apart`. Those two live in
## game/tactics (brains'), so `tests/test_control_formation_picker.gd` pins their signatures and fails loudly if either
## changes under this.
##
## SQUEEZED when any vehicle's slot had to move SQUEEZE_M or more to stand somewhere, or when the group would take a
## different shape than the one asked for; FITS otherwise. It is about HERE (the ground under the squad when the panel
## opened), never about where the next order will send it.

## A slot moved this far onto standable ground counts as squeezed. The unit card says "slot moved N m clear of a wall"
## from 1 m (SelectionPanel._order_words), so the badge and the card agree on what moving means.
const SQUEEZE_M := 1.0


## {"fits": bool, "moved_m": the largest slot move, "shape": the formation the group would take, "units": int} for
## `names` in `formation` at their own centre. {} when there is nothing to say (fewer than two living units, no orders).
static func check(orders: Orders, names: Array, formation: String) -> Dictionary:
	if orders == null or names.size() < 2:
		return {}
	var centre: Variant = _centre(orders, names)
	if centre == null:
		return {}
	var seated := orders.preview_group(names, formation, centre)
	if seated.size() < 2:
		return {}
	var moved := 0.0
	var shape := ""
	for unit_name: String in seated:
		var order: Dictionary = seated[unit_name]
		moved = maxf(moved, float(order.get("grounded_m", 0.0)))
		shape = String(order.get("formation", ""))
	var asked := formation if formation != UnitCommand.AUTO else shape
	return {"fits": moved < SQUEEZE_M and shape == asked, "moved_m": moved, "shape": shape, "units": seated.size()}


static func _centre(orders: Orders, names: Array) -> Variant:
	var sum := Vector3.ZERO
	var count := 0
	for unit_name in names:
		var tank := orders._tank(String(unit_name))
		if tank != null and tank.is_alive():
			sum += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			count += 1
	return sum / count if count >= 2 else null
