class_name SfxSystem
extends Node3D
## Pooled sound effects: a fixed set of AudioStreamPlayer3D voices (world sounds) and a few
## AudioStreamPlayer voices (UI). Playing a sound grabs a free voice or steals the oldest; nothing is
## allocated in combat. Attenuation is tuned for our cameras (46 m follow cam, 200 m tactical view),
## so battle sounds stay audible from the top-down map. Lives in FxWorld (never on headless peers).
## `--mute` silences it.

const SOUNDS := {
	"cannon_shot": "res://assets/audio/cannon_shot.wav",
	"explosion_small": "res://assets/audio/explosion_small.wav",
	"explosion_big": "res://assets/audio/explosion_big.wav",
	"laser_pulse": "res://assets/audio/laser_pulse.wav",
	"shield_hit": "res://assets/audio/shield_hit.wav",
	"shield_down": "res://assets/audio/shield_down.wav",
	"flame_loop": "res://assets/audio/flame_loop.wav",
	"ui_blip": "res://assets/audio/ui_blip.wav",
	"ui_alert": "res://assets/audio/ui_alert.wav",
	"ui_tick": "res://assets/audio/ui_tick.wav",
	"crowd_murmur": "res://assets/audio/crowd_murmur.wav",
	"crowd_cheer": "res://assets/audio/crowd_cheer.wav",
	"engine_diesel": "res://assets/audio/engine_diesel.wav",
	"engine_v8": "res://assets/audio/engine_v8.wav",
	"engine_electric": "res://assets/audio/engine_electric.wav",
	# Feel (round 3): the new weapons (make_sfx.gd).
	"tank_boom": "res://assets/audio/tank_boom.wav",
	"shell_whine": "res://assets/audio/shell_whine.wav",
	"shell_hit_armor": "res://assets/audio/shell_hit_armor.wav",
	"dirt_impact": "res://assets/audio/dirt_impact.wav",
	"autocannon_shot": "res://assets/audio/autocannon_shot.wav",
	"mg_round": "res://assets/audio/mg_round.wav",
	"mortar_launch": "res://assets/audio/mortar_launch.wav",
	"mg_loop": "res://assets/audio/mg_loop.wav",
	"ricochet": "res://assets/audio/ricochet.wav",
	"bullet_hit_metal": "res://assets/audio/bullet_hit_metal.wav",
	"weak_spot_hit": "res://assets/audio/weak_spot_hit.wav",
	"ui_ack_move": "res://assets/audio/ui_ack_move.wav",
	"ui_ack_attack": "res://assets/audio/ui_ack_attack.wav",
	"ui_select": "res://assets/audio/ui_select.wav",
	# Audio (round 5, after the lead played the Syndicate): the energy weapons have their own sounds instead of
	# borrowing a machine gun and a mortar (SfxWeapons). These exist only as layered ElevenLabs takes
	# (assets/audio/layered), so they have no entry here until sfx_layer writes one; ALIAS covers the gap.
	# Audio (round 5, X4): running gear under the engines (tools/audio/make_world_loops.py).
	"tread_loop": "res://assets/audio/tread_loop.wav",
	"tire_loop": "res://assets/audio/tire_loop.wav",
}
## Extra takes per sound (game/theme/audio/make_sfx.gd VARIANTS): "mg_round" also loads mg_round_2..4. A sound
## plays a take at random, so a burst is never the same crack eleven times (X4).
const TAKES := {
	"mg_round": 4, "bullet_hit_metal": 4, "autocannon_shot": 3, "ricochet": 3, "shell_hit_armor": 3,
	"dirt_impact": 3, "explosion_small": 3, "weak_spot_hit": 2, "tank_boom": 2, "cannon_shot": 2,
}
## Round 17 (G3): the guns designed in layers, two or three ways each (SfxDirections, tools/audio/gun_layers.py).
## This names the direction the game plays; the audition page is where the lead picks, and his pick is this one line.
## TODAY is the sound as it was before round 17. `--sfx-direction=tank_boom:b,autocannon_shot:0` overrides it.
const TODAY := "0"
const DIRECTION := {"tank_boom": "a", "autocannon_shot": "a", "explosion_big": "a", "mg_loop": "a",
		# G5: impacts by surface and calibre (SfxSurfaces); these exist only as round-17 takes.
		"impact_concrete_heavy": "a", "impact_steel_heavy": "a", "impact_water_heavy": "a", "impact_dirt_medium": "a",
		"impact_concrete_medium": "a", "impact_steel_medium": "a", "impact_armor_medium": "a", "impact_dirt_light": "a",
		"impact_concrete_light": "a", "impact_water_light": "a", "bullet_snap": "a",
		# G6: the audit's silent events.
		"track_skid": "a", "track_squeal": "a", "tyre_skid": "a", "wreck_fire_loop": "a", "shield_up": "a", "shell_incoming": "a",
		# G3: the other factions brought up beside the new guns.
		"railgun_shot": "a", "mortar_launch": "a", "missile_launch": "a", "pulse_shot": "a", "twin_mg_loop": "a", "flame_loop": "a"}
