class_name Element
extends RefCounted

## Round 19 (brains B5): a crew left this element (remove). Elements turns it into `element_changed` (or disbands an
## element left empty), whoever called remove: before it, a crew taken out by a caller other than Elements.form left
## the brains reading the old station until the next poll.
signal member_removed(unit_name: String)
## An element: a cluster of vehicles with a LEADER that runs them by standard operating procedure (contract
## L1, doctrine X1). The commander — the player or the CPU — gives the element a TASK (move, attack, screen,
## support by fire, hold). The leader decides the movement formation, the movement technique and the battle
## drills from its DoctrineTable, and issues ONE order per vehicle through control's K1 `Orders`, so every
## brain still obeys exactly one thing and keeps all of its own micro.
##
## The lead (2026-09-16): *"we should generally treat the game as cases where we're commanding well trained
## battle squads who operated based on standard operating procedures (like the army does) where there's
## essentially always a formation for any given task OR there's always a central decision maker per cluster
## of vehicles that automatically determines what the formation is based on their own decision matrix."*
##
## A player order always wins: if a vehicle's current order did not come from this element, the element stops
## commanding it (`detached`) until that order is finished, then quietly takes it back. Nothing an element
## does can hold a unit against its commander (K1's response guarantee).
##
## Decisions are pure: ElementSituation.build (the only impure step) -> Drills.select -> ElementPlan.build.

## Members are re-planned this often (ticks). Matches Match.INTEL_EVERY_TICKS: a leader can't react to
## intelligence it doesn't have yet.
const UPDATE_TICKS := SimClock.TICK_RATE / 10
## A unit's goal has to move this far before its order is re-issued: every new order resets what its brain
## was doing (round-3 lesson), so the leader does not nudge people around.
const REISSUE_M := 8.0
## The same intention is not handed to the same unit again inside this many ticks (2 s): a standing order already
## follows a moving target, and re-giving it only redraws the player's markers and costs frames.
const RE_ISSUE_TICKS := SimClock.TICK_RATE * 2
## Form-up ETAs (a navmesh route each) are refreshed at most this often.
const ETA_REFRESH_TICKS := SimClock.TICK_RATE
## A unit already this close to the goal of an order it has finished is left standing.
const SETTLED_M := 6.0
const MAX_EVENTS := 12

var id := 0
var element_name := ""
var team := 0
## Succession order: the first living member is the leader. Never reordered.
var roster: PackedStringArray = []
var leader := ""
var task := {}
var table: DoctrineTable = null

## What the leader decided last update (ElementPlan.build's output, for the HUD).
var formation := TacticsFormation.DEFAULT
var technique := "traveling"
var drill := ""
var reason := ""
var slots := {}
var sectors := {}
## Who stands in which slot of which shape ({unit: [formation, count, index]}): handed back to the next plan so
## the seating is stable from one update to the next (N2).
var seats := {}
## X1 (round 9): this element's TACTICAL pitch — Vector2(across the heading, along it), the doctrine's number for the
## terrain raised to what the members' own hulls fit in. It is what a slot's leash is one of (TankBrain.slot_leash)
## and what the coherence probe reports beside its threshold. The pitch a particular set of slots was laid at may be
## tighter, because X2 deforms it for the corridor — `corridor_m` and `file` below say by how much.
var pitch := Vector2(TacticsFormation.DEFAULT_SPACING, TacticsFormation.DEFAULT_SPACING)
## X2 (A8): the drivable width across the heading of the leg the element is on (metres; INF = open, or unmeasured),
## and how far its shape is pulled toward single file for it (0 = the nominal shape). Measured once per LEG, not per
## update: ~40 navmesh queries, and a leg is 22-45 m of driving.
## For nav (round 9): {unit: the slot the formation asked for} for the members whose slot SlotGround had to move to
## standable ground. Empty when every slot was already standable, which is the common case.
var slots_asked := {}
var corridor_m := INF
var file := 0.0
## X3 (A9): the element's bottleneck arrival time in TICKS — the time every member's pace is parameterised against.
var bottleneck_ticks := 0
## X3 (A9): the bounding-overwatch phase machine, when the element is bounding. {} when it is not.
## {"phase": int, "since_tick": int, "movers": PackedStringArray, "overwatch": PackedStringArray, "base": PackedStringArray}
var bound := {}
var _corridor_from: Variant = null
var _corridor_to: Variant = null
## X3: seconds each member needs to reach its slot, and the speed fraction it drives at so the element arrives
## together (FormUp). Refreshed every update.
var etas := {}
var paces := {}
var _etas_tick := -1_000_000
var events: PackedStringArray = []

## Round 12: the plain move's TRAVELLING ANCHOR (ElementPlan's TRANSIT block): {"route": Array[Vector3], "length",
## "s" (metres along the route), "tick" (last advance), "speed" (m/s at full pace), "pace" (0..1, the lag rule),
## "anchor": Vector3, "heading": Vector3, "velocity": Vector2 (m/s), "final_heading": Vector3, "arrived": bool}.
## {} for any task that is not a plain move to a point (or a move too short to travel). Impure to create (a navmesh
## route), pure to advance; passed to the plan as `state.transit`.
var transit := {}
## The crews' places on the way ({unit: Vector3}), from the last plan; {} when the element is not in transit. Published
## for the brains (ElementFeed "station"), which drive to it instead of the final slot while it exists.
var stations := {}
## Round 12, S3: the crews the fall-in rule is holding in their own lane this update (ElementPlan.fall_in); [] otherwise.
var falling_in: Array = []
## ...and where the SHAPE puts each crew, before that rule (what a probe measures "in formation" against).
var shape_stations := {}
## Round 23 (B1): the shape's OWN stations on the way (ElementPlan.stations_along, before the convergence from where
## each crew stood): what the pacing rules measure against. {} when not in transit.
var shape_along := {}
## The task (task_seq) whose move was too short for an anchor, so the question is not re-asked every update.
var _transit_declined_seq := -1

