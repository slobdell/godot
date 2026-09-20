extends SceneTree
## `make nav-fight` (nav, round 7): WHY a unit is not getting where it was sent, IN A REAL FIGHT. The lead (2026-09-19):
## *"a lot of them just keep getting stuck in places, and that's I think why I'm feeling like the units aren't obeying
## me."* Round 6 measured 100% arrival and 30/30 order completion — both with no enemy (lesson 23 again). This is the
## configuration he plays: two seeded CPU-rostered armies of ~30 on a shipping arena, fighting, with GREEN commanded
## through control's Orders the way a player right-clicks (and control's elements installed, as in a skirmish).
##
## Every tick, every living GREEN unit that has an order and is not at its goal is put in exactly ONE bucket:
##   progressing        closing on its order's goal at > PROGRESS_MPS
##   yielding           giving way to a friend (nav X4)
##   blocked_<cause>    Movement says blocked: a friend's name → blocked_friend, an enemy's → blocked_enemy,
##                      terrain, or no_path (the goal is unreachable: the route only gets it near)
##   halted_shooting    its move order is stop/face and its gun is engaged
##   halted             stop/face with nothing engaged
##   retasked:<OPTION>  it is driving, but to somewhere else than its order (its brain chose OPTION; > RETASK_M away)
##   slow               driving toward its order's goal but under PROGRESS_MPS (turning, crowded, pathing)
## plus: re-task EVENTS (its move target jumping > RETASK_M), unreachable-route ticks, arrivals per order.
## Prints `NAV_FIGHT <json>`. Diagnosis, not a gate.

## S3 (metrics, round 9): --trajectory=PATH writes the per-tick trajectory log `make metrics` reads.
## Off unless the flag is given; the writer is metrics' (tools/metrics/), and this file only turns it on.
const TRAJECTORY := preload("res://tools/metrics/trajectory_log.gd")
const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const PROGRESS_MPS := 0.7
const RETASK_M := 8.0
const AT_GOAL_M := 8.0

