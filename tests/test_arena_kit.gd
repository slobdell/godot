extends TestCase
## Arena X1 (round 5, contract M2): layout schema v2. Layouts place the arena kit (`props`: stacked containers, ad
## screens, barricades, wrecks, floodlights, signs), size spawn zones for full armies, and annotate lanes and regions
## for the AI. Everything that collides stays point-symmetric; unknown kit types fail loudly.

const ARENA := preload("res://game/arena/arena.tscn")


## A small v2 layout on top of foundry: a two-high container pair, a screen pair, low barricades, a sign, lanes, regions.
func _v2() -> Dictionary:
	var data: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	data["schema"] = 2
	data["obstacles"] = data["obstacles"].filter(func(o: Dictionary) -> bool: return not o.has("kit"))
	data["props"] = [
		{"type": "container_40", "position": [30.0, 10.0], "rotation_deg": 90.0, "stack": 2, "faction": "law"},
		{"type": "container_40", "position": [-30.0, -10.0], "rotation_deg": 270.0, "stack": 2},
		{"type": "ad_screen", "position": [0.0, 40.0], "rotation_deg": 0.0, "channel": "arena"},
		{"type": "ad_screen", "position": [0.0, -40.0], "rotation_deg": 180.0, "channel": "sponsor"},
		{"type": "barricade", "position": [-50.0, 5.0], "rotation_deg": 0.0},
		{"type": "barricade", "position": [50.0, -5.0], "rotation_deg": 0.0},
		{"type": "sign", "position": [100.0, 100.0], "rotation_deg": 0.0},
	]
	data["spawn_zones"] = {"green": {"center": [0.0, 102.0], "size": [150.0, 32.0]},
			"rust": {"center": [0.0, -102.0], "size": [150.0, 32.0]}}
	data["lanes"] = [
		{"name": "centre", "points": [[0.0, 90.0], [0.0, -90.0]], "width": 20.0},
		{"name": "west", "points": [[-100.0, 90.0], [-100.0, -90.0]], "width": 16.0},
		{"name": "east", "points": [[100.0, 90.0], [100.0, -90.0]], "width": 16.0},
	]
	data["regions"] = [
		{"name": "middle", "kind": "centre", "position": [0.0, 0.0], "radius": 20.0},
		{"name": "west yard", "kind": "cover_cluster", "position": [-40.0, 20.0], "radius": 15.0},
		{"name": "east yard", "kind": "cover_cluster", "position": [40.0, -20.0], "radius": 15.0},
	]
	return data


func test_a_v2_layout_validates_and_normalizes_props_into_obstacles() -> void:
	var data := _v2()
	assert_eq(Arena.validate(data), "", "the fixture is a valid v2 layout")
	var runtime := Arena.normalize(data)
	var containers: Array = runtime["obstacles"].filter(func(o: Dictionary) -> bool: return o["type"] == "container_40")
	assert_eq(containers.size(), 2, "colliding props join the obstacle list every consumer already reads")
	assert_near(Arena.obstacle_size(containers[0]).y, 2.0 * 2.59, 0.01, "a two-high stack is two containers tall")
	assert_near(Arena.obstacle_size(containers[0]).x, 12.19, 0.01, "a 40 ft container is 12.19 m long")
	assert_true(not runtime["obstacles"].any(func(o: Dictionary) -> bool: return o["type"] == "sign"),
			"a sign is decoration: no collision, not an obstacle")
	assert_eq(runtime["props"].size(), 7, "the authored props stay for dressing")
	var legacy := Arena.normalize(Arena.load_layout("scrapyard")["layout"])
	assert_eq(legacy["obstacles"].size(), 36, "a v1 layout normalizes to itself")


func test_the_loader_is_honest_about_the_kit() -> void:
	var unknown := _v2()
	unknown["props"].append({"type": "hot_tub", "position": [0.0, 0.0]})
	var error := Arena.validate(unknown)
	assert_true(error.contains("hot_tub") and error.contains("container_20"), "an unknown prop names itself and the kit: %s" % error)
	var tall := _v2()
	tall["props"][0]["stack"] = 5
	tall["props"][1]["stack"] = 5
	assert_true(Arena.validate(tall).contains("stack"), "containers stack 1 to 3 high: %s" % Arena.validate(tall))
	var stacked_screen := _v2()
	stacked_screen["props"][2]["stack"] = 2
	stacked_screen["props"][3]["stack"] = 2
	assert_true(Arena.validate(stacked_screen).contains("stack"), "a screen doesn't stack: %s" % Arena.validate(stacked_screen))
	var resized := _v2()
	resized["props"][4]["size"] = [30.0, 3.0, 1.0]
	resized["props"][5]["size"] = [30.0, 3.0, 1.0]
	assert_true(Arena.validate(resized).contains("size"), "kit props are real objects with fixed sizes: %s" % Arena.validate(resized))
	var legacy_kit := _v2()
	legacy_kit["obstacles"].append({"type": "container_20", "position": [0.0, 0.0]})
	assert_true(Arena.validate(legacy_kit).contains("props"), "a kit type under obstacles points at props: %s" % Arena.validate(legacy_kit))