## Plan state carried between updates.
var anchor: Variant = null
## X7: the covered route the element is following (waypoints) and which one it is driving to.
var route: Array = []
var route_index := 0
## Round 7 flow: the element has switched to its final slots for this task (never flows again until a new task).
var flow_joined := false
## Whether this task's dragged facing has been handed to every crew yet (option 3; one order per crew per task).
var facing_sent := false
var heading := Vector3.FORWARD
var bounding := 0
## Round 15 (squad P5): the bait drill's fixed hiding place and whether its runner has turned for home (ElementPlan).
var bait_hide: Variant = null
var bait_back := false
var arrived := false
## Round 21 (P2): the element's memory of the target its attack names, {"name", "position", "velocity", "seen_tick"}
## (flat), from its team's intel each update and kept after intel forgets it (12 s), until the target dies or the task
## changes; and whether the attack has become a pursuit (ElementPlan.pursues, sticky for the task).
var pursuit := {}
var pursuing := false
## Round 21 (orders' R2): whether a drill set the current anchor (ElementPlan.stale_anchor).
var anchor_by_drill := false
## Round 22 (B1): UnansweredFire's memory, {unit: {"since", "last_hit", "outcome", "point", "target", ...}}: who is
## being hit by fire it cannot return, since when, and what it is doing about it.
var ducks := {}
var drill_tick := 0
var drill_point: Variant = null
var drill_target := ""
## unit name -> the order this element issued it: {"id", "verb", "to", "target"}.
var _issued := {}
## Units whose current order came from somewhere else (the player): not ours to command.
var _detached := {}
## Contact name -> the tick this element first knew of it, so a drill can tell an ambush from a firefight.
var _known := {}
## X5: how many of this element's orders carried a `facing` (a halt, a hold or a firing line). The counter makes
## "a squad hold issues a facing" falsifiable in a real match rather than only in a unit test.
var _facings_issued := 0
## For nav (round 9, A1's finding): WHY the goal of an order this element issued moved. nav measured that its fixed
## repath cadence is worth ~3% of re-planning in a fight and that the rest are events — overwhelmingly "the goal
## moved" — and from its side of the seam it cannot tell an order that genuinely changed from a slot that jittered.
## From this side it is four different things, and they are four different bugs:
##   task     a new task arrived (the commander really did change its mind)
##   leg      the element advanced its leg, so the whole formation's anchor moved
##   reseat   this unit changed slot within the same shape
##   drift    same task, same leg, same seat, and the goal still moved: the slot itself wandered
## `following` is the other half of the answer: a member on a K1 `follow` has a goal that slides with its leader
## EVERY TICK by design (round 7's flow), which nav sees as continuous goal movement and which is not a re-issue at
## all. A number here of n means n of this element's members have a deliberately moving goal.
var goal_moves := {"task": 0, "leg": 0, "reseat": 0, "drift": 0}
var following := 0
## Bumped whenever anything the HUD shows changes.
var revision := 0
## What changed in the last update ("task", "formation", "technique", "drill", "leader", "roster"): the
## announcer and the HUD both want to know WHICH, not just that something did.
var changed_fields: PackedStringArray = []
## A task was just assigned: the next decision is the element acting on it, which is worth reporting even
## when the shape it picks happens to be the one it already had.
var _fresh_task := false
## R2 (round 10): a task the PLAYER gave that no update has acted on yet. The next physics tick re-derives every crew's
## order from it, out of the UPDATE_TICKS cycle and past the re-issue suppression, and takes back any crew the player
## had detached: the task is his newer word to the whole squad. Only on the player's team (`preempting`), so a CPU
## element plans on its own tick exactly as before and the sim baseline (CPU against CPU) does not move.
var _preempt := false
## Which player task this is (bumped by every `assign`). Carried on the element's orders as `task` once control's
## Orders accepts the key (R2, the request in squad.md): two orders from different tasks are then never "the same
## order", which is the only way an unchanged `follow`, or a move whose only change is the facing, reaches a crew.
var task_seq := 0
## Round 24 (R2): the physics frame this element's task arrived on. Squads given one order together (his selection
## of several squads; a CPU commander's tasks in one pass) are the elements of one team whose task arrived on the
## same frame: they are the BODY whose route each of them weighs leaving (see _route_with_body).
var task_frame := -1
## The tick the last player task was acted on (-1: never), for the R2 readout and its test.
var preempted_tick := -1
## How far the element was from what triggered its current drill, in meters, when the drill started.
var drill_distance := 0.0
## Living members when the last decision was taken.
var strength := 0
## The situation's member data at the last decision (formation_group()).
var _last_members: Array = []
## Round 18 (brains D5): per crew, the closest it has come to its slot this movement and when: {name: [metres, tick]}.
## A crew driving (above STUCK_MPS) that has not closed by STUCK_GAIN_M for STUCK_TICKS asks for one fresh seating
## (leader unpinned, previous seats dropped) on the next update, at most once per RESEAT_COOLDOWN_TICKS.
const STUCK_MPS := 1.0
const STUCK_GAIN_M := 1.0
const STUCK_TICKS := SimClock.TICK_RATE * 4
const STUCK_FAR_M := 6.0
const RESEAT_COOLDOWN_TICKS := SimClock.TICK_RATE * 10
## ...and at most this many in one movement: past it the element stops asking (logged), so a re-seat that cannot help
## (the Cut, seed 3: 17 re-seats in 180 s beside a block's face in open ground) cannot run for the whole move.
const MAX_RESEATS := 3
var _reseats_this_move := 0
var _closest := {}
var _reseat := false
## ...and after one, the leader is not pinned to the point until this movement ends (arrival or a new task): pinned
## again on the next update, it took the front seat straight back.
var _unpinned := false
var _reseat_tick := -1_000_000
## Round 19 (brains B4): MAKE ROOM. A stuck crew with a STATIONARY squadmate within MAKE_ROOM_M of it trades slots with
## it instead of asking for a fresh seating, once a fresh seating this movement has come back unchanged: the squadmate standing a few metres short of its own slot, where its order
## counted as arrived, is what corks the gap (the Cut, seed 3: four Law tanks, a crew turning the corner of a city block
## pressed for 70 s against the squadmate parked 3.7 m short of its slot at that corner, and every fresh seating came
## back the same, 0312). The swap is the pair's seats as they were when it was made, re-applied while the Hungarian
## keeps choosing them, until the movement ends. Its own budget: MAX_SWAPS a movement, not counted toward MAX_RESEATS.
## {stuck: seat, blocker: seat} or {}.
const MAKE_ROOM_M := 9.0
static var MAKE_ROOM_ENABLED := true
var _swap := {}
## A fresh seating this movement gave every crew the seat it already had (the re-seat cannot help here).
var _reseat_useless := false
## At most this many make-room swaps in one movement (they do not count toward MAX_RESEATS).
const MAX_SWAPS := 2
var _swaps_this_move := 0
## How many make-room swaps (probes and tests).
var swaps := 0
## How many fresh seatings a stuck crew asked for (probes and tests).
var reseats := 0


func _init(p_id: int = 0, p_name: String = "", p_team: int = 0, p_roster: PackedStringArray = [],
		p_table: DoctrineTable = null) -> void:
	id = p_id
	element_name = p_name
	team = p_team
	roster = p_roster
	leader = roster[0] if not roster.is_empty() else ""
	table = p_table


## Give the element something to do. "" or a human-readable reason it can't.
func assign(new_task: Variant) -> String:
	_state_stamp += 1
	var error := ElementTask.validate(new_task)
	if error != "":
		return error
	task = (new_task as Dictionary).duplicate(true)
	_fresh_task = true
	_preempt = true
	task_seq += 1
	task_frame = Engine.get_physics_frames()
	# A new task starts a new movement: forget the leg, the route and any drill we were running.
	anchor = null
	route = []
	route_index = 0
	transit = {}
	stations = {}
	shape_stations = {}
	shape_along = {}
	falling_in = []
	flow_joined = false
	facing_sent = false
	arrived = false
	_closest = {}
	_unpinned = false
	_reseats_this_move = 0
	_swap = {}
	_reseat_useless = false
	_swaps_this_move = 0
	drill = ""
	drill_point = null
	drill_target = ""
	pursuit = {}
	pursuing = false
	ducks = {}
	_log("task: %s" % ElementTask.describe(task))
	revision += 1
	return ""


## The same task with a new aim (target or point), without starting the element over: its drill, its route and its
## seating stand; only a firing line or leg anchored on the old point is re-chosen when the point moved (X6, round 6).
func retarget(new_task: Variant) -> String:
	_state_stamp += 1
	var error := ElementTask.validate(new_task)
	if error != "":
		return error
	if String((new_task as Dictionary).get("verb", "")) != String(task.get("verb", "")):
		return assign(new_task)
	var old_point: Variant = ElementTask.destination(task)
	if String((new_task as Dictionary).get("target", "")) != String(task.get("target", "")):
		pursuit = {}
		pursuing = false
	task = (new_task as Dictionary).duplicate(true)
	var new_point: Variant = ElementTask.destination(task)
	if old_point is Vector3 and new_point is Vector3 and (old_point as Vector3).distance_to(new_point) > 1.0:
		anchor = null
		route = []
		route_index = 0
		transit = {}
		stations = {}
		shape_stations = {}
		shape_along = {}
		falling_in = []
	_log("task: %s" % ElementTask.describe(task))
	return ""


## Stop: the element holds where it stands.
func stand_down() -> void:
	_state_stamp += 1
	assign({"verb": "hold"})


## R2: whether this element owes the player a decision THIS tick (Elements runs it out of its cycle).
func preempting(game_match: Match) -> bool:
	return _preempt and team == OrderFeed.player_team(game_match)


