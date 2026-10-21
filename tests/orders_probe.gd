extends SceneTree
## Round 34 (planner, orders' O5 for C34.11; measurement only): his "select 3 squads, click one point" case, through the
## real player path. A skirmish (main.tscn, the player's squads from tests/control/orders_probe_<N>.json, a one-scout
## enemy far away) is resumed from its planning pause; every squad is selected together and ordered through
## RtsControls.order_selection, as his right-click is: ONE click (`--probe-route=click`), or a shifted route of three
## waypoints (`--probe-route=route`, the first two queued behind nothing, then queued). Then, per squad:
##   anchor_offset_m   straight distance from the click (the route's last waypoint) to the squad's own anchor
##   plan_drive_m      the drive from the squad's start to its anchor on the navmesh; driven_m: its centre's actual path
##   deck              whether any crew stood on a bridge deck (its ramp counts; plan_deck: whether the planned drive
##                     crosses one); crossed: whether any crew got past a deck to the far bank (his scouts' suicidal run)
##   arrived_s         the element's first `arrived`, seconds after the order (-1: not inside the window)
##   foreign_m         at arrival, the nearest hull of ANOTHER of his squads (enemy_m: the nearest enemy)
##   shuffle_m         the most any crew moved after its squad's arrival, to the end of the window (brains' B6 shuffle)
## Round 35 (orders D2, the deploy step ON): the shuffle split in two. The squad's PLACE move starts when it deploys (the
## element's deploy tick; with `--deploy-step=off` its arrival) and lasts PLACE_S:
##   deploy_s          seconds from the order to that start (-1: never); deploy_cause: all_in / cap / arrived (off)
##   place_m           the most any crew moved from where it stood at that start, during PLACE_S (the deploy move)
##   twitch_m          the most any crew moved after PLACE_S, to the window's end (what should be ~0)
##   end_foreign_m     at the window's end, the nearest hull of another of his squads (packing: >= ~9 m wanted)
##   end_far_m         at the window's end, the farthest crew of the squad from the click (how far the body spreads)
## ORDERS_PROBE_SQUAD {...} a squad, ORDERS_PROBE {...} the run. With a display, top-down screenshots when every squad has
## arrived (or the window ends), desktop 1280x720 and phone 1560x720, into `--probe-shots=DIR`.
##
##   godot --fixed-fps 30 --path . --script res://tests/orders_probe.gd -- --arena=locks --seed=34 --probe-squads=3 \
##     --probe-route=click [--ground-cap=off] [--halt-price=off] [--probe-shots=build/orders-probe] [--probe-click=x,z]
## The arms are main's own switches (O1's ground cap, O3's halt price; O2's when it lands), read by SelectionSquads.
## The click (unless given): the near bank of the deck nearest the arena's middle, DECK_BACK_M short of it on the
## player's side, where an anchor laid 70 m sideways meets the river (his case); moved by the seed (`_jitter`) unless 34. The route: the squads' middle, then
## two points a third and two thirds of the way, then the click.

const MAIN := "res://game/main.tscn"
const DECK_BACK_M := 18.0
const WINDOW_S := 90.0
const AFTER_ARRIVAL_S := 30.0
## O2 (round 37): how long a fight probe watches the parked squads after the last arrived.
const FIGHT_AFTER_S := 120.0
const PLACE_S := 8.0
const SHOT_AFTER_S := 5
## Squad 1..5's anchor posts in the shots (the order the probe lists squads in).
const MARK_COLOURS := [Color(1.0, 0.25, 0.25), Color(1.0, 0.85, 0.1), Color(0.2, 1.0, 0.3), Color(0.2, 0.6, 1.0), Color(0.9, 0.3, 1.0)]
const SHOT_SIZES := {"desktop": Vector2i(1280, 720), "phone": Vector2i(1560, 720)}

