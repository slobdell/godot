extends TestCase
## Round 30, manoeuvre M4b (C30.6): **the readers that judge progress see the motion a hull really made; the plant
## keeps its own reading.**
##
## Traced in round 29 (terminus rigs seed 9, GDScript path, DRIVE_TRACE): a gang truck pressing a squadmate moved
## 0.0000 m a tick while `move_and_slide` handed its velocity back unchanged (floating mode, the slide fully blocked by
## another body), so `estimated_velocity` and the wheels' `_speed` stayed at 12 m/s, and `Movement.unstick`
## (estimated_velocity < STUCK_SPEED) never fired: the hull pressed for seconds to minutes. Round 29's fix (A) made
## `estimated_velocity` honest for everyone and freed the pinned hulls, but a rig BRUSHING a wall lost its `_speed` on
## every touch and ground along the wall instead of sliding off (Terminus rigs 81 -> 64 of 96 arrived).
##
## M4b: `Tank.real_velocity` = this tick's real flat displacement over dt, capped at the velocity asked (a depenetration
## shove is not motion), `--tank-off=real_velocity` makes it equal `estimated_velocity`. `estimated_velocity` and
## `_speed` are untouched (design B). `Movement.unstick` reads it; and because the plant still carries its phantom
## momentum, the stall escape holds reverse until the hull has REALLY backed off, with its cap sized to the momentum it
## must shed first (`--nav-off=unstickback` = round 29's 0.9 s escape).


## B, `behind` metres south of A and facing it, drives at full throttle for `seconds` (A holds still), the plant alone:
## no controller writes either command. B's real displacement over the last second, and its readings at the end.
func _press(unit_id: String, behind: float, seconds: float, real_on: bool, native_plant := false) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_real := Tank.real_velocity_on
	Tank.real_velocity_on = real_on
	BrainSwitches.native = native_plant and NativeBridge.available
	var lab := TacticsLab.create(self, 31)
	var a := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 20), 0.0, unit_id)
	var b := lab.gun(Match.Team.GREEN, "Green_A_2", Vector3(TacticsScenarios.LANE_X, 0, 20 + behind), 0.0, unit_id)
	await lab.start()
	_controller_of(lab, a).set_physics_process(false)
	_controller_of(lab, b).set_physics_process(false)
	var mark := Vector3.ZERO
	var ticks := int(SimClock.TICK_RATE * seconds)
	for tick in ticks:
		b.command = TankCommand.new(1.0, 0.0, b.global_position + Vector3(0, 0, -20))
		a.command = TankCommand.new(0.0, 0.0, a.global_position + Vector3(0, 0, -20))
		await lab.step()
		if tick == ticks - SimClock.TICK_RATE:
			mark = b.global_position
	var real := Vector2(b.global_position.x - mark.x, b.global_position.z - mark.z).length()
	var out := {"real": real, "speed": b.speed(), "estimated": Vector2(b.estimated_velocity.x, b.estimated_velocity.z).length(),
			"reader": Vector2(b.real_velocity.x, b.real_velocity.z).length(),
			"gap": Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z).length()}
	lab.dispose()
	BrainSwitches.native = was_native
	Tank.real_velocity_on = was_real
	return out


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


func test_a_pinned_truck_reads_zero_by_the_readers_and_twelve_by_the_plant() -> void:
	var now := await _press("gang_tank", 12.0, 4.0, true)
	var base := await _press("gang_tank", 12.0, 4.0, false)
	print("MEASURE m4b_wedge gang_tank pinned on a parked squadmate: real %.2f m/s, reader %.2f, plant speed %.2f, estimated %.2f (base: real %.2f, reader %.2f, speed %.2f)" % [
			now["real"], now["reader"], now["speed"], now["estimated"], base["real"], base["reader"], base["speed"]])
	assert_true(base["real"] < 1.0 and base["speed"] > base["real"] + 3.0,
			"setup: the plant shows the defect (pinned at %.2f m/s, reporting %.2f)" % [base["real"], base["speed"]])
	assert_true(absf(base["reader"] - base["estimated"]) < 0.01, "switched off, the reader IS estimated_velocity (%.2f v %.2f)" % [base["reader"], base["estimated"]])
	assert_true(now["real"] < 1.0, "the truck is still pinned (%.2f m/s)" % now["real"])
	assert_true(now["reader"] <= now["real"] + 0.5, "real_velocity is the motion it makes (%.2f v %.2f m/s)" % [now["reader"], now["real"]])
	assert_true(now["speed"] > now["real"] + 3.0, "design B: the plant's speed is untouched (%.2f)" % now["speed"])
	assert_true(now["estimated"] > now["real"] + 3.0, "design B: estimated_velocity is untouched (%.2f)" % now["estimated"])


