class_name UtilityCurves
extends RefCounted
## Response curves for utility considerations (Dave Mark's IAUS; _agents/unit_ai.md §1). Each maps an input
## to 0..1. A behavior's score is the product of its considerations, corrected by compensate() for how many
## there are, times the behavior's weight. Pure and static.


## 0 at `from`, 1 at `to` (either order), clamped.
static func linear(x: float, from: float, to: float) -> float:
	if is_equal_approx(from, to):
		return 1.0 if x >= to else 0.0
	return clampf((x - from) / (to - from), 0.0, 1.0)


## linear() raised to `power`: > 1 stays low until close to `to`, < 1 rises early.
static func power_curve(x: float, from: float, to: float, power: float) -> float:
	return pow(linear(x, from, to), power)


## A smooth S from 0 at `from` to 1 at `to` (Hermite smoothstep).
static func smooth(x: float, from: float, to: float) -> float:
	var t := linear(x, from, to)
	return t * t * (3.0 - 2.0 * t)


## A plateau: 1 between `low` and `high`, falling smoothly to 0 over `soft` outside them ("preferred range").
static func band(x: float, low: float, high: float, soft: float) -> float:
	if x < low:
		return smooth(x, low - soft, low)
	if x > high:
		return 1.0 - smooth(x, high, high + soft)
	return 1.0


## Scale a value into [floor, 1] so a weak consideration dampens instead of vetoing.
static func floor_at(value: float, floor_value: float) -> float:
	return lerpf(floor_value, 1.0, clampf(value, 0.0, 1.0))


## IAUS compensation: a product of `count` considerations shrinks as count grows; this adds back part of
## what was lost so behaviors with more considerations aren't penalized for being thorough.
static func compensate(product: float, count: int) -> float:
	if count <= 1:
		return product
	var make_up := (1.0 - product) * (1.0 - 1.0 / count)
	return product + make_up * product