var game_match: Match
var orders: Orders
var green: Array[Tank] = []
var buckets := {}        # reason -> ticks
var options := {}        # brain option while retasked -> ticks
var halted_as := {}      # brain option while halted -> ticks
var by_verb := {}        # order verb -> {reason -> ticks, "_ticks": ordered ticks under that verb}
var retask_by_verb := {} # order verb -> re-task events
var retask_cause := {}   # "OPTION[ hop][ (switched from X)]" -> re-task events
var last_option := {}    # name -> brain option last tick
var retask_events := 0
var unreachable_ticks := 0
var last_target := {}    # name -> Vector3 (its controller's move_to target last tick)
var last_distance := {}  # name -> distance to its order's goal last tick
var ordered_ticks := 0
var arrivals := 0
var order_count := 0
var issued_tick := 0
var time_limit := 120.0
var phase_two_done := false
## --busy=N: like a player, a new move order to one squad every N seconds (seeded, so reproducible). 0 = off.
var busy_every := 0.0
var busy_rng := RandomNumberGenerator.new()
var busy_next := 0.0
var busy_orders := 0
## Round 9 (N0): unit-orders issued carrying a `facing`, and whether the hold-on-a-facing leg went out. These are the
## run's own positive control for the arrival arc: `facings_issued` 0 means the arc could not have fired, whatever the
## gate counter says.
## A1: "<cause>/<order source>/<verb>" -> re-plans. The denominator for "whose churn is it".
var replan_owner := {}
var facings_issued := 0
var holds_issued := 0
var hold_done := false
var stall_verb := ""
## Round 8, pre-registered before its first run (the lead: "the semi trucks are yawing in place (should be impossible,
## they're not a tracker vehicle)"): an IN-PLACE YAW is a WHEELED hull, alive, whose heading changes by >= 30 degrees over
## a 2 s window while its centre moves < 1.5 m over the same window. Counted per unit type, whatever its orders (the
## lead watched the whole battlefield, not only ordered units). NAV_FIGHT reports inplace_yaw_events by unit type.
const INPLACE_WINDOW_S := 2.0
const INPLACE_DEG := 30.0
const INPLACE_M := 1.5
var inplace_trail := {}   # name -> Array of [x, z, heading_deg]
var inplace_events := {}  # unit_id -> count
var inplace_cooldown := {} # name -> ticks left (one event per window, not one per tick)
## Diagnostics beside the pre-registered count (added after its first run; they don't change what counts as an event):
## per unit type, the wheeled unit-seconds alive (so events become a rate), and each event split by its NET heading change
## over the window — "turned" (net >= 30 degrees: a real rotation near one spot, e.g. a K-turn) or "wobble" (the summed
## |change| reached 30 but the hull ended within 30 degrees of where it started: steering jitter) — and by path length
## ("crept" when the centre travelled >= 1.5 m along its trail while ending < 1.5 m away: shuffling back and forth).
var inplace_alive_ticks := {}  # unit_id -> ticks alive
var fielded := {}  # unit_id -> count at the start, both sides
var inplace_detail := {}  # unit_id -> {turned, wobble, crept}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	time_limit = float(_flag("time-limit", "120"))
	busy_every = float(_flag("busy", "0"))
	stall_verb = _flag("stall-verb", "")
	var seed_value := int(_flag("seed", "3"))
	busy_rng.seed = seed_value * 7919 + 17
	var budget := int(_flag("budget", "6500"))
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = _flag("arena", "yard")
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(seed_value, 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	await physics_frame
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var faction := _flag("green-faction" if team == Match.Team.GREEN else "rust-faction", "")
		# --green-army=cpu:<archetype> pins the archetype (the seed picks one otherwise: seed 3 fielded gang_hail on both
		# sides, so round 8's first gang run never had a semi on the field).
		var army := _flag("green-army" if team == Match.Team.GREEN else "rust-army", "cpu")
		var loaded := Army.load_army(army, seed_value + team, budget, faction)
		var error: String = loaded.get("error", "")
		if error == "":
			error = game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			push_error("nav-fight: " + error)
			quit(1)
			return
	orders = Orders.new()
	Orders.attach(game_match, orders)
	Elements.install(game_match, orders)
	for tank: Tank in game_match.tanks.get_children():
		if tank.team == Match.Team.GREEN:
			green.append(tank)
		fielded[tank.unit_id] = int(fielded.get(tank.unit_id, 0)) + 1
	# The run's own conditions, checked before any number is produced (arena's positive control, round 7): a number from
	# a run whose conditions weren't met looks exactly like a real one.
	if String(Arena.active.get("name", "")) != _flag("arena", "yard"):
		push_error("nav-fight control FAILED: asked for arena %s, got %s" % [_flag("arena", "yard"), Arena.active.get("name", "?")])
		quit(1)
		return
	var rust := 0
	for tank: Tank in game_match.tanks.get_children():
		rust += 1 if tank.team == Match.Team.RUST else 0
	if green.is_empty() or rust == 0:
		push_error("nav-fight control FAILED: armies of %d and %d units" % [green.size(), rust])
		quit(1)
		return
	# --require=<unit_id>[,<unit_id>]: the unit types the run is ABOUT must be on the field, or it refuses before any number
	# exists (round 8: a semi in-place-yaw run whose seed fielded no semis; a treatment arm without the treatment is a
	# failed run, not a null result — lesson 101).
	for required in _flag("require", "").split(",", false):
		if int(fielded.get(required, 0)) == 0:
			push_error("nav-fight control FAILED: --require=%s but none fielded (fielded %s)" % [required, fielded])
			quit(1)
			return
	var stacked := 0
	var all: Array = game_match.tanks.get_children()
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i] as Tank).global_position.distance_to((all[j] as Tank).global_position) < 1.0:
				stacked += 1
	# Stacked starts separate (Avoidance parts coincident hulls by name), so this is reported, not fatal.
	# The treatment, read live from the code under test (not from the flag passed): an A/B arm is only an arm if this
	# differs between them.
	# Every field here is read from the CODE UNDER TEST, never from the flag that was passed — `a7=` asks
	# `CombatMotion.a7_on()`, not `not switched_off("a7")`. The first version of this line did the latter, and the
	# moment A7's switch was inverted it printed `a7=false` on a run with `--nav-off=a7` set: an arm header that
	# confidently reports the opposite treatment, which is precisely how round 7 compared two byte-identical arms.
	print("NAV_FIGHT_ARM commit=%s holdband=%s fixed_style=%s a1=%s a7=%s a11=%s avoidance=%s station=%s off=%s" % [
			CombatMotion.commit_on(), CombatMotion.hold_band_on(), CombatMotion.fixed_style, Movement.a1_on(),
			CombatMotion.a7_on(), CombatMotion.a11_on(), Movement.avoidance_on, Movement.station_on, Movement._off])
	# Round 9: the arm counters start at zero for THIS run, so a number in the report is this run's (statics outlive a
	# single probe inside one process).
	CombatMotion.reset_arms()
	Movement.reset_gates()
	Movement.reset_route_arms()
	print("NAV_FIGHT_CONTROL arena %s, green %d, rust %d, %d pairs start on top of each other" % [
			Arena.active.get("name", "?"), green.size(), rust, stacked])
	TRAJECTORY.install(game_match, _flag("trajectory", ""), "nav-fight",
			{"seed": seed_value, "arena": _flag("arena", "yard"), "time_limit": time_limit, "busy": busy_every,
			"budget": budget, "stall_verb": stall_verb})
	for frame in SimClock.TICK_RATE:
		await physics_frame
	_order_squads(0.45)  # to the middle of the arena, squads fanned out across it
	issued_tick = game_match.tick
	print("NAV_FIGHT_ISSUED %d green units on %s, seed %d" % [green.size(), Arena.active.get("name", "?"), seed_value])
	physics_frame.connect(_sample)


