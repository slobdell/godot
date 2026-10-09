extends SceneTree
## Round 24 (for native, the freeze set): what each call inside the brain's t.poll lap costs, timed from OUTSIDE
## tank_brain.gd (frozen), in-process on a live player squad moving under its element's orders (the yard).
##   POLL_PART <name> <us a call>

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var lab := TacticsLab.create(case, 3, "yard")
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var names: Array = []
	for i in 5:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_F_%d" % (i + 1), Vector3(-24.0 + 8.0 * i, 0.0, 60.0), PI, "law_tank").name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	element.assign({"verb": "move", "to": [0.0, -40.0], "drills": false})
	for tick in 90:
		await lab.step()
	var gm := lab.game_match
	var tanks: Array = []
	for n: String in names:
		tanks.append(lab.tank_of(n))
	var calls := 20000
	var parts := {}
	var t0 := 0
	t0 = Time.get_ticks_usec()
	for c in calls:
		gm.squad_for(tanks[c % 5])
	parts["match.squad_for"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		AiTickCache.order_source(gm)
	parts["AiTickCache.order_source"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		AiTickCache.element_source(gm)
	parts["AiTickCache.element_source"] = Time.get_ticks_usec() - t0
	var feed := AiTickCache.order_source(gm)
	t0 = Time.get_ticks_usec()
	for c in calls:
		OrderFeed.current(feed, String(names[c % 5]))
	parts["OrderFeed.current"] = Time.get_ticks_usec() - t0
	var now := OrderFeed.current(feed, String(names[0]))
	t0 = Time.get_ticks_usec()
	for c in calls:
		OrderFeed.key(now)
	parts["OrderFeed.key"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		OrderFeed.station(feed, String(names[c % 5]))
	parts["OrderFeed.station"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		OrderFeed.player_team(gm)
	parts["OrderFeed.player_team"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		feed.call("current", String(names[c % 5]))
	parts["  Orders.current"] = Time.get_ticks_usec() - t0
	var raw: Variant = feed.call("current", String(names[0]))
	t0 = Time.get_ticks_usec()
	for c in calls:
		OrderFeed.normalize(raw)
	parts["  OrderFeed.normalize"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		feed.call("pace_factor", String(names[c % 5]))
	parts["  Orders.pace_factor"] = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for c in calls:
		feed.call("goal_position", String(names[c % 5]))
	parts["  Orders.goal_position"] = Time.get_ticks_usec() - t0
	for key: String in parts:
		print("POLL_PART %s %.2f us" % [key, float(parts[key]) / calls])
	print("POLL_ORDER_KEYS %s" % [now.keys()])
	lab.dispose()
	case.teardown()
	quit(0)
