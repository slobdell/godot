extends TestCase
## Round 39 (feedback F1, C39.5, his rule "never hide an enemy inside a range the player was shown"): with R1 ON a crew's
## sight shrinks from ~110 % to ~85 % within a second of driving off. The fog of war is the range he is shown, so the lit
## ground must never reach past what his crews really see: an enemy standing on lit ground is drawn.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

## Open ground in the default arena (tests/rules/test_rules_sight.gd's lane).
const LANE_X := -100.0


func teardown() -> void:
	RuleSwitches.sight_on = RuleSwitches._on("sight")
	super.teardown()


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	return game_match


## Standard tanks, no brains. Green_A_1 halts at z = -40 facing +Z; one Rust tank parks `behind` metres behind it. With
## `army` > 1 the rest of Green parks out of sight across the map, so the fog cycles through a whole army's looks.
func _pair(game_match: Match, behind: float, army := 1) -> Array:
	var one := {"name": "T", "squads": [{"name": "A", "units": [{"unit": "tank"}]}]}
	var squads: Array = []
	for s in ceili(army / 5.0):
		var units: Array = []
		for u in mini(5, army - s * 5):
			units.append({"unit": "tank"})
		squads.append({"name": "ABCDE"[s], "units": units})
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": squads}), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, one), "", "rust loads")
	var viewer := game_match.tanks.get_node("Green_A_1") as Tank
	var enemy := game_match.tanks.get_node("Rust_A_1") as Tank
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	viewer.global_position = Vector3(LANE_X, 0.0, -40.0)
	viewer.rotation.y = PI  # forward is -Z: this faces +Z, away from the enemy
	enemy.global_position = Vector3(LANE_X, 0.0, -40.0 - behind)
	enemy.rotation.y = 0.0
	_park_spares(game_match, viewer)
	return [viewer, enemy]


func _park_spares(game_match: Match, viewer: Tank) -> void:
	var spare := 0
	for tank in game_match.sorted_team_tanks(Match.Team.GREEN):
		if tank != viewer:
			tank.global_position = Vector3(90.0 + 8.0 * (spare % 5), 0.0, -60.0 + 12.0 * (spare / 5))
			tank.velocity = Vector3.ZERO
			tank.command = TankCommand.new()
			spare += 1


func _field(game_match: Match) -> VisibilityField:
	var field := VisibilityField.new()
	field.game_match = game_match
	field.team = Match.Team.GREEN
	game_match.add_child(field)
	return field


func _drive(pair: Array, throttle: float) -> void:
	for tank in (pair[0] as Tank).get_parent().get_children():
		(tank as Tank).command = TankCommand.new()
	(pair[0] as Tank).command = TankCommand.new(throttle, 0.0, (pair[0] as Tank).global_position + Vector3(0, 0, 50), false)
	(pair[1] as Tank).command = TankCommand.new()
	await wait_physics_frames(1)


## Ticks on which the drawn fog lights the enemy's ground while the enemy is hidden, and the worst overshoot in metres:
## `shown` is what the fog draws (FogViewers.shown, the shader's clip), `field` the field's picture alone (before round 39).
func _lies_while_driving(game_match: Match, field: VisibilityField, pair: Array, ticks: int) -> Dictionary:
	var viewer: Tank = pair[0]
	var enemy: Tank = pair[1]
	var out := {"shown": 0, "shown_worst": 0.0, "field": 0, "field_worst": 0.0}
	for tick in ticks:
		await _drive(pair, 1.0)
		if game_match.is_visible_to(Match.Team.GREEN, enemy):
			continue
		var cell := field.world_to_cell(enemy.global_position)
		var v := field.image.get_pixel(cell.x, cell.y).r8 / 255.0
		var past := viewer.global_position.distance_to(enemy.global_position) - viewer.sight_radius
		var viewers := FogViewers.pack(field)
		var at := Vector2(enemy.global_position.x, enemy.global_position.z)
		for key: String in ["field", "shown"]:
			var drawn := v if key == "field" else FogViewers.shown(v, at, viewers, viewers.size())
			if drawn > 0.5:  # the shader starts clearing the fog above 0.5 (`lit`)
				out[key] += 1
				out[key + "_worst"] = maxf(out[key + "_worst"], past)
	return out


## Drive-offs from every point of the fog's refresh cycle: {lies, worst, phases}.
func _measure(army: int, sight_on: bool) -> Dictionary:
	RuleSwitches.sight_on = sight_on
	var game_match := _setup()
	var calm := float(Units.stat("tank", "sight_radius"))
	# Inside the stopped crew's ~110 %, outside its driving ~85 %: seen while parked, lost on the move. OFF, just
	# inside its radius: lost as soon as it pulls away.
	var behind := calm * (0.97 if sight_on else 0.93)
	var pair: Array = await _pair(game_match, behind, army)
	var viewer: Tank = pair[0]
	var field := _field(game_match)
	var total := {"shown": 0, "shown_worst": 0.0, "field": 0, "field_worst": 0.0}
	var phases := 0
	var cycle := maxi(VisibilityField.REFRESH_TICKS, army)
	for phase in range(0, cycle, 3):
		viewer.global_position = Vector3(LANE_X, 0.0, -40.0)
		viewer.velocity = Vector3.ZERO
		_park_spares(game_match, viewer)
		for tick in SimClock.TICK_RATE * 4 + phase:
			await _drive(pair, 0.0)
		assert_true(game_match.is_visible_to(Match.Team.GREEN, pair[1]), "setup: the parked crew sees the enemy behind it")
		var result: Dictionary = await _lies_while_driving(game_match, field, pair, SimClock.TICK_RATE * 2)
		assert_true(not game_match.is_visible_to(Match.Team.GREEN, pair[1]), "setup: driving away, it loses the enemy")
		for key: String in ["field", "shown"]:
			total[key] += int(result[key])
			total[key + "_worst"] = maxf(total[key + "_worst"], float(result[key + "_worst"]))
		phases += 1
	(game_match.get_meta("arena") as Node).queue_free()
	game_match.queue_free()
	await wait_physics_frames(2)
	total["phases"] = phases
	return total


