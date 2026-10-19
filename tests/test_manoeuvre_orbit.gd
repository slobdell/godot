extends TestCase
## Round 33 (C33.9, his playtest): a lone law_scout (wheels, a fixed MG, 20 deg arc) is circled by a faster enemy that
## shoots it; the scout "was repeatedly driving forward and backward trying to yaw right" and took hits without a shot.
## The stage: the scout alone on open ground, an enemy driven round it on a circle at range (its own move_to steps,
## re-centred on the scout every few ticks, so it really orbits), firing at will.

const ORBIT_R := 30.0
const LEAD_DEG := 40.0
## C339_DENSE="from-to" (seconds): a per-tick trace window for a diagnosis.
var _dense_from := -1.0
var _dense_to := -1.0


## `halt` (seconds, from-to): the enemy is told `stop` inside that window instead of its orbit steps (a target that
## stands; round 34's M0).
func _orbit_stage(enemy_unit: String, seconds: float, radius := ORBIT_R, player := true, seed_value := 4, on := false,
		subject := "law_scout", trace := true, halt := Vector2(-1.0, -1.0)) -> Dictionary:
	var was_off := Movement._off
	Movement._off = PackedStringArray(["turnin"]) if on != Manoeuvre.TURN_IN_DEFAULT else PackedStringArray([])
	Movement._off_parsed = true
	var ti0 := [Manoeuvre.turn_in_ticks, Manoeuvre.turn_in_stalls]
	var s := AiScenario.create(self, seed_value)
	s.game_match.set_meta("player_team", Match.Team.GREEN if player else Match.Team.RUST)
	# The seed sets the geometry (the hit dice alone barely moved a cell): which way the enemy circles, where it starts,
	# and the scout's heading.
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var way := 1.0 if dice.randi() % 2 == 0 else -1.0
	var phase := dice.randf() * TAU
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), dice.randf() * TAU, {}, subject)
	AiScenario.make_durable(me)
	var start := Vector3(radius * cos(phase), 0, radius * sin(phase))
	var enemy := s.shooter(Match.Team.RUST, "Rust_A_1", start, PI, {"type": "stop"},
			{"type": "fire_at_will", "long_shot": true}, enemy_unit)
	AiScenario.make_durable(enemy)
	var brain := s.brain_of(me)
	var ctl := s.controller_of(enemy)
	await s.start()
	var lay0 := [CombatMotion.lay_plans, CombatMotion.lay_reverse, CombatMotion.lay_holds]
	var mplans0 := Manoeuvre.face_plans
	var seam0 := [PlannerSeam.requests, PlannerSeam.plans, PlannerSeam.driving_ticks, PlannerSeam.pending_ticks]
	var arc0 := OrderController.wheel_arc_stops
	var giveups0 := s.controller_of(me).face_giveups if "face_giveups" in s.controller_of(me) else 0
	var face_paths := {}
	var fnone0 := Manoeuvre.face_none
	var frefused0 := Manoeuvre.face_refused
	var aligned := 0
	var rev_off_arc := 0
	var rev_face := 0
	var rev_face_cmd := 0  # ...of which the hull was TOLD to reverse (throttle < 0); the rest a bounce under a forward command
	var flips_face_cmd := 0  # (d) as filed on main after R33.23: gear changes by the COMMANDED gear while a face holds
	var face_cmd_gear := 0
	var rev_stop := 0  # (d2), filed after R33.23: reverse ticks while the order is `stop` (gunnery's R2 swing)
	var stops0 := Manoeuvre.turn_in_stops
	var holds0 := Manoeuvre.turn_in_holds
	var hold_ticks := 0  # face ticks in the arc with the hull still (round 34: a standing target in the sights)
	var half_arc_me := float(Units.stat(subject, "fire_arc_deg", 0.0)) * 0.5
	var evades0 := Manoeuvre.turn_in_evades
	var bounces := {}  # a reverse tick under a forward command: what the hull was touching (collider names; "none")
	var d_sum := 0.0
	var flips_face := 0
	var face_gear := 0
	var far := 0.0
	var far_face := 0.0  # (e) read apart: the furthest point while a face order holds (the turn-in's) v any order
	var home := Vector3.ZERO
	var health0 := me.health + me.shield
	var enemy0 := enemy.health + enemy.shield  # (c) in reach, the ruling: the EXCHANGE, damage dealt / taken
	home = me.global_position
	var ticks := int(SimClock.TICK_RATE * seconds)
	var reverse_ticks := 0
	var gear_flips := 0
	var last_gear := 0
	var in_arc_ticks := 0
	var whys := {}
	var orders := {}
	var yaw_sum := 0.0
	var bearing_sum := 0.0
	var last_forward := Vector3.ZERO
	var last_bearing := Vector3.ZERO
	var hits := 0
	var last_hp := health0
	var first_shot := -1.0
	var first_hit := -1.0
	var timeline: Array[String] = []
	for tick in ticks:
		var halted := halt.x >= 0.0 and float(tick) / SimClock.TICK_RATE >= halt.x and float(tick) / SimClock.TICK_RATE <= halt.y
		if tick % 5 == 0 and halted:
			ctl.set_orders({"type": "stop"}, ctl.weapon_order)
		elif tick % 5 == 0:
			var centre := me.global_position
			var at := Vector3(enemy.global_position.x - centre.x, 0.0, enemy.global_position.z - centre.z)
			var ahead := at.normalized().rotated(Vector3.UP, deg_to_rad(LEAD_DEG) * way) * radius
			ctl.set_orders({"type": "move_to", "x": centre.x + ahead.x, "z": centre.z + ahead.z}, ctl.weapon_order)
		await s.step()
		var forward := Vector3(-me.global_basis.z.x, 0.0, -me.global_basis.z.z).normalized()
		var to := Vector3(enemy.global_position.x - me.global_position.x, 0.0, enemy.global_position.z - me.global_position.z)
		var bearing := to.normalized()
		var err := rad_to_deg(forward.signed_angle_to(bearing, Vector3.UP))
		d_sum += to.length()
		if absf(err) <= 10.0:
			in_arc_ticks += 1
		var last_yaw := 0.0
		if last_forward != Vector3.ZERO:
			last_yaw = absf(last_forward.signed_angle_to(forward, Vector3.UP))
			yaw_sum += absf(last_forward.signed_angle_to(forward, Vector3.UP))
			bearing_sum += absf(last_bearing.signed_angle_to(bearing, Vector3.UP))
		last_forward = forward
		last_bearing = bearing
		var gear := signi(int(signf(me.speed()))) if absf(me.speed()) > 0.3 else 0
		if gear < 0:
			reverse_ticks += 1
			if trace and String(brain.move_order.get("type", "")) == "face" and brain._last_command != null:
				print("  REV t%.2f spd %.1f thr %.2f turn %.2f live %s rest %d rate %.0f legs %d err %.0f d %.1f ti %d vel %.1f m/s at %.0f deg off the nose" % [float(tick) / SimClock.TICK_RATE,
						me.speed(), brain._last_command.throttle, brain._last_command.turn, brain._turn_in_live, brain._turn_in_rest - Engine.get_physics_frames(),
						brain._turn_in_rate, brain.movement._face_legs.size(), err, me.global_position.distance_to(enemy.global_position), Manoeuvre.turn_in_ticks,
						Vector2(me.velocity.x, me.velocity.z).length(), rad_to_deg(absf(forward.signed_angle_to(Vector3(me.velocity.x, 0.0, me.velocity.z), Vector3.UP)))])
			if absf(err) > 30.0:
				rev_off_arc += 1
		far = maxf(far, Vector2(me.global_position.x - home.x, me.global_position.z - home.z).length())
		if String(brain.move_order.get("type", "")) == "face":
			far_face = maxf(far_face, Vector2(me.global_position.x - home.x, me.global_position.z - home.z).length())
		if gear != 0 and last_gear != 0 and gear != last_gear:
			gear_flips += 1
		if gear != 0:
			last_gear = gear
		var hp := me.health + me.shield
		if hp < last_hp - 0.01:
			hits += 1
			if first_hit < 0.0:
				first_hit = float(tick) / SimClock.TICK_RATE
		last_hp = hp
		if first_shot < 0.0 and s.shots_by(me) > 0:
			first_shot = float(tick) / SimClock.TICK_RATE
		var order: Dictionary = brain.move_order
		if String(order.get("type", "")) == "stop" and gear < 0:
			rev_stop += 1
		if String(order.get("type", "")) == "face":
			# (d), scoped on main 82752ecc: reverse ticks and gear changes while a face order holds.
			if gear < 0:
				rev_face += 1
				if brain._last_command != null and brain._last_command.throttle < 0.0:
					rev_face_cmd += 1
				else:
					var touched := false
					for i in me.get_slide_collision_count():
						var other: Object = me.get_slide_collision(i).get_collider()
						var who := String((other as Node).name) if other is Node else str(other)
						bounces[who] = int(bounces.get(who, 0)) + 1
						touched = true
					if not touched:
						bounces["none"] = int(bounces.get("none", 0)) + 1
			if trace and brain._last_command != null and brain._last_command.throttle < 0.0:
				print("  NEGCMD t%.2f spd %.1f thr %.2f turn %.2f ti %d legs %d left %.1f err %.0f d %.1f" % [float(tick) / SimClock.TICK_RATE, me.speed(),
						brain._last_command.throttle, brain._last_command.turn, Manoeuvre.turn_in_ticks, brain.movement._face_legs.size(),
						brain.movement._face_left_m, err, me.global_position.distance_to(enemy.global_position)])
			if brain._last_command != null and brain._last_command.throttle != 0.0:
				var cmd_gear := 1 if brain._last_command.throttle > 0.0 else -1
				if face_cmd_gear != 0 and cmd_gear != face_cmd_gear:
					flips_face_cmd += 1
				face_cmd_gear = cmd_gear
			if gear != 0 and face_gear != 0 and gear != face_gear:
				flips_face += 1
			if gear != 0:
				face_gear = gear
		else:
			face_gear = 0
		if String(order.get("type", "")) == "face":
			if absf(err) <= half_arc_me and absf(me.speed()) < 0.5:
				hold_ticks += 1
			if absf(err) <= Manoeuvre.FACE_ALIGNED_DEG:
				aligned += 1
			var path := "legs" if not brain.movement._face_legs.is_empty() or brain.movement._face_left_m > 0.0 else "other"
			if PlannerSeam.on() and PlannerSeam._crews.has(String(me.name)):
				path = "seam"
			face_paths[path + ("_rev" if gear < 0 else "_fwd" if gear > 0 else "_still")] = int(face_paths.get(path + ("_rev" if gear < 0 else "_fwd" if gear > 0 else "_still"), 0)) + 1
		var key := String(order.get("type", "")) + ("/rev" if bool(order.get("reverse", false)) else "")
		orders[key] = int(orders.get(key, 0)) + 1
		var opt := String(brain.choice.get("option", "-"))
		whys[opt] = int(whys.get(opt, 0)) + 1
		if trace and _dense_from >= 0.0 and float(tick) / SimClock.TICK_RATE >= _dense_from and float(tick) / SimClock.TICK_RATE <= _dense_to:
			var ev := Vector2(enemy.velocity.x, enemy.velocity.z)
			print("  DENSE t%.2f %s goal=(%.1f,%.1f) enemy=(%.1f,%.1f) ev=%.1f d=%.1f err=%+.0f spd=%.1f thr=%.2f turn=%.2f rate=%.0f live=%s legs=%d left=%.1f holds=%d" % [
					float(tick) / SimClock.TICK_RATE, String(order.get("type", "")), float(order.get("x", 0)), float(order.get("z", 0)),
					enemy.global_position.x, enemy.global_position.z, ev.length(), to.length(), err, me.speed(),
					brain._last_command.throttle if brain._last_command != null else -9.0, brain._last_command.turn if brain._last_command != null else -9.0,
					brain._turn_in_rate, brain._turn_in_live, brain.movement._face_legs.size(), brain.movement._face_left_m, Manoeuvre.turn_in_holds])
		if trace and tick % 15 == 0:
			timeline.append("t%.1f %s why=%s err=%+.0f spd=%+.1f d=%.0f at=(%.0f,%.0f) goal=(%.0f,%.0f) ti_rate=%.0f live=%s yawnow=%.0f post=%s leashed=%d thr=%.2f turn=%.2f" % [float(tick) / SimClock.TICK_RATE, key,
					String(brain.choice.get("option", "-")) + ":" + brain.why, err, me.speed(), to.length(), me.global_position.x, me.global_position.z, float(order.get("x", 0)), float(order.get("z", 0)), brain._turn_in_rate, brain._turn_in_live, rad_to_deg(last_yaw) * SimClock.TICK_RATE, str(brain.get("_player_post")), Manoeuvre.turn_in_leashed, brain._last_command.throttle if brain._last_command != null else -9.0, brain._last_command.turn if brain._last_command != null else -9.0])
	var secs := float(ticks) / SimClock.TICK_RATE
	var out := {"enemy": enemy_unit, "first_shot_s": first_shot, "first_hit_s": first_hit, "shots": s.shots_by(me),
			"enemy_shots": s.shots_by(enemy), "hits_taken": hits, "damage": health0 - (me.health + me.shield), "damage_dealt": enemy0 - (enemy.health + enemy.shield),
			"yaw_deg_s": rad_to_deg(yaw_sum) / secs, "orbit_deg_s": rad_to_deg(bearing_sum) / secs,
			"in_arc_pct": 100.0 * in_arc_ticks / ticks, "reverse_pct": 100.0 * reverse_ticks / ticks, "gear_flips": gear_flips,
			"orders": orders, "whys": whys, "radius": radius, "player": player, "way": way, "subject": subject, "seed": seed_value, "rev_off_arc": rev_off_arc, "rev_face": rev_face, "rev_stop": rev_stop, "evades": Manoeuvre.turn_in_evades - evades0, "reach_m": Engagement.effective_range(me.weapon), "stop_turn_ins": Manoeuvre.turn_in_stops - stops0, "holds": Manoeuvre.turn_in_holds - holds0, "hold_ticks": hold_ticks, "halt": [halt.x, halt.y], "rev_face_cmd": rev_face_cmd, "flips_face_cmd": flips_face_cmd, "bounces": bounces, "mean_d": d_sum / ticks, "flips_face": flips_face, "far_m": far, "far_face_m": far_face, "on": on, "turn_in": [Manoeuvre.turn_in_ticks - ti0[0], Manoeuvre.turn_in_stalls - ti0[1]],
			"lay": [CombatMotion.lay_plans - lay0[0], CombatMotion.lay_reverse - lay0[1], CombatMotion.lay_holds - lay0[2]],
			"face_plans": Manoeuvre.face_plans - mplans0, "face_paths": face_paths, "face_none": Manoeuvre.face_none - fnone0, "face_refused": Manoeuvre.face_refused - frefused0, "aligned_ticks": aligned, "aligned_deg": Manoeuvre.FACE_ALIGNED_DEG, "seam_on": PlannerSeam.on(),
			"seam": [PlannerSeam.requests - seam0[0], PlannerSeam.plans - seam0[1], PlannerSeam.driving_ticks - seam0[2], PlannerSeam.pending_ticks - seam0[3]],
			"arc_stops": OrderController.wheel_arc_stops - arc0, "wheelhold_on": OrderController.wheel_hold_on(), "kturn": Manoeuvre.report()}
	for line in timeline:
		print("  TL %s r%.0f p%s on%s " % [enemy_unit, radius, player, on], line)
	s.dispose()
	Movement._off = was_off
	return out


