extends TestCase
## Round 32 (C32.8 / R31.9): the stage of test_tactics_pursuit*.gd (split by time); no tests of its own.
## Round 21 (brains P2): AN ATTACK ON A NAMED TARGET THAT MOVES IS A PURSUIT. His game (foundry, seed 29989,
## build/recordings/2026-10-06T18-38-40.jsonl, tick 1827): he named `Rust_Eyes_3`, a Syndicate spotter retreating from
## (-33, 6) to (15, -112) over 17 s; Bravo_1 drove past the target's old spot and back (an orbit ~40 m across) and
## Delta_1, the last of his scouts, "arrived" 70 m short and sat. *"even when there was only one vehicle remaining it was
## still just driving in circles instead of actually moving to the target I designated"*.
##
## The stage: the open yard, five gang scouts (Rat Rods, 18 m/s, the spear's 30 m) abreast at the Green spawn, HIS squad,
## {"verb": "attack", "target": <it>, "formation": "vee"}; one Syndicate spotter platform 70 m ahead that drives away
## from them, then doglegs, at a set speed. Measured every half second while the target lives:
##   * closing: for every crew and every t after the first leg (FIRST_LEG_S) at which it is still chasing (farther than
##     FIGHTING_M), its distance to the target at t + 5 s is not more than at t (+ CLOSING_SLACK_M);
##   * no orbit: no chasing crew's HULL heading turns more than REVERSAL_DEG within REVERSAL_WINDOW_S while it drives
##     (above DRIVING_MPS). The hull, not the direction of travel: a crew backing a metre to get round a squadmate
##     flips its velocity 180 degrees without turning at all, and an orbit is the hull going round.

const FIRST_LEG_S := 5.0
const CLOSING_WINDOW_S := 5.0
const CLOSING_SLACK_M := 2.0
const REVERSAL_DEG := 120.0
const REVERSAL_WINDOW_S := 4.0
## A crew counts as driving (its heading means something) above this speed (m/s).
const DRIVING_MPS := 4.0
## Both measures are of the CHASE: a crew within this of the target (the spear's 30 m band and a little) is fighting it,
## and turning round a target it is shooting at is the brain's fight (ORBIT, FLANK), not the bug he saw.
const FIGHTING_M := 35.0
const SAMPLE_TICKS := SimClock.TICK_RATE / 2
## Round 25 (F1b, C25.3 ruling): "badly hurt" (decide's own RETREAT threshold at caution 0), and how far back (samples,
## 2 s) the target's gun on a crew still excuses it peeling off.
const BADLY_HURT := 0.15
const EXCUSE_BACK := 4
## The open yard (round 18's yard with its containers lifted): the pursuit is measured where nothing but the chase turns a
## hull. On the container yard a crew that meets a 12 m container backs round it, which is routing, not an orbit.
const ARENA := "yard_open"