const WORLD_VOICES := 20
## Voice priority (round 5, X4). A sound is judged by how loud it will be where the camera is: its MIX level less the
## inverse-distance fall-off the players use. Quieter than CULL_DB, it never takes a voice. With every voice busy it
## steals the one that is quietest *now* (its start level less TAIL_DECAY_DB_PER_S for every second it has played),
## and only if it is louder than that: a ping across the arena must never cut a nearby cannon's tail.
const CULL_DB := -46.0
const TAIL_DECAY_DB_PER_S := 14.0
## Round 17 (G2): the fight he watches is 40-120 m from the camera. With 55 / 600 a shot lost 8.7 dB across that span
## (inverse distance AND Godot's linear fade to max_distance, both measured by the probe); with 75 / 900 it loses 5.3, and
## distance is told by brightness (DISTANCE_FILTER) and the takes' own tails rather than by level.
const UNIT_SIZE := 75.0
const MAX_DISTANCE := 900.0
const UI_VOICES := 4
## World sounds go through their own bus so the whole battle can be mixed, limited, and ducked under the announcer
## in one place (AnnouncerVoice sidechains a compressor onto this bus when the booth is on).
const WORLD_BUS := "World"
## Headroom: twenty voices summing in a firefight clip the master and turn to mush. The limiter catches the peaks
## that survive per-sound gain staging; the trim leaves room for it to work.
## Round 17 (G2): it was -6 dB under an AudioEffectLimiter that lifted everything +3 dB (ceiling - threshold) and then
## clamped every loud sound to the same -6.5 dBTP at the master - the tank, a held machine gun and a railgun alike, with
## 5.5 dB of the master's headroom never used. Now the battle has a transparent limiter (no make-up) and a small trim
## for the booth and the music to sit on top of.
const WORLD_TRIM_DB := -2.0
const WORLD_CEILING_DB := -1.0
const WORLD_RELEASE_S := 0.12
## Round 17 (G2): the booth's duck on the battle, tuned here (AnnouncerVoice adds one only if none exists). At
## -28 dB / 6:1 it took ~16 dB off every gun for the 70 % of a match the booth speaks (fight taps, builder0): the voice
## sat a median 26 dB over the battle where speech needs well under half of that.
## Measured on his match (Sumps, seed 92721, the booth speaking ~76 % of it; builder0): booth over the battle, median /
## worst 10 %: launch 21.7 / 8.8 dB, mid 14.7 / 2.9, light (-20, 2.5:1) 9.6 / 1.5. Default: mid - the guns get 6.4 dB
## back and the caller keeps his lead; the page's booth item is the lead's call.
const BOOTH_DUCK := {"threshold": -24.0, "ratio": 4.0, "attack_us": 5000.0, "release_ms": 320.0, "script_db": 12.7}
## X2 (round 5): the moment a shell lands is the loudest thing in the mix, then it falls away. Heavy impacts play on
## IMPACT_BUS; everything that runs underneath the fight (engines, gun loops, the crowd, small hits) plays on BED_BUS,
## which a compressor keyed from the impacts pulls down for a moment and lets back up. Both feed World, so the
## limiter and the announcer's ducking still see all of it.
const IMPACT_BUS := "Impacts"
const BED_BUS := "Bed"
## Feel X3 (round 6): the crowd has its own bus. On Bed it was ducked 5:1 by every impact on top of sitting 20-25 dB
## under the mix (a recorded match: -46.5 dBFS soloed before contact), so nobody ever heard it. The stands are a
## different place from the fight: an impact dips them gently rather than silencing them, and the bus's own meter is
## what `--crowd-meter` reads to prove the crowd is audible in a real match.
const CROWD_BUS := "Crowd"
## Round 6 (the lead: "I believe we're missing machine guns"): the machine guns' held loops left the Bed bus, where every
## cannon impact ducked them 5:1 and they dropped out exactly when the fight was busiest. Their own bus takes a 2:1 dip.
const GUNFIRE_BUS := "Gunfire"
const IMPACT_SOUNDS := ["tank_boom", "shell_hit_armor", "explosion_big", "explosion_small", "weak_spot_hit",
		"dirt_impact", "shield_down", "impact_concrete_heavy", "impact_steel_heavy", "impact_water_heavy"]