var _controls: RtsControls
var _match: Match
var _squads: Array = []  # [{number, units, start, path_len, deck, anchor, arrived_tick, at_arrival, foreign, enemy, shuffle}]
var _click := Vector3.ZERO
var _route: Array = []
var _order_tick := 0
var _last_centre := {}
var _shot := {}  # labels already shot


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	# `--squad-cap`: his laptop's preset caps a side at 4 squads (C25.6); the probe pins N so every machine fields them all.
	# The arena and Match read the COMMAND LINE (LaunchFlags.from_environment), not Main.next_flags: `--arena` and `--seed`
	# are the probe's own arguments, and the rest is added to what main.gd reads.
	var map := _flag("arena", "locks")
	var count := int(_flag("probe-squads", "3"))
	var flags := LaunchFlags.from_environment()
	# Round 37 (orders O2): `--probe-fight=on` parks his squads where the click puts them and lets a real CPU army
	# (`--probe-enemy`, default cpu, at `--probe-budget` points) come to them, for FIGHT_AFTER_S after all are in.
	var fight := _flag("probe-fight", "off") == "on"
	var enemy := "--enemy=%s" % _flag("probe-enemy", "cpu") if fight else "--enemy=res://tests/control/orders_probe_enemy.json"
	var budget := "--budget=%s" % _flag("probe-budget", "2500") if fight else "--budget=6000"
	for extra: String in ["--skirmish", "--player=res://tests/control/orders_probe_%d.json" % count,
			enemy, budget, "--no-control", "--no-pick-faction",
			"--hints=off", "--no-record", "--squad-cap=%d" % count]:
		var parts := extra.trim_prefix("--").split("=", true, 1)
		flags.values[parts[0]] = parts[1] if parts.size() > 1 else ""
	Main.next_flags = flags
	change_scene_to_file(MAIN)
	for i in 40:  # the scene, the arena's navmesh and the controls (built after the mode starts)
		await physics_frame
	_controls = current_scene.find_child("TacticalMap", true, false) as RtsControls
	if _controls == null:
		print("ORDERS_PROBE {\"error\": \"no RtsControls (TacticalMap)\"}")
		quit(2)
		return
	_match = _controls.game_match
	# The token enemy stands still at its base: its controllers are freed (a probe of driving, not of a fight; a picket
	# that drove into sight was killed in the first windowed run and the VICTORY banner covered the shot).
	# It is also held in the far corner every tick (`_park`): its brain lives outside `brains` in a skirmish.
	if not fight:
		for brain in _match.brains.get_children():
			var driven: Variant = brain.get("tank")
			if driven is Tank and (driven as Tank).team != Match.Team.GREEN:
				brain.queue_free()
		physics_frame.connect(_park)
	if paused:
		_controls.set_paused(false, "")
	for i in 30:
		await physics_frame
	var units: Array = []
	for number: int in _controls.groups.numbers():
		var members: Array = _controls.groups.members(number)
		if members.is_empty():
			continue
		units += members
		_squads.append({"number": number, "units": members, "start": _centre(members)})
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	_click = _pick_click(map, _centre(units), forward)
	_route = [_click]
	if _flag("probe-route", "click") == "route":
		var from := _centre(units)
		_route = [from.lerp(_click, 1.0 / 3.0), from.lerp(_click, 2.0 / 3.0), _click]
	print("ORDERS_PROBE_SETUP " + JSON.stringify({"map": map, "squads": _squads.size(), "units": units.size(),
			"click": _xz(_click), "route": _route.map(func(p: Vector3) -> Array: return _xz(p)),
			"ground_cap": SelectionSquads.GROUND_CAP, "decks": SlotGround.deck_boxes()}))
	_controls.selection.set_units(units)
	await physics_frame
	var returned: Array = []
	for i in _route.size():
		var p: Vector3 = _route[i]
		returned.append(_controls.order_selection("move", {"to": [p.x, p.z], "queue": i > 0}))
		if _flag("probe-legs-each", "") == "on":
			for squad: Dictionary in _squads:
				var held := _controls.elements.of(String(squad["units"][0])) if _controls.elements != null else null
				print("ORDERS_PROBE_CLICK %d squad %d task %s queued %s" % [i, int(squad["number"]),
						str(held.task.get("to")) if held != null else "-", str(held.queued_tasks.map(func(t: Dictionary) -> Variant: return t.get("to"))) if held != null else "-"])
	_order_tick = _match.tick
	# Round 35 (D5): every squad's legs as dealt (its element's task, then its queued tasks' destinations).
	for squad: Dictionary in _squads:
		var held := _controls.elements.of(String(squad["units"][0])) if _controls.elements != null else null
		if held != null:
			var legs: Array = [held.task.get("to")]
			for queued: Dictionary in held.queued_tasks:
				legs.append(queued.get("to"))
			print("ORDERS_PROBE_LEGS squad %d start %s legs %s" % [int(squad["number"]), _xz(squad["start"]), legs])
	for squad: Dictionary in _squads:
		squad["anchor"] = _anchor_of(squad)
		var ground := _tank(String(squad["units"][0]))
		var anchor: Variant = squad["anchor"]
		squad["path_len"] = SlotGround.path_length(ground, squad["start"], anchor) if anchor is Vector3 and ground != null else -1.0
		squad["plan_deck"] = bool(SelectionSquads.crosses_on(ground).call(squad["start"], anchor)) \
				if anchor is Vector3 and ground != null else false
		squad["deck"] = false
		squad["crossed"] = false
		squad["goals_across"] = []
		squad["driven"] = 0.0
		squad["arrived_tick"] = -1
		squad["shuffle"] = 0.0
		_last_centre[squad["number"]] = squad["start"]
	var all_in_tick := -1
	var window_s := WINDOW_S + (FIGHT_AFTER_S - AFTER_ARRIVAL_S if fight else 0.0)
	var after_s := FIGHT_AFTER_S if fight else AFTER_ARRIVAL_S
	while _match.tick - _order_tick < int(window_s * SimClock.TICK_RATE):
		await physics_frame
		_watch()
		var all_in := _squads.all(func(s: Dictionary) -> bool: return int(s["arrived_tick"]) >= 0)
		if all_in and all_in_tick < 0:
			all_in_tick = _match.tick
			await _shots("arrival")
		# And 5 s later: what he sees once the squads have settled (or shuffled) after arriving.
		if all_in_tick >= 0 and _match.tick - all_in_tick == SHOT_AFTER_S * SimClock.TICK_RATE:
			await _shots("arrival_plus5")
		if all_in_tick >= 0 and _match.tick - all_in_tick >= int(after_s * SimClock.TICK_RATE):
			break
	if all_in_tick < 0:
		await _shots("window_end")
	var rows: Array = []
	for squad: Dictionary in _squads:
		var anchor: Variant = squad["anchor"]
		var row := {"map": map, "squads": _squads.size(), "route": _flag("probe-route", "click"), "arm": _flag("probe-arm", ""),
				"seed": int(_flag("seed", "34")),
				"ground_cap": "on" if SelectionSquads.GROUND_CAP else "off",
				"halt_price": "on" if SelectionSquads.HALT_PRICE else "off", "squad": squad["number"],
				"crews": (squad["units"] as Array).size(), "start": _xz(squad["start"]), "anchor": _xz(anchor) if anchor is Vector3 else null,
				"anchor_offset_m": snappedf(_flat_d(anchor, _click), 0.1) if anchor is Vector3 else -1.0,
				# How much nearer the click its anchor is than its start (negative: the squad is sent AWAY from the click).
				"toward_m": snappedf(_flat_d(squad["start"], _click) - _flat_d(anchor, _click), 0.1) if anchor is Vector3 else 0.0,
				"plan_drive_m": snappedf(float(squad["path_len"]), 0.1), "driven_m": snappedf(float(squad["driven"]), 0.1),
				"plan_deck": squad["plan_deck"], "deck": squad["deck"], "deck_at": squad.get("deck_at"),
				"crossed": squad["crossed"], "crossed_at": squad.get("crossed_at"),
				"arrived_s": snappedf((int(squad["arrived_tick"]) - _order_tick) / float(SimClock.TICK_RATE), 0.1)
						if int(squad["arrived_tick"]) >= 0 else -1.0,
				"foreign_m": snappedf(float(squad.get("foreign", -1.0)), 0.1),
				"enemy_m": snappedf(float(squad.get("enemy", -1.0)), 0.1),
				"shuffle_m": snappedf(float(squad["shuffle"]), 0.1), "goals_across": squad["goals_across"],
				"arrived_by": squad.get("arrived_by", ""),
				"deploy_s": snappedf((int(squad["place_tick"]) - _order_tick) / float(SimClock.TICK_RATE), 0.1)
						if squad.has("place_tick") else -1.0, "deploy_cause": squad.get("deploy_cause", ""),
				"place_m": snappedf(float(squad.get("place", -1.0)), 0.1),
				"deploy_leg_m": snappedf(float(squad.get("deploy_leg_m", -1.0)), 0.1), "deploy_passes": int(squad.get("deploy_passes", -1)),
				"leg_minmax_m": snappedf(float(squad.get("leg_minmax_m", -1.0)), 0.1), "leg_compact_m": snappedf(float(squad.get("leg_compact_m", -1.0)), 0.1),
				"detour_worst_m": snappedf(float(squad.get("detour_worst_m", -1.0)), 0.1), "detours": int(squad.get("detours", -1)),
				"detours_caught": int(squad.get("detours_caught", -1)),
				"travel_width_m": snappedf(float(squad.get("travel_width_m", -1.0)), 0.1),
				"halt_depth_m": snappedf(float(squad.get("halt_depth_m", -1.0)), 0.1), "halt_shape": squad.get("halt_shape", ""), "twitch_m": snappedf(float(squad.get("twitch", -1.0)), 0.1)
						if squad.has("placed") else -1.0,
				"end_foreign_m": snappedf(_nearest(_living(squad), func(t: Tank) -> bool: return t.team == Match.Team.GREEN \
						and not (squad["units"] as Array).has(String(t.name))), 0.1),
				# O2 (round 36, the orchestrator's guard): own squad's closest two crews at the window's end, centre to centre
				# and hull to hull (less both hulls' half-diagonals, SlotGround.envelope_of).
				"twitch_seen": squad.get("twitch_seen", {}), "redealt": int(squad.get("redealt", 0)), "away_m": snappedf((squad.get("away", {}) as Dictionary).values().reduce(func(a: float, b: float) -> float: return maxf(a, b), 0.0), 0.1),
				"shape_flips": int(squad.get("shape_flips", -1)), "terrain_flips": int(squad.get("terrain_flips", -1)),
				"anchor_terrain_flips": int(squad.get("anchor_terrain_flips", -1)), "relays": int(squad.get("relays", -1)), "reseats": int(squad.get("reseats", 0)),
				"shapes": squad.get("shapes", []),
				"away_held_m": snappedf((squad.get("away_held", {}) as Dictionary).values().reduce(func(a: float, b: float) -> float: return maxf(a, b), 0.0), 0.1),
				"away_seat_m": snappedf((squad.get("away_seat", {}) as Dictionary).values().reduce(func(a: float, b: float) -> float: return maxf(a, b), 0.0), 0.1),
				"self_off_m": snappedf((squad.get("self_off", {}) as Dictionary).values().reduce(func(a: float, b: float) -> float: return maxf(a, b), 0.0), 0.1),
				"self_off_crews": (squad.get("self_off", {}) as Dictionary).size(), "left_by": squad.get("left_by", {}),
				"self_off_back": (squad.get("self_off", {}) as Dictionary).keys().filter(func(n: String) -> bool:
						return _tank(n) != null and _tank(n).is_alive() and _flat_d(_tank(n).global_position, squad["placed"][n]) <= BACK_M).size(),
				"placed_crews": (squad.get("placed", {}) as Dictionary).size(),
				"lost_after_placed": (squad.get("placed", {}) as Dictionary).keys().filter(func(n: String) -> bool:
						return _tank(n) == null or not _tank(n).is_alive()).size(),
				"end_seat_m": snappedf(_living(squad).filter(func(n: String) -> bool: return (squad.get("placed", {}) as Dictionary).has(n)) \
						.map(func(n: String) -> float: return _flat_d(_tank(n).global_position, squad["placed"][n])).reduce(
						func(a: float, b: float) -> float: return maxf(a, b), 0.0), 0.1),
				"end_own_min_m": snappedf(_own_min(_living(squad), false), 0.1), "end_own_gap_m": snappedf(_own_min(_living(squad), true), 0.1),
				"end_far_m": snappedf(_living(squad).map(func(n: String) -> float: return _flat_d(_tank(n).global_position, _click)).max()
						if not _living(squad).is_empty() else -1.0, 0.1),
				"deploy_step": "on" if ElementPlan.DEPLOY_STEP else "off",
				"end": _end_state(squad)}
		rows.append(row)
		print("ORDERS_PROBE_SQUAD " + JSON.stringify(row))
	print("ORDERS_PROBE " + JSON.stringify({"map": map, "squads": _squads.size(), "route": _flag("probe-route", "click"),
			"arm": _flag("probe-arm", ""),
			"ground_cap": "on" if SelectionSquads.GROUND_CAP else "off",
			"halt_price": "on" if SelectionSquads.HALT_PRICE else "off", "capped": SelectionSquads.ground_capped,
			# O4 (main 471cdcd5e): a shifted route on a squad is its element's move; its gate counters, when the tree has them
			"gates_laid": _static_or(RtsControls, "gates_laid"), "route_starts": _static_or(RtsControls, "route_starts"),
			# Round 35 (D5, D3): the swaps uncross_paths made and the packs laid (each A/B confirms its own counter first, R35.5)
			"uncrossed": _static_or(SelectionSquads, "uncrossed"), "packed": _static_or(SelectionSquads, "packed"), "pack_refused": SelectionSquads.pack_refused, "deck_cleared": _static_or(SelectionSquads, "deck_cleared"),
			"friend_contacts": _contacts, "friend_contacts_foreign": _contacts_foreign, "contact_ticks": _contact_ticks,
			"swapped_whole": SelectionSquads.swapped_whole, "whole_still_crossed": SelectionSquads.whole_still_crossed,
			"untangle": "whole" if SelectionSquads.UNTANGLE_WHOLE else "deal",
			"fight": _flag("probe-fight", "off"), "green_kills": _sum_values(_match.kills_by_unit[Match.Team.GREEN]),
			"green_lost": int(_match.units_lost[Match.Team.GREEN]), "rust_lost": int(_match.units_lost[Match.Team.RUST]),
			"returned": returned, "all_in_s": snappedf((all_in_tick - _order_tick) / float(SimClock.TICK_RATE), 0.1)
					if all_in_tick >= 0 else -1.0, "on_deck": rows.filter(func(r: Dictionary) -> bool: return r["deck"]).size(),
			"crossed": rows.filter(func(r: Dictionary) -> bool: return r["crossed"]).size(),
			"worst_offset_m": rows.map(func(r: Dictionary) -> float: return r["anchor_offset_m"]).max(),
			"worst_shuffle_m": rows.map(func(r: Dictionary) -> float: return r["shuffle_m"]).max()}))
	quit(0)