## One decision cycle. Returns true when anything the HUD shows changed.
func update(game_match: Match, orders: Object) -> bool:
	_state_stamp += 1
	var before := _snapshot()
	changed_fields = PackedStringArray()
	var preempt := preempting(game_match)
	_preempt = false
	_prune(game_match)
	if preempt:
		_retake()
		preempted_tick = game_match.tick
	else:
		_adopt(orders)
	var commanded := _commanded_members()
	if commanded.is_empty():
		return _note_changes(before)
	var situation := ElementSituation.build(game_match, team, commanded, leader,
			{"heading": heading, "arrived": arrived, "known": _known})
	_known = situation["known"]
	situation["corridor_m"] = _corridor(game_match, situation)
	_advance_transit(game_match, situation)
	_track_pursuit(game_match)
	var state := {"task": task, "drill": drill, "drill_tick": drill_tick, "drill_point": drill_point,
			"drill_target": drill_target, "drill_why": reason, "anchor": anchor, "bounding": bounding,
			"arrived": arrived, "heading": heading, "seats": seats, "formation": formation, "flow_joined": flow_joined,
			"facing_sent": facing_sent, "transit": transit,
			"route": route, "route_index": route_index, "bound": bound, "bait_hide": bait_hide, "bait_back": bait_back,
			"reseat": _reseat, "unpin_leader": _unpinned, "issued_slots": slots, "issued_anchor": anchor,
			# His element (Drills.obeys_player: no elective drill under any task of his; round 20 M1b, round 21 P1).
			"player": team == OrderFeed.player_team(game_match),
			"pursuit": pursuit, "pursuing": pursuing, "attacking": _attacking(), "anchor_by_drill": anchor_by_drill,
			"ducks": ducks}
	var reseating := _reseat
	_reseat = false
	var plan := ElementPlan.build(situation, state, _doctrine())
	if reseating and plan.get("seats", {}) == seats:
		_reseat_useless = true
	Element.apply_swap(plan, _swap)
	var ground_node := game_match.tanks.get_child(0) as Node3D if game_match.tanks != null \
			and game_match.tanks.get_child_count() > 0 else null
	Element.ground(plan, ground_node, _envelopes(situation), situation["center"])
	if ElementPlan.PACE_ENABLED and plan.has("shape_along"):
		# Round 23 (B1): the pacing rules measure against each seat where the hull can actually stand (the brain drives
		# to its station grounded the same way); a seat laid inside a container would otherwise hold the anchor for
		# a crew that can never reach it (the yard's lanes).
		Element.ground_stations(plan["shape_along"], ground_node, _envelopes(situation))
	_take(plan, situation)
	var by_name := AiTickCache.tanks_by_name(game_match)
	# An ETA is a navmesh route per member (nav's Movement.eta), so it is refreshed once a second, or at once when the
	# slots change hands; the pace in between uses the latest one.
	if game_match.tick - _etas_tick >= ETA_REFRESH_TICKS or etas.size() != slots.size() \
			or not etas.has_all(slots.keys()):
		etas = FormUp.etas(by_name, slots)
		_etas_tick = game_match.tick
	# X3 (A9): ONE bottleneck, one pacing rule, every member including the leader (FormUp.paces). Round 7 had a
	# second rule here — `_pace_leader_for_flow`, which eased the leader off by how far the worst follower trailed
	# its follow offset — and two rules pacing the same vehicle by different arithmetic is what A9 replaces.
	paces = FormUp.paces(by_name, slots, etas)
	if pursuing:
		# Round 21 (P2): a chase is at road speed, every crew: co-arrival pacing slows the crew nearest its station,
		# which in a pursuit is the one in front.
		for unit_name: String in paces:
			paces[unit_name] = 1.0
	if not transit.is_empty():
		# Round 12: on a move that travels as a formation the ANCHOR is the pace (it drives at the slowest cruise and
		# waits for laggards), and a crew keeping station on a moving point must be free to close on it. After the
		# hand-off the crews are within TRANSIT_HANDOFF_M of their slots IN FILE, and restarting co-arrival pacing there
		# slowed the crew whose slot was nearest -- the one in FRONT -- under a faster crew behind it with a farther
		# slot, which deflected round it into a crate (default arena, squad-settle forward, seed 1: stopped 20.8 s
		# against 10.1). So no co-arrival pacing for the whole of a travelled move. TRIED AND REVERTED: one uniform pace
		# of 0.6 for everyone after the hand-off (the arrival speed round 10's co-arrival gave its wheeled crews) --
		# builder0, paired series, 4 seeds: default forward stopped median 16.6 -> 22.2 s, every cell slower. Under one
		# factor the faster hulls (IFVs, at the tail of a column) still close on the tanks ahead, and slowly.
		for unit_name: String in paces:
			paces[unit_name] = 1.0
		# Round 23 (B1): on the way (before the hand-off) each crew's pace comes from where it stands against the SHAPE's
		# own seat (ElementPlan.crew_paces: a crew ahead of its seat slows, never stops; behind or beside, 1.0). After
		# the hand-off every pace stays 1.0, as the two reverted attempts above found it must.
		if ElementPlan.PACE_ENABLED and ElementPlan.PACE_PART_OFF != "crew" and not pursuing and in_transit():
			var velocity: Vector2 = transit.get("velocity", Vector2.ZERO)
			var crew_paces := ElementPlan.crew_paces(situation.get("members", []), plan.get("shape_along", {}),
					TacticsFormation.flat(transit.get("heading", Vector3.FORWARD)), velocity.length(),
					maxf(float(transit.get("converge_m", 0.0)), ElementPlan.PACE_SPAN_MIN_M))
			for unit_name: String in crew_paces:
				paces[unit_name] = crew_paces[unit_name]
	bottleneck_ticks = FormUp.bottleneck_ticks(etas)
	_issue(plan, orders, situation, game_match, preempt)
	_watch_progress(game_match)
	return _note_changes(before)


## Round 21 (P2): the crews this element last sent to kill its task's target (`attack` on it): {unit: true}.
func _attacking() -> Dictionary:
	var target := String(task.get("target", ""))
	var found := {}
	if target == "":
		return found
	for unit_name: String in _issued:
		var mine: Dictionary = _issued[unit_name]
		if String(mine.get("verb", "")) == "attack" and String(mine.get("target", "")) == target:
			found[unit_name] = true
	return found


## Round 21 (P2): keep `pursuit`, the element's track of the target its attack names: refreshed from the team's intel
## whenever intel has a newer sighting, kept when intel forgets it, dropped when the target is dead or gone or the task
## names another. Reads the match (impure); ElementPlan reads the track as `state.pursuit`.
func _track_pursuit(game_match: Match) -> void:
	var target := String(task.get("target", ""))
	if String(task.get("verb", "")) != "attack" or target == "":
		pursuit = {}
		return
	var tank := AiTickCache.tanks_by_name(game_match).get(target) as Tank
	if tank == null or not tank.is_alive():
		pursuit = {}
		return
	if String(pursuit.get("name", "")) != target:
		pursuit = {}
	var known: Dictionary = (game_match.intel[team] as Dictionary).get(target, {})
	if not known.is_empty() and int(known.get("seen_tick", -1)) >= int(pursuit.get("seen_tick", -1)):
		var at: Vector3 = known["position"]
		var velocity: Vector3 = known.get("velocity", Vector3.ZERO)
		pursuit = {"name": target, "position": Vector3(at.x, 0.0, at.z), "velocity": Vector3(velocity.x, 0.0, velocity.z),
				"seen_tick": int(known["seen_tick"])}


## Round 18 (brains D5): a crew that keeps driving without closing on its slot is stuck behind something the seating
## put in its way (a squadmate parked in its own slot in a single-file lane, the Sumps' 14 m lanes: the pinned leader
## behind, holding the front seat). Ask for one fresh seating on the next update.
func _watch_progress(game_match: Match) -> void:
	if arrived or not ElementTask.runs_drills(task):
		_closest = {}
		_unpinned = false
		return
	var by_name := AiTickCache.tanks_by_name(game_match)
	for unit_name: String in slots:
		var tank := by_name.get(unit_name) as Tank
		var slot: Variant = slots[unit_name]
		if tank == null or not (slot is Vector3):
			continue
		var here := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		var flat_slot := Vector3((slot as Vector3).x, 0.0, (slot as Vector3).z)
		var gap := here.distance_to(flat_slot)
		var best: Array = _closest.get(unit_name, [INF, game_match.tick, flat_slot])
		# A new leg or a re-seat moves the slot: progress is measured toward the slot the crew has NOW.
		if (best[2] as Vector3).distance_to(flat_slot) > STUCK_GAIN_M:
			best = [INF, game_match.tick, flat_slot]
		if gap < float(best[0]) - STUCK_GAIN_M or gap <= STUCK_FAR_M or tank.estimated_velocity.length() < STUCK_MPS:
			_closest[unit_name] = [minf(gap, float(best[0])), game_match.tick, flat_slot]
		elif game_match.tick - int(best[1]) >= STUCK_TICKS and game_match.tick - _reseat_tick >= RESEAT_COOLDOWN_TICKS:
			if _reseats_this_move >= MAX_RESEATS:
				if _reseats_this_move == MAX_RESEATS:
					_log("re-seat: %s still not closing, but this movement has re-seated %d times: no more" % [unit_name, MAX_RESEATS])
					_reseats_this_move += 1
				return
			_reseats_this_move += 1
			_reseat_tick = game_match.tick
			_closest = {}
			# Make room only once a fresh seating has come back UNCHANGED this movement: until then the re-seat may still
			# help (round 18's 80 runs), and a swap taken early cost a mixed Sumps squad its last re-seat (seed 3).
			var blocker := _blocker_of(unit_name, by_name) if MAKE_ROOM_ENABLED and _reseat_useless else ""
			if blocker != "" and _swaps_this_move < MAX_SWAPS and seats.get(unit_name) is Array and seats.get(blocker) is Array:
				_swap = {unit_name: int(seats[unit_name][2]), blocker: int(seats[blocker][2])}
				swaps += 1
				_swaps_this_move += 1
				_reseats_this_move -= 1  # a swap has its own budget (MAX_SWAPS): it does not spend a re-seat
				_log("make room: %s has driven %d s without closing on its slot (%.0f m); %s, standing beside it, trades slots with it"
						% [unit_name, (game_match.tick - int(best[1])) / SimClock.TICK_RATE, gap, blocker])
				return
			_reseat = true
			_unpinned = true
			reseats += 1
			_log("re-seat: %s has driven %d s without closing on its slot (%.0f m)" % [unit_name,
					(game_match.tick - int(best[1])) / SimClock.TICK_RATE, gap])
			return


