class_name GarageSettings
extends RefCounted
## The garage's small per-player memory, in a ConfigFile (path "" = in memory only, for tests and
## automated runs, so they never touch the player's file):
##   - first-run tips: a tip bar that advances as the player does each thing (X skips), then a few
##     Hud.post_message tips when their first skirmish starts;
##   - the army they last fought with, so the garage reopens on it.

const DEFAULT_PATH := "user://garage.cfg"
## [tip, the event that completes it]
const STEPS := [
	["TIP 1/3: tap a unit in a squad to equip it.", "select_unit"],
	["TIP 2/3: pick a weapon, or drag a unit chip onto another squad.", "edit"],
	["TIP 3/3: choose an opponent, then tap FIGHT.", "fight"],
]
const MATCH_TIPS := [
	"Your squads hold position until you give orders.",
	"Tap a tank to select its squad, then drag on the ground to send it (drag direction = facing).",
	"Planning pause: give orders first, then press Space to start the battle.",
]

var path: String
var step := 0
var match_tips_shown := false
## Path of the army the player last fought with ("" = none).
var last_army := ""


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path
	var config := ConfigFile.new()
	if path != "" and config.load(path) == OK:
		step = int(config.get_value("tutorial", "step", 0))
		match_tips_shown = bool(config.get_value("tutorial", "match_tips_shown", false))
		last_army = String(config.get_value("armies", "last", ""))


## The current garage tip, or "" when done.
func tip() -> String:
	return String(STEPS[step][0]) if step < STEPS.size() else ""


## Something happened; returns true if it completed the current tip.
func notify(event: String) -> bool:
	if step >= STEPS.size() or STEPS[step][1] != event:
		return false
	step += 1
	_save()
	return true


func skip_tips() -> void:
	step = STEPS.size()
	match_tips_shown = true
	_save()


## The skirmish tips, once ever (empty afterwards).
func take_match_tips() -> Array:
	if match_tips_shown:
		return []
	match_tips_shown = true
	_save()
	return MATCH_TIPS


func remember_army(army_path: String) -> void:
	last_army = army_path
	_save()


func _save() -> void:
	if path == "":
		return
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("tutorial", "step", step)
	config.set_value("tutorial", "match_tips_shown", match_tips_shown)
	config.set_value("armies", "last", last_army)
	config.save(path)
