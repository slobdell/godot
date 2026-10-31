class_name BlastDoorLook
extends Node3D
## `prop.blast_door` (mapkit P4, round 47; the lead's pick A on the looks page: VAULT SLABS). Two armoured leaves that
## slide sideways out of the opening, chevron faces, a header light red while shut and green while open, and amber beacons
## on the pylons that flash through the 5 s warning before every change. Presentation only: ArenaDoors' collider snaps at
## the tick the schedule says; the leaves glide over LEAF_S so the eye reads the move. `setup(door)` takes the door's
## {width, height, depth}; `set_state(state)` takes BlastDoors.state(): open / closing / shut / opening.

const LEAF_S := 1.2
const PYLON := Vector3(2.0, 1.4, 3.4)  # width, extra height above the opening, depth
const STEEL := Color(0.16, 0.17, 0.19)
const GUNMETAL := Color(0.24, 0.25, 0.28)

var width := 14.0
var height := 7.5
var depth := 1.6
var _leaves: Array[MeshInstance3D] = []
var _lamp: MeshInstance3D
var _beacons: Array[MeshInstance3D] = []
var _state := "open"
var _open := 1.0  # 0 shut .. 1 open, what is drawn
var _built := false
var _told := false


func setup(door: Dictionary) -> void:
	width = float(door.get("width", width))
	height = float(door.get("height", height))
	depth = float(door.get("depth", depth))
	_build()


func _ready() -> void:
	if not _built:
		_build()


func set_state(state: String) -> void:
	_state = state
	if not _built:
		_build()
	_lamp.material_override = CyberMaterials.neon(CyberMaterials.GREEN if state == "open" or state == "closing" else CyberMaterials.RED, 4.0, 0.0)
	for beacon in _beacons:
		beacon.visible = state == "closing" or state == "opening"
	if not _told:
		# The first state snaps (a door at load, or a render): only a change of state glides.
		_told = true
		_open = 1.0 if state == "open" or state == "closing" else 0.0
		_place_leaves()
	set_process(true)


func _process(delta: float) -> void:
	var want := 1.0 if _state == "open" or _state == "closing" else 0.0
	_open = move_toward(_open, want, delta / LEAF_S)
	_place_leaves()
	if is_equal_approx(_open, want):
		set_process(_beacons.any(func(b: MeshInstance3D) -> bool: return b.visible))
	if _beacons[0].visible:
		var on := fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3
		for beacon in _beacons:
			beacon.transparency = 0.0 if on else 0.85


func _build() -> void:
	for child in get_children():
		child.free()
	_leaves.clear()
	_beacons.clear()
	var pylon := CyberMaterials.surface(GUNMETAL, 0.45, 0.6)
	for side in [-1.0, 1.0]:
		var x: float = side * (width / 2.0 + PYLON.x / 2.0)
		CyberMaterials.box(self, Vector3(PYLON.x, height + PYLON.y, PYLON.z), Vector3(x, (height + PYLON.y) / 2.0, 0.0), pylon)
		var beacon := CyberMaterials.box(self, Vector3(0.6, 0.5, 0.6), Vector3(x, height + PYLON.y + 0.25, 0.8),
				CyberMaterials.neon(CyberMaterials.YELLOW, 4.0, 0.0), false)
		beacon.visible = false
		_beacons.append(beacon)
	CyberMaterials.box(self, Vector3(width + PYLON.x * 2.0, PYLON.y, PYLON.z), Vector3(0, height + PYLON.y / 2.0, 0.0), pylon)
	# The header light on the face toward the camera's usual side (+z); a door seen from behind reads by its leaves.
	_lamp = CyberMaterials.box(self, Vector3(width - 1.0, 0.3, 0.1), Vector3(0, height + PYLON.y / 2.0, PYLON.z / 2.0 + 0.05),
			CyberMaterials.neon(CyberMaterials.GREEN, 4.0, 0.0), false)
	var leaf_material := CyberMaterials.surface(STEEL, 0.4, 0.7)
	var chevrons := CyberMaterials.panel(CyberMaterials.YELLOW, (width / 2.0) / height, 1.6, true)
	for side in [-1.0, 1.0]:
		var leaf := CyberMaterials.box(self, Vector3(width / 2.0, height, depth * 0.75), Vector3.ZERO, leaf_material)
		for face in [-1.0, 1.0]:
			var mesh := QuadMesh.new()
			mesh.size = Vector2(width / 2.0 - 0.6, height - 1.2)
			mesh.material = chevrons
			var quad := MeshInstance3D.new()
			quad.mesh = mesh
			quad.position = Vector3(0, 0, face * (depth * 0.375 + 0.02))
			quad.rotation.y = 0.0 if face > 0 else PI
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			leaf.add_child(quad)
		leaf.set_meta("side", side)
		_leaves.append(leaf)
	_built = true
	_place_leaves()


func _place_leaves() -> void:
	for leaf in _leaves:
		var side := float(leaf.get_meta("side"))
		# Shut: the two halves meet in the middle. Open: each slid a full half-width plus the pylon past the jamb.
		leaf.position = Vector3(side * (width / 4.0 + _open * (width / 2.0 + PYLON.x)), height / 2.0, 0.0)