## The bar's cells (C33.9, filed on main a1b6d388), run only when C339_CELLS names the seeds ("11-16"): too long for a
## suite (288 runs of 30 s). `C339_CELLS=11-16 godot --headless --script res://tests/run_tests.gd -- --filter=c339_cells`
func test_c339_cells() -> void:
	var spec := OS.get_environment("C339_CELLS")
	# One traced cell for a diagnosis: C339_ONE="subject,enemy,radius,seed[,on]" (on defaults to 1; the OFF row too when 2).
	var one := OS.get_environment("C339_ONE")
	if one != "":
		var f := one.split(",")
		var dense := OS.get_environment("C339_DENSE")
		if dense != "":
			_dense_from = float(dense.split("-")[0])
			_dense_to = float(dense.split("-")[-1])
		var was_native := BrainSwitches.native
		BrainSwitches.native = false
		var arms: Array = [true] if f.size() < 5 or f[4] == "1" else ([false] if f[4] == "0" else [false, true])
		var halt := Vector2(-1.0, -1.0)  # a 6th field "a-b" halts the enemy between those seconds
		if f.size() >= 6 and f[5] != "":
			halt = Vector2(float(f[5].split("-")[0]), float(f[5].split("-")[-1]))
		for on: bool in arms:
			var r := await _orbit_stage(f[1], 30.0, float(f[2]), true, int(f[3]), on, f[0], true, halt)
			r.erase("kturn")
			print("C339_ONE_ROW ", JSON.stringify(r))
		BrainSwitches.native = was_native
		assert_true(true, "one cell traced")
		return
	if spec == "":
		assert_true(true, "cells run on request only")
		return
	var ends := spec.split("-")
	# Both arms on the GDScript path (an ON arm's --nav-off already drops it there; the OFF arm would run native on a
	# machine with the library and not on one without).
	var was_native := BrainSwitches.native
	BrainSwitches.native = false
	# C339_SET=report (round 34, the orchestrator's ask from brains' B1 verdict): the REPORTED cell beside the bar's,
	# gang_scout v syn_lancer 15 m at a post (their worst duel cell: a held fixed gun k-turning, 0 shots), both arms. Its
	# rows are kept apart from the bar's cells (the table pools by cell, so they never enter a judged line).
	var report := OS.get_environment("C339_SET") == "report"
	var subjects: Array = ["gang_scout"] if report else ["law_scout", "gang_scout"]
	var enemies: Array = ["syn_lancer"] if report else ["syn_scout", "gang_ifv"]
	var radii: Array = [15.0] if report else [15.0, 30.0, 45.0]
	var posts: Array = [true] if report else [true, false]
	for seed_value in range(int(ends[0]), int(ends[-1]) + 1):
		for subject: String in subjects:
			for enemy_unit: String in enemies:
				for radius: float in radii:
					for player: bool in posts:
						for on: bool in [false, true]:
							var r := await _orbit_stage(enemy_unit, 30.0, radius, player, seed_value, on, subject, false)
							r.erase("kturn")
							print("C339_CELL ", JSON.stringify(r))
	BrainSwitches.native = was_native
	assert_true(true, "cells printed")


