class_name Show
extends Node
## S6: the show director — the arena as a light show. It computes every channel once per frame from FRAME TIME and
## pushes each one as a single write to the material a fixture exposes. `_agents/lighting.md` is the reference.
##
## The lead: *"rather than just randomly having breathing lights, we should immerse ourselves in this whole arena
## sporting event ... imagine light shows in Las Vegas"*, and *"make it beautiful, with the idea that we can easily
## create desirable lighting effects at low compute cost"*.
##
## The whole architecture is the widget spec's: bake the expensive part once, animate only a scalar. Nothing here
## allocates per frame, nothing blurs, nothing adds a draw call and nothing adds a real light. A fixture is whatever
## accepts [method add_fixture] — the show does not know what a city block is, which is why a road stripe or a bridge
## next round is a PATCH and not a new abstraction.
##
## Visual only, and this is a hard contract (S6): the show reads the match and never writes it; it runs on frame time,
## never the tick; nothing in `game/match/`, `game/tank/`, `game/ai/`, `game/units/` or `game/tactics/` may read it.
## Pre-registered: the sim hash does not move.

## `parameter` in a patch entry -> the uniform the show writes. EVERY uniform the show touches starts with `show_`,
## so one grep gives the complete list of what the light show reaches (lighting.md section 4).
const UNIFORMS := {
	&"level": &"show_level",
	&"edge": &"show_edge",
	&"window": &"show_window",
	&"shop": &"show_shop",
}
## Written beside a channel that carries a colour (a victory sweep). Not per-instance: per-instance colour would need
## a second custom-data lane and buys nothing the phase does not.
const COLOR_UNIFORM := &"show_color"
const COLOR_MIX_UNIFORM := &"show_color_mix"
## How far instances of one fixture are pushed out of phase with each other. Constant per arena, so it is written
## ONCE when a fixture registers and never per frame.
const SPREAD_UNIFORM := &"show_spread"
## A fixture's STYLE: a named, whole-fixture shape the patch chooses between, written once at registration like
## spread. Today one fixture has one: the city blocks' edge run is the roof `parapet` (the default, a horizontal
## line that reads as a building) or the full `outline` (every vertical chamfer too, which reads as a wireframe --
## art_direction.md :56's named anti-pattern, kept so the lead can compare against his own words).
const STYLES := {
	&"city_block": {&"parapet": {&"show_chamfer_gain": 0.0}, &"outline": {&"show_chamfer_gain": 1.0}},
}
## A K5 event rippling outward from where it happened: (world x, world z, the wavefront's radius in metres, gain).
## Gain 0 is "no event", which is what every fixture holds until a kill. The crowd's `event_position` pattern.
const EVENT_UNIFORM := &"show_event"
## Parameters that modulate a surface which is lit TODAY. A channel driving one of these must keep a floor above zero
## -- a rim or a window grid that goes fully dark reads as broken, not idle (lighting.md rule 5, the widget spec's
## "the circuit disconnected visually every cycle and looked broken"). `edge` is not here: the blocks have no edge
## emission today, so its identity IS zero and a floor of zero is the look we ship without a patch.
const CORE_PARAMETERS := [&"level", &"window", &"shop"]

## Whether the show drives anything this frame. Turning it OFF writes every fixture back to its identity, so the
## venue renders exactly as it did before the show existed; turning it back on resumes from the same clock.
##
## This exists to be a MEASUREMENT, and it is the only instrument that works on a contended machine: as the
## `no_show` layer of `make perf-scene`, the with-show and without-show halves are measured SECONDS apart inside
## one run, under identical load, instead of minutes or an hour apart under whatever else the builder was doing.
## Two paired runs on 2026-09-20 put the show-on arm 43% FASTER than the show-off arm -- physically impossible as
## an effect, and therefore a measurement of the noise rather than of the show.
@export var driving := true:
	set(value):
		driving = value
		if not value:
			for selector: Variant in _fixtures:
				for target: Object in _fixtures[selector]:
					if is_instance_valid(target):
						_write_identity(target)

