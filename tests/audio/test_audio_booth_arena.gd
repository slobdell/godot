extends TestCase
## Arena's --arena=random (the skirmish default): the booth names the map that was built, not the flag.


func test_the_booth_names_the_arena_that_was_built() -> void:
	var saved := Arena.active
	Arena.active = {"name": "pit"}
	assert_eq(AnnouncerBooth.arena_key("random"), "pit", "random resolved to the Pit, so the booth says the Pit")
	assert_eq(AnnouncerBooth.arena_key("yard"), "pit", "the built arena wins over the flag")
	Arena.active = {}
	assert_eq(AnnouncerBooth.arena_key("random"), "", "nothing built and a random flag: no map name, quiet lines")
	assert_eq(AnnouncerBooth.arena_key("foundry"), "foundry", "nothing built: the flag's map")
	Arena.active = saved
	var library := AnnouncerLibrary.load_default()
	for key in ["yard", "boulevard", "pit", "boneyard"]:
		assert_true(library.speak("arena", key) != "", "%s has a spoken name" % key)
