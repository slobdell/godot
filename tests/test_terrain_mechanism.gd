extends TestCase
## The water/pit/bridge mechanism as the terrain stream ships it (round 10). arena's `test_arena_terrain.gd` pins the
## round-7 claims (carve, rim, fire over); these pin what the first real maps needed on top of them:
##   - a rim is cut only by a deck that actually crosses THAT edge. Round 7 cut an edge wherever any deck overlapped
##     its axis, so on a map with two rivers (or a river and its mirror) the second one had a gap in its rim where no
##     bridge is: a hull could drive into the water there;
##   - a deck has RAILS along every side that borders water. Round 7 had none, so a hull shoved sideways on a bridge
##     left the deck and ended up in the pan for the rest of the match;
##   - rims and rails are in the navmesh bake (R3: what a hull cannot drive through has a collider AND sits in the
##     bake), so a route stops an agent radius short of them instead of scraping along them;
##   - a deck is a LANE under R4: wide enough that the widest hull keeps two hull widths of drivable deck after the
##     bake radius and the rails.

const ARENA := preload("res://game/arena/arena.tscn")
## A river across the south half and its mirror, each with one bridge at a DIFFERENT x (the mirror's is at -x).
const RIVER := {"kind": "water", "name": "river", "rect": [0.0, 40.0, 320.0, 24.0]}
const RIVER_FAR := {"kind": "water", "name": "river (far)", "rect": [0.0, -40.0, 320.0, 24.0]}
const BRIDGE := {"kind": "bridge", "name": "bridge", "rect": [50.0, 40.0, 14.0, 30.0]}
const BRIDGE_FAR := {"kind": "bridge", "name": "bridge (far)", "rect": [-50.0, -40.0, 14.0, 30.0]}


func _layout(terrain: Array) -> Dictionary:
	var layout: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	layout["terrain"] = terrain
	return layout


## Does any box in `slabs` ([cx, cz, w, d]) cover the point?
func _covers(slabs: Array, x: float, z: float) -> bool:
	for slab: Array in slabs:
		if absf(x - float(slab[0])) <= float(slab[2]) / 2.0 and absf(z - float(slab[1])) <= float(slab[3]) / 2.0:
			return true
	return false


func test_a_rim_is_cut_only_where_a_deck_crosses_it() -> void:
	var terrain := [RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]
	var rim := ArenaTerrain.rim_slabs(RIVER, terrain)
	var north_bank := 40.0 - 12.0 - ArenaTerrain.RIM_THICKNESS / 2.0
	var south_bank := 40.0 + 12.0 + ArenaTerrain.RIM_THICKNESS / 2.0
	assert_true(not _covers(rim, 50.0, north_bank), "the river's own bridge cuts its north rim")
	assert_true(not _covers(rim, 50.0, south_bank), "and its south rim")
	# The far river's bridge sits at x = -50. Round 7 cut THIS river's rim there too, because the cut only asked
	# whether a deck overlapped the edge along x -- and left a gap onto open water.
	assert_true(_covers(rim, -50.0, north_bank), "the far river's bridge does NOT cut this river's rim (a gap onto water)")
	assert_true(_covers(rim, -50.0, south_bank), "on either bank")
	var far_rim := ArenaTerrain.rim_slabs(RIVER_FAR, terrain)
	assert_true(not _covers(far_rim, -50.0, -north_bank), "the far river is cut at its own bridge")
	assert_true(_covers(far_rim, 50.0, -north_bank), "and sealed where this one's bridge is")


func test_a_deck_has_rails_where_it_borders_water_and_none_where_it_meets_the_bank() -> void:
	var terrain := [RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]
	var rails := ArenaTerrain.rail_slabs(BRIDGE, terrain)
	assert_true(not rails.is_empty(), "a deck over water has rails")
	var west := 50.0 - 7.0 + ArenaTerrain.RAIL_THICKNESS / 2.0
	var east := 50.0 + 7.0 - ArenaTerrain.RAIL_THICKNESS / 2.0
	assert_true(_covers(rails, west, 40.0) and _covers(rails, east, 40.0), "on both sides, mid-river")
	# The rail must meet the rim, or a hull slips between the rim's cut end and the start of the rail.
	assert_true(_covers(rails, west, 40.0 + 12.0 + ArenaTerrain.RIM_THICKNESS / 2.0),
			"and run on past the bank line far enough to close the gap the rim's cut leaves")
	assert_true(not _covers(rails, 50.0, 40.0), "but not across the deck: the roadway is clear")
	assert_true(not _covers(rails, 50.0, 40.0 + 14.9), "nor across the deck's end on the bank, where it meets floor")
	for rail: Array in rails:
		var inside := absf(float(rail[0]) - 50.0) + float(rail[2]) / 2.0 <= 7.0 + 0.01
		assert_true(inside, "every rail stands ON the deck, not over the water beside it (%s)" % [rail])


