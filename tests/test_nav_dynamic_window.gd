extends TestCase
## Round 9 (nav, A11 — Fox, Burgard & Thrun 1997, *The Dynamic Window Approach*): score a fixed lattice of
## (speed, yaw-rate) pairs the plant can ACTUALLY REACH this tick, as constant-curvature arcs, instead of a ring of
## 16 directions some of which the hull cannot take. **The ring is why a heavy hull picks a heading and then hunts
## toward it** — it scores a direction, the plant cannot deliver it, and the next plan picks a different one.
##
## The claim these tests hold A11 to is narrow and checkable: **every candidate it offers is one `TankMotion` can
## execute.** That is the whole difference from the ring, and it is verified against the plant itself rather than
## against a restatement of the plant's rules — the two drifting apart is how the chord test got it wrong for wheels.

const HORIZON := CombatMotion.DWA_HORIZON


static func _state(unit_id: String, speed: float, yaw_rate := 0.0) -> Dictionary:
	var state := TankMotion.state_for(unit_id, Vector3.ZERO, Vector3.FORWARD, speed)
	state["velocity"] = Vector3.FORWARD * speed
	state["yaw_rate"] = yaw_rate
	return state


func test_every_offered_arc_is_one_the_plant_can_actually_drive() -> void:
	# The window is over the CONTROL PERIOD (how long a command is actually held before the next plan), not over one
	# tick, so this drives the plant for that long and checks the cell promised what the plant delivered: the pose it
	# reaches, the speed it ends at, and the yaw rate it is turning at when it gets there.
	var ticks := maxi(1, int(CombatMotion.DWA_CONTROL_SECONDS * SimClock.TICK_RATE))
	for unit_id: String in ["tank", "ifv", "scout"]:
		var state := _state(unit_id, 4.0)
		var lattice := CombatMotion.dynamic_window(state)
		assert_true(not lattice.is_empty(), "%s gets a lattice (%d)" % [unit_id, lattice.size()])
		for cell: Dictionary in lattice:
			var driven: Dictionary = state.duplicate()
			for _t in ticks:
				TankMotion.step_in_place(driven, float(cell["throttle"]), float(cell["turn"]), SimClock.TICK_SECONDS)
			assert_near(float(driven["speed"]), float(cell["speed"]), 0.0001,
					"%s: the plant reached the speed the cell promised (cell %s)" % [unit_id, cell])
			assert_near((driven["position"] as Vector3).distance_to(cell["position"] as Vector3), 0.0, 0.0001,
					"%s: and the pose (cell %s)" % [unit_id, cell])
			assert_near((driven["forward"] as Vector3).dot(cell["forward"] as Vector3), 1.0, 0.0001,
					"%s: and the heading (cell %s)" % [unit_id, cell])


func test_a_car_is_never_offered_a_turn_it_cannot_roll_into() -> void:
	# The ring offers a stopped car all 16 directions and the plant answers with a creep K-turn. A car's yaw is
	# `|speed| * turn / radius`, so turning REQUIRES rolling — and over a control period a stopped car may legitimately
	# roll first and then turn, which is why the claim is not "no turning arcs" but "no turning without travelling".
	# The lattice cannot offer a pivot in place to something that has no way of performing one.
	for start_speed: float in [0.0, 6.0]:
		var state := _state("ifv", start_speed)
		for cell: Dictionary in CombatMotion.dynamic_window(state):
			var swung := absf(float(cell["mean_yaw"]))
			if swung <= 0.01:
				continue
			var moved := (cell["position"] as Vector3).distance_to(state["position"] as Vector3)
			assert_true(moved > 0.05,
					"a car that turned %.2f rad/s travelled to do it (%.3f m, from %.1f m/s)" % [swung, moved, start_speed])


func test_a_tracked_hull_reaches_its_full_turn_rate_within_the_control_period() -> void:
	# Round 8 gave tracks an angular-acceleration ramp, and YAW_RAMP_SECONDS is 0.25 — exactly the control period.
	# So a hull starting from rest CAN be offered its full rate by the end of the period, and must be: a one-tick
	# window offered it 21 degrees of heading change over a 2 s arc, every candidate pointed nearly the same way,
	# level 3 had nothing to choose between, and the duel scenario's tank died in 6.3 s of a 20 s fight.
	var state := _state("tank", 3.0, 0.0)
	var max_rate := deg_to_rad(float(state["hull_turn_rate_deg"]))
	var widest := 0.0
	for cell: Dictionary in CombatMotion.dynamic_window(state):
		widest = maxf(widest, absf(float(cell["yaw_rate"])))
	# Within a tenth: the period is a whole number of ticks (7 at 30 Hz = 0.233 s), so the ramp gets 93% of the way
	# rather than exactly all of it. The point of the assertion is "most of its rate", not a fencepost.
	assert_near(widest, max_rate, max_rate * 0.1,
			"a hull given the whole control period reaches its rate (%.3f of %.3f rad/s)" % [widest, max_rate])