func test_a_scout_circled_by_a_faster_enemy() -> void:
	for cell: Array in [["gang_ifv", 15.0, 19]]:
		print("CELL ", cell)
		var r := await _orbit_stage(cell[0], 30.0, cell[1], true, cell[2], true, "gang_scout")
		print("MEASURE c339_orbit ", JSON.stringify(r))
	assert_true(true, "diagnosis only")


## (f), the orchestrator's line: the turn-in's jink dwells come from the match tick and the hull's name, never a global
## or time-seeded RNG, so the same seed plays out the same (replays, sim-baseline, the network). The same ON cell in two
## fresh --fixed-fps children (FreshStage's child: nothing left by an earlier match, and no box load pacing the sim).
func test_the_turn_in_plays_out_the_same_twice() -> void:
	var rows: Array = []
	for run in 2:
		var out: Array = []
		var code := OS.execute("timeout", [FreshStage.CHILD_TIMEOUT_S, OS.get_executable_path(), "--headless", "--fixed-fps",
				str(SimClock.TICK_RATE), "--path", ProjectSettings.globalize_path("res://"), "--script", FreshStage.CHILD, "--",
				"--case=%s" % String(get_script().resource_path), "--stage=_turn_in_once"], out, true)
		for line in "\n".join(PackedStringArray(out.map(func(l: Variant) -> String: return str(l)))).split("\n"):
			if line.begins_with("C339_ONCE "):
				rows.append(JSON.parse_string(line.trim_prefix("C339_ONCE ")))
			elif line.begins_with(FreshStage.MARK):
				for failure: String in (JSON.parse_string(line.trim_prefix(FreshStage.MARK)) as Dictionary).get("failures", []):
					failures.append("(fresh run %d) %s" % [run, failure])
		assert_eq(code, 0, "fresh run %d exited 0" % run)
	assert_eq(rows.size(), 2, "both fresh runs printed their row")
	if rows.size() == 2:
		assert_true(int(rows[0]["turn_in"][0]) > 0, "setup: the turn-in drove")
		for k: String in rows[0]:
			if JSON.stringify(rows[0][k]) != JSON.stringify(rows[1].get(k)):
				print("C339_DIFF ", k, " ", JSON.stringify(rows[0][k]), " v ", JSON.stringify(rows[1].get(k)))
		assert_eq(JSON.stringify(rows[1]), JSON.stringify(rows[0]), "the same seed, ON, gives identical rows")


