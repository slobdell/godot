class_name ShowChannel
extends RefCounted
## S6: one channel of the arena light show — a named signal computed once per frame on the CPU and pushed as ONE
## write ([Show]). See [url=res://_agents/lighting.md]_agents/lighting.md[/url] for the vocabulary; this file is the
## whole of the maths.
##
## A channel packs into one vec4, and every shader in the venue reads it through the single shared function in
## `game/theme/fx/shaders/show.gdshaderinc`:
## [codeblock]
##     chan = (floor, span, clock, sharpness)
##     show_value(chan, phase) = chan.x + chan.y * pow(max(0.5 + 0.5 * sin(chan.z + phase), 1e-4), chan.w)
## [/codeblock]
## [method level] below is the same line in GDScript, at `phase = 0`. That equality is the contract between the two
## implementations and [code]tests/test_show_channels.gd[/code] asserts it, so the headless test documents the GPU.
##
## `phase` is the PER-INSTANCE offset and never comes from here: it is data the mesh already carries (a block's seed
## in COLOR.g, the rim's angle in world space, a sign's INSTANCE_CUSTOM.a). That is why eight blocks breathe on eight
## clocks from one uniform write, and why the per-frame cost is O(patch entries) and never O(instances).
##
## Visual only. Frame time, never the tick. Nothing here reads the simulation.

## Programme -> its default sharpness (the exponent on the raised sine). `hold` also forces span to 0.
## `breathe` is the idle; `sweep` a wide wave; `chase` a travelling pulse; `strobe` a short stab (cues only);
## `cycle` a breathe that also walks a colour.
const PROGRAMMES := {
	&"hold": 1.0,
	&"breathe": 1.0,
	&"sweep": 3.0,
	&"chase": 8.0,
	&"strobe": 40.0,
	&"cycle": 1.0,
}
## Periods outside this band are refused by the validator: faster reads as alarm-blinking, slower as static
## (widget spec section 3). A cue may drive a channel faster for a moment; a PATCH may not declare one.
const PERIOD_MIN_S := 10.0
const PERIOD_MAX_S := 25.0
## Two periods are "commensurate" (the ensemble visibly loops) when their ratio lands this close to p/q for small
## integers. 2% is tight enough to catch 5:4 dressed up as 1.2543, and the limit is 5 rather than 4 because 5:4 is
## audibly and visibly a small ratio -- at 4 this check passed a 24.4 : 19.9 pair that is 5:4 to within 2 parts in a
## thousand, which is a bank that visibly re-syncs every couple of minutes.
const COMMENSURATE_TOLERANCE := 0.02
const SMALL_INTEGER := 5

var channel_name := &""
var programme := &"breathe"
var period := 17.0
var phase := 0.0
## The level the fixture never falls below. > 0 for anything driving a core surface: a rim that goes fully dark reads
## as broken, not idle (lighting.md rule 5).
var level_floor := 0.0
var level_ceiling := 1.0
var sharpness := 1.0
## A colour cue's target and how far towards it the fixture goes (0 = the fixture's own colour, the default).
var color := Color(0, 0, 0)
var color_mix := 0.0
## Absorbs a period change so the clock never JUMPS, only changes rate (see [method retune]). Zero while no cue has
## touched this channel, which is what keeps an idle show a pure function of frame time -- the property
## `make show-frames` relies on to give the same strip on any machine.
var clock_offset := 0.0
## The SPATIAL half of a programme, for a fixture whose instances have a position the shader knows (the windows of a
## city block, round 10): (radians per storey, radians per metre along the facade, scatter 0..1 of TAU by the
## instance's hash, clock-rate jitter 0..1). Zero is "every instance on the block's own phase", i.e. no wave. Written
## beside the channel as `<uniform>_wave`, and only on a frame where it changed.
var wave := Vector4.ZERO


static func from_data(name: StringName, data: Dictionary) -> ShowChannel:
	var channel := ShowChannel.new()
	channel.channel_name = name
	channel.programme = StringName(str(data.get("programme", "breathe")))
	channel.period = float(data.get("period", 17.0))
	channel.phase = float(data.get("phase", 0.0))
	channel.level_floor = float(data.get("floor", 0.0))
	channel.level_ceiling = float(data.get("ceiling", 1.0))
	channel.sharpness = float(data.get("sharpness", PROGRAMMES.get(channel.programme, 1.0)))
	if data.has("color"):
		channel.color = Color(str(data["color"]))
	channel.color_mix = float(data.get("color_mix", 1.0 if data.has("color") else 0.0))
	if data.has("wave"):
		channel.wave = ShowChannel.wave_from(data["wave"])
	if channel.programme == &"hold":
		# A hold IS a floor equal to its ceiling. Saying it in the data rather than as a special case in span() is
		# what lets a cue blend in and out of a hold without the span popping halfway through the ramp.
		channel.level_floor = channel.level_ceiling
	return channel


func duplicate_channel() -> ShowChannel:
	var copy := ShowChannel.new()
	copy.channel_name = channel_name
	copy.programme = programme
	copy.period = period
	copy.phase = phase
	copy.level_floor = level_floor
	copy.level_ceiling = level_ceiling
	copy.sharpness = sharpness
	copy.color = color
	copy.color_mix = color_mix
	copy.clock_offset = clock_offset
	copy.wave = wave
	return copy


