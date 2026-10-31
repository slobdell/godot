extends TestCase
## Mapkit P4 (round 47): the overpass, the lead's pick C (the monorail). A `monorail` prop is one pillar (hard cover) and
## the 10 m of beam it carries at 9 m; only the pillar collides, so a hull drives between pillars and under the beam.

const AT := [0.0, 24.0]


func _layout() -> Dictionary:
	var data: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	data["schema"] = 2
	data["obstacles"] = data["obstacles"].filter(func(o: Dictionary) -> bool:
			return not o.has("kit") and (absf(float(o["position"][1])) > 40.0 or absf(float(o["position"][0])) > 30.0))
	data["spawn_zones"] = {"green": {"center": [0.0, 102.0], "size": [150.0, 32.0]},
			"rust": {"center": [0.0, -102.0], "size": [150.0, 32.0]}}
	data["props"] = []
	# Three pillars 10 m apart along x (rotated 90: the beam runs along x), and their mirrors.
	for i in 3:
		var x := -10.0 + 10.0 * i
		data["props"].append({"type": "monorail", "position": [x, AT[1]], "rotation_deg": 90.0})
		data["props"].append({"type": "monorail", "position": [-x, -AT[1]], "rotation_deg": 270.0})
		data["props"].append({"type": "monorail_deck", "position": [x, AT[1]], "rotation_deg": 90.0, "car": i == 1})
		data["props"].append({"type": "monorail_deck", "position": [-x, -AT[1]], "rotation_deg": 270.0, "car": i == 1})
	return data


func test_the_pillar_is_hard_and_the_span_is_open() -> void:
	assert_eq(ArenaKit.cover_of("monorail"), "hard", "a pillar is hard cover")
	var arena := await ArenaFixture.build_layout(self, _layout())
	await wait_physics_frames(2)
	var space := arena.get_world_3d().direct_space_state
	var across := func(x: float, y: float, mask: int) -> bool:
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y, AT[1] + 8.0), Vector3(x, y, AT[1] - 8.0), mask)).is_empty()
	assert_true(not across.call(0.0, 1.3, Perception.eye_mask()), "a look through the pillar is blocked")
	assert_true(not across.call(0.0, 0.5, 3), "a hull meets the pillar")
	assert_true(across.call(5.0, 0.5, 3) and across.call(5.0, 6.5, 3), "between pillars, open up to above the tallest hull")
	var map := arena.get_world_3d().navigation_map
	var mid := Vector3(5.0, 0.0, AT[1])
	var closest := NavigationServer3D.map_get_closest_point(map, mid)
	assert_true(Vector2(closest.x, closest.z).distance_to(Vector2(mid.x, mid.z)) < 0.5, "navmesh between the pillars")


func test_a_rail_is_two_multimeshes_and_the_car_rides_on_its_span() -> void:
	var holder := Node3D.new()
	add_to_tree(holder)
	var scene := GameTheme.scene("prop.monorail")
	var deck_scene := GameTheme.scene("prop.monorail_deck")
	assert_true(scene != null and deck_scene != null, "prop.monorail and prop.monorail_deck are dressed")
	var decks: Array[Node3D] = []
	for i in 12:
		var pillar := scene.instantiate() as Node3D
		holder.add_child(pillar)
		pillar.global_position = Vector3(0.0, 0.0, -60.0 + 10.0 * i)
		pillar.call("setup", {"type": "monorail"})
		var deck := deck_scene.instantiate() as Node3D
		holder.add_child(deck)
		deck.global_position = pillar.global_position
		deck.call("setup", {"type": "monorail_deck", "car": i == 5})
		decks.append(deck)
	await wait_physics_frames(3)
	var yard := MapkitYard.for_node(holder)
	assert_eq(yard.count("monorail"), 12, "every span")
	var cars := holder.find_children("Car", "VisualSlot", true, false)
	assert_eq(cars.size(), 1, "one car: his Meshy car (prop.monorail_car) on the deck that asks for it")
	assert_eq((cars[0] as VisualSlot).slot, "prop.monorail_car", "through its slot")
	assert_true(GameTheme.slots.has("prop.monorail_car"), "the car is dressed")
	assert_eq(yard.count("monorail_beam"), 12, "a beam per pillar")
	assert_eq(yard.draws_of("monorail") + yard.draws_of("monorail_beam"), 2, "two MultiMeshes for the whole rail")
	var beam := MapkitYard.mesh_of("monorail_beam").get_aabb()
	assert_true(beam.position.y >= MapkitYard.BEAM_Y - 0.01, "the beam is up at %.1f m" % MapkitYard.BEAM_Y)
	# Camera's deck cutaway hides the deck's slot alone: its beam leaves the batch, the pillar stays.
	decks[0].visible = false
	await wait_physics_frames(2)
	assert_eq(yard.count("monorail_beam"), 11, "a hidden deck leaves the MultiMesh")
	assert_eq(yard.count("monorail"), 12, "its pillar does not")
	decks[0].visible = true
	await wait_physics_frames(2)
	assert_eq(yard.count("monorail_beam"), 12, "shown again, it is back")
	assert_true(ArenaKit.deck_y("monorail_deck") > 6.18 and not ArenaKit.collides("monorail_deck"),
			"the deck is overhead decoration (deck_y %.1f m)" % ArenaKit.deck_y("monorail_deck"))
	var lengths := yard._entries.values().filter(func(e: Array) -> bool: return e[0] == "monorail_beam").map(
			func(e: Array) -> float: return (e[1] as Transform3D).basis.z.length())
	assert_true(lengths.all(func(l: float) -> bool: return is_equal_approx(l, MapkitYard.SPAN)), "10 m of beam each by default")
