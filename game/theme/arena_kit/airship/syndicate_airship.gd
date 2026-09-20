class_name SyndicateAirship
extends Node3D
## Feel X7 (the lead, approved for round 9): *"a Bladerunner-like Airship that hovered over the arena, sometimes
## visible in the field of view, that also had a big TV screen … I suppose the theme would be consistent if this
## airship had a Syndicate-feel to it?"*
##
## Built from PRIMITIVES, not Meshy, and that is a recommendation rather than a compromise: it is seen far away, in
## the sky, often half out of frame, so nothing about it rewards a high-detail model -- and Meshy's failure mode is
## "cartoon", which is the wrong failure for the faction that is supposed to read as the ivory tower
## ([art_direction.md]). Ellipsoid envelope, tail cone, fins, gondola, a screen a side.
##
## THE SCREEN IS FREE. `AdBroadcast.channel()` gives every screen on a channel ONE shared material -- "ten screens
## cost one layout" -- so joining the `arena` channel costs one more quad and no second 2D feed, and the airship
## shows whatever the ground screens show, including `LiveFeed`'s replay of the player's last kill.
##
## Three constraints, each earned from a failure this project already paid for:
##   1. NO collision body of any kind, and the sim hash is pre-registered unchanged. Visual-only SHOULD leave it
##      alone, but arena's `_build_perimeter()` once produced geometrically identical walls in a different body
##      creation order and moved the baseline anyway (workstreams Invariant 2), so it is an expectation, not a law.
##   2. Drift comes from the fixed tick (`Match.tick`), never the wall clock, so a replay shows it where it was.
##   3. "Sometimes visible" is verified AT THE LEAD'S POSE with frames (`make airship-look`), never with a
##      screenshot taken deliberately from somewhere it happens to look good.
##
## Tiered like the crowd: absent on LOW (the web build and phones), where its draws cannot be spared.

const ENVELOPE_LENGTH := 64.0
const ENVELOPE_DIAMETER := 17.0
const SCREEN := Vector2(26.0, 11.0)
## The orbit: radius and altitude are the only two numbers that decide whether he ever sees it, so they are
## measured at his pose rather than chosen (see `make airship-look`, and the Status note recording what the frames
## said). One lap in this many ticks, off the fixed clock.
const ORBIT_RADIUS := 118.0
const ORBIT_ALTITUDE := 74.0
const ORBIT_TICKS := 70.0 * SimClock.TICK_RATE
## Ivory, almost no rust: the Syndicate is the only faction in the game that is allowed to look clean.
const HULL_COLOR := Color(0.88, 0.88, 0.86)
const PANEL_COLOR := Color(0.72, 0.73, 0.76)
const TRIM := Color(0.20, 0.22, 0.26)

var broadcast: AdBroadcast
var channel_name := "arena"
var _screens: Array[MeshInstance3D] = []
var _tick_source: Node


func _init() -> void:
	name = "SyndicateAirship"


func _ready() -> void:
	_build()
	_apply_channel()
	set_process(true)
	_place(0)


## The pose `tick` fixed ticks into the match: a slow orbit, nose along the tangent, with a gentle roll into the
## turn. Static and pure so a test can assert the path without building the airship or running a match.
static func pose_at(tick: int) -> Transform3D:
	var angle := TAU * float(tick) / ORBIT_TICKS
	var at := Vector3(sin(angle) * ORBIT_RADIUS, ORBIT_ALTITUDE, cos(angle) * ORBIT_RADIUS)
	# Flying the circle: the nose (-Z) points along the tangent, so the hull leads its own turn.
	var heading := angle + PI / 2.0
	var basis := Basis(Vector3.UP, heading) * Basis(Vector3.FORWARD, deg_to_rad(6.0))
	return Transform3D(basis, at)


func _process(_delta: float) -> void:
	_place(_match_tick())


## The running match's fixed tick, or 0 where there is no match (the galleries). Never `Time`: a replay has to draw
## the airship where it was, and a wall clock would put it somewhere else every time the same match is watched.
func _match_tick() -> int:
	if _tick_source == null or not is_instance_valid(_tick_source):
		var fx := FxWorld.existing()
		_tick_source = fx.link.attached_match() if fx != null and fx.link != null else null
	if _tick_source == null:
		return 0
	return int(_tick_source.get("tick"))


func _place(tick: int) -> void:
	transform = pose_at(tick)


func _apply_channel() -> void:
	broadcast = AdBroadcast.channel(self, channel_name)
	for screen in _screens:
		screen.material_override = broadcast.screen_material


