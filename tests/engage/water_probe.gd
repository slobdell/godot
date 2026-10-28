extends SceneTree
## Round 43 (engage A7, R43.5 / R43.21): THE ENGAGE-ACROSS-WATER CENSUS. On his Locks seed (A1's trace, ticks 556-694) a War Rig
## under attack-move chose ENGAGE on a Syndicate crew across the canal, 58-61 m away: team-seen, "own line" clear because the
## cover map knows walls and props but not water, inside the gun's range + 15 m hop margin, out of its range to hit; the
## combat move then hopped along the bank (one reverse hop 36 m) and swung the 14 m hull round. This probe stages a squad
## under attack-move across the canal (Locks on even seeds, Crossing on odd) with the CPU dug in on the far bank, and counts
## per crew-tick under an attack / attack-move order: the brain in ENGAGE or SUPPRESS on a contact whose straight leg crosses
## water (SlotGround.leg_wet), split by "could hit" (within the gun's range) and "cannot hit" (beyond it); the seconds of direct
## hops (and reverse hops) while in it; the largest rise of the crew's distance to its own order goal while in it; deaths,
## kills, the squad's arrival. One run = one seed; the arm is the A7 rule's switch (built after this census).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/water_probe.gd -- --seed=N [--arena=A] [--seconds=60] [--trace=on]
##         [--named=on] [--engage-water=off] [--brains-off=native_decide]
## Prints ENGAGE_WATER {json} once (read by tests/engage/water_table.py).

