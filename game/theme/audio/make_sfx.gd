extends SceneTree
## Synthesizes the game's sound effects from scratch (no samples, no downloads) and writes 16-bit
## mono WAVs to assets/audio/. Deterministic: same seed, same files. Everything it makes is ours, so
## the output is dedicated CC0 (assets/audio/README.md).
##   make sfx   (godot --headless --script res://game/theme/audio/make_sfx.gd)

const RATE := 22050
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 1984
	_write("cannon_shot", _cannon_shot())
	_write("explosion_small", _explosion(0.7, 0.55, 900.0))
	_write("explosion_big", _explosion(1.5, 1.0, 600.0))
	_write("laser_pulse", _laser_pulse())
	_write("shield_hit", _shield_hit())
	_write("shield_down", _shield_down())
	_write("flame_loop", _flame_loop())
	_write("ui_blip", _blip(1400.0, 0.06))
	_write("ui_alert", _alert())
	_write("ui_tick", _tick())
	# Art X5 (appended so the seeded sounds above stay byte-identical).
	_write("crowd_murmur", _crowd_murmur())
	_write("crowd_cheer", _crowd_cheer())
	# Engines per unit type (art stretch). Loops exactly 1 s long with whole-cycle frequencies, so they're seamless.
	_write("engine_diesel", _engine(31.0, 0.55, 0.35, 0.0))
	_write("engine_v8", _engine(57.0, 0.9, 0.5, 0.0))
	_write("engine_electric", _engine(29.0, 0.45, 0.25, 0.6))
	# Feel (round 3): the new weapons. Each reseeds from its name, so adding one never changes another.
	_seeded("tank_boom", _tank_boom)
	_seeded("shell_whine", _shell_whine)
	_seeded("shell_hit_armor", _shell_hit_armor)
	_seeded("dirt_impact", _dirt_impact)
	_seeded("autocannon_shot", _autocannon_shot)
	_seeded("mg_round", _mg_round)
	_seeded("mortar_launch", _mortar_launch)
	_seeded("mg_loop", _mg_loop)
	_seeded("ricochet", _ricochet)
	_seeded("bullet_hit_metal", _bullet_hit_metal)
	_seeded("weak_spot_hit", _weak_spot_hit)
	_seeded("ui_ack_move", _ack_move)
	_seeded("ui_ack_attack", _ack_attack)
	_seeded("ui_select", _select_blip)
	# Audio (round 4, X4): variation pools. A machine gun firing eleven identical cracks a second is the single
	# most "Atari" thing in the mix, and pitch jitter alone does not hide it. These sounds now come in several
	# takes; SfxSystem picks one per shot. VARIANTS lists how many, and the pool includes the original file, so
	# nothing that already exists changes. Short sounds get more takes because they cost almost nothing.
	for sound in VARIANTS:
		_takes(sound, VARIANTS[sound])
	quit()


## How many extra takes each varied sound gets (on top of the original). Kept small for the long ones: the tank's
## boom is 2.8 s and by far the biggest file here.
const VARIANTS := {
	"mg_round": 3, "bullet_hit_metal": 3, "autocannon_shot": 2, "ricochet": 2, "shell_hit_armor": 2,
	"dirt_impact": 2, "explosion_small": 2, "weak_spot_hit": 1, "tank_boom": 1, "cannon_shot": 1,
}


## Extra takes of one sound, each from its own seed so the takes differ but never change run to run, and so adding
## a take to one sound never moves another.
func _takes(sound: String, count: int) -> void:
	var synths := {
		"mg_round": _mg_round, "bullet_hit_metal": _bullet_hit_metal, "autocannon_shot": _autocannon_shot,
		"ricochet": _ricochet, "shell_hit_armor": _shell_hit_armor, "dirt_impact": _dirt_impact,
		"weak_spot_hit": _weak_spot_hit, "tank_boom": _tank_boom, "cannon_shot": _cannon_shot,
	}
	for take in range(2, count + 2):
		rng.seed = hash(sound) + take * 7919
		var samples: PackedFloat32Array = _explosion(0.7, 0.55, 900.0) if sound == "explosion_small" \
				else (synths[sound] as Callable).call()
		_write("%s_%d" % [sound, take], samples)


