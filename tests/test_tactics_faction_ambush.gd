extends TestCase
## B3 (round 40, balance): the faction-aware CPU, v1. A faction's doctrine table may let a share of its line lie in ambush
## at once (`traits.ambush_share`): the gangs, whose guns reach 30-50 m, wait for the enemy on its way rather than meet
## 70-170 m guns in the open (B1's tally). Behind `--faction-ambush` until its bar; OFF, every side keeps one ambush.


func test_limit_is_one_when_off_or_without_the_trait() -> void:
	assert_eq(ElementCommander.ambush_limit(5, {"ambush_share": 0.6}, false), 1, "OFF: one ambush, as today")
	assert_eq(ElementCommander.ambush_limit(5, {}, true), 1, "no trait: one ambush, as today")


func test_limit_follows_the_share_and_never_drops_below_one() -> void:
	assert_eq(ElementCommander.ambush_limit(5, {"ambush_share": 0.6}, true), 3, "60 % of five line elements")
	assert_eq(ElementCommander.ambush_limit(1, {"ambush_share": 0.6}, true), 1, "a lone element may still ambush")
	assert_eq(ElementCommander.ambush_limit(8, {"ambush_share": 0.6}, true), 4, "floor(4.8)")


func test_only_the_gangs_table_asks_for_it() -> void:
	for faction: String in Units.FACTIONS:
		var table := DoctrineTable.for_faction(faction)
		assert_true(table != null, "%s has a table" % faction)
		assert_eq(table.traits.has("ambush_share"), faction == "gangs", "%s ambush_share" % faction)
