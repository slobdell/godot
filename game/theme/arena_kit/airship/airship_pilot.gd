class_name AirshipPilot
extends RefCounted
## The broadcast airship's flight model: a PID rudder on a body with deliberately high rotational inertia, chasing a
## carrot that circles wherever the fight is. Round 11, the lead: *"it's just moving in straight lines. We need to
## invest whatever effort necessary to make it appear floating … and splining or circling behavior throughout the
## match. Also the airship should ideally generally fly to where the action is … I think the airship would have its
## own PID controller to try to fly the path of a target spline, and since it's an airship, slightly bad PID tunes
## might create a realistic effect for high rotational inertia."*
##
## That last sentence is the design. The gains below are NOT critically damped and that is the point: a 57 m gas bag
## does not point where it is told, it leans into the correction, overshoots, and wallows back. Tuning this to
## perfection would make it look like a camera drone.
##
## WHY IT IS A SEPARATE, PURE-ISH OBJECT. Round 9's rule is that the airship is posed from the FIXED tick and never
## the wall clock, so the same match looks the same at 30 fps and at 144. A PID is an integrator and cannot be a pure
## function of a tick -- so instead it is stepped exactly once per fixed tick, from a known start, by an object with
## no scene, no node and no clock of its own. Given the same tick sequence and the same goals it produces the same
## flight, it can be simulated thousands of ticks ahead in a test without a match, and `step()` is the only way its
## state ever changes.
##
## Honest limit: the goals come from the live match (where the units are), and a dressing rebuild mid-match restarts
## the pilot, which then re-converges rather than resuming. Frame-rate independence holds; bit-exact replay after a
## mid-match rebuild does not, and nothing in the simulation depends on either.

## --- the airframe -------------------------------------------------------------------------------------------
## Rotational inertia in "rudder units per rad/s^2". High: this is the number that makes it an airship and not a
## quadcopter. Doubling it roughly doubles how long a turn takes to start AND to stop.
const YAW_INERTIA := 9.0
## Aerodynamic damping on yaw, and it is LOW on purpose. This is the single number that decides whether the hull
## wallows or glides, and the first tune got it wrong: at 0.55 the closed loop came out at zeta = 1.01 -- critically
## damped, gliding onto every heading without ever crossing it, which is the opposite of what was asked for. The
## damping ratio of the whole loop is (KD/YAW_INERTIA + YAW_DAMPING) / (2 * sqrt(KP/YAW_INERTIA)); at 0.12 that is
## **zeta = 0.38**, which overshoots a 40 deg correction by 12.5 deg, crosses back twice, and settles in about 5 s.
const YAW_DAMPING := 0.12
## The most rudder the hull can carry, and the most yaw rate the envelope will take.
const MAX_RUDDER := 1.0
## A SAFETY limit, not the operating point. The first tune had it at 0.22 rad/s, which the rudder saturated on every
## correction -- and a rate-limited turn slews to its heading and stops dead, so the hull could not overshoot however
## the gains were set. Keep this comfortably above the yaw rate a normal correction reaches (~0.25 rad/s).
const MAX_YAW_RATE := 0.30
## Cruise, and how much a hard turn costs it -- an airship scrubs speed in a turn.
const CRUISE_MPS := 7.5
const TURN_DRAG := 1.9
const ACCEL_MPS2 := 0.35
## A turning airship slips sideways: the hull is a sail. Fraction of forward speed pushed along the outward normal.
const SIDESLIP := 0.55

## --- the PID, deliberately under-damped ---------------------------------------------------------------------
## Kp alone would oscillate forever; Kd is what stops it, and it is set LOW on purpose so the hull overshoots a
## heading change by a few degrees and comes back. Ki is small and clamped: it exists to kill the steady-state bias a
## constant crosswind-like sideslip would otherwise leave, not to chase precision.
const KP := 1.35
const KI := 0.06
const KD := 1.60
const I_CLAMP := 0.6