## The show's own clock, in frame-time seconds. Never `Time.get_ticks_*`, never the physics tick.
var now := 0.0
## name -> ShowChannel, from the arena's `show.channels`.
var channels := {}
## [{fixture: StringName, parameter: StringName, channel: StringName}] from the arena's `show.patch`.
var bindings: Array = []
## fixture selector -> how far its instances are spread out of phase (0 = all in phase).
var spreads := {}
## fixture selector -> the style the patch chose. `--show-style=<name>` overrides every fixture that has one, so
## `make show-frames` can shoot both variants from one arena file instead of two patches that can drift apart.
var styles := {}
## driven object -> the `show_*` uniforms its shader actually declares, or null when the shader is unknown (a bare
## ShaderMaterial in a test). Writing a parameter a shader does not have is harmless but pointless, and during a
## kill ripple it would be one wasted write per fixture per frame on every shader but the blocks'.
var _accepts := {}
## fixture selector -> the objects being driven. ONE object per selector in practice: the rim's six edges share one
## cached material, all eight city blocks share `CityBlock.facade_material()`, every sign is one MultiMesh. That is
## what keeps the per-frame cost O(patch entries) instead of O(instances), and `writes_last_frame` proves it.
var _fixtures := {}
## Uniform writes performed on the last [method apply]. The test that asserts this equals the number of bound patch
## entries is the guard that stops the show becoming per-instance writes in a year's time.
var writes_last_frame := 0
## The cue book: channel overrides bound to `MatchMood` states, plus the event cues. Loaded once.
var cues: ShowCues
## The mood the cues are following. `lull` until a booth says otherwise, which is also what a muted or headless run
## sees -- there is no booth there, so the show runs its idle and the event cues still fire (lighting.md section 7).
var mood_state := &"lull"

static var _instance: Show
## The blended channel actually pushed each frame: the patch's channel moved toward the active cue's by its weight.
var _live := {}
## channel -> how far the active cue has taken it, 0..1. Attack and release are what keep a cue from popping.
var _weights := {}
## The live event ripple: {"pos": Vector2, "age": float, "gain": float, "speed": float, "life": float}.
var _event := {}
var _mood: MatchMood
var _spectacle_connected := false
## Frame-time seconds left on the FIGHT cue, which holds while the match becomes playable and then hands over to
## the mood. `MatchMood` has no name for that moment (it starts at `lull`), so the show keeps this one itself.
var _fight_left := 0.0
## True for the running show, which follows `Arena.active` so nothing in the venue has to tell it the arena changed.
## False for a Show a test or `make show-report` drives by hand, which is handed its patch directly.
var follows_active_arena := false
## The arena whose patch is loaded.
var _arena := ""
## The last patch problem, kept so `make show-report` and the tests can read it and a bad patch is never silent.
var last_problem := ""


func _init() -> void:
	name = "Show"
	# The venue keeps breathing while the planning pause holds the simulation: the show is frame time, not the tick.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_ensure_cues()
	# `make show-frames`: the strip at the lead's pose. It rides here rather than in FxWorld so nothing feel owns has
	# to know the show exists.
	if follows_active_arena and LaunchFlags.from_environment().has("show-look"):
		add_child(ShowLook.new())


## The running show, or null on a headless peer (servers and tests draw nothing, and the show must never reach the
## simulation). Mirrors `FxWorld.get_instance()`, deliberately: it mounts itself under the scene tree root so no
## file feel owns has to know the show exists.
static func get_instance() -> Show:
	if DisplayServer.get_name() == "headless":
		return null
	# `--no-show`: the control that cancels the cause (orchestration.md lesson 22). With no show, no fixture
	# registers and every material keeps its shader defaults -- which ARE the identity -- so the venue renders
	# exactly as it did before the show existed, on the same binary, the same import cache and the same machine.
	# That is what makes `make perf-scene PERF_FLAGS="--no-show"` a paired control rather than another run.
	var flags := LaunchFlags.from_environment()
	if flags.has("no-show") and not flags.has("show-look"):
		return null
	if is_instance_valid(_instance) and not _instance.is_queued_for_deletion():
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_instance = Show.new()
	_instance.follows_active_arena = true
	# Deferred: the root may be busy adding the main scene when the first fixture asks.
	tree.root.add_child.call_deferred(_instance)
	return _instance


