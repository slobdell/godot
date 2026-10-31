extends TestCase
## Round 47 (camera K2/K3): a new selection pans at once and his squad stays framed (RtsCamera.select_pan).
## His notes (2026-10-30): "a delay between selecting a squad and the camera starting to move toward the other selected
## squad"; "the squad I was controlling off in the distance at the edge of the peripheral, and the camera position didn't
## seem to correct". Parade tick 2911: Bravo 152 m ahead, at the top edge of the view, so round 46's urgent pan (a crew OFF
## screen) never began and the look crept at the hand's pace.

const FPS := 60.0


func _squad(at: Vector3) -> Array:
	return [at + Vector3(-3, 0, 0), at + Vector3(3, 0, 0), at + Vector3(0, 0, 8)]


func _middle(points: Array) -> Vector3:
	var m := Vector3.ZERO
	for p: Vector3 in points:
		m += p
	return m / float(points.size())


func _rig(frame: Array, names: Array, pan := true) -> RtsCamera:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	RtsCamera.fov = RtsCamera.FOV_DEG
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 40)
	rig.zoom = RtsCamera.level_for(49.0)
	add_to_tree(rig)
	rig.planner_on = true
	rig.select_pan = pan
	rig.set_meta("frame", frame)
	rig.set_meta("names", names)
	rig.vision = func() -> Dictionary:
		var f: Array = rig.get_meta("frame")
		return {"frame": f, "own": f.size(), "pad_m": 2.0, "destination": null, "region": null}
	rig.selection = func() -> Array: return rig.get_meta("names")
	return rig


## His hand on the mouse as the replay models it: moving 0.6 s, resting 0.4 s (under HOVER_HOLD_S: the aim hold applies).
func _hand(rig: RtsCamera) -> void:
	if fmod(rig._clock, 1.0) < 0.6:
		rig._mouse_moved_at = rig._clock


func _gap(rig: RtsCamera) -> float:
	var m := _middle(rig.get_meta("frame"))
	return Vector2(rig._shown_focus.x - m.x, rig._shown_focus.z - m.z).length()


func _settle(rig: RtsCamera, seconds: float) -> void:
	for i in int(seconds * FPS):
		_hand(rig)
		rig._process(1.0 / FPS)


## Seconds (at 60 fps, his hand on the mouse) until the look is within `metres` of the selection, or -1.
func _frames_until(rig: RtsCamera, metres: float, limit_s: float) -> float:
	for i in int(limit_s * FPS):
		_hand(rig)
		rig._process(1.0 / FPS)
		if _gap(rig) < metres:
			return (i + 1) / FPS
	return -1.0


func test_round_46s_rule_counts_a_squad_150_m_ahead_at_the_top_edge_as_shown_and_crawls() -> void:
	var rig := _rig(_squad(Vector3(0, 0, 40)), ["a"], false)
	rig.aiming = func() -> bool: return true
	_settle(rig, 2.0)
	rig.set_meta("frame", _squad(Vector3(0, 0, -110)))  # straight ahead, 150 m: Parade's Bravo
	rig.set_meta("names", ["b"])
	rig._process(1.0 / FPS)
	assert_true(rig._selection_shown(), "the cause: the far squad is ON the screen, at its top edge")
	var took := _frames_until(rig, 20.0, 3.0)
	assert_true(took < 0.0, "round 46's camera has not framed it 3 s later (took %.2f)" % took)


func test_a_new_selection_150_m_ahead_is_framed_within_a_second_while_his_hand_is_on_the_mouse() -> void:
	var rig := _rig(_squad(Vector3(0, 0, 40)), ["a"])
	rig.aiming = func() -> bool: return true
	_settle(rig, 2.0)
	rig.set_meta("frame", _squad(Vector3(0, 0, -110)))
	rig.set_meta("names", ["b"])
	var took := _frames_until(rig, 20.0, 3.0)
	assert_true(took > 0.0 and took <= 1.5, "within 20 m in %.2f s (want <= 1.5 at 4 heights/s)" % took)


func test_a_new_selection_off_to_the_side_is_framed_as_fast() -> void:
	var rig := _rig(_squad(Vector3(0, 0, 40)), ["a"])
	rig.aiming = func() -> bool: return true
	_settle(rig, 2.0)
	rig.set_meta("frame", _squad(Vector3(140, 0, 0)))
	rig.set_meta("names", ["b"])
	var took := _frames_until(rig, 20.0, 3.0)
	assert_true(took > 0.0 and took <= 1.5, "within 20 m in %.2f s (want <= 1.5 at 4 heights/s)" % took)


