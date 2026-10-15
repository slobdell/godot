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
static var native_scan := false  # Gunnery._nearest_shootable as one native call over the record (N3b weapon.scan; OFF by its price: 50 v 50 +1.1 % mean, under the 2 % bar, d0bc1517 builder0 n = 3; in contact on the laptop, round 25: -0.39 %, se 1.08, 49e2bdcd n = 6 paired, still OFF)
static var native_path := true  # Movement._next_waypoint's route-following tail as one native call (N3b move.path; its seam lands in movement.gd after CP1)
static var native_drive := true  # Movement.drive as one native call per tank (N3c; its seam lands in movement.gd after CP1)
static var native_situation := true  # TankBrain.build_situation's allies + contact selection + contact entries as one native call (N3d; alone under the bar, 00bb82dc; ON in the N4 group below)
static var native_matchups := false  # TankBrain.matchups_for (70 % of decide) with Matchups' math as one native call (N3d; OFF by its price: 50 v 50 +0.2 % mean, 4a8fbf20 builder0 n = 3)
static var native_decide := true  # TankBrain.decide as one native call (N3d; ruled by the laptop's windowed in-contact number)
static var native_tq := true  # TacticalQuery.find_cover / find_cover_fire as one native call each (C24.6; alone -2.1 %, se 1.1 %, under the bar; ON in the N4 group below)
static var native_fire := true  # Movement._around_fire (the beaten-zone check, ThreatField's reads) inside the native drive (N4; alone -1.16 %, se 0.82: not outside 2 se)
## N4 group (pre-registered by the orchestrator, round 24 phase 2): native_situation + native_tq + native_fire ship ON
## TOGETHER: in contact, laptop windowed 58056d54, n = 6 paired, tick scripts -4.11 % (se 0.47) against all three off,
## game speed in the window 0.835 v 0.810. `--brains-off=native_n4` turns the group off as one.
static var native_el := true  # SlotGround natively: the water rules (on_anchor_side, pulled_dry) and standable_for (C24.8; ON round 25 by a FRESH pre-registered n = 12 on the WATER workload: tick -4.85 %, se 0.47, b1884509 flightdeck, locks + crossing 12-24 s, ABBA; earlier, OFF by the in-contact rule: laptop windowed 4ba8fd0b, ABBA n = 6 paired, tick -0.37 %, se 0.67 -- his foundry/parade have no water, so only standable_for's -0.15 ms of elements shows; headless Sumps elements 4.21 -> 3.27 ms; round 25 on the WATER workload, locks + crossing 12-24 s, 49e2bdcd n = 6 paired: tick -1.64 %, se 1.65, still OFF, though elements -2.06 ms, se 0.33)
static var native_cb := true  # Round 27 (stage 1 E2): the native drive's GDScript callbacks ported (_keep_station + its PID, the PID reset, _inflate_corners, Pathing.query, _blocker, _negotiate's early returns, _planned_reverse's cheap look, right_of_way, unstick); off = every one called back as before. ON with native_exec/native_owned because E6 measured the three together; its own price alone was ~0 +-1 % (round 27 B), which says it is not worth a switch by itself, not that it is unsafe
static var native_gun := false  # Round 27 (stage 1 E3): Gunnery.apply as one native call per crew (gun_native.cpp; OFF until priced)
static var native_exec := true  # Round 27 (stage 1 E5): OrderController.compute_command's common path as ONE native call per crew (execute_native.cpp). ON by E6 (his laptop, 19543dae, bar workload, ABBA n = 6 paired, with native_owned: 20 a side tick scripts -8.59 % se 3.90, game speed 0.890 -> 0.930; 25 a side -7.21 % se 0.68, 0.818 -> 0.865)
static var native_owned := true  # Round 27 (stage 1 E5b): native_exec on the C++-owned state (ON with native_exec by E6; a switch so the laptop's tick-profile arms can name it; --native-exec-owned is the same)
static var native_motion := false  # Round 28 (N6.1): TankMotion.step_in_place behind its own seam (motion_native.cpp). OFF by its price: the planners roll it many times a think, a crossing a step costs more than the step (50 v 50 band +1.7/+3.5/+2.3 %, builder0 8223ae16 n = 3, hashes equal); the native tank drive calls the same model with no crossing
static var native_tank := true  # Round 28 (N6.1): Tank._drive as one native call (tank_drive_native.cpp; the motion model with no crossing); ON: native-proof on = tank on his Sumps (+ leaders), foundry, terminus, yard
static var native_combat := true  # Round 28 (N6.2): combat resolution's rules natively (combat_native.cpp: the hit's terms, Tank.take_hit's arithmetic); ON: test_native_combat 840 terms + 840 take_hits 0 mismatches, native-proof on = combat (price ~0: a few hits a second)
static var native_pathing := true  # Round 28 (N6.4): Pathing.is_ready / query / find_path natively (pathing_native.cpp); ON: test_native_pathing 300 pairs 0 mismatches, native-proof on = off = pathing (price ~0, within builder0 noise)
static var native_perception := true  # Round 28 (N6.3): who sees whom as one batched pass a team (perception_native.cpp: Match._update_intel's sight and gun-ready lines; intel stays GDScript); ON: test_native_perception 240 poses 0 mismatches, native-proof on = off = perception (price ~0)
static var native_incoming := true  # Round 28 (N7.1): Match.incoming_projectiles (K2) and IncomingFire._count_in_flight natively (incoming_native.cpp; the estimate over combat_native's terms); ON: test_native_incoming 0 mismatches, native-proof equal (price ~0: K2 -8 %, the count unchanged)
static var native_shell := true  # Round 28 (N7.1c): Shell._fly natively (shell_native.cpp: the swept ray, the hit, the burn-out; called from each shell's own tick); ON: test_native_shell 0 mismatches, native-proof equal (price ~0)
static var native_threat := true  # Round 28 (N7.2): the suppression field natively (threat_native.cpp: ThreatField's stamps and decay, Match._update_suppression's settle); ON: test_native_threat 0 mismatches, native-proof equal (match/suppression 0.36 -> 0.23 % of the tick)
static var native_recorder := true  # Round 28 (N7.6): MatchRecorder's per-tick work natively (recorder_native.cpp: the task scan, the census, their rows); ON: test_native_recorder byte for byte, 0 mismatches (-24 % on its own work; the black box only records skirmishes)
static var native_wall := false  # Round 29 (N7.4): WallContact.observe's scan natively (wall_native.cpp: alive/parked, the slide collisions, the deepest wall, a hull touched); a wall tick still classified by the GDScript. OFF until its check
static var native_feed := true  # Round 30 (N7.5): ElementFeed's builders natively (feed_native.cpp: _shared, _normalize; the memo stays GDScript); ON once test_native_feed and native-proof feed are equal
static var native_planner := true  # Round 31 (C31.5, CP-P0): Planner.plan takes the C++ search (PlannerNative) when native and this; the GDScript search is the twin
static var native_controller := false  # Round 28 (N7.3a): OrderController._physics_process natively (controller_native.cpp: the stride hold, think then execute, the measurement bookkeeping); OFF until its check
## Round 31 (brains B8, a CP-H consumer, C31.4; R31.1: OPT-IN): the element's re-seat / make-room clock reads the honest
## speed (`Element.reads_slow`). NAMING it (`--brains-off=realslow`) flips it against REALSLOW_DEFAULT, as manoeuvre's
## `unstickback` / `kturnarc` / `realspeed` do: OPT-IN while the default is false, and the A/B's off arm once CP-H ships it
## (flipping the const is the whole ship change). Not in NAMES, so `--brains-off=all` (ai-parity's proof) and set_all
## never touch it.
const REALSLOW_DEFAULT := false
static var realslow := REALSLOW_DEFAULT
static var native_move := false  # Movement's geometry: _chord_compute's samples, _outline_ok, _arc_hit as one native call each (N2b; OFF by ruling: ~1 % of the band, see _agents/native.md)

