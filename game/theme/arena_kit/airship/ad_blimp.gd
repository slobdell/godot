class_name AdBlimp
extends Node3D
## Contract R7 (round 10, feel). The lead, on the Terminus: *"we're missing the blimp I wanted."*
##
## The round-9 airship (SyndicateAirship, 560 m out over the city) is real and he has never seen it, because of one
## line of geometry: at his pose (21 deg, FOV 35, 49 m) the top of the frame is 3.5 deg BELOW the horizon, so the sky is
## never on screen. What he can see is what is lower than his camera (~17.5 m) by more than that 3.5 deg over the
## distance -- at 12 m up that is anything within ~90 m of the camera, which is the far half of his frame. So the
## blimp he asked for is a SMALL AD BLIMP flying LOW, down the streets between the blocks (24 m tall), at a walking
## pace: the thing you see drifting past the rooftops while you fight. The airship stays as the city's.
##
## Built like the airship, and for the same reasons: primitives (it is a lit ellipsoid with fins; Meshy's failure is
## "cartoon"), NO collider of any kind (pre-registered: the sim baseline does not move), posed from the fixed tick
## (`pose_at`, pure), never the wall clock, and its two flank screens join the `arena` AdBroadcast channel, so they
## cost no second feed and replay the player's kills for free. It is lit from inside, the way real night ad blimps
## are, so the envelope reads against the dark city without adding a light; the navigation lights are steady (red
## port, green starboard, white tail), instruments rather than decoration.
##
## The ROUTE follows the streets because at 12 m it is below the rooftops -- and on the Terminus it is the AVENUE,
## which a first version got wrong. It flew the ring roads round the central blocks, and the physics-ray sweep at his
## pose saw it in 0% of samples: from the bases the ring road is walled by the 24 m block rows, and his camera (17.5 m
## up) cannot see over them. The avenue is the one long corridor that runs along his view, up the map from base to
## base, so the blimp flies a stadium loop down it: out along x = +4, back along x = -4, turning where the block rows
## end (z = +-86). Its screens are four panels on the flanks, each yawed 35 deg toward the nose or the tail, so a
## camera behind or ahead of it -- the usual view down the avenue -- still sees most of a panel.
## Maps without a route get no blimp.

const ENVELOPE_LENGTH := 22.0
const ENVELOPE_DIAMETER := 6.5
const SCREEN := Vector2(7.5, 3.4)
## Each flank panel is yawed this far toward the nose or the tail (see the header).
const SCREEN_YAW_DEG := 35.0
## Flight altitude of the envelope's centre. 12 m: the envelope's bottom (8.75 m) and the gondola's (~7.4 m) clear
## the tallest hull (6.18 m) and R3's lamp heads, and its top (15.25 m) stays under the camera's ~17.5 m.
const ALTITUDE := 12.0
const BOB_M := 0.25
## A walking pace, the brief's word: 1.5 m/s. One lap of the Terminus avenue loop is ~240 s.
const SPEED_MPS := 1.5
## Corners are filleted at this radius so the hull turns through an intersection (18-20 m wide) instead of pivoting.
const CORNER_RADIUS := 8.0
const ROUTES := {
	"terminus": [Vector2(4.0, 86.0), Vector2(4.0, -86.0), Vector2(-4.0, -86.0), Vector2(-4.0, 86.0)],
}
const HULL_COLOR := Color(0.90, 0.89, 0.86)
const GLOW_COLOR := Color(1.0, 0.93, 0.80)
const GLOW_ENERGY := 0.45
const TRIM := Color(0.20, 0.22, 0.26)

var broadcast: AdBroadcast
var channel_name := "arena"
var route: PackedVector2Array
var _screens: Array[MeshInstance3D] = []
var _tick_source: Node
## The route sampled at SAMPLE_M along its length (fillets included), built once.
var _samples := PackedVector2Array()
var _length := 0.0
const SAMPLE_M := 0.5


func _init(corners: PackedVector2Array = PackedVector2Array()) -> void:
	name = "AdBlimp"
	route = corners


## The route for the running layout, or an empty array (no blimp) when the map has none.
static func route_for(layout: Dictionary) -> PackedVector2Array:
	return PackedVector2Array(ROUTES.get(String(layout.get("name", "")), []))


func _ready() -> void:
	_samples = sample_route(route)
	_length = _samples.size() * SAMPLE_M
	_build()
	_apply_channel()
	_place(0)


