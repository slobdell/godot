extends TestCase
## Fleet round 15, F1: the instrument behind `make class-look` (garage's tour: *"My tanks and IFVs look the same in the
## fight."*). The frames need a display; the arithmetic that turns them into numbers does not, so it is held here: a
## mask is found where it is, two silhouettes are compared on their centroids (so where a unit sits in the frame
## cannot change the verdict), and each faction's pair is the catalog's tank and IFV.

const ClassLook := preload("res://game/theme/gallery/class_look.gd")


## A black image with white rectangles: a silhouette mask as the renderer writes one.
func _mask(size: Vector2i, rects: Array) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for rect: Rect2i in rects:
		image.fill_rect(rect, Color.WHITE)
	return image


func _flat(size: Vector2i, colour: Color) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return image


func test_a_mask_is_found_with_its_box_area_and_lit_colour() -> void:
	var mask := _mask(Vector2i(40, 30), [Rect2i(5, 7, 10, 4)])
	var shot: Dictionary = ClassLook.analyse(_flat(Vector2i(40, 30), Color(0.2, 0.4, 0.8)), mask)
	assert_eq(shot["rect"], Rect2i(5, 7, 10, 4), "the mask's box")
	assert_eq(int(shot["area"]), 40, "its area in pixels")
	var mean: Color = shot["mean"]
	assert_true(absf(mean.b - 0.8) < 0.01 and absf(mean.r - 0.2) < 0.01, "the lit colour inside it: %s" % mean)
	assert_true(float(shot["bright"]) > 0.99, "0.8 blue is past the bright line")


func test_the_same_silhouette_anywhere_in_the_frame_is_iou_one() -> void:
	var lit := _flat(Vector2i(60, 40), Color.GRAY)
	var a: Dictionary = ClassLook.analyse(lit, _mask(Vector2i(60, 40), [Rect2i(2, 3, 20, 6)]))
	var b: Dictionary = ClassLook.analyse(lit, _mask(Vector2i(60, 40), [Rect2i(30, 25, 20, 6)]))
	assert_true(absf(ClassLook.centred_iou(a, b) - 1.0) < 1e-6, "moved, not changed: %.3f" % ClassLook.centred_iou(a, b))


func test_a_shorter_silhouette_overlaps_by_its_length_ratio() -> void:
	var lit := _flat(Vector2i(60, 40), Color.GRAY)
	var long: Dictionary = ClassLook.analyse(lit, _mask(Vector2i(60, 40), [Rect2i(0, 0, 40, 10)]))
	var short: Dictionary = ClassLook.analyse(lit, _mask(Vector2i(60, 40), [Rect2i(10, 20, 30, 10)]))
	var iou: float = ClassLook.centred_iou(long, short)
	assert_true(absf(iou - 0.75) < 0.03, "a 30-pixel bar centred on a 40-pixel one: IoU 0.75, got %.3f" % iou)
	assert_true(absf(ClassLook.centred_iou(short, long) - iou) < 1e-6, "symmetric")


func test_every_faction_pair_is_its_tank_and_its_ifv() -> void:
	var pairs: Array = ClassLook.faction_pairs(Units.FACTIONS)
	assert_eq(pairs.size(), Units.FACTIONS.size(), "one pair per faction: %s" % [pairs])
	for pair: Array in pairs:
		assert_eq(Units.role_of(pair[0]), "tank", "%s first" % [pair])
		assert_eq(Units.role_of(pair[1]), "ifv", "%s second" % [pair])
	assert_eq(pairs[0], ["tank", "ifv"], "the Condemned's: the bus and the garbage truck")
