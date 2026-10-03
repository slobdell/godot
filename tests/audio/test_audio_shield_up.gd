extends TestCase
## Round 17 G6 (the audit): a shield coming back up (23-39 a minute in a 30-a-side fight) was silent. ShieldEffect
## (lent to guns for this one line, C17.6) asks for `shield_up` once when a shield returns from zero - never on each
## tick of a recharge, which would turn 30 a minute into hundreds.


func test_a_shield_returning_from_zero_is_heard_once() -> void:
	var fx := _fx()
	var shield := ShieldEffect.new()
	add_to_tree(shield)
	shield.set_shield(1.0)  # where it starts: not an event
	shield.set_shield(0.4)
	shield.set_shield(0.0)  # down
	var before := int(fx.sfx.plays.get("shield_up", 0))
	for step in [0.05, 0.1, 0.2, 0.4, 0.8, 1.0]:
		shield.set_shield(step)
	assert_eq(int(fx.sfx.plays.get("shield_up", 0)) - before, 1, "one recharge from zero, one shield_up")


func test_a_shield_ticking_upward_from_part_full_is_not_a_return() -> void:
	var fx := _fx()
	var shield := ShieldEffect.new()
	add_to_tree(shield)
	var before := int(fx.sfx.plays.get("shield_up", 0))
	shield.set_shield(1.0)
	shield.set_shield(0.5)
	for step in [0.55, 0.6, 0.7, 0.9]:
		shield.set_shield(step)
	assert_eq(int(fx.sfx.plays.get("shield_up", 0)) - before, 0, "a recharge that never hit zero says nothing")


## An FxWorld that FxWorld.existing() returns, as the game's own is (get_instance() makes none headless).
func _fx() -> FxWorld:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	FxWorld._instance = fx
	return fx


func teardown() -> void:
	FxWorld._instance = null
	super.teardown()
