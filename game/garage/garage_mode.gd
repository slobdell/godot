class_name GarageMode
extends GameMode
## --garage: build an army, tap FIGHT, and play the skirmish with it (GA2). The garage is a screen
## over the still-empty arena; FIGHT hands over to SkirmishMode in the same process (nothing has
## spawned yet, so no scene reload is needed).
##   --enemy=OPPONENT      preselect the opponent: cpu:<archetype> (ArmyPresets, default cpu:balanced) or a doctrine
##   --seed=N              seed for a cpu:<archetype> army (default: random each fight)
##   --army=CODE           open with a shared army code (ArmyCode; browser: ?garage&army=CODE)
##   --garage-autofight    tap FIGHT as soon as the garage opens (smoke tests, screenshots of the handover)
## Prints GARAGE_FIGHT player=<path> enemy=<opponent> enemy_path=<doctrine> seed=<n> green=<tanks> rust=<tanks>
## when the skirmish starts.

const CPU_DIR := "user://doctrines/cpu/"

var screen: GarageScreen
var _layer: CanvasLayer


func role_name() -> String:
	return "GARAGE"


func start() -> void:
	main.hud.visible = false
	_layer = CanvasLayer.new()
	_layer.name = "Garage"
	_layer.layer = 10
	screen = GarageScreen.new()
	screen.name = "GarageScreen"
	screen.enemy = flags.text("enemy", screen.enemy)
	_layer.add_child(screen)
	main.add_child(_layer)
	screen.fight_requested.connect(fight)
	if flags.has("army"):
		screen.import_code(flags.text("army"))
	if flags.has("garage-autofight"):
		screen.fight.call_deferred()


## Leave the garage and start the skirmish with the saved army at `player_path`.
func fight(player_path: String, enemy: String) -> void:
	var seed_value := flags.integer("seed", randi() % 100000)
	var enemy_path := enemy
	if enemy.begins_with("cpu:"):
		var built := GarageMode.save_cpu_army(enemy.trim_prefix("cpu:"), seed_value)
		if built.has("error"):
			screen.report(String(built["error"]))
			return
		enemy_path = built["path"]
	_layer.queue_free()
	main.hud.visible = true
	main.flags.values.erase("garage")
	main.flags.values["skirmish"] = ""
	main.flags.values["player"] = player_path
	main.flags.values["enemy"] = enemy_path
	var skirmish := SkirmishMode.new()
	skirmish.main = main
	skirmish.flags = main.flags
	main.mode = skirmish
	skirmish.start()
	print("GARAGE_FIGHT player=%s enemy=%s enemy_path=%s seed=%d green=%d rust=%d" % [player_path, enemy, enemy_path, seed_value,
			main.game_match.team_tanks(Match.Team.GREEN).size(), main.game_match.team_tanks(Match.Team.RUST).size()])


## Build and save a CPU army. Returns {"path"} or {"error"}.
static func save_cpu_army(archetype: String, seed_value: int) -> Dictionary:
	if not ArmyPresets.ARCHETYPES.has(archetype):
		return {"error": "no CPU army archetype '%s' (have %s)" % [archetype, ArmyPresets.ids()]}
	var loadout := ArmyPresets.build(archetype, GarageCatalog.from_game(), seed_value)
	if not loadout.is_ready():
		return {"error": "CPU army %s isn't legal: %s" % [archetype, loadout.problems()]}
	return ArmyStore.save(loadout.to_doctrine(), archetype, CPU_DIR)