## Load the cue book once. Safe to call from anywhere; a test or a tool that supplies its own book keeps it.
func _ensure_cues() -> void:
	if cues != null:
		return
	cues = ShowCues.load_book()
	if cues.problem != "":
		push_error("SHOW %s" % cues.problem)


## Follow `Arena.active`. Called before every registration and every frame, so a fixture built during an arena's
## construction is always patched against that arena and never against the one before it.
func follow_active_arena() -> void:
	if not follows_active_arena:
		return
	# `--no-show` with `--show-look`: the Show exists only to host the frame tool, and loads no patch. Every fixture
	# keeps its identity, so the frames ARE the branch-point look -- which is how the lead gets a before and an
	# after of the same arena, the same seed and the same pose rather than one frame and a memory.
	if LaunchFlags.from_environment().has("no-show"):
		_arena = str(Arena.active.get("name", ""))
		channels.clear()
		bindings.clear()
		return
	# The cue book must exist BEFORE the first fixture registers, not at _ready(): the venue is built while the show
	# is still a deferred add_child, so a book loaded in _ready() arrives after the arena has already been patched
	# and the FIGHT cue -- the one the loading screen drops into -- would never fire.
	_ensure_cues()
	var arena := str(Arena.active.get("name", ""))
	if arena == _arena:
		return
	# Materials are cached and shared between arenas: put every one of them back to today's look before letting go,
	# or the next arena inherits a cue it never asked for.
	for selector: Variant in _fixtures:
		for driven: Object in _fixtures[selector]:
			if is_instance_valid(driven):
				_write_identity(driven)
	_fixtures.clear()
	_arena = arena
	_weights.clear()
	_live.clear()
	_event = {}
	# The house lights coming down as the loading screen drops: the one cue the mood cannot name.
	_fight_left = float(cues.for_state(ShowCues.FIGHT_STATE).get("hold", 0.0)) if cues != null and arena != "" else 0.0
	last_problem = load_patch(Arena.active.get("show"), arena)
	if last_problem != "":
		push_error("SHOW %s" % last_problem)


