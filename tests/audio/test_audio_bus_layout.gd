extends TestCase
## Round 17 (guns, from ship's measurement of the browser build): on the web, Godot plays sounds as WebAudio samples,
## and a bus SEND set at runtime (AudioServer.set_bus_send) silences every sample playback after it, Master included
## (probed in a scratch export: add_bus alone, a rename, an effect on Master are harmless; one set_bus_send is not).
## Every bus the game used to make at runtime is therefore declared up front in res://default_bus_layout.tres, with its
## send, and the code only dresses them (limiters, ducks): no runtime send on any path the game takes.

## The ORDER is the old game's, as it printed itself (make bus-order on a git-archive copy of the launch tree 3713fdaa,
## windowed on builder0, round 17): "World>Master Impacts>World Bed>World Gunfire>World Crowd>World Announcer>Master
## Music>Master" - FxWorld (made by child nodes before main.gd's _ready) builds the world buses first, the booth and the
## music attach after. The page's tree 1619596d printed the same. Godot mixes buses by index and a sidechain hears another
## bus's buffer, so the order is part of the mix (~5 dB on the booth's duck between the two orders).
const ORDER := ["World", "Impacts", "Bed", "Gunfire", "Crowd", "Announcer", "Music"]
const WANTED := {"World": "Master", "Impacts": "World", "Bed": "World", "Gunfire": "World", "Crowd": "World",
		"Announcer": "Master", "Music": "Master"}


func _layout() -> Dictionary:
	var layout := load("res://default_bus_layout.tres") as AudioBusLayout
	var buses := {}
	for i in range(1, 32):
		var bus_name: Variant = layout.get("bus/%d/name" % i)
		if bus_name == null:
			break
		buses[String(bus_name)] = String(layout.get("bus/%d/send" % i))
	return buses


func test_every_bus_the_game_uses_is_declared_with_its_send() -> void:
	var buses := _layout()
	for bus in WANTED:
		assert_true(buses.has(bus), "%s is declared in default_bus_layout.tres" % bus)
		assert_eq(buses.get(bus, ""), WANTED[bus], "%s sends to %s" % [bus, WANTED[bus]])


func test_the_buses_keep_the_order_the_game_built_them_in() -> void:
	var layout := load("res://default_bus_layout.tres") as AudioBusLayout
	for i in ORDER.size():
		assert_eq(String(layout.get("bus/%d/name" % (i + 1))), ORDER[i], "bus %d is %s" % [i + 1, ORDER[i]])


func test_the_project_loads_that_layout_at_startup() -> void:
	for bus in WANTED:
		var index := AudioServer.get_bus_index(bus)
		assert_true(index >= 0, "%s exists from startup" % bus)
		if index >= 0:
			assert_eq(String(AudioServer.get_bus_send(index)), WANTED[bus], "%s's send came from the layout" % bus)


func test_declared_buses_are_still_dressed() -> void:
	SfxSystem.ensure_world_bus()
	var world := AudioServer.get_bus_index("World")
	var limited := false
	for i in AudioServer.get_bus_effect_count(world):
		limited = limited or AudioServer.get_bus_effect(world, i) is AudioEffectHardLimiter
	assert_true(limited, "World keeps its limiter though the layout made the bus")
	for bus in ["Bed", "Gunfire", "Crowd"]:
		var index := AudioServer.get_bus_index(bus)
		var keyed := 0
		for i in AudioServer.get_bus_effect_count(index):
			var effect := AudioServer.get_bus_effect(index, i) as AudioEffectCompressor
			keyed += 1 if effect != null and effect.sidechain == SfxSystem.IMPACT_BUS else 0
		assert_eq(keyed, 1, "%s has exactly one impacts' duck, however often it is ensured" % bus)
	SfxSystem.ensure_world_bus()
	var limiters := 0
	for i in AudioServer.get_bus_effect_count(world):
		limiters += 1 if AudioServer.get_bus_effect(world, i) is AudioEffectHardLimiter else 0
	assert_eq(limiters, 1, "and one limiter, not one per call")


func test_the_declared_world_trim_is_the_mix_s() -> void:
	var layout := load("res://default_bus_layout.tres") as AudioBusLayout
	assert_near(float(layout.get("bus/%d/volume_db" % (ORDER.find("World") + 1))), SfxSystem.WORLD_TRIM_DB, 0.001,
			"World is declared at WORLD_TRIM_DB, so the layout and the mix never disagree")


func test_the_web_keeps_sample_playback_and_native_is_untouched() -> void:
	## Round 17: Stream playback on the web was tapped by the lead on a price that was wrong (the "stream" arm was served
	## by a Sample build); measured properly, Stream at ~9 fps in a single-threaded web build plays only ~40 % of the
	## time at Godot's default 50 ms buffer. His tap is void (C17.4); the web keeps Godot's default, Sample (audible and
	## robust with the bus layout), until a re-priced decision.
	assert_eq(int(ProjectSettings.get_setting("audio/general/default_playback_type.web", 1)), 1,
			"the web plays Sample (1), Godot's default")
	assert_eq(int(ProjectSettings.get_setting("audio/general/default_playback_type", -1)), 0,
			"native's own default is Stream, as it always was")