const LIMIT_DB := -1.0
const BOOTH_BUS := "Announcer"
## Distance filtering: a blast heard across the arena is dull, not just quiet. Per sound, the cutoff (Hz) at
## max_distance and how much of the sound is filtered; the engine interpolates with distance. Sounds not listed keep
## their full brightness, which is right for the small metallic ones that are only ever heard close.
## Round 17 (G2): the shelves sat at 1.1-3 kHz and took up to 24 dB, so a tank's crack was gone 25 dB at 120 m (probe).
## They now sit above the crack's core and take about a third less: distance takes the air off, the crack carries.
## Applied by distance alone (filter_db_for), never by how loud a sound is mixed.
const DISTANCE_FILTER := {
	"tank_boom": [5000.0, -14.0], "cannon_shot": [5000.0, -14.0], "explosion_big": [3500.0, -16.0],
	"explosion_small": [4000.0, -14.0], "mortar_launch": [4500.0, -12.0], "autocannon_shot": [5000.0, -12.0],
	"mg_round": [6000.0, -10.0], "mg_loop": [6000.0, -10.0], "shell_hit_armor": [5000.0, -10.0],
	"dirt_impact": [4000.0, -12.0], "weak_spot_hit": [6000.0, -8.0], "flame_loop": [4500.0, -10.0],
	"engine_diesel": [3000.0, -14.0], "engine_v8": [3000.0, -14.0], "engine_electric": [4000.0, -10.0],
	"railgun_shot": [5000.0, -14.0], "energy_beam": [5000.0, -10.0], "plasma_loop": [5000.0, -10.0],
	"pulse_shot": [5000.0, -12.0], "missile_launch": [4000.0, -12.0], "energy_hit": [5000.0, -10.0],
	"sonic_loop": [3500.0, -12.0],
	"impact_concrete_heavy": [4000.0, -14.0], "impact_steel_heavy": [4000.0, -14.0], "impact_water_heavy": [3500.0, -14.0],
	"impact_dirt_medium": [5000.0, -12.0], "impact_concrete_medium": [5000.0, -12.0], "impact_steel_medium": [5000.0, -12.0],
	"impact_armor_medium": [5000.0, -12.0], "impact_dirt_light": [6000.0, -10.0], "impact_concrete_light": [6000.0, -10.0],
	"impact_water_light": [6000.0, -10.0], "bullet_snap": [6000.0, -14.0],
}
## Per sound: base volume (dB) and random pitch spread, so repeated shots don't sound identical.
## Round 17 (G2): the kill on top, then a tank shot, the 25 mm 7 dB under it, a machine-gun round no longer 20 dB under
## a shot at the master. A round-17 take is mastered to -1 dBTP with its crack as the peak (crest ~13 dB against the old
## take's 7), so it carries ~3.5 dB less loudness at the same peak: the headroom the old World limiter never let any
## sound use (it clamped them all to -6.5 dBTP) pays for that. A lone shot at the camera's focus peaks ~-4.5 dBTP.
const MIX := {
	"cannon_shot": [-4.0, 0.08], "explosion_small": [-3.0, 0.1], "explosion_big": [3.0, 0.06],
	"laser_pulse": [-8.0, 0.12], "shield_hit": [-7.0, 0.1], "shield_down": [-4.0, 0.03],
	"ui_blip": [-14.0, 0.0], "ui_alert": [-10.0, 0.0], "ui_tick": [-20.0, 0.15],
	"tank_boom": [3.0, 0.05], "shell_whine": [-5.0, 0.08], "shell_hit_armor": [-1.0, 0.07], "dirt_impact": [-3.0, 0.1],
	"autocannon_shot": [-4.0, 0.06], "mg_round": [-9.0, 0.12], "mortar_launch": [-5.0, 0.05],
	"ricochet": [-9.0, 0.15], "bullet_hit_metal": [-12.0, 0.12], "weak_spot_hit": [-2.0, 0.03],
	"ui_ack_move": [-13.0, 0.03], "ui_ack_attack": [-12.0, 0.03], "ui_select": [-18.0, 0.05],
	# The energy family: a railgun hits like a cannon, the rest sit with the weapons they replace.
	"railgun_shot": [2.0, 0.05], "energy_beam": [-5.0, 0.07], "plasma_loop": [-10.0, 0.06],
	"pulse_shot": [-6.0, 0.06], "missile_launch": [-5.0, 0.05], "energy_hit": [-2.0, 0.07], "sonic_loop": [-11.0, 0.05],
	# G5: where a round lands, by calibre: a shell into anything is an event, a 25 mm a hard pop, a bullet a texture.
	"impact_concrete_heavy": [-1.0, 0.06], "impact_steel_heavy": [-1.0, 0.06], "impact_water_heavy": [-2.0, 0.06],
	"impact_dirt_medium": [-5.0, 0.08], "impact_concrete_medium": [-5.0, 0.08], "impact_steel_medium": [-5.0, 0.08],
	"impact_armor_medium": [-4.0, 0.07], "impact_dirt_light": [-9.0, 0.12], "impact_concrete_light": [-9.0, 0.12],
	"impact_water_light": [-9.0, 0.12], "bullet_snap": [-8.0, 0.1],
	# G6: under the guns, never over them.
	"track_skid": [-9.0, 0.1], "track_squeal": [-10.0, 0.1], "tyre_skid": [-10.0, 0.1], "wreck_fire_loop": [-8.0, 0.05],
	"shield_up": [-8.0, 0.05], "shell_incoming": [-6.0, 0.05],
}

