class_name AiExplainOverlay
extends MeshInstance3D
## Why is that unit doing that? (round-3 stretch, _agents/streams/ai.md): with --ai-explain (or --ai-explain=green /
## =rust for one team) every brain tank draws a line to where it's driving, colored by what it's doing, and a thin line
## to what it's shooting. Nameplates already carry the words (tank.intent). Presentation only: it reads brains and never
## changes them. Brains add it to their match on their first think when the flag is on (TankBrain.think).

const COLORS := {
	"order": Color(0.35, 0.65, 1.0),     # MOVE, FOLLOW, PURSUE, KEEP_SLOT, HOLD under orders
	"fight": Color(1.0, 0.35, 0.3),      # ENGAGE, FLANK, ORBIT, BOMBARD, CLEAR_LANE
	"cover": Color(1.0, 0.85, 0.25),     # COVER_FIRE, TAKE_COVER, RECHARGE
	"away": Color(0.9, 0.9, 0.95),       # RETREAT, RESUPPLY
	"roam": Color(0.55, 1.0, 0.55),      # everything else (ADVANCE, SPOT, INVESTIGATE, ...)
}
const CATEGORY := {"MOVE": "order", "FOLLOW": "order", "PURSUE": "order", "KEEP_SLOT": "order", "HOLD": "order",
		"ENGAGE": "fight", "FLANK": "fight", "ORBIT": "fight", "BOMBARD": "fight", "CLEAR_LANE": "fight",
		"COVER_FIRE": "cover", "TAKE_COVER": "cover", "RECHARGE": "cover", "RETREAT": "away", "RESUPPLY": "away"}
## Redraw this often (ticks).
const EVERY_TICKS := 6
const LINE_HEIGHT := 0.6

var game_match: Match
## -1 = both teams.
var team := -1
var _mesh := ImmediateMesh.new()
var _materials := {}


## The overlay flag from the command line: -2 = off, -1 = both teams, else a team.
static func flag_team() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg == "--ai-explain":
			return -1
		if arg.begins_with("--ai-explain="):
			match arg.trim_prefix("--ai-explain="):
				"green":
					return Match.Team.GREEN
				"rust":
					return Match.Team.RUST
				_:
					return -1
	return -2


## Adds the overlay to `game_match` once, when the flag asks for it and something draws.
static func ensure(game_match: Match) -> void:
	if game_match.has_node("AiExplainOverlay"):
		return
	var wanted := flag_team()
	if wanted == -2:
		return
	var overlay := AiExplainOverlay.new()
	overlay.name = "AiExplainOverlay"
	overlay.game_match = game_match
	overlay.team = wanted
	game_match.add_child.call_deferred(overlay)


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for key: String in COLORS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLORS[key]
		material.no_depth_test = true
		_materials[key] = material


func _physics_process(_delta: float) -> void:
	if game_match == null or game_match.tick % EVERY_TICKS != 0:
		return
	redraw()


## Rebuilds the lines from every brain's current choice and standing orders. Returns how many units it drew.
func redraw() -> int:
	_mesh.clear_surfaces()
	var drawn := 0
	var by_name := AiTickCache.tanks_by_name(game_match)
	for node in game_match.brains.get_children():
		var brain := node as TankBrain
		if brain == null or brain.tank == null or not brain.tank.is_alive() or brain.choice.is_empty():
			continue
		if team >= 0 and brain.tank.team != team:
			continue
		var from := brain.tank.global_position + Vector3(0, LINE_HEIGHT, 0)
		var category: String = CATEGORY.get(brain.choice["option"], "roam")
		var move := brain.move_order
		if move.get("type") == "move_to" or move.get("type") == "face":
			var to := Vector3(float(move["x"]), LINE_HEIGHT, float(move["z"]))
			_line(from, to, category)
			_cross(to, category)
		var target := by_name.get(brain.engaged_target) as Tank
		if target != null and target.is_alive():
			_line(from, target.global_position + Vector3(0, LINE_HEIGHT + 0.4, 0), "fight")
		drawn += 1
	return drawn


func _line(a: Vector3, b: Vector3, category: String) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _materials[category])
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(b)
	_mesh.surface_end()


func _cross(at: Vector3, category: String) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _materials[category])
	for offset: Vector3 in [Vector3(1, 0, 1), Vector3(1, 0, -1)]:
		_mesh.surface_add_vertex(at - offset)
		_mesh.surface_add_vertex(at + offset)
	_mesh.surface_end()
