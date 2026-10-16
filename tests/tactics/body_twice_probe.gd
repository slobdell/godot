extends SceneTree
## Round 32 (R32.6, MEASUREMENT ONLY): the body test's stage run several times in ONE process, to find the static that
## carries from one match to the next. test_tactics_body read on 24.5 after an off run in the same process and 12.0 in a
## fresh one (builder0): `--arms=off,on` runs them in order; `--clear=a,b` empties those static caches before every run
## after the first (CLEARS below).
##   godot --headless --fixed-fps 30 --path . --script res://tests/tactics/body_twice_probe.gd -- --arms=on,on --clear=slot
##   BODY_TWICE {"run", "arm", "cleared", "alone_s", "arrived_s", "Sirens": ...}

var case: TestCase

const CLEARS := ["slot", "pathing", "avoid", "perception", "tick", "squad", "cover", "unanswered", "feed", "incoming",
		"body", "traffic"]


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _clear(what: String) -> void:
	match what:
		"slot":
			SlotGround._side_memo.clear()
			SlotGround._ground_memo.clear()
		"pathing":
			Pathing._memo.clear()
			Pathing._memo_frame = -1
		"avoid":
			Avoidance._grid.clear()
			Avoidance._index.clear()
		"perception":
			Perception._seen.clear()
		"tick":
			AiTickCache._by_name.clear()
			AiTickCache._facing_cache = [{}, {}]
			AiTickCache._fired.clear()
			AiTickCache._hooked.clear()
		"squad":
			SquadTactics._cache.clear()
		"cover":
			CoverMap._cached = null
			CoverMap._cached_arena_id = 0
		"unanswered":
			UnansweredFire._asked.clear()
		"feed":
			ElementFeed._ctx_memo.clear()
		"incoming":
			IncomingFire._hull_by_unit.clear()
		"body":
			Element._body_memo.clear()
		"traffic":
			Traffic._forget()
		_:
			push_error("body_twice_probe: no clear named %s (have %s)" % [what, CLEARS])


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var clears := _flag("clear", "").split(",", false)
	var run := 0
	for arm: String in _flag("arms", "off,on").split(","):
		if run > 0:
			for what: String in clears:
				_clear(what)
		Element.BODY_ENABLED = arm != "off"
		var report := await BodyStage.run(case, int(_flag("seed", "1")), float(_flag("seconds", "60")))
		report["run"] = run
		report["arm"] = arm
		report["cleared"] = ",".join(clears) if run > 0 else ""
		print("BODY_TWICE " + JSON.stringify(report))
		run += 1
	Element.BODY_ENABLED = true
	case.teardown()
	quit(0)