## Round 9 (nav, N0): every A/B this round issues at least one order that CARRIES A FACING, so the arrival arc is a
## live arm by construction rather than by memory. Round 8's facing A/B compared two arms in which no order in the whole
## run ever carried one (`gates aimed 0` in both), and the run looked like a clean null. Squads alternate: even squads
## are told to arrive facing the way they travelled (the common player drag), odd squads to arrive facing 90 degrees
## across it (the demanding case — the hull has to come round on the approach). One squad is additionally told to HOLD
## on a facing, which is squad's KEEP_SLOT path and the lead's ambush case.
static func _facing_for(index: int, heading: Vector2) -> Array:
	if index % 2 == 0:
		return [heading.x, heading.y]
	return [-heading.y, heading.x]


## Order every GREEN squad (by name: Green_<squad>_<n>) to a lane point `depth` of the way toward the enemy base.
func _order_squads(depth: float) -> void:
	var squads := {}
	for tank in green:
		if not tank.is_alive():
			continue
		var parts := String(tank.name).split("_")
		var squad := parts[1] if parts.size() >= 3 else "?"
		if not squads.has(squad):
			squads[squad] = []
		(squads[squad] as Array).append(String(tank.name))
	var keys := squads.keys()
	keys.sort()
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var away := Match.spawn_position(Match.Team.RUST, 0)
	for i in keys.size():
		var lane := (float(i) - (keys.size() - 1) / 2.0) * 28.0
		var point := home.lerp(away, depth)
		var to := [point.x + lane, point.z]
		var verb := "move" if depth < 0.6 else "attack_move"
		var heading := Vector2(away.x - home.x, away.z - home.z).normalized()
		var extra := {"to": to, "facing": _facing_for(i, heading)}
		if orders.issue(UnitCommand.make(squads[keys[i]], verb, extra)) == "":
			order_count += (squads[keys[i]] as Array).size()
			facings_issued += (squads[keys[i]] as Array).size()


## A player's habit: pick one living squad and send it somewhere else on the field (a plain move — a right-click).
func _busy_order() -> void:
	var squads := {}
	for tank in green:
		if tank.is_alive():
			var parts := String(tank.name).split("_")
			var squad := parts[1] if parts.size() >= 3 else "?"
			if not squads.has(squad):
				squads[squad] = []
			(squads[squad] as Array).append(String(tank.name))
	if squads.is_empty():
		return
	var keys := squads.keys()
	keys.sort()
	var pick: String = keys[busy_rng.randi_range(0, keys.size() - 1)]
	var half := float(Arena.active.get("half_size", 120.0)) * 0.7
	var to := [busy_rng.randf_range(-half, half), busy_rng.randf_range(-half, half)]
	if orders.issue(UnitCommand.make(squads[pick], "move", {"to": to})) == "":
		busy_orders += 1


## Round 9 (N0): the second live path for a facing — a squad told to HOLD on a heading (squad's KEEP_SLOT / station
## path, and the lead's ambush case). A player's drag gives a move a facing; a hold gives the station one, which
## `TankBrain.intended_facing()` then hands to every later move the unit makes. Only the FIRST squad by name, so the
## rest of the fight is unchanged and the leg is identical in both arms of an A/B.
func _hold_on_a_facing() -> void:
	var squads := {}
	for tank in green:
		if tank.is_alive():
			var parts := String(tank.name).split("_")
			var squad := parts[1] if parts.size() >= 3 else "?"
			if not squads.has(squad):
				squads[squad] = []
			(squads[squad] as Array).append(String(tank.name))
	if squads.is_empty():
		return
	var keys := squads.keys()
	keys.sort()
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var away := Match.spawn_position(Match.Team.RUST, 0)
	var heading := Vector2(away.x - home.x, away.z - home.z).normalized()
	# Across the line of advance: a hold facing the way you already point asks the hull for nothing.
	if orders.issue(UnitCommand.make(squads[keys[0]], "hold", {"facing": [-heading.y, heading.x]})) == "":
		holds_issued += (squads[keys[0]] as Array).size()
		facings_issued += (squads[keys[0]] as Array).size()