## `corners` as a closed loop, every corner filleted at CORNER_RADIUS, sampled every SAMPLE_M. Pure.
static func sample_route(corners: PackedVector2Array) -> PackedVector2Array:
	var dense := PackedVector2Array()
	var n := corners.size()
	if n < 2:
		return dense
	# Each leg runs from the end of one fillet to the start of the next; each fillet is a quadratic Bezier.
	var path: Array = []  # one fillet per corner: {start, corner, end}
	for i in n:
		var a := corners[(i - 1 + n) % n]
		var b := corners[i]
		var c := corners[(i + 1) % n]
		var into := (b - a).normalized()
		var out_of := (c - b).normalized()
		var r := minf(CORNER_RADIUS, minf(a.distance_to(b), b.distance_to(c)) * 0.45)
		path.append({"start": b - into * r, "end": b + out_of * r, "corner": b})
	for i in n:
		var here: Dictionary = path[i]
		var next: Dictionary = path[(i + 1) % n]
		# the fillet at corner i (a quadratic Bezier through the corner, close enough to an arc at these angles)
		var p0: Vector2 = here["start"]
		var p1: Vector2 = here["corner"]
		var p2: Vector2 = here["end"]
		var arc_len := p0.distance_to(p1) + p1.distance_to(p2)
		var arc_steps := maxi(8, int(arc_len / (SAMPLE_M * 0.1)))
		for s in arc_steps:
			var t := float(s) / arc_steps
			dense.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
		# the straight leg to the next fillet
		var leg_from: Vector2 = here["end"]
		var leg_to: Vector2 = next["start"]
		var leg_steps := maxi(1, int(leg_from.distance_to(leg_to) / (SAMPLE_M * 0.1)))
		for s in leg_steps:
			dense.append(leg_from.lerp(leg_to, float(s) / leg_steps))
	# Resampled by arc length, so every sample is SAMPLE_M of travel and the pace is the same on a fillet as on a leg.
	var out := PackedVector2Array([dense[0]])
	var carried := 0.0
	for i in range(1, dense.size() + 1):
		var from := dense[i - 1]
		var to := dense[i % dense.size()]
		var step := from.distance_to(to)
		while carried + step >= SAMPLE_M:
			var t := (SAMPLE_M - carried) / step
			from = from.lerp(to, t)
			step = from.distance_to(to)
			carried = 0.0
			out.append(from)
		carried += step
	if out.size() > 1 and out[out.size() - 1].distance_to(out[0]) < SAMPLE_M * 0.5:
		out.remove_at(out.size() - 1)
	return out


## The pose `tick` fixed ticks into the match. Nose (-Z) along the direction of travel, a slow bob. Pure given the
## samples, so the look sweep and the tests can pose it without a match.
static func pose_on(samples: PackedVector2Array, tick: int) -> Transform3D:
	if samples.is_empty():
		return Transform3D(Basis(), Vector3(0.0, ALTITUDE, 0.0))
	var seconds := float(tick) / SimClock.TICK_RATE
	var travelled := fposmod(seconds * SPEED_MPS / SAMPLE_M, float(samples.size()))
	var i := int(travelled)
	var t := travelled - i
	var here := samples[i]
	var next := samples[(i + 1) % samples.size()]
	var ahead := samples[(i + 8) % samples.size()]  # 4 m ahead: the nose leads the turn smoothly
	var at := here.lerp(next, t)
	var dir := ahead - at
	var heading := atan2(-dir.x, -dir.y) if dir.length() > 0.01 else 0.0
	var y := ALTITUDE + BOB_M * sin(seconds * TAU / 11.0)
	return Transform3D(Basis(Vector3.UP, heading), Vector3(at.x, y, at.y))


func pose_at(tick: int) -> Transform3D:
	return pose_on(_samples, tick)


func _process(_delta: float) -> void:
	_place(_match_tick())


func _match_tick() -> int:
	if _tick_source == null or not is_instance_valid(_tick_source):
		var fx := FxWorld.existing()
		_tick_source = fx.link.attached_match() if fx != null and fx.link != null else null
	if _tick_source == null:
		return 0
	return int(_tick_source.get("tick"))


func _place(tick: int) -> void:
	transform = pose_at(tick)


## Ticks per lap, for the look sweep.
func lap_ticks() -> int:
	return int(ceil(_length / SPEED_MPS * SimClock.TICK_RATE))