## Round 17 (G2): `--mix=launch` rebuilds the mix the lead heard before round 17 in this build, so a before/after runs
## on one tree and one match (the orchestrator's ask), and the page can play today's mix next to the new one. Every
## value is the launch tree's (3713fdaa). `--booth-duck=launch|mid|new` picks the booth's duck alone (his call: the
## page's dedicated item); the default is BOOTH_DUCK, or the launch duck under --mix=launch.
const LAUNCH_MIX := {
	"unit_size": 55.0, "max_distance": 600.0, "world_trim_db": -6.0, "bed_duck": [-26.0, 5.0], "gun_dip": [-22.0, 2.0],
	"levels": {"tank_boom": 1.0, "explosion_big": 0.0, "autocannon_shot": -6.0, "mg_round": -13.0, "railgun_shot": 0.0},
	"filter": {
		"tank_boom": [1400.0, -22.0], "cannon_shot": [1500.0, -20.0], "explosion_big": [1100.0, -24.0],
		"explosion_small": [1600.0, -20.0], "mortar_launch": [2200.0, -14.0], "autocannon_shot": [2400.0, -14.0],
		"mg_round": [3000.0, -12.0], "mg_loop": [3000.0, -12.0], "shell_hit_armor": [2600.0, -12.0],
		"dirt_impact": [1800.0, -16.0], "weak_spot_hit": [3000.0, -10.0], "flame_loop": [2600.0, -12.0],
		"engine_diesel": [1800.0, -16.0], "engine_v8": [1800.0, -16.0], "engine_electric": [2600.0, -12.0],
		"railgun_shot": [1500.0, -20.0], "energy_beam": [2600.0, -12.0], "plasma_loop": [2800.0, -12.0],
		"pulse_shot": [2400.0, -14.0], "missile_launch": [2000.0, -14.0], "energy_hit": [2600.0, -12.0],
		"sonic_loop": [2000.0, -14.0]},
}
## `script_db`: the median depth that duck takes off the battle while the caller speaks, measured natively on his match
## (World's gain during speech against during silence, builder0): what the web's script duck reproduces.
const BOOTH_DUCKS := {
	"launch": {"threshold": -28.0, "ratio": 6.0, "attack_us": 5000.0, "release_ms": 350.0, "script_db": 18.2},
	"mid": {"threshold": -24.0, "ratio": 4.0, "attack_us": 5000.0, "release_ms": 320.0, "script_db": 12.7},
	"new": {"threshold": -20.0, "ratio": 2.5, "attack_us": 5000.0, "release_ms": 300.0, "script_db": 6.8},
}
## Round 17: the SCRIPT duck. In the browser (Sample playback) no bus effect runs, so the booth's sidechain does not
## exist; while a booth line plays SfxSystem lowers the World bus's volume by the chosen duck's `script_db` instead.
## Round 17 (the orchestrator's call): Sample mode has no limiter; comparable 30-a-side browser fights peaked at +0.1 /
## 0.0 dBFS untrimmed and −3.2 / −2.2 at −3 dB, so −4 dB. Earlier: four fights peaked at −0.3 to
## −1.8 dBFS at the destination. The web's Master is trimmed, keeping every relation in the mix as native and giving
## the sum headroom; the player's volume knob makes up the level. Natively Master stays at 0 dB under its limiter.
const WEB_MASTER_TRIM_DB := -4.0
const SCRIPT_DUCK_ATTACK_S := 0.05
const SCRIPT_DUCK_RELEASE_S := 0.3
## Under `--sfx-direction=all:0` (the sound before round 17): G5's new impacts were silent then, except a 25 mm round on
## armour, which clinked like a bullet.
const TODAY_ALIAS := {"impact_armor_medium": "bullet_hit_metal"}


## Where bus effects do not run: the web in Sample playback (Godot's web default). There the mix has no sidechain and no
## limiter, so it gets the script duck and WEB_MASTER_TRIM_DB. `--web-mix=on|off` forces it (probes and tests).
static func web_sample_mix() -> bool:
	var forced := LaunchFlags.from_environment().text("web-mix", "")
	if forced != "":
		return forced == "on"
	return OS.has_feature("web") and int(ProjectSettings.get_setting("audio/general/default_playback_type.web", 1)) == 1


## Natively the sidechain ducks the battle; a script duck there would be a second one on top of it.
static func script_duck_wanted() -> bool:
	return web_sample_mix()


static func script_duck_depth_db(duck: Dictionary) -> float:
	return float(duck.get("script_db", 0.0))


static func launch_mix() -> bool:
	return LaunchFlags.from_environment().text("mix", "") == "launch"


static func booth_duck() -> Dictionary:
	var wanted := LaunchFlags.from_environment().text("booth-duck", "launch" if launch_mix() else "")
	return BOOTH_DUCKS.get(wanted, BOOTH_DUCK)


var muted := false
## The distance law in force (UNIT_SIZE / MAX_DISTANCE, or the launch mix's).
var unit_size := UNIT_SIZE
var max_distance := MAX_DISTANCE
var _launch := false
## The script duck (web, Sample playback only): on/off, what says the booth is speaking, and where it is now (dB down).
var script_duck_on := false
var booth_speaking: Callable = _booth_speaking
var _script_duck_db := 0.0
var _script_duck_speaking := false
var _booth_voices: Array = []
var _booth_scan_s := 0.0
## G6: mortar rounds coming down (ArcRoundVisual seen entering the tree): [{to, at}] in presentation time.
var incoming_played := 0
var _incoming: Array = []
var _clock := 0.0
var _today_alias := {}
## key -> the first take, as an AudioStreamWAV. Feel's engine and crowd systems read this directly, so it stays
## exactly what it always was.
var streams := {}
## key -> every take of that sound, first one included. play_at picks from here.
var takes := {}
## Sounds started since load (tests and the bench).
var played := 0
## Sounds not started because they would be inaudible, or quieter than everything already playing.
var culled := 0
## sound -> how many times it started (tests count one sound among many).
var plays := {}
## The voice the last play_at started (null when it was culled): the weapon probe pins its pitch.
var last_voice: AudioStreamPlayer3D = null
## Where loudness is judged from; null = the viewport's camera (tests set a point).
var listener: Variant = null
## What a sound falls back to while it has no file of its own: a new weapon sound that hasn't been generated yet
## plays the family sound it replaces rather than nothing at all.
const ALIAS := {
	"railgun_shot": "tank_boom", "energy_beam": "laser_pulse", "plasma_loop": "mg_loop", "pulse_shot": "autocannon_shot",
	"missile_launch": "mortar_launch", "energy_hit": "shell_hit_armor", "sonic_loop": "mg_loop",
	"twin_mg_loop": "mg_loop",
}
## Sounds --audio-solo keeps quiet.
var silenced := {}
## key -> how many synthesised takes loaded (make_sfx.gd), whether or not layered ones replaced them.
var synth_takes := {}
## Sounds playing ElevenLabs-layered takes (SfxLayers, round 5 X1) rather than the synthesised ones.
var layered := {}
## sound -> the direction it plays (only sounds that have directions).
var _direction := {}
## sound -> its pool before any direction replaced it (TODAY).
var _today := {}

