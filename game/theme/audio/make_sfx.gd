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
	quit()


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
