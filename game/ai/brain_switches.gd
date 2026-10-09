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
## SlotGround.standable_for keeps its answers for the nav map's iteration (the same point and clearance, the same answer).
static var ground_memo := true
## SuppressionFeed and FireLanes call the Match's L2 / line-of-fire queries directly instead of has_method + call().
static var direct_calls := true
## ElementPlan.preview (the HUD's task preview) keeps its last answers for the same arguments.
static var preview_memo := true
## ...and asks the start pose's outline per point, only where a probe along the arc needs it (needs kturn_cap).
static var kturn_lazy := true
## TankBrain reads Movement.repaired_arrival / corridor_of instead of building a whole Movement.state() for two fields.
static var narrow_state := true
## Round 17 (T6): AiTickCache builds the allies rows on the first ask of a tick (a thinking brain) instead of every tick.
static var lazy_allies := true
## Round 23 (native): the ported seams (IncomingFire.closest_approach, ...) call the native library (C++, native/) instead
## of their GDScript. ON only while the library is loaded (NativeBridge.available): set_named masks it, so
## `set_all(true)` on a machine without the .so stays OFF. `_agents/native.md`.
static var native := NativeBridge.available
## ...and one sub-switch per ported seam, so each step is priced on its own (`AB_SWITCH=native_avoid`): a seam runs
## native only while `native` AND its own switch are on. `native` alone (the master) prices every port at once.
static var native_dodge := true  # CombatMotion.would_be_hit as one native call (N0b)
static var native_avoid := true  # Avoidance.solve: neighbours + ORCA native over this tick's table (N1)
static var native_cover := true  # CoverMap.clear_line / clear_line_coarse / path_blocked: the LOS grid, boxes and memo native (N1b)
static var native_nav := true  # Pathing.closest_point: the navmesh's closest point over a native polygon index (N2a)
static var native_record := false  # N3a (round 24): NativeRecord.fill / fill_contacts once a tick (the data the ported execute step will read); OFF while nothing reads it, ON in an A/B prices the marshalling
static var native_scan := false  # Gunnery._nearest_shootable as one native call over the record (N3b weapon.scan; OFF by its price: 50 v 50 +1.1 % mean, under the 2 % bar, d0bc1517 builder0 n = 3)
static var native_path := true  # Movement._next_waypoint's route-following tail as one native call (N3b move.path; its seam lands in movement.gd after CP1)
static var native_drive := true  # Movement.drive as one native call per tank (N3c; its seam lands in movement.gd after CP1)
static var native_situation := false  # TankBrain.build_situation's allies + contact selection + contact entries as one native call (N3d; OFF by its price: 50 v 50 +1.7 % mean, under the 2 % bar, 00bb82dc builder0 n = 3)
static var native_matchups := false  # TankBrain.matchups_for (70 % of decide) with Matchups' math as one native call (N3d; OFF by its price: 50 v 50 +0.2 % mean, 4a8fbf20 builder0 n = 3)
static var native_decide := true  # TankBrain.decide as one native call (N3d; ruled by the laptop's windowed in-contact number)
static var native_tq := false  # TacticalQuery.find_cover / find_cover_fire as one native call each (C24.6; OFF by the in-contact rule: tick -2.1 %, se 1.1 %, not outside 2 se; the direct parts -0.29 ms)
static var native_move := false  # Movement's geometry: _chord_compute's samples, _outline_ok, _arc_hit as one native call each (N2b; OFF by ruling: ~1 % of the band, see _agents/native.md)

const NAMES: Array[String] = ["ready_memo", "chord_memo", "closest_memo", "avoid_halves", "avoid_neighbours",
		"kturn_cap", "kturn_lazy", "lazy_path", "ground_memo", "direct_calls",
		"preview_memo", "narrow_state", "lazy_allies", "native", "native_dodge", "native_avoid", "native_cover", "native_nav", "native_move", "native_record", "native_scan", "native_path", "native_drive", "native_situation", "native_matchups", "native_decide", "native_tq"]

static var _parsed := false


## Apply `--brains-off=` once (the first caller in a process). Unknown names are refused loudly: a switch nothing reads
## would make an A/B come back a clean null.
static func ensure_parsed() -> void:
	if _parsed:
		return
	_parsed = true
	apply_args(OS.get_cmdline_user_args())


## The command line's switches: `--brains-on=a,b` first (round 24: switches that ship OFF, for an arm that measures one
## on another workload), then `--brains-off=a,b|all`. Tests call it with their own arguments.
static func apply_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--brains-on="):
			for name: String in arg.trim_prefix("--brains-on=").split(","):
				if NAMES.has(name):
					set_named(name, true)
				else:
					push_error("--brains-on=%s: no such switch (have %s)" % [name, ", ".join(NAMES)])
	for arg in args:
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
		"kturn_lazy":
			kturn_lazy = on
		"lazy_path":
			lazy_path = on
		"ground_memo":
			ground_memo = on
		"direct_calls":
			direct_calls = on
		"preview_memo":
			preview_memo = on
		"narrow_state":
			narrow_state = on
		"lazy_allies":
			lazy_allies = on
		"native":
			native = on and NativeBridge.available
		"native_dodge":
			native_dodge = on
		"native_avoid":
			native_avoid = on
		"native_cover":
			native_cover = on
		"native_nav":
			native_nav = on
		"native_move":
			native_move = on
		"native_record":
			native_record = on
		"native_scan":
			native_scan = on
		"native_path":
			native_path = on
		"native_drive":
			native_drive = on
		"native_situation":
			native_situation = on
		"native_matchups":
			native_matchups = on
		"native_decide":
			native_decide = on
		"native_tq":
			native_tq = on
		_:
			push_error("BrainSwitches: no switch %s" % name)
