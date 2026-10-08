extends SceneTree
## `make native-info`: what this Godot loaded (round 23, native). Prints one NATIVE line and quits.


func _init() -> void:
	print("NATIVE %s | switch %s | %s" % [NativeBridge.describe(), "on" if BrainSwitches.native else "off", OS.get_environment("HOSTNAME")])
	quit(0)