const ARRIVED_M := 20.0
const JITTER_M := 2.0
const PITCH_M := 9.0
const HULL_SETS := [
	["gang_tank", "gang_tank", "gang_ifv", "gang_tank", "gang_support"],
	["law_tank", "law_ifv", "law_scout", "law_tank", "law_ifv"],
	["gang_tank", "gang_ifv", "gang_scout", "gang_tank", "gang_scout"],
	["tank", "ifv", "scout", "tank", "ifv"],
]
## The census ran five defenders with a Railgun (dev 7001-7012: 4.75 of 5 attackers died, nobody arrived in 60 s); the bar's
## stage is three Limousines, so the squad's arrival and the named-attack cost can be read.
const DEFENDERS := ["syn_ifv", "syn_ifv", "syn_ifv"]
## Per arena: the squad's start (the near bank, by the crossing's approach), its attack-move point (the far-bank objective),
## the defenders' line (the far bank beside the crossing's exit) and their facing (toward the near bank).
const STAGES := {
	"locks": {"from": Vector3(-88, 0, 48), "to": Vector3(-72, 0, -24), "line": Vector3(-82, 0, -22), "face": Vector3(0, 0, 1)},
	"crossing": {"from": Vector3(-88, 0, 55), "to": Vector3(-76, 0, -22), "line": Vector3(-84, 0, -26), "face": Vector3(0, 0, 1)},
}

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _r(x: float) -> float:
	return snappedf(x, 0.1)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	var seed_value := int(_flag("seed", "7001"))
	var seconds := float(_flag("seconds", "60"))
	var trace := _flag("trace", "off") == "on"
	var arena := _flag("arena", "locks" if seed_value % 2 == 0 else "crossing")
	var stage: Dictionary = STAGES[arena]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hulls: Array = HULL_SETS[rng.randi_range(0, HULL_SETS.size() - 1)]
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var from: Vector3 = stage["from"]
	var to: Vector3 = stage["to"]
	var along := (to - from).normalized()
	var across := Vector3(-along.z, 0.0, along.x)
	var yaw := atan2(-along.x, -along.z)
	var names: Array = []
	for i in hulls.size():
		var rank := float(i / 3)
		var file := float(i % 3) - 1.0
		var at := from + across * file * PITCH_M - along * rank * PITCH_M \
				+ Vector3(rng.randf_range(-JITTER_M, JITTER_M), 0.0, rng.randf_range(-JITTER_M, JITTER_M))
		var face := yaw + deg_to_rad(rng.randf_range(-10.0, 10.0))
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), ElementPlan.clamp_to_arena(at), face, String(hulls[i])).name))
	var line: Vector3 = stage["line"]
	var face_dir: Vector3 = stage["face"]
	var line_across := Vector3(-face_dir.z, 0.0, face_dir.x)
	var defenders: Array = []
	for i in DEFENDERS.size():
		var at := line + line_across * (float(i) - float(DEFENDERS.size() - 1) * 0.5) * 10.0 + Vector3(rng.randf_range(-JITTER_M, JITTER_M), 0.0, rng.randf_range(-JITTER_M, JITTER_M))
		var face := atan2(-face_dir.x, -face_dir.z)
		defenders.append(String(lab.unit(Match.Team.RUST, "Rust_D_%d" % (i + 1), ElementPlan.clamp_to_arena(at), face, DEFENDERS[i]).name))
	await lab.start()
	for unit_name: String in names + defenders:
		var t := lab.tank_of(unit_name)
		var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
		t.global_position = Vector3(at.x, 0.0, at.z)
		t.velocity = Vector3.ZERO
	for i in 3:
		await lab.step()
	var element := lab.elements.form(names, "SquadA")
	# `--named=on` (Bar A7's guard 8): the squad's order is a named ATTACK on the nearest defender instead of the attack-move.
	var named := _flag("named", "off") == "on"
	if named:
		var nearest := ""
		var best := INF
		for unit_name: String in defenders:
			var d := _flat(lab.tank_of(unit_name).global_position).distance_to(from)
			if d < best:
				best = d
				nearest = unit_name
		element.assign({"verb": "attack", "target": nearest})
	else:
		element.assign({"verb": "move", "to": [to.x, to.z]})  # an attack-move: a move task with drills
	var guard := lab.elements.form(defenders, "Line")
	guard.assign({"verb": "hold", "to": [line.x, line.z], "facing": [face_dir.x, face_dir.z]})
	var given: int = game_match.tick
	var orders := lab.orders
	# Damage the squad's guns deal to the defenders while the whole living squad is across water from the victim (the impact
	# event names no shooter, so the attribution is by the squad's bank), and the first such hit: the gun firing across the
	# canal is fine (R43.21's note); moving for it is what looks dumb.
	var damage_water := 0.0
	var hits_water := 0
	var first_hit_s := -1.0
	var damage_total := 0.0  # every hit on the defenders, whichever bank the squad fires from
	var hits_total := 0
	var first_hit_any_s := -1.0
	var last_hp := {}
	for unit_name: String in defenders:
		var d := lab.tank_of(unit_name)
		last_hp[unit_name] = float(d.health) + d.shield
	var fire_ticks := 0
	var fire_far_ticks := 0
	var water_ticks := 0
	var water_far_ticks := 0
	var hop_ticks := 0
	var hop_rev_ticks := 0
	var hop_far_ticks := 0
	var crews_water := {}
	var crews_far := {}
	var off_order_m := 0.0
	var off_base := {}  # crew -> the distance to its order goal when it entered the water state
	var arrive := {}
	var rows := 0
	var total := int(seconds * SimClock.TICK_RATE)
	for tick in total:
		await lab.step()
		var now := game_match.tick - given
		for unit_name: String in defenders:
			var d := lab.tank_of(unit_name)
			if d == null:
				continue
			var hp := float(d.health) + d.shield if d.is_alive() else 0.0
			if hp < float(last_hp[unit_name]) - 0.01:
				damage_total += float(last_hp[unit_name]) - hp
				hits_total += 1
				if first_hit_any_s < 0.0:
					first_hit_any_s = float(now) / SimClock.TICK_RATE
				var across_all := true
				var any_alive := false
				for crew_name: String in names:
					var c := lab.tank_of(crew_name)
					if c == null or not c.is_alive():
						continue
					any_alive = true
					if not SlotGround.leg_wet(_flat(c.global_position), _flat(d.global_position)):
						across_all = false
						break
				if any_alive and across_all:
					damage_water += float(last_hp[unit_name]) - hp
					hits_water += 1
					if first_hit_s < 0.0:
						first_hit_s = float(now) / SimClock.TICK_RATE
			last_hp[unit_name] = hp
		for unit_name: String in names:
			var t := lab.tank_of(unit_name)
			if t == null or not t.is_alive():
				continue
			var here := _flat(t.global_position)
			if not arrive.has(unit_name) and here.distance_to(to) <= ARRIVED_M:
				arrive[unit_name] = float(now) / SimClock.TICK_RATE
			var order: Dictionary = orders.call("current", unit_name)
			var verb := String(order.get("verb", ""))
			if verb != "attack" and verb != "attack_move":
				off_base.erase(unit_name)
				continue
			var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
			if brain == null:
				continue
			var option := String(brain.choice.get("option", ""))
			var target := lab.tank_of(String(brain.choice.get("target", ""))) if option == "ENGAGE" or option == "SUPPRESS" else null
			if target == null or not target.is_alive():
				off_base.erase(unit_name)
				continue
			var tpos := _flat(target.global_position)
			if not SlotGround.leg_wet(here, tpos):
				off_base.erase(unit_name)
				continue
			var dist := here.distance_to(tpos)
			var reach := float(t.weapon.get("range", 0.0))
			var far := dist > reach
			var hop := String(brain.move_order.get("type", "")) == "move_to" and bool(brain.move_order.get("direct", false))
			var firing := brain.engaged_target == String(target.name)
			if firing:
				fire_ticks += 1
				if far:
					fire_far_ticks += 1
			water_ticks += 1
			crews_water[unit_name] = true
			if far:
				water_far_ticks += 1
				crews_far[unit_name] = true
				if hop:
					hop_far_ticks += 1
			if hop:
				hop_ticks += 1
				if bool(brain.move_order.get("reverse", false)):
					hop_rev_ticks += 1
			var goal: Variant = order.get("goal")
			if goal is Array and (goal as Array).size() >= 2:
				var d_goal := here.distance_to(Vector3(float(goal[0]), 0.0, float(goal[1])))
				if not off_base.has(unit_name):
					off_base[unit_name] = d_goal
				off_order_m = maxf(off_order_m, d_goal - float(off_base[unit_name]))
			if trace and now % 15 == 0:
				print("ENGAGE_WATER_TRACE t=%d %s at (%.1f, %.1f) %s %s on %s at %.1f m (range %.0f) far %s hop %s rev %s why '%s'" % [now, unit_name,
						here.x, here.z, verb, option, target.name, dist, reach, far, hop, brain.move_order.get("reverse", false), brain.why])
				rows += 1
	var arrivals: Array = []
	for unit_name: String in names:
		arrivals.append(float(arrive.get(unit_name, seconds)))
	var deaths := 0
	for unit_name: String in names:
		var t := lab.tank_of(unit_name)
		if t == null or not t.is_alive():
			deaths += 1
	var kills := 0
	for unit_name: String in defenders:
		var t := lab.tank_of(unit_name)
		if t == null or not t.is_alive():
			kills += 1
	var hz := float(SimClock.TICK_RATE)
	print("ENGAGE_WATER %s" % JSON.stringify({"seed": seed_value, "arena": arena, "hulls": hulls, "seconds": seconds,
			"arm": "on" if TankBrain.ENGAGE_WATER else "off", "named": named, "flags": " ".join(OS.get_cmdline_user_args()),
			"water_s": _r(water_ticks / hz), "water_far_s": _r(water_far_ticks / hz), "fire_s": _r(fire_ticks / hz),
			"fire_far_s": _r(fire_far_ticks / hz), "damage_water": _r(damage_water), "hits_water": hits_water, "first_hit_water_s": _r(first_hit_s),
			"damage_total": _r(damage_total), "hits_total": hits_total, "first_hit_s": _r(first_hit_any_s),
			"hop_s": _r(hop_ticks / hz),
			"hop_rev_s": _r(hop_rev_ticks / hz), "hop_far_s": _r(hop_far_ticks / hz), "crews_water": crews_water.size(),
			"crews_far": crews_far.size(), "off_order_m": _r(off_order_m), "arrivals": arrivals, "last_a_s": arrivals.max(),
			"deaths": deaths, "kills": kills, "rows": rows}))
	print("ENGAGE_WATER_DONE")
	lab.dispose()
	quit(0)