## Past a deck to the far side from the click: within a deck's span across the river (its x range, widened by
## ACROSS_SIDE_M) and beyond its far edge along the line from the click. A crew nosing onto the near ramp is `deck`, not this.
const ACROSS_SIDE_M := 30.0
const ARRIVE_M := 12.0
const LEFT_M := 15.0


func _across(at: Vector3) -> bool:
	for box: Array in SlotGround.deck_boxes():
		var lo_x := float(box[0]) - ACROSS_SIDE_M
		var hi_x := float(box[2]) + ACROSS_SIDE_M
		if at.x < lo_x or at.x > hi_x:
			continue
		var lo_z := float(box[1])
		var hi_z := float(box[3])
		if (_click.z > hi_z and at.z < lo_z) or (_click.z < lo_z and at.z > hi_z):
			return true
	return false


func _park() -> void:
	if _match == null or not is_instance_valid(_match):
		return
	var corner := Orders.clamp_to_arena(Vector3(1000.0, 0.0, -1000.0) * (1.0 if Match.team_frame(Match.Team.GREEN)["forward"].z < 0.0 else -1.0))
	for t in _match.tanks.get_children():
		if t is Tank and (t as Tank).team != Match.Team.GREEN:
			(t as Tank).global_position = Vector3(corner.x, (t as Tank).global_position.y, corner.z)
			(t as Tank).velocity = Vector3.ZERO