## One ON cell, for the fresh child above.
func _turn_in_once() -> void:
	var r := await _orbit_stage("gang_ifv", 15.0, 30.0, true, 21, true, "law_scout", false)
	r.erase("kturn")  # Manoeuvre.report(): process-wide counters
	print("C339_ONCE ", JSON.stringify(r))


## Round 34 (M0, seed 36 of round 33's judged cells): an orbiter that STOPS (the stage's own: the scout had driven onto
## its nose) is a target that stands. ON, the scout holds still in its arc and shoots it (hold_ticks), and never reverses:
## before the fix the jink rolled it past the stopped enemy, the arc was lost, and after 3 s the face planner's first leg
## reversed (13 reverse ticks, 2 commanded gear changes).
func test_a_scout_holds_still_when_its_orbiter_stops_in_its_arc() -> void:
	var on := await _orbit_stage("syn_scout", 12.0, 15.0, true, 14, true, "gang_scout", false, Vector2(2.0, 12.0))
	print("MEASURE c339_halt ", JSON.stringify(on))
	assert_true(int(on["turn_in"][0]) > 0, "setup: the turn-in drove")
	assert_eq(int(on["rev_face_cmd"]), 0, "ON: no reverse commanded while the enemy stands")
	assert_eq(int(on["flips_face_cmd"]), 0, "ON: no commanded gear change while the enemy stands")
	assert_true(int(on["hold_ticks"]) >= SimClock.TICK_RATE * 3, "ON: held still in the arc on the standing target for >= 3 s (%d ticks)" % on["hold_ticks"])