## A wave from data: {"row": rad/storey, "along": rad/m, "scatter": 0..1, "jitter": 0..1}, every key optional.
static func wave_from(data: Variant) -> Vector4:
	if typeof(data) != TYPE_DICTIONARY:
		return Vector4.ZERO
	var d: Dictionary = data
	return Vector4(float(d.get("row", 0.0)), float(d.get("along", 0.0)), float(d.get("scatter", 0.0)),
			float(d.get("jitter", 0.0)))


## Change the period at frame time `t` without moving the clock: the offset takes up the discontinuity exactly, so
## a cue speeding the rim up from a 24 s breathe to a 6 s chase is a change of RATE and never a tear.
func retune(new_period: float, t: float) -> void:
	var before := clock(t)
	period = maxf(new_period, 0.0001)
	clock_offset += before - clock(t)


## The channel's own clock in radians at frame time `t`. A programme swap changes the RATE, never jumps this value,
## which is why a cue can change programme without the fixture tearing.
func clock(t: float) -> float:
	return TAU * t / maxf(period, 0.0001) + phase + clock_offset


## `ceiling - floor`. Zero for a `hold`, because a hold's floor IS its ceiling.
func span() -> float:
	return level_ceiling - level_floor


## The vec4 pushed to the shader: (floor, span, clock, sharpness).
func packed(t: float) -> Vector4:
	return Vector4(level_floor, span(), clock(t), maxf(sharpness, 0.0001))


## The bank-wide level at frame time `t` — the same line the shader runs at `phase = 0`. Pure: same `t`, same value,
## no per-frame state. This is the property the show's "never reads the clock in a decision" test rests on.
func level(t: float) -> float:
	return level_at(packed(t), 0.0)


## The smallest base `pow` is ever given. `0.5 + 0.5 * sin(x)` is mathematically in [0, 1] but touches EXACTLY 0 at
## the trough and can land a hair below it in float, and `pow` is undefined for a negative base and for `pow(0, 0)`.
## Mesa, Adreno and ANGLE disagree about what undefined means, so this is the class of bug that only appears on the
## lead's phone (feel, 2026-09-20). The shader clamps identically.
const BASE_MIN := 1e-4


## The shared waveform, in GDScript. Must stay identical to `show_value()` in show.gdshaderinc.
static func level_at(chan: Vector4, instance_phase: float) -> float:
	var x := maxf(0.5 + 0.5 * sin(chan.z + instance_phase), BASE_MIN)
	return chan.x + chan.y * pow(x, chan.w)


## "" or why this channel's data is wrong, named so a reader can fix it without opening the code.
func problem() -> String:
	if not PROGRAMMES.has(programme):
		return "channel '%s': unknown programme '%s' (have %s)" % [channel_name, programme,
				", ".join(PackedStringArray(PROGRAMMES.keys()))]
	if period < PERIOD_MIN_S or period > PERIOD_MAX_S:
		return "channel '%s': period %.1f s is outside %.0f-%.0f s (faster reads as alarm-blinking, slower as static)" \
				% [channel_name, period, PERIOD_MIN_S, PERIOD_MAX_S]
	if level_floor < 0.0 or level_ceiling < level_floor:
		return "channel '%s': floor %.2f and ceiling %.2f must satisfy 0 <= floor <= ceiling" \
				% [channel_name, level_floor, level_ceiling]
	if sharpness <= 0.0:
		return "channel '%s': sharpness must be positive" % channel_name
	return ""


## "" or why these periods would make the ensemble visibly loop. The widget spec's rule: pairwise incommensurate, no
## small integer ratios. `periods` is {name: seconds}.
static func commensurate_problem(periods: Dictionary, tolerance := COMMENSURATE_TOLERANCE) -> String:
	var names: Array = periods.keys()
	names.sort()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a := float(periods[names[i]])
			var b := float(periods[names[j]])
			if a <= 0.0 or b <= 0.0:
				continue
			var ratio := maxf(a, b) / minf(a, b)
			for p in range(1, SMALL_INTEGER + 1):
				for q in range(1, SMALL_INTEGER + 1):
					var target := float(p) / float(q)
					if target < 1.0 or absf(ratio - target) > tolerance * target:
						continue
					return "periods %.2f s ('%s') and %.2f s ('%s') are %d:%d within %.0f%% — the ensemble will visibly loop" \
							% [a, names[i], b, names[j], p, q, tolerance * 100.0]
	return ""


## "" or why these phases are bunched. Geometrically parallel fixtures on bunched phases read as a loading indicator
## rather than as current (widget spec section 3). `phases` is {name: radians}; the bar is half of even spacing.
static func phase_spread_problem(phases: Dictionary) -> String:
	if phases.size() < 2:
		return ""
	var names: Array = phases.keys()
	var sorted: Array = []
	for name in names:
		sorted.append([fposmod(float(phases[name]), TAU), name])
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var bar := TAU / (2.0 * sorted.size())
	for i in sorted.size():
		var here: float = sorted[i][0]
		var next: float = sorted[(i + 1) % sorted.size()][0] + (TAU if i == sorted.size() - 1 else 0.0)
		if next - here < bar:
			return "phases %.2f ('%s') and %.2f ('%s') are %.2f rad apart, under the %.2f rad bar — they will pulse together" \
					% [here, sorted[i][1], fposmod(next, TAU), sorted[(i + 1) % sorted.size()][1], next - here, bar]
	return ""
