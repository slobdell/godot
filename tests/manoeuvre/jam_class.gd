extends RefCounted
## Round 41 (manoeuvre Q1, the jam census; measurement only): the classifier probe_jam.gd reads a blocked crew's situation with,
## pure so tests/manoeuvre/test_jam_class.gd can pin it. A BLOCKER (the friend a slowed crew is up against) is classed by what it
## is doing this tick, from state only:
##   head_on    moving (>= MOVING_MPS) within 60 deg of straight at the asker (its velocity against the asker's way)
##   same_way   moving within 30 deg of the asker's way (a slower leader: waiting behind it is following it)
##   crossing   moving, neither: it is driving across the asker's line and will be off it
##   turning    slower than MOVING_MPS, hull yawing at TURNING_DPS or more: turning in place (his "pointed north" scout)
##   stalled    slower than MOVING_MPS, not turning, under way: itself blocked (a chain)
##   parked     slower than MOVING_MPS, not turning, not under way (or no mover: the player's own hull)
## And what the ASKER did over an episode: yielded (gave way most of the time), reversed, steered (left its lane by more than
## STEERED_M), stopped (still most of the time), else slowed.

const MOVING_MPS := 1.0
const TURNING_DPS := 15.0
const SAME_WAY_COS := 0.866  # cos 30 deg (Traffic.FOLLOW_COS)
const HEAD_ON_COS := -0.5  # cos 120 deg
const STEERED_M := 1.5
const REVERSED_TICKS := 5
const CLASSES: Array[String] = ["head_on", "same_way", "crossing", "turning", "stalled", "parked"]


## `speed` the blocker's flat speed (m/s), `yaw_dps` its hull yaw rate (deg/s, sign ignored), `cos_way` the cosine between its
## velocity and the asker's way (ignored when it is not moving), `under_way` its mover's is_under_way() (false for no mover).
static func blocker_class(speed: float, yaw_dps: float, cos_way: float, under_way: bool) -> String:
	if speed >= MOVING_MPS:
		if cos_way >= SAME_WAY_COS:
			return "same_way"
		if cos_way <= HEAD_ON_COS:
			return "head_on"
		return "crossing"
	if absf(yaw_dps) >= TURNING_DPS:
		return "turning"
	return "stalled" if under_way else "parked"


## Is a hull at `off` (its centre relative to the lane's origin) inside the lane along `way` (unit): ahead of the origin, within
## `length` along it and within `width` of its centre line?
static func in_lane(off: Vector2, way: Vector2, width: float, length: float) -> bool:
	var along := off.dot(way)
	if along <= 0.0 or along > length:
		return false
	return absf(off.cross(way)) <= width


## When two discs of summed radius `r`, me at the origin, the other at `p` moving at `v_rel` RELATIVE TO ME (v_other - v_me),
## first touch: the seconds until |p + v_rel t| = r, or INF when they never do (or already overlap and part). Already
## overlapping and closing = 0.
static func time_to_meet(p: Vector2, v_rel: Vector2, r: float) -> float:
	var a := v_rel.length_squared()
	var b := 2.0 * p.dot(v_rel)
	var c := p.length_squared() - r * r
	if c <= 0.0:
		return 0.0 if b < 0.0 else INF
	if a < 0.000001:
		return INF
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return INF
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 else INF


## What the asker did over an episode of `ticks` ticks: see the header.
static func asker_action(ticks: int, yield_ticks: int, reversed_ticks: int, max_lateral_m: float, stopped_ticks: int) -> String:
	if ticks <= 0:
		return "none"
	if yield_ticks * 2 > ticks:
		return "yielded"
	if reversed_ticks >= REVERSED_TICKS:
		return "reversed"
	if max_lateral_m > STEERED_M:
		return "steered"
	if stopped_ticks * 2 > ticks:
		return "stopped"
	return "slowed"


## The hull's flat yaw (radians) from its forward vector (-basis.z, flat).
static func yaw_of(forward: Vector3) -> float:
	return atan2(forward.x, forward.z)


## Degrees per second between two yaws `dt` seconds apart, the shortest way round.
static func yaw_rate_dps(yaw_then: float, yaw_now: float, dt: float) -> float:
	if dt <= 0.0:
		return 0.0
	return rad_to_deg(angle_difference(yaw_then, yaw_now)) / dt