## Round 19 (B4): the stationary squadmate nearest `unit_name`, within MAKE_ROOM_M; "" if none. A new swap replaces the
## last one (the Cut, seed 3, corks twice with the same crew: the first swap's pair must be eligible again).
func _blocker_of(unit_name: String, by_name: Dictionary) -> String:
	var stuck := by_name.get(unit_name) as Tank
	if stuck == null:
		return ""
	var best := ""
	var best_d := MAKE_ROOM_M
	for other: String in slots:
		if other == unit_name:
			continue
		var tank := by_name.get(other) as Tank
		if tank == null or not tank.is_alive() or tank.estimated_velocity.length() >= STUCK_MPS:
			continue
		var d := Vector2(tank.global_position.x - stuck.global_position.x, tank.global_position.z - stuck.global_position.z).length()
		if d < best_d - 0.001 or (absf(d - best_d) <= 0.001 and other < best):
			best = other
			best_d = d
	return best


## Round 19 (B4): re-apply the make-room swap to this update's plan while the seating still gives the pair the seats
## they had when it was made (once the seating itself keeps them swapped, nothing to do).
static func apply_swap(plan: Dictionary, swap: Dictionary) -> void:
	if swap.size() != 2:
		return
	var names: Array = swap.keys()
	var a: String = names[0]
	var b: String = names[1]
	var seats_now: Dictionary = plan.get("seats", {})
	if not (seats_now.get(a) is Array and seats_now.get(b) is Array):
		return
	if int(seats_now[a][2]) != int(swap[a]) or int(seats_now[b][2]) != int(swap[b]):
		return
	for key: String in ["slots", "sectors", "seats", "orders"]:
		var table: Dictionary = plan.get(key, {})
		if table.has(a) and table.has(b):
			var held: Variant = table[a]
			table[a] = table[b]
			table[b] = held


## Round 24 (stretch, native's relay): what the brains' feed reads (ElementFeed.normalize), the same dictionary as
## state() but built once per element per physics frame instead of once per crew per think (native measured the feed's
## poll at 7.9 % of the brains' work at 50 v 50, bfc00f53, builder0). Rebuilt whenever the element changes: every
## mutator above bumps _state_stamp, and `revision` is in the key too. EQUAL ANSWER: the readers only read it.
var _state_stamp := 0
var _feed_key := Vector3i(-1, -1, -1)
var _feed_state := {}


## What the per-crew feed context depends on changes only inside a mutator (update, assign, retarget, stand_down,
## remove) or with `revision`: ElementFeed keeps each crew's context until this key moves.
func feed_key() -> Vector2i:
	return Vector2i(_state_stamp, revision)


func feed_state() -> Dictionary:
	var key := Vector3i(Engine.get_physics_frames(), _state_stamp, revision)
	if key != _feed_key:
		_feed_key = key
		_feed_state = _feed_view()
	return _feed_state


## The keys ElementFeed reads, with state()'s values and formats, and none of its copies or the readout the HUD alone
## uses (form_up_eta, bound, events, goal_moves, slots_asked ...). Measured (builder0, 50 v 50 with leaders, fa254a48):
## the feed's normalize was ~40 % of the brains' poll at ~44 us a call, and built from the whole state() each time.
## Shared with the feed's readers, which only read it (tests/test_tactics_feed_view.gd holds it equal to state()).
func _feed_view() -> Dictionary:
	return {"id": id, "leader": leader, "members": members(), "task": task, "formation": formation,
			"technique": technique, "drill": drill, "slots": slots, "sectors": sectors, "pace": paces,
			"pitch": [pitch.x, pitch.y], "heading": [heading.x, heading.z], "stations": stations,
			"transit": _transit_readout()}


## What the HUD reads (L1: read-only).
func state() -> Dictionary:
	return {"id": id, "name": element_name, "team": team, "leader": leader, "members": members(),
			"task": task.duplicate(true), "formation": formation, "technique": technique, "drill": drill,
			"reason": reason, "slots": slots.duplicate(), "slots_asked": slots_asked.duplicate(),
			"sectors": sectors.duplicate(), "pace": paces.duplicate(),
			"form_up_eta": form_up_eta(),
			# X1: the pitch the slots were laid at, across the heading and along it. A squad of 14 m rigs is spaced
			# by its hulls, not by its doctrine's number, and control's readout can say so.
			"pitch": [pitch.x, pitch.y], "facings_issued": _facings_issued,
			# X2 (A8): the corridor the element is deforming for, and how far toward single file it has gone.
			"corridor_m": corridor_m if is_finite(corridor_m) else null, "file": file,
			# X3 (A9): the bounding phase, so control can draw it and the announcer can call it. `stationary_share`
			# is the falsifier's own quantity: what fraction of the element is not moving this phase.
			# duplicate(), not duplicate(true): a PackedStringArray is a VALUE in GDScript (trip-up 48), so a shallow
			# copy already isolates the member lists, and this dictionary is read once per brain decision.
			"bound": bound.duplicate(), "bottleneck_ticks": bottleneck_ticks,
			# For nav: why this element's goals moved, and how many members have a goal that slides by design.
			"goal_moves": goal_moves.duplicate(), "following": following,
			# The element's intended facing and where its formation stands (round 6): the geometry control's facing
			# indicator and preview draw, rather than an illustration of it.
			"heading": [heading.x, heading.z], "anchor": [anchor.x, anchor.z] if anchor is Vector3 else null,
			"detached": _detached.keys(), "events": events,
			# B7: the player's order is COMPLETED at operational arrival (the centre in the destination zone); the crews
			# still dressing onto their slots after it are not the order running late. R2: the tick the last player
			# task was acted on (-1 never), so a readout can show the acknowledgement.
			"arrived": arrived, "preempted_tick": preempted_tick,
			# Round 12: the shape on the way. `stations` is where each crew should be NOW ({} unless in transit), and
			# `transit` the anchor they ride: where it is, which way the route runs there, how fast it is moving (m/s,
			# so a brain can lead it) and the lag rule's pace. The brains read these; nothing else does.
			"stations": stations.duplicate(), "transit": _transit_readout()}


## X2 (A8): the drivable width across the heading of the leg this element is driving, measured once per leg.
## Re-measured when the leg's ends move (a new task, a new destination, real progress), and never for an element
## that is not going anywhere — a halt deforms for nothing. INF when the navmesh cannot answer, which is the
## identity: a formation must not be worse than today for the lack of a number.
const CORRIDOR_MOVED_M := 12.0


func _corridor(game_match: Match, situation: Dictionary) -> float:
	var destination: Variant = ElementTask.destination(task)
	var from: Vector3 = situation["center"]
	if not (destination is Vector3):
		corridor_m = INF
		_corridor_from = null
		_corridor_to = null
		return corridor_m
	var to: Vector3 = destination
	var stale: bool = not (_corridor_from is Vector3) or not (_corridor_to is Vector3) \
			or (_corridor_from as Vector3).distance_to(from) > CORRIDOR_MOVED_M \
			or (_corridor_to as Vector3).distance_to(to) > CORRIDOR_MOVED_M
	if not stale:
		return corridor_m
	_corridor_from = from
	_corridor_to = to
	var ground := game_match.tanks.get_child(0) as Node3D if game_match.tanks != null \
			and game_match.tanks.get_child_count() > 0 else null
	corridor_m = SlotGround.corridor_width(ground, from, to, TacticsFormation.flat(to - from))
	return corridor_m


## X3: seconds until the element is formed up — until its slowest member reaches its slot (the lead's estimate).
func form_up_eta() -> float:
	return FormUp.group_eta(etas)


# ---- Round 12: the travelling anchor (ElementPlan's TRANSIT block has the argument) ----------------------------------

## Whether the element is on its way as a formation: a plain move whose anchor has not reached the click yet.
func in_transit() -> bool:
	return not transit.is_empty() and not bool(transit.get("arrived", true))


## Create the anchor on the first update of a plain move (the ONE impure step: the navmesh route from the squad's centre
## to the click, like `_corridor`), then advance it every update by the slowest member's cruise times the lag rule.
## Deterministic: the route is the navmesh's, dt is a tick count, the pace reads member positions from the situation.
## Round 19 (brains B5, C19.1): where a travelled move starts. The element's centre only when its crews stand within
## one formation width of each other (the line's frontage at `spacing`, the widest shape); otherwise the LEAD vehicle's
## position. Two squads on opposite flanks have their centroid on the centre line, and a transit started there sent
## every crew to the middle of the map first (his two-squad click, 2026-10-05). Orders now sends one order per squad;
## this keeps any element that is spread out (a partial selection, a squad scattered by a fight) from doing the same.
static func transit_origin(situation: Dictionary, spacing: float) -> Vector3:
	var center: Vector3 = situation["center"]
	var members: Array = situation.get("members", [])
	if members.size() < 2:
		return center
	var spread := 0.0
	for member: Dictionary in members:
		spread = maxf(spread, 2.0 * Vector2((member["position"] as Vector3).x - center.x,
				(member["position"] as Vector3).z - center.z).length())
	if spread <= TacticsFormation.frontage("line", members.size(), spacing):
		return center
	var leader := String(situation.get("leader", ""))
	for member: Dictionary in members:
		if String(member["name"]) == leader:
			return member["position"]
	return (members[0] as Dictionary)["position"]


