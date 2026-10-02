extends TestCase
## Fleet round 15, F4: THE LINEUP AS A STANDING TEST. Garage's tour found *"My tanks and IFVs look the same in the
## fight"* by eye, a round after the meshes went in. This finds the next one first: every faction's scout, IFV and tank
## are rasterised at his pose (pitch 21, FOV 35, 72 m, the phone's 810 rows; ClassLook.raster_silhouette, no renderer)
## and every pair within a faction must stay under a silhouette-overlap CEILING (centred IoU; 1 = the same shape at the
## same size). A new mesh that makes two classes alike goes red here, naming the pair and the heading.
##
## The ceiling is 0.80 for every pair except the two `make class-look` found alike and the page is asking him about
## (F3: the Condemned bus/garbage truck, Law's Assault Gun/APC): those are held where they are today plus a margin, so
## they cannot get WORSE; when an approved IFV lands, lower its line to the general ceiling.

## Every pair, every heading, unless named below.
const CEILING := 0.80
## Today's alike pairs, held where they stand: the raster's worst heading at `b2031a45` + 0.03 ("must not get
## worse"). Measured: tank/ifv 0.90 (away), law_tank/law_ifv 0.87 (toward); the rendered class-look gave 0.89 and 0.87.
const KNOWN_ALIKE := {
	"tank/ifv": 0.93,
	"law_tank/law_ifv": 0.90,
}
const HEADINGS := ["away", "quarter_away", "side", "quarter_toward", "toward"]
const ROLES := ["scout", "ifv", "tank"]
const ClassLook := preload("res://game/theme/gallery/class_look.gd")


func _spawn(unit_id: String) -> Node3D:
	var tank := (load("res://game/tank/tank.tscn") as PackedScene).instantiate() as Node3D
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	add_to_tree(tank)
	return tank


func _faction_units(faction: String) -> Array:
	var units: Array = []
	for role: String in ROLES:
		for unit_id: String in Units.roster(faction):
			if Units.role_of(unit_id) == role:
				units.append(unit_id)
				break
	return units


func test_no_two_classes_of_a_faction_share_a_silhouette_at_his_pose() -> void:
	GameTheme.use("cyberpunk")
	var report: Array = []
	for faction: String in Units.FACTIONS:
		var units := _faction_units(faction)
		assert_eq(units.size(), ROLES.size(), "%s fields a scout, an IFV and a tank" % faction)
		var shapes := {}
		for unit_id: String in units:
			var tank := _spawn(unit_id)
			await wait_physics_frames(2)
			shapes[unit_id] = {}
			for heading: String in HEADINGS:
				shapes[unit_id][heading] = ClassLook.raster_silhouette(tank, heading)
		for i in units.size():
			for j in range(i + 1, units.size()):
				var a: String = units[j]  # the bigger class first: tank/ifv, tank/scout, ifv/scout
				var b: String = units[i]
				var key := "%s/%s" % [a, b]
				var ceiling: float = KNOWN_ALIKE.get(key, CEILING)
				var worst := 0.0
				var worst_heading := ""
				for heading: String in HEADINGS:
					var iou: float = ClassLook.centred_iou(shapes[a][heading], shapes[b][heading])
					if iou > worst:
						worst = iou
						worst_heading = heading
				report.append("%s %.2f (%s)" % [key, worst, worst_heading])
				assert_true(worst <= ceiling, "%s look alike at his pose: silhouette IoU %.2f %s, ceiling %.2f" % [key,
						worst, worst_heading, ceiling])
	print("CLASS_LINEUP " + ", ".join(report))


func test_the_raster_finds_the_shape_the_renderer_draws() -> void:
	# Mutation guard for the instrument itself: a unit against itself is 1, and the bus is not the scout.
	GameTheme.use("cyberpunk")
	var bus := _spawn("tank")
	var scout := _spawn("scout")
	await wait_physics_frames(2)
	var bus_away: Dictionary = ClassLook.raster_silhouette(bus, "away")
	var bus_side: Dictionary = ClassLook.raster_silhouette(bus, "side")
	assert_near(ClassLook.centred_iou(bus_away, bus_away), 1.0, 1e-6, "a shape against itself")
	assert_true(int(bus_side["area"]) > int(bus_away["area"]) * 1.5, "side-on the bus shows its length: %d vs %d px"
			% [int(bus_side["area"]), int(bus_away["area"])])
	var scout_side: Dictionary = ClassLook.raster_silhouette(scout, "side")
	assert_true(ClassLook.centred_iou(bus_side, scout_side) < 0.5, "the bus is not the scout: %.2f"
			% ClassLook.centred_iou(bus_side, scout_side))
	# The rendered `make class-look` measured the bus's side-on box at 1920x1080 (box_px); at 810 rows it scales by 0.75.
	var rect: Rect2i = bus_side["rect"]
	assert_true(rect.size.x > 150 and rect.size.x < 260, "the bus side-on is ~%d px long at 810 rows" % rect.size.x)
