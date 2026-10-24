extends TestCase
## Round 39 (native N4): the engine's float trig is the correctly rounded one on every machine. glibc >= 2.41 (the
## builders) has it in libm; an older glibc (the laptop's 2.39) gets it from mk/native.mk's LD_PRELOAD of
## native/src/trig (CORE-MATH). Vector2.angle() is the engine's atan2f (real_t float). The case is an input where glibc
## 2.39 answers one ulp low (`make trig-check`'s first atan2f difference on the laptop): it fails on a laptop run outside
## make (no preload) or with TRIG=system, and nowhere else. _agents/native.md "Machine-independent trig".


static func _f(bits: int) -> float:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, bits)
	return b.decode_float(0)


static func _bits(value: float) -> int:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, value)
	return b.decode_u32(0)


func test_engine_atan2f_is_correctly_rounded() -> void:
	# atan2f(0x1.8cc522p+104, -0x1.09e8d2p-37): correctly rounded 0x1.921fb6p+0 (0x3fc90fdb); glibc 2.39 0x1.921fb4p+0.
	var angle := Vector2(_f(0xad04f469), _f(0x73c66291)).angle()
	assert_eq("%08x" % _bits(angle), "3fc90fdb",
			"Vector2.angle() is the correctly rounded atan2f (3fc90fda = this machine's old libm: run through make, or TRIG=cr)")


func test_double_trig_untouched() -> void:
	# GDScript's own atan2 is the double function, the same on every glibc; the preload replaces only the float five.
	assert_eq(atan2(1.0, 1.0), PI / 4.0, "atan2(1, 1) is pi/4 in double")