## Round 8: gear flips. A wheeled hull changing between forward and reverse above GEAR_SPEED must brake through zero
## first, which is what the "shuffle" in an in-place-yaw event looks like. Counted per unit type per alive-minute, for
## every wheeled unit whatever its orders. Diagnostic: nothing is pre-registered on it yet.
const GEAR_SPEED := 0.5
var gear_sign := {}   # name -> -1 / 0 / 1
var gear_flips := {}  # unit_id -> count
## unit_id -> {path_m, net_m, windows, oscillating}: how far a hull of this type travels against how far it GETS,
## summed over the same 4 s windows the oscillation counter uses. `net_m / path_m` near 1 is driving somewhere;
## near 0 is shuffling.
var travelled := {}
var gear_detail := {} # unit_id -> {"phase:<x>": n, "reverse_order": n, "yielding": n}


func _controller_of(tank: Tank) -> OrderController:
	for node in game_match.brains.get_children():
		if node is OrderController and (node as OrderController).tank == tank:
			return node
	return null


func _sample_gear(tank: Tank) -> void:
	var speed := tank.speed()
	if absf(speed) < GEAR_SPEED:
		return
	var sign_now := signi(int(signf(speed)))
	var was := int(gear_sign.get(String(tank.name), 0))
	if was != 0 and sign_now != was:
		gear_flips[tank.unit_id] = int(gear_flips.get(tank.unit_id, 0)) + 1
		# Where the flip came from: the mover's phase, and whether the order it is driving asks for reverse (a yield
		# spot behind it, a retreat) rather than the brain's combat steering picking a reversing direction.
		var detail: Dictionary = gear_detail.get(tank.unit_id, {})
		var phase := "phase:" + String(Movement.state(tank).get("phase", "none"))
		detail[phase] = int(detail.get(phase, 0)) + 1
		var controller := _controller_of(tank)
		var order: Dictionary = controller.move_order if controller != null else {}
		detail["reverse_order"] = int(detail.get("reverse_order", 0)) + (1 if bool(order.get("reverse", false)) else 0)
		detail["order:" + String(order.get("type", "none"))] = int(detail.get("order:" + String(order.get("type", "none")), 0)) + 1
		gear_detail[tank.unit_id] = detail
	gear_sign[String(tank.name)] = sign_now


func _sample_inplace() -> void:
	var span := int(INPLACE_WINDOW_S * SimClock.TICK_RATE)
	for tank: Tank in game_match.tanks.get_children():
		if not tank.is_alive() or String(Units.stat(tank.unit_id, "locomotion", "tracks")) != "wheels":
			inplace_trail.erase(String(tank.name))
			continue
		var key := String(tank.name)
		inplace_alive_ticks[tank.unit_id] = int(inplace_alive_ticks.get(tank.unit_id, 0)) + 1
		_sample_gear(tank)
		var forward := -tank.global_basis.z
		var trail: Array = inplace_trail.get(key, [])
		trail.append([tank.global_position.x, tank.global_position.z, rad_to_deg(atan2(-forward.x, -forward.z)), tank.speed()])
		if trail.size() > span:
			trail.remove_at(0)
		inplace_trail[key] = trail
		var cool := int(inplace_cooldown.get(key, 0))
		if cool > 0:
			inplace_cooldown[key] = cool - 1
			continue
		if trail.size() < span:
			continue
		var turned := 0.0
		for i in range(1, trail.size()):
			turned += absf(wrapf(float(trail[i][2]) - float(trail[i - 1][2]), -180.0, 180.0))
		var net := Vector2(float(trail[-1][0]) - float(trail[0][0]), float(trail[-1][1]) - float(trail[0][1])).length()
		if turned >= INPLACE_DEG and net < INPLACE_M:
			inplace_events[tank.unit_id] = int(inplace_events.get(tank.unit_id, 0)) + 1
			inplace_cooldown[key] = span
			var travelled := 0.0
			for i in range(1, trail.size()):
				travelled += Vector2(float(trail[i][0]) - float(trail[i - 1][0]), float(trail[i][1]) - float(trail[i - 1][1])).length()
			var detail: Dictionary = inplace_detail.get(tank.unit_id, {"turned": 0, "wobble": 0, "crept": 0})
			var net_turn := absf(wrapf(float(trail[-1][2]) - float(trail[0][2]), -180.0, 180.0))
			detail["turned" if net_turn >= INPLACE_DEG else "wobble"] += 1
			detail["crept"] += 1 if travelled >= INPLACE_M else 0
			# Where the event happened: the mover's phase ("none" = no Movement order, e.g. a brain steering it directly)
			# and whether the plant was in its wheeled creep (K-turn legs) at that tick.
			var phase := "phase:" + String(Movement.state(tank).get("phase", "none"))
			detail[phase] = int(detail.get(phase, 0)) + 1
			var motion: Variant = tank.get("_motion")
			var creeping := motion is Dictionary and int((motion as Dictionary).get("creep_dir", 0)) != 0
			detail["creeping"] = int(detail.get("creeping", 0)) + (1 if creeping else 0)
			# Gear changes in the window: forward and reverse both above 0.5 m/s (a car shuffling back and forth).
			var fwd := false
			var rev := false
			for sample: Array in trail:
				fwd = fwd or float(sample[3]) > 0.5
				rev = rev or float(sample[3]) < -0.5
			detail["shuffled"] = int(detail.get("shuffled", 0)) + (1 if fwd and rev else 0)
			inplace_detail[tank.unit_id] = detail


