extends TestCase
## Cover behavior (A2/A3 in _agents/streams/archive/round2/ai.md). The stage: WallWestA (x -45..-27, z ≈ -20) with a Green
## tank in the open south-east of it and Rust guns to the north whose sight lines pass east of the wall.

const PENDING := []

const GREEN_START := Vector3(-20, 0, -12)
## Behind the wall from both guns (checked by the setup assertions).
const HIDDEN_SPOT := Vector3(-36, 0, -14)


func _stage(s: AiScenario, gun_count: int) -> Array[Tank]:
	var guns: Array[Tank] = []
	var spots := [Vector3(-38, 0, -55), Vector3(-30, 0, -58)]
	for i in gun_count:
		var gun := s.shooter(Match.Team.RUST, "Rust_Gun_%d" % (i + 1), spots[i], PI)
		AiScenario.make_durable(gun)
		guns.append(gun)
	return guns


func _hidden_from_all(me: Tank, guns: Array[Tank]) -> bool:
	for gun in guns:
		if AiScenario.sees(gun, me):
			return false
	return true


func test_a_hurt_tank_under_fire_gets_out_of_sight() -> void:
	var s := AiScenario.create(self)
	var guns := _stage(s, 2)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", GREEN_START, 0.0)
	# 40% hurt. Combat X2 (round 3): a hull big enough to live through one volley of the new cannons (320 per shell);
	# at 120 of 300 the first shell killed it before any brain could react (two side hits: 640).
	me.max_health = 2000
	me.health = 800
	me.shield = 0.0
	me.ticks_since_hit = 0  # just hit: the shield stays down for its recharge delay
	var hidden_run := 0
	var longest_hidden := 0
	var first_hidden := -1
	var visible_at_start := false
	await s.start()
	for tick in range(1, SimClock.TICK_RATE * 7 + 1):
		await s.step()
		if not me.is_alive():
			continue
		if tick == 1:
			visible_at_start = not _hidden_from_all(me, guns)
		if _hidden_from_all(me, guns):
			hidden_run += 1
			longest_hidden = maxi(longest_hidden, hidden_run)
			if first_hidden < 0:
				first_hidden = tick
		else:
			hidden_run = 0
	print("MEASURE ai_hurt_to_cover first hidden after %d ticks, longest hidden %d ticks, alive %s" % [first_hidden, longest_hidden, me.is_alive()])
	assert_true(visible_at_start, "setup: both guns can see the tank at the start")
	assert_true(me.is_alive(), "the tank survives 7 s under two guns")
	assert_true(first_hidden > 0 and first_hidden <= SimClock.TICK_RATE * 5, "it is out of both guns' sight within 5 s (first hidden at tick %d)" % first_hidden)
	assert_true(longest_hidden >= 60, "and stays hidden for at least a second (%d ticks)" % longest_hidden)


func test_a_healthy_tank_near_a_wall_fights_from_cover() -> void:
	var s := AiScenario.create(self)
	var guns := _stage(s, 1)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", GREEN_START, 0.0)
	# Durable since CP2 (round-3 cannons: 320 per shell, three hits kill): this measures fighting from cover, not survival.
	AiScenario.make_durable(me)
	var samples := 0
	var hidden := 0
	var back_in_cover_after_shot := 0
	var shots_seen := 0
	var was_hidden := false
	await s.start()
	for tick in range(1, SimClock.TICK_RATE * 25 + 1):
		await s.step()
		if tick < SimClock.TICK_RATE * 5 or not me.is_alive():
			continue
		samples += 1
		var now_hidden := _hidden_from_all(me, guns)
		hidden += 1 if now_hidden else 0
		if s.shots_by(me) > shots_seen and not now_hidden:
			shots_seen = s.shots_by(me)
		if now_hidden and not was_hidden and shots_seen > 0:
			back_in_cover_after_shot += 1
		was_hidden = now_hidden
	var fraction := float(hidden) / maxf(samples, 1)
	print("MEASURE ai_cover_fire hidden %.0f%% of 20 s, shots %d, returns to cover %d, alive %s" % [fraction * 100.0,
			s.shots_by(me), back_in_cover_after_shot, me.is_alive()])
	assert_true(fraction >= 0.5, "it spends most of the fight out of the gun's sight (%.0f%%)" % (fraction * 100.0))
	# At least half the shots its reload allows over the 20 s measured.
	var reload := float(Weapons.profile(me.weapon_id).get("reload", 2.5))
	var expected := int(20.0 / reload * 0.5)
	assert_true(s.shots_by(me) >= expected, "and still shoots back from cover (%d shots, at least %d)" % [s.shots_by(me), expected])
	assert_true(back_in_cover_after_shot >= 2, "it goes back into cover after firing, repeatedly (%d times)" % back_in_cover_after_shot)