var _world: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _next_world := 0
var _voice_level: Array[float] = []
var _voice_started: Array[float] = []
var _next_ui := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Sfx"
	_rng.seed = 7
	muted = LaunchFlags.from_environment().has("mute")
	_launch = launch_mix()
	script_duck_on = script_duck_wanted()
	if _launch:
		unit_size = float(LAUNCH_MIX["unit_size"])
		max_distance = float(LAUNCH_MIX["max_distance"])
	var soloed := AudioSolo.solo()
	for key in SOUNDS:
		# --audio-solo keeps the stream (engine, crowd and flame code read it) but never plays it.
		if not AudioSolo.allows(AudioSolo.layer_of(key), soloed):
			silenced[key] = true
		var stream := load(SOUNDS[key]) as AudioStream
		if stream == null:
			continue
		streams[key] = stream
		var pool: Array[AudioStream] = [stream]
		for take in range(2, int(TAKES.get(key, 1)) + 1):
			var extra := load(String(SOUNDS[key]).replace(".wav", "_%d.wav" % take)) as AudioStream
			if extra != null:
				pool.append(extra)
		takes[key] = pool
		synth_takes[key] = pool.size()
	if not LaunchFlags.from_environment().has("sfx-synth"):
		_use_layered_takes()
		var chosen := DIRECTION.duplicate()
		var asked := parse_directions(LaunchFlags.from_environment().text("sfx-direction", ""))
		if asked.get("all", "") == TODAY:
			for sound in chosen:
				chosen[sound] = TODAY
		chosen.merge(asked, true)
		chosen.erase("all")
		for sound in chosen:
			use_direction(sound, String(chosen[sound]))
			if String(chosen[sound]) == TODAY and not _today.has(sound):
				# A round-17-only sound, asked for as it was before round 17: what played then.
				if TODAY_ALIAS.has(sound):
					_today_alias[sound] = TODAY_ALIAS[sound]
				else:
					silenced[sound] = true
	var flame := streams.get("flame_loop") as AudioStreamWAV
	if flame != null:
		flame.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flame.loop_end = loop_frames(flame)
	ensure_world_bus()
	for i in WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = unit_size
		voice.max_distance = max_distance
		voice.max_polyphony = 1
		voice.bus = WORLD_BUS
		add_child(voice)
		_world.append(voice)
		_voice_level.append(-INF)
		_voice_started.append(0.0)
	add_child(FireVoices.new(self))
	for i in UI_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "UiVoice%d" % i
		add_child(voice)
		_ui.append(voice)


## Round 5 (X1): sounds with ElevenLabs source material layered under their transients (tools/audio/sfx_layer.py)
## play those takes instead. A loop's layered take is a WAV, so it also replaces `streams[key]`, which the engine,
## crowd, flame and gunfire code duplicate and set loop points on; a one-shot's is Ogg and only changes the pool.
## `--sfx-synth` keeps the synthesised set, for A/B listening.
func _use_layered_takes() -> void:
	for key in SfxLayers.TAKES:
		var pool: Array[AudioStream] = []
		for path in SfxLayers.TAKES[key]:
			var stream := load(String(path)) as AudioStream
			if stream != null:
				pool.append(stream)
		if pool.is_empty():
			continue
		takes[key] = pool
		layered[key] = pool.size()
		# A sound that exists only as layered takes (the energy weapons) becomes a sound like any other.
		if pool[0] is AudioStreamWAV or not streams.has(key):
			streams[key] = pool[0]


## "tank_boom:b,autocannon_shot:0" -> {tank_boom: "b", autocannon_shot: "0"}; anything malformed is dropped.
static func parse_directions(text: String) -> Dictionary:
	var parsed := {}
	for entry in text.split(",", false):
		var parts := entry.strip_edges().split(":")
		if parts.size() == 2 and parts[0] != "" and parts[1] != "":
			parsed[parts[0]] = parts[1]
	return parsed


## Plays `sound` as `direction` (TODAY: as before round 17). An unbuilt direction is ignored.
func use_direction(sound: String, direction: String) -> void:
	if not _today.has(sound) and takes.has(sound):
		_today[sound] = takes[sound]
	if direction == TODAY:
		if _today.has(sound):
			takes[sound] = _today[sound]
			_direction[sound] = TODAY
		return
	var paths: Array = (SfxDirections.TAKES.get(sound, {}) as Dictionary).get(direction, [])
	var pool: Array[AudioStream] = []
	for path in paths:
		var stream := load(String(path)) as AudioStream
		if stream != null:
			pool.append(stream)
	if pool.is_empty():
		return
	takes[sound] = pool
	_direction[sound] = direction
	if not streams.has(sound) or (sound.ends_with("_loop") and pool[0] is AudioStreamWAV):
		# A sound that exists only as round-17 takes (the G5 impacts) is a sound like any other; a loop's stream is what
		# the flamethrower, the gunfire and the fires duplicate and loop, so it follows the direction too.
		streams[sound] = pool[0]


## The direction `sound` plays, or "" when it has none.
func direction_of(sound: String) -> String:
	return String(_direction.get(sound, ""))


## A WAV's length in frames, whatever its import compression. `data.size() / 2` is only right for 16-bit PCM: on a
## QOA import it is a fifth of the sound, which is how every loop came to repeat its first 0.2 s (round 5).
static func loop_frames(stream: AudioStreamWAV) -> int:
	return int(round(stream.get_length() * stream.mix_rate))


