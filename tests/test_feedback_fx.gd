extends TestCase
## Round 37 (feedback, C37.6): FeedbackFx draws each look from the match's own events and state -- a flank or rear hit by
## its face (never an artillery round from above), a pinned crew, the Tanker's mending, the Emitter's cone -- and only
## the looks FeedbackLook picks.

const FIELD := Vector3(60.0, 0.0, 0.0)


func teardown() -> void:
	FeedbackLook.reset()


func _world() -> Array:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	fx.link.attach(game_match)
	return [fx, game_match]


func _shot(id: int, muzzle: Vector3, fire_model := "shell") -> Dictionary:
	return {"tick": 1, "shooter": "Shooter", "weapon": "cannon", "fire_model": fire_model, "projectile_id": id,
			"muzzle": [muzzle.x, muzzle.y, muzzle.z], "direction": [0.0, 0.0, -1.0]}


func _hit(id: int, target: String, face: String, weak_spot := false) -> Dictionary:
	return {"tick": 2, "projectile_id": id, "position": [FIELD.x, 1.0, FIELD.z], "normal": [0.0, 0.0, 1.0],
			"target": target, "face": face, "weak_spot": weak_spot, "damage": 30.0, "killed": false}


func test_hits_are_drawn_by_the_face_struck_and_artillery_never_reads_as_a_flank() -> void:
	FeedbackLook.use("hit:a+c")
	var world := _world()
	var fx: FxWorld = world[0]
	var target: Tank = (world[1] as Match).spawn_tank("Target", 0, Match.Team.RUST, "tank")
	target.global_position = FIELD
	var bursts := fx.bursts.started
	fx.feedback.fired(_shot(1, FIELD + Vector3(0, 1, 30)), 1.0)
	fx.feedback.impact(_hit(1, "Target", "rear"), 1.0)
	assert_eq(int(fx.feedback.hits_drawn.get("rear", 0)), 1, "a rear hit is drawn as one")
	assert_true(fx.bursts.started > bursts, "and flares (look a)")
	var hit := fx.feedback.recent_hit("Target", 1.1)
	assert_eq(String(hit.get("kind", "")), "rear", "remembered for the screen marker")
	assert_true((hit["toward"] as Vector3).dot(Vector3.BACK) > 0.99, "pointing back at where the shot came from")
	assert_true(fx.feedback.recent_hit("Target", 1.0 + FeedbackFx.HIT_MEMORY_S + 0.1).is_empty(), "and forgotten after")
	fx.feedback.fired(_shot(2, FIELD + Vector3(30, 20, 0), "arc"), 2.0)
	fx.feedback.impact(_hit(2, "Target", "side"), 2.0)
	assert_eq(int(fx.feedback.hits_drawn.get("side", 0)), 0, "a shell from above has no flank: nothing drawn")
	fx.feedback.impact(_hit(3, "Target", "side", true), 3.0)
	assert_eq(int(fx.feedback.hits_drawn.get("deck", 0)), 1, "the engine deck is its own kind")


