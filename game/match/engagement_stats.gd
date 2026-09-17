class_name EngagementStats
extends RefCounted
## Round 5 combat X1: the SHAPE of a fight, measured. The lead played round 4 and saw "just these 2 masses shooting
## at each other"; this is how that sentence becomes numbers a tuning pass can move:
##
## - how far apart the fighting happens (each living unit's nearest enemy, median over seconds with shots in them),
## - whether anyone moves while it happens (`static_share`: combat seconds where BOTH teams' mean speed is below
##   STILL_SPEED, i.e. a standing exchange),
## - whether the armies' centres of mass move once contact is made (`centroid_travel`, metres per team),
## - where kills come from (the killing hit's face: front, side, rear; arcs count as indirect), and
## - whether cover is used (unit-seconds, shots, killers and victims within COVER_RADIUS of an obstacle footprint).
##
## Match feeds it once a second and on every enemy kill; it never reads the RNG or changes a unit, so the sim baseline
## does not move. Centroids shift a little when units die: read `centroid_travel` as "the army moved", not as metres
## any one vehicle drove.

## Sample once a second.
const SAMPLE_TICKS := 60
## "By cover": within this many metres of an obstacle's footprint (a hull is ~2.5-3 m wide, so this is "tucked in
## beside it", not "somewhere near").
const COVER_RADIUS := 5.0
## A team whose living units average less than this (m/s) is standing still.
const STILL_SPEED := 1.5
## Army level: a combat second is a HELD LINE when neither team's centre of mass moved more than HELD_LINE_METRES over
## the last HELD_LINE_WINDOW seconds. Units weave and jink while they trade fire, so hull speed says little about
## whether the ARMIES are going anywhere; this is the "two masses" measure.
const HELD_LINE_WINDOW := 5
const HELD_LINE_METRES := 5.0
## A kill is OFF AXIS when the killer stood more than this many degrees away from the line between the two armies'
## centres, seen from the victim (a flank of the army, not just the side of the hull).
const OFF_AXIS_DEG := 45.0

var obstacles: Array = []

var samples := 0
var contact_second := -1
var combat_seconds := 0
var static_seconds := 0
var separation_at_contact := -1.0
var _engaged_distances: Array[float] = []
var _last_centroids: Array = [null, null]
var centroid_travel: Array[float] = [0.0, 0.0]
var unit_seconds := 0
var unit_seconds_near_cover := 0
var shots := 0
var shots_near_cover := 0
var kills := {"front": 0, "side": 0, "rear": 0, "indirect": 0}
var _kill_distances: Array[float] = []
var kills_by_cover_shooters := 0
var deaths_near_cover := 0
var held_line_seconds := 0
var _centroid_history: Array = []
## Each team's centre of mass at contact and now (net advance = movement toward the other army's contact position).
var _centroids_at_contact: Array = [null, null]
var _centroids_now: Array = [null, null]
var kills_off_axis := 0
var kills_from_behind_line := 0
var _axis_kills := 0


## `features`: Arena.cover_features()-shaped dictionaries ({position, size, rotation, ...}).
func _init(features: Array = []) -> void:
	obstacles = features


## Obstacles of the arena that is loaded now (Arena.active), as cover features.
static func features_of(layout: Dictionary) -> Array:
	var features: Array = []
	for obstacle: Dictionary in layout.get("obstacles", []):
		features.append({"position": Vector3(obstacle["position"][0], 0.0, obstacle["position"][1]),
				"size": Arena.obstacle_size(obstacle), "rotation": deg_to_rad(float(obstacle.get("rotation_deg", 0.0)))})
	return features


## Flat distance from `point` to the rotated footprint of `feature` (0 inside it).
static func distance_to_feature(point: Vector3, feature: Dictionary) -> float:
	var center: Vector3 = feature["position"]
	var size: Vector3 = feature["size"]
	var local := Vector3(point.x - center.x, 0.0, point.z - center.z).rotated(Vector3.UP, -float(feature.get("rotation", 0.0)))
	var dx := maxf(absf(local.x) - size.x * 0.5, 0.0)
	var dz := maxf(absf(local.z) - size.z * 0.5, 0.0)
	return sqrt(dx * dx + dz * dz)


func near_cover(point: Vector3) -> bool:
	for feature: Dictionary in obstacles:
		if distance_to_feature(point, feature) <= COVER_RADIUS:
			return true
	return false


## One second of the fight. `teams[t]` = the living units of team t as [{position, speed, near_cover}];
## `shots_this_second` = rounds fired by anyone since the last sample.
func sample(teams: Array, shots_this_second: int) -> void:
	var second := samples
	samples += 1
	var centroids: Array = [null, null]
	var speeds := [0.0, 0.0]
	for team in 2:
		var units: Array = teams[team]
		if units.is_empty():
			continue
		var sum := Vector3.ZERO
		for unit: Dictionary in units:
			sum += unit["position"]
			speeds[team] += absf(float(unit["speed"]))
			unit_seconds += 1
			unit_seconds_near_cover += 1 if unit["near_cover"] else 0
		centroids[team] = sum / units.size()
		speeds[team] /= units.size()
	if shots_this_second > 0 and contact_second < 0:
		contact_second = second
		if centroids[0] != null and centroids[1] != null:
			separation_at_contact = (centroids[0] as Vector3).distance_to(centroids[1])
	if contact_second >= 0:
		for team in 2:
			if centroids[team] != null and _last_centroids[team] != null and second > contact_second:
				centroid_travel[team] += (centroids[team] as Vector3).distance_to(_last_centroids[team])
	_last_centroids = centroids
	_centroids_now = centroids
	if contact_second == second:
		_centroids_at_contact = centroids.duplicate()
	_centroid_history.append(centroids)
	if _centroid_history.size() > HELD_LINE_WINDOW + 1:
		_centroid_history.pop_front()
	if shots_this_second <= 0 or centroids[0] == null or centroids[1] == null:
		return
	combat_seconds += 1
	if speeds[0] < STILL_SPEED and speeds[1] < STILL_SPEED:
		static_seconds += 1
	if _centroid_history.size() == HELD_LINE_WINDOW + 1:
		var oldest: Array = _centroid_history[0]
		var held := true
		for team in 2:
			if oldest[team] == null or (oldest[team] as Vector3).distance_to(centroids[team]) > HELD_LINE_METRES:
				held = false
		if held:
			held_line_seconds += 1
	var nearest: Array[float] = []
	for team in 2:
		for unit: Dictionary in teams[team]:
			var best := INF
			for enemy: Dictionary in teams[1 - team]:
				best = minf(best, (unit["position"] as Vector3).distance_to(enemy["position"]))
			nearest.append(best)
	_engaged_distances.append(_median(nearest))