func _advance_transit(game_match: Match, situation: Dictionary) -> void:
	var destination: Variant = ElementTask.destination(task)
	if not ElementPlan.TRANSIT_ENABLED or ElementTask.runs_drills(task) or String(task.get("verb", "")) != "move" \
			or not (destination is Vector3):
		transit = {}
		return
	var tick := int(situation["tick"])
	if transit.is_empty():
		if _transit_declined_seq == task_seq:
			return  # decided once per task: a short move never grows an anchor later
		var center: Vector3 = transit_origin(situation, _doctrine().spacing("open"))
		var to := Vector3((destination as Vector3).x, 0.0, (destination as Vector3).z)
		var from := Vector3(center.x, 0.0, center.z)
		if from.distance_to(to) < ElementPlan.TRANSIT_MIN_M:
			_transit_declined_seq = task_seq
			return  # a short reposition: everyone drives straight to its slot (round 10's measured path)
		var found: Array = [from, to]
		var ground := game_match.tanks.get_child(0) as Node3D if game_match.tanks != null \
				and game_match.tanks.get_child_count() > 0 else null
		if ground != null:
			found = _route_with_body(game_match, ground, from, to)
		if found.size() < 2:
			found = [from, to]
		var slowest := INF
		for member: Dictionary in situation.get("members", []):
			slowest = minf(slowest, maxf(float(member.get("speed", 9.0)), 0.5))
		var last := found[found.size() - 1] as Vector3
		var before_last := found[found.size() - 2] as Vector3
		var final_heading := TacticsFormation.flat(last - before_last) if last.distance_to(before_last) > 0.05 \
				else TacticsFormation.flat(to - from)
		# The anchor starts AHEAD of the squad's centre by half the shape's depth (ElementPlan.transit_start_m), so at the
		# moment of the order every station is in front of every crew and the squad moves off the way a column does:
		# the head first, each crew falling in behind. Started ON the centre, half the crews were ahead of their
		# stations (waiting) and the middle pair converging onto the line from either side met head-on and yielded to
		# each other for 8 s while the anchor idled at its floor pace (yard, forward from the spawn, seed 1).
		# The plan has not run for this task yet, so the shape is the one it WILL pick: his G choice, else the table's.
		var shape := String(task.get("formation", UnitCommand.AUTO))
		if shape == UnitCommand.AUTO or not TacticsFormation.NAMES.has(shape):
			shape = String(_doctrine().select({"task": "move", "threat": String(situation["threat"]),
					"terrain": String(situation["terrain"]), "composition": String(situation["composition"])})["formation"])
		var half_depth := ElementPlan.transit_start_m(shape, situation.get("members", []),
				_doctrine().spacing(String(situation["terrain"])))
		var start := minf(half_depth, maxf(ElementPlan.route_length(found) - ElementPlan.TRANSIT_HANDOFF_M, 0.0))
		var first := ElementPlan.route_pose(found, start)
		# Round 20 (M1): where each crew stands now, in the route's frame: its station starts there (ElementPlan.converge).
		var starts := ElementPlan.transit_starts(situation.get("members", []), found, start, 2.0 * half_depth)
		transit = {"route": found, "length": ElementPlan.route_length(found), "s": start, "start_s": start, "tick": tick,
				"start_tick": tick, "speed": (slowest if is_finite(slowest) else 9.0) * ElementPlan.TRANSIT_CRUISE,
				"pace": 1.0, "anchor": first["point"], "heading": first["tangent"],
				"velocity": Vector2.ZERO, "final_heading": final_heading, "arrived": false,
				"starts": starts["starts"], "converge_m": starts["converge_m"]}
		_log("moving off in formation, %.0f m" % float(transit["length"]))
		return
	if bool(transit.get("arrived", false)):
		return
	var dt := float(tick - int(transit["tick"])) / float(SimClock.TICK_RATE)
	transit["tick"] = tick
	var pace := _transit_pace(situation)
	if ElementPlan.PACE_ENABLED and ElementPlan.PACE_PART_OFF != "anchor":
		# Round 23 (B1): the anchor paces to the slowest-to-seat crew (ElementPlan.form_pace, against last update's
		# shape stations, 0.1 s old like the lag rule's), never faster than the lag rule allows.
		pace = minf(pace, ElementPlan.form_pace(situation.get("members", []), shape_along,
				TacticsFormation.flat(transit.get("heading", Vector3.FORWARD)), float(transit["speed"]),
				maxf(float(transit.get("converge_m", 0.0)), ElementPlan.PACE_SPAN_MIN_M)))
	var speed := ElementPlan.transit_speed(float(transit["speed"]), pace,
			float(transit["length"]) - float(transit["s"]))
	var s := float(transit["s"]) + speed * dt
	if s >= float(transit["length"]) - ElementPlan.TRANSIT_HANDOFF_M:
		# Hand over short of the click (TRANSIT_HANDOFF_M): the stations stop here and every crew's standing move to its
		# final slot does the last metres as an approach.
		s = minf(s, float(transit["length"]))
		transit["arrived"] = true
		speed = 0.0
		_log("formation closing on the spot")
	var pose := ElementPlan.route_pose(transit["route"], s)
	var tangent: Vector3 = pose["tangent"]
	transit["s"] = s
	transit["pace"] = pace
	transit["anchor"] = pose["point"]
	transit["heading"] = tangent
	transit["velocity"] = Vector2(tangent.x, tangent.z) * speed


## The lag rule: full pace until a crew is TRANSIT_LAG_SLACK_M behind its station along the route, then down to
## TRANSIT_MIN_PACE over TRANSIT_LAG_FALLOFF_M more. Only lag ALONG the heading counts: a crew off to the side closes by
## cutting across, and counting it made a freshly ordered squad crawl (Squad._commander_pace, the CPU's rule since
## round 3). Stations are last update's, 0.1 s old.
## Round 24 (brains R2, C24.5): his "I had a lot of units selected, I moved them all to the west side of the map, and
## one squad took a whole different route and basically arbitrarily detached from the rest of the force ... there
## should be a cost associated with a vehicle or vehicles detaching from the safety of the rest of their army".
## A squad ordered together with others (same team, same frame, same verb: see task_frame) weighs two routes: its own
## shortest, and "with the body": join the body's route (the army's centre to the army's destination centre), drive
## it, and leave it where it passes nearest this squad's own spot. Each costs its length plus BODY_DETACH_WEIGHT for
## every metre driven farther than BODY_CORRIDOR_M from the body's route; the cheaper wins. A cost, not a ban: a split
## that really saves driving (a second bridge that is much shorter) still wins, and is logged as such.
## Both sides: any plain move given to several elements on one frame, his or a CPU commander's, gets the same weighing.
## NOT on a task that runs drills (the CPU's grouped attack-moves): measured (builder0, R2 series cpu-green/cpu-rust,
## seeds 1-3) those already keep together (13.5-15 squad-seconds alone without it, against 50-84 on his plain move),
## and offering the body's route to their leg-by-leg anchor made it worse (21-104 s alone, one seed never arrived).
static var BODY_ENABLED := true
## A metre out of the body's corridor costs this many metres of driving (2: a squad accepts a detour up to twice the
## length it would have spent alone).
const BODY_DETACH_WEIGHT := 2.0
## The body's corridor: within this of its route a squad is with the army (a squad's frontage plus a neighbour's).
const BODY_CORRIDOR_M := 25.0
## The detached metres are measured every this many metres along a route.
const BODY_SAMPLE_M := 4.0
## The last choice (for the probe and the log): {"own_m", "own_alone_m", "body_m", "body_alone_m", "chosen"}.
var body_choice := {}
## Per (team, frame): the body's route, computed once for every squad of the order.
static var _body_memo := {}


