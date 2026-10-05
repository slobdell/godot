class_name Orphans
extends RefCounted
## Nodes outside the tree, told apart (ship, round 18; picker's probe of the runner's ORPHAN report).
##
## `Performance.OBJECT_ORPHAN_NODE_COUNT` counts a node that has been `queue_free()`d and is waiting for the end of the
## process frame the same as one nobody will ever free. The runner samples after the teardown's drain, which awaits
## PHYSICS frames; Godot frees queued nodes on the PROCESS frame -- so ArenaDressing's StaticBatcher.merge sources
## (queue_free()d, correctly) were named as +188 orphans per arena, and test_every_unit_selectable as +2820, with clean
## exits. `count()` splits them: `live` is a node outside the tree that is NOT queued for deletion (a leak unless
## something frees it later); `queued` is a late free.


static func count() -> Dictionary:
	var live := 0
	var queued := 0
	for id: int in Node.get_orphan_node_ids():
		var node := instance_from_id(id) as Node
		if node == null:
			continue
		if node.is_queued_for_deletion():
			queued += 1
		else:
			live += 1
	return {"live": live, "queued": queued}