## Round 34 (M0): a brain's threat face at a PARKED enemy (the common case: a scout spots a standing tank off its nose).
## ON, a fixed gun on wheels comes round rolling forward and then holds, never a planned reverse leg while the enemy is
## live; it stays near its post.
func test_a_threat_face_at_a_parked_enemy_comes_round_forward_and_holds() -> void:
	var on := await _orbit_stage("syn_scout", 10.0, 20.0, true, 36, true, "law_scout", false, Vector2(0.0, 10.0))
	print("MEASURE c339_parked ", JSON.stringify(on))
	assert_true(int(on["turn_in"][0]) > 0, "setup: the turn-in drove")
	assert_eq(int(on["rev_face_cmd"]), 0, "ON: no reverse commanded at a parked enemy")
	assert_true(int(on["hold_ticks"]) >= SimClock.TICK_RATE * 3, "ON: came round and held still in the arc for >= 3 s (%d ticks)" % on["hold_ticks"])
	assert_true(float(on["far_m"]) <= 20.0, "ON: within 20 m of its post (%.1f m)" % on["far_m"])


## (d2), filed on main after R33.23 ("it's literally what the lead saw"): between SPOTs the brain HOLDs, and at `stop`
## gunnery's R2 swing turned the fixed gun with no throttle, which the plant drove as the creep's forward/back legs. ON,
## a gang scout circled at 15 m never reverses at `stop` (OFF does).
func test_a_scout_at_stop_does_not_shuffle_under_turn_in() -> void:
	var off := await _orbit_stage("syn_scout", 30.0, 15.0, true, 14, false, "gang_scout", false)
	var on := await _orbit_stage("syn_scout", 30.0, 15.0, true, 14, true, "gang_scout", false)
	print("MEASURE c339_stop off %d on %d (stop swings turned in %d)" % [off["rev_stop"], on["rev_stop"], on["stop_turn_ins"]])
	assert_true(int(off["rev_stop"]) > 0, "setup: OFF shuffles at stop (%d reverse ticks)" % off["rev_stop"])
	assert_eq(int(on["rev_stop"]), 0, "ON: no reverse tick at stop")
	# The swings that went through the turn-in are REPORTED (MEASURE above): round 34's turn-in holds the hull in its arc
	# so well that at HOLD gunnery has nothing to swing (laptop: 3 -> 0 swings), which is the point.


