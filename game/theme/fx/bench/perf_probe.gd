extends Node
## A timestamp for PerfScene in the process order (slots 0-2) or the physics order (3, 4); its priorities decide where.


func _process(_delta: float) -> void:
	var slot := int(get_meta("slot"))
	if slot < 3:
		(get_meta("owner") as Object).call("mark", slot)


func _physics_process(_delta: float) -> void:
	var slot := int(get_meta("slot"))
	if slot >= 3:
		(get_meta("owner") as Object).call("mark", slot)
