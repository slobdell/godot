extends TestCase
## Round 18 (finale; lent, C18.6): before a quit, the sound stops and the audio thread gets two buffers to let go of its
## playbacks (the exit leak: AudioStreamPlaybackOggVorbis + OggPacketSequencePlayback still referenced at exit). Bounded,
## synchronous, and a no-op when nothing plays. Its effect needs the exported binary: `make quit-leak-arms` on builder0.


func test_the_wait_is_two_audio_buffers_and_never_over_the_cap() -> void:
	assert_eq(MusicDirector.quit_wait_ms(0.0, 44100.0), 52, "no reported latency (Dummy): two 1024-frame buffers at 44.1 kHz + 5 ms")
	assert_eq(MusicDirector.quit_wait_ms(0.01, 48000.0), 25, "a 10 ms driver: two buffers + 5 ms")
	assert_eq(MusicDirector.quit_wait_ms(0.5, 48000.0), MusicDirector.QUIT_WAIT_CAP_MS, "a slow device never holds a quit past the cap")
	assert_true(MusicDirector.quit_wait_ms(0.0, 0.0) <= MusicDirector.QUIT_WAIT_CAP_MS, "and at the cap at most")


func test_it_stops_what_plays_and_returns_within_the_cap() -> void:
	var player: AudioStreamPlayer = add_to_tree(AudioStreamPlayer.new())
	var tone := AudioStreamGenerator.new()
	player.stream = tone
	player.play()
	assert_true(player.playing, "the precondition: something is playing")
	var started := Time.get_ticks_msec()
	var waited := MusicDirector.quiet_for_quit(tree)
	var took := Time.get_ticks_msec() - started
	assert_true(not player.playing, "every playing player is stopped before the quit")
	assert_true(waited > 0 and waited <= MusicDirector.QUIT_WAIT_CAP_MS, "it waited, bounded (%d ms)" % waited)
	assert_true(took <= MusicDirector.QUIT_WAIT_CAP_MS + 100, "and returned (%d ms)" % took)


func test_nothing_playing_returns_at_once() -> void:
	var player: AudioStreamPlayer = add_to_tree(AudioStreamPlayer.new())
	player.stream = AudioStreamGenerator.new()
	var started := Time.get_ticks_msec()
	assert_eq(MusicDirector.quiet_for_quit(tree), 0, "no wait when nothing plays (a match runner, a test, a silent build)")
	assert_true(Time.get_ticks_msec() - started < 20, "at once")