## Load an arena's `show` key. Returns "" or a readable reason, naming the arena, the key and what was expected.
## A missing or empty key is not an error: it means today's static look, and every fixture keeps its defaults.
func load_patch(data: Variant, arena := "") -> String:
	channels.clear()
	bindings.clear()
	spreads.clear()
	if data == null:
		return ""
	var where := "arena %s: 'show'" % arena if arena != "" else "'show'"
	if typeof(data) != TYPE_DICTIONARY:
		return "%s must be an object with 'channels' and 'patch'" % where
	var dict: Dictionary = data
	var raw_channels: Variant = dict.get("channels", {})
	if typeof(raw_channels) != TYPE_DICTIONARY:
		return "%s.channels must be an object of {name: {programme, period, phase, floor, ceiling}}" % where
	for key: Variant in raw_channels:
		if typeof(raw_channels[key]) != TYPE_DICTIONARY:
			return "%s.channels.%s must be an object" % [where, key]
		var channel := ShowChannel.from_data(StringName(str(key)), raw_channels[key])
		var problem := channel.problem()
		if problem != "":
			return "%s: %s" % [where, problem]
		channels[channel.channel_name] = channel
	var periods := {}
	var phases := {}
	for key: Variant in channels:
		var channel: ShowChannel = channels[key]
		if channel.programme == &"hold":
			continue  # a constant has no period to beat against anything
		periods[key] = channel.period
		phases[key] = channel.phase
	var loops := ShowChannel.commensurate_problem(periods)
	if loops != "":
		return "%s: %s" % [where, loops]
	var bunched := ShowChannel.phase_spread_problem(phases)
	if bunched != "":
		return "%s: %s" % [where, bunched]
	var raw_patch: Variant = dict.get("patch", [])
	if typeof(raw_patch) != TYPE_ARRAY:
		return "%s.patch must be a list of {fixture, parameter, channel}" % where
	var seen := {}
	for entry: Variant in raw_patch:
		if typeof(entry) != TYPE_DICTIONARY:
			return "%s.patch: every entry is an object {fixture, parameter, channel}" % where
		var patch_entry: Dictionary = entry
		var fixture := StringName(str(patch_entry.get("fixture", "")))
		var parameter := StringName(str(patch_entry.get("parameter", "level")))
		var channel_name := StringName(str(patch_entry.get("channel", "")))
		if fixture == &"":
			return "%s.patch: an entry has no 'fixture'" % where
		if not UNIFORMS.has(parameter):
			return "%s.patch: fixture '%s' has no parameter '%s' (have %s)" % [where, fixture, parameter,
					", ".join(PackedStringArray(UNIFORMS.keys()))]
		if not channels.has(channel_name):
			return "%s.patch: fixture '%s'/'%s' listens to channel '%s', which is not declared (have %s)" \
					% [where, fixture, parameter, channel_name,
					", ".join(PackedStringArray(channels.keys()))]
		var pair := "%s/%s" % [fixture, parameter]
		if seen.has(pair):
			return "%s.patch: '%s' is patched twice ('%s' then '%s') — two writers to one uniform read as flicker" \
					% [where, pair, seen[pair], channel_name]
		seen[pair] = channel_name
		var channel: ShowChannel = channels[channel_name]
		if CORE_PARAMETERS.has(parameter) and channel.programme != &"hold" and channel.level_floor <= 0.0:
			return "%s.patch: '%s' drives a surface that is lit today from channel '%s', whose floor is %.2f — a core fixture never goes fully dark, it reads as broken rather than idle" \
					% [where, pair, channel_name, channel.level_floor]
		if patch_entry.has("style"):
			var style := StringName(str(patch_entry["style"]))
			var available: Dictionary = STYLES.get(fixture, {})
			if not available.has(style):
				return "%s.patch: fixture '%s' has no style '%s' (have %s)" % [where, fixture, style,
						", ".join(PackedStringArray(available.keys())) if not available.is_empty() else "none"]
			styles[fixture] = style
		if patch_entry.has("spread"):
			var spread := float(patch_entry["spread"])
			if spread < 0.0:
				return "%s.patch: fixture '%s' has a negative 'spread'" % [where, fixture]
			if spreads.has(fixture) and not is_equal_approx(float(spreads[fixture]), spread):
				return "%s.patch: fixture '%s' declares two spreads (%.2f and %.2f); it is one property of the bank" \
						% [where, fixture, float(spreads[fixture]), spread]
			spreads[fixture] = spread
		bindings.append({"fixture": fixture, "parameter": parameter, "channel": channel_name})
	for fixture: Variant in _fixtures:
		_write_spread(fixture)
		_write_style(fixture)
	return ""


## The style in force for `selector`: the patch's, unless `--show-style=` overrides it.
func style_of(selector: StringName) -> StringName:
	var available: Dictionary = STYLES.get(selector, {})
	if available.is_empty():
		return &""
	var wanted := StringName(LaunchFlags.from_environment().text("show-style"))
	if available.has(wanted):
		return wanted
	return StringName(str(styles.get(selector, available.keys()[0])))


func _write_style(selector: StringName) -> void:
	var available: Dictionary = STYLES.get(selector, {})
	if available.is_empty():
		return
	var chosen: Dictionary = available[style_of(selector)]
	for driven: Object in _fixtures.get(selector, []):
		for uniform: Variant in chosen:
			if _takes(driven, uniform):
				driven.set_shader_parameter(uniform, chosen[uniform])


## A fixture offers the show one object to drive — a ShaderMaterial, or anything with `set_shader_parameter`. Call it
## once per DRIVEN OBJECT, never once per instance: eight city blocks register the one shared `facade_material()`
## between them, and registering the same object twice is a no-op.
func add_fixture(selector: StringName, driven: Object) -> void:
	if driven == null or not driven.has_method("set_shader_parameter"):
		return
	follow_active_arena()
	var list: Array = _fixtures.get(selector, [])
	if list.has(driven):
		return
	list.append(driven)
	_fixtures[selector] = list
	_accepts[driven] = _uniforms_of(driven)
	_write_spread(selector)
	_write_style(selector)
	_apply_defaults(selector, driven)