func _seeded(sound: String, synth: Callable) -> void:
	rng.seed = hash(sound)
	_write(sound, synth.call())


func _write(name: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.89 / peak if peak > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	var path := ProjectSettings.globalize_path(OUT + name + ".wav")
	var err := stream.save_to_wav(path)
	print("sfx: %s %.2f s (%s)" % [name, samples.size() / float(RATE), error_string(err)])


func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


## Deep thump (pitch-dropping sine) + a lowpassed noise crack: a heavy cannon.
func _cannon_shot() -> PackedFloat32Array:
	var out := _buffer(0.6)
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var freq := 38.0 + 90.0 * exp(-t * 18.0)
		phase += TAU * freq / RATE
		# tanh saturation adds audible harmonics: phone speakers can't play the 40–80 Hz fundamental.
		var thump := tanh(sin(phase) * 4.0) * exp(-t * 7.0) * 0.8
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * clampf(0.6 * exp(-t * 6.0) + 0.04, 0.0, 1.0)
		var crack := low * exp(-t * 9.0) * 2.6
		out[i] = thump * 0.9 + crack
	return out


## Noise through a closing lowpass with a sub rumble and a crackle tail.
func _explosion(seconds: float, rumble: float, cutoff: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	var low := 0.0
	var mid_low := 0.0
	var mid := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var envelope := minf(1.0, t * 80.0) * exp(-t * 3.2 / seconds)
		var a := clampf(TAU * cutoff * exp(-t * 2.5) / RATE, 0.005, 1.0)
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * a
		# A 250–1500 Hz band: the part of the blast a phone speaker actually plays.
		mid_low += (noise - mid_low) * 0.35
		mid += (mid_low - mid) * 0.07
		phase += TAU * (45.0 - 15.0 * t / seconds) / RATE
		var crackle := (rng.randf_range(-1.0, 1.0) if rng.randf() < 0.004 * (1.0 - t / seconds) else 0.0) * 0.6
		var body := tanh(sin(phase) * 3.0) * rumble * 0.5
		out[i] = (low * 2.2 + (mid_low - mid) * 1.6 * exp(-t * 4.0 / seconds) + body) * envelope + crackle * envelope
	return out


## A falling FM zap: the cyberpunk "pew".
func _laser_pulse() -> PackedFloat32Array:
	var out := _buffer(0.28)
	var phase := 0.0
	var mod_phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var freq := 2400.0 * exp(-t * 9.0) + 300.0
		mod_phase += TAU * freq * 0.5 / RATE
		phase += TAU * (freq + sin(mod_phase) * freq * 0.35) / RATE
		out[i] = sin(phase) * exp(-t * 11.0) * minf(1.0, t * 400.0)
	return out


## Inharmonic metallic ring with a buzzy attack.
func _shield_hit() -> PackedFloat32Array:
	var out := _buffer(0.45)
	var ratios := [1.0, 2.76, 5.4, 8.93]
	var phases := [0.0, 0.0, 0.0, 0.0]
	for i in out.size():
		var t := float(i) / RATE
		var sample := 0.0
		for k in ratios.size():
			phases[k] += TAU * 520.0 * ratios[k] / RATE
			sample += sin(phases[k]) * exp(-t * (6.0 + k * 5.0)) / (k + 1)
		var buzz := signf(sin(TAU * 110.0 * t)) * exp(-t * 30.0) * 0.3
		out[i] = sample + buzz
	return out


## A descending buzz that sputters out.
func _shield_down() -> PackedFloat32Array:
	var out := _buffer(0.7)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (420.0 * exp(-t * 3.0) + 40.0) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var sputter := 1.0 if fmod(t * 23.0, 1.0) > t * 1.1 else 0.2
		out[i] = saw * exp(-t * 3.5) * sputter * 0.7
	return out


## A roaring, seamless 1 s loop: bandpassed noise with slow flutter. The ends crossfade.
func _flame_loop() -> PackedFloat32Array:
	var out := _buffer(1.0)
	var low := 0.0
	var high := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.18
		high += (low - high) * 0.02
		var flutter := 0.75 + 0.25 * sin(TAU * 7.0 * t) * sin(TAU * 2.0 * t)
		out[i] = (low - high) * flutter
	var fade := int(0.08 * RATE)
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[out.size() - fade + i] * (1.0 - w)
	out.resize(out.size() - fade)
	return out


## A stadium's murmur (loops): many voices are noise through two moving vowel-like bands (~500 Hz and ~1.4 kHz),
## each with slow random swells, over a low room rumble. Crossfaded seam.
func _crowd_murmur() -> PackedFloat32Array:
	var out := _buffer(4.08)
	var bands := [[520.0, 0.0, 0.0], [1400.0, 0.0, 0.0], [900.0, 0.0, 0.0]]  # center Hz, low state, band state
	var swells := PackedFloat32Array([0.6, 0.5, 0.4])
	var targets := PackedFloat32Array([0.6, 0.5, 0.4])
	var rumble := 0.0
	var soft := 0.0  # voices across a stadium lose their top end: roll off above ~2 kHz
	for i in out.size():
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := 0.0
		for b in bands.size():
			if i % 2205 == 0:
				targets[b] = rng.randf_range(0.25, 1.0)
			swells[b] += (targets[b] - swells[b]) * 0.0004
			var band: Array = bands[b]
			var k := TAU * float(band[0]) * (1.0 + 0.08 * sin(TAU * (0.3 + b * 0.17) * i / RATE)) / RATE
			band[1] += (noise - float(band[1])) * k          # lowpass at the band center
			band[2] += (float(band[1]) - float(band[2])) * k * 0.35  # minus a lower lowpass = a band
			sample += (float(band[1]) - float(band[2])) * swells[b]
		rumble += (noise - rumble) * 0.004
		soft += (sample * 1.4 + rumble * 2.0 - soft) * 0.45
		out[i] = soft
	var fade := int(0.08 * RATE)
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[out.size() - fade + i] * (1.0 - w)
	out.resize(out.size() - fade)
	return out


## A roar for a kill: the murmur's bands opened wide with a fast swell and slow decay, whistles sweeping up,
## and a scatter of claps.
func _crowd_cheer() -> PackedFloat32Array:
	var out := _buffer(3.2)
	var low := 0.0
	var band := 0.0
	var whistles := []
	for w in 3:
		whistles.append([rng.randf_range(0.2, 1.4), rng.randf_range(1700.0, 2600.0), 0.0])
	for i in out.size():
		var t := float(i) / RATE
		var envelope := minf(t / 0.35, 1.0) * exp(-maxf(t - 0.6, 0.0) * 1.1)
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.32
		band += (low - band) * 0.05
		var roar := (low - band) * envelope * (0.8 + 0.2 * sin(TAU * 3.0 * t))
		var whistle := 0.0
		for w in whistles:
			var start: float = w[0]
			if t > start and t < start + 0.5:
				var local := t - start
				w[2] += TAU * (float(w[1]) + 900.0 * local) / RATE
				whistle += sin(float(w[2])) * sin(PI * local / 0.5) * 0.12
		var clap := 0.0
		if rng.randf() < 0.0022 * envelope:
			clap = rng.randf_range(0.5, 1.0)
		out[i] = roar + whistle + clap * noise
	return out


## An engine loop: a firing-pulse train at `firing` Hz (a narrow pulse through a resonant lowpass, saturated so its
## harmonics carry on phone speakers), a clattering noise layer, and an optional 120 Hz electrical hum with buzz
## (the Lancer's transformer). `rasp` = exhaust distortion. Rendered 1.08 s and crossfaded into 1 s so the filters'
## state doesn't click at the seam.
func _engine(firing: float, rasp: float, clatter: float, hum: float) -> PackedFloat32Array:
	var out := _buffer(1.08)
	var low := 0.0
	var band := 0.0
	var noise_low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		# Four cylinders of uneven strength per engine cycle: the lope of a big engine.
		var cylinder := int(fmod(t * firing * 4.0, 4.0))
		var strength: float = [1.0, 0.8, 0.95, 0.7][cylinder]
		var pulse := (1.0 if fmod(t * firing * 4.0, 1.0) < 0.18 else 0.0) * strength
		low += (pulse - low) * 0.22
		band += (low - band) * 0.03
		# Hard saturation: phone speakers can't play the firing frequency itself, only its harmonics.
		var body := tanh((low - band) * (8.0 + rasp * 10.0))
		var noise := rng.randf_range(-1.0, 1.0)
		noise_low += (noise - noise_low) * 0.25
		var clank := noise_low * clatter * (0.6 + 0.4 * sin(TAU * firing * 2.0 * t))
		var electric := 0.0
		if hum > 0.0:
			electric = hum * (0.6 * sin(TAU * 120.0 * t) + 0.25 * sin(TAU * 360.0 * t) + 0.12 * signf(sin(TAU * 240.0 * t)))
		out[i] = body * 0.8 + clank + electric * 0.5
	var fade := int(0.08 * RATE)
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[out.size() - fade + i] * (1.0 - w)
	out.resize(out.size() - fade)
	return out


func _blip(freq: float, seconds: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = signf(sin(TAU * freq * t)) * 0.4 * minf(1.0, (seconds - t) * 200.0) * minf(1.0, t * 800.0)
	return out


func _alert() -> PackedFloat32Array:
	var out := _buffer(0.32)
	for i in out.size():
		var t := float(i) / RATE
		var freq := 880.0 if t < 0.15 else 660.0
		var gate := 1.0 if fmod(t, 0.16) < 0.13 else 0.0
		out[i] = (sin(TAU * freq * t) * 0.6 + signf(sin(TAU * freq * t)) * 0.2) * gate * exp(-t * 2.0)
	return out


func _tick() -> PackedFloat32Array:
	var out := _buffer(0.018)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 400.0)
	return out


# ---- Feel (round 3) ------------------------------------------------------------------------------------------------

## Mixes delayed, darker copies of the sound back in: slap echoes off the arena walls and stands.
func _echoes(samples: PackedFloat32Array, delays: Array, gains: Array) -> PackedFloat32Array:
	var out := samples.duplicate()
	for k in delays.size():
		var offset := int(float(delays[k]) * RATE)
		var dark := 0.0
		for i in range(offset, out.size()):
			dark += (samples[i - offset] - dark) * 0.12
			out[i] += dark * float(gains[k])
	return out


## The tank cannon: a supersonic crack, a chest-deep pitch-dropping boom, a 150–400 Hz body a phone can play, and a long
## rumbling tail with slap echoes off the stands. Built to sound expensive: you wait five seconds for the next one.
func _tank_boom() -> PackedFloat32Array:
	var out := _buffer(2.8)
	var phase := 0.0
	var crack_hp := 0.0
	var crack_lp := 0.0
	var body_lp := 0.0
	var body_bp := 0.0
	var rumble := 0.0
	var rumble2 := 0.0
	var mid_lp := 0.0
	var mid_bp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		crack_lp += (noise - crack_lp) * 0.55
		crack_hp = noise - crack_lp
		var crack := crack_hp * exp(-t * 90.0) * 1.6
		var freq := 34.0 + 110.0 * exp(-t * 14.0)
		phase += TAU * freq / RATE
		var boom := tanh(sin(phase) * 5.0) * exp(-t * 3.2) * minf(1.0, t * 600.0)
		body_lp += (noise - body_lp) * 0.09
		body_bp += (body_lp - body_bp) * 0.02
		var body := (body_lp - body_bp) * exp(-t * 5.5) * 7.0
		rumble += (noise - rumble) * 0.018
		rumble2 += (rumble - rumble2) * 0.2
		var tail := rumble2 * 9.0 * exp(-t * 1.25) * minf(1.0, t * 12.0) * (0.8 + 0.2 * sin(TAU * 5.5 * t + sin(TAU * 1.3 * t)))
		# The tail's audible part: a 200–500 Hz roll that laptop and phone speakers can play.
		mid_lp += (noise - mid_lp) * 0.08
		mid_bp += (mid_lp - mid_bp) * 0.025
		var mid_tail := (mid_lp - mid_bp) * 3.4 * exp(-t * 1.7) * minf(1.0, t * 8.0) * (0.7 + 0.3 * sin(TAU * 3.1 * t))
		out[i] = crack * 1.5 + boom * 0.55 + body + tail * 0.8 + mid_tail
	return _echoes(out, [0.19, 0.43, 0.71], [0.35, 0.22, 0.12])


## A shell tearing past: an airy whoosh that swells as it nears and a falling, wavering whistle (Doppler), cut off sharply.
func _shell_whine() -> PackedFloat32Array:
	var out := _buffer(0.85)
	var phase := 0.0
	var air_lp := 0.0
	var air_bp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var approach := pow(minf(t / 0.55, 1.0), 2.5)
		var away := exp(-maxf(t - 0.55, 0.0) * 14.0)
		var freq := 1650.0 - 900.0 * smoothstep(0.35, 0.7, t) + 35.0 * sin(TAU * 11.0 * t)
		phase += TAU * freq / RATE
		var whistle := (sin(phase) + 0.3 * sin(phase * 2.01)) * 0.35
		var noise := rng.randf_range(-1.0, 1.0)
		air_lp += (noise - air_lp) * 0.3
		air_bp += (air_lp - air_bp) * 0.04
		out[i] = (whistle + (air_lp - air_bp) * 1.4) * approach * away
	return out


## A shell slamming into armor: a heavy metal clang (inharmonic partials of a thick plate), a crunch of tearing steel,
## and a low thump.
func _shell_hit_armor() -> PackedFloat32Array:
	var out := _buffer(1.4)
	var partials := [[247.0, 3.2], [389.0, 4.5], [611.0, 5.5], [1013.0, 8.0], [1577.0, 12.0]]
	var phases := PackedFloat32Array([0, 0, 0, 0, 0])
	var crunch_lp := 0.0
	var thump := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var ring := 0.0
		for k in partials.size():
			phases[k] += TAU * float(partials[k][0]) * (1.0 - 0.02 * t) / RATE
			ring += sin(phases[k]) * exp(-t * float(partials[k][1])) / (1.0 + k * 0.6)
		var noise := rng.randf_range(-1.0, 1.0)
		crunch_lp += (noise - crunch_lp) * 0.4
		var grit := 1.0 if rng.randf() < 0.3 * exp(-t * 6.0) else 0.3
		var crunch := crunch_lp * exp(-t * 11.0) * grit * 1.8
		thump += TAU * (70.0 + 60.0 * exp(-t * 25.0)) / RATE
		out[i] = tanh(ring * 1.6) * 1.3 * minf(1.0, t * 900.0) + crunch * 1.3 + tanh(sin(thump) * 3.0) * exp(-t * 9.0) * 0.4
	return _echoes(out, [0.17, 0.39], [0.25, 0.12])


## A shell burying itself in the dirt: a dull thud, a spray of grit, and clods pattering back down.
func _dirt_impact() -> PackedFloat32Array:
	var out := _buffer(1.1)
	var phase := 0.0
	var spray_lp := 0.0
	var spray_hp := 0.0
	var patter_lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (55.0 + 80.0 * exp(-t * 20.0)) / RATE
		var thud := tanh(sin(phase) * 4.0) * exp(-t * 7.0)
		var noise := rng.randf_range(-1.0, 1.0)
		spray_lp += (noise - spray_lp) * 0.25
		spray_hp += (spray_lp - spray_hp) * 0.03
		var spray := (spray_lp - spray_hp) * exp(-t * 6.0) * minf(1.0, t * 200.0) * 1.6
		var clod := rng.randf_range(0.4, 1.0) if t > 0.25 and rng.randf() < 0.0025 * exp(-(t - 0.25) * 3.0) else 0.0
		patter_lp += (clod * noise * 3.0 - patter_lp) * 0.5
		out[i] = thud * 0.5 + spray * 1.7 + patter_lp * 1.4
	return _echoes(out, [0.18], [0.2])


## The IFV's 25 mm: a short punchy thump with a hard crack (thump-thump-thump when strung into a burst).
func _autocannon_shot() -> PackedFloat32Array:
	var out := _buffer(0.45)
	var phase := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (95.0 + 160.0 * exp(-t * 30.0)) / RATE
		var thump := tanh(sin(phase) * 6.0) * exp(-t * 16.0)
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.5
		var crack := (noise - lp) * exp(-t * 120.0) * 2.2 + lp * exp(-t * 28.0) * 1.3
		out[i] = thump * 0.8 + crack
	return _echoes(out, [0.12], [0.2])


## One machine-gun round: a sharp dry crack with a hint of mechanism.
func _mg_round() -> PackedFloat32Array:
	var out := _buffer(0.11)
	var lp := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.35
		phase += TAU * (180.0 + 200.0 * exp(-t * 80.0)) / RATE
		out[i] = (noise - lp * 0.5) * exp(-t * 70.0) + tanh(sin(phase) * 3.0) * exp(-t * 45.0) * 0.5
	return out


## A mortar leaving its tube: a hollow resonant "thoonk" and a breathy push of gas.
func _mortar_launch() -> PackedFloat32Array:
	var out := _buffer(0.6)
	var low := 0.0
	var band := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.2
		band += (low - band) * 0.05
		phase += TAU * (230.0 - 60.0 * t) / RATE
		var tube := sin(phase) * exp(-t * 11.0) * minf(1.0, t * 300.0)
		out[i] = tube * 0.9 + (low - band) * exp(-t * 7.0) * 1.3
	return out


## The scout's machine gun held down (loops): exactly 11 rounds per second so the loop is seamless, each a dry crack with
## a slightly different weight, over the rattle of the action and a low chug that phones render as its harmonics. brrrt.
func _mg_loop() -> PackedFloat32Array:
	var out := _buffer(1.0)
	var rounds := 11
	var period := out.size() / rounds
	var lp := 0.0
	var rattle := 0.0
	for r in rounds:
		var weight := rng.randf_range(0.75, 1.0)
		var tone := rng.randf_range(170.0, 210.0)
		var phase := 0.0
		for j in period:
			var i := r * period + j
			var t := float(j) / RATE
			var noise := rng.randf_range(-1.0, 1.0)
			lp += (noise - lp) * 0.35
			phase += TAU * (tone + 180.0 * exp(-t * 70.0)) / RATE
			var crack := (noise - lp * 0.5) * exp(-t * 90.0) * weight
			var knock := tanh(sin(phase) * 3.0) * exp(-t * 38.0) * 0.55 * weight
			rattle += (noise * 0.25 - rattle) * 0.08
			out[i] = crack + knock + rattle * (0.6 + 0.4 * exp(-t * 20.0))
	for i in range(rounds * period, out.size()):
		out[i] = 0.0
	return out


## A round glancing off armor: a bright metallic tick and a zinging whine that falls away (pee-yoww).
func _ricochet() -> PackedFloat32Array:
	var out := _buffer(0.55)
	var phase := 0.0
	var mod := 0.0
	var start := rng.randf_range(2600.0, 3200.0)
	for i in out.size():
		var t := float(i) / RATE
		var freq := start * exp(-t * 2.2) + 500.0
		mod += TAU * 37.0 / RATE
		phase += TAU * freq * (1.0 + 0.012 * sin(mod)) / RATE
		var zing := sin(phase) * exp(-t * 5.5) * minf(1.0, t * 150.0) * 0.6
		var tick := rng.randf_range(-1.0, 1.0) * exp(-t * 300.0)
		out[i] = zing + tick
	return out


## A bullet or 25 mm round striking steel: a short hard clank.
func _bullet_hit_metal() -> PackedFloat32Array:
	var out := _buffer(0.16)
	var ratios := [1.0, 2.31, 3.87]
	var phases := [0.0, 0.0, 0.0]
	var base := rng.randf_range(820.0, 980.0)
	for i in out.size():
		var t := float(i) / RATE
		var ring := 0.0
		for k in ratios.size():
			phases[k] += TAU * base * float(ratios[k]) / RATE
			ring += sin(phases[k]) * exp(-t * (28.0 + k * 12.0)) / (k + 1)
		out[i] = ring * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.9
	return out


## A weak-spot hit: a heavy crunch into something that matters, then a bright rising two-note chime that rings out. It
## has to feel like a reward you learn to listen for.
func _weak_spot_hit() -> PackedFloat32Array:
	var out := _buffer(1.0)
	var lp := 0.0
	var thump := 0.0
	var bell := [0.0, 0.0, 0.0, 0.0]
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.3
		var crunch := lp * exp(-t * 14.0) * (1.0 if rng.randf() < 0.5 else 0.4) * 1.6
		thump += TAU * (90.0 + 90.0 * exp(-t * 30.0)) / RATE
		var body := tanh(sin(thump) * 3.0) * exp(-t * 10.0) * 0.6
		# The chime: E6 then B6, each with a detuned partner for shimmer, entering a beat after the crunch.
		var chime := 0.0
		var notes := [[1318.5, 0.06], [1975.5, 0.14]]
		for k in notes.size():
			var start := float(notes[k][1])
			if t >= start:
				var local := t - start
				bell[k * 2] += TAU * float(notes[k][0]) / RATE
				bell[k * 2 + 1] += TAU * float(notes[k][0]) * 1.004 / RATE
				chime += (sin(bell[k * 2]) + 0.6 * sin(bell[k * 2 + 1])) * exp(-local * 4.5) * minf(1.0, local * 300.0) * 0.35
		out[i] = crunch + body + chime
	return _echoes(out, [0.16], [0.18])


## A radio squelch click then two quick rising tones: "copy, moving."
func _ack_move() -> PackedFloat32Array:
	var out := _buffer(0.2)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.5
		var freq := 880.0 if t < 0.07 else 1318.5
		var gate := 1.0 if (t > 0.012 and t < 0.065) or (t > 0.08 and t < 0.16) else 0.0
		phase += TAU * freq / RATE
		var tone := (sin(phase) * 0.7 + signf(sin(phase)) * 0.15) * gate * exp(-maxf(t - 0.08, 0.0) * 12.0)
		out[i] = click + tone * 0.6
	return out


## A squelch click and a hard descending buzz with a stab on top: "engaging."
func _ack_attack() -> PackedFloat32Array:
	var out := _buffer(0.24)
	var phase := 0.0
	var stab := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.5
		phase += TAU * (420.0 - 700.0 * t) / RATE
		var saw := (fmod(phase / TAU, 1.0) * 2.0 - 1.0) * minf(1.0, t * 200.0) * exp(-t * 9.0)
		stab += TAU * 1760.0 / RATE
		var top := sin(stab) * exp(-t * 30.0) * 0.4
		out[i] = click + tanh(saw * 2.0) * 0.45 + top
	return out


## A soft short blip for selecting units.
func _select_blip() -> PackedFloat32Array:
	var out := _buffer(0.07)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (1500.0 + 500.0 * t / 0.07) / RATE
		out[i] = sin(phase) * minf(1.0, t * 800.0) * exp(-t * 45.0)
	return out