## travelled, as shares: how much of each type's path length turns into net displacement, and what share of its 4 s
## windows counted as oscillating.
func _travel_report() -> Dictionary:
	var out := {}
	for unit_id: String in travelled:
		var travel: Dictionary = travelled[unit_id]
		var path := float(travel["path_m"])
		out[unit_id] = {"path_m": snappedf(path, 0.1), "net_over_path": snappedf(float(travel["net_m"]) / maxf(path, 0.01), 0.001),
				"windows": travel["windows"], "oscillating_share": snappedf(float(travel["oscillating"]) / maxf(float(travel["windows"]), 1.0), 0.001)}
	return out


func _inplace_rates() -> Dictionary:
	var rates := {}
	for unit_id: String in inplace_alive_ticks:
		var minutes := float(inplace_alive_ticks[unit_id]) / SimClock.TICK_RATE / 60.0
		rates[unit_id] = {"events_per_unit_minute": snappedf(int(inplace_events.get(unit_id, 0)) / maxf(minutes, 0.01), 0.01),
				"gear_flips_per_unit_minute": snappedf(int(gear_flips.get(unit_id, 0)) / maxf(minutes, 0.01), 0.01),
				"alive_unit_minutes": snappedf(minutes, 0.1)}
	return rates


func _sample() -> void:
	_sample_inplace()
	var elapsed := float(game_match.tick - issued_tick) / float(SimClock.TICK_RATE)
	if not phase_two_done and elapsed >= time_limit * 0.4:
		phase_two_done = true
		_order_squads(0.85)  # then attack-move onward: the fight
	if busy_every > 0.0 and elapsed >= busy_next:
		busy_next = elapsed + busy_every
		_busy_order()
	if not hold_done and elapsed >= time_limit * 0.7:
		hold_done = true
		_hold_on_a_facing()
	var dt := 1.0 / float(SimClock.TICK_RATE)
	var dump := OS.get_cmdline_user_args().has("--where") and (game_match.tick - issued_tick) % (SimClock.TICK_RATE * 6) == 0 \
			and not phase_two_done
	for tank in green:
		if not tank.is_alive():
			continue
		var key := String(tank.name)
		var goal_v: Variant = orders.goal_position(key)
		if goal_v == null:
			last_distance.erase(key)
			continue
		var goal: Vector3 = goal_v
		var distance := Vector2(tank.global_position.x - goal.x, tank.global_position.z - goal.z).length()
		var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + key)) as TankBrain
		if brain == null:
			continue
		ordered_ticks += 1
		var move: Dictionary = brain.move_order
		var target := Vector3(float(move.get("x", tank.global_position.x)), 0.0, float(move.get("z", tank.global_position.z)))
		if String(move.get("type", "")) == "move_to":
			if last_target.has(key) and (last_target[key] as Vector3).distance_to(target) > RETASK_M:
				retask_events += 1
				var v := String(orders.current(key).get("verb", "?"))
				retask_by_verb[v] = int(retask_by_verb.get(v, 0)) + 1
				# Who moved the target: the same option re-aiming (a CombatMotion hop is `direct`), or a change of mind.
				var option_now := String(brain.choice.get("option", "?"))
				var cause := "%s%s%s" % [option_now, " hop" if bool(move.get("direct", false)) else "",
						"" if option_now == String(last_option.get(key, option_now)) else " (switched from %s)" % last_option[key]]
				retask_cause[cause] = int(retask_cause.get(cause, 0)) + 1
			last_target[key] = target
		last_option[key] = String(brain.choice.get("option", "?")) if not last_option.has(key) else last_option[key]
		var reading := Movement.state(tank)
		# A1: attribute a re-plan to an OWNER. nav publishes why it re-planned; only a harness that can see the K1
		# order knows whose order it was, because the mover is handed a `move_to` and never the order behind it.
		# squad's point: a sliding goal is an element's flow OR the player's own follow, and those are different owners.
		var why_replan := String(reading.get("replan", ""))
		if why_replan != "":
			var k1: Dictionary = orders.current(key)
			var owner := "%s/%s/%s" % [why_replan, String(k1.get("source", "?")), String(k1.get("verb", "?"))]
			replan_owner[owner] = int(replan_owner.get(owner, 0)) + 1
		if reading.get("reachable") == false and String(move.get("type", "")) == "move_to":
			unreachable_ticks += 1
		var closing := (float(last_distance.get(key, distance)) - distance) / dt
		last_distance[key] = distance
		# --stall-verb=<verb>: arena's counters sample only units under that verb (round 8: does an ATTACK-MOVING unit
		# go back and forth? The counters' goal is the ORDER's goal, so this is the trajectory against what was asked).
		if distance > AT_GOAL_M and (stall_verb == "" or String(orders.current(key).get("verb", "")) == stall_verb):
			_sample_stall(tank, key, goal)
		var reason := ""
		if distance <= AT_GOAL_M:
			reason = "at_goal"
		elif closing > PROGRESS_MPS:
			reason = "progressing"
		elif String(reading.get("phase", "")) == "yielding":
			reason = "yielding"
		elif String(reading.get("phase", "")) == "blocked":
			var by := String(reading.get("blocked_by", ""))
			var other := game_match.tanks.get_node_or_null(NodePath(by)) as Tank if by != "" and by != "terrain" and by != "no_path" else null
			reason = "blocked_" + (("friend" if other.team == tank.team else "enemy") if other != null else by)
		elif ["stop", "face"].has(String(move.get("type", ""))):
			reason = "halted_shooting" if brain.engaged_target != "" else "halted"
			var why := String(brain.choice.get("option", "?"))
			halted_as[why] = int(halted_as.get(why, 0)) + 1
		elif String(move.get("type", "")) == "move_to" and target.distance_to(Vector3(goal.x, 0.0, goal.z)) > RETASK_M:
			var option := String(brain.choice.get("option", "?"))
			reason = "retasked"
			options[option] = int(options.get(option, 0)) + 1
		else:
			reason = "slow"
		buckets[reason] = int(buckets.get(reason, 0)) + 1
		if dump and not ["progressing", "at_goal"].has(reason):
			print("NAV_FIGHT_WHERE t=%.0f %s at (%.1f, %.1f) goal (%.1f, %.1f) %s by=%s option=%s speed=%.1f stalled=%.1fs reachable=%s steer=%s" % [
					elapsed, key, tank.global_position.x, tank.global_position.z, goal.x, goal.z, reason,
					reading.get("blocked_by", ""), brain.choice.get("option", "?"), tank.speed(), float(reading.get("stalled_s", 0.0)),
					reading.get("reachable"), reading.get("steer_to")])
		last_option[key] = String(brain.choice.get("option", "?"))
		var verb := String(orders.current(key).get("verb", "?"))
		var per_verb: Dictionary = by_verb.get(verb, {})
		per_verb[reason] = int(per_verb.get(reason, 0)) + 1
		per_verb["_ticks"] = int(per_verb.get("_ticks", 0)) + 1
		by_verb[verb] = per_verb
	if elapsed >= time_limit:
		_report(elapsed)