## O3 (round 37, the contention guard): friendly hull contacts, from each of his hulls' physics collisions this tick
## (CharacterBody3D slide collisions with another of his Tanks); a pair counts once when it starts touching.
## `_contacts` all pairs, `_contacts_foreign` pairs from different squads (as dealt at the start), `_contact_ticks`
## pair-ticks in contact.
var _contacts := 0
var _contacts_foreign := 0
var _contact_ticks := 0
var _contact_last := {}


func _watch_contacts() -> void:
	var squad_of := {}
	for squad: Dictionary in _squads:
		for n: String in squad["units"]:
			squad_of[n] = int(squad["number"])
	var now := {}
	for t: Node in _match.tanks.get_children():
		var tank := t as Tank
		if tank == null or tank.team != Match.Team.GREEN or not tank.is_alive():
			continue
		for k in tank.get_slide_collision_count():
			var other := tank.get_slide_collision(k).get_collider() as Tank
			if other == null or other.team != Match.Team.GREEN or other == tank:
				continue
			var a := String(tank.name)
			var b := String(other.name)
			now[a + "|" + b if a < b else b + "|" + a] = [a, b]
	for key: String in now:
		_contact_ticks += 1
		if not _contact_last.has(key):
			_contacts += 1
			if squad_of.get(now[key][0], -1) != squad_of.get(now[key][1], -2):
				_contacts_foreign += 1
	_contact_last = now


## Every tick: decks crossed, the centre's path, arrival (and the hulls around it then), and the shuffle after it.
func _watch() -> void:
	_watch_contacts()
	for squad: Dictionary in _squads:
		var alive: Array = (squad["units"] as Array).filter(func(n: String) -> bool:
			var t := _tank(n)
			return t != null and t.is_alive())
		if alive.is_empty():
			continue
		var centre := _centre(alive)
		squad["driven"] = float(squad["driven"]) + _flat_d(centre, _last_centre[squad["number"]])
		_last_centre[squad["number"]] = centre
		for n: String in alive:
			var at := _tank(n).global_position
			if not bool(squad["deck"]) and SlotGround.near_deck(at, 0.0):
				squad["deck"] = true
				squad["deck_at"] = [_xz(at), snappedf((_match.tick - _order_tick) / float(SimClock.TICK_RATE), 0.1)]
			if not bool(squad["crossed"]) and _across(at):
				squad["crossed"] = true
				squad["crossed_at"] = [_xz(at), snappedf((_match.tick - _order_tick) / float(SimClock.TICK_RATE), 0.1)]
		var element := _controls.elements.of(String(alive[0])) if _controls.elements != null else null
		# Arrived: its element says so with nothing queued, or (a route's element is gone by its end) its centre is within
		# ARRIVE_M of its anchor with every crew still.
		var anchor: Variant = squad["anchor"]
		# A route's squad that has not set off yet is not "settled" at a last anchor near its start (round 34: a back-rank
		# squad read arrived at 0.1 s and then drove the whole route): it must first have been LEFT_M from its start.
		if _flat_d(centre, squad["start"]) >= LEFT_M or _flag("probe-route", "click") == "click":
			squad["left"] = true
		var settled := bool(squad.get("left", false)) and anchor is Vector3 and _flat_d(centre, anchor) <= ARRIVE_M \
				and alive.all(func(n: String) -> bool: return Vector2(_tank(n).velocity.x, _tank(n).velocity.z).length() < 0.5)
		if int(squad["arrived_tick"]) < 0 and _match.tick > _order_tick + 2 \
				and ((element != null and element.arrived and element.queued_tasks.is_empty()) or settled):
			squad["arrived_by"] = "element" if element != null and element.arrived else "settled"
			squad["arrived_tick"] = _match.tick
			var seats := {}
			for n: String in alive:
				seats[n] = _tank(n).global_position
			squad["at_arrival"] = seats
			squad["foreign"] = _nearest(alive, func(t: Tank) -> bool: return t.team == Match.Team.GREEN \
					and not (squad["units"] as Array).has(String(t.name)))
			squad["enemy"] = _nearest(alive, func(t: Tank) -> bool: return t.team != Match.Team.GREEN)
		# `--probe-trace=N`: squad N's crews every second (position, own goal, the brain's option), to read a crossing.
		if int(_flag("probe-trace", "0")) == int(squad["number"]) and (_match.tick - _order_tick) % SimClock.TICK_RATE == 0:
			var parts: Array = []
			for n: String in alive:
				var goal: Variant = _controls.orders.goal_position(n)
				var mover := Movement.of(_tank(n))
				var option := ""
				if mover != null and mover.ctl is TankBrain:
					option = String((mover.ctl as TankBrain).choice.get("option", ""))
				# Round 36 (orders): the crew's element NOW (untangle and the split re-deal vehicles between squads).
				var elements := Elements.of_match(_match)
				var now: Element = elements.of(n) if elements != null else null
				# Round 37 (orders O2): the crew's own words (TankBrain.label + why), to read a parked crew that moves.
				var station: Variant = OrderFeed.station(_controls.orders, n)
				var drive: Variant = mover.get("_goal") if mover != null else null
				parts.append("%s(%.1f,%.1f goal %s %s el %s \"%s\" st %s drv %s)" % [n, _tank(n).global_position.x, _tank(n).global_position.z,
						str(_xz(goal)) if goal is Vector3 else "-", option, now.element_name if now != null else "-", _tank(n).intent,
						str(_xz(station)) if station is Vector3 else "-",
						str(_xz(drive)) if drive is Vector3 and (drive as Vector3).is_finite() else "-"])
			print("ORDERS_PROBE_TRACE t=%d %s" % [(_match.tick - _order_tick) / SimClock.TICK_RATE, " ".join(parts)])
		# Each crew's OWN destination (its formation slot, not the squad's anchor), sampled every half second: one past a
		# deck on the far bank is a crew sent over the river however the anchor was capped.
		if (_match.tick - _order_tick) % (SimClock.TICK_RATE / 2) == 0:
			for n: String in alive:
				var goal: Variant = _controls.orders.goal_position(n)
				if goal is Vector3 and _across(goal) and not (squad["goals_across"] as Array).any(func(g: Array) -> bool: return g[0] == n):
					(squad["goals_across"] as Array).append([n, _xz(goal), snappedf((_match.tick - _order_tick) / float(SimClock.TICK_RATE), 0.1)])
		if int(squad["arrived_tick"]) >= 0:
			var seats: Dictionary = squad["at_arrival"]
			for n: String in alive:
				if seats.has(n):
					squad["shuffle"] = maxf(float(squad["shuffle"]), _flat_d(_tank(n).global_position, seats[n]))
			# Round 36 (orders, R36.6 trace): a crew untangle dealt to ANOTHER squad's element drives with that squad, so the
			# place move and twitch are read over the crews of this squad's own element only (Terminus 5 route s3624:
			# Delta_2, element Echo from the order on, read as a 69.8 m "twitch"); `redealt` counts the others.
			var elements_now := Elements.of_match(_match)
			var mine: Array = alive.filter(func(n: String) -> bool:
				return element == null or elements_now == null or elements_now.of(n) == element)
			squad["redealt"] = maxi(int(squad.get("redealt", 0)), alive.size() - mine.size())
			_watch_place(squad, mine, element)
			_watch_halt(squad, mine, element)