## Adds the World bus (and its limiter) if it isn't there, and the Impacts and Bed buses that feed it. Static so
## anything that wants to route to them can. Returns World's index.
static func ensure_world_bus() -> int:
	ensure_master_limiter()
	# Round 17: every one of these buses is declared, with its send, in res://default_bus_layout.tres. On the web a
	# send set at runtime silences every sample playback after it (Master included; probed), so _bus only makes a bus
	# where no layout did (a test runner), and everything below DRESSES buses whoever made them, at most once.
	var fresh := AudioServer.get_bus_index(WORLD_BUS) < 0
	var index := _bus(WORLD_BUS, "Master")
	_dress_world(index, fresh)
	_bus(IMPACT_BUS, WORLD_BUS)
	_duck(_bus(BED_BUS, WORLD_BUS), float(LAUNCH_MIX["bed_duck"][0]) if launch_mix() else -20.0,
			float(LAUNCH_MIX["bed_duck"][1]) if launch_mix() else 3.0, 1000.0, 420.0)
	_duck(_bus(GUNFIRE_BUS, WORLD_BUS), float(LAUNCH_MIX["gun_dip"][0]) if launch_mix() else -18.0, 2.0, 2000.0, 350.0)
	_duck(_bus(CROWD_BUS, WORLD_BUS), -22.0, 2.0, 5000.0, 700.0)
	_tune_booth_duck(index)
	return index


## The bus called `bus_name`, made (sending to `send`) only if nothing declared it.
static func _bus(bus_name: String, send: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	return index


## The impacts' duck on a bus (X2, round 5; retuned round 17 G2 from the fight taps: Bed -26/5:1 took a median 14.5 dB
## off engines and small hits for a whole 30-a-side fight), added once.
static func _duck(bus: int, threshold: float, ratio: float, attack_us: float, release_ms: float) -> void:
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i) as AudioEffectCompressor
		if effect != null and effect.sidechain == IMPACT_BUS:
			return
	var duck := AudioEffectCompressor.new()
	duck.sidechain = IMPACT_BUS
	duck.threshold = threshold
	duck.ratio = ratio
	duck.attack_us = attack_us
	duck.release_ms = release_ms
	AudioServer.add_bus_effect(bus, duck)


## X6 (round 5): a limiter on Master. World had one, but the booth and the music summed into Master unlimited, and the
## first full-match recording peaked at +0.1 dBFS with 485 clipped samples, all on the booth's lines. Idempotent;
## everything that makes a bus calls it.
const MASTER_CEILING_DB := -1.0

## `--no-bus-layout` (the layout's control arm): drop res://default_bus_layout.tres at the FIRST bus-building call, so
## the game builds its buses at runtime exactly as before round 17. It has to be here: FxWorld is made by child nodes
## whose _ready runs before main.gd's, so a reset in main wiped World and the booth rebuilt the list Announcer-first
## (round 17: that control arm was not the old game; the launch tree's own print is World-first).
static var _layout_checked := false


static func _drop_layout_if_asked() -> void:
	if _layout_checked:
		return
	_layout_checked = true
	if LaunchFlags.from_environment().has("no-bus-layout"):
		AudioServer.set_bus_layout(AudioBusLayout.new())
		print("AUDIO_BUSES layout=none (dropped before the first bus was built)")


static func ensure_master_limiter() -> void:
	_drop_layout_if_asked()
	var master := AudioServer.get_bus_index("Master")
	if web_sample_mix() and absf(AudioServer.get_bus_volume_db(master) - WEB_MASTER_TRIM_DB) > 0.001:
		AudioServer.set_bus_volume_db(master, WEB_MASTER_TRIM_DB)
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = MASTER_CEILING_DB
	AudioServer.add_bus_effect(master, limiter)


## World's trim and limiter, once (the layout declares the bus at the new trim; --mix=launch sets its own).
static func _dress_world(index: int, fresh: bool) -> void:
	for i in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			return
	if launch_mix():
		AudioServer.set_bus_volume_db(index, float(LAUNCH_MIX["world_trim_db"]))
		var old := AudioEffectLimiter.new()  # the launch mix's: +3 dB make-up, soft clip, no look-ahead
		old.ceiling_db = LIMIT_DB
		old.threshold_db = -4.0
		old.soft_clip_db = 2.0
		AudioServer.add_bus_effect(index, old)
		return
	if fresh:
		AudioServer.set_bus_volume_db(index, WORLD_TRIM_DB)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = WORLD_CEILING_DB
	limiter.pre_gain_db = 0.0
	limiter.release = WORLD_RELEASE_S
	AudioServer.add_bus_effect(index, limiter)


## The booth's duck on World, with BOOTH_DUCK's settings, once the booth's bus exists (a compressor whose sidechain
## bus is missing would compress the battle by itself). Whichever side comes up first: AnnouncerVoice.ensure_bus makes
## its bus and then calls ensure_world_bus, and finds this duck already there.
static func _tune_booth_duck(world: int) -> void:
	if AudioServer.get_bus_index(BOOTH_BUS) < 0:
		return
	var duck: AudioEffectCompressor = null
	for i in AudioServer.get_bus_effect_count(world):
		var effect := AudioServer.get_bus_effect(world, i) as AudioEffectCompressor
		if effect != null and effect.sidechain == BOOTH_BUS:
			duck = effect
	if duck == null:
		duck = AudioEffectCompressor.new()
		duck.sidechain = BOOTH_BUS
		AudioServer.add_bus_effect(world, duck)
	var tuning := booth_duck()
	duck.threshold = float(tuning["threshold"])
	duck.ratio = float(tuning["ratio"])
	duck.attack_us = float(tuning["attack_us"])
	duck.release_ms = float(tuning["release_ms"])


