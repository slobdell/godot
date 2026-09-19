class_name AudioSolo
extends RefCounted
## Stretch (round 5): hear one layer of the mix on its own while tuning. `--audio-solo=guns` plays only weapons
## firing; the others are `impacts`, `engines`, `crowd`, `booth`, `music`, and `ui`. With no flag everything plays.
## Each system asks `AudioSolo.allows(layer)` once when it is built, so the flag costs nothing per frame.

const LAYERS := ["guns", "impacts", "engines", "crowd", "booth", "music", "ui"]
## Which layer each SfxSystem sound belongs to (anything not listed is an impact).
const SOUND_LAYER := {
	"cannon_shot": "guns", "tank_boom": "guns", "autocannon_shot": "guns", "mg_round": "guns", "mg_loop": "guns", "twin_mg_loop": "guns",
	"mortar_launch": "guns", "laser_pulse": "guns", "flame_loop": "guns", "shell_whine": "guns",
	"railgun_shot": "guns", "energy_beam": "guns", "plasma_loop": "guns", "pulse_shot": "guns",
	"missile_launch": "guns", "sonic_loop": "guns", "energy_hit": "impacts",
	"engine_diesel": "engines", "engine_v8": "engines", "engine_electric": "engines", "tread_loop": "engines",
	"tire_loop": "engines", "crowd_murmur": "crowd", "crowd_cheer": "crowd",
	"ui_blip": "ui", "ui_alert": "ui", "ui_tick": "ui", "ui_ack_move": "ui", "ui_ack_attack": "ui", "ui_select": "ui",
}


## The layer being soloed, or "" for the full mix.
static func solo() -> String:
	var wanted := LaunchFlags.from_environment().text("audio-solo", "")
	return wanted if wanted in LAYERS else ""


static func allows(layer: String, soloed: String = solo()) -> bool:
	return soloed == "" or soloed == layer


static func layer_of(sound: String) -> String:
	return String(SOUND_LAYER.get(sound, "impacts"))
