extends TestCase
## tests/support/orphans.gd: a queue_free()d node is a late free, not a live orphan (ship, round 18).


func test_a_queued_node_is_not_a_live_orphan() -> void:
	var before := Orphans.count()
	var node := Node.new()
	node.queue_free()
	var after := Orphans.count()
	assert_eq(int(after["live"]) - int(before["live"]), 0, "a queue_free()d node reads +0 live")
	assert_eq(int(after["queued"]) - int(before["queued"]), 1, "and +1 queued")


func test_a_node_removed_and_never_freed_is_a_live_orphan() -> void:
	var before := Orphans.count()
	var node := Node.new()
	add_to_tree(node)
	tree.root.remove_child(node)
	var after := Orphans.count()
	assert_eq(int(after["live"]) - int(before["live"]), 1, "a node removed from the tree and never freed reads +1 live")
	node.free()
	assert_eq(int(Orphans.count()["live"]), int(before["live"]), "freed, it is gone")