## Round 37 (orders O1, R36.26): the halt-shape flicker. From the end of the place window on, within one task (the element's
## task_seq unchanged): `shape_flips` counts changes of the element's formation, `terrain_flips` changes of
## ElementSituation.terrain_at at the crews' centroid (main's read), `anchor_terrain_flips` at the element's anchor, and
## `reseats` the element's reseat goal moves (Element.goal_moves) since then. `shapes` lists the shapes seen.
func _watch_halt(squad: Dictionary, alive: Array, element: Element) -> void:
	if element == null or alive.is_empty() or not squad.has("placed"):
		return  # from the end of the place window on (as twitch_m): the deploy's travel -> halt change is not a flip
	var centre_terrain := ElementSituation.terrain_at(_centre(alive))
	var anchor_terrain := ElementSituation.terrain_at(element.anchor) if element.anchor is Vector3 else "-"
	# The terrain the element itself reads this arm (its halt's shape AND spacing follow it): `relays` counts updates where
	# the shape or that terrain changed, the deciding count (a lanes <-> dense flip keeps the herringbone but re-spaces it).
	var read_terrain := ElementSituation.terrain_at(ElementSituation.terrain_point(_centre(alive),
			{"arrived": element.arrived, "anchor": element.anchor}))
	var reseats := int(element.goal_moves.get("reseat", 0))
	if not squad.has("halt_seq") or int(squad["halt_seq"]) != element.task_seq:
		squad["halt_seq"] = element.task_seq
		squad["halt_last"] = [element.formation, centre_terrain, anchor_terrain, read_terrain]
		squad["reseat_from"] = reseats
		if not squad.has("shape_flips"):
			squad["shape_flips"] = 0
			squad["terrain_flips"] = 0
			squad["anchor_terrain_flips"] = 0
			squad["relays"] = 0
			squad["shapes"] = [element.formation]
		return
	var last: Array = squad["halt_last"]
	if element.formation != String(last[0]) or read_terrain != String(last[3]):
		squad["relays"] = int(squad["relays"]) + 1
	if element.formation != String(last[0]):
		squad["shape_flips"] = int(squad["shape_flips"]) + 1
		if not (squad["shapes"] as Array).has(element.formation):
			(squad["shapes"] as Array).append(element.formation)
	if centre_terrain != String(last[1]):
		squad["terrain_flips"] = int(squad["terrain_flips"]) + 1
	if anchor_terrain != String(last[2]):
		squad["anchor_terrain_flips"] = int(squad["anchor_terrain_flips"]) + 1
	squad["halt_last"] = [element.formation, centre_terrain, anchor_terrain, read_terrain]
	squad["reseats"] = int(squad.get("reseats", 0)) + reseats - int(squad["reseat_from"])
	squad["reseat_from"] = reseats


