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


## The gains for `loop` ("station", …) for a unit of `faction` ("" = default).
static func for_loop(loop: String, faction: String = "") -> Dictionary:
	var gains: Dictionary = (DEFAULT.get(loop, {}) as Dictionary).duplicate()
	var override: Variant = (FACTIONS.get(faction, {}) as Dictionary).get(loop)
	if override is Dictionary:
		gains.merge(override, true)
	return gains
