class_name SfxSurfaces
extends RefCounted
## Round 17 G5: what a round sounds like where it lands. The lead: *"different sounds for a round hitting the ground
## or a building versus making a direct hit on a vehicle versus hitting the plasma shield versus destroying a
## vehicle"*. Until round 17 an impact knew its weapon and nothing else: a shell that missed played `dirt_impact`
## into a container, a tower block or a canal alike, and a 25 mm burst or a machine-gun stream that missed played
## nothing at all.
##
## A miss's surface is read from the arena's LAYOUT (Arena.active: every obstacle's type, footprint and turn, the
## water) - static data, presentation only; combat's impact event is unchanged. A vehicle hit is armour by calibre;
## the weak spot, the shield and the kill keep their own sounds (WeaponFx, ShieldEffect, FxWorld).

const SURFACES := ["ground", "concrete", "steel", "water"]
const CALIBRES := ["heavy", "medium", "light"]
## Obstacle type -> what it is made of. Anything not listed is steel (the arena kit is mostly steel).
const MATERIAL := {
	"container_20": "steel", "container_40": "steel", "wreck": "steel", "floodlight": "steel", "sign": "steel",
	"ad_screen": "steel", "crate": "steel",
	"block": "concrete", "barricade": "concrete", "wall": "concrete",
}
## calibre -> surface -> SfxSystem sound.
const MISS := {
	"heavy": {"ground": "dirt_impact", "concrete": "impact_concrete_heavy", "steel": "impact_steel_heavy",
			"water": "impact_water_heavy"},
	"medium": {"ground": "impact_dirt_medium", "concrete": "impact_concrete_medium", "steel": "impact_steel_medium",
			"water": "impact_water_light"},
	"light": {"ground": "impact_dirt_light", "concrete": "impact_concrete_light", "steel": "bullet_hit_metal",
			"water": "impact_water_light"},
}
## calibre -> the sound of that round on a vehicle's armour: a 120 mm on armour is not a bullet on armour.
const ARMOUR := {"heavy": "shell_hit_armor", "medium": "impact_armor_medium", "light": "bullet_hit_metal"}
## How close (m) to an obstacle's box an impact counts as striking it, and above its top.
const MARGIN_M := 0.6
## Within this of the arena's edge, a round struck the perimeter wall.
const WALL_BAND_M := 1.5


static func calibre_of(fire_model: String) -> String:
	match fire_model:
		"shell", "arc":
			return "heavy"
		"burst":
			return "medium"
	return "light"


static func miss_sound(calibre: String, surface: String) -> String:
	return String((MISS.get(calibre, MISS["light"]) as Dictionary).get(surface, ""))


static func hit_sound(calibre: String) -> String:
	return String(ARMOUR.get(calibre, ARMOUR["light"]))


static func all_sounds() -> Array:
	var names: Array = []
	for calibre in MISS:
		for surface in MISS[calibre]:
			if not MISS[calibre][surface] in names:
				names.append(MISS[calibre][surface])
	for calibre in ARMOUR:
		if not ARMOUR[calibre] in names:
			names.append(ARMOUR[calibre])
	return names


## What the round at `position` (its surface `normal`) struck, in `layout` (Arena.active's normalized shape).
static func surface_at(position: Vector3, normal: Vector3, layout: Dictionary) -> String:
	var flat := Vector2(position.x, position.z)
	for entry: Dictionary in layout.get("terrain", []):
		if String(entry.get("kind", "")) != "water":
			continue
		var rect: Array = entry.get("rect", [0, 0, 0, 0])
		if absf(flat.x - float(rect[0])) <= float(rect[2]) / 2.0 and absf(flat.y - float(rect[1])) <= float(rect[3]) / 2.0:
			return "water"
	var best := ""
	var best_gap := INF
	for obstacle: Dictionary in layout.get("obstacles", []):
		var size := Arena.obstacle_size(obstacle)
		if position.y > size.y + MARGIN_M:
			continue
		var at: Array = obstacle.get("position", [0.0, 0.0])
		# The TURNED footprint (yard, round 17 CP1: ground-level containers turn a few degrees for real), the arena
		# kit's own measure, so a round on a turned container's corner is steel, not dirt.
		var gap := ArenaKit.distance_to_footprint(flat, Vector2(float(at[0]), float(at[1])), size,
				float(obstacle.get("rotation_deg", 0.0)))
		if gap <= MARGIN_M and gap < best_gap:
			# The ground right beside a box is still ground: a round that landed flat on the floor next to it.
			if position.y < 0.2 and normal.y > 0.7 and gap > 0.0:
				continue
			best_gap = gap
			best = String(MATERIAL.get(String(obstacle.get("type", "")), "steel"))
	if best != "":
		return best
	var half := float(layout.get("half_size", 0.0))
	if half > 0.0:
		var shape := String((layout.get("shape", {}) as Dictionary).get("kind", ArenaShape.DEFAULT_KIND))
		if not ArenaShape.contains(shape, half - WALL_BAND_M, flat):
			return "concrete"
	return "ground"


## Keeps a stream of small rounds a texture: per calibre, at most one impact per spot (3 m) every SPACING seconds.
## Heavy rounds are never thinned: each is an event. Presentation clock only.
class RateLimit:
	const SPACING := {"heavy": 0.0, "medium": 0.1, "light": 0.2}
	var _last := {}

	func allow(calibre: String, position: Vector3, now: float) -> bool:
		var spacing := float(SPACING.get(calibre, 0.2))
		if spacing <= 0.0:
			return true
		var key := "%s/%s" % [calibre, position.snapped(Vector3.ONE * 3.0)]
		if now - float(_last.get(key, -INF)) < spacing:
			return false
		_last[key] = now
		if _last.size() > 128:
			_last.clear()
		return true