## {"closing_worst_m", "closing_at", "reversal_worst_deg", "reversal_at", "lived_s", "start_m", "end_m": {crew: m},
##  "drills", "why"}
## Round 31 (brains B5c-v5, C31.6): `nudge_m` moves each crew's start by that much in a direction drawn from the seed (0 =
## the stage as written): the A/A (`make pursuit-aa`) asks how far an inconsequential change to the opening carries.
func _pursue(speed_mps: float, seconds: float, seed_value := 3, start_m := 70.0, pursuer := "gang_scout",
		nudge_m := 0.0) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, ARENA)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	home.y = 0.0
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	var nudge := RandomNumberGenerator.new()
	nudge.seed = seed_value
	for i in 5:
		var at := home + right * ((i - 2) * 6.0) - toward * (i % 2) * 4.0
		if nudge_m > 0.0:
			at += Vector3.FORWARD.rotated(Vector3.UP, nudge.randf_range(-PI, PI)) * nudge_m
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, yaw, pursuer).name))
	var start := home + toward * start_m
	var target := lab.gun(Match.Team.RUST, "Rust_Eyes_1", start, yaw, "syn_lancer")
	target.max_forward_speed = maxf(speed_mps, target.max_forward_speed)
	var pace := clampf(speed_mps / target.max_forward_speed, 0.2, 1.0)
	# Away from them, then bearing off to the right (60 degrees, then 90): a target that only ran straight would hide an
	# orbit's cause. It never turns back toward them (a pursuer has to turn round for that, and it is no orbit).
	var waypoints: Array = []
	for w: Vector3 in [start + toward * 80.0, start + toward * 120.0 + right * 70.0, start + toward * 120.0 + right * 160.0]:
		waypoints.append(ElementPlan.clamp_to_arena(w))
	var controller := game_match.brains.get_node("Orders_Rust_Eyes_1") as OrderController
	await lab.start()
	if OS.get_environment("PURSUIT_OBSTACLES") != "":
		var stack: Array = [lab.arena]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is StaticBody3D:
				var at := _flat((node as Node3D).global_position)
				if at.distance_to(Vector3(-20, 0, 30)) < 25.0:
					print("OBSTACLE %s at %s" % [node.name, at.round()])
	var element := lab.elements.form(names, "Alpha")
	element.assign({"verb": "attack", "target": String(target.name), "formation": "vee"})
	var leg := 0
	controller.set_orders(_drive(waypoints[0], pace), {"type": "fire_at_will"})
	var distances := {}
	var headings := {}
	var starts := {}
	# Round 25 (F1b, C25.3 ruling): per sample, whether the crew may peel off (the lead: "Stay on the chase"; it peels
	# off only when badly hurt or when the target turns and fights): hull under BADLY_HURT, or the target's gun on it.
	var excused := {}
	# Round 31 (R31.3 (a)): per sample, whether the crew is badly hurt (the same BADLY_HURT): the closing and reversal
	# lines excuse it as the let-go line does. Traced (builder0, main, 18 m/s seed 1): Green_A_1 shot to 1 % at 5.0 s broke
	# away home (decide's RETREAT, as the lead asked) and failed both lines; seed 9 the same.
	var hurt_marks := {}
	for unit_name: String in names:
		distances[unit_name] = []
		headings[unit_name] = []
		excused[unit_name] = []
		hurt_marks[unit_name] = []
		starts[unit_name] = lab.tank_of(unit_name).global_position.distance_to(target.global_position)
	# Round 26 (traffic CP1a, C26.6 ruling): who killed the target, from the match's kill signal (the kill log's
	# "Green_A_3 destroyed Rust_Eyes_1").
	var killer := {"name": ""}
	game_match.tank_destroyed.connect(func(victim: Tank, by: String) -> void:
		if victim == target:
			killer["name"] = by)
	var lived := 0
	var arrived_ticks := 0
	var forgotten_ticks := 0
	var whys := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		if leg < waypoints.size() and _flat(target.global_position).distance_to(_flat(waypoints[leg])) < 6.0:
			leg += 1
			if leg < waypoints.size():
				controller.set_orders(_drive(waypoints[leg], pace), {"type": "fire_at_will"})
		await lab.step()
		if not target.is_alive():
			break
		lived = tick + 1
		if tick > SimClock.TICK_RATE and element.arrived:
			arrived_ticks += 1
		if not (game_match.intel[Match.Team.GREEN] as Dictionary).has(String(target.name)):
			forgotten_ticks += 1
		if element.reason != "":
			whys[element.reason] = true
		if OS.get_environment("PURSUIT_CREW") != "" and tick % 6 == 0:
			for crew: String in OS.get_environment("PURSUIT_CREW").split(","):
				var t := lab.tank_of(crew)
				if t == null or not t.is_alive():
					continue
				var brain := game_match.brains.get_node_or_null("Brain_" + crew)
				var order: Dictionary = lab.orders.call("current", crew)
				print("CREW t=%.1f %s hp=%.2f pos=%s v=%s d=%.1f order=%s/%s to=%s brain=%s slot=%s" % [float(tick) / SimClock.TICK_RATE, crew,
						float(t.health) / float(t.max_health),
						_flat(t.global_position).round(), _flat(t.estimated_velocity).round(),
						_flat(t.global_position).distance_to(_flat(target.global_position)), order.get("verb", "-"),
						order.get("target", ""), order.get("to", "-"), "-" if brain == null else "%s %s" % [brain.get("choice").get("option", ""), brain.get("why")],
						element.slots.get(crew, "-")])
		if OS.get_environment("PURSUIT_TRACE") != "" and tick % 15 == 0:
			var known: Dictionary = game_match.intel[Match.Team.GREEN].get(String(target.name), {})
			print("TRACE t=%.1f drill=%s why=%s arrived=%s anchor=%s center=%s target=%s known=%s vis=%s" % [float(tick) / SimClock.TICK_RATE,
					element.drill, element.reason, element.arrived, element.anchor, lab.center_of(names).round(),
					_flat(target.global_position).round(), known.get("position", Vector3.INF).round() if not known.is_empty() else "-",
					known.get("visible", "-")])
		if tick % SAMPLE_TICKS != 0:
			continue
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			var alive := tank != null and tank.is_alive()
			(distances[unit_name] as Array).append(
					_flat(tank.global_position).distance_to(_flat(target.global_position)) if alive else -1.0)
			var velocity := _flat(tank.estimated_velocity) if alive else Vector3.ZERO
			var chasing := alive and _flat(tank.global_position).distance_to(_flat(target.global_position)) > FIGHTING_M
			var hull := _flat(-tank.global_basis.z).normalized() if alive else Vector3.ZERO
			(headings[unit_name] as Array).append(hull if chasing and velocity.length() >= DRIVING_MPS else Vector3.ZERO)
			var hurt: bool = alive and float(tank.health) / float(tank.max_health) < BADLY_HURT
			var aimed := false
			if alive and target.is_alive():
				var to_me := _flat(tank.global_position - target.global_position).normalized()
				aimed = _flat(target.turret_forward()).normalized().dot(to_me) >= TankBrain.COS_AIMED_AT_ME
			(excused[unit_name] as Array).append(hurt or aimed)
			(hurt_marks[unit_name] as Array).append(hurt)
	var result := {"closing_worst_m": -INF, "closing_at": "", "reversal_worst_deg": 0.0, "reversal_at": "",
			"lived_s": snappedf(float(lived) / SimClock.TICK_RATE, 0.1), "start_m": {}, "end_m": {},
			"drills": lab.drills_of(element), "why": whys.keys(),
			"arrived_s": snappedf(float(arrived_ticks) / SimClock.TICK_RATE, 0.1),
			"forgotten_s": snappedf(float(forgotten_ticks) / SimClock.TICK_RATE, 0.1),
			"center_to_target_m": snappedf(_flat(lab.center_of(names)).distance_to(_flat(target.global_position)), 0.1)
					if lab.alive(names) > 0 and target.is_alive() else -1.0,
			"killed_by": killer["name"], "squad": names, "let_go_at": ""}
	var per_s := float(SimClock.TICK_RATE) / SAMPLE_TICKS
	var first := int(FIRST_LEG_S * per_s)
	var window := int(CLOSING_WINDOW_S * per_s)
	var turn_window := int(REVERSAL_WINDOW_S * per_s)
	for unit_name: String in names:
		var d: Array = distances[unit_name]
		var h: Array = headings[unit_name]
		result["start_m"][unit_name] = snappedf(float(starts[unit_name]), 0.1)
		result["end_m"][unit_name] = snappedf(float(d[-1]), 0.1) if not d.is_empty() else -1.0
		for i in range(first, d.size() - window):
			if float(d[i]) < FIGHTING_M or float(d[i + window]) < 0.0:
				continue
			if _excused(hurt_marks[unit_name], i - EXCUSE_BACK, i + window):
				continue  # badly hurt: peeling off is what the lead asked for
			var opened := float(d[i + window]) - float(d[i])
			if opened > float(result["closing_worst_m"]):
				result["closing_worst_m"] = snappedf(opened, 0.1)
				result["closing_at"] = "%s at %.1f s (%.1f -> %.1f m)" % [unit_name, i / per_s, d[i], d[i + window]]
		for i in h.size():
			if (h[i] as Vector3) == Vector3.ZERO:
				continue
			for j in range(i + 1, mini(h.size(), i + turn_window + 1)):
				if (h[j] as Vector3) == Vector3.ZERO:
					continue
				if _excused(hurt_marks[unit_name], i - EXCUSE_BACK, j):
					continue  # badly hurt: turning for home is the lead's rule, not an orbit
				var turned := rad_to_deg((h[i] as Vector3).angle_to(h[j]))
				if turned > float(result["reversal_worst_deg"]):
					result["reversal_worst_deg"] = snappedf(turned, 1.0)
					result["reversal_at"] = "%s %.1f -> %.1f s" % [unit_name, i / per_s, j / per_s]
	# ...and the squad as a whole never lets go: at no sample does EVERY crew still chasing open the range.
	for i in range(first, int(lived / SAMPLE_TICKS) - window):
		var chasing := 0
		var opening := 0
		var alive_crews := 0
		var all_excused := true
		var on_it := false  # some crew within FIGHTING_M of the (living) target at the window's end
		for unit_name: String in names:
			var d: Array = distances[unit_name]
			# Only crews alive at both ends of the window: a crew killed in it did not let go.
			if i + window >= d.size() or float(d[i]) < 0.0 or float(d[i + window]) < 0.0:
				continue
			alive_crews += 1
			var crew_excused := _excused(excused[unit_name], i - EXCUSE_BACK, i + window)
			all_excused = all_excused and crew_excused
			# Holding the chase: within FIGHTING_M of it at the window's end, or still closing over the window.
			if float(d[i + window]) >= 0.0 and (float(d[i + window]) < FIGHTING_M
					or float(d[i + window]) - float(d[i]) <= CLOSING_SLACK_M):
				on_it = true
			if float(d[i]) < FIGHTING_M or float(d[i + window]) < 0.0:
				continue
			if crew_excused:
				continue  # a crew allowed to peel off is not "the squad" letting go
			chasing += 1
			if float(d[i + window]) - float(d[i]) > CLOSING_SLACK_M:
				opening += 1
		if result["let_go_at"] == "":
			if chasing > 0 and opening == chasing:
				result["let_go_at"] = "%.1f s (%d of %d chasing crews opened)" % [i / per_s, opening, chasing]
			# The orchestrator's guard (C25.3): when EVERY crew is excused (all hurt or all under its gun) the chase must
			# still hold: some crew within FIGHTING_M of the target at the window's end, or still closing over it (the
			# target alive: sampling stops when it dies, and a kill is judged by killed_by_squad). "Still closing" was
			# added because the target's turret sweeps every crew within a 7 s window while they are 70 m back and closing.
			elif alive_crews > 0 and all_excused and not on_it:
				result["let_go_at"] = "%.1f s (every crew excused, none within %.0f m or closing)" % [i / per_s, FIGHTING_M]
	lab.dispose()
	return result


