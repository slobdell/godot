class_name FormationPreview
extends RefCounted
## Round 18 (picker, P3): what a formation does, played the way TaskPreview plays a task (round 7). The selected
## vehicles form up at the bottom of the box, drive up it in the formation, halt, turn to the sector each crew watches,
## and the sectors light up: who covers where, and where the shape is blind. The bottom line says how wide it is and how
## much of the circle it watches.
##
## TRUE, not illustrative: the slots, the seating (heavies to the front) and the sectors come from TacticsFormation.place,
## the same call the squads use, for the vehicles actually selected (four tanks draw four tanks; a mixed squad draws its
## real seats). One instance lives in the picker, built on first open; its layouts are remembered per (shape, vehicles),
## so an open panel runs the planner once per card, not once a frame.

const LOOP_S := 3.6
## Phases, as fractions of LOOP_S: forming up, driving, turning to the sectors, then the sectors shown.
const FORM_END := 0.22
const DRIVE_END := 0.55
const TURN_END := 0.68
## Fewer selected than this and the preview shows a squad of four tanks instead (a formation of one is a dot).
const MIN_SHOWN := 2
const STAND_IN := 4
## Where the start row sits behind the destination (meters), for the seating.
const START_BACK_M := 40.0

var _layouts := {}


## The formation for these members, from the real planner: {"slots": [Vector2 (right, back) m, centred], "facing":
## [float azimuth deg, 0 = travel, + = right], "roles": [String], "leader": int (index of the leader's seat or -1),
## "frontage_m", "coverage" (0..1), "count"}. `members` is GroupFormation.members_of(tanks, false).
func layout(shape: String, members: Array) -> Dictionary:
	var shown := members if members.size() >= MIN_SHOWN else _stand_in()
	var key := shape
	for member: Dictionary in shown:
		key += "|" + String(member.get("unit", ""))
	if _layouts.has(key):
		return _layouts[key]
	var seated: Array = []
	for i in shown.size():
		var member: Dictionary = (shown[i] as Dictionary).duplicate()
		# The squad starts in a row behind the destination, so place() seats it the way a real move from there would.
		member["position"] = Vector3((i - (shown.size() - 1) * 0.5) * 8.0, 0.0, START_BACK_M)
		seated.append(member)
	var placed := TacticsFormation.place(seated, shape, Vector3.ZERO, Vector3.FORWARD, TacticsFormation.DEFAULT_SPACING,
			{"policy": "front", "halt": true})
	var slots: Array[Vector2] = []
	var facing: Array[float] = []
	var roles: Array[String] = []
	var leader := -1
	for entry: Dictionary in placed:
		slots.append(entry["offset"])
		facing.append(float(entry["sector"]))
		roles.append(String(entry.get("role", "tank")))
		if int(entry["index"]) == 0:
			leader = slots.size() - 1
	var result := {"slots": slots, "facing": facing, "roles": roles, "leader": leader, "count": shown.size(),
			"frontage_m": TacticsFormation.frontage(shape, shown.size()), "coverage": TacticsFormation.coverage(shape, shown.size())}
	_layouts[key] = result
	return result


func _stand_in() -> Array:
	var result: Array = []
	for i in STAND_IN:
		result.append({"name": "Preview_%d" % i, "unit": "tank", "role": Units.role_of("tank")})
	return result


## Draw the loop for `shape` into `rect` at `seconds` (any clock; it wraps).
func draw(canvas: CanvasItem, rect: Rect2, shape: String, seconds: float, members: Array, ink: Color) -> void:
	if rect.size.x < 20.0 or rect.size.y < 20.0 or not TacticsFormation.NAMES.has(shape):
		return
	var plan := layout(shape, members)
	var slots: Array = plan["slots"]
	if slots.is_empty():
		return
	var t := fposmod(seconds, LOOP_S) / LOOP_S
	# Scale: the shape's extent plus a margin fits a third of the box's height and most of its width.
	var extent := Vector2.ZERO
	for slot: Vector2 in slots:
		extent = extent.max(slot.abs())
	var scale := minf(rect.size.x * 0.36 / maxf(extent.x, 6.0), rect.size.y * 0.2 / maxf(extent.y, 6.0))
	var finish := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.36)
	var depart := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.8)
	var form := CyberStyle.ease_in_out(clampf(t / FORM_END, 0.0, 1.0))
	var drive := CyberStyle.ease_in_out(clampf((t - FORM_END) / (DRIVE_END - FORM_END), 0.0, 1.0))
	var turn := clampf((t - DRIVE_END) / (TURN_END - DRIVE_END), 0.0, 1.0)
	var glyph := clampf(rect.size.y * 0.15, 11.0, 28.0)
	var anchor := depart.lerp(finish, drive)
	# The route: a faint line from where they set off to where they halt.
	canvas.draw_dashed_line(depart, finish, Color(ink, 0.25), 1.0, 4.0)
	var roles: Array = plan["roles"]
	var facing: Array = plan["facing"]
	var count := slots.size()
	if t >= TURN_END:
		var fade := clampf((t - TURN_END) / 0.08, 0.0, 1.0)
		for i in count:
			var at: Vector2 = finish + (slots[i] as Vector2) * scale
			_sector(canvas, at, float(facing[i]), rect.size.y * 0.24, Color(ink, 0.13 * fade))
	for i in count:
		var row: Vector2 = depart + Vector2((i - (count - 1) * 0.5) * glyph * 1.3, glyph * 0.2)
		var at: Vector2 = row.lerp(anchor + (slots[i] as Vector2) * scale, form) if drive <= 0.0 else anchor + (slots[i] as Vector2) * scale
		var heading := deg_to_rad(float(facing[i])) * turn
		var color := CyberStyle.YELLOW if i == int(plan["leader"]) else ink
		CommandIcons.draw_unit(canvas, String(roles[i]), at, glyph, color, heading)
	var font := CyberStyle.font()
	var px := clampi(roundi(rect.size.y * 0.075), 9, 13)
	var words := "%d m wide  ·  watches %d°" % [roundi(float(plan["frontage_m"])), roundi(float(plan["coverage"]) * 360.0)]
	if members.size() < MIN_SHOWN:
		words += "  ·  a squad of %d" % STAND_IN
	canvas.draw_string(font, rect.position + Vector2(4, rect.size.y - 4), words, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8,
			px, Color(ink, 0.75))


## A crew's sector of fire: a fan SECTOR_WIDTH wide around `azimuth` (degrees, 0 = up the box, + = right).
static func _sector(canvas: CanvasItem, at: Vector2, azimuth: float, radius: float, color: Color) -> void:
	var half := deg_to_rad(TacticsFormation.SECTOR_WIDTH * 0.5)
	var middle := deg_to_rad(azimuth)
	var fan := PackedVector2Array([at])
	for k in 9:
		var a := middle - half + 2.0 * half * k / 8.0
		fan.append(at + Vector2(sin(a), -cos(a)) * radius)
	canvas.draw_colored_polygon(fan, color)
