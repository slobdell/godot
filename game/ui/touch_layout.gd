class_name TouchLayout
extends RefCounted
## Round 39 (feedback F2/F3, his note "the most important part of the view is the top of the screen since that corresponds
## to units in the distance"): where the phone map (`--touch-map`, TacticalMap) puts its squad chips, order bar and camera
## buttons. He picked "dock" on the directions page (2026-10-24): everything in the bottom of the screen, around the
## HUD's score bug (lower left) and radar (lower right), where thumbs reach. "top" is round 2's layout (chips top centre,
## camera buttons top right, orders bottom left, where they ran into the score bug), kept behind `--touch-layout=top` for
## A/B. Pure: tests read the rects.
##
##   dock   orders along the bottom between the bug and the radar, the chips in a row just above them, the camera
##          buttons stacked over the radar
## Portrait: the orders stacked at the left edge and the chips at the right edge over the bug and radar, the camera
## buttons stacked between them.

const LAYOUTS := ["dock", "top"]
const MARGIN := 10.0
const GAP := 6.0


## The layout this run asked for (his "dock" unless `--touch-layout=top`).
static func from_flags() -> String:
	var asked := LaunchFlags.from_environment().text("touch-layout")
	return asked if LAYOUTS.has(asked) else "dock"


## Rects for the order bar, the squad chips and the camera buttons, given each one's size laid out in a row and stacked
## ([row, column] Vector2 pairs) and the HUD's bug and radar. {orders, squads, tools: Rect2, orders_vertical,
## squads_vertical, tools_vertical: bool, text_floor: float (the lowest y free for toasts)}. Empty for "top".
static func place(layout: String, screen: Vector2, orders: Array, squads: Array, tools: Array, bug: Rect2,
		radar: Rect2) -> Dictionary:
	if layout == "top" or not LAYOUTS.has(layout):
		return {}
	if HudLayout.portrait(screen):
		var floor_y := minf(bug.position.y, radar.position.y) - GAP
		var orders_rect := Rect2(Vector2(MARGIN, floor_y - orders[1].y), orders[1])
		var squads_rect := Rect2(Vector2(screen.x - MARGIN - squads[1].x, floor_y - squads[1].y), squads[1])
		var middle := (orders_rect.end.x + squads_rect.position.x) * 0.5
		var tools_rect := Rect2(Vector2(middle - tools[1].x * 0.5, floor_y - tools[1].y), tools[1])
		return _out(orders_rect, squads_rect, tools_rect, [true, true, true],
				minf(minf(orders_rect.position.y, squads_rect.position.y), tools_rect.position.y) - GAP)
	var left := bug.end.x + GAP
	var right := radar.position.x - GAP
	var bottom := screen.y - MARGIN
	var tools_rect := Rect2(Vector2(screen.x - MARGIN - tools[1].x, radar.position.y - GAP - tools[1].y), tools[1])
	var orders_rect := _band(left, right, bottom, orders[0], bug)
	var squads_rect := _band(left, right, orders_rect.position.y - GAP, squads[0], bug)
	return _out(orders_rect, squads_rect, tools_rect, [false, false, true], squads_rect.position.y - GAP)


static func _out(orders: Rect2, squads: Rect2, tools: Rect2, vertical: Array, text_floor: float) -> Dictionary:
	return {"orders": orders, "squads": squads, "tools": tools, "orders_vertical": vertical[0],
			"squads_vertical": vertical[1], "tools_vertical": vertical[2], "text_floor": text_floor}


## `size` centred in [left, right] with its bottom at `bottom`; when it doesn't fit there, over the bug at the left edge.
static func _band(left: float, right: float, bottom: float, size: Vector2, bug: Rect2) -> Rect2:
	if size.x <= right - left:
		return Rect2(Vector2(left + (right - left - size.x) * 0.5, bottom - size.y), size)
	var low := minf(bottom, bug.position.y - GAP)
	return Rect2(Vector2(MARGIN, low - size.y), size)
