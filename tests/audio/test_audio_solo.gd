extends TestCase
## Stretch (round 5): --audio-solo=<layer> plays one layer of the mix for tuning.


func test_no_solo_plays_everything_and_a_solo_plays_only_its_layer() -> void:
	for layer in AudioSolo.LAYERS:
		assert_true(AudioSolo.allows(layer, ""), "%s plays in the full mix" % layer)
	assert_true(AudioSolo.allows("guns", "guns"), "soloing guns plays guns")
	assert_true(not AudioSolo.allows("engines", "guns"), "and nothing else")


func test_every_sound_belongs_to_a_layer() -> void:
	for sound in SfxSystem.SOUNDS:
		assert_true(AudioSolo.layer_of(sound) in AudioSolo.LAYERS, "%s is in a real layer" % sound)
	assert_eq(AudioSolo.layer_of("tank_boom"), "guns", "a cannon firing is a gun")
	assert_eq(AudioSolo.layer_of("shell_hit_armor"), "impacts", "a shell landing is an impact")