func test_colliding_props_must_be_point_symmetric_and_decoration_needn_t_be() -> void:
	var uneven := _v2()
	uneven["props"][1]["stack"] = 1
	assert_true(Arena.validate(uneven).contains("point-symmetric"), "a mirror one container shorter is unfair: %s" % Arena.validate(uneven))
	var moved := _v2()
	moved["props"][4]["position"] = [-52.0, 5.0]
	assert_true(Arena.validate(moved).contains("point-symmetric"), "so is a moved barricade")
	var looks := _v2()
	looks["props"][1]["faction"] = "gangs"
	assert_eq(Arena.validate(looks), "", "paint and faction are cosmetic: mirrors may differ")
	assert_eq(_v2()["props"].filter(func(p: Dictionary) -> bool: return p["type"] == "sign").size(), 1, "the fixture's one sign has no mirror, and that's fine")


func test_spawns_live_in_their_zone_clear_of_cover() -> void:
	var outside := _v2()
	outside["spawn_zones"]["green"]["size"] = [40.0, 32.0]
	outside["spawn_zones"]["rust"]["size"] = [40.0, 32.0]
	assert_true(Arena.validate(outside).contains("zone"), "every spawn sits inside its side's zone: %s" % Arena.validate(outside))
	var lopsided := _v2()
	lopsided["spawn_zones"]["rust"]["center"] = [0.0, -90.0]
	assert_true(Arena.validate(lopsided).contains("point-symmetric"), "zones mirror each other: %s" % Arena.validate(lopsided))
	var buried := _v2()
	buried["props"].append({"type": "container_20", "position": [11.0, 98.0], "rotation_deg": 0.0})
	buried["props"].append({"type": "container_20", "position": [-11.0, -98.0], "rotation_deg": 0.0})
	var error := Arena.validate(buried)
	assert_true(error.contains("spawn") and error.contains("container_20"), "a vehicle can't spawn inside a container: %s" % error)
	var legacy_missing := _v2()
	legacy_missing.erase("spawn_zones")
	assert_true(Arena.validate(legacy_missing).contains("spawn_zones"), "schema 2 requires spawn zones")


func test_lanes_and_regions_mirror_and_use_known_kinds() -> void:
	var one_sided := _v2()
	one_sided["lanes"].remove_at(2)
	assert_true(Arena.validate(one_sided).contains("lane"), "a west lane needs an east twin: %s" % Arena.validate(one_sided))
	var bad_kind := _v2()
	bad_kind["regions"][0]["kind"] = "vibes"
	assert_true(Arena.validate(bad_kind).contains("vibes"), "region kinds are a fixed vocabulary: %s" % Arena.validate(bad_kind))
	var lonely := _v2()
	lonely["regions"].remove_at(2)
	assert_true(Arena.validate(lonely).contains("region"), "a cover cluster needs its mirror")
	var data := _v2()
	var lanes := Arena.lanes_of(data)
	assert_eq(lanes.size(), 3, "three lanes")
	assert_eq(lanes[1]["points"][0], Vector3(-100, 0, 90), "lane points are world positions, green end first")
	assert_eq(Arena.regions_of(data, "cover_cluster").size(), 2, "regions filter by kind")
	var zone := Arena.spawn_zone_of(data, true)
	assert_eq(zone["center"], Vector3(0, 0, 102), "green's zone centre")
	assert_eq(zone["size"], Vector2(150, 32), "and its size")


