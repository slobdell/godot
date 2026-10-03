extends TestCase
## Round 17 (ship W2, option c): the browser's booth fetches each clip on first use (VoiceFetch). A line waits up to
## AnnouncerVoice.LATE_S for its clip and is spoken when it lands; later than that it stays subtitles. The transport is
## replaced here by a reader over the real clips folder with a chosen delay, and the cache by a test folder (trip-up 54).

const CLIPS := "res://assets/announcer/clips"
const FILE := "pa/pa.control.01@gangs.ogg"
const CACHE := "user://test_ship_voice_fetch"


func _clean() -> void:
	var path := ProjectSettings.globalize_path(CACHE)
	if DirAccess.dir_exists_absolute(path):
		_remove_tree(path)


func _remove_tree(path: String) -> void:
	for dir in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(dir))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A fetcher whose "network" reads the project's clips after `delay_s` (0 = at once), counting the requests.
func _fetcher(delay_s: float) -> VoiceFetch:
	_clean()
	var fetch := VoiceFetch.new()
	fetch.cache_dir = CACHE
	fetch.base_url = "http://test.invalid/voice/"
	fetch.set_meta("asked", [])
	fetch.fetch_bytes = func(url: String, done: Callable) -> void:
		(fetch.get_meta("asked") as Array).append(url)
		var file := url.trim_prefix(fetch.base_url).uri_decode()
		var bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(CLIPS).path_join(file))
		if delay_s > 0.0:
			await tree.create_timer(delay_s).timeout
		done.call(bytes, not bytes.is_empty())
	add_to_tree(fetch)
	return fetch


func _voice(fetch: VoiceFetch) -> AnnouncerVoice:
	var voice := AnnouncerVoice.new()
	voice.load_clips(CACHE)
	voice.manifest = {"lines": {"pa.control.01": {"variants": {"gangs": "c1"}}}, "clips": {"c1": {"file": FILE}}}
	voice.fetch = fetch
	add_to_tree(voice)
	return voice


const CUE := {"line_id": "pa.control.01", "variant_key": "gangs", "speaker": "pa"}


func test_a_clip_is_fetched_once_cached_and_then_local() -> void:
	var fetch := _fetcher(0.0)
	await wait_physics_frames(1)
	assert_true(not fetch.ensure(FILE), "a clip not on the device is not ready")
	await wait_physics_frames(1)
	assert_true(fetch.has_cached(FILE), "it is on the device after the fetch")
	assert_true(fetch.ensure(FILE), "and ready the next time it is asked for")
	assert_eq((fetch.get_meta("asked") as Array).size(), 1, "one request, however often it is asked for")
	assert_eq(FileAccess.get_file_as_bytes(fetch.cached_path(FILE)).size(),
			FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(CLIPS).path_join(FILE)).size(), "the bytes are the clip's")
	_clean()


func test_a_line_whose_clip_lands_in_time_is_spoken_late() -> void:
	var fetch := _fetcher(0.3)
	var voice := _voice(fetch)
	await wait_physics_frames(1)
	assert_true(not voice.play(CUE), "the first time, the clip is not here yet: nothing plays at once")
	assert_true(not voice.is_speaking(), "silent while it travels")
	await tree.create_timer(0.6).timeout
	assert_true(voice.is_speaking(), "it is spoken when it lands, inside LATE_S")
	assert_eq(voice.late_lines, 1, "counted as a late line")
	assert_true(voice._player.stream is AudioStreamOggVorbis, "from the fetched Ogg file")
	_clean()


func test_a_line_whose_clip_is_too_late_stays_subtitles() -> void:
	var fetch := _fetcher(AnnouncerVoice.LATE_S + 0.4)
	var voice := _voice(fetch)
	await wait_physics_frames(1)
	voice.play(CUE)
	await tree.create_timer(AnnouncerVoice.LATE_S + 0.8).timeout
	assert_true(not voice.is_speaking(), "a clip that lands after LATE_S does not talk over what came next")
	assert_eq(voice.missed_lines, 1, "counted as missed")
	assert_true(fetch.has_cached(FILE), "but it is kept: the next time this line is said, it is local")
	assert_true(voice.play(CUE), "and then it plays at once")
	_clean()


func test_the_editor_reads_the_project_clips_folder() -> void:
	assert_eq(AnnouncerBooth.clips_folder(AnnouncerBooth.DEFAULT_CLIPS), ProjectSettings.globalize_path(CLIPS),
			"in the editor (and the tests) the booth reads the project's folder, as before")


func test_the_opening_set_is_this_arena_and_these_factions_only() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(CLIPS).path_join("manifest.json")))
	var arenas: Array = Array(DirAccess.get_files_at("res://arenas")).map(func(f: String) -> String: return f.get_basename())
	var files := VoiceFetch.opening_set(manifest, ["gangs", "law"], "yard", arenas)
	assert_true(files.size() > 20, "an opening worth prefetching (%d clips)" % files.size())
	var bytes := 0
	for file in files:
		bytes += FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(CLIPS).path_join(file)).size()
		assert_true(not file.contains("condemned") and not file.contains("syndicate"), "no other faction's line: " + file)
		assert_true(not file.contains("@boneyard") and not file.contains("@sumps"), "no other arena's welcome: " + file)
	assert_true(files.has("pa/pa.welcome.01@yard.ogg"), "the Yard's own welcome is in it")
	assert_true(bytes < 8_000_000, "a few MB, not the match's 53 (%.1f MB)" % (bytes / 1e6))
	print("MEASURE opening_set gangs v law on the yard: %d clips, %.2f MB" % [files.size(), bytes / 1e6])