func _build() -> void:
	var hull := Node3D.new()
	hull.name = "Hull"
	add_child(hull)
	var skin := CyberMaterials.surface(HULL_COLOR, 0.35, 0.15)
	var panel := CyberMaterials.surface(PANEL_COLOR, 0.30, 0.45)
	var trim := CyberMaterials.surface(TRIM, 0.5, 0.6)
	# The envelope: one sphere stretched into an ellipsoid. A capsule would cost the same and read as a pill.
	var envelope := MeshInstance3D.new()
	envelope.name = "Envelope"
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 24
	ball.rings = 12
	ball.material = skin
	envelope.mesh = ball
	envelope.scale = Vector3(ENVELOPE_DIAMETER, ENVELOPE_DIAMETER, ENVELOPE_LENGTH)
	hull.add_child(envelope)
	# A tail cone, so the silhouette is a dirigible rather than a bean.
	var cone := MeshInstance3D.new()
	cone.name = "Tail"
	var taper := CylinderMesh.new()
	taper.top_radius = 0.0
	taper.bottom_radius = ENVELOPE_DIAMETER * 0.34
	taper.height = ENVELOPE_LENGTH * 0.30
	taper.radial_segments = 16
	taper.material = skin
	cone.mesh = taper
	cone.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0, ENVELOPE_LENGTH * 0.60))
	hull.add_child(cone)
	# Four fins in a cross at the tail.
	for i in 4:
		var fin := CyberMaterials.box(hull, Vector3(0.6, ENVELOPE_DIAMETER * 0.62, ENVELOPE_LENGTH * 0.16),
				Vector3.ZERO, panel)
		fin.name = "Fin%d" % i
		var roll := TAU * i / 4.0
		fin.transform = Transform3D(Basis(Vector3.FORWARD, roll),
				Vector3(0, 0, ENVELOPE_LENGTH * 0.40).rotated(Vector3.FORWARD, roll))
		fin.position = Vector3(0, 0, ENVELOPE_LENGTH * 0.40) + Vector3(0, ENVELOPE_DIAMETER * 0.42, 0).rotated(Vector3.FORWARD, roll)
	# The gondola, slung under the nose, and the spine the screens hang from.
	CyberMaterials.box(hull, Vector3(5.0, 3.2, 15.0), Vector3(0, -ENVELOPE_DIAMETER * 0.52, -ENVELOPE_LENGTH * 0.18), panel)
	CyberMaterials.box(hull, Vector3(2.2, 2.0, ENVELOPE_LENGTH * 0.66), Vector3(0, -ENVELOPE_DIAMETER * 0.47, 0), trim)
	# Engine pods.
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(hull, Vector3(2.4, 2.4, 6.0),
				Vector3(sx * ENVELOPE_DIAMETER * 0.46, -ENVELOPE_DIAMETER * 0.22, ENVELOPE_LENGTH * 0.24), trim)
	# Navigation lights: the only neon on a Syndicate hull, and they are instruments, not decoration.
	CyberMaterials.box(hull, Vector3(1.0, 1.0, 1.0), Vector3(0, 0, -ENVELOPE_LENGTH * 0.52),
			CyberMaterials.neon(CyberMaterials.CYAN, 5.0, 0.0, &"airship"), false)
	CyberMaterials.box(hull, Vector3(0.9, 0.9, 0.9), Vector3(0, -ENVELOPE_DIAMETER * 0.58, -ENVELOPE_LENGTH * 0.16),
			CyberMaterials.neon(CyberMaterials.RED, 4.0, 0.5, &"airship"), false)
	StaticBatcher.merge(hull)
	# A screen a side, hung off the spine. One channel, one layout, one material: the eleventh screen in the arena
	# is approximately free and shows whatever the ground screens show.
	for sx in [-1.0, 1.0]:
		var screen := MeshInstance3D.new()
		screen.name = "Screen%s" % ("Port" if sx < 0.0 else "Starboard")
		var quad := QuadMesh.new()
		quad.size = SCREEN
		screen.mesh = quad
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A QuadMesh faces +Z; turned to face outward from the hull's flank.
		screen.transform = Transform3D(Basis(Vector3.UP, PI / 2.0 * sx),
				Vector3(sx * (ENVELOPE_DIAMETER * 0.5 + 0.6), -ENVELOPE_DIAMETER * 0.20, 0))
		add_child(screen)
		_screens.append(screen)
