class_name DeployPassers
extends RefCounted
## X3b (round 35 extension, R35.17/R35.74): the friendly crews of OTHER elements near a squad whose deploy is pending,
## each {"position", "velocity", "to"} (`to` = its element's destination, null when it has none), for
## ElementPlan.deploy_passing. Gathered only while ElementPlan.DEPLOY_PASS is on and the deploy is pending (Element's hook).

const GATHER_M := 30.0


static func of(game_match: Match, element: Element, situation: Dictionary) -> Array:
	var out: Array = []
	var elements := Elements.of_match(game_match)
	if elements == null:
		return out
	var center: Vector3 = situation.get("center", Vector3.ZERO)
	var mine := {}
	for unit_name in element.members():
		mine[String(unit_name)] = true
	var tanks: Dictionary = AiTickCache.tanks_by_name(game_match)
	for other: Element in elements.of_team(element.team):
		if other == element:
			continue
		var to: Variant = ElementTask.destination(other.task)
		for unit_name in other.members():
			if mine.has(String(unit_name)):
				continue
			var tank := tanks.get(String(unit_name)) as Tank
			if tank == null or not is_instance_valid(tank):
				continue
			var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			if Vector2(at.x - center.x, at.z - center.z).length() > GATHER_M:
				continue
			out.append({"position": at, "velocity": Vector3(tank.velocity.x, 0.0, tank.velocity.z), "to": to})
	return out