## Whether any sample in [from, to] of a crew's `marks` excuses it (badly hurt, or the target's gun on it).
static func _excused(marks: Array, from: int, to: int) -> bool:
	for k in range(maxi(from, 0), mini(to + 1, marks.size())):
		if bool(marks[k]):
			return true
	return false


static func _drive(point: Vector3, pace: float) -> Dictionary:
	return {"type": "move_to", "x": point.x, "z": point.z, "speed": pace}


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Round 31 (brains B5c-v5, the orchestrator's R31.3): ONE seed decided nothing. The A/A (`make pursuit-aa`, builder0,
## 3cb76e17, rule off, rows in references/round31/brains/) moved every crew's start 0.25 m and flipped 3 of 12 seeds'
## verdicts at 8 m/s, seed 3 among them. So each visible chase runs on PURSUIT_SEEDS (the test's seed and the next four,
## not chosen by outcome) with the same three lines per run, and passes when at least PURSUIT_PASSES do: on these seeds
## main passes 5/5 at both speeds and the nudged starts 3/5 (8 m/s) and 5/5 (18 m/s), the do-nothing floor.
const PURSUIT_SEEDS := [3, 4, 5, 6, 7]
const PURSUIT_PASSES := 3


## The three lines as one verdict per run, and why it failed ("" when it passed). Round 26 (brains, the orchestrator's
## ruling): the squad as a whole never lets go (the lead: "Stay on the chase"). Round 25's line, without its excuses on
## the closing and reversal lines (those came with the unpin, which does not ship): pinned seating passes it, nearest
## seating let go at 7.5 s (builder0 fe45a510), so it guards his answer.
static func pursuit_fails(result: Dictionary) -> String:
	var why: Array = []
	if float(result["closing_worst_m"]) > CLOSING_SLACK_M:
		why.append("a crew opened the range over 5 s (worst +%.1f m: %s)" % [float(result["closing_worst_m"]), result["closing_at"]])
	if String(result["let_go_at"]) != "":
		why.append("the whole squad let go at %s" % result["let_go_at"])
	if float(result["reversal_worst_deg"]) > REVERSAL_DEG:
		why.append("a crew reversed its heading (worst %.0f deg: %s)" % [float(result["reversal_worst_deg"]), result["reversal_at"]])
	return "; ".join(why)


func _assert_pursuit_seeds(speed_mps: float, seconds: float) -> void:
	var passes := 0
	var failed: Array = []
	for seed_value: int in PURSUIT_SEEDS:
		var result: Dictionary = await _pursue(speed_mps, seconds, seed_value)
		var why := pursuit_fails(result)
		print("MEASURE pursuit %s seed %d five gang scouts v a spotter at %.0f m/s: %s %s" % [ARENA, seed_value, speed_mps,
				"PASS" if why == "" else "FAIL (%s)" % why, result])
		if why == "":
			passes += 1
		else:
			failed.append("seed %d: %s" % [seed_value, why])
	assert_true(passes >= PURSUIT_PASSES, "%.0f m/s: %d of %d seeds chased it down (need %d): %s"
			% [speed_mps, passes, PURSUIT_SEEDS.size(), PURSUIT_PASSES, failed])


## The recording's case (the orchestrator's question): a target that leaves the squad's sight ENTIRELY, long enough
## for its team's intel to forget it (12 s). Five Law tanks (12 m/s, 78 m of sight) see it 60 m off and it drives away at
## 18 m/s, out of their sight. Before P2 the squad "arrived" short and sat once intel forgot it; now it follows its own
## track of it: never arrived while the target lives, and it finds it again.
## C25.3's line, as ruled for round 26 (traffic CP1a, C26.6): the squad finds it again when one of ITS crews killed it,
## or when it ends within 40 m of it. A target dead by anyone else's hand, or alive and far, is not found. Pure.
static func found_again(result: Dictionary) -> bool:
	if (result.get("squad", []) as Array).has(String(result.get("killed_by", ""))):
		return true
	var gap := float(result.get("center_to_target_m", -1.0))
	return gap >= 0.0 and gap <= 40.0


# ---- Pure: the pieces of the pursuit ------------------------------------------------------------------------------

func _situation(count: int, contacts: Array = [], threat := "none") -> Dictionary:
	var members: Array = []
	var center := Vector3.ZERO
	for i in count:
		var at := Vector3(i * 6.0 - (count - 1) * 3.0, 0.0, 0.0)
		members.append({"name": "Green_%d" % (i + 1), "position": at, "forward": Vector3.FORWARD, "role": "scout",
				"unit": "gang_scout", "speed": 18.0, "range": 30.0, "effective_range": 24.0, "sight": 105.0,
				"health": 1.0, "suppression": 0.0, "taking_fire": false})
		center += at
	center /= float(maxi(count, 1))
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": contacts, "terrain": "open", "threat": threat, "composition": "light",
			"strength": 400.0 * count, "enemy_strength": 400.0, "taking_fire": false, "arrived": false}
