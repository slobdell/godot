extends TestCase
## Round 13 (G2): which launches of the garage play the garage's bed. The builder a player is looking at does; a
## garage that hands straight over to a match (REMATCH, a challenge, an immediate autofight) does not, or every
## rematch would open on a bar of blues before the match's own opening.


func _mode(args: Array) -> GarageMode:
	var mode := GarageMode.new()
	mode.flags = LaunchFlags.parse(PackedStringArray(args))
	return mode


func test_the_builder_plays_the_garage_and_a_straight_handover_does_not() -> void:
	assert_eq(_mode(["--garage"]).music_state(), "garage", "the title's GARAGE: the player is building")
	assert_eq(_mode(["--garage", "--garage-army=user://doctrines/a.json"]).music_state(), "garage",
			"ARMY from the results screen: back in the builder")
	assert_eq(_mode(["--garage", "--garage-autofight=4"]).music_state(), "garage", "a delayed FIGHT hears the garage first")
	assert_eq(_mode(["--garage", "--garage-autofight"]).music_state(), "", "an immediate FIGHT opens on the match")
	assert_eq(_mode(["--garage", "--garage-rematch"]).music_state(), "", "REMATCH goes straight to the match")
	assert_eq(_mode(["--garage", "--challenge=scout_hunt"]).music_state(), "", "and so does a challenge")
