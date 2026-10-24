/* native/trig/tank_trig.c (round 39, N4): the five float trig functions whose results differ between glibc 2.39 (the
 * laptop) and >= 2.41 (the builders: CORE-MATH, correctly rounded), defined over the vendored CORE-MATH sources so every
 * machine computes the correctly rounded result, the builders' result, bit for bit. _agents/native.md "Machine-independent
 * trig". Built two ways from this one file:
 *   - inside libtank_native (CMakeLists.txt, TANK_TRIG_HIDDEN): hidden definitions, so the library's own calls (godot-cpp's
 *     Math::atan2 etc.) bind here at link time on every machine, whatever libm the box has (no PLT, no DEEPBIND question);
 *   - as $(TOOLS_DIR)/trig/libtank_trig-<sha>.so (mk/native.mk), exported and LD_PRELOADed into the ENGINE on a machine
 *     whose glibc is older than 2.41, so Godot's own float math (Vector2.angle_to, ...) matches the builders too.
 * Every other libm function the engine and native import is already the same on 2.39 and 2.43 (trig_check digest). */
float cr_atan2f(float, float);
float cr_acosf(float);
float cr_asinf(float);
float cr_atanf(float);
float cr_tanf(float);

#ifdef TANK_TRIG_HIDDEN
#define TANK_TRIG_API __attribute__((visibility("hidden")))
#else
#define TANK_TRIG_API __attribute__((visibility("default")))
#endif

TANK_TRIG_API float atan2f(float y, float x) { return cr_atan2f(y, x); }
TANK_TRIG_API float acosf(float x) { return cr_acosf(x); }
TANK_TRIG_API float asinf(float x) { return cr_asinf(x); }
TANK_TRIG_API float atanf(float x) { return cr_atanf(x); }
TANK_TRIG_API float tanf(float x) { return cr_tanf(x); }