## A world sound at `position`, in one of its takes.
func play_at(sound: String, position: Vector3, volume_offset_db := 0.0) -> void:
	# Not in the tree yet (FxWorld is added deferred; the match announcer speaks at spawn): drop it.
	if muted or not is_inside_tree() or silenced.has(sound):
		return
	sound = String(_today_alias.get(sound, sound))
	sound = String(ALIAS.get(sound, sound)) if not streams.has(sound) else sound
	if not streams.has(sound):
		return
	var mix: Array = MIX.get(sound, [0.0, 0.0])
	if _launch and (LAUNCH_MIX["levels"] as Dictionary).has(sound):
		mix = [float(LAUNCH_MIX["levels"][sound]), mix[1]]
	var level := heard_level_db(float(mix[0]) + volume_offset_db, position)
	var index := _voice_for(level)
	last_voice = null
	if index < 0:
		culled += 1
		return
	var voice := _world[index]
	_voice_level[index] = level
	_voice_started[index] = Time.get_ticks_msec() / 1000.0
	voice.stream = _a_take(sound)
	voice.bus = IMPACT_BUS if sound in IMPACT_SOUNDS else BED_BUS
	voice.position = position
	voice.volume_db = float(mix[0]) + volume_offset_db
	# Inside UNIT_SIZE a sound plays at its own level (Godot's default max_db of +3 lifted every near sound, the
	# loud ones most, until they all met at the limiter).
	voice.max_db = clampf(voice.volume_db, -24.0, 6.0) if not _launch else 3.0  # 3.0: Godot's default, the launch mix
	voice.pitch_scale = 1.0 + _rng.randf_range(-float(mix[1]), float(mix[1]))
	var filtering: Array = (LAUNCH_MIX["filter"] if _launch else DISTANCE_FILTER).get(sound, [])
	voice.attenuation_filter_cutoff_hz = float(filtering[0]) if not filtering.is_empty() else 20500.0
	if filtering.is_empty():
		voice.attenuation_filter_db = 0.0
	elif _launch:
		voice.attenuation_filter_db = float(filtering[1])  # uncompensated, as it was
	else:
		voice.attenuation_filter_db = filter_db_for(voice.volume_db, _distance_to(position), float(filtering[1]))
	voice.play()
	last_voice = voice
	played += 1
	plays[sound] = int(plays.get(sound, 0)) + 1


## One take of a sound, chosen from its pool. Presentation randomness: its own generator, never the simulation's.
func _a_take(sound: String) -> AudioStream:
	var pool: Array = takes.get(sound, [])
	if pool.is_empty():
		return streams[sound]
	if pool.size() == 1:
		return pool[0]
	return pool[_rng.randi_range(0, pool.size() - 1)]


## A UI sound (not positional).
func play_ui(sound: String) -> void:
	if muted or not streams.has(sound) or not is_inside_tree() or silenced.has(sound):
		return
	var voice := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % _ui.size()
	voice.stream = _a_take(sound)
	var mix: Array = MIX.get(sound, [0.0, 0.0])
	voice.volume_db = float(mix[0])
	voice.pitch_scale = 1.0 + _rng.randf_range(-float(mix[1]), float(mix[1]))
	voice.play()
	played += 1


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


## G6: a round in flight appears as an ArcRoundVisual (Match.show_arc, on every peer that draws); its whistle starts
## so that it ends as the round lands.
func _on_node_added(node: Node) -> void:
	if node is ArcRoundVisual:
		track_incoming(node as ArcRoundVisual, _clock)


func track_incoming(round_visual: ArcRoundVisual, now: float) -> void:
	_incoming.append({"to": round_visual.to, "at": now + maxf(0.0, round_visual.seconds - incoming_lead_s())})
	if _incoming.size() > 32:
		_incoming.pop_front()


## How long before landing the whistle starts: its take's length, so its end is the landing.
func incoming_lead_s() -> float:
	var pool: Array = takes.get("shell_incoming", [])
	return (pool[0] as AudioStream).get_length() if not pool.is_empty() else 2.0


func tick_incoming(now: float) -> void:
	for i in range(_incoming.size() - 1, -1, -1):
		if now >= float(_incoming[i]["at"]):
			play_at("shell_incoming", _incoming[i]["to"] + Vector3.UP * 6.0)
			incoming_played += 1
			_incoming.remove_at(i)


## G6: the burning wrecks, from FxWorld's FireSites (the parent this lives in), and the rounds coming down, once a frame.
func _process(delta: float) -> void:
	_clock += delta
	if script_duck_on:
		step_script_duck(delta)
	if not _incoming.is_empty():
		tick_incoming(_clock)
	var fx := get_parent()
	var fires: Variant = fx.get("fires") if fx != null else null
	if fires == null or not (fires is FireSites):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	(get_node("Fires") as FireVoices).update((fires as FireSites).sites, camera.global_position, float(fx.get("now")))