func _report(elapsed: float) -> void:
	physics_frame.disconnect(_sample)
	# Round 9 (N0) positive control: the run must actually have asked for a facing, or the arrival arc could not have
	# fired and no number about it means anything. Round 8 measured exactly this configuration twice without noticing.
	if facings_issued == 0:
		push_error("nav-fight control FAILED: no order in this run carried a `facing`, so the arrival arc was never offered one")
		quit(1)
		return
	var seconds := {}
	var share := {}
	for reason: String in buckets:
		seconds[reason] = snappedf(float(buckets[reason]) / SimClock.TICK_RATE, 0.1)
		share[reason] = snappedf(float(buckets[reason]) / maxf(1.0, float(ordered_ticks)), 0.001)
	var retasked_as := {}
	for option: String in options:
		retasked_as[option] = snappedf(float(options[option]) / SimClock.TICK_RATE, 0.1)
	var halted_opt := {}
	for option: String in halted_as:
		halted_opt[option] = snappedf(float(halted_as[option]) / SimClock.TICK_RATE, 0.1)
	var verbs := {}
	for verb: String in by_verb:
		var d: Dictionary = by_verb[verb]
		var total := float(d["_ticks"])
		var row := {"unit_seconds": snappedf(total / SimClock.TICK_RATE, 0.1),
				"retask_events_per_unit_minute": snappedf(int(retask_by_verb.get(verb, 0)) / maxf(0.01, total / SimClock.TICK_RATE / 60.0), 0.01)}
		for reason: String in d:
			if reason != "_ticks":
				row[reason] = snappedf(float(d[reason]) / total, 0.001)
		verbs[verb] = row
	var alive := green.filter(func(t: Tank) -> bool: return t.is_alive()).size()
	var rust_units: Array = game_match.tanks.get_children().filter(func(t: Tank) -> bool: return t.team == Match.Team.RUST)
	var rust_alive := rust_units.filter(func(t: Tank) -> bool: return t.is_alive()).size()
	var hops := 0
	var switches := 0
	for cause: String in retask_cause:
		if cause.contains("(switched"):
			switches += int(retask_cause[cause])
		else:
			hops += int(retask_cause[cause])
	var minutes := maxf(0.01, float(ordered_ticks) / SimClock.TICK_RATE / 60.0)
	var out := {"arena": String(Arena.active.get("name", "?")), "seed": int(_flag("seed", "3")), "green": green.size(),
			"green_alive_end": alive, "rust": rust_units.size(), "rust_alive_end": rust_alive,
			"green_lost": green.size() - alive, "rust_lost": rust_units.size() - rust_alive,
			"shots": game_match.stats.get("shots", []),
			"motion_jumps_per_unit_minute": snappedf(hops / minutes, 0.01),
			"decision_jumps_per_unit_minute": snappedf(switches / minutes, 0.01), "seconds": snappedf(elapsed, 0.1),
			"ordered_unit_seconds": snappedf(float(ordered_ticks) / SimClock.TICK_RATE, 0.1),
			"unit_seconds": seconds, "share": share, "retasked_by_option_unit_seconds": retasked_as,
			"retask_events": retask_events, "retask_cause": retask_cause, "halted_by_option_unit_seconds": halted_opt, "by_verb": verbs,
			"retask_events_per_unit_minute": snappedf(retask_events / maxf(0.01, float(ordered_ticks) / SimClock.TICK_RATE / 60.0), 0.01),
			"unreachable_route_unit_seconds": snappedf(float(unreachable_ticks) / SimClock.TICK_RATE, 0.1),
			"stall": _stall_report(), "stall_verb": stall_verb, "inplace_yaw_events": inplace_events,
			"inplace_detail": inplace_detail, "gear_detail": gear_detail, "travelled": _travel_report(),
			"gates": Movement.gate_report(), "facings_issued": facings_issued, "holds_issued": holds_issued,
			"arms": CombatMotion.arm_report(), "route_arms": Movement.route_arms(), "replan_owner": replan_owner,
			"inplace_per_unit_minute": _inplace_rates(),
			"factions": [_flag("green-faction", "condemned"), _flag("rust-faction", "condemned")],
			"armies": [_flag("green-army", "cpu"), _flag("rust-army", "cpu")], "fielded": fielded, "busy_every_s": busy_every, "busy_orders": busy_orders}
	print("NAV_FIGHT %s" % JSON.stringify(out))
	quit(0)

