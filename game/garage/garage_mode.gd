class_name GarageMode
extends GameMode
## --garage: build an army, tap FIGHT, and play the skirmish with it (GA2). The garage is a screen
## over the still-empty arena; FIGHT hands over to SkirmishMode in the same process (nothing has
## spawned yet, so no scene reload is needed).
##   --enemy=DOCTRINE      preselect the CPU opponent (default individuals)
##   --garage-autofight    tap FIGHT as soon as the garage opens (smoke tests, screenshots of the handover)
## Prints GARAGE_FIGHT player=<path> enemy=<doctrine> green=<tanks> rust=<tanks> when the skirmish starts.

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
	screen.enemy = flags.text("enemy", "individuals")
	_layer.add_child(screen)
	main.add_child(_layer)
	screen.fight_requested.connect(fight)
	if flags.has("garage-autofight"):
		screen.fight.call_deferred()


## Leave the garage and start the skirmish with the saved army at `player_path`.
func fight(player_path: String, enemy: String) -> void:
	_layer.queue_free()
	main.hud.visible = true
	main.flags.values.erase("garage")
	main.flags.values["skirmish"] = ""
	main.flags.values["player"] = player_path
	main.flags.values["enemy"] = enemy
	var skirmish := SkirmishMode.new()
	skirmish.main = main
	skirmish.flags = main.flags
	main.mode = skirmish
	skirmish.start()
	print("GARAGE_FIGHT player=%s enemy=%s green=%d rust=%d" % [player_path, enemy,
			main.game_match.team_tanks(Match.Team.GREEN).size(), main.game_match.team_tanks(Match.Team.RUST).size()])
