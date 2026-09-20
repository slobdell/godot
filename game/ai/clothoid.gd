class_name Clothoid
extends RefCounted
## A4 (round 9, nav; catalogue row A4 — Fraichard & Scheuer 2004, *From Reeds and Shepp's to Continuous-Curvature
## Paths*, IEEE T-RO 20(6)): curvature LINEAR in arc length, so the steering rate is bounded and no join demands an
## instantaneous steering change.
##
## Why this and not Reeds-Shepp, which `algorithms.md` parked: Reeds-Shepp concatenates arcs and straight lines, so a
## car-like hull must change steering angle instantaneously at every join. Our plant expresses that as exactly the
## visible correction the lead complains about. Both external reviews said so independently (research_catalog.md
## Part 1 section 5), and it is the *forward* argument — the reason the park stands is no longer "its evidence was an
## angle-wrap bug in our own reporter".
##
## **Determinism (the row's own constraint): the Fresnel integrals come from a FIXED-SIZE lookup table with
## fixed-order interpolation, never a series evaluated to a tolerance.** A series that stops when it is "close
## enough" takes a different number of steps on different inputs and is exactly the kind of thing that makes two
## machines disagree. The table is built once, with a fixed step count, from arithmetic that is the same everywhere.

## Samples over [0, X_MAX] of the Fresnel integrals. 513 = 2^9 + 1 so the interval count is a power of two and
## Simpson's rule divides it exactly.
const SAMPLES := 513
const X_MAX := 5.0
## Simpson sub-intervals per table step. Fixed: never "until it converges".
const SUB_STEPS := 8


static var _c := PackedFloat32Array()
static var _s := PackedFloat32Array()


## C(x) and S(x), the Fresnel integrals in the normalised form C(x) = int_0^x cos(pi t^2 / 2) dt (and sin for S).
## Odd in x. Beyond X_MAX both are clamped rather than extrapolated — an honest flat answer beats a confident wrong
## one off the end of a table. **Be precise about what that costs:** C and S approach 1/2 only in the limit and get
## there by spiralling, so at x = X_MAX the value is still ~0.564, a 13% ripple — NOT "far below anything this
## consumer can see", which is what this comment said until a test caught it. It does not matter here because the
## consumer never goes near the end: an arrival clothoid evaluates at `length / sqrt(PI / sharpness)`, which for a
## 20 m approach is about 1.0. It would matter to any caller that reached X_MAX, and that caller should not clamp.
static func fresnel(x: float) -> Vector2:
	if x < 0.0:
		return -fresnel(-x)
	_build()
	if x >= X_MAX:
		return Vector2(_c[SAMPLES - 1], _s[SAMPLES - 1])
	var step := X_MAX / float(SAMPLES - 1)
	var at := x / step
	var i := int(at)
	var t := at - float(i)
	# Fixed-order (linear) interpolation between two table entries. One multiply and one add per component.
	return Vector2(_c[i] + (_c[i + 1] - _c[i]) * t, _s[i] + (_s[i + 1] - _s[i]) * t)


## Where a clothoid ends up, in its OWN frame: it starts at the origin heading +X with zero curvature, and its
## curvature grows linearly at `sharpness` (rad/m per metre) over `length` metres. Returns the offset as
## (along, across) in metres, with `across` positive to the left.
##
## Zero initial curvature is not a simplification we are hiding: it is the arrival case exactly. A hull comes off a
## straight route (curvature 0) and has to be pointing a given way by the time it reaches the goal, which is the one
## place round 8's arrival arc drives a straight run-in today.
static func offset(sharpness: float, length: float) -> Vector2:
	if absf(sharpness) < 0.000001 or length <= 0.0:
		return Vector2(length, 0.0)
	# theta(u) = sharpness * u^2 / 2, so the integral is the Fresnel pair scaled by sqrt(pi / sharpness).
	var magnitude := absf(sharpness)
	var scale := sqrt(PI / magnitude)
	var pair := fresnel(length / scale)
	return Vector2(pair.x * scale, pair.y * scale * signf(sharpness))


## The heading a clothoid has turned through over `length` (radians, positive to the left).
static func heading_change(sharpness: float, length: float) -> float:
	return sharpness * length * length * 0.5


## The sharpness that turns through `angle` radians over `length` metres — the inverse of `heading_change`, which is
## how a caller asks for "curve onto that heading in this much room" rather than guessing a sharpness.
static func sharpness_for(angle: float, length: float) -> float:
	if length <= 0.0:
		return 0.0
	return 2.0 * angle / (length * length)


## The peak curvature a clothoid reaches, so a caller can refuse one its hull cannot drive (1 / min_turn_radius_m).
static func peak_curvature(sharpness: float, length: float) -> float:
	return absf(sharpness) * length


static func _build() -> void:
	if not _c.is_empty():
		return
	var c := PackedFloat32Array()
	var s := PackedFloat32Array()
	c.resize(SAMPLES)
	s.resize(SAMPLES)
	c[0] = 0.0
	s[0] = 0.0
	var step := X_MAX / float(SAMPLES - 1)
	var h := step / float(SUB_STEPS)
	var sum_c := 0.0
	var sum_s := 0.0
	for i in range(1, SAMPLES):
		# Composite Simpson over this table step, a fixed SUB_STEPS of them, every time, for every entry.
		var x0 := float(i - 1) * step
		for k in SUB_STEPS:
			var a := x0 + float(k) * h
			var b := a + h
			var m := (a + b) * 0.5
			sum_c += h / 6.0 * (_cos_arg(a) + 4.0 * _cos_arg(m) + _cos_arg(b))
			sum_s += h / 6.0 * (_sin_arg(a) + 4.0 * _sin_arg(m) + _sin_arg(b))
		c[i] = sum_c
		s[i] = sum_s
	_c = c
	_s = s


static func _cos_arg(t: float) -> float:
	return cos(PI * t * t * 0.5)


static func _sin_arg(t: float) -> float:
	return sin(PI * t * t * 0.5)
