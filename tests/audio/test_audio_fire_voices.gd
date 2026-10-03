extends TestCase
## Round 17 G6 (the audit): a kill leaves a wreck burning for 30 s with flames, smoke and cook-off pops on screen, and
## until round 17 none of it made a sound. FireVoices gives the nearest burning wrecks a fire loop that burns down with
## the fire, and sounds each cook-off pop FireSites draws. Presentation only (it reads FireSites' own list).


func _site(position: Vector3, start: float, next_pop: float) -> Dictionary:
	return {"position": position, "start": start, "next": 0.0, "next_smoke": 0.0, "next_pop": next_pop}


func _voices() -> FireVoices:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	return sfx.get_node("Fires") as FireVoices


func test_the_nearest_wrecks_burn_audibly() -> void:
	var fires := _voices()
	var sites := [_site(Vector3(0, 0, 10), 0.0, 9.0), _site(Vector3(0, 0, 200), 0.0, 9.0), _site(Vector3(5, 0, 12), 0.0, 9.0)]
	fires.update(sites, Vector3.ZERO, 1.0)
	assert_eq(fires.burning_voices(), FireVoices.VOICES, "the nearest %d fires have a voice" % FireVoices.VOICES)
	assert_true(fires.voiced_positions().has(Vector3(0, 0, 10)) and fires.voiced_positions().has(Vector3(5, 0, 12)),
			"and they are the near ones, not the one 200 m off")


func test_a_fire_burns_down_with_its_flames() -> void:
	var fires := _voices()
	var sites := [_site(Vector3(0, 0, 10), 0.0, 99.0)]
	fires.update(sites, Vector3.ZERO, 1.0)
	var early := fires.level_of(0)
	fires.update(sites, Vector3.ZERO, FireSites.BURN_SECONDS - 1.0)
	assert_true(fires.level_of(0) < early - 6.0, "nearly burnt out is quieter (%.1f -> %.1f dB)" % [early, fires.level_of(0)])
	fires.update([], Vector3.ZERO, FireSites.BURN_SECONDS + 1.0)
	assert_eq(fires.burning_voices(), 0, "gone when the fire is")


func test_every_cook_off_pop_is_heard() -> void:
	var fires := _voices()
	var site := _site(Vector3(0, 0, 10), 0.0, 2.0)
	fires.update([site], Vector3.ZERO, 1.0)
	assert_eq(fires.pops, 0, "no pop yet")
	site["next_pop"] = 6.0  # FireSites drew one and scheduled the next
	fires.update([site], Vector3.ZERO, 2.1)
	assert_eq(fires.pops, 1, "the pop it drew is heard")
