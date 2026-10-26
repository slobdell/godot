extends TestCase
## Round 41 (orders G1 v8, `--group-column-toward=on`): a column never sends a squad away from his click. Pure read:
## SelectionSquads.column_sends_away.


func test_a_column_ahead_of_the_body_sends_nobody_away() -> void:
	var blocks := [{"center": Vector3(-20, 0, 0)}, {"center": Vector3(0, 0, 0)}, {"center": Vector3(20, 0, 0)}]
	var click := Vector3(0, 0, -100)
	var laid := [Vector3(0, 0, -100), Vector3(0, 0, -85), Vector3(0, 0, -70)]
	assert_true(not SelectionSquads.column_sends_away(laid, blocks, click), "every place nearer the click than its squad")


func test_his_terminus_click_beside_the_body_is_refused() -> void:
	# The dev read's case (s7007): squad 5 stood 88 m from the click and was given a place 103 m from it.
	var click := Vector3(-29.3, 0, 85.8)
	var blocks := [{"center": Vector3(-26.7, 0, 94.2)}, {"center": Vector3(59.0, 0, 93.3)}]
	var laid := [Vector3(-29.3, 0, 85.8), Vector3(71.4, 0, 108.3)]
	assert_true(SelectionSquads.column_sends_away(laid, blocks, click), "squad 5 sent 15 m farther than it stood")
	laid[1] = Vector3(65.0, 0, 95.0)  # 94.4 m: within COLUMN_AWAY_M of where it stood
	assert_true(not SelectionSquads.column_sends_away(laid, blocks, click), "a few metres back is a rank, not away")