## The native tank drive (stage 1 ON in check) writes `estimated_velocity` itself; `real_velocity` must be as honest
## behind it (the GDScript reads it after the native call until native's port carries it, C30.2).
func test_the_native_plant_reads_the_same_pin() -> void:
	if not NativeBridge.available:
		print("MEASURE m4b_wedge_native: no native library here, skipped")
		return
	var now := await _press("gang_tank", 12.0, 4.0, true, true)
	print("MEASURE m4b_wedge_native gang_tank pinned (native plant): real %.2f, reader %.2f, speed %.2f, estimated %.2f" % [
			now["real"], now["reader"], now["speed"], now["estimated"]])
	assert_true(now["real"] < 1.0, "the truck is still pinned (%.2f m/s)" % now["real"])
	assert_true(now["reader"] <= now["real"] + 0.5, "real_velocity is the motion it makes on the native plant (%.2f v %.2f)" % [now["reader"], now["real"]])
	assert_true(now["speed"] > now["real"] + 3.0, "the native plant's speed is untouched too (%.2f)" % now["speed"])


func test_a_free_truck_reads_the_same_either_way() -> void:
	var now := await _press("gang_tank", 40.0, 2.0, true)
	var base := await _press("gang_tank", 40.0, 2.0, false)
	print("MEASURE m4b_free gang_tank driving free: speed %.3f (base %.3f), reader %.2f, estimated %.2f, real %.2f" % [
			now["speed"], base["speed"], now["reader"], now["estimated"], now["real"]])
	assert_true(now["real"] > 3.0, "setup: the truck drives free (%.2f m/s)" % now["real"])
	assert_true(absf(now["speed"] - base["speed"]) < 0.05, "same plant speed both ways (%.3f v %.3f)" % [now["speed"], base["speed"]])
	assert_true(absf(now["reader"] - now["estimated"]) < 0.3, "free, the reader equals the plant's reading (%.2f v %.2f)" % [now["reader"], now["estimated"]])


func test_a_tracked_tank_pinned_reads_its_real_motion_and_drives_the_same() -> void:
	var now := await _press("tank", 9.0, 4.0, true)
	var base := await _press("tank", 9.0, 4.0, false)
	print("MEASURE m4b_tracked tank pinned: real %.2f, reader %.2f, speed %.2f (base reader %.2f, speed %.2f)" % [
			now["real"], now["reader"], now["speed"], base["reader"], base["speed"]])
	assert_true(now["reader"] <= now["real"] + 0.5, "real_velocity is the motion it makes (%.2f v %.2f)" % [now["reader"], now["real"]])
	assert_true(absf(now["speed"] - base["speed"]) < 0.05, "a tracked hull's plant speed is unchanged (%.3f v %.3f)" % [now["speed"], base["speed"]])


## A rig driving into a wall at a shallow angle slides along it; its plant speed (the thing round 29's (A) zeroed on
## every brush) is the same with the reader on or off, pose for pose, and it keeps most of its speed.
func _brush(real_on: bool) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_real := Tank.real_velocity_on
	Tank.real_velocity_on = real_on
	BrainSwitches.native = false
	var lab := TacticsLab.create(self, 31)
	# A 50 m wall along the lane, its face 6.5 m to the rig's right (a 14 m hull at 20 deg reaches 3.95 m out at its
	# corner, so the start is clear); the rig starts nosed 20 deg into it and meets it after ~7 m, at speed.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 6.0, 50.0)
	shape.shape = box
	wall.add_child(shape)
	add_to_tree(wall)
	wall.global_position = Vector3(TacticsScenarios.LANE_X + 7.0, 3.0, 5.0)
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 30), deg_to_rad(-20.0), "gang_tank")
	await lab.start()
	_controller_of(lab, rig).set_physics_process(false)
	var poses := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	var touched := 0
	for tick in int(SimClock.TICK_RATE * 3.5):
		rig.command = TankCommand.new(1.0, 0.0, rig.global_position + Vector3(0, 0, -20))
		await lab.step()
		if rig.get_slide_collision_count() > 0:
			touched += 1
		poses.append(rig.global_position.x)
		poses.append(rig.global_position.z)
		speeds.append(rig.speed())
	var out := {"poses": poses, "speeds": speeds, "touched": touched, "speed": rig.speed(),
			"reader": Vector2(rig.real_velocity.x, rig.real_velocity.z).length(), "z": rig.global_position.z}
	lab.dispose()
	BrainSwitches.native = was_native
	Tank.real_velocity_on = was_real
	return out