func test_the_pan_starts_on_the_next_frames_even_while_he_aims_and_starts_from_rest() -> void:
	var rig := _rig(_squad(Vector3(0, 0, 40)), ["a"])
	rig.aiming = func() -> bool: return true
	_settle(rig, 2.0)
	rig._mouse_moved_at = rig._clock - 0.3  # his hand has just come to rest on a unit: the aim hold's case
	var before := rig._shown_focus
	rig.set_meta("frame", _squad(Vector3(0, 0, -110)))
	rig.set_meta("names", ["b"])
	var steps: Array = []
	var last := before
	for i in 30:
		rig._process(1.0 / FPS)
		steps.append(rig._shown_focus.distance_to(last))
		last = rig._shown_focus
	assert_true(not (rig.holding), "nothing holds the pan to his new selection")
	assert_true(rig._shown_focus.distance_to(before) > 5.0, "moving within half a second (%.1f m)" % rig._shown_focus.distance_to(before))
	assert_true(float(steps[0]) < 1.5, "from rest: the first frame moves %.2f m" % float(steps[0]))
	for i in range(1, steps.size()):
		assert_true(float(steps[i]) - float(steps[i - 1]) < 1.0, "no step in speed at frame %d (%s)" % [i, str(steps)])
		var height := 2.0 * RtsCamera.distance_for(rig._shown_zoom) * tan(deg_to_rad(RtsCamera.fov) / 2.0)
		assert_true(float(steps[i]) <= RtsCamera.PAN_SCREENS_PER_S * height / FPS + 0.05, "a pan, not a cut: under %.1f heights/s" % RtsCamera.PAN_SCREENS_PER_S)


func test_a_squad_that_drove_off_while_he_aimed_is_caught_up_once_he_stops_aiming() -> void:
	var rig := _rig(_squad(Vector3(0, 0, 40)), ["a"])
	rig.aiming = func() -> bool: return true
	_settle(rig, 3.0)  # the selection is old: no fresh pan left
	for i in 60:  # he aims (hand resting) while the squad drives 60 m away
		rig._mouse_moved_at = rig._clock - 0.3
		rig.set_meta("frame", _squad(Vector3(i * 1.0, 0, 40)))
		rig._process(1.0 / FPS)
	rig.set_meta("frame", _squad(Vector3(70, 0, 40)))
	for i in 30:  # still aiming: the correction waits for him (a pan under his aim slides his click)
		rig._mouse_moved_at = rig._clock - 0.3
		rig._process(1.0 / FPS)
	assert_true(not rig.planner_urgent, "no correction starts under his aim")
	var took := -1.0
	for i in int(3.0 * FPS):  # he lets go of the mouse: the aim lapses after HOVER_HOLD_S, then the view catches up
		rig._process(1.0 / FPS)
		if _gap(rig) < 20.0:
			took = (i + 1) / FPS
			break
	assert_true(took >= 0.0 and took <= RtsCamera.HOVER_HOLD_S + 1.0, "the view corrects once he stops aiming (%.2f s)" % took)


func test_his_own_pan_stays_his_until_he_selects_then_the_view_comes_back_at_once() -> void:
	var rig := _rig(_squad(Vector3(0, 0, 40)), ["a"])
	_settle(rig, 3.0)
	rig.pan_world(Vector2(80, 0))  # he looks elsewhere by hand
	var urgent := false
	for i in int(5.0 * FPS):
		rig._process(1.0 / FPS)
		urgent = urgent or rig.planner_urgent
	assert_true(not (urgent), "no fast swing back over his own pan")
	rig.pan_world(Vector2(80, 0))
	rig.take_vision()  # he selects (the same squad): the camera is handed back
	var took := _frames_until(rig, 20.0, 2.0)
	assert_true(took >= 0.0 and took <= 1.5, "back on his squad in %.2f s" % took)


func test_the_planners_point_stays_within_the_bound_of_his_selection() -> void:
	var crews := _squad(Vector3(0, 0, 0))
	var far := RtsCamera.bound_to(Vector3(0, 0, -50), crews, RtsCamera.SEL_BOUND_M)
	var mean := _middle(crews)
	assert_near(Vector2(far.x - mean.x, far.z - mean.z).length(), RtsCamera.SEL_BOUND_M, 0.01, "a 50 m lean is held to the bound")
	var near := Vector3(5, 0, -5)
	assert_true(RtsCamera.bound_to(near, crews, RtsCamera.SEL_BOUND_M) == near, "inside the bound: untouched")
	var strung := [Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(0, 0, -120)]  # one crew far ahead: the frame's centre is 50 m off the mean
	var centre := Vector3(0, 0, -60)
	assert_true(RtsCamera.bound_to(centre, strung, RtsCamera.SEL_BOUND_M).distance_to(centre) < 0.01, "a strung-out squad keeps its frame")
