extends SceneTree
## What the game's audio costs the frame, headless: `make audio-bench`.
##
## M1 gives audio 0.3 ms of script time per frame for the booth, music and crowd (fx_tricks.md). `make perf-scene`
## runs with --mute, so it cannot see any of it. This drives every audio system this stream owns through a battle
## far busier than a real one, frame by frame at 60 fps, and times each system's per-frame work separately:
##   - 60 vehicles moving (engine voices chosen, pitched and placed every frame);
##   - 16 machine gunners streaming, and a shot, hit or impact every frame from someone else (pooled voices);
##   - the announcer director and the match mood following a real fixture, replayed faster than real time so the
##     booth is always busy;
##   - the music director following that mood, stems and all.
## Prints AUDIO_BENCH lines (mean and p95 per system) and writes build/audio/bench.json. Informational: the laptop is
## shared, so it reports rather than gates.

const FRAMES := 1200
const DELTA := 1.0 / 60.0
const VEHICLES := 60
const GUNNERS := 16
const BUDGET_MS := 0.3
const FIXTURE := "res://tests/announcer/fixtures/control_swing.jsonl"
## The fixture is replayed this much faster than it happened, looping, so the booth never goes quiet.
const REPLAY_SPEED := 4.0
const ONE_SHOTS := ["tank_boom", "autocannon_shot", "shell_hit_armor", "bullet_hit_metal", "dirt_impact",
		"explosion_small", "ricochet", "mortar_launch", "laser_pulse", "explosion_big"]

var _times := {}


func _initialize() -> void:
	var root_3d := Node3D.new()
	root.add_child(root_3d)
	var sfx := SfxSystem.new()
	root_3d.add_child(sfx)
	var gunfire := GunfireLoops.new()
	root_3d.add_child(gunfire)
	gunfire.use_streams(sfx.streams)
	var engines := EngineSystem.new()
	root_3d.add_child(engines)
	engines.use_streams(sfx.streams)
	var vehicles: Array[Node3D] = []
	for i in VEHICLES:
		var vehicle := Node3D.new()
		root_3d.add_child(vehicle)
		vehicle.position = Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))
		vehicles.append(vehicle)
	await process_frame  # everything above is in the tree from here on
	for i in VEHICLES:
		engines.add(vehicles[i], ["engine_diesel", "engine_v8", "engine_electric"][i % 3])
	var events := _read_fixture(FIXTURE)
	var director := AnnouncerDirector.new(AnnouncerLibrary.load_default(), 1)
	var mood := MatchMood.new("green")
	var music := MusicDirector.new()
	music.load_tracks()
	root.add_child(music)
	music.follow(mood)

	var clock := 0.0
	var replay_offset := 0.0
	var next_event := 0
	var cues := 0
	for frame in FRAMES:
		clock += DELTA
		var match_time := clock * REPLAY_SPEED - replay_offset
		# The announcer and the mood, fed whatever the fixture says happened by now.
		var started := Time.get_ticks_usec()
		while next_event < events.size() and float(events[next_event]["t"]) <= match_time:
			director.push_event(events[next_event])
			mood.push_event(events[next_event])
			next_event += 1
		mood.advance(match_time)
		cues += director.advance(match_time).size()
		_add("booth_and_mood", started)
		if next_event >= events.size():  # loop the match: a fresh booth, the same load
			next_event = 0
			replay_offset += match_time + 1.0
			director = AnnouncerDirector.new(AnnouncerLibrary.load_default(), frame)
			mood = MatchMood.new("green")
			music.follow(mood)

		started = Time.get_ticks_usec()
		music._process(DELTA)
		_add("music", started)

		for i in VEHICLES:
			vehicles[i].position += Vector3(sin(clock + i), 0, cos(clock * 0.7 + i)) * 8.0 * DELTA
		started = Time.get_ticks_usec()
		engines.update(Vector3.ZERO, DELTA)
		_add("engines", started)

		started = Time.get_ticks_usec()
		for g in GUNNERS:
			gunfire.trigger("gunner%d" % g, vehicles[g].position, clock)
		gunfire.update(Vector3.ZERO, clock)
		_add("gunfire", started)

		started = Time.get_ticks_usec()
		sfx.play_at(ONE_SHOTS[frame % ONE_SHOTS.size()], vehicles[(frame * 7) % VEHICLES].position)
		_add("one_shots", started)

		await process_frame

	var report := {"frames": FRAMES, "vehicles": VEHICLES, "gunners": GUNNERS, "cues": cues, "systems": {}}
	var total_mean := 0.0
	for system in _times:
		var samples: Array = _times[system]
		samples.sort()
		var mean := 0.0
		for value in samples:
			mean += float(value)
		mean /= samples.size()
		var p95 := float(samples[int(samples.size() * 0.95)])
		total_mean += mean
		report["systems"][system] = {"mean_ms": snappedf(mean, 0.0001), "p95_ms": snappedf(p95, 0.0001)}
		print("AUDIO_BENCH %-15s mean %.4f ms  p95 %.4f ms" % [system, mean, p95])
	report["total_mean_ms"] = snappedf(total_mean, 0.0001)
	report["budget_ms"] = BUDGET_MS
	print("AUDIO_BENCH total mean %.4f ms per frame (budget %.1f ms for booth, music and crowd), %d cues spoken, %d world voices" % [
			total_mean, BUDGET_MS, cues, sfx.voice_count()])
	var out := FileAccess.open(OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://audio_bench.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(report, " "))
	sfx.stop_all()
	gunfire.stop_all()
	music.queue_free()
	root_3d.queue_free()
	await process_frame
	print("AUDIO_BENCH_DONE")
	quit()


func _add(system: String, started_usec: int) -> void:
	if not _times.has(system):
		_times[system] = []
	_times[system].append((Time.get_ticks_usec() - started_usec) / 1000.0)


func _read_fixture(path: String) -> Array:
	var events: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parser := JSON.new()
		if parser.parse(line) == OK:
			events.append(parser.data)
	return events