# ---- arena's three pre-registered stall counters, pasted VERBATIM from
# _agents/streams/references/arena/stall_counters_for_fight_probe.gd.txt (arena c0aa421f); definitions frozen in
# _agents/streams/references/arena/stuck_preregistration.md. Identical here so both probes report the same quantity.
# Note on re-orders: _note_goal() resets the windows when the goal jumps (> 3 m), so a re-order is never scored as
# no-progress; if under_way_seconds collapses, the orders are coming faster than the measure can see.
## Window over which "is it getting anywhere" is asked. Long enough to contain a full back-and-forth, short enough
## that a unit rounding a corner does not look like one.
const WINDOW_S := 4.0
## `oscillating`: over the window, this much path travelled...
const OSCILLATE_PATH_M := 8.0
## ...while net displacement is under this share of it. A ratio, not a distance: a unit crossing the map slowly
## still has net ≈ path; a unit shuffling has net ≈ 0 with path large. Scale-free, so no retuning per unit type.
const OSCILLATE_RATIO := 0.25
## `no_progress`: distance to the goal improved by less than this over the window.
## The gap-coverer. `crawl` catches a unit too SLOW to be going anywhere (< 0.5 m/s); `oscillating` catches one
## travelling far enough to be obviously shuffling (>= 8 m). A unit creeping back and forth at 1–2 m/s is NEITHER
## — too fast to crawl, too little path to oscillate — and that is what being pinned at a barrier end looks like.
const PROGRESS_M := 2.0
## A goal that jumps further than this is a different goal: reset the window rather than score across it.
const GOAL_MOVED_M := 3.0

