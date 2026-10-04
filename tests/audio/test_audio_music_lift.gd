extends TestCase
## Round 17: the guns got ~10 dB louder against the music (mix-ab: the music 7-9 dB further under the battle, its own
## level unchanged). In a MATCH the music bus is lifted IN_MATCH_LIFT_DB (the page's "about half the gap back", the
## worker's pick until the lead's tap); the garage and the title keep their level, where there is no battle.


func test_the_music_is_lifted_in_a_match_and_not_in_the_garage() -> void:
	var music := MusicDirector.new()
	music.load_stream = func(_path: String) -> AudioStream: return null
	add_to_tree(music)
	var bus := AudioServer.get_bus_index(MusicDirector.BUS)
	music.volume_db = 0.0
	music.set_state("garage")
	assert_near(AudioServer.get_bus_volume_db(bus), MusicDirector.TRIM_DB, 0.01, "the garage: the trim alone")
	music.set_state("battle")
	assert_near(AudioServer.get_bus_volume_db(bus), MusicDirector.TRIM_DB + MusicDirector.IN_MATCH_LIFT_DB, 0.01,
			"a match: lifted %.0f dB" % MusicDirector.IN_MATCH_LIFT_DB)
	music.volume_db = -6.0
	assert_near(AudioServer.get_bus_volume_db(bus), -6.0 + MusicDirector.TRIM_DB + MusicDirector.IN_MATCH_LIFT_DB, 0.01,
			"and the player's music volume still applies on top")
	music.set_state("garage")
	music.volume_db = 0.0


func test_the_title_keeps_the_intro_as_it_was() -> void:
	var music := MusicDirector.new()
	music.load_stream = func(_path: String) -> AudioStream: return null
	add_to_tree(music)
	var bus := AudioServer.get_bus_index(MusicDirector.BUS)
	music.lift_allowed = false  # what attach() sets under the TitleMode
	music.volume_db = 0.0
	music.set_state("battle")
	assert_near(AudioServer.get_bus_volume_db(bus), MusicDirector.TRIM_DB, 0.01, "the title's backdrop fight is not lifted")
	music.lift_allowed = true  # what adopt_carried() sets when a match takes the director
	music._apply_bus_volume()
	assert_near(AudioServer.get_bus_volume_db(bus), MusicDirector.TRIM_DB + MusicDirector.IN_MATCH_LIFT_DB, 0.01,
			"the match that adopts it is")
	music.set_state("garage")
