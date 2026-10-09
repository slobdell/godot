extends TestCase
## Round 24 (brains R1, his bridge on the Locks): on EVERY map with water or a pit, a route from one side of each body
## of water to the other exists, reaches its goal, and never crosses the water (it goes over a bridge or round the
## end). A map edit that cuts a bridge, or a navmesh change that opens the river, fails here. Every map is read from
## the arena's own list (lesson 265: an enumerating tool reads the live list, never a copy).
##
## The lattice: for each carved rectangle, points along its long axis (SHARES), each pair WATER_STANDOFF_M off both
## long sides, grounded where a hull can stand; the route between them is the one a squad is given (Pathing.query, the
## same navmesh the brains plan on). An end that neither side's spawn can reach (a sealed courtyard in the Crossing's
## canal district) is not a place a squad stands, and its pair is skipped.

const WATER_STANDOFF_M := 18.0
## Along the long axis; off the round numbers the bridges stand on (Terminus Canal's decks are at x = 0 and +-70).
const SHARES := [0.15, 0.4, 0.6, 0.85]


func _wet_maps() -> PackedStringArray:
	var out: PackedStringArray = []
	for map_name: String in Arena.layout_names():
		var layout: Dictionary = Arena.load_layout(map_name).get("layout", {})
		for entry: Dictionary in layout.get("terrain", []):
			if ArenaTerrain.carves(String(entry["kind"])):
				out.append(map_name)
				break
	return out


func test_the_wet_maps_are_the_ones_we_think() -> void:
	var maps := _wet_maps()
	for map_name: String in ["locks", "crossing", "sumps", "terminus_canal", "docks", "gorge", "pit"]:
		assert_true(maps.has(map_name), "%s has water or pits (the list is read from the arenas): %s" % [map_name, maps])


func test_every_crossing_route_reaches_the_far_side_without_crossing_water() -> void:
	for map_name: String in _wet_maps():
		var lab := TacticsLab.create(self, 1, map_name)
		await lab.start()
		var node := lab.arena
		var layout: Dictionary = Arena.active
		var pairs := 0
		var hubs: Array = []
		for south: bool in [false, true]:
			var zone: Dictionary = Arena.spawn_zone_of(layout, south)
			if zone.has("center"):
				hubs.append(SlotGround.standable(node, zone["center"]))
		for entry: Dictionary in layout["terrain"]:
			if not ArenaTerrain.carves(String(entry["kind"])):
				continue
			var box := ArenaTerrain.bounds(entry)
			var wide: bool = box[2] - box[0] >= box[3] - box[1]
			for share: float in SHARES:
				var a: Vector3
				var b: Vector3
				if wide:
					var x := lerpf(box[0], box[2], share)
					a = Vector3(x, 0.0, box[1] - WATER_STANDOFF_M)
					b = Vector3(x, 0.0, box[3] + WATER_STANDOFF_M)
				else:
					var z := lerpf(box[1], box[3], share)
					a = Vector3(box[0] - WATER_STANDOFF_M, 0.0, z)
					b = Vector3(box[2] + WATER_STANDOFF_M, 0.0, z)
				if not Arena.contains(a, layout) or not Arena.contains(b, layout):
					continue  # off the map's own shape (a river reaching the hexagon's corner)
				a = SlotGround.standable(node, a)
				b = SlotGround.standable(node, b)
				if SlotGround.wet(a, layout) or SlotGround.wet(b, layout) or not SlotGround.leg_wet(a, b, layout):
					continue  # grounding put both ends on one side: no crossing to test here
				if not _connected(node, a, hubs) or not _connected(node, b, hubs):
					continue
				var route := Pathing.query(node, a, b)
				assert_true(bool(route["ready"]), "%s: navigation ready" % map_name)
				assert_true(bool(route["reachable"]), "%s: the far side is reachable from %s to %s (end gap %.1f m)" % [
						map_name, a, b, float(route["end_gap_m"])])
				var points: PackedVector3Array = route["points"]
				for i in range(1, points.size()):
					assert_true(not SlotGround.leg_wet(points[i - 1], points[i], layout),
							"%s: the route %s -> %s crosses water between %s and %s" % [map_name, a, b, points[i - 1], points[i]])
				pairs += 1
		assert_true(pairs >= 2, "%s: at least two crossings were tested (%d)" % [map_name, pairs])
		lab.dispose()
		await wait_physics_frames(2)


## Whether a squad standing at either spawn can drive to `point` (it is part of the map, not a sealed pocket).
func _connected(node: Node3D, point: Vector3, hubs: Array) -> bool:
	for hub: Vector3 in hubs:
		if bool(Pathing.query(node, hub, point)["reachable"]):
			return true
	return false