const NAMES: Array[String] = ["ready_memo", "chord_memo", "closest_memo", "avoid_halves", "avoid_neighbours",
		"kturn_cap", "kturn_lazy", "lazy_path", "ground_memo", "direct_calls",
		"preview_memo", "narrow_state", "lazy_allies", "native", "native_dodge", "native_avoid", "native_cover", "native_nav", "native_move", "native_record", "native_scan", "native_path", "native_drive", "native_situation", "native_matchups", "native_decide", "native_tq", "native_fire", "native_el", "native_cb", "native_gun", "native_exec", "native_owned", "native_motion", "native_tank", "native_combat", "native_pathing", "native_perception", "native_incoming", "native_shell", "native_threat", "native_recorder", "native_controller", "native_wall", "native_feed", "native_planner"]
## Switch GROUPS: names `--brains-on=` / `--brains-off=` / an A/B accept that set several switches at once (set_named);
## not switches themselves, so set_all and a test reading every switch walk NAMES only.
const GROUPS: Array[String] = ["native_n4"]

static var _parsed := false


## Apply `--brains-off=` once (the first caller in a process). Unknown names are refused loudly: a switch nothing reads
## would make an A/B come back a clean null.
static func ensure_parsed() -> void:
	if _parsed:
		return
	_parsed = true
	apply_args(OS.get_cmdline_user_args())


## `realslow` once `--brains-off` names it: the opposite of its default, never forced one way (round 31: the opt-in parse
## set it true, so with the default flipped ON no arm could turn it off). Pure, so a test can read both defaults.
static func realslow_named(default_value: bool) -> bool:
	return not default_value


## The command line's switches: `--brains-on=a,b` first (round 24: switches that ship OFF, for an arm that measures one
## on another workload), then `--brains-off=a,b|all`. Tests call it with their own arguments.
static func apply_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--brains-on="):
			for name: String in arg.trim_prefix("--brains-on=").split(","):
				if NAMES.has(name) or GROUPS.has(name):
					set_named(name, true)
				else:
					push_error("--brains-on=%s: no such switch (have %s)" % [name, ", ".join(NAMES)])
	for arg in args:
		if arg.begins_with("--brains-off="):
			for name: String in arg.trim_prefix("--brains-off=").split(","):
				if name == "all":
					set_all(false)
				elif name == "realslow":
					realslow = realslow_named(REALSLOW_DEFAULT)
				elif NAMES.has(name) or GROUPS.has(name):
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
		"native_fire":
			native_fire = on
		"native_el":
			native_el = on
		"native_cb":
			native_cb = on
		"native_gun":
			native_gun = on
		"native_exec":
			native_exec = on
		"native_owned":
			native_owned = on
		"native_motion":
			native_motion = on
		"native_tank":
			native_tank = on
		"native_combat":
			native_combat = on
		"native_pathing":
			native_pathing = on
		"native_perception":
			native_perception = on
		"native_incoming":
			native_incoming = on
		"native_shell":
			native_shell = on
		"native_threat":
			native_threat = on
		"native_recorder":
			native_recorder = on
		"native_controller":
			native_controller = on
		"native_wall":
			native_wall = on
		"native_feed":
			native_feed = on
		"native_planner":
			native_planner = on
		"native_n4":
			native_situation = on
			native_tq = on
			native_fire = on
		_:
			push_error("BrainSwitches: no switch %s" % name)
