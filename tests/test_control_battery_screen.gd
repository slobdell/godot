extends TestCase
## Round 47 (orders O6): his Sumps game (references/round46/playtest/2026-10-30T15-53-39-sumps.jsonl): a screen order reached
## Charlie, his artillery, which drove its mortars north onto the screen line at (-1, 59) and took fire there. A screen task to a
## squad that is all artillery is taken as support by fire on the same point (its firing position covering the line); a tank
## squad's screen is a screen. `--battery-screen=off` (RtsControls.BATTERY_SCREEN) is round 46's.

const GUNS := ["Green_Guns_1", "Green_Guns_2", "Green_Guns_3"]
const TANKS := ["Green_Tanks_1", "Green_Tanks_2", "Green_Tanks_3"]
const SCREEN_AT := [0.0, -80.0]

var _lab: TacticsLab
var _controls: RtsControls


func teardown() -> void:
	RtsControls.BATTERY_SCREEN = not OS.get_cmdline_user_args().has("--battery-screen=off")
	if _controls != null and is_instance_valid(_controls):
		_controls.queue_free()
	_controls = null
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _build() -> void:
	_lab = TacticsLab.create(self, 7)
	for i in GUNS.size():
		_lab.unit(Match.Team.GREEN, GUNS[i], Vector3(-30.0 + i * 8.0, 0, 60.0), 0.0, "law_artillery")
		_lab.unit(Match.Team.GREEN, TANKS[i], Vector3(14.0 + i * 8.0, 0, 60.0), 0.0, "law_tank")
	await _lab.start()
	_controls = RtsControls.new()
	_controls.game_match = _lab.game_match
	_controls.orders = _lab.orders
	_controls.elements = _lab.elements
	_controls.reveal_all = true
	add_to_tree(_controls)
	_controls.groups.save(1, GUNS.duplicate())
	_controls.groups.save(2, TANKS.duplicate())
	await wait_physics_frames(1)


func _screen(group: int) -> Element:
	_controls.recall_group(group)
	assert_eq(_controls.order_selection("screen", {"to": SCREEN_AT}), "", "his screen is taken")
	return _controls.elements.of(String(_controls.groups.members(group)[0]))


func test_a_batterys_screen_is_support_by_fire_and_a_tank_squads_is_a_screen() -> void:
	await _build()
	assert_true(_controls.all_artillery(GUNS), "the guns are all artillery")
	assert_true(not _controls.all_artillery(TANKS), "the tanks are not")
	var guns := _screen(1)
	var tanks := _screen(2)
	assert_eq(String(guns.task.get("verb", "")), "support_by_fire", "the battery covers the line from its firing position")
	assert_eq(guns.task.get("to"), SCREEN_AT, "on the point he clicked")
	assert_eq(String(tanks.task.get("verb", "")), "screen", "the tanks screen")


func test_off_is_round_46() -> void:
	await _build()
	RtsControls.BATTERY_SCREEN = false
	assert_eq(String(_screen(1).task.get("verb", "")), "screen", "OFF: the battery screens on the line")


## What he would see: ON the mortars stop well short of the line (their standoff); OFF they drive onto it.
func test_the_mortars_stay_off_the_line() -> void:
	var near := {}
	for on: bool in [false, true]:
		await _build()
		RtsControls.BATTERY_SCREEN = on
		_screen(1)
		for i in int(25.0 * SimClock.TICK_RATE):
			await _lab.step()
		var at := _lab.center_of(GUNS)
		near[on] = Vector2(at.x - SCREEN_AT[0], at.z - SCREEN_AT[1]).length()
		print("BATTERY_SCREEN %s: the battery's centre %.1f m from the line's point after 25 s" % ["on" if on else "off", near[on]])
		_controls.queue_free()
		_controls = null
		_lab.dispose()
		_lab = null
	assert_true(float(near[true]) > float(near[false]) + 15.0, "ON stands farther back than OFF (%.1f v %.1f m)" % [near[true], near[false]])
