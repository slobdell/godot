class_name LeakFree
extends RefCounted
## Free a node that never entered the tree, AND the nodes it and its descendants hold in member variables (ship,
## round 18, S5).
##
## A widget that builds its children as `var button := Button.new()` adds them in `_ready()`. A test that makes one
## with `.new()` (or instantiates a whole scene) and `free()`s it without adding it to the tree frees the nodes that are
## children and leaves every member control that `_ready()` would have parented an orphan: the engine reports them at
## exit as "ObjectDB instances were leaked", with their CanvasItem RIDs and text-shaping RIDs beside them -- the test
## shards' exit leaks, which no test could be blamed for at exit. Found by `make test-leaks` (builder0, 2026-10-04):
## test_hud_widgets (HudSkin's five buttons and frames) and test_control_faction_pick (the main scene's HUD banners).


## Frees every unparented Node held in a script member by `node`, by any descendant of it, or by any such member in
## turn, and then `node` itself.
static func free_with_members(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var strays: Array[Node] = []
	var seen := {}
	var queue: Array[Node] = [node]
	while not queue.is_empty():
		var current: Node = queue.pop_back()
		if seen.has(current.get_instance_id()):
			continue
		seen[current.get_instance_id()] = true
		queue.append_array(current.get_children(true))
		for property: Dictionary in current.get_property_list():
			if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var value: Variant = current.get(String(property["name"]))
			if value is Node and is_instance_valid(value) and (value as Node).get_parent() == null and value != node \
					and not seen.has((value as Node).get_instance_id()):
				strays.append(value)
				queue.append(value)
	node.free()
	for stray in strays:
		if is_instance_valid(stray):
			stray.free()