## X3 reload windows, as round 18 (B1) rewrote them: the same wall duel for a brain variant, the brain made durable so
## hits can be counted. `teammate` (a spot, or null) puts a durable Green dummy in the open there, farther from the gun
## than the corner and on nearly the same bearing (inside the gun's watching cone), so the gun has someone else to
## shoot whenever the subject is out of sight, and reloads that are windows.
## A PEEK is the subject coming into the gun's sight, after at least PEEK_HIDDEN_TICKS out of it, while its brain is
## fighting from cover (COVER_FIRE: a real peek or a bait); it is AT A LOADED GUN when, on that tick, the gun is loaded
## and its turret points at the subject (TankBrain.COS_WATCHING, ~20 degrees). Coming into sight under any other option
## (ADVANCE once the team's intel has forgotten the gun, ENGAGE) is counted apart: "other_at_loaded".
## Returns {"hits", "shots", "gun_shots", "peeks", "peeks_at_loaded", "other_at_loaded", "friend_seen"}.
const PEEK_HIDDEN_TICKS := 10
## Stage 2's teammates: three spots east of the wall, 49-59 m from the gun (the corner is ~42 m), so the gun's reload
## is at a different phase each time the subject is ready to peek. Each one's line from the gun passes >= 6 m clear of the
## hide spot: a first version had (-19, -3), whose line ran 3.5 m from it, and shells aimed at the teammate hit the
## subject behind its wall (3 of 4 hits there, x3 and the champion alike).
const TEAMMATE_SPOTS := [Vector3(-15, 0, -5), Vector3(-10, 0, -3), Vector3(-12, 0, -9)]


func _cover_duel(variant: String, teammate: Variant = null, seconds := 30, gun_count := 1) -> Dictionary:
	BrainVariants.use(Match.Team.GREEN, variant)
	var s := AiScenario.create(self)
	var guns := _stage(s, gun_count)
	var gun := guns[0]
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", GREEN_START, 0.0)
	AiScenario.make_durable(me)
	var friend: Tank = null
	if teammate is Vector3:
		friend = s.dummy(Match.Team.GREEN, "Green_B_1", teammate, PI)
		AiScenario.make_durable(friend)
	var hits := 0
	var last := me.health + me.shield
	var hidden_for := 0
	var peeks := 0
	var at_loaded := 0
	var other_at_loaded := 0
	var friend_seen := true
	await s.start()
	for tick in SimClock.TICK_RATE * seconds:
		await s.step()
		var now := me.health + me.shield
		if now < last - 5.0:
			hits += 1
		var brain := s.brain_of(me)
		if OS.has_environment("BRAINS_COVER_TRACE") and (tick % 6 == 0 or now < last - 5.0):
			print("COVER_TRACE %s t=%d hit=%s seen=%s gun_reload=%.2f me_reload=%.2f pos=(%.0f,%.0f) %s | %s" % [variant, tick,
					now < last - 5.0, AiScenario.sees(gun, me), gun.sync_reload, me.sync_reload, me.global_position.x,
					me.global_position.z, brain.choice.get("option", ""), brain.why])
		last = now
		if friend != null and tick == 0:
			friend_seen = AiScenario.sees(gun, friend)
		if _seen_by_any(guns, me):
			if hidden_for >= PEEK_HIDDEN_TICKS:
				var loaded := _loaded_on(guns, me)
				if String(brain.choice.get("option", "")) == "COVER_FIRE":
					peeks += 1
					at_loaded += 1 if loaded else 0
				elif loaded:
					other_at_loaded += 1
			hidden_for = 0
		else:
			hidden_for += 1
	var result := {"hits": hits, "shots": s.shots_by(me), "gun_shots": s.shots_by(gun), "peeks": peeks,
			"peeks_at_loaded": at_loaded, "other_at_loaded": other_at_loaded, "friend_seen": friend_seen}
	s.dispose()
	BrainVariants.reset()
	return result


func _seen_by_any(guns: Array[Tank], me: Tank) -> bool:
	for gun in guns:
		if AiScenario.sees(gun, me):
			return true
	return false


## A gun that sees `me`, is loaded, and points at me (within TankBrain.COS_WATCHING).
func _loaded_on(guns: Array[Tank], me: Tank) -> bool:
	for gun in guns:
		if AiScenario.sees(gun, me) and gun.sync_reload >= 1.0 \
				and TankBrain.points_at(gun.turret_forward(), me.global_position - gun.global_position, TankBrain.COS_WATCHING):
			return true
	return false