func test_the_lattice_is_a_fixed_size_and_the_same_every_time() -> void:
	var a := CombatMotion.dynamic_window(_state("tank", 5.0, 0.2))
	var b := CombatMotion.dynamic_window(_state("tank", 5.0, 0.2))
	assert_eq(a.size(), b.size(), "same size")
	assert_true(a.size() <= CombatMotion.DWA_SPEEDS * CombatMotion.DWA_YAWS,
			"never more than the fixed grid (%d)" % a.size())
	for i in a.size():
		assert_near(float((a[i] as Dictionary)["yaw_rate"]), float((b[i] as Dictionary)["yaw_rate"]), 0.0000001,
				"cell %d identical, row-major and deterministic" % i)


## The arm, provable from outside (lesson 147, and round 8's `gates aimed 0` in both arms). A11 only means anything
## inside A7's chooser, so both switches are pinned here rather than inherited.
func test_the_lattice_replaces_the_ring_and_says_so() -> void:
	var request := {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 10.0, "reverse_speed": 5.0,
			"style": "strafe", "target": {"position": Vector3(0, 0, -30), "forward": Vector3.BACK, "velocity": Vector3.ZERO},
			"band": [15.0, 40.0], "side": 1.0, "wheels": false, "turn_rate_deg": 90.0, "acceleration": 8.0,
			"velocity": Vector3.FORWARD * 6.0, "limit": 200.0,
			"motion": _state("tank", 6.0, 0.1)}
	var was := Movement._off
	Movement._off = PackedStringArray(["a7"])
	Movement._off_parsed = true
	CombatMotion.reset_arms()
	var ring := CombatMotion.choose(request)
	var ring_arms := CombatMotion.arm_report()
	Movement._off = PackedStringArray(["a7", "a11"])
	CombatMotion.reset_arms()
	var lattice := CombatMotion.choose(request)
	var lattice_arms := CombatMotion.arm_report()
	Movement._off = was
	assert_eq(int(ring_arms["a11_lattices"]), 0, "the ring arm builds no lattice (%s)" % ring_arms)
	assert_true(int(lattice_arms["a11_lattices"]) > 0, "the lattice arm builds one (%s)" % lattice_arms)
	assert_true(int(lattice_arms["dwa_candidates_reachable"]) > 16,
			"and it offers more than a ring's worth of reachable arcs (%s)" % lattice_arms)
	assert_eq(int(lattice_arms["a11_with_live_state"]), 1,
			"built from the hull's LIVE motion state, not a synthesised one (%s)" % lattice_arms)
	assert_true(not ring.is_empty() and not lattice.is_empty(), "both arms chose something")


## The arm HEADER must say what the code is doing, not what the flag said. The first version of `nav-fight`'s
## NAV_FIGHT_ARM line read `not Movement.switched_off("a7")`, which was right while A7 was on by default and became a
## confident lie the moment the switch was inverted: it printed `a7=false` on a run with `--nav-off=a7` set. An arm
## header that reports the opposite treatment is how round 7 compared two byte-identical arms and believed the result.
func test_the_switches_report_the_treatment_the_code_is_actually_running() -> void:
	var was := Movement._off
	Movement._off = PackedStringArray()
	Movement._off_parsed = true
	assert_true(not CombatMotion.a7_on(), "no flag: the blend")
	assert_true(not CombatMotion.a11_on(), "no flag: the ring")
	Movement._off = PackedStringArray(["a7"])
	assert_true(CombatMotion.a7_on(), "--nav-off=a7 turns A7 ON")
	assert_true(not CombatMotion.a11_on(), "and leaves A11 alone")
	Movement._off = PackedStringArray(["a7", "a11"])
	assert_true(CombatMotion.a7_on() and CombatMotion.a11_on(), "both on")
	Movement._off = was


