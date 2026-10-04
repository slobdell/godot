extends SceneTree
## Round 17 G1: what each weapon and impact sound is when it reaches the speakers, alone, through the game's own
## voices and buses: `make weapon-sheet` (tools/audio/weapon_sheet.py measures the recordings against the files).
##
## The camera stands where the skirmish's default RTS pose puts it (RtsCamera: pitch 21°, 49 m from its focus), and
## each sound plays once on the ground straight ahead of it at each arm's distances, through SfxSystem.play_at: the
## real inverse-distance fall-off, the distance filter, the bus (Impacts or Bed), the World bus's limiter and trim
## and the Master limiter. The Master bus is recorded per sound and distance to <out>/<sound>@<distance>m.wav.
## The first take of each sound plays at its unshifted pitch, so two runs record the same thing.
##
## ARMS take the chain apart one stage at a time, so each stage's cost is a difference between two recordings of the
## same sound: `full` (as the game plays it), `nolimit` (the World and Master limiters bypassed), `nofilter` (and no
## distance filter), `notrim` (and the World bus at 0 dB). What `notrim` still lacks against the file is the mix
## level, the distance fall-off and the pan. Files: <sound>@<distance>m.wav for `full`, <sound>@<distance>m~<arm>.wav.
## With nothing limiting it, a loud sound would clip the 16-bit recorder, so the unlimited arms run the World bus
## HEADROOM_DB lower (a linear stage after the voice: the distance filter, which reads the voice's level, is
## unchanged) and the sheet adds it back.
##
## Presentation only: no match, no simulation. Prints WEAPON_PROBE lines and WEAPON_PROBE_DONE.

## arm -> the distances it is recorded at.
const ARMS := {"full": [30.0, 49.0, 80.0, 120.0], "nolimit": [49.0, 120.0], "nofilter": [49.0, 120.0],
		"notrim": [49.0, 120.0]}
const HEADROOM_DB := 12.0
const PITCH_DEG := 21.0
const FOCUS_M := 49.0
## How long a loop is held (a gunner's trigger), and the silence recorded after each sound's end.
const LOOP_HOLD_S := 2.5
const AFTER_S := 0.4
const SOUNDS := ["tank_boom", "cannon_shot", "autocannon_shot", "mg_round", "mg_loop", "twin_mg_loop", "mortar_launch",
		"railgun_shot", "energy_beam", "laser_pulse", "pulse_shot", "plasma_loop", "missile_launch", "sonic_loop",
		"flame_loop", "explosion_big", "explosion_small", "shell_hit_armor", "dirt_impact", "bullet_hit_metal", "ricochet",
		"weak_spot_hit", "shield_hit", "shield_down", "energy_hit", "shell_whine"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("weapon_probe")
	var only: Array = args[1].split(",") if args.size() > 1 and args[1] != "" else SOUNDS
	DirAccess.make_dir_recursive_absolute(out)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	var height := FOCUS_M * sin(deg_to_rad(PITCH_DEG))
	camera.position = Vector3(0.0, height, FOCUS_M * cos(deg_to_rad(PITCH_DEG)))
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	camera.current = true
	var sfx := SfxSystem.new()
	stage.add_child(sfx)
	sfx.listener = camera.position
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), record)
	await process_frame
	print("WEAPON_PROBE driver=%s mix_rate=%d camera=%s out=%s" % [AudioServer.get_driver_name(), AudioServer.get_mix_rate(),
			camera.position, out])
	var ahead := Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
	for sound in only:
		if not sfx.takes.has(sound):
			print("WEAPON_PROBE missing=%s" % sound)
			continue
		sfx.takes[sound] = [sfx.takes[sound][0]]
		var stream: AudioStream = sfx.takes[sound][0]
		var loop := String(sound).ends_with("_loop")
		for arm in ARMS:
			_set_arm(arm)
			for distance in ARMS[arm]:
				var along := sqrt(maxf(distance * distance - height * height, 0.0))
				var at := Vector3(camera.position.x, 0.0, camera.position.z) + ahead * along
				record.set_recording_active(true)
				await create_timer(0.05).timeout
				sfx.play_at(sound, at)
				var voice := sfx.last_voice
				if voice != null:
					voice.pitch_scale = 1.0
					if arm == "nofilter" or arm == "notrim":
						voice.attenuation_filter_db = 0.0
				await create_timer((LOOP_HOLD_S if loop else stream.get_length()) + AFTER_S).timeout
				if voice != null:
					voice.stop()
				record.set_recording_active(false)
				var take := record.get_recording()
				var path := out.path_join("%s@%dm%s.wav" % [sound, int(distance), "" if arm == "full" else "~" + arm])
				var error := take.save_to_wav(path) if take != null else ERR_UNAVAILABLE
				print("WEAPON_PROBE sound=%s arm=%s distance=%d voice=%s seconds=%.2f error=%d" % [sound, arm, int(distance),
						"yes" if voice != null else "culled", take.get_length() if take != null else 0.0, error])
	_set_arm("full")
	sfx.stop_all()
	print("WEAPON_PROBE_DONE")
	quit(0)


## Bypasses the stages an arm leaves out (the limiters on World and Master, the World bus's trim).
func _set_arm(arm: String) -> void:
	var limited := arm == "full"
	for bus_name in ["World", "Master"]:
		var bus := AudioServer.get_bus_index(bus_name)
		for i in AudioServer.get_bus_effect_count(bus):
			var effect := AudioServer.get_bus_effect(bus, i)
			if effect is AudioEffectLimiter or effect is AudioEffectHardLimiter:
				AudioServer.set_bus_effect_enabled(bus, i, limited)
	var trim := 0.0 if arm == "notrim" else SfxSystem.WORLD_TRIM_DB
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("World"), trim - (0.0 if limited else HEADROOM_DB))