func test_a_pinned_crew_a_mending_tanker_and_a_blowing_emitter_are_held_while_true() -> void:
	FeedbackLook.use("pinned:b,repair:a+b,cone:a+b+c")
	var world := _world()
	var fx: FxWorld = world[0]
	var game_match: Match = world[1]
	var pinned := game_match.spawn_tank("Pinned", 0, Match.Team.RUST, "tank")
	var tanker := game_match.spawn_tank("Tanker", 0, Match.Team.GREEN, "gang_support")
	var patient := game_match.spawn_tank("Patient", 1, Match.Team.GREEN, "gang_tank")
	pinned.global_position = FIELD + Vector3(0, 0, 40)
	tanker.global_position = FIELD
	patient.global_position = FIELD + Vector3(10, 0, 0)
	patient.health = patient.max_health / 2
	patient.ticks_since_hit = 1_000_000
	pinned.suppression = 0.9
	fx.feedback.fired({"shooter": "Tanker", "weapon": "sonic_emitter", "muzzle": [FIELD.x, 1.0, FIELD.z],
			"direction": [0.0, 0.0, -1.0], "projectile_id": 9}, fx.now)
	fx.feedback.update(fx.now)
	var counts := fx.feedback.last_counts
	assert_eq(int(counts.get(FeedbackFx.Mark.PIN_RING, 0)), 1, "one pinned crew, one pin ring")
	assert_eq(fx.feedback.pinned_of(&"Pinned"), 1.0, "pinned hard")
	assert_eq(int(counts.get("beams", 0)), 1, "one mending beam, Tanker to patient")
	assert_eq(int(counts.get(FeedbackFx.Mark.REACH_RING, 0)), 1, "the Tanker's reach while it mends")
	assert_eq(int(counts.get(FeedbackFx.Mark.MENDING_GLOW, 0)), 1, "under the patient")
	assert_eq(fx.feedback.mending_of(&"Patient").get("node"), tanker, "the screen half knows who mends it")
	assert_eq(int(counts.get(FeedbackFx.Mark.RIPPLES, 0)) + int(counts.get(FeedbackFx.Mark.FOOTPRINT, 0)), 2, "the cone, both ground looks")
	assert_eq(int(counts.get("cones", 0)), 1, "and in the air")
	pinned.suppression = 0.1
	patient.health = patient.max_health
	fx.now += 1.0
	fx.feedback.update(fx.now)
	counts = fx.feedback.last_counts
	assert_eq(int(counts.get(FeedbackFx.Mark.PIN_RING, 0)) + int(counts.get("beams", 0)) + int(counts.get("cones", 0)), 0,
			"recovered, mended, and the horns quiet: nothing left drawn")


func test_a_look_that_is_off_draws_nothing() -> void:
	FeedbackLook.use("pinned:off,repair:off,cone:off,hit:off")
	var world := _world()
	var fx: FxWorld = world[0]
	var game_match: Match = world[1]
	var pinned := game_match.spawn_tank("Pinned", 0, Match.Team.RUST, "tank")
	pinned.global_position = FIELD
	pinned.suppression = 1.0
	var bursts := fx.bursts.started
	fx.feedback.fired(_shot(1, FIELD + Vector3(0, 1, 30)), 1.0)
	fx.feedback.impact(_hit(1, "Pinned", "rear"), 1.0)
	fx.feedback.update(fx.now)
	assert_eq(fx.bursts.started, bursts, "no flare")
	assert_eq(int(fx.feedback.last_counts.get(FeedbackFx.Mark.PIN_RING, 0)), 0, "no ring")
	assert_eq(fx.feedback.pinned_of(&"Pinned"), 1.0, "but the fact is still read, for the screen half")


func test_the_reading_is_redone_ten_times_a_second_not_every_frame() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var game_match: Match = world[1]
	var crew := game_match.spawn_tank("Crew", 0, Match.Team.RUST, "tank")
	crew.global_position = FIELD
	crew.suppression = 1.0
	fx.feedback.update(fx.now)
	assert_eq(fx.feedback.pinned_of(&"Crew"), 1.0, "read on the first frame")
	crew.suppression = 0.0
	fx.now += FeedbackFx.REREAD_S * 0.5
	fx.feedback.update(fx.now)
	assert_eq(fx.feedback.pinned_of(&"Crew"), 1.0, "a frame later the last reading stands")
	fx.now += FeedbackFx.REREAD_S
	fx.feedback.update(fx.now)
	assert_eq(fx.feedback.pinned_of(&"Crew"), 0.0, "and the next reading sees it recover")


func test_the_look_flag_parses_slots_and_combinations() -> void:
	var picked := FeedbackLook.parse("hit:b,pinned:a+c,repair:off")
	assert_eq(Array(picked["hit"]), ["b"], "one look")
	assert_eq(Array(picked["pinned"]), ["a", "c"], "two at once")
	assert_eq(Array(picked["repair"]), [], "off")
	assert_eq(Array(picked["cone"]), [], "unnamed slots draw nothing until his pick")
	for slot: String in FeedbackLook.SLOTS + FeedbackLook.EXTRA_SLOTS:
		assert_eq(Array(FeedbackLook.parse("")[slot]), [], "%s is off with no flag" % slot)
