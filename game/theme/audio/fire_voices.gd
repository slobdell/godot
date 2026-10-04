class_name FireVoices
extends Node3D
## Round 17 G6 (the audit: after a kill the wreck burns on screen for 30 s - flames, smoke, cook-off pops - in
## silence). The VOICES burning wrecks nearest the camera get a looping fire voice that burns down with the fire, and
## every cook-off pop FireSites draws is heard. Reads FireSites' own `sites` list (presentation; nothing reads the
## simulation). SfxSystem owns it and calls update() each frame with FxWorld's fires.

const VOICES := 2
const SOUND := "wreck_fire_loop"
const POP_SOUND := "explosion_small"
const POP_DB := -8.0
const FULL_DB := -4.0
## A fire's loudness follows FireSites' own burn-down (the last 40 % of its life), to this far under FULL_DB.
const BURNT_OUT_DB := -24.0
const HEARING := 120.0

var pops := 0
var _sfx: SfxSystem
var _voices: Array[AudioStreamPlayer3D] = []
var _owner: Array = []  # voice -> the site Dictionary it plays, or null
var _levels: Array[float] = []
var _last_pop := {}  # site (by its start and position) -> the next_pop it last had


func _init(sfx: SfxSystem = null) -> void:
	name = "Fires"
	_sfx = sfx
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Fire%d" % i
		voice.unit_size = 20.0
		voice.max_distance = HEARING * 1.5
		voice.bus = SfxSystem.BED_BUS
		add_child(voice)
		_voices.append(voice)
		_owner.append(null)
		_levels.append(-INF)


func update(sites: Array, camera: Vector3, now: float) -> void:
	var near: Array = []
	for site: Dictionary in sites:
		var distance := camera.distance_to(site["position"])
		if distance <= HEARING:
			near.append([distance, site])
		_heard_pop(site, now)
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	near.resize(mini(near.size(), VOICES))
	var wanted: Array = near.map(func(entry: Array) -> Dictionary: return entry[1])
	for i in VOICES:
		if _owner[i] != null and not wanted.has(_owner[i]):
			_voices[i].stop()
			_owner[i] = null
			_levels[i] = -INF
	for site: Dictionary in wanted:
		var index := _owner.find(site)
		if index < 0:
			index = _owner.find(null)
			if index < 0:
				continue
			_owner[index] = site
			_start(index, site)
		var age := now - float(site["start"])
		var strength := 1.0 - smoothstep(FireSites.BURN_SECONDS * 0.6, FireSites.BURN_SECONDS, age)
		_levels[index] = lerpf(BURNT_OUT_DB, FULL_DB, strength)
		_voices[index].volume_db = _levels[index]


func _start(index: int, site: Dictionary) -> void:
	var voice := _voices[index]
	voice.position = site["position"]
	if _sfx == null or _sfx.muted or _sfx.silenced.has(SOUND):
		return
	var pool: Array = _sfx.takes.get(SOUND, [])
	if pool.is_empty():
		return
	var stream := (pool[randi() % pool.size()] as AudioStreamWAV)
	if stream == null:
		return
	var looping := stream.duplicate() as AudioStreamWAV
	looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looping.loop_end = SfxSystem.loop_frames(looping)
	voice.stream = looping
	voice.play(randf() * looping.get_length())


## FireSites schedules the next pop when it draws one: a site whose next_pop moved on has just popped.
func _heard_pop(site: Dictionary, now: float) -> void:
	var key := "%s@%.2f" % [site["position"], float(site["start"])]
	var next_pop := float(site.get("next_pop", 0.0))
	if _last_pop.has(key) and next_pop > float(_last_pop[key]):
		pops += 1
		if _sfx != null:
			_sfx.play_at(POP_SOUND, (site["position"] as Vector3) + Vector3.UP * 1.4, POP_DB)
	_last_pop[key] = next_pop
	if _last_pop.size() > 64:
		_last_pop.clear()


func burning_voices() -> int:
	return _owner.count(null) * -1 + VOICES


func voiced_positions() -> Array:
	var out: Array = []
	for site in _owner:
		if site != null:
			out.append(site["position"])
	return out


func level_of(index: int) -> float:
	return _levels[index]