## ---- A11's duel: THE INSTRUMENT, not a verdict -------------------------------------------------------------------
##
## Round 9 left A11 opt-in with one open behaviour question, and it was open because the harness could not answer it.
## `scenario_motion::test_two_tanks_duel_on_the_move_front_armor_first` fails A11 on `shots >= 6` — but only because
## the duel ENDS at 6.3 s of 20 when A11 is on. That assertion measures how long the fight lasted, not how well it
## was fought, so "A11's hulls kill each other three times faster" can be lethality or blundering and the bar cannot
## tell them apart. A zero-length fight would fail it just as a perfect one would.
##
## So this measures the EXCHANGE and lets the duration fall out as a consequence:
##   shots/s, damage/s   tempo -- how fast the trade happens
##   damage per shot     QUALITY of each trade: side and rear hits hurt more than front ones
##   front hit share     WHERE the trade lands, which is the same quantity round 3 shipped x3 to protect
## Read together: **more damage per second with the front share HELD is lethality; more damage per shot with the
## front share FALLING is two hulls presenting their flanks to each other faster.** Those are different outcomes and
## the shot count cannot separate them.
##
## `tests/ai_scenarios/` is SQUAD's, so nav builds the instrument in nav's file, publishes the numbers, and hands
## squad the assertion rather than editing their scenario.
func test_a11s_duel_measures_the_exchange_and_not_the_survival_time() -> void:
	# POOLED over seeds. One duel gave a front share of 2 hits in 3 -- a denominator far too small to say anything
	# about where the trade lands, which is the defect this round has been finding in everyone else's numbers.
	var control := await _pooled(false)
	var treated := await _pooled(true)
	for entry: Array in [["A7 alone (control)", control], ["A7+A11", treated]]:
		var r: Dictionary = entry[1]
		print(("MEASURE a11_exchange %s over %d duels: %.1f s mean, shots/s %.2f, damage/s %.1f, "
				+ "damage per shot %.1f, front hits %.0f%% (%d of %d)") % [entry[0], r["duels"], r["seconds"],
				r["shots_per_s"], r["damage_per_s"], r["damage_per_shot"], float(r["front_share"]) * 100.0,
				r["front"], r["hits"]])
	# THE VERDICT THIS INSTRUMENT CAN AND CANNOT GIVE, printed beside the numbers so neither travels without it.
	# The TEMPO change is solid: it rests on every shot and every point of damage in ten duels. The FRONT SHARE is
	# the half that would decide lethality against blundering, and at 25 and 15 hits it cannot -- Fisher two-tailed
	# on 21/25 against 10/15 is p = 0.26. So A11 demonstrably doubles the rate of the exchange, and where the trade
	# LANDS needs more duels than a 6.3 s fight produces. That is a better answer than the shot-count bar gave,
	# because it names the number that is missing instead of failing on the one that was never the question.
	print(("MEASURE a11_exchange VERDICT: tempo %.1fx shots/s and %.1fx damage/s (solid); front share %.0f%% -> "
			+ "%.0f%% points to blundering but p=0.26 on %d and %d hits, so it does NOT settle it") % [
			float(treated["shots_per_s"]) / maxf(float(control["shots_per_s"]), 0.0001),
			float(treated["damage_per_s"]) / maxf(float(control["damage_per_s"]), 0.0001),
			float(control["front_share"]) * 100.0, float(treated["front_share"]) * 100.0,
			control["hits"], treated["hits"]])
	# The instrument must be an instrument before it is evidence: a duel that never fought measures nothing, and
	# that is the failure this whole test exists to stop being mistaken for a result (round 8's `gates aimed 0`).
	for entry: Array in [["control (A7)", control], ["A7+A11", treated]]:
		assert_true(float(entry[1]["seconds"]) > 1.0 and int(entry[1]["hits"]) > 0,
				"POSITIVE CONTROL: the %s duel actually happened (%.1f s, %d hits)" % [
				entry[0], float(entry[1]["seconds"]), int(entry[1]["hits"])])
	# No bar on the comparison yet, deliberately. The numbers go to squad, who own the scenario and its thresholds;
	# nav asserting one here would be nav choosing A11's acceptance bar after seeing A11's numbers.
	assert_true(float(treated["damage_per_shot"]) > 0.0, "and A11's arm produced a damage-per-shot to compare")


## SEEDS pooled: rates are averaged over duels, but the front share is pooled over HITS, because a share needs its
## own denominator and averaging five small shares is not the same number.
const EXCHANGE_SEEDS := [1, 2, 3, 4, 5]


func _pooled(a11: bool) -> Dictionary:
	var out := {"duels": 0, "seconds": 0.0, "shots_per_s": 0.0, "damage_per_s": 0.0, "shots": 0,
			"damage": 0.0, "front": 0, "hits": 0}
	for seed_value: int in EXCHANGE_SEEDS:
		var r := await _exchange(a11, seed_value)
		out["duels"] = int(out["duels"]) + 1
		out["seconds"] = float(out["seconds"]) + float(r["seconds"])
		out["shots"] = int(out["shots"]) + int(r["shots"])
		out["damage"] = float(out["damage"]) + float(r["damage"])
		out["front"] = int(out["front"]) + int(r["front"])
		out["hits"] = int(out["hits"]) + int(r["hits"])
	var duels := maxf(float(out["duels"]), 1.0)
	var total_seconds := maxf(float(out["seconds"]), 0.001)
	out["shots_per_s"] = float(out["shots"]) / total_seconds
	out["damage_per_s"] = float(out["damage"]) / total_seconds
	out["damage_per_shot"] = float(out["damage"]) / maxf(float(out["shots"]), 1.0)
	out["front_share"] = float(out["front"]) / maxf(float(out["hits"]), 1.0)
	out["seconds"] = float(out["seconds"]) / duels
	return out