## The army-level half of a kill: where the killer stood relative to the line between the two armies' centres (as
## last sampled), seen from the victim. `victim_team` is the team that lost the unit.
func record_kill_bearing(victim_team: int, victim: Vector3, killer: Vector3) -> void:
	var own: Variant = _last_centroids[victim_team]
	var enemy: Variant = _last_centroids[1 - victim_team]
	if own == null or enemy == null:
		return
	var axis := Vector3((enemy as Vector3).x - (own as Vector3).x, 0.0, (enemy as Vector3).z - (own as Vector3).z)
	var toward_killer := Vector3(killer.x - victim.x, 0.0, killer.z - victim.z)
	if axis.length() < 0.01 or toward_killer.length() < 0.01:
		return
	_axis_kills += 1
	var angle := rad_to_deg(axis.angle_to(toward_killer))
	if angle > OFF_AXIS_DEG:
		kills_off_axis += 1
	if angle > 135.0:
		kills_from_behind_line += 1


## Metres each team's centre of mass moved toward where the other army stood at contact (negative = fell back).
func net_advance() -> Array:
	var advance := [0.0, 0.0]
	for team in 2:
		var start: Variant = _centroids_at_contact[team]
		var now: Variant = _centroids_now[team]
		var enemy_start: Variant = _centroids_at_contact[1 - team]
		if start == null or now == null or enemy_start == null:
			continue
		var toward := Vector3((enemy_start as Vector3).x - (start as Vector3).x, 0.0, (enemy_start as Vector3).z - (start as Vector3).z)
		if toward.length() > 0.01:
			advance[team] = snappedf(((now as Vector3) - (start as Vector3)).dot(toward.normalized()), 0.1)
	return advance


func record_shot(shooter_near_cover: bool) -> void:
	shots += 1
	shots_near_cover += 1 if shooter_near_cover else 0


## An enemy kill: the killing hit's `face`, whether it was an indirect (arcing) round, how far the killer stood from
## the victim, and whether each of them was by cover.
func record_kill(_team: int, face: String, indirect: bool, distance: float, killer_near_cover: bool,
		victim_near_cover: bool) -> void:
	kills["indirect" if indirect else face] += 1
	if distance >= 0.0:  # -1: the killer is gone (its shell outlived it)
		_kill_distances.append(distance)
	kills_by_cover_shooters += 1 if killer_near_cover else 0
	deaths_near_cover += 1 if victim_near_cover else 0


func summary() -> Dictionary:
	var direct := int(kills["front"]) + int(kills["side"]) + int(kills["rear"])
	var all_kills := direct + int(kills["indirect"])
	return {"samples": samples, "contact_second": contact_second, "combat_seconds": combat_seconds,
			"separation_at_contact": snappedf(separation_at_contact, 0.1),
			"static_share": _share(static_seconds, combat_seconds),
			"engaged_distance_median": snappedf(_median(_engaged_distances), 0.1),
			"centroid_travel": [snappedf(centroid_travel[0], 0.1), snappedf(centroid_travel[1], 0.1)],
			"kills": kills.duplicate(),
			"flank_rear_kill_share": _share(int(kills["side"]) + int(kills["rear"]), direct),
			"kill_distance_median": snappedf(_median(_kill_distances), 0.1),
			"kill_distance_p25": snappedf(_percentile(_kill_distances, 0.25), 0.1),
			"kill_distance_p75": snappedf(_percentile(_kill_distances, 0.75), 0.1),
			"unit_seconds_near_cover_share": _share(unit_seconds_near_cover, unit_seconds),
			"shots_near_cover_share": _share(shots_near_cover, shots),
			"kills_by_cover_shooters_share": _share(kills_by_cover_shooters, all_kills),
			"deaths_near_cover_share": _share(deaths_near_cover, all_kills),
			"held_line_share": _share(held_line_seconds, combat_seconds),
			"net_advance": net_advance(),
			"off_axis_kill_share": _share(kills_off_axis, _axis_kills),
			"behind_line_kill_share": _share(kills_from_behind_line, _axis_kills)}


static func _share(part: int, whole: int) -> float:
	return snappedf(float(part) / whole, 0.001) if whole > 0 else 0.0


static func _median(values: Array[float]) -> float:
	return _percentile(values, 0.5)


## Linear interpolation between closest ranks; -1 for no data.
static func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	var position := fraction * (sorted.size() - 1)
	var low := floori(position)
	var high := mini(low + 1, sorted.size() - 1)
	return lerpf(sorted[low], sorted[high], position - low)