## Sums _cover_duel over the stage-2 teammate spots.
func _teammate_duels(variant: String) -> Dictionary:
	var total := {}
	for spot: Vector3 in TEAMMATE_SPOTS:
		var one: Dictionary = await _cover_duel(variant, spot, 40)
		print("MEASURE ai_reload_window teammate at (%.0f, %.0f) %s: %s" % [spot.x, spot.z, variant, one])
		for key: String in one:
			if key == "friend_seen":
				total[key] = bool(total.get(key, true)) and bool(one[key])
			else:
				total[key] = int(total.get(key, 0)) + int(one[key])
	return total


func _report(stage: String, plain: Dictionary, fixed: Dictionary) -> void:
	print("MEASURE ai_reload_window %s: x3 took %d hits, fired %d, peeked %d (%d at a loaded gun; %d other showings at one; gun fired %d); %s took %d, fired %d, peeked %d (%d at a loaded gun; %d other showings at one; gun fired %d)" % [
			stage, plain["hits"], plain["shots"], plain["peeks"], plain["peeks_at_loaded"], plain["other_at_loaded"],
			plain["gun_shots"], BrainVariants.CHAMPION, fixed["hits"], fixed["shots"], fixed["peeks"], fixed["peeks_at_loaded"],
			fixed["other_at_loaded"], fixed["gun_shots"]])


## B1 (round 18; the lead: "Yes make the CPU smarter, this would apply to all units"): a lone gun with nothing else to do
## stays LAID on the corner, so any showing into it is the sure hit. The champion (x18m) takes no real peek into a loaded
## gun watching it and draws no gun laid on its peek spot; it may still draw a gun that would have to traverse, which this
## gun never needs to. A lone gun opens a window only by firing at the subject, so the champion cannot take FEWER hits
## than x3 (no reload windows) here: no more, and no peek into the loaded gun.
func test_does_not_peek_into_a_gun_laid_on_it() -> void:
	var plain: Dictionary = await _cover_duel("x3")
	var fixed: Dictionary = await _cover_duel(BrainVariants.CHAMPION)
	_report("lone gun over 30 s", plain, fixed)
	assert_true(int(fixed["peeks_at_loaded"]) == 0, "%s never peeks into a loaded gun watching it (%d of %d peeks did)" % [
			BrainVariants.CHAMPION, fixed["peeks_at_loaded"], fixed["peeks"]])
	assert_true(int(fixed["hits"]) <= int(plain["hits"]), "and takes no more hits than x3 (%d vs %d)" % [fixed["hits"], plain["hits"]])


## B1's second stage: a teammate in the open draws the gun's shots, so its reloads are windows the subject can use. Measured
## with clean geometry (round 18, laptop): x3 — no reload windows, and no bait either — takes 3 hits over the three spots,
## and so does a brain that never peeks into a loaded gun; the round-15 bait brain (x5p) takes 9. So the bar is: no more
## hits than x3, FEWER than the bait brain, never a peek into a loaded gun, and it still fights.
## The floor: with the teammate drawing every shot, a brain that never baits and never times its peeks (x3) is already
## at it (3 hits); the champion ties it. What the champion must beat is the round-15 bait brain.
func test_with_a_teammate_drawing_fire_it_takes_no_more_hits_than_x3_and_fewer_than_the_bait_brain() -> void:
	var plain: Dictionary = await _teammate_duels("x3")
	var baiting: Dictionary = await _teammate_duels("x5p")
	var fixed: Dictionary = await _teammate_duels(BrainVariants.CHAMPION)
	_report("teammate draws, %d spots x 40 s" % TEAMMATE_SPOTS.size(), plain, fixed)
	print("MEASURE ai_reload_window teammate draws: x5p (the bait brain) took %d hits, fired %d" % [baiting["hits"], baiting["shots"]])
	assert_true(bool(plain["friend_seen"]) and bool(fixed["friend_seen"]), "setup: the gun can see the teammate")
	assert_true(int(fixed["peeks_at_loaded"]) == 0, "%s never peeks into a loaded gun watching it (%d of %d peeks did)" % [
			BrainVariants.CHAMPION, fixed["peeks_at_loaded"], fixed["peeks"]])
	assert_true(int(fixed["hits"]) <= int(plain["hits"]), "no more hits than x3 (%d vs %d)" % [fixed["hits"], plain["hits"]])
	assert_true(int(fixed["hits"]) < int(baiting["hits"]), "and fewer than the bait brain x5p (%d vs %d)" % [
			fixed["hits"], baiting["hits"]])
	assert_true(int(fixed["shots"]) >= 3 * TEAMMATE_SPOTS.size(), "and it still fights (%d shots)" % fixed["shots"])

