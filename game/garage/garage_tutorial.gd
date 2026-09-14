class_name GarageTutorial
extends RefCounted
## First-run hints: a short tip bar in the garage that advances as the player does each thing, then
## a few Hud.post_message tips when their first skirmish starts. Progress lives in a ConfigFile so
## returning players aren't nagged (path "" = in memory only, for automated runs). Tap the tip bar's X to skip.

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


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path
	var config := ConfigFile.new()
	if path != "" and config.load(path) == OK:
		step = int(config.get_value("tutorial", "step", 0))
		match_tips_shown = bool(config.get_value("tutorial", "match_tips_shown", false))


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


func skip() -> void:
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


func _save() -> void:
	if path == "":
		return
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("tutorial", "step", step)
	config.set_value("tutorial", "match_tips_shown", match_tips_shown)
	config.save(path)