func _apply_channel() -> void:
	broadcast = AdBroadcast.channel(self, channel_name)
	for screen in _screens:
		screen.material_override = broadcast.screen_material


func _build() -> void:
	var hull := Node3D.new()
	hull.name = "Hull"
	add_child(hull)
	# Lit from inside: an ivory skin with a warm emission, like a night ad blimp. Unshaded would lose the form; a low
	# emission keeps the scene's shading on top of a floor that never goes black.
	var skin := StandardMaterial3D.new()
	skin.albedo_color = HULL_COLOR
	skin.roughness = 0.55
	skin.metallic = 0.0
	skin.emission_enabled = true
	skin.emission = GLOW_COLOR
	skin.emission_energy_multiplier = GLOW_ENERGY
	var trim := CyberMaterials.surface(TRIM, 0.5, 0.6)
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
	# Four fins in a cross at the tail (+Z is the tail: the nose is -Z).
	for i in 4:
		var roll := TAU * i / 4.0 + PI / 4.0
		var fin := CyberMaterials.box(hull, Vector3(0.25, ENVELOPE_DIAMETER * 0.45, ENVELOPE_LENGTH * 0.18),
				Vector3.ZERO, trim)
		fin.name = "Fin%d" % i
		fin.transform = Transform3D(Basis(Vector3.FORWARD, roll),
				Vector3(0, 0, ENVELOPE_LENGTH * 0.40) + Vector3(0, ENVELOPE_DIAMETER * 0.42, 0).rotated(Vector3.FORWARD, roll))
	# The gondola under the forward third.
	CyberMaterials.box(hull, Vector3(1.8, 1.3, 5.0), Vector3(0, -ENVELOPE_DIAMETER * 0.5 - 0.35, -ENVELOPE_LENGTH * 0.10), trim)
	# Navigation lights, steady: red port, green starboard, white tail.
	CyberMaterials.box(hull, Vector3(0.45, 0.45, 0.45), Vector3(-ENVELOPE_DIAMETER * 0.5, 0, -ENVELOPE_LENGTH * 0.05),
			CyberMaterials.neon(Color(1.0, 0.1, 0.1), 5.0, 0.0, &"blimp"), false)
	CyberMaterials.box(hull, Vector3(0.45, 0.45, 0.45), Vector3(ENVELOPE_DIAMETER * 0.5, 0, -ENVELOPE_LENGTH * 0.05),
			CyberMaterials.neon(Color(0.1, 1.0, 0.3), 5.0, 0.0, &"blimp"), false)
	CyberMaterials.box(hull, Vector3(0.4, 0.4, 0.4), Vector3(0, 0, ENVELOPE_LENGTH * 0.5 + 0.2),
			CyberMaterials.neon(Color(1.0, 1.0, 1.0), 5.0, 0.0, &"blimp"), false)
	StaticBatcher.merge(hull)
	# Four screens on the flanks, just above the equator, tilted UP 20 deg (his camera is above the blimp) and yawed
	# SCREEN_YAW_DEG toward the nose (front pair) or the tail (rear pair), so the view down the avenue sees a screen.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var screen := MeshInstance3D.new()
			screen.name = "Screen%s%s" % ["Port" if sx < 0.0 else "Starboard", "Fore" if sz < 0.0 else "Aft"]
			var quad := QuadMesh.new()
			quad.size = SCREEN
			screen.mesh = quad
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# A QuadMesh faces +Z. Yaw it to face outward (+-X), then a further SCREEN_YAW_DEG toward -Z (fore) or +Z
			# (aft), then tip its face up.
			var outward := PI / 2.0 * sx
			var toward := -deg_to_rad(SCREEN_YAW_DEG) * sx * sz  # fore (sz < 0) turns toward -Z on both flanks
			var face := Basis(Vector3.UP, outward + toward) * Basis(Vector3.RIGHT, deg_to_rad(-20.0))
			var along := sz * ENVELOPE_LENGTH * 0.2
			var radius := ENVELOPE_DIAMETER * 0.5 * sqrt(maxf(0.0, 1.0 - pow(along / (ENVELOPE_LENGTH * 0.5), 2.0)))
			screen.transform = Transform3D(face, Vector3(sx * (radius + 0.25), 0.9, along))
			add_child(screen)
			_screens.append(screen)
