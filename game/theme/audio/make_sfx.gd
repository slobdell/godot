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