func test_a_crew_driving_off_never_leaves_lit_ground_over_a_hidden_enemy() -> void:
	for army in [1, 25]:
		for sight_on in [true, false]:
			var result: Dictionary = await _measure(army, sight_on)
			var label := "army %d, R1 %s" % [army, "ON" if sight_on else "OFF"]
			print("SIGHT_SHOWN %s: field alone lit over a hidden enemy on %d ticks over %d drive-offs (worst %.1f m)"
					% [label, result["field"], result["phases"], result["field_worst"]])
			assert_eq(int(result["shown"]), 0, "%s: the drawn fog lit over a hidden enemy on %d ticks over %d drive-offs (worst %.1f m past its real sight)"
					% [label, result["shown"], result["phases"], result["shown_worst"]])


func test_the_clip_never_darkens_ground_a_crew_sees() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match, 30.0)
	var field := _field(game_match)
	for tick in SimClock.TICK_RATE * 4:
		await _drive(pair, 0.0)
	field.refresh_all()
	var viewers := FogViewers.pack(field)
	var viewer: Tank = pair[0]
	var lit_cells := 0
	var darkened := 0
	for dx in range(-80, 81, 2):
		for dz in range(-80, 81, 2):
			var at := Vector3(viewer.global_position.x + dx, 0.0, viewer.global_position.z + dz)
			var cell := field.world_to_cell(at)
			if cell.x < 0 or cell.y < 0 or cell.x >= field.cells or cell.y >= field.cells:
				continue
			var v := field.image.get_pixel(cell.x, cell.y).r8 / 255.0
			if v < 0.99 or Vector2(dx, dz).length() > viewer.sight_radius - FogViewers.SOFT_M - VisibilityField.CELL_SIZE:
				continue
			lit_cells += 1
			if FogViewers.shown(v, Vector2(at.x, at.z), viewers, viewers.size()) < v:
				darkened += 1
	assert_true(lit_cells > 500, "setup: a parked crew lights a wide circle (%d cells)" % lit_cells)
	assert_eq(darkened, 0, "ground inside a crew's current sight stays exactly as the field draws it")
	assert_near(FogViewers.shown(0.0, Vector2.ZERO, viewers, viewers.size()), 0.0, 0.0001, "never-seen ground stays never-seen")
	assert_near(FogViewers.shown(FogViewers.SEEN_V, Vector2(500, 500), viewers, viewers.size()), FogViewers.SEEN_V, 0.0001,
			"remembered ground stays remembered")
	assert_near(FogViewers.shown(1.0, Vector2(500, 500), viewers, -1), 1.0, 0.0001, "count -1: no clip, the field alone")


func test_the_fog_sheet_hands_its_shader_the_live_crews() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match, 30.0, 7)
	var field := _field(game_match)
	for scene_path in ["res://game/theme/cyberpunk/fx_fog_of_war.tscn", "res://game/theme/default/fx_fog_of_war.tscn"]:
		var sheet := (load(scene_path) as PackedScene).instantiate() as MeshInstance3D
		add_to_tree(sheet)
		sheet.call("setup", {"texture": field.texture, "origin": field.origin, "size": field.cells * VisibilityField.CELL_SIZE})
		await wait_physics_frames(3)
		var material := sheet.material_override as ShaderMaterial
		assert_eq(int(material.get_shader_parameter("viewer_count")), 7, "%s: seven living crews reach the shader" % scene_path)
		var first: Vector4 = (material.get_shader_parameter("viewers") as PackedVector4Array)[0]
		var crew: Tank = game_match.sorted_team_tanks(Match.Team.GREEN)[0]
		assert_near(first.z, crew.sight_radius, 0.01, "%s: with each crew's sight radius as it is now" % scene_path)
		assert_eq(material.get_shader_parameter("origin_m"), field.origin, "%s: and where the sheet's corner is" % scene_path)
		sheet.queue_free()


func test_the_radar_clips_its_fog_the_same_way() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match, 30.0, 3)
	var field := _field(game_match)
	var radar := Radar.new()
	radar.game_match = game_match
	radar.visibility = field
	add_to_tree(radar)
	await wait_physics_frames(3)
	var fog := radar.get_node("Backdrop/Fog") as Control
	assert_true(fog != null and fog.material is ShaderMaterial, "the radar's fog has its own layer and clip shader")
	var material := fog.material as ShaderMaterial
	assert_eq(int(material.get_shader_parameter("viewer_count")), 3, "three living crews reach the radar's shader")
	(pair[0] as Tank).health = 0
	(pair[0] as Tank).alive = false
	await wait_physics_frames(2)
	assert_eq(int(material.get_shader_parameter("viewer_count")), 2, "a dead crew's circle goes at once")
