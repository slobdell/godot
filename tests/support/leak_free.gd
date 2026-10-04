class_name LeakFree
extends RefCounted
## Free a node that never entered the tree, AND the nodes it holds in member variables (ship, round 18, S5).
##
## A widget that builds its children as `var button := Button.new()` adds them in `_ready()`. A test that makes one
## with `.new()` and `free()`s it without adding it to the tree frees the widget and leaves every member control an
## orphan: the engine reports them at exit as "ObjectDB instances were leaked", with their CanvasItem RIDs and their
## text-shaping RIDs beside them -- the test shards' exit leaks, which no test could be blamed for at exit.


## Frees every script member of `node` that is a Node with no parent (they would be orphans), then `node` itself.
static func free_with_members(node: Node) -> void:
	if not is_instance_valid(node):
		return
	for property: Dictionary in node.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = node.get(String(property["name"]))
		if value is Node and is_instance_valid(value) and value != node and (value as Node).get_parent() == null:
			(value as Node).free()
	node.free()
