class_name BrainSwitches
extends RefCounted
## Round 16 (brains): one switch per performance change of the round, so each is attributed by REMOVAL WITHIN ONE RUN
## (C16.3, verification.md "Attributing a behaviour's cost"), never by comparing two runs on a loaded machine.
##
## Every change behind a switch here is an EQUALITY: the same inputs in the same physics frame (or nav iteration) give
## the same answer with the switch on or off. That is what makes the A/B legitimate: `make ai-perf AB=1` flips them
## all (or `AB=<name>` one) every AB_BLOCK ticks inside ONE deterministic fight and charges each block's thread CPU to
## its arm, and the fight must come out identical to an unswitched run (its LOS fingerprint is printed beside the
## numbers). `--brains-off=<names>|all` on any run turns them off for the whole run: `make ai-parity
## PARITY_FLAGS=--brains-off=all` must print the same digest as `make ai-parity`, which is the proof that the switched
## path and the old path agree.
##
## Measurement and proof only: nothing here may change a decision, and every name must be read by exactly one change.

## Pathing.is_ready asks the owner probe once per nav iteration instead of per call.
static var ready_memo := true
## Movement._chord_on_mesh answers a repeat of the same chord in the same frame from memory, and computes its slack
## once per chord instead of once per sample.
static var chord_memo := true
## Pathing.closest_point answers a repeat of the same point in the same frame (and nav iteration) from memory.
static var closest_memo := true
## Avoidance caches each unit type's hull halves instead of reading the roster for every hull every tick.
static var avoid_halves := true
## Avoidance.neighbours keeps the nearest MAX_NEIGHBOURS as it goes instead of sorting every hull in reach.
static var avoid_neighbours := true
## Movement's planned-reverse check sweeps its forward arc only as far as a hit can change the decision.
static var kturn_cap := true
## Movement.note_decision hands the wall-contact instrument the route and an index instead of a copy every tick.
static var lazy_path := true
## TankBrain reads Movement.repaired_arrival / corridor_of instead of building a whole Movement.state() for two fields.
static var narrow_state := true

const NAMES: Array[String] = ["ready_memo", "chord_memo", "closest_memo", "avoid_halves", "avoid_neighbours",
		"kturn_cap", "lazy_path", "narrow_state"]

static var _parsed := false


## Apply `--brains-off=` once (the first caller in a process). Unknown names are refused loudly: a switch nothing reads
## would make an A/B come back a clean null.
static func ensure_parsed() -> void:
	if _parsed:
		return
	_parsed = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--brains-off="):
			for name: String in arg.trim_prefix("--brains-off=").split(","):
				if name == "all":
					set_all(false)
				elif NAMES.has(name):
					set_named(name, false)
				else:
					push_error("--brains-off=%s: no such switch (have %s, or all)" % [name, ", ".join(NAMES)])


static func set_all(on: bool) -> void:
	for name in NAMES:
		set_named(name, on)


static func set_named(name: String, on: bool) -> void:
	match name:
		"ready_memo":
			ready_memo = on
		"chord_memo":
			chord_memo = on
		"closest_memo":
			closest_memo = on
		"avoid_halves":
			avoid_halves = on
		"avoid_neighbours":
			avoid_neighbours = on
		"kturn_cap":
			kturn_cap = on
		"lazy_path":
			lazy_path = on
		"narrow_state":
			narrow_state = on
		_:
			push_error("BrainSwitches: no switch %s" % name)
