class_name VoiceFetch
extends Node
## Round 17 (ship W2, option c): the booth's clips fetched over HTTP on first use and kept in `user://voice` (on the
## web, user:// is IndexedDB, so a line heard once is on the device for every later match, offline included).
##
## Why on demand and not a pack: the clips are 3,112 mono Vorbis files, 76.9 MB (assets/announcer/clips), and a match
## says a few dozen of them. A pack costs every player the whole library before the booth can speak; this costs the
## lines tonight's match uses, after the manifest (1.6 MB, which every host compresses). Static hosts serve loose files
## of any number up to their limits (_agents/streams/ship.md, W2), and a 25 KB file is under every per-file cap.
##
## The manifest comes first and the voice joins the booth when it lands; until then the booth is subtitles, as today.
## Behind `--web-voice=fetch` (AnnouncerBooth.voice_source); the default is unchanged until the lead chooses (C17.4).

signal manifest_ready(ok: bool)
signal clip_ready(file: String, ok: bool)

const CACHE_DIR := "user://voice"
## Downloads in flight at once: enough to fetch a line while the next is asked for, few enough not to compete with the
## game's own first seconds.
const MAX_IN_FLIGHT := 4

## Where they are kept (tests point it elsewhere: trip-up 54, a test never writes the player's own user:// files).
var cache_dir := CACHE_DIR
## Where the clips live: an absolute URL ending in "/", or a path relative to the page (resolved in the browser).
var base_url := "voice/"
## Replaceable for tests: fetch(url, done: Callable(bytes: PackedByteArray, ok: bool)). The default is HTTPRequest.
var fetch_bytes: Callable = _http_fetch

var _queue: Array[String] = []
var _in_flight := {}
var _failed := {}
var requested := 0
var fetched := 0
var bytes_fetched := 0


## The cached path of a clip file ("caller/x.ogg"), whether or not it has arrived.
func cached_path(file: String) -> String:
	return cache_dir.path_join(file)


func has_cached(file: String) -> bool:
	return FileAccess.file_exists(cached_path(file))


## Starts fetching the manifest (always fresh: it names the clips, and a new build may name new ones).
func start() -> void:
	DirAccess.make_dir_recursive_absolute(cache_dir)
	fetch_bytes.call(_url("manifest.json"), func(bytes: PackedByteArray, ok: bool) -> void:
		ok = ok and _write(cached_path("manifest.json"), bytes)
		print("VOICE_FETCH manifest %s (%d bytes from %s)" % ["ok" if ok else "FAILED", bytes.size(), _url("manifest.json")])
		manifest_ready.emit(ok))


## True when the clip is already on the device; otherwise asks for it (once) and returns false. `clip_ready` follows.
func ensure(file: String) -> bool:
	if has_cached(file):
		return true
	if _failed.has(file) or _in_flight.has(file) or _queue.has(file):
		return false
	requested += 1
	_queue.append(file)
	_pump()
	return false


func _pump() -> void:
	while not _queue.is_empty() and _in_flight.size() < MAX_IN_FLIGHT:
		var file: String = _queue.pop_front()
		_in_flight[file] = true
		fetch_bytes.call(_url(file), _on_clip.bind(file))


func _on_clip(bytes: PackedByteArray, ok: bool, file: String) -> void:
	_in_flight.erase(file)
	ok = ok and not bytes.is_empty() and _write(cached_path(file), bytes)
	if ok:
		fetched += 1
		bytes_fetched += bytes.size()
	else:
		_failed[file] = true
		print("VOICE_FETCH clip FAILED %s" % file)
	clip_ready.emit(file, ok)
	_pump()


func _url(file: String) -> String:
	var path := file.uri_encode().replace("%2F", "/")
	if base_url.begins_with("http://") or base_url.begins_with("https://"):
		return base_url.path_join(path)
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("new URL(%s, document.baseURI).href" % JSON.stringify(base_url.path_join(path)), true))
	return base_url.path_join(path)


static func _write(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	out.close()
	return true


func _http_fetch(url: String, done: Callable) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		done.call(body, result == HTTPRequest.RESULT_SUCCESS and code == 200))
	if request.request(url) != OK:
		request.queue_free()
		done.call(PackedByteArray(), false)