## The script duck, one frame: towards the chosen duck's depth while the booth speaks (fast), back to rest (slow).
## Writes the World bus's volume only when it moves (a runtime bus change per frame is not free on the web).
func step_script_duck(delta: float) -> void:
	var speaking := bool(booth_speaking.call())
	if speaking != _script_duck_speaking:
		_script_duck_speaking = speaking
		print("SCRIPT_DUCK %s t=%.1f" % ["down" if speaking else "up", _clock])
	var target := -script_duck_depth_db(booth_duck()) if speaking else 0.0
	var tau := SCRIPT_DUCK_ATTACK_S if target < _script_duck_db else SCRIPT_DUCK_RELEASE_S
	var next := lerpf(_script_duck_db, target, 1.0 - exp(-delta / tau))
	if absf(next - _script_duck_db) < 0.02 and absf(target - next) < 0.02:
		next = target
	if next == _script_duck_db:
		return
	_script_duck_db = next
	var world := AudioServer.get_bus_index(WORLD_BUS)
	var rest := float(LAUNCH_MIX["world_trim_db"]) if _launch else WORLD_TRIM_DB
	AudioServer.set_bus_volume_db(world, rest + _script_duck_db)


## Whether a booth line is playing: any AudioStreamPlayer under an AnnouncerVoice (looked up once a second).
func _booth_speaking() -> bool:
	_booth_scan_s -= get_process_delta_time()
	if _booth_scan_s <= 0.0 and is_inside_tree():
		_booth_scan_s = 1.0
		_booth_voices = get_tree().root.find_children("*", "AnnouncerVoice", true, false)
	for voice: Node in _booth_voices:
		if not is_instance_valid(voice):
			continue
		for child in voice.get_children():
			if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
				return true
	return false


## Silence every voice (before quitting: a playback still running at exit leaks its stream, e.g. the tank boom's tail).
func stop_all() -> void:
	for voice in _world:
		voice.stop()
	for voice in _ui:
		voice.stop()


func _exit_tree() -> void:
	stop_all()
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func voice_count() -> int:
	return _world.size() + _ui.size()


## How loud a sound of `volume_db` at `position` will be at the listener: Godot's own law, as the probe measured it
## (round 17) - inverse distance from UNIT_SIZE, capped at the sound's own level, times a linear fade to MAX_DISTANCE.
func heard_level_db(volume_db: float, position: Vector3) -> float:
	var distance := _distance_to(position)
	if distance < 0.0:
		return volume_db
	if distance >= max_distance:
		return -INF  # the player itself would be silent out there
	return volume_db + distance_gain_db(distance, unit_size, max_distance)


## dB a sound loses at `distance` (<= 0), the way AudioStreamPlayer3D applies it with max_db at the sound's own level.
static func distance_gain_db(distance: float, unit := UNIT_SIZE, max_distance := MAX_DISTANCE) -> float:
	var fade := maxf(0.0, 1.0 - distance / max_distance)
	if fade <= 0.0:
		return -INF
	return minf(20.0 * log(unit / maxf(distance, 0.001)) / log(10.0), 0.0) + 20.0 * log(fade) / log(10.0)


## How much a voice is dulled at `distance` (dB of its filter shelf), as Godot does it: (1 - its linear gain) times
## filter_db, where the gain INCLUDES the voice's volume - which is why a gun mixed low was dulled even close.
static func effective_filter_db(volume_db: float, distance: float, filter_db: float, unit := UNIT_SIZE,
		max_distance := MAX_DISTANCE, max_db: float = INF) -> float:
	var cap := volume_db if max_db == INF else max_db
	var att := minf(20.0 * log(unit / maxf(distance, 0.001)) / log(10.0) + volume_db, cap)
	var gain := db_to_linear(att) * maxf(0.0, 1.0 - distance / max_distance)
	return (1.0 - minf(1.0, gain)) * filter_db


## The filter_db to give a voice of `volume_db` so that it is dulled as a 0 dB voice at that distance would be:
## distance alone sets the brightness, never the mix level (G2).
static func filter_db_for(volume_db: float, distance: float, filter_db: float) -> float:
	if distance < 0.0:
		return filter_db  # no listener to measure from: Godot's own behaviour
	var wanted := effective_filter_db(0.0, distance, filter_db)
	var share := 1.0 - minf(1.0, db_to_linear(minf(20.0 * log(UNIT_SIZE / maxf(distance, 0.001)) / log(10.0) + volume_db,
			volume_db)) * maxf(0.0, 1.0 - distance / MAX_DISTANCE))
	if share < 0.001:
		return filter_db
	return clampf(wanted / share, -80.0, 0.0)


## Distance from the listener (the camera unless a test set one); -1 when there is none.
func _distance_to(position: Vector3) -> float:
	var at: Variant = listener
	if at == null:
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		if camera == null:
			return -1.0
		at = camera.global_position
	return (at as Vector3).distance_to(position)


## A voice for a sound this loud: a free one, else the quietest playing one if this is louder; -1 = don't play.
## (Wall-clock time here is presentation only: nothing in the simulation reads a sound.)
func _voice_for(level: float) -> int:
	if level < CULL_DB:
		return -1
	for i in _world.size():
		var index := (_next_world + i) % _world.size()
		if not _world[index].playing:
			_next_world = (index + 1) % _world.size()
			return index
	var now := Time.get_ticks_msec() / 1000.0
	var quietest := -1
	var quietest_level := INF
	for i in _world.size():
		var current := _voice_level[i] - (now - _voice_started[i]) * TAIL_DECAY_DB_PER_S
		if current < quietest_level:
			quietest_level = current
			quietest = i
	# Equal counts: the same round fired again takes over its own oldest voice rather than being dropped.
	return quietest if level >= quietest_level else -1
