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

## X8 (stretch): per-faction overrides, merged over DEFAULT. Empty until the defaults are measured stable.
const FACTIONS := {}


## The gains for `loop` ("station", …) for a unit of `faction` ("" = default).
static func for_loop(loop: String, faction: String = "") -> Dictionary:
	var gains: Dictionary = (DEFAULT.get(loop, {}) as Dictionary).duplicate()
	var override: Variant = (FACTIONS.get(faction, {}) as Dictionary).get(loop)
	if override is Dictionary:
		gains.merge(override, true)
	return gains
