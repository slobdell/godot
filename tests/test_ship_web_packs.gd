extends TestCase
## Round 17 (ship W2, Q3): WebPacks fetches packs.json, then each wanted pack once, keeps it under its md5 and mounts
## it. The transport and the mount are replaced here (a mount would change the running test's resources), and the
## cache points at a test folder (trip-up 54).

const CACHE := "user://test_ship_web_packs"
const PACK := "factions"


func _packs(index: Dictionary, pack_bytes: PackedByteArray) -> WebPacks:
	WebPacks.mounted.clear()
	_wipe()
	var packs := WebPacks.new()
	packs.cache_dir = CACHE
	packs.base_url = "http://test.invalid/packs/"
	packs.wanted = [PACK]
	packs.set_meta("asked", [])
	packs.set_meta("mounts", [])
	packs.fetch_bytes = func(url: String, done: Callable) -> void:
		(packs.get_meta("asked") as Array).append(url.get_file())
		if url.ends_with("packs.json"):
			done.call(JSON.stringify(index).to_utf8_buffer(), true)
		else:
			done.call(pack_bytes, not pack_bytes.is_empty())
	packs.load_pack = func(path: String) -> bool:
		(packs.get_meta("mounts") as Array).append(path)
		return FileAccess.file_exists(path)
	add_to_tree(packs)
	return packs


func _wipe() -> void:
	var dir := ProjectSettings.globalize_path(CACHE)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))


func test_a_pack_is_fetched_kept_under_its_md5_and_mounted() -> void:
	var bytes := "pretend pack".to_utf8_buffer()
	var packs := _packs({PACK: {"file": "factions.pck", "bytes": bytes.size(), "md5": "abc"}}, bytes)
	packs.start()
	assert_eq(packs.loaded, [PACK] as Array[String], "the pack is loaded")
	assert_true(FileAccess.file_exists(CACHE.path_join("factions-abc.pck")), "kept on the device under its md5")
	assert_eq((packs.get_meta("asked") as Array), ["packs.json", "factions.pck"], "the index, then the pack")
	assert_eq((packs.get_meta("mounts") as Array).size(), 1, "mounted once")
	_wipe()


func test_a_kept_pack_is_mounted_without_a_download() -> void:
	var bytes := "pretend pack".to_utf8_buffer()
	var packs := _packs({PACK: {"file": "factions.pck", "bytes": bytes.size(), "md5": "abc"}}, bytes)
	packs.start()
	WebPacks.mounted.clear()  # a new visit: a new process, the file still on the device
	var again := _packs({PACK: {"file": "factions.pck", "bytes": bytes.size(), "md5": "abc"}}, PackedByteArray())
	VoiceFetch._write(CACHE.path_join("factions-abc.pck"), bytes)
	again.start()
	assert_eq(again.loaded, [PACK] as Array[String], "loaded from the device")
	assert_eq((again.get_meta("asked") as Array), ["packs.json"], "only the index travelled")
	_wipe()


func test_a_new_build_is_a_new_file() -> void:
	var bytes := "pretend pack".to_utf8_buffer()
	VoiceFetch._write(CACHE.path_join("factions-old.pck"), bytes)
	var packs := _packs({PACK: {"file": "factions.pck", "bytes": bytes.size(), "md5": "new"}}, bytes)
	VoiceFetch._write(CACHE.path_join("factions-old.pck"), bytes)
	packs.start()
	assert_eq((packs.get_meta("asked") as Array), ["packs.json", "factions.pck"], "a pack under another md5 is fetched again")
	assert_true((packs.get_meta("mounts") as Array)[0].ends_with("factions-new.pck"), "and the new one is mounted")
	_wipe()


func test_a_short_download_is_refused() -> void:
	var packs := _packs({PACK: {"file": "factions.pck", "bytes": 999, "md5": "abc"}}, "short".to_utf8_buffer())
	packs.start()
	assert_true(packs.loaded.is_empty(), "a pack whose size is not the index's is never mounted")
	assert_true((packs.get_meta("mounts") as Array).is_empty(), "nothing mounted")
	_wipe()


func test_a_reload_does_not_fetch_again() -> void:
	var bytes := "pretend pack".to_utf8_buffer()
	var packs := _packs({PACK: {"file": "factions.pck", "bytes": bytes.size(), "md5": "abc"}}, bytes)
	packs.start()
	var after_reload := WebPacks.new()
	after_reload.wanted = [PACK]
	after_reload.fetch_bytes = func(_url: String, _done: Callable) -> void: assert_true(false, "nothing is fetched after a reload")
	add_to_tree(after_reload)
	after_reload.start()
	assert_eq(after_reload.loaded, [PACK] as Array[String], "the pack this process mounted is still there")
	WebPacks.mounted.clear()
	_wipe()
