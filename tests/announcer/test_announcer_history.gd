extends TestCase
## X1: the booth must not open the same way every night. The director's own anti-repetition lasts one match; this
## covers the memory that lasts across them, and the weighting it feeds the director.

const SCRATCH := "user://test_announcer/history.json"


func _scratch() -> String:
	# Never the player's real user://announcer_history.json (orientation trip-up 54).
	DirAccess.make_dir_recursive_absolute("user://test_announcer")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	return SCRATCH


func test_a_line_heard_last_match_is_far_less_likely_tonight() -> void:
	var history := AnnouncerHistory.new()
	history.remember(["pa.welcome.03", "caller.intro.01"])
	assert_eq(history.matches_ago("pa.welcome.03"), 1, "it was said in the match just before this one")
	assert_true(history.weight("pa.welcome.03") < 0.05, "so tonight it is heavily weighted down")
	assert_eq(history.weight("pa.welcome.04"), 1.0, "a line nobody has heard is unpenalised")


func test_the_penalty_fades_as_matches_go_by() -> void:
	# The caller's curve; the PA's is longer on purpose (test_the_pa_is_remembered_for_an_evening).
	var history := AnnouncerHistory.new()
	history.remember(["caller.intro.03"])
	var weights: Array[float] = [history.weight("caller.intro.03")]
	for index in 6:
		history.remember(["other.%d" % index])
		weights.append(history.weight("caller.intro.03"))
	for index in range(1, weights.size()):
		assert_true(weights[index] > weights[index - 1],
				"the longer ago it was said the likelier it comes back (step %d)" % index)
	assert_true(weights[-1] > 0.5, "after six matches it is nearly fresh again")


## C9 (round 10): the PA's one wrong detail is remembered across sessions, so a repeat of hers after six matches is
## still a repeat. Her lines keep a penalty for a whole evening of matches, fading slowly, where the caller's are fresh
## again after about six.
func test_the_pa_is_remembered_for_an_evening() -> void:
	var history := AnnouncerHistory.new()
	history.remember(["pa.welcome.03", "caller.intro.03"])
	for index in 10:
		history.remember(["other.%d" % index])
	assert_eq(history.weight("caller.intro.03"), 1.0, "eleven matches on, the caller's line is forgotten")
	var pa := history.weight("pa.welcome.03")
	assert_true(pa < 0.6, "the PA's line is still held back (%.2f)" % pa)
	assert_true(pa > 0.0, "but not banned")
	var previous := pa
	for index in 20:
		history.remember(["more.%d" % index])
	assert_true(history.weight("pa.welcome.03") > previous, "and it keeps fading back in")
	assert_true(history.matches_ago("pa.welcome.03") > 0, "thirty-one matches on, it is still remembered")


func test_the_memory_forgets_past_its_depth() -> void:
	var history := AnnouncerHistory.new()
	history.remember(["old.line"])
	for index in AnnouncerHistory.DEPTH:
		history.remember(["filler.%d" % index])
	assert_eq(history.matches_ago("old.line"), 0, "a line nobody has heard in DEPTH matches is forgotten")
	assert_eq(history.weight("old.line"), 1.0, "and is as likely as any other")
	assert_eq(history.matches.size(), AnnouncerHistory.DEPTH, "the file never grows past DEPTH matches")


func test_the_most_recent_use_is_the_one_that_counts() -> void:
	var history := AnnouncerHistory.new()
	history.remember(["pa.welcome.03"])
	history.remember(["something.else"])
	history.remember(["pa.welcome.03"])
	assert_eq(history.matches_ago("pa.welcome.03"), 1, "said three matches ago and again last match: last match wins")


func test_it_survives_a_round_trip_through_a_file() -> void:
	var path := _scratch()
	var history := AnnouncerHistory.load_from(path)
	history.remember(["caller.intro.02", "pa.welcome.07"])
	assert_true(history.save(), "it saved")
	var reloaded := AnnouncerHistory.load_from(path)
	assert_eq(reloaded.matches_ago("caller.intro.02"), 1, "the next run remembers last night")
	assert_eq(reloaded.matches_ago("pa.welcome.07"), 1, "every line of it")


func test_a_missing_or_broken_file_is_simply_an_empty_memory() -> void:
	var missing := AnnouncerHistory.load_from("user://test_announcer/nothing_here.json")
	assert_eq(missing.matches.size(), 0, "a first run has no past and no error")
	var path := ProjectSettings.globalize_path("user://test_announcer/broken.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not json at all")
	file.close()
	var broken := AnnouncerHistory.load_from("user://test_announcer/broken.json")
	assert_eq(broken.matches.size(), 0, "a corrupt memory is thrown away, not crashed on")
	assert_eq(broken.weight("anything"), 1.0, "and the booth just picks freely")


func test_the_director_actually_uses_it() -> void:
	## The whole point: with the same seed, a line heard last match gives way to one that wasn't.
	var library := AnnouncerLibrary.load_default()
	assert_eq(library.errors.size(), 0, "the real library loads")
	var loaded := AnnouncerEvents.load_file("res://tests/announcer/fixtures/close_match.jsonl")
	var without := AnnouncerDirector.new(library, 11)
	var first := without.run_timeline(loaded["events"])
	assert_true(first.size() > 0, "the booth called the match")
	var history := AnnouncerHistory.new()
	history.remember(without.used_line_ids())
	var with_memory := AnnouncerDirector.new(library, 11)
	with_memory.history = history
	var second := with_memory.run_timeline(loaded["events"])
	var repeated := 0
	for cue in second:
		if history.matches_ago(cue["line_id"]) > 0:
			repeated += 1
	assert_true(repeated < second.size() / 2,
			"most of tonight's lines are ones last night didn't use (%d of %d repeated)" % [repeated, second.size()])
	assert_true(first[0]["line_id"] != second[0]["line_id"],
			"and the same seed opens the broadcast differently, which is what the lead noticed")