## --- the path -----------------------------------------------------------------------------------------------
## It does not fly AT the action, it circles it: flying at it would park a 57 m hull on top of the fight and its
## belly cannot go that low (see SyndicateAdAirship.belly floor). The carrot is a point on that circle, this far
## around it -- big enough that the hull leads its turn, small enough that it does not cut the corner.
const ORBIT_RADIUS := 62.0
const CARROT_LEAD_RAD := 0.55
## Outside this the airship stops circling and just goes there, so a fight moving across the map is followed.
const APPROACH_AT := 1.45
## Which way round. Fixed, because a hull that reverses its circling direction reads as indecision, not drift.
const ORBIT_SIGN := 1.0
## Where the containment starts biting, as a fraction of the play radius. Inside this the airship is left alone.
const CONTAIN_FROM := 0.72

var position := Vector2.ZERO
var heading := 0.0
var yaw_rate := 0.0
var speed := CRUISE_MPS
## Bank angle (roll), lagged behind yaw rate so the hull leans into a turn late and comes out of it late.
var bank := 0.0
var _integral := 0.0
var _previous_error := 0.0
var _has_error := false


func reset(at: Vector2, facing: float) -> void:
	position = at
	heading = facing
	yaw_rate = 0.0
	speed = CRUISE_MPS
	bank = 0.0
	_integral = 0.0
	_previous_error = 0.0
	_has_error = false


## One fixed tick. `goal` is where the carrot is right now, in XZ metres.
func step(dt: float, goal: Vector2) -> void:
	var to_goal := goal - position
	if to_goal.length_squared() < 0.0001:
		return
	# Godot's forward is -Z, so a node at heading h points (-sin h, -cos h) in XZ. Getting this backwards is not a
	# subtle bug: the hull flies its whole route in reverse, nose pointing where it has been. It did, and the lead
	# saw it. `heading_toward` and `forward_of` are the only two places the convention lives.
	var wanted := heading_toward(to_goal)
	var error := wrapf(wanted - heading, -PI, PI)
	# A derivative on the FIRST step has no previous error to work from, and seeding it with zero produces a kick
	# that looks like the airship flinching as it spawns.
	var derivative := (error - _previous_error) / dt if _has_error else 0.0
	_previous_error = error
	_has_error = true
	_integral = clampf(_integral + error * dt, -I_CLAMP, I_CLAMP)
	var rudder := clampf(KP * error + KI * _integral + KD * derivative, -MAX_RUDDER, MAX_RUDDER)
	# The body: rudder torque against inertia, then damping. This is where the weight comes from -- and the torque
	# scales with SPEED, because a rudder with no flow over it does nothing. The lead: *"I saw some stationary yaw.
	# It would be more realistic to yaw more like a boat."* Exactly so: without this term the hull can pivot on the
	# spot like a turret, which no vessel with a rudder can do. It also closes a nice loop with TURN_DRAG -- a hard
	# turn scrubs speed, which costs rudder authority, which limits the turn.
	var flow := clampf(speed / CRUISE_MPS, 0.0, 1.2)
	var yaw_accel := rudder * flow / YAW_INERTIA - YAW_DAMPING * yaw_rate
	yaw_rate = clampf(yaw_rate + yaw_accel * dt, -MAX_YAW_RATE, MAX_YAW_RATE)
	heading = wrapf(heading + yaw_rate * dt, -PI, PI)
	# Speed: cruise, less what the turn scrubs off.
	var wanted_speed := maxf(CRUISE_MPS - TURN_DRAG * absf(yaw_rate) / MAX_YAW_RATE * CRUISE_MPS * 0.25, CRUISE_MPS * 0.45)
	speed = move_toward(speed, wanted_speed, ACCEL_MPS2 * dt)
	var forward := forward_of(heading)
	var right := Vector2(forward.y, -forward.x)
	# Forward travel plus the slip a sail-sided hull carries through a turn.
	position += (forward + right * (-yaw_rate / MAX_YAW_RATE) * SIDESLIP) * speed * dt
	# Roll lags the turn: 2.2 s to settle, so the lean arrives after the turn has begun.
	var wanted_bank := clampf(-yaw_rate / MAX_YAW_RATE, -1.0, 1.0)
	bank = lerpf(bank, wanted_bank, clampf(dt / 2.2, 0.0, 1.0))


