extends TestCase
## Round 22 (found by orders' five-squads-shots on the merged tip, fixed by the orchestrator): a stem fade is a tween
## bound to a stem index; when the track changed, `stem_db` was re-assigned (empty for a track without stems) while
## the fade still ticked, and `_set_stem_db` threw "Invalid assignment of index 0 (on base Array[float])" every frame.


func test_a_stem_write_past_the_array_is_ignored_not_an_error() -> void:
	var music := MusicDirector.new()
	music.load_stream = func(_path: String) -> AudioStream: return null
	add_to_tree(music)
	music.stem_db = []
	music._set_stem_db(-12.0, 0)  # the old fade's callback after a track change: must not throw
	assert_eq(music.stem_db.size(), 0, "nothing is written into an array the track change emptied")
	music.stem_db = [0.0, 0.0]
	music._set_stem_db(-12.0, 1)
	assert_near(music.stem_db[1], -12.0, 0.001, "a write inside the array still lands")
	music._set_stem_db(-12.0, 2)
	assert_eq(music.stem_db.size(), 2, "and one past the end is ignored")
