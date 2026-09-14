class_name TitleMode
extends GameMode
## `--title` (browser `?title`): swap the main scene for the animated title screen.
## Owned by look & feel; GameMode.choose() routes the flag here.

const SCENE := "res://game/ui/widgets/title/title_screen.tscn"


func role_name() -> String:
	return "TITLE"


func start() -> void:
	main.get_tree().change_scene_to_file.call_deferred(SCENE)
