extends Node3D
## `prop.tank_trap` (hedgehogs), `prop.monorail` (the overpass), `prop.pipeline` (pipe runs) and `prop.gantry_leg` (the
## gantry crane) -- mapkit P4, round 47, the lead's picks. Registers its
## instances with the viewport's MapkitYard (one MultiMesh per kind) and holds no mesh itself. `setup(prop)` reads the
## `car` look key (a monorail span with a lit car parked on it) and `span` (a gantry leg's beam to its partner leg). Visual only; the collision is Arena's.

@export_enum("hedgehog", "monorail", "monorail_deck", "pipeline", "gantry_leg") var kind := "hedgehog"

var _ids: Array[int] = []
var _car := false
## A gantry leg's `span` look key: [dx, dz] to the leg its beam reaches (world metres), or empty for a plain leg.
var _span: Array = []
## A monorail pillar's `span` look key: the metres of beam it carries (0 = MapkitYard.SPAN).
var _span_m := 0.0
var _yard: MapkitYard


func _ready() -> void:
	_register()


## A hidden prop leaves its MultiMesh (the batched draw cannot hide one instance): camera's deck cutaway hides the deck's
## VisualSlot and the beam goes with it; showing it again puts it back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		if is_visible_in_tree():
			_register()
		else:
			_unregister()


func setup(prop: Dictionary) -> void:
	_car = bool(prop.get("car", false))
	var span: Variant = prop.get("span", [])
	_span = span if span is Array and span.size() == 2 else []
	_span_m = float(span) if span is float or span is int else 0.0
	if is_inside_tree():
		_register()


func _exit_tree() -> void:
	_unregister()


func _register() -> void:
	_unregister()
	if not is_visible_in_tree():
		return
	_yard = MapkitYard.for_node(self)
	var base := Transform3D(global_basis.orthonormalized(), global_position)
	if kind != "monorail_deck":
		_ids.append(_yard.add(kind, base))
	if kind == "monorail_deck":
		# The deck: `span` (a number, metres; default MapkitYard.SPAN) of beam along its local z.
		var length := float(_span_m) if _span_m > 0.0 else MapkitYard.SPAN
		_ids.append(_yard.add("monorail_beam", base * Transform3D(Basis.from_scale(Vector3(1, 1, length)), Vector3.ZERO)))
		_place_car()
	if kind == "gantry_leg" and not _span.is_empty():
		var reach := Vector3(float(_span[0]), 0.0, float(_span[1]))
		var along := reach.normalized()
		var basis := Basis(along * reach.length(), Vector3.UP, along.cross(Vector3.UP).normalized())
		_ids.append(_yard.add("gantry_beam", Transform3D(basis, global_position)))


## R47.39: a deck with the `car` look key carries the lead's Meshy car (prop.monorail_car, train_r47_a): one instance,
## one draw, its underside at the beam's base so its own bogie block sinks into our beam. Hidden with the deck (a child).
func _place_car() -> void:
	var existing := get_node_or_null("Car")
	if not _car:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var car := VisualSlot.new()
	car.name = "Car"
	car.slot = "prop.monorail_car"
	car.position = Vector3(0.0, MapkitYard.BEAM_Y, 0.0)
	add_child(car)


func _unregister() -> void:
	if _yard != null and is_instance_valid(_yard):
		for id in _ids:
			_yard.remove(id)
	_ids.clear()
