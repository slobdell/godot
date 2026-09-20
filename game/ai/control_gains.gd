class_name ControlGains
extends RefCounted
## N6: the gains every regulator in the movement layer reads, as DATA (the lead: *"we might even be able to
## differentiate units of different factions by PID values"*). Defaults first; per-faction tables are the X8 stretch
## and only override what they name.
##
## station: a unit keeping its place relative to a moving point (a formation slot, a leader). The error is metres
##          along its heading to the point; the output is m/s added to the point's own speed (a correction on top of
##          feed-forward, not the whole command). kd acts on the gap's rate, i.e. my speed relative to the point's.

const DEFAULT := {
	"station": {"kp": 0.9, "ki": 0.08, "kd": 0.6, "integral_limit": 4.0, "output_limit": 6.0},
}

## X8: per-faction overrides, merged over DEFAULT — the lead's idea that factions differ by their control law.
## The Condemned are the default (the reference crew). What each one should FEEL like, and the gains that do it:
##   syndicate  crisp and twitchy: high P, strong D (it brakes into its slot), a tight integral
##   gangs      loose and overshooting: low P, almost no D, a lazy integral (it swings past and comes back)
##   law        damped and deliberate: moderate P, heavy D (never overshoots, a little slower to close)
## Measured by test_station_keeping.gd (MEASURE station_faction lines): tracking gap, overshoot, settling time.
const FACTIONS := {
	"syndicate": {"station": {"kp": 1.5, "ki": 0.12, "kd": 0.9, "integral_limit": 3.0}},
	"gangs": {"station": {"kp": 0.45, "ki": 0.15, "kd": 0.05, "integral_limit": 6.0}},
	"law": {"station": {"kp": 0.7, "ki": 0.03, "kd": 1.2, "integral_limit": 3.0}},
}


## MEASURING ONLY (round 9, squad's X6 — the lead's named ask). Gains are chosen by `Units.stat(unit, "faction")`,
## so *"the same army with different gains"* could not be set up at all: changing the faction changes the hulls, the
## weapons and the doctrine with it, and the comparison stops being about the control law. This forces a gain set
## regardless of faction, so an identical army can be driven two ways and only the regulator differs.
##
## `--gains=<faction>` on any run sets it; a test or scenario may assign it directly and must restore it. Empty = off,
## which is the shipped behaviour and what every run does unless someone asks otherwise.
##
## Read at CALL time, never captured in a static initialiser — `CombatMotion.fixed_style` is the cautionary case in
## this codebase: a static initialised from another class's static ran before that one was populated, the switch
## silently did nothing, and round 7's first commitment A/B came back with two byte-identical arms.
static var forced := ""


static func _forced() -> String:
	if forced != "":
		return forced
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gains="):
			var name := arg.trim_prefix("--gains=")
			if not FACTIONS.has(name) and name != "":
				push_error("--gains=%s: no such faction (have %s). A flag nothing reads is an A/B with one treatment." % [
						name, ", ".join(FACTIONS.keys())])
			return name
	return ""


## The gains for `loop` ("station", …) for a unit of `faction` ("" = default), or for the forced set when one is on.
static func for_loop(loop: String, faction: String = "") -> Dictionary:
	var gains: Dictionary = (DEFAULT.get(loop, {}) as Dictionary).duplicate()
	var pick := _forced()
	var override: Variant = (FACTIONS.get(pick if pick != "" else faction, {}) as Dictionary).get(loop)
	if override is Dictionary:
		gains.merge(override, true)
	return gains
