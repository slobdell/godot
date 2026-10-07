extends TestCase
## Round 21 (brains stretch a): a holding element LOSING ITS TRADE falls back one bound — built, measured, shipped OFF
## (`--hold-fallback`). The rule's arithmetic, and that the game's default is round 19's hold.


func test_losing_the_trade_is_losing_more_than_it_takes_and_enough_to_matter() -> void:
	assert_true(ElementCommander.losing_trade(400.0, 100.0), "lost 400, dealt 100: losing")
	assert_true(not ElementCommander.losing_trade(400.0, 300.0), "lost 400, dealt 300: an even trade (under 1.5 x)")
	assert_true(not ElementCommander.losing_trade(100.0, 0.0), "lost 100 for nothing: too little to give ground over")
	assert_true(ElementCommander.losing_trade(ElementCommander.TRADE_MIN_LOSS, 0.0), "the threshold itself counts")


func test_the_game_holds_as_round_19_did_unless_asked() -> void:
	assert_true(not ElementCommander.HOLD_FALLBACK_ENABLED, "shipped off: the series traded worse with it")
