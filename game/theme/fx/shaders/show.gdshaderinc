// S6: the ONLY waveform in the game's lighting. Every fixture the arena light show drives reads its channel through
// this one function, and `ShowChannel.level_at()` in game/theme/show/channels.gd is the same line in GDScript --
// that equality is the contract between the two implementations, and tests/test_show_channels.gd asserts it.
//
// A channel arrives as one vec4, written once per frame by the CPU (game/theme/show/show.gd):
//     chan.x  floor      the level the fixture never falls below (a core surface never goes fully dark)
//     chan.y  span       ceiling - floor; 0 for a `hold` channel, which sits at chan.x
//     chan.z  clock      TAU * t / period + phase, in radians, advanced by the CPU from FRAME time
//     chan.w  sharpness  1 = breathe, ~3 sweep, ~8 chase, ~40 strobe
//
// `phase` is the PER-INSTANCE offset and never comes from the CPU: it is data the mesh already carries -- a block's
// seed in COLOR.g, the rim's angle in world space, a sign's INSTANCE_CUSTOM.a. That is why eight blocks breathe on
// eight clocks from ONE uniform write, and why the show costs O(patch entries) and never O(instances).
//
// Pass phase = 0.0 for the bank-wide value. Defaults everywhere are chosen so an unpatched fixture looks exactly as
// it did before the show existed: SHOW_IDENTITY is a constant 1.0, SHOW_OFF a constant 0.0.

// `pow` is undefined for a negative base and for pow(0, 0). `0.5 + 0.5 * sin(x)` is mathematically in [0, 1] but
// touches EXACTLY 0 at the trough and can land a hair below it in float, and Mesa, Adreno and ANGLE disagree about
// what undefined means -- the class of bug that only shows up on a phone (feel, 2026-09-20). Clamp, always.
const float SHOW_BASE_MIN = 1e-4;
// A parameter nothing is patched to: a constant multiplier of 1.0, i.e. today's look.
const vec4 SHOW_IDENTITY = vec4(1.0, 0.0, 0.0, 1.0);
// A parameter that is off until a patch drives it (the city blocks' edge emission, which does not exist today).
const vec4 SHOW_OFF = vec4(0.0, 0.0, 0.0, 1.0);

float show_value(vec4 chan, float phase) {
	float x = max(0.5 + 0.5 * sin(chan.z + phase), SHOW_BASE_MIN);
	return chan.x + chan.y * pow(x, chan.w);
}
