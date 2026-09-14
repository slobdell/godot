class_name Fixed
extends RefCounted
## Deterministic integer math for the lockstep spike (netcode phase N2). No floats anywhere:
## every platform (native x86-64, WebAssembly, ARM phones) computes bit-identical results.
##
## Numbers are Q16.16 fixed point in GDScript's 64-bit ints: 65536 means 1.0 meter.
## Angles are "binary angle" units: 65536 per full turn, counter-clockwise from +x.
## Trig uses integer CORDIC with constants baked below (never libm sin/cos, which differ per platform).
##
## Keep products inside int64: |a|, |b| < 2^31 (±32768 m) before mul.

const ONE := 65536
const HALF := 32768
const TURN := 65536
const HALF_TURN := 32768
const QUARTER_TURN := 16384

## atan(2^-i) in 2^32-per-turn units, i = 0..27 (computed offline, see _agents/streams/archive/round1/netcode.md N2).
const ATAN_BAM32 := [536870912, 316933406, 167458907, 85004756, 42667331, 21354465, 10679838, 5340245,
		2670163, 1335087, 667544, 333772, 166886, 83443, 41722, 20861, 10430, 5215, 2608, 1304, 652, 326,
		163, 81, 41, 20, 10, 5]
## CORDIC gain compensation: prod(1/sqrt(1 + 2^-2i)) in Q30.
const CORDIC_K_Q30 := 652032874
const ITERATIONS := 28


static func from_int(value: int) -> int:
	return value * ONE


## Q16.16 × Q16.16. Arithmetic shift floors toward −∞ identically on every two's-complement target.
static func mul(a: int, b: int) -> int:
	return (a * b) >> 16


## Q16.16 ÷ Q16.16, truncating toward zero. b must not be 0.
static func div(a: int, b: int) -> int:
	return (a << 16) / b


## Wrap an angle into [−HALF_TURN, HALF_TURN).
static func wrap_angle(angle: int) -> int:
	return ((angle + HALF_TURN) & (TURN - 1)) - HALF_TURN


## Integer square root: floor(sqrt(n)) for n ≥ 0.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


## Length of a Q16.16 vector, in Q16.16.
static func length(x: int, y: int) -> int:
	return isqrt(x * x + y * y)


## [cos, sin] of a binary angle, each in Q16.16.
static func cos_sin(angle: int) -> Array[int]:
	var a := angle & (TURN - 1)
	var flip := false
	if a > QUARTER_TURN and a < 3 * QUARTER_TURN:
		a -= HALF_TURN
		flip = true
	elif a >= 3 * QUARTER_TURN:
		a -= TURN
	var z := a << 16
	var x := CORDIC_K_Q30
	var y := 0
	for i in ITERATIONS:
		var dx := x >> i
		var dy := y >> i
		if z >= 0:
			x -= dy
			y += dx
			z -= ATAN_BAM32[i]
		else:
			x += dy
			y -= dx
			z += ATAN_BAM32[i]
	x >>= 14
	y >>= 14
	if flip:
		return [-x, -y]
	return [x, y]


## Binary angle of the vector (x, y) (any consistent units), in [0, TURN).
static func atan2(y: int, x: int) -> int:
	if x == 0 and y == 0:
		return 0
	var base := 0
	if x < 0:
		x = -x
		y = -y
		base = HALF_TURN
	# Scale up for precision; CORDIC gain (~1.65) stays well inside int64.
	var big := maxi(absi(x), absi(y))
	while big < (1 << 28):
		x <<= 1
		y <<= 1
		big <<= 1
	while big >= (1 << 40):
		x >>= 1
		y >>= 1
		big >>= 1
	var z := 0
	for i in ITERATIONS:
		var dx := x >> i
		var dy := y >> i
		if y > 0:
			x += dy
			y -= dx
			z += ATAN_BAM32[i]
		else:
			x -= dy
			y += dx
			z -= ATAN_BAM32[i]
	return (base + (z >> 16)) & (TURN - 1)