func test_the_arena_builds_kit_collision_that_behaves_like_the_object() -> void:
	var path := "user://test_arena_kit_v2.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_v2()))
	file.close()
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = path
	add_to_tree(arena)
	for frame in 60:
		if Pathing.is_ready(arena):
			break
		await tree.physics_frame
	assert_eq(arena.layout.get("schema"), 2, "the arena loaded the v2 layout, not the fallback")
	var space := arena.get_world_3d().direct_space_state
	var ray := func(from: Vector3, to: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Perception.WORLD_MASK)).is_empty()
	assert_true(ray.call(Vector3(20, 1.3, 10), Vector3(40, 1.3, 10)), "a container stack blocks eye-level sight")
	assert_true(ray.call(Vector3(20, 4.5, 10), Vector3(40, 4.5, 10)), "two high still blocks at 4.5 m")
	assert_true(not ray.call(Vector3(-50, 1.3, 0), Vector3(-50, 1.3, 10)), "a barricade is low: eyes and guns see over it")
	assert_true(ray.call(Vector3(-50, 0.5, 0), Vector3(-50, 0.5, 10)), "but it stops a hull")
	var features := arena.cover_features()
	var barricade: Dictionary = features.filter(func(f: Dictionary) -> bool: return f["type"] == "barricade")[0]
	assert_eq(barricade["cover"], "low", "the AI is told a barricade is low cover")
	assert_true(not barricade["blocks_sight"], "that doesn't block sight")
	var stack: Dictionary = features.filter(func(f: Dictionary) -> bool: return f["type"] == "container_40")[0]
	assert_eq(stack["stack"], 2, "and how high a stack is")
	assert_true(stack["blocks_sight"], "which does")
	assert_true(not features.any(func(f: Dictionary) -> bool: return f["type"] == "sign"), "a sign is not cover")
	assert_eq(arena.get_node("Decor").get_child_count(), 1, "the sign is built as decoration")
	DirAccess.remove_absolute(path)


func test_every_shipped_layout_connects_both_bases_and_the_centre() -> void:
	for layout_name in Arena.layout_names():
		# ArenaFixture, not a bare Pathing.is_ready() poll: the previous layout's regions outlive its node by a frame
		# or two, so is_ready() returns true against the PREVIOUS arena's map and this test then proves that one is
		# connected, once per layout. It never failed, which is exactly why it needed changing (round 6).
		var arena := await ArenaFixture.build(self, layout_name)
		var green: Vector3 = Arena.spawn_spot(true, 0)
		var rust: Vector3 = Arena.spawn_spot(false, 0)
		# What the match is FOUGHT OVER must be reachable: every objective the layout declares, which is the centre
		# only when it declares none (`Arena.objectives_of`). Round 10 (terrain): the Crossing's centre is a river
		# and the Pits' a pump house, and a centre nobody fights over has no reason to be reachable.
		var goals: Array = [[rust, 4.0]]
		for objective: Dictionary in Arena.objectives_of(Arena.load_layout(layout_name)["layout"]):
			goals.append([objective["position"], 12.0])
		for goal: Array in goals:
			var route := Pathing.find_path(arena, green, goal[0])
			assert_true(route.size() >= 2 and route[route.size() - 1].distance_to(goal[0]) < goal[1],
					"%s: green's base reaches %s" % [layout_name, goal[0]])
		arena.queue_free()
		await tree.process_frame


func test_random_picks_a_proven_arena_the_same_way_for_the_same_seed() -> void:
	assert_true(not Arena.ROTATION.is_empty(), "there is a rotation")
	for layout_name in Arena.ROTATION:
		assert_true(Arena.load_layout(layout_name).has("layout"), "rotation arena %s loads" % layout_name)
	var seen := {}
	for seed_value in 40:
		var picked := Arena.resolve_name("random", seed_value)
		assert_true(picked in Arena.ROTATION, "random picks from the rotation (%s)" % picked)
		assert_eq(Arena.resolve_name("random", seed_value), picked, "the same seed picks the same arena")
		seen[picked] = true
	assert_eq(seen.size(), Arena.ROTATION.size(), "40 seeds visit every arena in the rotation")
	assert_eq(Arena.resolve_name("yard", 3), "yard", "a named arena is itself")