## One symmetric duel with A11 off or ON, reported as rates and per-shot quality rather than as totals.
func _exchange(a11: bool, seed_value := 1) -> Dictionary:
	var was := Movement._off
	# A7 is ON IN BOTH ARMS. Every `a11_on()` in `combat_motion.gd` sits inside `choose_projected`, which only runs
	# when `a7_on()` is true, so **A11 alone is inert by construction** and `--nav-off=a11` against the default is
	# one treatment in two arms. nav ran exactly that against the duel scenario first and got byte-identical
	# results -- round 7's failure, reproduced with the switch working perfectly. The only difference between these
	# arms is A11.
	Movement._off = PackedStringArray(["a7", "a11"]) if a11 else PackedStringArray(["a7"])
	Movement._off_parsed = true
	# The x3 brain, because that is the arm whose bar A11 fails. nav's first cut of this left the variant at the
	# default and the duel ran the full 20 s in BOTH arms -- a perfectly good measurement of a fight that is not the
	# one in question. Measuring something adjacent to the failure and reporting it as the failure is how a wrong
	# number gets a provenance line and survives.
	BrainVariants.use(Match.Team.GREEN, "x3")
	BrainVariants.use(Match.Team.RUST, "x3")
	var s := AiScenario.create(self, seed_value)
	var green := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 25), 0.0)
	var rust := s.brain_tank(Match.Team.RUST, "Rust_A_1", Vector3(-96, 0, -20), PI)
	var counted := 0
	await s.start()
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		if not green.is_alive() or not rust.is_alive():
			break
		counted += 1
	var seconds := maxf(counted / float(SimClock.TICK_RATE), 0.001)
	var stats: Dictionary = s.game_match.stats
	var faces: Dictionary = stats["hits_by_face"]
	var hits := int(faces["front"]) + int(faces["side"]) + int(faces["rear"])
	var shots := s.shots_by(green) + s.shots_by(rust)
	var damage := float(stats["damage"][0]) + float(stats["damage"][1])
	var result := {"seconds": seconds, "shots": shots, "hits": hits, "front": int(faces["front"]), "damage": damage,
			"shots_per_s": shots / seconds, "damage_per_s": damage / seconds,
			"damage_per_shot": damage / maxf(shots, 1.0),
			"front_share": float(faces["front"]) / maxf(hits, 1)}
	s.dispose()
	BrainVariants.reset()
	Movement._off = was
	return result


## A11 IS INERT WITHOUT A7, and this says so in a test because a comment did not stop nav measuring it anyway.
## Every `a11_on()` in `combat_motion.gd` is inside `choose_projected`, which `choose()` calls only when `a7_on()`.
## So `--nav-off=a11` against the default runs ONE treatment in TWO arms: the switch works, the flag is read, the
## arm line prints `a11=true`, and nothing downstream can differ. nav ran that against the duel scenario and got
## byte-identical results in both arms -- round 7's failure with every part working as written.
##
## If A11 is ever lifted out of the A7 path this test goes red, which is the right time to revisit the arms.
func test_a11_alone_is_inert_because_it_lives_inside_a7s_path() -> void:
	var was := Movement._off
	Movement._off = PackedStringArray(["a11"])
	Movement._off_parsed = true
	var a11_without_a7 := CombatMotion.a11_on() and not CombatMotion.a7_on()
	Movement._off = was
	Movement._off_parsed = true
	assert_true(a11_without_a7,
			"the switch itself works: a11 reads ON and a7 reads off, which is exactly the arm that measures nothing")
	# The structural claim, checked against the source rather than restated: no `a11_on()` outside `choose_projected`.
	var src := FileAccess.get_file_as_string("res://game/ai/combat_motion.gd")
	assert_true(not src.is_empty(), "read combat_motion.gd")
	var projected := src.find("static func choose_projected")
	var after := src.find("\nstatic func ", projected + 1)
	assert_true(projected > 0 and after > projected, "found choose_projected's extent")
	# Drop the DECLARATION before scanning for calls: `static func a11_on() -> bool:` contains the very string this
	# searches for, and nav's first cut of this test failed on its own accessor.
	var outside := (src.substr(0, projected) + src.substr(after)).replace("static func a11_on()", "")
	assert_true(not outside.contains("a11_on()"),
			"every a11_on() is inside choose_projected, so A11 cannot act with A7 off - if this fails, A11 has "
			+ "escaped A7's path and `--nav-off=a11` is a real arm again")