## The heading that points along `direction`, in Godot's -Z-forward convention. Pure.
static func heading_toward(direction: Vector2) -> float:
	return atan2(-direction.x, -direction.y)


## The unit XZ direction a hull at `heading` is pointing. The inverse of `heading_toward`. Pure.
static func forward_of(heading: float) -> Vector2:
	return Vector2(-sin(heading), -cos(heading))


## Where the carrot sits for an airship at `from` circling `centre`: a point `CARROT_LEAD_RAD` further round the
## orbit, or the centre itself while it is still a long way out. Pure, so the path can be drawn and tested.
static func carrot(from: Vector2, centre: Vector2, radius := ORBIT_RADIUS) -> Vector2:
	var offset := from - centre
	var distance := offset.length()
	if distance < 0.001:
		return centre + Vector2(radius, 0.0)
	if distance > radius * APPROACH_AT:
		# Far out: aim at the near edge of the circle rather than its middle, so arrival is already tangential and
		# the hull slides onto the orbit instead of hitting the centre and having to turn round.
		return centre + offset / distance * radius
	var angle := atan2(offset.y, offset.x) + CARROT_LEAD_RAD * ORBIT_SIGN
	return centre + Vector2(cos(angle), sin(angle)) * radius


## The carrot, pushed away from anything the hull must not fly into. `blockers` is [{x, z, radius}] in metres; the
## push is soft and falls off with distance so it bends the path rather than kinking it.
static func avoid(goal: Vector2, from: Vector2, blockers: Array, clearance: float) -> Vector2:
	var out := goal
	for blocker: Dictionary in blockers:
		var at := Vector2(float(blocker["x"]), float(blocker["z"]))
		var keep := float(blocker["radius"]) + clearance
		var offset := from - at
		var distance := offset.length()
		if distance > keep * 2.0 or distance < 0.001:
			continue
		# Full push at the edge of the keep-out, nothing at twice that.
		var strength := clampf((keep * 2.0 - distance) / keep, 0.0, 1.0)
		out += offset / distance * keep * strength
	return out


## The goal, pulled back inside the arena. Without this the airship leaves the map: the orbit carries it outward,
## `avoid` pushes it further out whenever it passes a perimeter floodlight, and nothing was pulling the other way --
## the lead watched it *"fly into the crowd and disappear"*, which is exactly what is beyond the wall (the venue
## stands sit just outside `half_size`). The pull is gradual from CONTAIN_FROM and absolute past the edge, so it
## reads as the hull declining to leave rather than as a wall it bounces off.
static func contain(goal: Vector2, from: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return goal
	var out := from.length()
	if out <= radius * CONTAIN_FROM:
		return goal
	var result := goal
	if out >= radius:
		result = Vector2.ZERO  # past the edge: forget the orbit, come home
	else:
		var pull := (out - radius * CONTAIN_FROM) / (radius * (1.0 - CONTAIN_FROM))
		result = goal.lerp(Vector2.ZERO, clampf(pull, 0.0, 1.0))
	# ...and the carrot NEVER points outside the arena, whatever `avoid` wanted. The gradual pull alone was not
	# enough: near a perimeter floodlight the avoidance push outward beat the containment lerp inward and the hull
	# left the map anyway. A goal it can never chase past the wall is the property that actually holds.
	if result.length() > radius * 0.9:
		result = result.normalized() * radius * 0.9
	return result


## How much room a heavy hull needs to TRACK its orbit: the PID lags, so the circle it actually flies is wider than
## the one it is given. The orbit centre is kept this much further in than the geometry alone would need, because
## without it the orbit touches the containment radius exactly and the tracking error puts the hull through the wall
## (measured: 141.1 m on a 140 m map).
const TRACK_MARGIN := 20.0