func test_a_rig_brushing_a_wall_keeps_its_plant_speed() -> void:
	var now := await _brush(true)
	var base := await _brush(false)
	print("MEASURE m4b_brush gang_tank along a wall: touched %d ticks, end speed %.2f (base %.2f), reader %.2f, z %.1f" % [
			now["touched"], now["speed"], base["speed"], now["reader"], now["z"]])
	assert_true(now["touched"] > 10 and now["touched"] < 90, "setup: the rig meets the wall under way and slides along it (%d of 105 ticks touching)" % now["touched"])
	assert_true(now["speed"] > 6.0, "it slides along the wall at speed (%.2f m/s)" % now["speed"])
	# Two lab instances in one process differ by a few cm at spawn (the depenetration of the hull placed over the
	# floor), so the arms are compared within that, not bit for bit.
	var worst_pose := 0.0
	var worst_speed := 0.0
	for i in now["speeds"].size():
		worst_speed = maxf(worst_speed, absf(now["speeds"][i] - base["speeds"][i]))
		worst_pose = maxf(worst_pose, Vector2(now["poses"][2 * i] - base["poses"][2 * i], now["poses"][2 * i + 1] - base["poses"][2 * i + 1]).length())
	print("MEASURE m4b_brush arms: worst pose gap %.3f m, worst plant speed gap %.3f m/s over %d ticks" % [worst_pose, worst_speed, now["speeds"].size()])
	assert_true(worst_pose < 0.25, "pose for pose the same with the reader on or off, the plant untouched (worst %.3f m)" % worst_pose)
	assert_true(worst_speed < 0.25, "and the plant speed every tick (worst %.3f m/s)" % worst_speed)


## The stall escape on a rig pinned on a SQUADMATE: with the honest reader it fires within a few seconds and the rig gets
## free (the reverse on full lock swings the nose off the hull and it goes round it: freed = 1.5 m from where it was
## pinned and under way again); round 29's reading never fires (the defect, reproduced). Movement.unstick is driven
## directly on the plant: the controller's own tick is off, so this is the GDScript rule on either native switch.
func _escape(real_on: bool, backoff_on: bool, seconds: float) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_real := Tank.real_velocity_on
	var was_off := Movement._off
	Tank.real_velocity_on = real_on
	BrainSwitches.native = false
	Movement._off = PackedStringArray([]) if backoff_on else PackedStringArray(["unstickback"])
	var lab := TacticsLab.create(self, 31)
	var a := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 20), 0.0, "gang_tank")
	# 16 m apart: two 14 m hulls with a 2 m gap (12 m would overlap at spawn, and the depenetration shove reads as
	# motion); B reaches A in under a second and is pinned from then on.
	var b := lab.gun(Match.Team.GREEN, "Green_A_2", Vector3(TacticsScenarios.LANE_X, 0, 36), 0.0, "gang_tank")
	await lab.start()
	var ca := _controller_of(lab, a)
	var cb := _controller_of(lab, b)
	ca.set_physics_process(false)
	cb.set_physics_process(false)
	var mover := cb.movement
	var goal := b.global_position + Vector3(0, 0, -40)
	var order := {"type": "move_to", "x": goal.x, "z": goal.z}
	var fires_before := Movement.unstick_fires
	var pinned_at := Vector3.INF  # where the hull stood when the stall rule fired
	var fired_at := -1.0
	var freed_at := -1.0
	var delta := 1.0 / float(SimClock.TICK_RATE)
	for tick in int(SimClock.TICK_RATE * seconds):
		var cmd := TankCommand.new(1.0, 0.0, goal)
		mover.unstick(cmd, order, delta)
		b.command = cmd
		a.command = TankCommand.new(0.0, 0.0, a.global_position + Vector3(0, 0, -20))
		if fired_at < 0.0 and Movement.unstick_fires > fires_before:
			fired_at = tick * delta
			pinned_at = b.global_position
		await lab.step()
		if pinned_at == Vector3.INF:
			continue
		var away := Vector2(b.global_position.x - pinned_at.x, b.global_position.z - pinned_at.z).length()
		if freed_at < 0.0 and away >= 1.5 and b.real_velocity.length() >= 3.0:
			freed_at = tick * delta
	var out := {"fires": Movement.unstick_fires - fires_before, "fired_at": fired_at, "freed_at": freed_at,
			"backed": Movement.unstick_backed, "capped": Movement.unstick_capped}
	lab.dispose()
	BrainSwitches.native = was_native
	Tank.real_velocity_on = was_real
	Movement._off = was_off
	return out


func test_the_stall_rule_frees_a_rig_pinned_on_a_squadmate() -> void:
	var now := await _escape(true, true, 8.0)
	var base := await _escape(false, true, 8.0)
	print("MEASURE m4b_escape gang_tank pinned on a squadmate: fires %d at %.2f s, free at %.2f s (escapes ended by backoff %d, by cap %d) | old reading: fires %d" % [
			now["fires"], now["fired_at"], now["freed_at"], now["backed"], now["capped"], base["fires"]])
	assert_eq(base["fires"], 0, "the defect: with the old reading the stall rule never fires on a pinned rig")
	assert_true(now["fires"] >= 1 and now["fired_at"] <= 3.0, "the honest reader fires the stall rule within 3 s (at %.2f s)" % now["fired_at"])
	assert_true(now["freed_at"] >= 0.0 and now["freed_at"] - now["fired_at"] <= 4.0, "and the rig is free within 4 s of it (at %.2f s)" % now["freed_at"])


