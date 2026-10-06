class_name UnitThumbs
extends RefCounted
## Round 20 (garage, R2; contract C20.4): the picture of a vehicle on its garage card and squad chip. The lead: *"We
## should incorporate the graphics of the vehicles we're adding to the squads"* (2026-10-06). The files are rendered
## from the real mesh by `make unit-thumbs` (tools/unit_thumbs.gd) and committed under DIR; nothing is rendered at
## runtime. `tests/garage/test_unit_thumbs.gd` fails when a unit in `Units.PROFILES` has no picture.

const DIR := "res://assets/units/thumbs/"


## The card's picture of `unit_id` (320 x 200), or null when there is none.
static func card(unit_id: String) -> Texture2D:
	return UnitThumbs._load(UnitThumbs.card_path(unit_id))


## The squad chip's picture of `unit_id` (128 x 80), or null when there is none.
static func chip(unit_id: String) -> Texture2D:
	return UnitThumbs._load(UnitThumbs.chip_path(unit_id))


static func card_path(unit_id: String) -> String:
	return DIR + "%s.png" % unit_id


static func chip_path(unit_id: String) -> String:
	return DIR + "%s_chip.png" % unit_id


static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## `image` cropped to the pixels the vehicle drew (alpha), widened to `aspect` (width / height) with `margin` (a share
## of the height) around it, centred on the vehicle; the render's transparent rest is cut away. Pure: the tool and
## its test call it.
static func crop_to_vehicle(image: Image, aspect: float, margin: float) -> Image:
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return image
	var pad := margin * maxf(float(used.size.x) / aspect, float(used.size.y))
	var width := float(used.size.x) + 2.0 * pad
	var height := float(used.size.y) + 2.0 * pad
	if width / height < aspect:
		width = height * aspect
	else:
		height = width / aspect
	var centre := Vector2(used.position) + Vector2(used.size) / 2.0
	var rect := Rect2i(Vector2i(roundi(centre.x - width / 2.0), roundi(centre.y - height / 2.0)),
			Vector2i(roundi(width), roundi(height)))
	var result := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	# The crop may reach past the render's edge (a long vehicle in a wide frame): copy only the part inside it.
	var inside := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	result.blit_rect(image, inside, inside.position - rect.position)
	return result