var trail := {}            # key -> Array[Vector3], the position window
var goal_trail := {}       # key -> Array[float], distance-to-goal over the window
var last_goal := {}        # key -> Vector3, to detect a re-order
var oscillating_ticks := {}
var no_progress_ticks := {}
var crawl_ticks := 0
var under_way_ticks := 0   # denominator: ticks where a unit HOLDS AN ORDER and has not arrived


## Call once per unit per tick, only while the unit is under orders and has not arrived.
## `goal` is the unit's CURRENT goal this tick.
func _sample_stall(unit: Node3D, key: String, goal: Vector3) -> void:
	under_way_ticks += 1
	if unit.speed() < 0.5:   # CRAWL_SPEED
		crawl_ticks += 1
	_note_goal(key, goal)
	var span := int(WINDOW_S * SimClock.TICK_RATE)

	# no_progress: distance to the goal over the window, reset on a re-order.
	var goals: Array = goal_trail.get(key, [])
	goals.append(_flat(unit.global_position, goal))
	if goals.size() > span:
		goals.remove_at(0)
	goal_trail[key] = goals
	if goals.size() == span and float(goals[0]) - float(goals[goals.size() - 1]) < PROGRESS_M:
		no_progress_ticks[key] = int(no_progress_ticks.get(key, 0)) + 1

	# oscillating: path length vs net displacement over the same window.
	var history: Array = trail.get(key, [])
	history.append(unit.global_position)
	if history.size() > span:
		history.remove_at(0)
	trail[key] = history
	if history.size() < span:
		return
	var path := 0.0
	for i in range(1, history.size()):
		path += _flat(history[i - 1], history[i])
	if path < OSCILLATE_PATH_M:
		return  # not moving enough to be "moving back and forth"; that is the blocked case, counted separately
	# Per unit TYPE as well as per unit (round 8, combat's request): "did THIS vehicle go anywhere", which is the one
	# shape that separates a shuffling hull (long path, no net), a stuck one (neither) and a merely bigger target
	# (both intact). An army-level mean cannot see it: vehicles shuffling forward and back cancel in the average.
	var unit_id := String(unit.get("unit_id"))
	var travel: Dictionary = travelled.get(unit_id, {"path_m": 0.0, "net_m": 0.0, "windows": 0, "oscillating": 0})
	travel["path_m"] = float(travel["path_m"]) + path
	travel["net_m"] = float(travel["net_m"]) + _flat(history[0], history[history.size() - 1])
	travel["windows"] = int(travel["windows"]) + 1
	if _flat(history[0], history[history.size() - 1]) / path < OSCILLATE_RATIO:
		oscillating_ticks[key] = int(oscillating_ticks.get(key, 0)) + 1
		travel["oscillating"] = int(travel["oscillating"]) + 1
	travelled[unit_id] = travel


## A re-order invalidates both windows: the unit is now chasing something else, and neither "did it get closer"
## nor "did it go anywhere" is answerable across the change.
func _note_goal(key: String, goal: Vector3) -> void:
	var previous: Variant = last_goal.get(key)
	if previous != null and _flat(previous, goal) > GOAL_MOVED_M:
		goal_trail.erase(key)
		trail.erase(key)
	last_goal[key] = goal


## Flat distance. x/z only — measuring in 3D made a ramp read as travel and cost me a published number once.
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Shares are of UNDER-WAY ticks, never of wall-clock or of all ticks: a parked unit standing still is not stuck,
## and including it silently divides the interesting number down.
func _stall_report() -> Dictionary:
	return {
		"crawl_share": snappedf(float(crawl_ticks) / maxf(1.0, float(under_way_ticks)), 0.001),
		"oscillating_share": snappedf(float(_total(oscillating_ticks)) / maxf(1.0, float(under_way_ticks)), 0.001),
		"oscillating_units": _with_any(oscillating_ticks),
		"no_progress_share": snappedf(float(_total(no_progress_ticks)) / maxf(1.0, float(under_way_ticks)), 0.001),
		"no_progress_units": _with_any(no_progress_ticks),
		"under_way_seconds": snappedf(float(under_way_ticks) / float(SimClock.TICK_RATE), 0.1),
	}


func _total(ticks: Dictionary) -> int:
	var sum := 0
	for value in ticks.values():
		sum += int(value)
	return sum


func _with_any(ticks: Dictionary) -> int:
	var count := 0
	for value in ticks.values():
		if int(value) > 0:
			count += 1
	return count
