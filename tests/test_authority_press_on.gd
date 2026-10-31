extends TestCase
## Round 47 (engage E7, R47.6): HIS ATTACK BEATS RETREAT. Route's R1 trace (his Locks, Hunters_4, staged from his census):
## a crew at 15/220 hull with threats in sight, carrying the attack_move its element dealt it under his attack on
## Rust_Lances_3, chose RETREAT (0.99 when critical) over the fight he ordered, and `withdraw_point` drove it north, away
## from his target, again and again. Under `--press-on` an attack_move naming a target, from an element whose task is
## ATTACK (his click, or a CPU commander's attack: C47.9), keeps the fight: RETREAT is not on the menu. Any other order
## keeps today's rule (a hurt crew under his move or attack-move still saves itself when it is about to die).

func teardown() -> void:
	TankBrain.PRESS_ON = TankBrain.PRESS_ON_DEFAULT
	super.teardown()


func _s(task: String) -> Dictionary:
	var s := {"contacts": [{"name": "Rust_Lances_3", "visible": true, "age": 0, "position": Vector3(30.0, 0.0, 0.0)}],
			"self": {"position": Vector3.ZERO, "weapon": {"range": 35.0}}, "features": {}}
	s["element"] = {"task": task} if task != "" else null
	return s


func _candidates() -> Array:
	return [{"option": "RETREAT", "target": "", "score": 0.99},
			{"option": "ENGAGE", "target": "Rust_Lances_3", "score": 0.6}]


func _options(result: Array) -> Array:
	return result.map(func(c: Dictionary) -> String: return String(c["option"]))


func _attack_move() -> Dictionary:
	return {"verb": "attack_move", "target": "Rust_Lances_3", "goal": Vector3(30.0, 0.0, 0.0)}


func test_today_a_critical_crew_under_his_attack_retreats() -> void:
	TankBrain.PRESS_ON = false
	var result := TankBrain._obey(_candidates(), _attack_move(), _s("attack"), true, false)
	assert_true(_options(result).has("RETREAT"), "--press-on=off is today's: critical, RETREAT is on the menu (%s)" % [_options(result)])


func test_under_his_attack_a_critical_crew_presses_on() -> void:
	TankBrain.PRESS_ON = true
	var result := TankBrain._obey(_candidates(), _attack_move(), _s("attack"), true, false)
	assert_true(not _options(result).has("RETREAT"), "his attack: no RETREAT (%s)" % [_options(result)])
	assert_true(_options(result).has("ENGAGE"), "and the fight he ordered is there (%s)" % [_options(result)])


func test_under_any_other_task_the_survival_rule_stands() -> void:
	TankBrain.PRESS_ON = true
	for task: String in ["move", "screen", ""]:
		var result := TankBrain._obey(_candidates(), _attack_move(), _s(task), true, false)
		assert_true(_options(result).has("RETREAT"), "task '%s': a crew about to die may still save itself (%s)" % [task, _options(result)])


func test_an_attack_move_that_names_no_target_keeps_the_survival_rule() -> void:
	TankBrain.PRESS_ON = true
	var order := _attack_move()
	order["target"] = ""
	var result := TankBrain._obey(_candidates(), order, _s("attack"), true, false)
	assert_true(_options(result).has("RETREAT"), "no named target: not his attack on it (%s)" % [_options(result)])


func test_not_critical_is_unchanged() -> void:
	for on: bool in [false, true]:
		TankBrain.PRESS_ON = on
		var result := TankBrain._obey(_candidates(), _attack_move(), _s("attack"), false, false)
		assert_true(not _options(result).has("RETREAT"), "not critical: RETREAT never under an attack-move (press_on %s)" % on)