## (e2), the orchestrator's line: a STATIC face (a drawn facing, nothing moving) is no worse under turn-in: aligned no
## later than OFF and no further from its spot than OFF + 2 m. A plain K1 move a few metres on, with a facing `turn`
## degrees off the hull's heading, for each fixed gun on wheels.
func _static_face(subject: String, turn: float, on: bool) -> Dictionary:
	var was_off := Movement._off
	Movement._off = PackedStringArray(["turnin"]) if on != Manoeuvre.TURN_IN_DEFAULT else PackedStringArray([])
	Movement._off_parsed = true
	var s := AiScenario.create(self, 4)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0, {}, subject)
	await s.start()
	var goal := Vector3(0, 0, -4)
	var want := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(turn))
	assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "move", "to": [goal.x, goal.z], "facing": [want.x, want.z],
			"source": "player"}), "", "setup: the move is accepted")
	var half_arc := float(Units.stat(subject, "fire_arc_deg", 0.0)) * 0.5
	var aligned_s := -1.0
	var far := 0.0
	var ticks_in := Manoeuvre.turn_in_ticks
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		far = maxf(far, Vector2(me.global_position.x - goal.x, me.global_position.z - goal.z).length())
		var forward := Vector3(-me.global_basis.z.x, 0.0, -me.global_basis.z.z).normalized()
		if aligned_s < 0.0 and rad_to_deg(forward.angle_to(want)) <= half_arc:
			aligned_s = float(tick) / SimClock.TICK_RATE
	var out := {"subject": subject, "turn": turn, "on": on, "aligned_s": aligned_s, "far_m": far,
			"turn_in_ticks": Manoeuvre.turn_in_ticks - ticks_in}
	s.dispose()
	Movement._off = was_off
	return out


func test_a_static_drawn_face_is_no_worse_under_turn_in() -> void:
	for subject: String in ["law_scout", "gang_scout"]:
		for turn: float in [90.0, 150.0, -120.0]:
			var off := await _static_face(subject, turn, false)
			var on := await _static_face(subject, turn, true)
			print("MEASURE c339_static ", JSON.stringify({"off": off, "on": on}))
			assert_eq(on["turn_in_ticks"], 0, "%s %.0f: a static spot never starts a turn-in" % [subject, turn])
			if off["aligned_s"] >= 0.0:
				assert_true(on["aligned_s"] >= 0.0 and on["aligned_s"] <= off["aligned_s"] + 0.05,
						"%s %.0f: aligned no later (%.2f v %.2f s)" % [subject, turn, on["aligned_s"], off["aligned_s"]])
			assert_true(on["far_m"] <= off["far_m"] + 2.0, "%s %.0f: no further (%.1f v %.1f m)" % [subject, turn, on["far_m"], off["far_m"]])
