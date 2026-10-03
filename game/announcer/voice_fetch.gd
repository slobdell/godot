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
## Replaceable for tests: fetch(url, done: Callable(bytes: PackedByteArray, ok: bool)). The default is the browser's own
## fetch() on the web (async, not frame-bound) and HTTPRequest elsewhere. Measured (laptop, headless Chrome at 3 fps):
## through HTTPRequest, which advances once a frame and reads 64 KB a frame, the 1.66 MB manifest took 30 s and three
## of four lines missed LATE_S at 1.5-1.6 s; a line's latency was frames, not network.
var fetch_bytes: Callable = _js_fetch if OS.has_feature("web") else _http_fetch
var _js_pending := {}
var _js_next := 1

## The line families a match's first minute is said from: when the voice joins, their clips for THIS arena and THESE
## two factions are fetched in the background (`prefetch`), so the opening is local. Measured at 2-3 fps (laptop,
## headless): a clip fetched on cue took 1.35-2.32 s in a match's busy first minute, past LATE_S; a whole match's
## possible set is ~53 MB / 2,200 clips (most lines name no faction or arena), so only the opening is prefetched.
const OPENING := ["pa.welcome", "caller.intro", "caller.army", "color.army", "caller.contact", "color.contact"]

var _queue: Array[String] = []
var _background: Array[String] = []
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


func _init() -> void:
	# The skirmish opens in its planning pause (the tree paused); an HTTPRequest under a pausable node is never
	# processed, so the download would wait for Space. Presentation, like the music director (round 16, P4).
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	_background.erase(file)  # asked for on cue now: ahead of the background
	requested += 1
	_queue.append(file)
	_pump()
	return false


## Fetch these in the background, behind every clip asked for on cue.
func prefetch(files: PackedStringArray) -> void:
	for file in files:
		if not has_cached(file) and not _background.has(file) and not _queue.has(file) and not _in_flight.has(file):
			_background.append(file)
	_pump()


## The opening's clips for this arena and these factions, from the manifest: every variant of an OPENING line whose
## slot values name no other faction and no other arena.
static func opening_set(manifest: Dictionary, factions: Array, arena: String, arenas: Array) -> PackedStringArray:
	var files := PackedStringArray()
	var clips: Dictionary = manifest.get("clips", {})
	var lines: Dictionary = manifest.get("lines", {})
	for line_id: String in lines:
		if not OPENING.has(".".join(line_id.split(".").slice(0, 2))):
			continue
		var variants: Dictionary = lines[line_id].get("variants", {})
		for key: String in variants:
			var ok := true
			for token in key.split("."):
				if (FactionArt.FACTIONS.has(token) and not factions.has(token)) or (arenas.has(token) and token != arena):
					ok = false
					break
			var clip: String = variants[key]
			if ok and clips.has(clip):
				files.append(String(clips[clip]["file"]))
	return files


func _pump() -> void:
	while (not _queue.is_empty() or not _background.is_empty()) and _in_flight.size() < MAX_IN_FLIGHT:
		var file: String = _queue.pop_front() if not _queue.is_empty() else _background.pop_front()
		if has_cached(file):
			continue
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


## The browser fetches; the bytes cross as base64 (JavaScriptBridge passes strings), polled once a frame.
func _js_fetch(url: String, done: Callable) -> void:
	var id := _js_next
	_js_next += 1
	_js_pending[id] = done
	JavaScriptBridge.eval("""(function(){ window.__voiceFetch = window.__voiceFetch || {}; window.__voiceFetch[%d] = null;
		fetch(%s).then(r => r.ok ? r.arrayBuffer() : Promise.reject(r.status)).then(b => {
			const u = new Uint8Array(b); let s = '';
			for (let i = 0; i < u.length; i += 32768) s += String.fromCharCode.apply(null, u.subarray(i, i + 32768));
			window.__voiceFetch[%d] = btoa(s); }).catch(() => { window.__voiceFetch[%d] = '!'; }); })()""" % [id, JSON.stringify(url), id, id], true)


func _process(_delta: float) -> void:
	if _js_pending.is_empty():
		return
	for id: int in _js_pending.keys():
		var got: Variant = JavaScriptBridge.eval("(function(){ const v = window.__voiceFetch[%d]; if (v !== null) delete window.__voiceFetch[%d]; return v; })()" % [id, id], true)
		if got == null:
			continue
		var done: Callable = _js_pending[id]
		_js_pending.erase(id)
		var text := str(got)
		if text == "!":
			done.call(PackedByteArray(), false)
		else:
			done.call(Marshalls.base64_to_raw(text), true)


func _http_fetch(url: String, done: Callable) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		done.call(body, result == HTTPRequest.RESULT_SUCCESS and code == 200))
	if request.request(url) != OK:
		request.queue_free()
		done.call(PackedByteArray(), false)