## The `show_*` uniform names `driven`'s shader declares, or an empty dictionary meaning "unknown, write anything"
## (a ShaderMaterial with no shader, which is what a headless test uses).
func _uniforms_of(driven: Object) -> Dictionary:
	if not driven.has_method("get_shader"):
		return {}
	var shader: Shader = driven.get_shader()
	if shader == null:
		return {}
	var names := {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		var uniform := StringName(str(entry.get("name", "")))
		if str(uniform).begins_with("show_"):
			names[uniform] = true
	return names


## Whether it is worth writing `uniform` to `driven` at all.
func _takes(driven: Object, uniform: StringName) -> bool:
	var names: Dictionary = _accepts.get(driven, {})
	return names.is_empty() or names.has(uniform)


## The channel actually being pushed for `name` -- the patch's, or the cue-blended one when a cue is running. What a
## frame is really showing, which is what `make show-frames` reports beside each capture.
func live_channel(name: StringName) -> ShowChannel:
	return _live.get(name, channels.get(name))


## Everything a fixture registered for `selector` (for tests and `make show-report`).
func fixtures_for(selector: StringName) -> Array:
	return _fixtures.get(selector, [])


func _write_spread(selector: StringName) -> void:
	var spread := float(spreads.get(selector, 0.0))
	for driven: Object in _fixtures.get(selector, []):
		if _takes(driven, SPREAD_UNIFORM):
			driven.set_shader_parameter(SPREAD_UNIFORM, spread)


## A fixture that nothing patches must look exactly as it does today, so any parameter with no binding is written
## back to its identity value the moment it registers. Without this a fixture would keep whatever a previous arena's
## cue left on a cached, shared material.
func _apply_defaults(selector: StringName, driven: Object) -> void:
	var bound := {}
	for binding: Dictionary in bindings:
		if binding["fixture"] == selector:
			bound[binding["parameter"]] = true
	for parameter: Variant in UNIFORMS:
		if bound.has(parameter) or not _takes(driven, UNIFORMS[parameter]):
			continue
		driven.set_shader_parameter(UNIFORMS[parameter], identity_for(parameter))
	if _takes(driven, COLOR_MIX_UNIFORM):
		driven.set_shader_parameter(COLOR_MIX_UNIFORM, 0.0)
	if _takes(driven, EVENT_UNIFORM):
		driven.set_shader_parameter(EVENT_UNIFORM, Vector4.ZERO)


## Every show parameter back to the value that reproduces today's look.
func _write_identity(driven: Object) -> void:
	for parameter: Variant in UNIFORMS:
		driven.set_shader_parameter(UNIFORMS[parameter], identity_for(parameter))
	driven.set_shader_parameter(COLOR_MIX_UNIFORM, 0.0)
	driven.set_shader_parameter(SPREAD_UNIFORM, 0.0)
	driven.set_shader_parameter(EVENT_UNIFORM, Vector4.ZERO)


## The packed vec4 that reproduces today's look for a parameter: a constant 1.0 for a multiplier, a constant 0 for
## the edge emission the blocks do not have today.
static func identity_for(parameter: StringName) -> Vector4:
	return Vector4(0.0, 0.0, 0.0, 1.0) if parameter == &"edge" else Vector4(1.0, 0.0, 0.0, 1.0)


func _process(delta: float) -> void:
	now += delta
	_fight_left = maxf(_fight_left - delta, 0.0)
	follow_active_arena()
	_listen_for_events()
	read_mood()
	apply(now, delta)


## The booth owns the one `MatchMood` in a match (`announcer_booth.gd:91`), and a windowed launch -- the game the
## lead plays -- always attaches one. The show NEVER grows a second: two moods advancing independently from one
## event stream disagree in ways nobody can reproduce (feel, 2026-09-20). Lazy, cached, copes with null, which is
## exactly `CrowdVoice._mood()`'s pattern.
func read_mood() -> void:
	if _mood == null and is_inside_tree():
		var booth := get_tree().get_first_node_in_group(CrowdVoice.BOOTH_GROUP) as AnnouncerBooth
		if booth != null:
			_mood = booth.mood
	if _fight_left > 0.0:
		mood_state = ShowCues.FIGHT_STATE
		return
	if _mood != null:
		mood_state = StringName(str(_mood.current().get("state", "lull")))


func _listen_for_events() -> void:
	if _spectacle_connected:
		return
	var fx := FxWorld.get_instance()
	if fx == null:
		return
	fx.spectacle.connect(_on_spectacle)
	_spectacle_connected = true


## A kill (weight 1.0) or a hit (~0.15) somewhere in the venue. The same bus the crowd reacts to, read and never
## written -- the show is visual only.
func _on_spectacle(position: Vector3, weight: float) -> void:
	fire_event(position, weight)


## Start the ripple, if `weight` clears the cue's bar. Public so `make show-frames` can shoot a cue and a headless
## test can drive one -- the signal handler is a one-line wrapper on it.
func fire_event(position: Vector3, weight: float) -> void:
	if cues == null or not cues.events.has(&"kill"):
		return
	var cue: Dictionary = cues.events[&"kill"]
	if weight < float(cue["min_weight"]):
		return
	_event = {"pos": Vector2(position.x, position.z), "age": 0.0, "gain": float(cue["gain"]),
			"speed": float(cue["speed"]), "life": float(cue["life"])}


## Put the show into `state` and settle every channel there immediately, without waiting out the attack. For
## `make show-frames` and for tests: the live path always ramps.
func settle_into(state: StringName, t: float) -> void:
	mood_state = state
	_fight_left = 0.0
	for i in 2:
		_advance_cue(t, 1000.0)


## Push every bound channel at frame time `t`. Pure in `t`: the same `t` writes the same values, which is what lets a
## headless test drive the show without a clock. Returns the number of uniform writes it performed.
func apply(t: float, delta := 0.0) -> int:
	var writes := 0
	if not driving:
		writes_last_frame = 0
		return 0
	_advance_cue(t, delta)
	for binding: Dictionary in bindings:
		var channel: ShowChannel = _live.get(binding["channel"], channels[binding["channel"]])
		var packed := channel.packed(t)
		var uniform: StringName = UNIFORMS[binding["parameter"]]
		for driven: Object in _fixtures.get(binding["fixture"], []):
			if not is_instance_valid(driven):
				continue
			driven.set_shader_parameter(uniform, packed)
			writes += 1
			if channel.color_mix > 0.0:
				driven.set_shader_parameter(COLOR_UNIFORM, Vector3(channel.color.r, channel.color.g, channel.color.b))
				driven.set_shader_parameter(COLOR_MIX_UNIFORM, channel.color_mix)
				writes += 2
	writes += _push_event(delta)
	writes_last_frame = writes
	return writes


## Move every channel toward the cue the current mood asks for, at the cue's attack, and back at its release. The
## clock is RETUNED rather than recomputed (`ShowChannel.retune`), so a rim going from a 24 s breathe to a 6 s chase
## changes rate without tearing. With `delta == 0` nothing moves, which is what keeps `make show-frames` a pure
## function of `t` and its strip reproducible on any machine.
func _advance_cue(t: float, delta: float) -> void:
	if cues == null:
		return
	var cue := cues.for_state(mood_state)
	var overrides: Dictionary = cue["set"]
	var attack := float(cue["attack"])
	var release := float(cue["release"])
	for key: Variant in channels:
		var base: ShowChannel = channels[key]
		var wanted: Dictionary = overrides.get(str(key), {})
		var target := 1.0 if not wanted.is_empty() else 0.0
		var weight := float(_weights.get(key, 0.0))
		if delta > 0.0:
			var rate := delta / (attack if target > weight else release)
			weight = move_toward(weight, target, rate)
		_weights[key] = weight
		if weight <= 0.0 and not _live.has(key):
			continue
		var blended := ShowCues.blend(base, wanted, weight, winner_color())
		# Carry the clock across: the offset belongs to the channel's history, not to this frame's blend. The
		# channel we are coming FROM is the live one if a cue is already running, and otherwise the patch's own --
		# and getting that second case wrong is a real jump, not a rounding one: the first frame of a cue moves the
		# rim's period 24.0 -> 23.x, which at t = 40 s is 0.4 rad of clock if it is recomputed instead of retuned.
		var previous: ShowChannel = _live.get(key, base)
		blended.clock_offset = previous.clock_offset
		if not is_equal_approx(previous.period, blended.period):
			var was := blended.period
			blended.period = previous.period
			blended.retune(was, t)
		_live[key] = blended


## The winning team's colour, for the one team-coloured cue in the venue (the victory sweep). White until a match
## has a winner, which is also what a venue with no match sees.
func winner_color() -> Color:
	if _mood == null or str(_mood.winner) == "":
		return Color.WHITE
	return GameTheme.team_color(0 if str(_mood.winner) == "green" else 1)


## The event ripple: one vec4 per registered fixture while a kill is travelling outward, and nothing at all the rest
## of the time. Ages on frame time like everything else here.
func _push_event(delta: float) -> int:
	if _event.is_empty():
		return 0
	var age := float(_event["age"]) + delta
	_event["age"] = age
	var life := float(_event["life"])
	var pos: Vector2 = _event["pos"]
	var value := Vector4(pos.x, pos.y, age * float(_event["speed"]),
			float(_event["gain"]) * clampf(1.0 - age / life, 0.0, 1.0))
	if age >= life:
		_event = {}
		value = Vector4.ZERO  # one last write to put every fixture back where it was
	var writes := 0
	for selector: Variant in _fixtures:
		for driven: Object in _fixtures[selector]:
			if not is_instance_valid(driven) or not _takes(driven, EVENT_UNIFORM):
				continue
			driven.set_shader_parameter(EVENT_UNIFORM, value)
			writes += 1
	return writes


## What the patch resolved to, for `make show-report ARENA=<name>`: every knob it landed on, so a wrong value shows
## up in the artefact instead of in a frame three days later (lesson 44).
func report() -> Dictionary:
	var channel_rows := {}
	for key: Variant in channels:
		var channel: ShowChannel = channels[key]
		channel_rows[str(key)] = {
			"programme": str(channel.programme),
			"period_s": channel.period,
			"phase_rad": channel.phase,
			"floor": channel.level_floor,
			"ceiling": channel.level_ceiling,
			"sharpness": channel.sharpness,
			"color": channel.color.to_html(false) if channel.color_mix > 0.0 else "",
			"color_mix": channel.color_mix,
		}
	var patch_rows := []
	for binding: Dictionary in bindings:
		patch_rows.append({
			"fixture": str(binding["fixture"]),
			"parameter": str(binding["parameter"]),
			"uniform": str(UNIFORMS[binding["parameter"]]),
			"channel": str(binding["channel"]),
			"spread": float(spreads.get(binding["fixture"], 0.0)),
			"style": str(style_of(binding["fixture"])),
			"registered_objects": _fixtures.get(binding["fixture"], []).size(),
		})
	return {
		"channels": channel_rows,
		"patch": patch_rows,
		"bound_patch_entries": bindings.size(),
		"writes_per_frame": writes_for(0.0),
		"uniforms": PackedStringArray(UNIFORMS.values()),
	}


## How many uniform writes one frame costs, without performing them. O(patch entries): a bank of eight blocks or
## forty signs costs what one costs, because a fixture registers its driven material, not its instances.
func writes_for(_t: float) -> int:
	var writes := 0
	for binding: Dictionary in bindings:
		var channel: ShowChannel = channels[binding["channel"]]
		var per_object := 3 if channel.color_mix > 0.0 else 1
		writes += per_object * _fixtures.get(binding["fixture"], []).size()
	return writes