func test_a_rail_stops_a_hull_and_not_a_shot() -> void:
	assert_true(ArenaTerrain.RAIL_HEIGHT < Perception.EYE_HEIGHT,
			"a rail (%.2f m) is below the eye line (%.2f m): a bridge is a sightline, not a wall"
			% [ArenaTerrain.RAIL_HEIGHT, Perception.EYE_HEIGHT])
	assert_true(ArenaTerrain.RAIL_HEIGHT >= ArenaTerrain.RIM_HEIGHT, "and at least as tall as the rim it continues")


## R4: every lane keeps 2 x the widest hull's width drivable after the bake radius. A bridge deck is a lane, and it
## also loses its two rails. READ from the catalog and the navmesh, not copied: the bus is being widened this round
## (CP3), and a copied 3.32 would keep passing while the real bus stopped fitting.
func test_the_narrowest_legal_deck_is_a_lane_for_the_widest_hull() -> void:
	var widest := 0.0
	var widest_id := ""
	for id: String in Units.PROFILES:
		var width := float(Units.PROFILES[id]["hull_size"][0])
		if width > widest:
			widest = width
			widest_id = id
	var arena: Arena = ARENA.instantiate()
	var nav := arena.get_node("Navigation") as NavigationRegion3D
	var radius := nav.navigation_mesh.agent_radius
	arena.free()
	var needed := 2.0 * widest + 2.0 * radius + 2.0 * ArenaTerrain.RAIL_THICKNESS
	assert_true(ArenaTerrain.min_deck_m() >= needed - 0.01,
			"min_deck_m() %.2f m covers two %s widths (%.2f m) + the %.1f m bake radius twice + two %.2f m rails = %.2f m"
			% [ArenaTerrain.min_deck_m(), widest_id, 2.0 * widest, radius, ArenaTerrain.RAIL_THICKNESS, needed])
	var narrow := _layout([RIVER, RIVER_FAR,
			{"kind": "bridge", "name": "b", "rect": [50.0, 40.0, ArenaTerrain.min_deck_m() - 0.5, 30.0]},
			{"kind": "bridge", "name": "b (far)", "rect": [-50.0, -40.0, ArenaTerrain.min_deck_m() - 0.5, 30.0]}])
	assert_true(Arena.validate(narrow) != "", "and a deck under it is refused: %s" % Arena.validate(narrow))


func test_rims_and_rails_are_in_the_bake() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout([RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]))
	for body_name in ["TerrainRims", "TerrainRails"]:
		var body := arena.get_node_or_null(body_name)
		assert_true(body != null, "%s is built" % body_name)
		if body != null:
			assert_true(body.is_in_group("navigation_source"), "%s is a navigation source (R3)" % body_name)
	var map := arena.get_world_3d().navigation_map
	# The rim's outer face is at the bank + RIM_THICKNESS; with the rim in the bake the mesh stops an agent radius
	# further back. Probe a point just outside the rim's outer face, where the round-7 mesh still reached.
	var outer_face := 40.0 + 12.0 + ArenaTerrain.RIM_THICKNESS
	var just_outside := Vector3(-100.0, 0.0, outer_face + 0.75)
	var nearest := NavigationServer3D.map_get_closest_point(map, just_outside)
	assert_true(nearest.z > outer_face + 1.5,
			"the navmesh keeps an agent radius off the rim's outer face (nearest mesh at z %.2f, face at %.2f)"
			% [nearest.z, outer_face])
	# And the crossing still works through the rails: a deck wide enough for R4 stays connected.
	assert_true(ArenaFixture.route_arrives(arena, Vector3(50.0, 0.0, 70.0), Vector3(50.0, 0.0, 10.0)),
			"a bridge with rails still carries a route")


func test_a_hull_shoved_sideways_on_a_bridge_stays_on_it() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout([RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]))
	var space := arena.get_world_3d().direct_space_state
	# A ray at hull height from the middle of the deck outward over the water must hit the rail before it
	# reaches the deck's edge: that is what stops a shove.
	var from := Vector3(50.0, ArenaTerrain.RAIL_HEIGHT / 2.0, 40.0)
	for dir: float in [-1.0, 1.0]:
		var to := from + Vector3(dir * 10.0, 0.0, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		assert_true(not hit.is_empty(), "a sideways shove %s meets a rail" % ["west" if dir < 0.0 else "east"])
		if not hit.is_empty():
			assert_true(absf((hit["position"] as Vector3).x - 50.0) <= 7.0,
					"and the rail stands on the deck (hit at x %.2f)" % (hit["position"] as Vector3).x)
	# And an eye-level ray over the rail is clear: a bridge does not block sight.
	var eye := Vector3(50.0, Perception.EYE_HEIGHT, 40.0)
	assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + Vector3(40.0, 0.0, 0.0),
			Perception.WORLD_MASK)).is_empty(), "an eye-level ray crosses the rail and the water")