func _route_with_body(game_match: Match, ground: Node3D, from: Vector3, to: Vector3) -> Array:
	var own := Element._flat_path(Pathing.find_path(ground, from, to))
	body_choice = {}
	if not BODY_ENABLED or own.size() < 2:
		return own
	var body := _body_route(game_match, ground, from, to)
	if body.size() < 2:
		return own
	var join := Element._closest_along(body, from)
	var leave := Element._closest_along(body, to)
	if float(leave["s"]) - float(join["s"]) < BODY_CORRIDOR_M:
		return own  # the body's route has nothing to offer between where I join it and where I leave it
	var along := Element._flat_path(Pathing.find_path(ground, from, join["point"]))
	along.pop_back()
	along.append_array(Element._slice(body, float(join["s"]), float(leave["s"])))
	var tail := Element._flat_path(Pathing.find_path(ground, leave["point"], to))
	if not tail.is_empty():
		tail.pop_front()
		along.append_array(tail)
	var own_m := ElementPlan.route_length(own)
	var with_m := ElementPlan.route_length(along)
	var own_alone := Element._detached_m(own, body)
	var with_alone := Element._detached_m(along, body)
	var with_body := with_m + BODY_DETACH_WEIGHT * with_alone < own_m + BODY_DETACH_WEIGHT * own_alone - 1.0
	body_choice = {"own_m": snappedf(own_m, 0.1), "own_alone_m": snappedf(own_alone, 0.1), "body_m": snappedf(with_m, 0.1),
			"body_alone_m": snappedf(with_alone, 0.1), "chosen": "body" if with_body else "own"}
	if own_alone > BODY_CORRIDOR_M:
		_log("route: %s (own %.0f m, %.0f m away from the army; with the army %.0f m, %.0f m away)" % [
				"with the army" if with_body else "its own way: it saves enough", own_m, own_alone, with_m, with_alone])
	return along if with_body else own


## The body's route for this element's order, or [] when it was ordered alone.
func _body_route(game_match: Match, ground: Node3D, from: Vector3, to: Vector3) -> Array:
	var elements := Elements.of_match(game_match)
	if elements == null or task_frame < 0:
		return []
	var key := Vector3i(team, task_frame, 0)
	if _body_memo.has(key):
		return _body_memo[key]
	var froms: Array = [from]
	var tos: Array = [to]
	for other: Element in elements.of_team(team):
		if other == self or other.task_frame != task_frame or String(other.task.get("verb", "")) != String(task.get("verb", "")):
			continue
		var destination: Variant = ElementTask.destination(other.task)
		var centre: Variant = other._centre(game_match)
		if destination is Vector3 and centre is Vector3:
			froms.append(centre)
			tos.append(destination)
	var body: Array = []
	if froms.size() >= 2:
		body = Element._flat_path(Pathing.find_path(ground, Element._mean(froms), Element._mean(tos)))
	if _body_memo.size() > 64:
		_body_memo.clear()
	_body_memo[key] = body
	return body


func _centre(game_match: Match) -> Variant:
	var points: Array = []
	for unit_name: String in members():
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			points.append(Vector3(tank.global_position.x, 0.0, tank.global_position.z))
	return Element._mean(points) if not points.is_empty() else null