## D2: the place move (from the deploy, or the arrival with the step off) and the twitch after it.
func _watch_place(squad: Dictionary, alive: Array, element: Element) -> void:
	if not squad.has("place_tick"):
		var deploy: Dictionary = element.deploy if element != null else {}
		var started := not ElementPlan.DEPLOY_STEP or element == null or bool(deploy.get("deployed", false))
		if not started:
			return
		squad["place_tick"] = _match.tick
		squad["deploy_cause"] = String(deploy.get("cause", "arrived")) if ElementPlan.DEPLOY_STEP else "arrived"
		squad["place_from"] = _seats(alive)
		squad["place"] = 0.0
		squad["twitch"] = 0.0
		return
	var since := _match.tick - int(squad["place_tick"])
	if since == SimClock.TICK_RATE and element != null:
		_deploy_legs(squad, alive, element)
	if since <= int(PLACE_S * SimClock.TICK_RATE):
		var from: Dictionary = squad["place_from"]
		for n: String in alive:
			if from.has(n):
				squad["place"] = maxf(float(squad["place"]), _flat_d(_tank(n).global_position, from[n]))
		if since == int(PLACE_S * SimClock.TICK_RATE):
			squad["placed"] = _seats(alive)
		return
	var placed: Dictionary = squad["placed"]
	# Round 36 (orders, R36.6 traces): a crew driving AWAY from its own order goal (the distance to it growing while it has
	# one), summed per crew after the place window; the worst crew's metres are `away_m`. A turn-around loop (Locks 3
	# click s3624: Bravo_1's seat 7 m north, it drove 30 m south over the canal and back) reads as tens of metres.
	var last_gap: Dictionary = squad.get("goal_gap", {})
	var away: Dictionary = squad.get("away", {})
	for n: String in alive:
		var goal: Variant = _controls.orders.goal_position(n)
		if goal is Vector3:
			var gap := _flat_d(_tank(n).global_position, goal)
			if last_gap.has(n) and gap > float(last_gap[n]):
				away[n] = float(away.get(n, 0.0)) + gap - float(last_gap[n])
			last_gap[n] = gap
		else:
			last_gap.erase(n)
	squad["goal_gap"] = last_gap
	squad["away"] = away
	# Round 37 (orders O4, R36.24): `away_m` counts a goal that FLIPS as driving away (Bravo_2's seat <-> a point ~15 m off,
	# every second: 52.5 m of "away" with the hull creeping 3-5 m). Two reads that do not: `away_held_m` sums a crew's
	# gap growth only while its goal is unchanged (within GOAL_SAME_M of last tick's), and `away_seat_m` against a fixed
	# seat, the spot it stood on at the end of the place window. The worst crew's metres each.
	var last_goal: Dictionary = squad.get("goal_last", {})
	var held: Dictionary = squad.get("away_held", {})
	var seat_gap: Dictionary = squad.get("seat_gap", {})
	var seat_away: Dictionary = squad.get("away_seat", {})
	for n: String in alive:
		var goal: Variant = _controls.orders.goal_position(n)
		if goal is Vector3 and last_goal.get(n) is Vector3 and _flat_d(goal, last_goal[n]) <= GOAL_SAME_M \
				and last_gap.has(n) and squad.has("gap_prev") and (squad["gap_prev"] as Dictionary).has(n):
			var grew := float(last_gap[n]) - float(squad["gap_prev"][n])
			if grew > 0.0:
				held[n] = float(held.get(n, 0.0)) + grew
		last_goal[n] = goal
		if placed.has(n):
			var from_seat := _flat_d(_tank(n).global_position, placed[n])
			if seat_gap.has(n) and from_seat > float(seat_gap[n]):
				seat_away[n] = float(seat_away.get(n, 0.0)) + from_seat - float(seat_gap[n])
			seat_gap[n] = from_seat
	squad["gap_prev"] = last_gap.duplicate()
	squad["goal_last"] = last_goal
	squad["away_held"] = held
	squad["seat_gap"] = seat_gap
	squad["away_seat"] = seat_away
	# O2 (round 37): a crew more than PARKED_OFF_M off its placed seat with NO order goal is off it by its own choice
	# (his "stay put and shoot"); `self_off` keeps each such crew's farthest.
	var self_off: Dictionary = squad.get("self_off", {})
	for n: String in alive:
		if placed.has(n) and not (_controls.orders.goal_position(n) is Vector3):
			var off := _flat_d(_tank(n).global_position, placed[n])
			if off > PARKED_OFF_M:
				if not self_off.has(n):
					# What took it off: the brain's option the tick it passed PARKED_OFF_M, "+nogoal" when its Movement had
					# no goal set then (a give-way push, or an option that steers without one: SPOT, RETREAT read so).
					var mover := Movement.of(_tank(n))
					var why := String((mover.ctl as TankBrain).choice.get("option", "")) if mover != null and mover.ctl is TankBrain else "-"
					var drive: Variant = mover.get("_goal") if mover != null else null
					if not (drive is Vector3 and (drive as Vector3).is_finite()):
						why += "+nogoal"
					var by: Dictionary = squad.get("left_by", {})
					by[why] = int(by.get(why, 0)) + 1
					squad["left_by"] = by
				self_off[n] = maxf(float(self_off.get(n, 0.0)), off)
	squad["self_off"] = self_off
	for n: String in alive:
		if placed.has(n):
			var moved := _flat_d(_tank(n).global_position, placed[n])
			if moved > TWITCH_SEEN_M:
				# Round 36 (orders, the "neither" twitch): every brain option a crew shows while off its placed seat
				# (+ "@goal" when it has an order goal then): MOVE@goal = driving to its seat; ADVANCE etc = its own fight.
				var mover := Movement.of(_tank(n))
				var option := String((mover.ctl as TankBrain).choice.get("option", "")) if mover != null and mover.ctl is TankBrain else "-"
				if _controls.orders.goal_position(n) is Vector3:
					option += "@goal"
				var seen: Dictionary = squad.get("twitch_seen", {})
				seen[option] = int(seen.get(option, 0)) + 1
				squad["twitch_seen"] = seen
			squad["twitch"] = maxf(float(squad["twitch"]), moved)


## O2 (round 36): the deploy move's geometry, read 1 s after the deploy (the halt's seats issued): each crew's leg from where
## it stood at the deploy to its halt seat, how many legs drive PAST a squadmate (the leg's segment within PASS_M of another
## crew's spot at the deploy, that crew not at the leg's end), the travel shape's width across the heading and the halt's
## depth along it, and the halt's shape.
const PASS_M := 4.0
const DETOUR_M := 8.0
## A crew this far off its placed seat after the place window counts toward `twitch_seen` (ticks a brain option was shown).
const TWITCH_SEEN_M := 3.0
## O2 (round 37): off its placed seat by more than this with no order goal = it left the seat by itself.
const PARKED_OFF_M := 6.0
## ... and back on it at the window's end within this.
const BACK_M := 3.0
## O4 (round 37): a crew's order goal this close to last tick's is the same goal (`away_held_m`).
const GOAL_SAME_M := 0.5


