class_name FloatProbe
extends RefCounted
## Control experiment for the N2 verdict: are FLOATS themselves reproducible across builds?
## Iterates chaotic float recurrences (tiny differences grow exponentially, so any bit of
## disagreement shows up in the hash) and hashes the raw bits:
##   basic  only + − × ÷ and sqrt (IEEE 754 requires these to be correctly rounded everywhere)
##   trig   adds sin, cos, atan2, exp (library functions: each platform's libm may round differently)
## `make det-spike` prints both for native and WebAssembly.


static func run(kind: String, steps: int) -> String:
	var bytes := PackedFloat64Array()
	var x := 0.1234567
	var y := 0.7654321
	var z := 1.5
	for i in steps:
		if kind == "basic":
			x = 3.99 * x * (1.0 - x)  # logistic map: chaotic
			y = fmod(y * 1.7 + x / (z + 0.5), 1.0)
			z = sqrt(z * z + x * y) * 0.999 + 0.001
		else:
			x = 3.99 * x * (1.0 - x)
			y = fmod(absf(sin(y * 12.9898 + x) * 43758.5453), 1.0)
			z = atan2(y - 0.5, x - 0.5) + cos(z) * 0.5 + exp(-z * z)
		if i % 64 == 0:
			bytes.append_array(PackedFloat64Array([x, y, z]))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes.to_byte_array())
	return hashing.finish().hex_encode().left(16)