## The lead's verdict, as a test rather than as prose. `_agents/game_design.md` *The lead's arena verdict*
## (2026-09-19): Pit KEEP, Yard KEEP, Boulevard CUT, Foundry CUT, Boneyard CUT, Scrapyard CUT — recorded from the
## review page's store and confirmed in words.
##
## **This test exists because that verdict sat in a document for a full round while `--arena=random` kept dealing
## him boulevard and boneyard.** `make skirmish` passes `--arena=random`; random reads `Arena.ROTATION`; the
## rotation read the old list. Half of every skirmish he played was a map he had already cut, and nothing failed,
## because nothing was asking. A decision that lives only in prose is a decision the game does not have.
##
## **And then it failed to catch the second instance of the same bug (round 11).** It asserted only that the CUT
## maps were absent and the kept ones present — it never asked whether the maps BUILT SINCE were present. Round
## 10's terrain stream built the Crossing (a river and two bridges) and the Sumps (the only real pits in the game),
## exactly what he had asked for twice, and neither was reachable from the picker or from `--arena=random` for a
## whole round: *"we still barely have any maps, I haven't seen any bridges or pits"*. So the test below is the
## generalisation: EVERY layout in `arenas/` must be accounted for — a fixture (`"fixture": true`, never dealt),
## CUT by his verdict (`Arena.CUT`), or in the rotation. A map someone builds and forgets to publish fails here
## the day it lands, whatever it is called.
func test_random_deals_only_the_maps_the_lead_kept() -> void:
	for cut: String in Arena.CUT:
		assert_true(not Arena.ROTATION.has(cut),
				"%s was CUT (game_design.md, the lead's arena verdict) and --arena=random must never deal it" % cut)
	# yard and pit: his verdict of 2026-09-19. crossing and sumps: KEPT on arena's round-11 review page (2026-09-24),
	# the river and the pits he had asked for three times. locks: "deal it", the same page, with its name recorded.
	for kept in ["yard", "pit", "crossing", "sumps", "locks"]:
		assert_true(Arena.ROTATION.has(kept), "%s was KEPT and --arena=random must be able to deal it" % kept)
	# terminus is still in the rotation without a verdict of his (the cityscape, round 8). Listed explicitly so that
	# when he does rule, whoever acts on it can see exactly which line to change.
	for pending in ["terminus"]:
		assert_true(Arena.ROTATION.has(pending), "%s is in the rotation, pending the lead's verdict" % pending)
	# A fixture is not a map he plays: barriers and maze are instruments, reachable only by name.
	for fixture in ["maze", "barriers"]:
		assert_true(not Arena.ROTATION.has(fixture), "%s is a fixture, not a map in the rotation" % fixture)


## The generalisation (round 11): no layout is unaccounted for. Every file in `arenas/` is exactly one of a fixture,
## a map he cut, or a map in the rotation. A new non-fixture map that is not in `Arena.ROTATION` fails HERE, named.
func test_every_built_map_is_dealt_cut_or_a_fixture() -> void:
	var names := Arena.layout_names()
	assert_true(names.size() >= 10, "the layout directory was read (%d layouts)" % names.size())
	for name: String in names:
		var loaded := Arena.load_layout(name)
		assert_true(not loaded.has("error"), "%s loads (%s)" % [name, loaded.get("error", "")])
		var fixture := bool(loaded.get("layout", {}).get("fixture", false))
		var cut := Arena.CUT.has(name)
		var dealt := Arena.ROTATION.has(name)
		if fixture:
			assert_true(not dealt and not cut, "%s is a fixture: never dealt, never on the cut list" % name)
		else:
			assert_true(dealt != cut, ("%s is a map (not a fixture) and must be EITHER in Arena.ROTATION (the picker "
					+ "and --arena=random deal it) OR in Arena.CUT (the lead rejected it). dealt=%s cut=%s. A map that is "
					+ "neither is a map he asked for and has never seen.") % [name, dealt, cut])
	for name: String in Arena.ROTATION + Arena.CUT:
		assert_true(names.has(name), "%s is named in the rotation or the cut list and exists in arenas/" % name)


## Every map he can be dealt says what it is in the picker (faction_picker draws both), and a map with terrain names
## it in the note: the note is the only place he is told there is a river or a pit before the match starts.
func test_every_dealt_map_has_a_title_and_a_note_that_names_its_terrain() -> void:
	var words := {"water": ["river", "water", "canal"], "bridge": ["bridge", "causeway"], "pit": ["pit"]}
	for name: String in Arena.ROTATION:
		var layout: Dictionary = Arena.load_layout(name)["layout"]
		var note := String(layout.get("note", "")).to_lower()
		assert_true(String(layout.get("title", "")) != "", "%s has a title" % name)
		assert_true(note.length() > 40, "%s has a note that says what the fight is about" % name)
		for piece: Dictionary in layout.get("terrain", []):
			var kind := String(piece.get("kind", ""))
			var said := false
			for word: String in words.get(kind, [kind]):
				said = said or note.contains(word)
			assert_true(said, "%s has %s terrain and its note never says so (%s)" % [name, kind, words.get(kind, [kind])])


func test_a_random_arena_records_the_arena_it_built_and_unknown_names_stay_loud() -> void:
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "random"
	add_to_tree(arena)
	assert_true(String(Arena.active.get("name", "")) in Arena.ROTATION,
			"Arena.active names the arena actually built, never 'random' (%s)" % Arena.active.get("name", ""))
	assert_eq(arena.layout.get("name"), Arena.active.get("name"), "and the arena agrees")
	assert_true(String(Arena.load_layout("random").get("error", "")).contains("no arena layout"),
			"'random' is not a layout: only resolve_name understands it, the loader still refuses unknown names")
