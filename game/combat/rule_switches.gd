class_name RuleSwitches
extends RefCounted
## Round 37 (rules, C37.2): the "stop to be strong" rules against the slug-fest, each behind its own switch so it can be
## judged alone and turned off after it ships. R38.55 (his call, game_design.md *His call on R1-R3*): all three ship ON
## by default, a direction call rather than a passed bar. `--rules-off=` turns each one off:
##   sight     R1: a crew's OWN motion sets its sight (driving ~85 % of its radius, stopped ~2 s ~110 %; Tank.settle_motion_sight)
##   spread    R2: moving fire much less accurate (Match.MOVING_SPREAD_FACTOR 1.5 -> RULES_MOVING_SPREAD_FACTOR)
##   pin_slow  R3: suppression slows driving, never stops it (Tank.pin_slow)
## On any run: `--rules-off=sight,spread,pin_slow` for the old game, `--rules-on=` (now a no-op unless DEFAULT_ON shrinks),
## or the brief's spellings `--rules-sight`, `--rules-spread`, `--rules-pin-slow`. Tests set the static vars directly and
## put them back.

const NAMES := ["sight", "spread", "pin_slow"]
## Rules that ship ON (R38.55: his direction call). `--rules-off=` still turns them off.
const DEFAULT_ON: Array[String] = ["sight", "spread", "pin_slow"]

static var sight_on := _on("sight")
static var spread_on := _on("spread")
static var pin_slow_on := _on("pin_slow")


static func _on(name: String) -> bool:
	var on := DEFAULT_ON.has(name)
	var alias := "--rules-" + name.replace("_", "-")
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text == alias:
			on = true
		elif text.begins_with("--rules-on=") and text.trim_prefix("--rules-on=").split(",", false).has(name):
			on = true
		elif text.begins_with("--rules-off=") and text.trim_prefix("--rules-off=").split(",", false).has(name):
			return false
	return on


## The switches as one line for run headers and series rows ("sight=on spread=off pin_slow=off").
static func describe() -> String:
	return "sight=%s spread=%s pin_slow=%s" % ["on" if sight_on else "off", "on" if spread_on else "off",
			"on" if pin_slow_on else "off"]
