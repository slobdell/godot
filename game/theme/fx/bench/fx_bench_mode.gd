class_name FxBenchMode
extends GameMode
## `--fx-bench` (browser `?fx-bench`): swap the main scene for the FX lab (fx_bench.gd).
## Owned by look & feel; GameMode.choose() routes the flag here.

const SCENE := "res://game/theme/fx/bench/fx_bench.tscn"


func role_name() -> String:
	return "FX_BENCH"


func start() -> void:
	main.get_tree().change_scene_to_file.call_deferred(SCENE)