static func _mean(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for point: Vector3 in points:
		sum += point
	return sum / float(maxi(points.size(), 1))


## A navmesh path flattened, with Godot's repeated corners dropped (a zero-length leg has no tangent to steer by).
static func _flat_path(points: PackedVector3Array) -> Array:
	var found: Array = []
	for point: Vector3 in points:
		var flat := Vector3(point.x, 0.0, point.z)
		if found.is_empty() or (found[found.size() - 1] as Vector3).distance_to(flat) > 0.05:
			found.append(flat)
	return found


## The point of `route` nearest `point`: {"point", "s" (metres along the route)}.
static func _closest_along(route: Array, point: Vector3) -> Dictionary:
	var best := {"point": route[0], "s": 0.0}
	var best_d := INF
	var s := 0.0
	for i in range(1, route.size()):
		var a: Vector3 = route[i - 1]
		var b: Vector3 = route[i]
		var leg := a.distance_to(b)
		var t := clampf((point - a).dot(b - a) / maxf(leg * leg, 1e-6), 0.0, 1.0)
		var at := a.lerp(b, t)
		var d := at.distance_to(point)
		if d < best_d:
			best_d = d
			best = {"point": at, "s": s + leg * t}
		s += leg
	return best


## `route` from `s0` to `s1` metres along it, as points (both ends included).
static func _slice(route: Array, s0: float, s1: float) -> Array:
	var out: Array = [ElementPlan.route_pose(route, s0)["point"]]
	var s := 0.0
	for i in range(1, route.size()):
		s += (route[i - 1] as Vector3).distance_to(route[i])
		if s > s0 and s < s1:
			out.append(route[i])
	out.append(ElementPlan.route_pose(route, s1)["point"])
	return out


## Metres of `path` farther than BODY_CORRIDOR_M from the body's route.
static func _detached_m(path: Array, body: Array) -> float:
	var alone := 0.0
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var leg := a.distance_to(b)
		var steps := maxi(1, ceili(leg / BODY_SAMPLE_M))
		for k in steps:
			var at := a.lerp(b, (k + 0.5) / float(steps))
			if (Element._closest_along(body, at)["point"] as Vector3).distance_to(at) > BODY_CORRIDOR_M:
				alone += leg / float(steps)
	return alone


func _transit_pace(situation: Dictionary) -> float:
	var heading: Vector3 = TacticsFormation.flat(transit.get("heading", Vector3.FORWARD))
	var worst := 0.0
	for member: Dictionary in situation.get("members", []):
		# S3: a crew the fall-in rule is standing still on purpose is not a laggard to wait for (last update's list).
		if ElementPlan.FALLIN_MODE == "wait" and falling_in.has(String(member["name"])):
			continue
		var station: Variant = shape_stations.get(String(member["name"]), stations.get(String(member["name"])))
		if not (station is Vector3):
			continue
		var behind := ((station as Vector3) - (member["position"] as Vector3)).dot(heading)
		worst = maxf(worst, behind)
	return clampf(1.0 - (worst - ElementPlan.TRANSIT_LAG_SLACK_M) / ElementPlan.TRANSIT_LAG_FALLOFF_M,
			ElementPlan.TRANSIT_MIN_PACE, 1.0)


## `state()`'s transit entry: {} when not in transit, else the anchor's pose and motion as plain numbers.
func _transit_readout() -> Dictionary:
	if not in_transit():
		return {}
	var at: Vector3 = transit["anchor"]
	var heading: Vector3 = transit["heading"]
	var velocity: Vector2 = transit["velocity"]
	return {"anchor": [at.x, at.z], "heading": [heading.x, heading.z], "velocity": [velocity.x, velocity.y],
			"pace": float(transit.get("pace", 1.0)), "s": float(transit.get("s", 0.0)),
			"length": float(transit.get("length", 0.0))}


## N2 for TacticsFormation.slots(element, ...): this element as formation data (members where they were last update).
func formation_group() -> Dictionary:
	# `spacing` is the DOCTRINE's tactical number; TacticsFormation.place floors it by the members' hulls (X1), so a
	# caller that re-lays this shape gets the same slots the element issued.
	return {"formation": formation, "leader": leader, "policy": "exposure", "spacing": _doctrine().spacing("open"),
			"members": _last_members.duplicate(), "previous": _seating_now()}


func _seating_now() -> Dictionary:
	var result := {}
	for unit_name: String in seats:
		result[unit_name] = int(seats[unit_name][2])
	return result


## Living members, in succession order.
func members() -> PackedStringArray:
	return roster


func has(unit_name: String) -> bool:
	return roster.has(unit_name)


## What this element last issued `unit_name` ({"id", "verb", "tick", "to", "target", ...}; {} when nothing).
func issued_to(unit_name: String) -> Dictionary:
	return (_issued.get(unit_name, {}) as Dictionary).duplicate()


func is_detached(unit_name: String) -> bool:
	return _detached.has(unit_name)


func remove(unit_name: String) -> void:
	_state_stamp += 1
	var index := roster.find(unit_name)
	if index >= 0:
		roster.remove_at(index)
	_issued.erase(unit_name)
	_detached.erase(unit_name)
	slots.erase(unit_name)
	sectors.erase(unit_name)
	seats.erase(unit_name)
	stations.erase(unit_name)
	etas.erase(unit_name)
	paces.erase(unit_name)
	if leader == unit_name:
		leader = roster[0] if not roster.is_empty() else ""
		if leader != "":
			_log("%s takes over" % leader)
		revision += 1
	if index >= 0:
		member_removed.emit(unit_name)


## One line a spectator could read: "Alpha: wedge, bounding overwatch — contact likely in the open".
func describe() -> String:
	var words := "%s: %s" % [element_name, formation.replace("_", " ")]
	if drill != "":
		words += ", %s" % drill.replace("_", " ")
	else:
		words += ", %s" % technique.replace("_", " ")
	return "%s — %s" % [words, reason] if reason != "" else words


# ---- Internals -----------------------------------------------------------------------------------------

func _doctrine() -> DoctrineTable:
	if table == null:
		table = DoctrineTable.for_faction("")
	return table


## Drop the dead; the senior survivor takes over.
func _prune(game_match: Match) -> void:
	for unit_name in Array(roster):
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank if game_match.tanks != null else null
		if tank == null or not tank.is_alive():
			var was_leader: bool = leader == unit_name
			remove(unit_name)
			if was_leader and leader != "":
				_log("%s down" % unit_name)
	if leader == "" and not roster.is_empty():
		leader = roster[0]


## A vehicle whose current order isn't the one we gave it is under someone else's command (the player).
func _adopt(orders: Object) -> void:
	if orders == null:
		return
	for unit_name in roster:
		var current: Dictionary = orders.call("current", unit_name)
		if current.is_empty():
			if _detached.erase(unit_name):
				_log("%s back under command" % unit_name)
				revision += 1
			continue
		var mine: Dictionary = _issued.get(unit_name, {})
		if mine.is_empty() or int(current.get("id", -1)) != int(mine.get("id", -2)):
			if not _detached.has(unit_name):
				_detached[unit_name] = true
				_log("%s taken by its commander" % unit_name)
				revision += 1


## R2: a new player task takes back every crew the player had sent off on its own.
func _retake() -> void:
	for unit_name: String in _detached.keys():
		_detached.erase(unit_name)
		_log("%s back under command: new task" % unit_name)
		revision += 1


func _commanded_members() -> PackedStringArray:
	var result: PackedStringArray = []
	for unit_name in roster:
		if not _detached.has(unit_name):
			result.append(unit_name)
	return result


## X2: every slot and every order's destination moved onto ground a vehicle can stand on (SlotGround). The plan is
## pure geometry; this is the step that meets the arena. `node` is any node in the match's world (null: unchanged).
## Each member's turning envelope ({unit: metres}), for grounding its slot with the hull's own clearance.
static func _envelopes(situation: Dictionary) -> Dictionary:
	var result := {}
	for member: Dictionary in situation.get("members", []):
		result[String(member["name"])] = SlotGround.envelope_of(String(member.get("unit", "")))
	return result


## `from` (round 21, stretch d): where the element is, so a slot pushed out of an obstacle lands on the side it is
## reached from (SlotGround.standable_from), not the far side.
static func ground(plan: Dictionary, node: Node3D, envelopes: Dictionary = {}, from: Variant = null) -> void:
	if node == null:
		return
	var slots_in: Dictionary = plan["slots"]
	# Round 9, for nav: keep the slot the FORMATION asked for beside the one the navmesh allowed. nav measured 70% of
	# its arrival-arc refusals as `off_mesh` and cannot tell two different bugs apart without this — a gate behind a
	# slot that was always inside geometry, versus one behind a slot this push MOVED, where the gate is then computed
	# one approach-length back along the ordered heading into whatever the slot was pushed out of.
	var asked := {}
	# Round 24 (brains R1, his bridge): a slot stands on its ANCHOR's side of any water, never the other one. The
	# nearest-point grounding below answers a slot in a canal with the nearer bank, the side rule (round 21) then steps
	# it back to the bank the element is coming FROM, and a wedge whose anchor has just crossed lays its rear seats on
	# the bank behind: a squad ordered across the Locks had crews sent to the near quay while their shape stood on the
	# far one (SlotGround.on_anchor_side; an order's goal in the water: SlotGround.pulled_dry).
	var anchor: Variant = plan.get("anchor")
	for unit_name: String in slots_in:
		var wanted: Vector3 = slots_in[unit_name]
		var asked_for := wanted
		if anchor is Vector3:
			wanted = SlotGround.on_anchor_side(wanted, anchor)
		var allowed := SlotGround.standable_from(node, wanted, float(envelopes.get(unit_name, 0.0)), from)
		if allowed != asked_for:
			asked[unit_name] = asked_for
		slots_in[unit_name] = allowed
	plan["slots_asked"] = asked
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		if order["to"] is Vector3:
			var to: Vector3 = SlotGround.pulled_dry(order["to"], anchor) if anchor is Vector3 else order["to"]
			order["to"] = SlotGround.standable_from(node, to, float(envelopes.get(unit_name, 0.0)), from)


## Round 23 (B1): `stations` ({unit: Vector3}) moved in place to where each hull can stand (SlotGround.standable_for,
## the brain's own grounding of a station). Pure but for the navmesh query.
static func ground_stations(stations: Dictionary, node: Node3D, envelopes: Dictionary) -> void:
	if node == null:
		return
	for unit_name: String in stations:
		stations[unit_name] = SlotGround.standable_for(node, stations[unit_name], float(envelopes.get(unit_name, 0.0)))


## Record what the leader decided.
func _take(plan: Dictionary, situation: Dictionary) -> void:
	formation = String(plan["formation"])
	technique = String(plan["technique"])
	reason = String(plan["why"])
	anchor = plan["anchor"]
	heading = plan["heading"]
	bounding = int(plan["bounding"])
	arrived = bool(plan["arrived"])
	slots = plan["slots"]
	sectors = plan["sectors"]
	seats = plan["seats"]
	pitch = plan.get("pitch", pitch)
	slots_asked = plan.get("slots_asked", {})
	file = float(plan.get("file", 0.0))
	bound = plan.get("bound", {})
	flow_joined = bool(plan.get("flow_joined", false))
	facing_sent = bool(plan.get("facing_sent", false))
	route = plan["route"]
	route_index = int(plan["route_index"])
	stations = plan.get("stations", {})
	falling_in = plan.get("falling_in", [])
	shape_stations = plan.get("shape_stations", stations)
	shape_along = plan.get("shape_along", {})
	strength = (situation["members"] as Array).size()
	_last_members = situation["members"]
	bait_hide = plan.get("bait_hide")
	bait_back = bool(plan.get("bait_back", false))
	pursuing = bool(plan.get("pursuing", false))
	anchor_by_drill = bool(plan.get("anchor_by_drill", false))
	ducks = plan.get("ducks", {})
	var new_drill := String(plan["drill"])
	if new_drill != drill:
		drill = new_drill
		drill_tick = int(situation["tick"])
		drill_point = null
		drill_distance = 0.0
		if drill != "":
			drill_point = _drill_focus(plan, situation)
			var contact := Drills.nearest_contact(situation)
			drill_target = String(contact.get("name", ""))
			drill_distance = float(contact.get("distance", 0.0))
			_log("drill: %s" % drill.replace("_", " "))
		revision += 1


static func _drill_focus(plan: Dictionary, situation: Dictionary) -> Variant:
	var contact := Drills.nearest_contact(situation)
	if not contact.is_empty():
		return contact["position"]
	return plan.get("anchor")


## Turn the plan into K1 commands, issuing only what actually changed — or, on the first update after a player task
## (`force`, R2), issuing every crew its order from the new plan whatever it was doing.
func _issue(plan: Dictionary, orders: Object, situation: Dictionary, game_match: Match = null, force := false) -> void:
	if orders == null:
		return
	var positions := {}
	for member: Dictionary in situation["members"]:
		positions[String(member["name"])] = member["position"]
	var names: Array = (plan["orders"] as Dictionary).keys()
	names.sort()
	var player_team := OrderFeed.player_team(game_match)
	following = 0
	for unit_name: String in plan["orders"]:
		if String((plan["orders"][unit_name] as Dictionary).get("verb", "")) == "follow":
			following += 1
	for unit_name: String in names:
		if _detached.has(unit_name):
			continue
		var desired: Dictionary = plan["orders"][unit_name]
		var current: Dictionary = orders.call("current", unit_name)
		var skip := false
		# The player's authority is absolute (the lead, 2026-09-17: *"if they get sucked into combat I have no control
		# whatsoever"*). A unit carrying an order the PLAYER gave is not taken off it by its leader, and on the player's
		# own team a leader that has been given no task commands nobody at all — an untasked element running its SOP
		# over the player's army is the oldest version of this bug (L1's sharp edge, round 4).
		# A player TASK is that authority too, and the newest word wins (R2): on its first update none of the three
		# checks below may keep a crew on what it was doing — not an older direct order, not the re-issue suppression
		# (whose REISSUE_M and same-intention tests compare PLACES, so a re-drag near the old spot was swallowed whole).
		if String(current.get("source", "")) == "player":
			skip = true
		elif team == player_team and task.is_empty():
			skip = true
		elif not _should_issue(unit_name, desired, current, positions.get(unit_name, Vector3.ZERO), int(situation["tick"])):
			skip = true
		if skip and not force:
			continue
		var mine_before: Dictionary = (_issued.get(unit_name, {}) as Dictionary).duplicate()
		# K1's `source`: the player's own orders are the ones the response guarantee is about, and the only ones render
		# confirms with a marker and a cue. An element's are its own.
		var command := {"units": [unit_name], "verb": String(desired["verb"]), "source": "element"}
		if desired["to"] is Vector3:
			var point: Vector3 = desired["to"]
			command["to"] = [point.x, point.z]
		if String(desired.get("target", "")) != "":
			command["target"] = desired["target"]
		if desired.has("slot"):
			command["slot"] = desired["slot"]  # K1 follow-with-slot: this member's place relative to its leader
		if desired.get("facing") is Vector3:
			# X5: the heading this crew is to end up on (a halt's sector, a firing line's, a cover position's). K1 has
			# carried `facing` since round 5 and TankBrain.intended_facing() reads it; until round 9 an element's own
			# orders never set one, so nav's arrival arc counted `aimed 0 / refused 0` in every CPU fight.
			var look: Vector3 = desired["facing"]
			command["facing"] = [look.x, look.z]
			_facings_issued += 1
		if team == player_team and _ORDERS_TAKE_TASK:
			command["task"] = task_seq
		if command["verb"] == "attack" and not command.has("target"):
			command["verb"] = "hold"
			command.erase("to")
		var error: String = orders.call("issue", command, team)
		if error != "":
			# A target that just died, or a unit that did: try again next update with fresh facts.
			continue
		_count_goal_move(unit_name, desired, mine_before)
		var issued: Dictionary = orders.call("current", unit_name)
		_issued[unit_name] = {"id": int(issued.get("id", -1)), "verb": command["verb"], "tick": int(situation["tick"]),
				"to": desired["to"], "target": String(desired.get("target", "")),
				"anchor": anchor, "seat": _seat_index(unit_name), "task": task_seq}


## Attribute a re-issued goal to the thing that moved it (see `goal_moves`). `before` is what this element had issued
## to the unit previously ({} the first time, which is not a MOVE of a goal and is not counted).
func _count_goal_move(unit_name: String, desired: Dictionary, before: Dictionary) -> void:
	if before.is_empty() or not (before.get("to") is Vector3) or not (desired.get("to") is Vector3):
		return
	if (before["to"] as Vector3).distance_to(desired["to"]) <= 1.0:
		return  # nav's own threshold: under a metre is not a goal that moved
	var key := "drift"
	if _fresh_task:
		key = "task"
	elif not _same_anchor(before.get("anchor"), anchor):
		key = "leg"
	elif int(before.get("seat", -1)) != _seat_index(unit_name):
		key = "reseat"
	goal_moves[key] = int(goal_moves[key]) + 1


## R2's adapter: control's Orders accepts a `task` key on a command (its `_same_order` then keys on it). Until it
## does the key is not sent, because UnitCommand rejects unknown keys and the order would be refused outright.
static var _ORDERS_TAKE_TASK: bool = UnitCommand.KEYS.has("task")


static func _same_anchor(a: Variant, b: Variant) -> bool:
	if a is Vector3 and b is Vector3:
		return (a as Vector3).distance_to(b) <= 1.0
	return a == null and b == null


func _seat_index(unit_name: String) -> int:
	var seat: Variant = seats.get(unit_name)
	return int(seat[2]) if seat is Array and (seat as Array).size() > 2 else -1


func _should_issue(unit_name: String, desired: Dictionary, current: Dictionary, position: Vector3, tick: int) -> bool:
	var mine: Dictionary = _issued.get(unit_name, {})
	if current.is_empty():
		# Idle, having just finished what we gave it. The trap (round 5): a fight order's destination is a MOVING enemy,
		# so "there is somewhere else to be" is true on every update, and the leader re-gave the same intention five
		# times a second for as long as the fight lasted. A standing attack already follows its target, so the same
		# intention is not re-issued until RE_ISSUE_TICKS have passed or something real changes.
		var again: bool = not mine.is_empty() and String(mine.get("verb", "")) == String(desired["verb"]) \
				and String(mine.get("target", "")) == String(desired.get("target", ""))
		if again and tick - int(mine.get("tick", -RE_ISSUE_TICKS)) < RE_ISSUE_TICKS and _same_place(mine, desired, REISSUE_M):
			return false
		# It finished our order to THIS place and stopped short (a brain completes a stalled move up to 12 m out): it got
		# as close as it could. Sending it again every RE_ISSUE_TICKS is the idle-window thrash control measured (31-38
		# orders with nobody touching the controls, five squads crowded at the spawn). Getting it the rest of the way is
		# navigation's job (N1: arrive or report blocked), not a re-order's.
		if again and String(desired["verb"]) in ["move", "hold"] and _same_place(mine, desired, REISSUE_M):
			return false
		if desired["to"] is Vector3 and position.distance_to(desired["to"]) > SETTLED_M:
			return true
		# Arrived on a firing or screen line: the move is done, and the crew now HOLDS the spot (fires from it, and
		# drives back onto it if pushed). Left idle instead, a brain wanders its idle leash and the line dissolves.
		if String(desired["verb"]) == "hold" and desired["to"] is Vector3 and String(mine.get("verb", "")) != "hold":
			return true
		if String(desired["verb"]) in ["attack", "attack_move"] and String(desired.get("target", "")) != "":
			return String(mine.get("target", "")) != String(desired["target"]) \
					or tick - int(mine.get("tick", -RE_ISSUE_TICKS)) >= RE_ISSUE_TICKS
		# A crew that finished our move and went idle, now wanted on a `follow` (the new task's flow): a different
		# intention with no place to compare, so none of the checks above can issue it. control measured it on Terminus
		# (repath-test "arrived"): crews 3/4/6/8 idle through tick +8 while the leader drove off on the new task.
		if not mine.is_empty() and String(desired["verb"]) == "follow" and String(mine.get("verb", "")) != "follow":
			return true
		return mine.is_empty() and String(desired["verb"]) != "hold"
	if mine.is_empty() or int(current.get("id", -1)) != int(mine.get("id", -2)):
		return false  # not ours to change
	# Round 5 (the lead's playtest): a leader re-issues only when the INTENTION changed. Two verbs that mean "fight that
	# one" (attack, attack_move) are the same intention while the target is the same, and "go there" and "stay there"
	# are the same intention while the place is the same. Without this the plan's verb flapped between them every
	# update, and every flap was a new order id: a marker drawn and a cue played on the player's screen, ~35 a second
	# across an army, which is what he saw as blue dots repeating and heard as beeping.
	# A HOLD carrying a facing (the heading the player drew, held on arrival: d29115ae) replaces a MOVE of ours at once,
	# not when the move completes: it is a standing order the move cannot express. Round 10, after the pitch: two
	# wheeled crews circling their (wider) slots never completed the move and sat on it 15 s after arrival, never told
	# the heading (test_a_dragged_heading_turns_every_crew_once_the_element_arrives). One-way: a later `move` to the same
	# place is still "the same intention" below, so a centre wobbling across ARRIVE_M cannot flap it back.
	if String(desired["verb"]) == "hold" and desired.get("facing") is Vector3 and String(mine.get("verb", "")) == "move":
		return true
	var same_target := String(mine.get("target", "")) == String(desired.get("target", ""))
	var fight := ["attack", "attack_move"]
	var stay := ["move", "hold"]
	var same_intention: bool = String(mine["verb"]) == String(desired["verb"]) \
			or (fight.has(String(mine["verb"])) and fight.has(String(desired["verb"])) and same_target) \
			or (stay.has(String(mine["verb"])) and stay.has(String(desired["verb"])) and _same_place(mine, desired, SETTLED_M))
	if not same_intention or not same_target:
		return true
	if desired["to"] is Vector3 and mine["to"] is Vector3:
		return not _same_place(mine, desired, REISSUE_M)
	return desired["to"] is Vector3 != mine["to"] is Vector3


## Whether two orders point at the same place, within `slack` metres (a destination either may not have).
static func _same_place(mine: Dictionary, desired: Dictionary, slack: float) -> bool:
	if not (desired["to"] is Vector3 and mine["to"] is Vector3):
		return desired["to"] is Vector3 == mine["to"] is Vector3
	return (mine["to"] as Vector3).distance_to(desired["to"]) <= slack


## Everything the HUD shows: cheap change detection for element_changed, and the list of what moved, which
## the announcer uses to decide whether a decision is worth calling (Elements.element_reported).
func _snapshot() -> Dictionary:
	return {"formation": formation, "technique": technique, "drill": drill, "reason": reason,
			"leader": leader, "roster": ", ".join(Array(roster))}


func _note_changes(before: Dictionary) -> bool:
	var now := _snapshot()
	if _fresh_task:
		changed_fields.append("task")
		_fresh_task = false
	for key: String in now:
		if now[key] != before[key]:
			changed_fields.append(key)
	return not changed_fields.is_empty()


func _log(text: String) -> void:
	events.append(text)
	if events.size() > MAX_EVENTS:
		events.remove_at(0)