func _deploy_legs(squad: Dictionary, alive: Array, element: Element) -> void:
	var from: Dictionary = squad["place_from"]
	var heading: Vector3 = element.deploy.get("heading", Vector3.FORWARD)
	var side := Vector3(-heading.z, 0.0, heading.x)
	var worst := 0.0
	var passes := 0
	var across: Array = []
	var along: Array = []
	for n: String in alive:
		var seat: Variant = element.slots.get(n)
		if not (seat is Vector3) or not from.has(n):
			continue
		var a: Vector3 = from[n]
		var b: Vector3 = seat
		worst = maxf(worst, _flat_d(a, b))
		across.append(Vector3(a.x, 0.0, a.z).dot(side))
		along.append(Vector3(b.x, 0.0, b.z).dot(heading))
		for other: String in alive:
			if other == n or not from.has(other):
				continue
			var o: Vector3 = from[other]
			if _flat_d(o, b) > PASS_M and Geometry2D.get_closest_point_to_segment(Vector2(o.x, o.z), Vector2(a.x, a.z),
					Vector2(b.x, b.z)).distance_to(Vector2(o.x, o.z)) <= PASS_M and _flat_d(o, a) > PASS_M:
				passes += 1
				break
	# Counterfactuals (trace only): the worst leg with the best seating of the same seats, and with the halt's depth along
	# the heading halved about its middle (side offsets kept).
	var starts: Array = []
	var seats: Array = []
	for n: String in alive:
		if from.has(n) and element.slots.get(n) is Vector3:
			starts.append(from[n])
			seats.append(element.slots[n])
	var mid := 0.0
	for seat: Vector3 in seats:
		mid += seat.dot(heading) / float(seats.size())
	var compact: Array = seats.map(func(seat: Vector3) -> Vector3: return seat - heading * (seat.dot(heading) - mid) * 0.5)
	squad["leg_minmax_m"] = _minmax_leg(starts, seats)
	squad["leg_compact_m"] = _minmax_leg(starts, compact)
	# O3 (X3c's falsifier): each crew's DRIVE to its halt seat against the straight line, and whether X3c's anchor test
	# (drive from the halt's anchor <= straight x 1.3 + 3 m, no deck) fails that seat. A detour the anchor test passes is a
	# loop the reached halt would not catch.
	var detour_worst := 0.0
	var detours := 0
	var caught := 0
	var anchor: Vector3 = element.anchor if element.anchor is Vector3 else Vector3.ZERO
	var drive := SelectionSquads.drive_on(_tank(alive[0]))
	var crosses := SelectionSquads.crosses_on(_tank(alive[0]))
	for n: String in alive:
		var seat: Variant = element.slots.get(n)
		if not (seat is Vector3) or not from.has(n):
			continue
		var straight := _flat_d(from[n], seat)
		var detour := float(drive.call(from[n], seat)) - straight
		detour_worst = maxf(detour_worst, detour)
		if detour >= DETOUR_M:
			detours += 1
			var a_straight := _flat_d(anchor, seat)
			if a_straight >= 0.5 and (float(drive.call(anchor, seat)) > a_straight * 1.3 + 3.0 or bool(crosses.call(anchor, seat))):
				caught += 1
	squad["detour_worst_m"] = detour_worst
	squad["detours"] = detours
	squad["detours_caught"] = caught
	squad["deploy_leg_m"] = worst
	squad["deploy_passes"] = passes
	squad["travel_width_m"] = (across.max() - across.min()) if across.size() > 1 else 0.0
	squad["halt_depth_m"] = (along.max() - along.min()) if along.size() > 1 else 0.0
	squad["halt_shape"] = element.formation


## The shortest possible longest leg from `starts` to `seats` (every assignment; a squad is <= 6 crews).
func _minmax_leg(starts: Array, seats: Array) -> float:
	if starts.size() != seats.size() or starts.is_empty() or starts.size() > 6:
		return -1.0
	var best := [INF]
	var walk := func(walk_self: Callable, i: int, used: Array, worst: float) -> void:
		if worst >= float(best[0]):
			return
		if i == starts.size():
			best[0] = worst
			return
		for j in seats.size():
			if not used[j]:
				used[j] = true
				walk_self.call(walk_self, i + 1, used, maxf(worst, _flat_d(starts[i], seats[j])))
				used[j] = false
	var used: Array = []
	used.resize(seats.size())
	used.fill(false)
	walk.call(walk, 0, used, 0.0)
	return float(best[0])


func _seats(alive: Array) -> Dictionary:
	var seats := {}
	for n: String in alive:
		seats[n] = _tank(n).global_position
	return seats


## A static of `script` by name, or -1 on a tree before it existed (the probe runs on both sides of a change).
static func _static_or(script: Script, name: String) -> int:
	for property in script.get_property_list():
		if String(property["name"]) == name:
			return int(script.get(name))
	return -1


## At the window's end: the element's arrived flag, its queue, its task's verb, and the centre's distance to the anchor.
func _end_state(squad: Dictionary) -> Dictionary:
	var element := _controls.elements.of(String(squad["units"][0])) if _controls.elements != null else null
	var anchor: Variant = squad["anchor"]
	return {"arrived": element.arrived if element != null else null,
			"queued": element.queued_tasks.size() if element != null else -1,
			"verb": String(element.task.get("verb", "")) if element != null else "",
			"centre_to_anchor_m": snappedf(_flat_d(_centre(squad["units"]), anchor), 0.1) if anchor is Vector3 else -1.0}


## The squad's own anchor: its element's last task destination (the route's last waypoint for a queued route).
func _anchor_of(squad: Dictionary) -> Variant:
	var element := _controls.elements.of(String(squad["units"][0])) if _controls.elements != null else null
	if element == null:
		var goal: Variant = _controls.orders.goal_position(String(squad["units"][0]))
		return goal
	var task: Dictionary = element.queued_tasks.back() if not element.queued_tasks.is_empty() else element.task
	var to: Variant = task.get("to")
	return Vector3(float(to[0]), 0.0, float(to[1])) if to is Array and (to as Array).size() >= 2 else null


