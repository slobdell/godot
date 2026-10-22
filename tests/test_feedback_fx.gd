extends TestCase
## Round 37 (feedback, C37.6): FeedbackFx draws his picked looks from the match's own events and state -- a hit's ring
## segment by the face struck (never an artillery round from above), the Tanker's mending beam, the Emitter's shimmering
## cone -- and keeps the facts (pinned, mending) for the chevrons, the radar and the card; FeedbackLook turns each off.

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


func test_hits_light_the_struck_side_and_artillery_never_reads_as_a_flank() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var target: Tank = (world[1] as Match).spawn_tank("Target", 0, Match.Team.RUST, "tank")
	target.global_position = FIELD
	fx.feedback.fired(_shot(1, FIELD + Vector3(0, 1, 30)), 1.0)
	fx.feedback.impact(_hit(1, "Target", "rear"), 1.0)
	assert_eq(int(fx.feedback.hits_drawn.get("rear", 0)), 1, "his pick is on by default: a rear hit lights a segment")
	assert_eq(String(fx.feedback.last_segment.get("kind")), "rear", "lit in the rear's colour")
	assert_true((fx.feedback.last_segment["toward"] as Vector3).dot(Vector3.BACK) > 0.99, "toward where the shot came from")
	fx.feedback.fired(_shot(2, FIELD + Vector3(30, 20, 0), "arc"), 2.0)
	fx.feedback.impact(_hit(2, "Target", "side"), 2.0)
	assert_eq(int(fx.feedback.hits_drawn.get("side", 0)), 0, "a shell from above has no flank: nothing drawn")
	fx.feedback.impact(_hit(3, "Target", "side", true), 3.0)
	assert_eq(int(fx.feedback.hits_drawn.get("deck", 0)), 0, "the engine deck keeps its own gold flare (WeaponFx), no segment")


func test_a_mending_tanker_and_a_blowing_emitter_are_drawn_while_true() -> void:
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
	assert_eq(fx.feedback.pinned_of(&"Pinned"), 1.0, "pinned hard (UnitBars draws the chevrons)")
	assert_eq(int(counts.get("beams", 0)), 1, "one mending beam, Tanker to patient")
	assert_eq(fx.feedback.mending_of(&"Patient").get("node"), tanker, "the card knows who mends it")
	assert_eq(int(counts.get("cones", 0)), 1, "the Emitter's cone shimmers in the air")
	assert_eq(fx.feedback.mending_points.keys(), ["Patient"], "and the workshop sounds at the patient")
	fx.repair_hum.update(Vector3.ZERO, fx.feedback.mending_points)
	assert_eq(fx.repair_hum.active_count(), 1, "one repair voice while it mends")
	pinned.suppression = 0.1
	patient.health = patient.max_health
	fx.now += 1.0
	fx.feedback.update(fx.now)
	counts = fx.feedback.last_counts
	assert_eq(int(counts.get("beams", 0)) + int(counts.get("cones", 0)), 0, "mended and the horns quiet: nothing drawn")
	fx.repair_hum.update(Vector3.ZERO, fx.feedback.mending_points)
	assert_eq(fx.repair_hum.active_count(), 0, "and the workshop stops with the beam")
	assert_eq(fx.feedback.pinned_of(&"Pinned"), 0.0, "and recovered")


func test_a_flank_or_rear_round_is_heard_once_per_target_and_a_stream_never() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var target: Tank = (world[1] as Match).spawn_tank("Target", 0, Match.Team.RUST, "tank")
	target.global_position = FIELD
	var heard := func(sound: String) -> int: return int(fx.sfx.plays.get(sound, 0))
	fx.feedback.fired(_shot(1, FIELD + Vector3(30, 1, 0)), 1.0)
	fx.feedback.impact(_hit(1, "Target", "side"), 1.0)
	assert_eq(heard.call("flank_hit"), 1, "a shell in the side: his flank sound")
	fx.feedback.fired(_shot(2, FIELD + Vector3(0, 1, 30)), 1.1)
	fx.feedback.impact(_hit(2, "Target", "rear"), 1.1)
	assert_eq(heard.call("rear_hit"), 0, "the same crew again within HIT_SOUND_EVERY_S: once is enough")
	fx.feedback.fired(_shot(3, FIELD + Vector3(0, 1, 30)), 1.0 + FeedbackFx.HIT_SOUND_EVERY_S + 0.1)
	fx.feedback.impact(_hit(3, "Target", "rear"), 1.0 + FeedbackFx.HIT_SOUND_EVERY_S + 0.1)
	assert_eq(heard.call("rear_hit"), 1, "later, a rear hit: his rear sound")
	fx.feedback.fired(_shot(4, FIELD + Vector3(30, 1, 0), "stream"), 5.0)
	fx.feedback.impact(_hit(4, "Target", "side"), 5.0)
	assert_eq(heard.call("flank_hit"), 1, "a machine gun's stream in the side is not a flank shot: silent")
	fx.feedback.impact(_hit(5, "Target", "front"), 9.0)
	assert_eq(heard.call("flank_hit") + heard.call("rear_hit"), 2, "and the front makes none")


func test_a_look_that_is_off_draws_nothing() -> void:
	FeedbackLook.use("pinned:off,repair:off,cone:off,hit:off")
	var world := _world()
	var fx: FxWorld = world[0]
	var game_match: Match = world[1]
	var tanker := game_match.spawn_tank("Tanker", 0, Match.Team.GREEN, "gang_support")
	var patient := game_match.spawn_tank("Patient", 1, Match.Team.GREEN, "gang_tank")
	tanker.global_position = FIELD
	patient.global_position = FIELD + Vector3(10, 0, 0)
	patient.health = patient.max_health / 2
	patient.ticks_since_hit = 1_000_000
	patient.suppression = 1.0
	fx.feedback.fired(_shot(1, FIELD + Vector3(0, 1, 30)), 1.0)
	fx.feedback.impact(_hit(1, "Patient", "rear"), 1.0)
	fx.feedback.fired({"shooter": "Tanker", "weapon": "sonic_emitter", "muzzle": [FIELD.x, 1.0, FIELD.z],
			"direction": [0.0, 0.0, -1.0], "projectile_id": 9}, fx.now)
	fx.feedback.update(fx.now)
	assert_true(fx.feedback.hits_drawn.is_empty(), "no segment")
	assert_eq(fx.feedback.last_counts, {"beams": 0, "cones": 0}, "no beam, no cone")
	assert_eq(fx.feedback.pinned_of(&"Patient"), 1.0, "but the facts are still read, for the radar and the card")


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


func test_his_picks_are_on_by_default_and_the_flag_turns_any_off() -> void:
	var picked := FeedbackLook.parse("")
	for slot: String in ["hit", "pinned", "repair", "cone"]:
		assert_true(bool(picked[slot]), "%s: his pick, on" % slot)
	assert_true(not bool(picked["marks"]), "the radar ring and the card words were not on his page: off")
	picked = FeedbackLook.parse("hit:off,marks:on")
	assert_true(not bool(picked["hit"]), "off")
	assert_true(bool(picked["marks"]), "on")
	assert_true(bool(picked["cone"]), "unnamed: the default stands")
