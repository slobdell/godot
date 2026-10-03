class_name WebPacks
extends Node
## Round 17 (ship W2, the lead's Q3): content the browser build keeps OUT of its main pack and loads at runtime, so no
## single file nears a static host's per-file cap (GitHub Pages: 100 MB). The main pack is 68.2 MB, this round's sounds
## take it to ~81.8, and the three new factions' art (21.2 MB) on top would be 103 MB: over the cap. So the art ships
## as a second pack, `packs/factions.pck`, a PATCH exported against the main one (only what it lacks; `make export-web
## WEB_PACKS=1`), listed with its md5 in `packs/packs.json`.
##
## On the web it is fetched once into user:// (IndexedDB: kept for every later visit) and loaded with
## ProjectSettings.load_resource_pack; the theme is then re-applied (GameTheme.use) so every unit spawned afterwards
## wears its faction's art. A match started before it lands draws those factions with the Condemned's models, as today.
## OFF unless asked (`?web-packs=factions`) or listed in DEFAULT_PACKS: the lead's tap decides (C17.4).

signal pack_loaded(pack: String, ok: bool)

## The lead's choice turns these on for every browser player. Empty = today's build.
const DEFAULT_PACKS: Array[String] = []
const CACHE_DIR := "user://packs"

var base_url := "packs/"
var wanted: Array[String] = []
## Replaceable for tests: fetch(url, done: Callable(bytes: PackedByteArray, ok: bool)).
var fetch_bytes: Callable = _http_fetch
## Replaceable for tests: load(path) -> bool (ProjectSettings.load_resource_pack).
var load_pack: Callable = func(path: String) -> bool: return ProjectSettings.load_resource_pack(path)
var cache_dir := CACHE_DIR
var loaded: Array[String] = []
## Packs this PROCESS has mounted. A pack stays mounted across scene reloads (FIGHT, REMATCH reload the scene), so a
## reload must not fetch or mount it again; static, like the theme's slot table it fed.
static var mounted := {}


## Adds the loader when this launch asks for packs (web only, unless --web-packs-url names a server).
static func attach(main: Node) -> WebPacks:
	var flags: LaunchFlags = main.flags
	var names: Array[String] = DEFAULT_PACKS.duplicate()
	if flags.has("web-packs"):
		names.clear()
		for name in flags.text("web-packs").split(",", false):
			names.append(name.strip_edges())
	if names.is_empty() or (not OS.has_feature("web") and not flags.has("web-packs-url")):
		return null
	var packs := WebPacks.new()
	packs.name = "WebPacks"
	packs.wanted = names
	packs.base_url = flags.text("web-packs-url", packs.base_url)
	main.add_child(packs)
	packs.start()
	return packs


func _init() -> void:
	# The skirmish opens in its planning pause (the tree paused); an HTTPRequest under a pausable node is never
	# processed, so the download would wait for Space. Presentation, like the music director (round 16, P4).
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> void:
	if wanted.all(func(pack: String) -> bool: return mounted.has(pack)):
		loaded = wanted.duplicate()
		return  # mounted earlier in this process (a scene reload): nothing to fetch
	print("WEB_PACK fetching %s from %s" % [", ".join(wanted), base_url])
	fetch_bytes.call(_url("packs.json"), _on_index)


func _on_index(bytes: PackedByteArray, ok: bool) -> void:
	var index: Variant = JSON.parse_string(bytes.get_string_from_utf8()) if ok else null
	if not index is Dictionary:
		print("WEB_PACK FAILED: no packs.json at %s" % _url("packs.json"))
		for pack in wanted:
			pack_loaded.emit(pack, false)
		return
	for pack in wanted:
		if mounted.has(pack):
			loaded.append(pack)
			pack_loaded.emit(pack, true)
			continue
		var entry: Variant = (index as Dictionary).get(pack)
		if not entry is Dictionary:
			print("WEB_PACK FAILED: %s is not in packs.json" % pack)
			pack_loaded.emit(pack, false)
			continue
		var cached := cache_dir.path_join("%s-%s.pck" % [pack, str(entry.get("md5", "x"))])
		if FileAccess.file_exists(cached):
			_load(pack, cached, 0, true)
			continue
		var started := Time.get_ticks_msec()
		fetch_bytes.call(_url(str(entry["file"])), func(pack_bytes: PackedByteArray, fetched: bool) -> void:
			if not fetched or pack_bytes.size() != int(entry.get("bytes", pack_bytes.size())) or not _write(cached, pack_bytes):
				print("WEB_PACK FAILED: %s (%d of %d bytes)" % [pack, pack_bytes.size(), int(entry.get("bytes", 0))])
				pack_loaded.emit(pack, false)
				return
			_load(pack, cached, Time.get_ticks_msec() - started, false))


func _load(pack: String, path: String, fetch_ms: int, from_cache: bool) -> void:
	var ok: bool = load_pack.call(path)
	if ok:
		loaded.append(pack)
		mounted[pack] = path
		GameTheme.use(GameTheme.theme_name)  # the faction slots exist now: re-merge them
	print("WEB_PACK %s %s (%s, %.1f MB%s)" % ["loaded" if ok else "FAILED to load", pack,
			"from the device" if from_cache else "fetched in %.1f s" % (fetch_ms / 1000.0),
			FileAccess.get_file_as_bytes(path).size() / 1e6 if ok else 0.0, "" if ok else ": load_resource_pack refused"])
	pack_loaded.emit(pack, ok)


func _url(file: String) -> String:
	if base_url.begins_with("http://") or base_url.begins_with("https://"):
		return base_url.path_join(file)
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("new URL(%s, document.baseURI).href" % JSON.stringify(base_url.path_join(file)), true))
	return base_url.path_join(file)


func _write(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	out.close()
	return true


func _http_fetch(url: String, done: Callable) -> void:
	var request := HTTPRequest.new()
	request.body_size_limit = -1
	# HTTPRequest advances once a frame; at the default 64 KB a frame, 21 MB is ~330 frames (two minutes at 3 fps).
	request.download_chunk_size = 8 << 20
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		done.call(body, result == HTTPRequest.RESULT_SUCCESS and code == 200))
	if request.request(url) != OK:
		request.queue_free()
		done.call(PackedByteArray(), false)