## A rig wedged NOSE-ON into a wall (the thing he sees in a Terminus street): the pressed-wall escape (round 10; the
## wall contact is observed here as the controller would) fires within a second of the pin and ends by its real
## backoff rule (1.5 m from where it was pinned), not by its cap. Measured, not assumed: the escape's reverse on lock
## yaws the hull (the plant's yaw fit, `Tank.yaw_fit_enabled`, is OFF by default, so a yaw is never refused) and the
## phantom momentum then slides it sideways along the face: it leaves the pin point sideways-and-back, in both arms. A
## pocket with walls either side is NOT a plant case (the hull yaws through them and physics ejects it), so the sized
## cap is judged on the Terminus census (`press_backed` v `press_capped`), not here.
func _wedge(backoff_on: bool, seconds: float) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_real := Tank.real_velocity_on
	var was_off := Movement._off
	Tank.real_velocity_on = true
	BrainSwitches.native = false
	Movement._off = PackedStringArray([]) if backoff_on else PackedStringArray(["unstickback"])
	var lab := TacticsLab.create(self, 31)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 6.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	add_to_tree(wall)
	wall.global_position = Vector3(TacticsScenarios.LANE_X, 3.0, 20.0)  # its south face at z 20.5
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 30), 0.0, "gang_tank")  # nose at z 23
	await lab.start()
	var ctl := _controller_of(lab, rig)
	ctl.set_physics_process(false)
	var mover := ctl.movement
	var goal := rig.global_position + Vector3(0, 0, -40)
	var order := {"type": "move_to", "x": goal.x, "z": goal.z}
	var presses_before := Movement.press_escapes
	var backed_before := Movement.press_backed
	var capped_before := Movement.press_capped
	var pinned_at := Vector3.INF
	var fired_at := -1.0
	var left_at := -1.0
	var max_away := 0.0
	var delta := 1.0 / float(SimClock.TICK_RATE)
	for tick in int(SimClock.TICK_RATE * seconds):
		mover.observe_contact()  # the controller's first line of every tick: the slide the plant made last tick
		var cmd := TankCommand.new(1.0, 0.0, goal)
		mover.unstick(cmd, order, delta)
		rig.command = cmd
		if fired_at < 0.0 and Movement.press_escapes > presses_before:
			fired_at = tick * delta
			pinned_at = rig.global_position
		await lab.step()
		if pinned_at == Vector3.INF:
			continue
		var away := Vector2(rig.global_position.x - pinned_at.x, rig.global_position.z - pinned_at.z).length()
		max_away = maxf(max_away, away)
		if left_at < 0.0 and away >= Movement.PRESS_BACKOFF_M:
			left_at = tick * delta
	var out := {"presses": Movement.press_escapes - presses_before, "fired_at": fired_at, "left_at": left_at,
			"max_away": max_away, "backed": Movement.press_backed - backed_before, "capped": Movement.press_capped - capped_before,
			"y": rig.global_position.y}
	lab.dispose()
	BrainSwitches.native = was_native
	Tank.real_velocity_on = was_real
	Movement._off = was_off
	return out


func test_the_pressed_wall_escape_frees_a_wedged_rig() -> void:
	var now := await _wedge(true, 8.0)
	var short := await _wedge(false, 8.0)
	print("MEASURE m4b_wedge_wall gang_tank nose-on into a wall: press escapes %d, first at %.2f s, 1.5 m off the pin at %.2f s, max %.2f m, ended by backoff %d / cap %d, y %.2f | round 29's 2 s cap: escapes %d, off at %.2f s, by backoff %d / cap %d" % [
			now["presses"], now["fired_at"], now["left_at"], now["max_away"], now["backed"], now["capped"], now["y"],
			short["presses"], short["left_at"], short["backed"], short["capped"]])
	assert_true(now["presses"] >= 1 and now["fired_at"] <= 3.0, "the pressed-wall escape fires within 3 s of the pin (at %.2f s)" % now["fired_at"])
	assert_true(now["left_at"] >= 0.0 and now["left_at"] - now["fired_at"] <= 4.0, "the rig is 1.5 m off its pin within 4 s of it (at %.2f s)" % now["left_at"])
	assert_true(now["backed"] >= 1, "its escape ended by the real backoff, not the cap (backoff %d, cap %d)" % [now["backed"], now["capped"]])
	assert_true(absf(now["y"]) < 0.5, "and it is still on the floor (y %.2f)" % now["y"])