func _pick_click(map: String, army: Vector3, forward: Vector3) -> Vector3:
	var given := _flag("probe-click", "")
	if given != "":
		var xz := given.split(",")
		return Vector3(float(xz[0]), 0.0, float(xz[1]))
	var best: Variant = null
	for box: Array in SlotGround.deck_boxes():
		var mid := Vector3((float(box[0]) + float(box[2])) * 0.5, 0.0, (float(box[1]) + float(box[3])) * 0.5)
		if best == null or mid.length() < (best as Vector3).length():
			best = mid
	var picked := Orders.clamp_to_arena(army + forward * 60.0)
	if best != null:
		# DECK_BACK_M short of the deck along the player's forward axis, on his side.
		var back := forward * -1.0 if (best as Vector3).dot(forward) > army.dot(forward) else forward
		picked = Orders.clamp_to_arena((best as Vector3) + back * DECK_BACK_M)
	return _jitter(picked)


## Round 35 (D5's bar, fresh seeds): the probe's army and click are otherwise fixed, so every seed played the same run
## (seed 3601 = seed 34, byte for byte). A seed other than REFERENCE_SEED moves the click up to CLICK_JITTER_M (and so the
## route's waypoints), to a dry point his squads could stand on; seed 34 is round 34's reference cell, unmoved.
const REFERENCE_SEED := 34
const CLICK_JITTER_M := 12.0


func _jitter(click: Vector3) -> Vector3:
	var seed_value := int(_flag("seed", str(REFERENCE_SEED)))
	if seed_value == REFERENCE_SEED:
		return click
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ground: Tank = null
	for squad: Dictionary in _squads:
		ground = _tank(String(squad["units"][0]))
		if ground != null:
			break
	for attempt in 40:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * CLICK_JITTER_M
		var p := Orders.clamp_to_arena(click + Vector3(cos(angle), 0.0, sin(angle)) * r)
		if not SlotGround.over_water(p) and (ground == null or SlotGround.is_standable(ground, p)):
			return p
	return click


func _shots(label: String) -> void:
	var out := _flag("probe-shots", "")
	if out == "" or DisplayServer.get_name() == "headless" or _shot.has(label):
		return
	_shot[label] = true
	DirAccess.make_dir_recursive_absolute(out)
	var everyone: Array = []
	for squad: Dictionary in _squads:
		everyone += squad["units"]
	var centre := _centre(everyone).lerp(_click, 0.5)
	var extent := 40.0
	for n: String in everyone:
		var t := _tank(n)
		if t != null:
			extent = maxf(extent, _flat_d(t.global_position, centre) + 15.0)
	extent = maxf(extent, _flat_d(_click, centre) + 15.0)
	# The HUD's 2D layers (order rings, labels) are projected through the GAME's perspective camera, so under this
	# orthographic one they land in the wrong place (round 34: a ring drawn "in the void" was read as an anchor outside
	# the walls). They are hidden for the shot; the click (white) and each squad's anchor (a coloured post, squad order)
	# are marked in 3D instead, so everything in the frame is where it is.
	var hidden: Array = []
	for layer in current_scene.find_children("*", "CanvasLayer", true, false):
		if (layer as CanvasLayer).visible:
			(layer as CanvasLayer).visible = false
			hidden.append(layer)
	var marks: Array = [_post(_click, Color.WHITE, 3.0)]
	for i in _squads.size():
		var anchor: Variant = (_squads[i] as Dictionary)["anchor"]
		if anchor is Vector3:
			marks.append(_post(anchor, MARK_COLOURS[i % MARK_COLOURS.size()], 2.0))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent * 2.0
	camera.far = 400.0
	current_scene.add_child(camera)
	camera.global_position = Vector3(centre.x, 200.0, centre.z)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	var was := root.get_camera_3d()
	camera.make_current()
	var stem := "%s-%d-%s-%s-%s" % [_flag("arena", "locks"), _squads.size(), _flag("probe-route", "click"),
			_flag("probe-arm", "cap%s-halt%s" % ["on" if SelectionSquads.GROUND_CAP else "off", "on" if SelectionSquads.HALT_PRICE else "off"]), label]
	for aspect: String in SHOT_SIZES:
		DisplayServer.window_set_size(SHOT_SIZES[aspect])
		root.size = SHOT_SIZES[aspect]
		for i in 6:
			await process_frame
		var image := root.get_texture().get_image()
		var path := out.path_join("%s-%s.png" % [stem, aspect])
		image.save_png(path)
		print("ORDERS_PROBE_SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
	camera.queue_free()
	for mark: Node in marks:
		mark.queue_free()
	for layer: CanvasLayer in hidden:
		layer.visible = true
	if was != null:
		was.make_current()


## A tall unshaded post at `at` (seen from above as a disc): a mark that is in the world, not on the HUD.
func _post(at: Vector3, colour: Color, radius: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 30.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	mesh.material = material
	var post := MeshInstance3D.new()
	post.mesh = mesh
	current_scene.add_child(post)
	post.global_position = Vector3(at.x, 15.0, at.z)
	return post


func _nearest(alive: Array, keep: Callable) -> float:
	var best := INF
	for t in _match.tanks.get_children():
		if not (t is Tank) or not (t as Tank).is_alive() or not keep.call(t):
			continue
		for n: String in alive:
			best = minf(best, _flat_d((t as Tank).global_position, _tank(n).global_position))
	return best if best < INF else -1.0


## The closest two of `alive` (centre to centre, or hull to hull with `hulls`); -1 with fewer than two.
func _own_min(alive: Array, hulls: bool) -> float:
	var best := INF
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a := _tank(alive[i])
			var b := _tank(alive[j])
			var d := _flat_d(a.global_position, b.global_position)
			if hulls:
				d -= SlotGround.envelope_of(String(a.unit_id)) + SlotGround.envelope_of(String(b.unit_id))
			best = minf(best, d)
	return best if best < INF else -1.0


func _sum_values(d: Dictionary) -> int:
	var total := 0
	for v: Variant in d.values():
		total += int(v)
	return total


func _living(squad: Dictionary) -> Array:
	return (squad["units"] as Array).filter(func(n: String) -> bool:
		var t := _tank(n)
		return t != null and t.is_alive())


func _tank(unit_name: String) -> Tank:
	return _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank if _match != null else null


func _centre(names: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for unit_name: String in names:
		var t := _tank(unit_name)
		if t != null:
			sum += Vector3(t.global_position.x, 0.0, t.global_position.z)
			n += 1
	return sum / maxf(n, 1)


static func _flat_d(a: Variant, b: Variant) -> float:
	return Vector2((a as Vector3).x - (b as Vector3).x, (a as Vector3).z - (b as Vector3).z).length()


static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]
