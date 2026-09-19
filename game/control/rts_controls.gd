class_name RtsControls
extends Control
## Desktop-first, StarCraft-style control (round 3, control stream). A full-screen overlay under the HUD that turns
## mouse and keyboard into selections (Selection), control groups (ControlGroups), and K1 orders (Orders).
## The whole grammar is in _agents/tactical_map.md "v4".
##
##   SELECT   left-click a unit · drag a box · shift adds/removes · double-click or ctrl-click: every visible unit of
##            that type · Escape clears (or cancels a pending order) · click an enemy to inspect it
##   ORDER    right-click ground = move · right-click an enemy = attack · right-click a friend = follow
##            A then click = attack-move · F then click a friend = follow · M then click = move
##            E then click = screen that flank · R then click = support by fire (X3: L1 tasks, elements only)
##            S = stop · H = hold · shift queues any order (and keeps A/F/M armed for the next click)
##            G cycles the formation (auto by default: the group arranges itself by role and situation)
##            right-clicking an enemy with a mixed selection sends only the guns that can hurt it; the rest escort
##   OTHER    ctrl+A selects the whole army · F1 selects idle units · F2 goes to the next idle element
##            Q jumps to the newest alert · resting the mouse on a unit shows its stats
##            elements you aren't watching sit on the screen edge (EdgeMarkers): click one to go to it
##   GROUPS   ctrl+1–9 saves · shift+1–9 adds · 1–9 selects (twice quickly: center the camera) · Tab cycles groups
##   CAMERA   screen edges, arrows, middle-drag pan · wheel zoom · , . rotate · C centers on the selection
##            Page Up / Page Down or ctrl+wheel tilt (Home resets it) · O the overview and back (round 6 X3)
##            [ ] field of view · V auto-framing on/off · P copies the camera pose (CameraReadout shows it all)
##   TIME     Space pauses (orders still work while paused)
## The node is named "TacticalMap" in skirmish so the HUD skin lays its message columns out around it.

signal command_issued(command: Dictionary, error: String)
## Round 6: P copied the camera pose (the HUD says so).
signal pose_copied(pose: String)

## A left press that moves farther than this (pixels) draws a box instead of clicking.
const DRAG_THRESHOLD_PX := 6.0
## A click this close to a unit's screen position picks it (more when the unit is drawn bigger than that).
const PICK_RADIUS_PX := 22.0
const PICK_BODY_M := 2.6
## Screen positions count as "inside the box" within this margin (hull edges peeking in).
const BOX_MARGIN_PX := 4.0
## Armed orders a key waits for a click to complete (A, F, M), and what each click becomes.
const MODES := {KEY_A: "attack_move", KEY_F: "follow", KEY_M: "move", KEY_E: "screen", KEY_R: "support_by_fire",
		KEY_B: "ambush"}
const MODE_HINTS := {"attack_move": "ATTACK-MOVE: click the ground or an enemy", "follow": "FOLLOW: click a friendly unit",
		"move": "MOVE: click the ground", "screen": "SCREEN: click the flank to cover",
		"support_by_fire": "SUPPORT BY FIRE: click what to cover (the leader picks the firing line)",
		"ambush": "AMBUSH: click the kill zone"}
## X3: verbs the player gives an element as an L1 task (its leader picks the formation, technique and drills).
## attack-move maps onto a move task on purpose: an element on the move already runs react-to-contact, which is
## what attack-move means. `follow` stays a direct order - it is micro, not a task - and `stop` stands the element
## down so its leader stops re-issuing.
##
## A plain `move` is here again (round 6, with squad's X4). Round 5 took it out because a leader holding a move task
## kept re-slotting and manoeuvring (20 order changes a second, units ending 20-90 m from the click; the lead: "their
## behavior is overridden by a higher priority"). Round 6 put it back as a plain move (`"drills": false`: formed up, no
## contact drills, one formation anchored on the click) - and the first attempt was HELD: in the lead's own sequence
## (`make squad-orders-test`, five squads from the spawn) elements re-issued 31-38 commands while nobody touched the
## controls, against 0 for direct moves. Squad found two re-send rules (fix 4d734b1e). Re-admitted on the same test on
## the merged tree (laptop, seed 3, one run each): X4 on 0 idle commands, 14 arrived and stayed, 1 never arrived,
## mean 5.9 m from the given slot; direct 0, 12, 1, 5.6 m. If you touch this, re-run that A/B first.
const ELEMENT_TASKS := {"move": "move", "attack_move": "move", "attack": "attack", "hold": "hold",
		"screen": "screen", "support_by_fire": "support_by_fire", "ambush": "ambush"}
## G cycles the formation the next orders ask for (auto = by role and situation, GroupFormation.choose).
const FORMATION_CYCLE := [UnitCommand.AUTO, "wedge", "line", "column", "vee"]
## A right-clicked enemy is attacked only by selected units whose weapon does at least this fraction of its damage
## through the target's side armor (Match.armor_multiplier); the rest escort them. With none, everyone attacks.
const SMART_ATTACK_MULTIPLIER := 0.25
## The mouse resting this long on a unit shows its tooltip (seconds).
const HOVER_SECONDS := 0.35
## Order markers and waypoint lines farther than this outside the screen aren't drawn (pixels).
const OFF_SCREEN_PX := 4000.0
## How long an order's acknowledgement marker shows (seconds).
const ACK_SECONDS := 0.7
## X6: a hull bar floats this far above the top of the hull, is this fraction of the hull's width on screen, and
## is clamped to this many pixels wide so it neither vanishes at distance nor sits on top of the model up close.
const BAR_ABOVE_M := 0.9
const BAR_WIDTH_FACTOR := 0.9
const BAR_MIN_PX := 14.0
const BAR_MAX_PX := 62.0
const BAR_HEIGHT_PX := 3.4
## A second tap on the same group number within this long centers the camera on it (seconds, wall time: UI only).
const DOUBLE_TAP_SECONDS := 0.4
## L4 (X1): a queued destination further than this from the element is left out of the camera's frame; the camera
## leans toward it instead of climbing (RtsCamera.order_pose does the leaning).
const FRAME_DESTINATION_M := 220.0

var game_match: Match
var orders: Orders
var camera: Camera3D
var rig: RtsCamera
## What our team can see (optional).
var visibility: VisibilityField
var team := Match.Team.GREEN
## Tests without fog of war: every enemy counts as seen.
var reveal_all := false
var selection := Selection.new()
var groups := ControlGroups.new()
## X2: how every element is doing, and the alerts Q jumps to.
var awareness := ElementAwareness.new()
## X3 (L1): doctrine's elements, when the mode installed them. Null = every order goes out directly.
var elements: Elements
## Round 6 X5: what nav's Movement says each unit is doing (yielding, blocked, its ETA). Silent until N1 is wired in.
var movement := MovementReadout.new()
## Round 7 (B): how much of the selection's reach the vision frame shows ahead of it: 0 = off, 1 = out to the selection's
## covering range (`;` / `'` in play). The frame varies DISTANCE, not the lens: the lead's 35° telephoto is the look.
var range_frame := 1.0
const RANGE_FRAME_STEP := 0.25
const RANGE_FRAME_MAX := 2.0
## Round 7 (A): headings this far apart (mean resultant length below this) are a "mixed" selection with no facing.
const FACING_AGREEMENT := 0.6
## Round 6 X7: each element's recent decisions, for "why did my element do that" (the card's doctrine line tooltip).
var element_log := ElementLog.new()
## X2: the off-screen element chips and the alert strip (set by the mode).
var markers: EdgeMarkers
## The armed order waiting for a click ("" = none): "attack_move", "follow", or "move".
var mode := ""
## The formation move, attack-move, and hold orders ask for (FORMATION_CYCLE; G cycles it).
var formation: String = UnitCommand.AUTO

var _press_at: Variant = null
var _press_shift := false
var _press_ctrl := false
var _press_double := false
var _box_now := Vector2.ZERO
var _boxing := false
## Order acknowledgements: [{"kind", "position": Vector3, "left": seconds}], newest last.
var _acks: Array = []
## UI clock (seconds since ready, advancing while paused) for double taps.
var _clock := 0.0
var _last_group := 0
var _last_group_at := -10.0
## The pause banner's text ("" = none), shown while the tree is paused.
var _pause_text := ""
var _hover_at := Vector2(-1, -1)
var _hover_time := 0.0
## Draws above the panel, group bar, and radar (children draw over their parent): the tooltip and the armed-order hint.
var _overlay: Control


func _ready() -> void:
	# A Control under a CanvasLayer has no parent Control to size it: anchors AND offsets must be set.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 50
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	awareness.groups = groups


func _process(delta: float) -> void:
	if game_match == null:
		return
	_clock += delta
	_hover_time += delta
	for ack: Dictionary in _acks:
		ack["left"] = float(ack["left"]) - delta
	_acks = _acks.filter(func(ack: Dictionary) -> bool: return float(ack["left"]) > 0.0)
	if selection.prune(game_match) and selection.units.is_empty():
		disarm()
	groups.prune(game_match)
	_update_compliance(delta)
	awareness.game_match = game_match
	awareness.groups = groups
	awareness.orders = orders
	awareness.team = team
	awareness.update(delta)
	mouse_default_cursor_shape = Control.CURSOR_CROSS if mode != "" else Control.CURSOR_ARROW
	_apply_fog_of_war()
	queue_redraw()
	_overlay.queue_redraw()


## Enemies our team can't see are hidden in 3D; nameplates stay off (rings, bars, and the panel carry the info).
func _apply_fog_of_war() -> void:
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null:
			continue
		if tank.team != team:
			tank.visible = can_see(tank)
		tank.nameplate.visible = false
		tank.show_intent = false


func can_see(tank: Tank) -> bool:
	return reveal_all or game_match.is_visible_to(team, tank)


func selection_state() -> Dictionary:
	return {"units": selection.units.duplicate(), "inspected": selection.inspected}


# ---- L4: what the camera frames (X1) ----------------------------------------------------------------------

## The element the camera keeps framed: the selection when there is one, else the group last recalled, else the
## whole force (so an unselected player still watches their army instead of empty ground).
func commanded_units() -> Array[String]:
	if not selection.units.is_empty():
		return selection.units.duplicate()
	var last := _living(groups.members(_last_group))
	if not last.is_empty():
		return last
	var all_units: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive():
			all_units.append(String(tank.name))
	return all_units


func _living(names: Array[String]) -> Array[String]:
	var alive: Array[String] = []
	for unit_name in names:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			alive.append(unit_name)
	return alive


## L4 for RtsCamera.vision: the ground points it must keep on screen (the commanded element and the contacts that
## element can see), the element's current destination, and the whole team's sight region (the zoom-out cap and
## the "look" clamp come from the force's collective horizon, not from one element's).
func vision_state() -> Dictionary:
	if game_match == null:
		return {}
	var element: Array[String] = commanded_units()
	var frame: Array = []
	var eyes: Array = []
	var middle := Vector3.ZERO
	for unit_name in element:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			frame.append(Shown.ground(tank))
			middle += frame[-1]
			eyes.append(tank)
	middle /= maxf(frame.size(), 1.0)
	# Contacts the element can see widen the frame, but only symmetrically about the element: each one is framed
	# together with its mirror image, so the frame stays centred on your own vehicles. Framing contacts as they are
	# let a mass of enemies drag the centre across to them, and with the zoom capped your own element slid off the
	# bottom of the screen (the lead, round 5: "it ends up focusing on the enemy instead of our own friendly units").
	for node in game_match.tanks.get_children():
		var enemy := node as Tank
		if enemy == null or enemy.team == team or not enemy.is_alive() or not can_see(enemy):
			continue
		for tank: Tank in eyes:
			if tank.global_position.distance_to(enemy.global_position) <= tank.sight_radius:
				var at := Shown.ground(enemy)
				frame.append(at)
				frame.append(middle * 2.0 - at)
				break
	# Round 7 (B), the lead: "tanks were shooting at enemies I couldn't even see ... make the field of view match the
	# range of the vehicle or the max range of the selection". The view leans out toward what the selection can fight,
	# in the direction it faces - as a LEAN (RtsCamera.order_pose: the units stay framed, the view leans as far toward
	# the point as that allows), not as one more point to fit. Fitting it pulled the frame's centre forward and, with
	# the auto camera's distance capped, dropped the squad off the bottom of the screen with the enemy in view (round
	# 5's "focusing on the enemy", back again; shell-playtest caught it). An order's destination still wins the lean.
	var destination: Variant = _element_destination(element, frame)
	if destination == null and range_frame > 0.0 and not eyes.is_empty():
		var ahead: Variant = selection_facing()
		if ahead == null:
			ahead = Match.team_frame(team)["forward"]
		destination = middle + (ahead as Vector3) * selection_reach() * range_frame
	var friendly: Array = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive():
			friendly.append(tank)
	return {"frame": frame, "destination": destination, "region": VisionRegion.of(friendly)}


## Round 7 (B): the furthest the commanded units can see AND matter at - per unit, the smaller of its weapon's effective
## range and its sight (Engagement.covering_range's rule, per selection instead of per roster). 0 with no units.
func selection_reach() -> float:
	var reach := 0.0
	for unit_name in commanded_units():
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		reach = maxf(reach, minf(Engagement.effective_range(Weapons.profile(tank.weapon_id)), tank.sight_radius))
	return reach


## Round 7 (A): which way the commanded units mean to face, on the ground (unit Vector3), or null when there is nothing
## to follow. In order: a squad's formation heading while it has a task; else each unit's ordered facing or travel
## heading; else the hulls' own forward. Averaged as directions; a selection whose headings disagree (mean resultant
## below FACING_AGREEMENT) is "mixed" and returns null, and the camera then keeps its yaw rather than snap somewhere.
func selection_facing() -> Variant:
	var units := commanded_units()
	if units.is_empty() or game_match == null:
		return null
	var element := selected_element()
	if element != null and not element.task.is_empty() and element.heading.length() > 0.1:
		return Vector3(element.heading.x, 0.0, element.heading.z).normalized()
	var sum := Vector3.ZERO
	var count := 0
	for unit_name in units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		var order: Dictionary = orders.current(unit_name) if orders != null else {}
		var way: Variant = order.get("facing", order.get("heading"))
		var direction: Vector3
		if way is Array and (way as Array).size() == 2:
			direction = Vector3(float(way[0]), 0.0, float(way[1]))
		else:
			direction = -tank.global_basis.z  # forward is -Z (trip-up 2)
		direction.y = 0.0
		if direction.length() < 0.001:
			continue
		sum += direction.normalized()
		count += 1
	if count == 0 or sum.length() / float(count) < FACING_AGREEMENT:
		return null
	return sum.normalized()


## Where the element is headed (the nearest unit's current order goal), or null when it is going nowhere or the
## goal is too far away to be worth leaning toward.
func _element_destination(element: Array[String], frame: Array) -> Variant:
	if frame.is_empty() or orders == null:
		return null
	var middle := Vector3.ZERO
	for at: Vector3 in frame:
		middle += at
	middle /= frame.size()
	for unit_name in element:
		var route := waypoints(unit_name)
		if route.is_empty():
			continue
		var goal: Vector3 = route[0]["position"]
		if goal.distance_to(middle) <= FRAME_DESTINATION_M:
			return goal
	return null


# ---- Mouse ------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if rig != null and rig.handle_mouse(event):
		accept_event()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_left_button(button)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				if mode != "":
					disarm()  # right-click cancels an armed order, like StarCraft
				else:
					right_click_order(button.position, button.shift_pressed)
			accept_event()
	if event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		if at.distance_to(_hover_at) > 3.0:
			_hover_at = at
			_hover_time = 0.0
	if event is InputEventMouseMotion and _press_at != null:
		_box_now = (event as InputEventMouseMotion).position
		if not _boxing and _box_now.distance_to(_press_at) > DRAG_THRESHOLD_PX:
			_boxing = true
		accept_event()


func _left_button(button: InputEventMouseButton) -> void:
	if button.pressed:
		# X2: an edge marker is a button, not ground: it takes priority over selecting and box dragging.
		if markers != null and markers.marker_at(button.position) > 0:
			recall_group(markers.marker_at(button.position), true)
			return
		if mode != "":
			armed_click_order(button.position, button.shift_pressed)
			return
		_press_at = button.position
		_box_now = button.position
		_press_shift = button.shift_pressed
		_press_ctrl = button.ctrl_pressed or button.meta_pressed
		_press_double = button.double_click
		_boxing = false
		return
	if _press_at == null:
		return
	var start: Vector2 = _press_at
	_press_at = null
	if _boxing:
		_boxing = false
		box_select(Rect2(start, button.position - start).abs(), _press_shift)
	else:
		click_select(start, _press_shift, _press_ctrl, _press_double)


## A click: select the unit there (shift toggles it; ctrl or a double-click takes every visible unit of its type).
## An enemy is inspected. Empty ground keeps the selection.
func click_select(at: Vector2, shift := false, ctrl := false, double := false) -> void:
	var tank := pick_unit(at)
	if tank == null:
		return
	var unit_name := String(tank.name)
	if tank.team != team:
		if not shift or selection.units.is_empty():
			selection.inspect(unit_name)
		return
	if ctrl or double:
		var same := visible_of_type(tank.unit_id)
		if shift:
			selection.add(same)
		else:
			selection.set_units(same)
	elif shift:
		selection.toggle(unit_name)
	else:
		selection.set_units([unit_name])
	_watch_selection()


## A box: our units inside it (shift adds them). A box around none of ours keeps the selection.
func box_select(rect: Rect2, shift := false) -> void:
	var inside := units_in_box(rect)
	if inside.is_empty():
		return
	if shift:
		selection.add(inside)
	else:
		selection.set_units(inside)
	_watch_selection()


# ---- X3: tasks, not geometry (doctrine's L1) ----------------------------------------------------------------

## The element the selection *is*: every selected unit belongs to it and none of its living members is left out.
## Null for an ad-hoc handful of units, which keeps direct control (the player's order always wins).
## The control group the selection exactly is (its living members and nothing else), or 0. That is what the
## player thinks of as "an element", and it is what a task may be given to.
func selected_group() -> int:
	if selection.units.is_empty():
		return 0
	for number in groups.numbers():
		var living: Array[String] = []
		for unit_name in groups.members(number):
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive():
				living.append(unit_name)
		if living.size() == selection.units.size() and living.all(func(n: String) -> bool: return selection.units.has(n)):
			return number
	return 0


## Whether the selection can be given a task: it is a whole element, or a whole control group ready to become
## one. The armed task keys and the command card's element-only buttons both ask this.
func can_task() -> bool:
	return elements != null and (selected_element() != null or selected_group() > 0)


func selected_element() -> Element:
	if elements == null or selection.units.is_empty():
		return null
	var element := elements.of(selection.units[0])
	if element == null:
		return null
	for unit_name in selection.units:
		if elements.of(unit_name) != element:
			return null
	for member in element.members():
		if not selection.units.has(String(member)):
			return null
	return element


## Whether this order should go to a leader as a task rather than to the units as geometry. An explicit formation
## is the player overriding doctrine, so it drops back to direct orders (the brief: let them override, never
## require it), and a queued order is a route the player is drawing by hand.
func _is_task(verb: String, extra: Dictionary) -> bool:
	return elements != null and formation == UnitCommand.AUTO and not bool(extra.get("queue", false)) \
			and ELEMENT_TASKS.has(verb) and (selected_element() != null or selected_group() > 0)


## Give the selected element an L1 task. Returns "" or the reason it was refused.
func assign_task(verb: String, extra: Dictionary) -> String:
	var element := selected_element()
	if element == null:
		# An element exists only while it has a task: an untasked leader would still run its SOP and fight the
		# player's own orders for the wheel. The first task forms it; a direct order (below) dissolves it again.
		var number := selected_group()
		if number == 0 or elements == null:
			return _refuse("select a whole element to give it a task")
		element = elements.form(selection.units.duplicate(), groups.label(number))
	var task := {"verb": String(ELEMENT_TASKS[verb])}
	if extra.has("to"):
		task["to"] = [float(extra["to"][0]), float(extra["to"][1])]
	if extra.has("target"):
		task["target"] = String(extra["target"])
	if task["verb"] == "move" and not task.has("to"):
		return _refuse("a move task needs somewhere to go")
	if verb == "move":
		task["drills"] = false  # a plain move: formed up to the spot, no contact drills (squad X4)
	var error := element.assign(task)
	var command := UnitCommand.make(selection.units, verb, extra)
	command_issued.emit(command, error)
	if error == "":
		_acknowledge(command)
	return error


## X3 for the HUD: what the selected element's leader has decided ({} when the selection isn't an element).
func element_state() -> Dictionary:
	var element := selected_element()
	return element.state() if element != null else {}


## One line for the command card: "Alpha: wedge, bounding overwatch - contact ahead" ("" when not an element).
func doctrine_line() -> String:
	var element := selected_element()
	return element.describe() if element != null else ""


## X2: what you just picked is what you want to watch, even if you panned the camera away a moment ago.
func _watch_selection() -> void:
	if rig != null and not selection.units.is_empty():
		rig.take_vision()


## X2: go to the newest alert nobody has looked at: select that element and move the camera. Returns its text.
func jump_to_alert() -> String:
	var alert := awareness.take_alert()
	if alert.is_empty():
		return ""
	var number := int(alert["element"])
	if not groups.is_empty(number):
		recall_group(number, true)
	elif rig != null:
		rig.focus_on(alert["position"])
	return String(alert["text"])


## The living unit nearest `screen` within reach (ours, or an enemy we can see), or null.
func pick_unit(screen: Vector2) -> Tank:
	var best: Tank = null
	var best_distance := INF
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive() or camera.is_position_behind(Shown.at(tank)):
			continue
		if tank.team != team and not can_see(tank):
			continue
		var at := camera.unproject_position(Shown.at(tank))
		var distance := at.distance_to(screen)
		var body := camera.unproject_position(Shown.at(tank) + camera.global_basis.x * PICK_BODY_M).distance_to(at)
		# Ties (overlapping units) go to ours, then to the nearer one on screen.
		var score := distance - (0.5 if tank.team == team else 0.0)
		if distance <= maxf(PICK_RADIUS_PX, body) and score < best_distance:
			best = tank
			best_distance = score
	return best


## Our living units whose screen position lies inside `rect`.
func units_in_box(rect: Rect2) -> Array[String]:
	var grown := rect.grow(BOX_MARGIN_PX)
	var result: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and not camera.is_position_behind(Shown.at(tank)) \
				and grown.has_point(camera.unproject_position(Shown.at(tank))):
			result.append(String(tank.name))
	return result


## Our living units of `unit_id` that are on screen.
func visible_of_type(unit_id: String) -> Array[String]:
	var screen := get_viewport_rect()
	var result: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and tank.unit_id == unit_id and not camera.is_position_behind(Shown.at(tank)) \
				and screen.has_point(camera.unproject_position(Shown.at(tank))):
			result.append(String(tank.name))
	return result


# ---- Keyboard ---------------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# X4: ctrl+A takes the whole army. It sits with the other ctrl keys, before the ctrl guard below.
	if key.keycode == KEY_A and (key.ctrl_pressed or key.meta_pressed):
		select_army()
		get_viewport().set_input_as_handled()
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var number := int(key.keycode - KEY_0)
		if key.ctrl_pressed or key.meta_pressed:
			if not selection.units.is_empty():
				groups.save(number, selection.units)
		elif key.shift_pressed:
			if not selection.units.is_empty():
				groups.add(number, selection.units)
		else:
			recall_group(number)
		get_viewport().set_input_as_handled()
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	match key.keycode:
		KEY_ESCAPE:
			if mode != "":
				disarm()
			else:
				selection.clear()
		KEY_A, KEY_F, KEY_M, KEY_E, KEY_R, KEY_B:
			arm(MODES[key.keycode])
		KEY_S:
			order_selection("stop")
		KEY_H:
			order_selection("hold", {"queue": key.shift_pressed})
		KEY_TAB:
			var next := groups.next_after(_last_group)
			if next > 0:
				recall_group(next, true)
		KEY_C:
			center_on(selection.units)
		KEY_O:
			# X3: the deliberate top-down read of the map (and back). Tab cycles groups on desktop, so it needed a key.
			if rig != null:
				rig.toggle_overview(team)
		KEY_HOME:
			if rig != null:
				rig.reset_tilt()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			# Round 6: the lead finds the camera himself - [ narrows the field of view, ] widens it.
			if rig != null:
				rig.fov_by(RtsCamera.FOV_STEP_DEG * (1.0 if key.keycode == KEY_BRACKETRIGHT else -1.0))
		KEY_V:
			if rig != null:
				rig.set_auto_frame(not rig.auto_frame)
		KEY_Y:
			# Round 7 (A): the camera's yaw follows the selection's facing; Y turns that off and on.
			if rig != null:
				rig.yaw_follow = not rig.yaw_follow
		KEY_SEMICOLON, KEY_APOSTROPHE:
			# Round 7 (B): how far out the frame reaches toward the selection's weapon range (0 = off).
			range_frame = clampf(range_frame + RANGE_FRAME_STEP * (1.0 if key.keycode == KEY_APOSTROPHE else -1.0), 0.0, RANGE_FRAME_MAX)
		KEY_P:
			# Print the pose and put it on the clipboard, so the lead can paste the camera he found back to us.
			if rig != null:
				var pose := rig.pose_text() + " range_frame=%.2f" % range_frame
				print(pose)
				DisplayServer.clipboard_set(pose)
				pose_copied.emit(pose)
		KEY_G:
			cycle_formation()
		KEY_F1:
			select_idle()
		KEY_F2:
			next_idle_element()
		KEY_Q:
			jump_to_alert()
		KEY_SPACE:
			set_paused(not get_tree().paused)
		_:
			return
	get_viewport().set_input_as_handled()


## Tactical pause: the simulation stops, the controls keep working (orders land when it resumes).
func set_paused(paused: bool, message := "PAUSED: give orders, then Space to resume") -> void:
	get_tree().paused = paused
	_pause_text = message if paused else ""


# ---- Groups and camera ----------------------------------------------------------------------------------

## Select group `number`; a quick second tap (or `center`) also centers the camera on it.
func recall_group(number: int, center := false) -> void:
	var members := groups.members(number)
	if members.is_empty():
		return
	var double := number == _last_group and _clock - _last_group_at <= DOUBLE_TAP_SECONDS
	selection.set_units(members)
	disarm()
	_last_group = number
	_last_group_at = _clock
	if rig != null:
		rig.take_vision()  # L4: switching elements moves the camera to it, without waiting out the hand-back
	if double or center:
		center_on(members)


## Aim the camera at the middle of these units.
func center_on(names: Array) -> void:
	if rig == null or names.is_empty():
		return
	var middle := Vector3.ZERO
	var count := 0
	for unit_name: String in names:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			middle += Shown.at(tank)
			count += 1
	if count > 0:
		rig.focus_on(middle / count)


# ---- Orders -----------------------------------------------------------------------------------------------

## Issue a K1 command for our team, acknowledge it, and tell listeners. Returns "" or the error.
## Round 8: a refusal the player never hears is an order that silently didn't happen. Everything refused before it
## reaches Orders goes out on command_issued like an Orders error does (the HUD posts it as "Can't: ...").
func _refuse(error: String) -> String:
	command_issued.emit({"verb": "", "units": selection.units.duplicate()}, error)
	return error


func issue(command: Dictionary) -> String:
	var error := orders.issue(command, team) if orders != null else "no orders"
	command_issued.emit(command, error)
	if error == "":
		_acknowledge(command)
	return error


## A verb for the whole selection ("" when there is nothing to command).
func order_selection(verb: String, extra: Dictionary = {}) -> String:
	if selection.units.is_empty():
		return ""
	if _is_task(verb, extra):
		return assign_task(verb, extra)
	# A direct order is the player taking the wheel: dissolve the element so its leader stops commanding. The
	# next task re-forms it. (Doctrine detaches per unit too, but only from its next update, which is late
	# enough to clobber a queued route.)
	var element := selected_element()
	if element != null and elements != null:
		elements.disband(element)
	elif elements != null:
		# Part of a squad (round 6): those units leave their element, whose leader would otherwise re-slot them.
		for unit_name in selection.units:
			var owner := elements.of(unit_name)
			if owner == null:
				continue
			owner.remove(unit_name)
			if owner.members().is_empty():
				elements.disband(owner)
	var command := UnitCommand.make(selection.units, verb, extra)
	command["source"] = "player"
	if formation != UnitCommand.AUTO and verb in ["move", "attack_move", "hold"]:
		command["formation"] = formation
	return issue(command)


func cycle_formation() -> void:
	formation = FORMATION_CYCLE[(FORMATION_CYCLE.find(formation) + 1) % FORMATION_CYCLE.size()]


## Right-click: an enemy = attack, a friend outside the selection = follow, anything else = move there.
func right_click_order(at: Vector2, queue := false) -> String:
	if selection.units.is_empty():
		return ""
	var tank := pick_unit(at)
	if tank != null and tank.team != team:
		# X3: a whole element gets an attack task and its leader works out who shoots and from where; a handful
		# of units keeps the smart-attack split, which is the player doing that job by hand.
		if _is_task("attack", {"queue": queue}):
			return order_selection("attack", {"target": String(tank.name), "queue": queue})
		return smart_attack(tank, queue)
	# A right-click on your own vehicles is a move to that spot, not a follow (game_design.md: "right-click ground =
	# move ... F + click a friendly = follow/escort"). The lead, round 5: with an army packed on the start line, half of
	# "go there" landed on his own units and became "trail that one", so his squads never went where he clicked.
	var world: Variant = screen_to_world(at)
	if world == null:
		return ""
	return order_selection("move", {"to": [world.x, world.z], "queue": queue})


## A right click on the radar (a world point): move there (queued with shift).
func world_order(world: Vector3, queue := false) -> String:
	if mode != "":
		disarm()
		return ""
	return order_selection("move", {"to": [world.x, world.z], "queue": queue})


## A left click on the radar while an order is armed: attack-move, move, or an element task at that point.
func armed_world_order(world: Vector3, queue := false) -> String:
	var armed := mode
	if not queue:
		disarm()
	if armed in ["screen", "support_by_fire", "ambush"] and not can_task():
		return _refuse("select a whole element to give it a task")
	if armed in ["attack_move", "move", "screen", "support_by_fire", "ambush"]:
		return order_selection(armed, {"to": [world.x, world.z], "queue": queue})
	return ""


## Right-click an enemy: the selected units whose guns can hurt it attack; the others follow the nearest attacker.
func smart_attack(target: Tank, queue := false) -> String:
	var attackers: Array[String] = []
	var escorts: Array[String] = []
	for unit_name in selection.units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null:
			continue
		if Match.armor_multiplier(tank.weapon, target.unit_id, "side") >= SMART_ATTACK_MULTIPLIER:
			attackers.append(unit_name)
		else:
			escorts.append(unit_name)
	if attackers.is_empty():
		return order_selection("attack", {"target": String(target.name), "queue": queue})
	var error := issue(UnitCommand.make(attackers, "attack", {"target": String(target.name), "queue": queue, "source": "player"}))
	if error != "" or escorts.is_empty():
		return error
	var lead: String = attackers[0]
	var lead_tank := game_match.tanks.get_node(NodePath(lead)) as Tank
	for unit_name in attackers:
		var candidate := game_match.tanks.get_node(NodePath(unit_name)) as Tank
		if candidate.global_position.distance_to(target.global_position) < lead_tank.global_position.distance_to(target.global_position):
			lead = unit_name
			lead_tank = candidate
	return issue(UnitCommand.make(escorts, "follow", {"target": lead, "queue": queue, "source": "player"}))


## X4 (ctrl+A): every living unit we have. At 30+ a side this is the fastest way back to "everything", and it is
## what the player reaches for after a rout.
func select_army() -> void:
	var army: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive():
			army.append(String(tank.name))
	if army.is_empty():
		return
	selection.set_units(army)
	disarm()
	_watch_selection()


## X4 (F2): go to the next element with nothing to do - no task, and no unit of it under orders - cycling from
## the one you looked at last. Returns its group number, or 0 when every element is busy.
func next_idle_element() -> int:
	var start := _last_group
	for step in range(1, ControlGroups.COUNT + 1):
		var number := ((start - 1 + step) % ControlGroups.COUNT) + 1
		if groups.is_empty(number) or not _is_element_idle(number):
			continue
		recall_group(number, true)
		return number
	return 0


## An element is idle when no living member has orders and its leader has no task.
func _is_element_idle(number: int) -> bool:
	var living := 0
	for unit_name in groups.members(number):
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		living += 1
		if orders != null and not orders.is_idle(unit_name):
			return false
	if living == 0:
		return false
	var element := elements.of(groups.members(number)[0]) if elements != null and not groups.is_empty(number) else null
	return element == null or element.task.is_empty()


## F1: select every one of our units that has no orders (never ordered, or done). Keeps the selection if none.
func select_idle() -> void:
	var idle: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and (orders == null or orders.is_idle(String(tank.name))):
			idle.append(String(tank.name))
	if not idle.is_empty():
		selection.set_units(idle)
		disarm()


## The tooltip for the unit under a resting mouse: {"unit", "title", "lines": [String], "enemy": bool}, or {}.
func tooltip() -> Dictionary:
	if _hover_time < HOVER_SECONDS or _press_at != null or _hover_at.x < 0.0 or game_match == null:
		return {}
	if get_viewport().gui_get_hovered_control() != self:
		return {}  # the mouse is over the panel, the radar, or other UI
	var tank := pick_unit(_hover_at)
	if tank == null:
		return {}
	var id := tank.unit_id
	var weapon := Weapons.profile(tank.weapon_id)
	var words := func(roles: Variant) -> String:
		return ", ".join((roles if roles is Array else []).map(func(r: Variant) -> String: return String(r).capitalize())) if roles is Array and not (roles as Array).is_empty() else "-"
	return {"unit": String(tank.name), "enemy": tank.team != team,
			"title": ("Enemy " if tank.team != team else "") + String(Units.stat(id, "display_name", id)),
			"lines": [String(Units.stat(id, "blurb", "")),
				"Hull %d/%d   Shield %d/%d" % [tank.health, tank.max_health, roundi(tank.shield), roundi(tank.max_shield)],
				"Weapon %s   Range %d m   Speed %d m/s" % [String(weapon.get("display_name", tank.weapon_id)).capitalize(),
						roundi(float(weapon.get("range", 0.0))), roundi(tank.max_forward_speed)],
				"Strong vs %s   Weak vs %s" % [words.call(Units.stat(id, "good_vs", [])), words.call(Units.stat(id, "weak_vs", []))]]}


## A left click while an order is armed. Shift keeps it armed for the next click (queue a chain).
func armed_click_order(at: Vector2, queue := false) -> String:
	var armed := mode
	if not queue:
		disarm()
	var tank := pick_unit(at)
	var world: Variant = screen_to_world(at)
	match armed:
		"attack_move":
			if tank != null and tank.team != team:
				return order_selection("attack", {"target": String(tank.name), "queue": queue})
			if world != null:
				return order_selection("attack_move", {"to": [world.x, world.z], "queue": queue})
		"follow":
			if tank != null and tank.team == team and not selection.units.has(String(tank.name)):
				return order_selection("follow", {"target": String(tank.name), "queue": queue})
			return _refuse("click a friendly unit to follow")
		"move":
			if world != null:
				return order_selection("move", {"to": [world.x, world.z], "queue": queue})
		"screen", "support_by_fire", "ambush":
			if not can_task():
				return _refuse("select a whole element to give it a task")
			if world != null:
				return order_selection(armed, {"to": [world.x, world.z], "queue": queue})
	return ""


## Arm an order that waits for a click (A, F, M). Needs a selection.
func arm(p_mode: String) -> void:
	if selection.units.is_empty():
		return
	mode = p_mode
	_press_at = null
	_boxing = false


func disarm() -> void:
	mode = ""


func screen_to_world(screen: Vector2) -> Variant:
	if camera == null:
		return null
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return null
	var point: Vector3 = hit
	return Orders.clamp_to_arena(Vector3(point.x, 0.0, point.z))  # M4: the arena's shape, not a square


# ---- X6: readability at close zoom --------------------------------------------------------------------------

## Hull bars to draw over our vehicles: [{"unit", "at": Vector2 (screen), "width": float, "health": 0..1,
## "shield": 0..1}]. Only ours, and only when a vehicle is hurt or selected - X4 collapsed the panel's portraits
## to one per type, so this is where "which of mine is nearly dead" now lives, and a bar over every healthy
## vehicle at 30 a side would be noise instead of information.
func health_bars() -> Array:
	var result: Array = []
	if game_match == null or camera == null:
		return result
	var screen := Rect2(Vector2.ZERO, size)
	for tank in game_match.sorted_team_tanks(team):
		if not tank.is_alive():
			continue
		var health := clampf(float(tank.health) / maxf(float(tank.max_health), 1.0), 0.0, 1.0)
		var shield := clampf(tank.shield / tank.max_shield, 0.0, 1.0) if tank.max_shield > 0.0 else 0.0
		var hurt := health < 0.999 or (tank.max_shield > 0.0 and shield < 0.999)
		if not hurt and not selection.units.has(String(tank.name)):
			continue
		var hull: Array = Units.stat(tank.unit_id, "hull_size")
		var top := Shown.at(tank) + Vector3.UP * (float(hull[1]) + BAR_ABOVE_M)
		if camera.is_position_behind(top):
			continue
		var at := camera.unproject_position(top)
		if not at.is_finite() or not screen.has_point(at):
			continue
		# The hull's own width on screen, so the bar shrinks with distance exactly as the vehicle does.
		var edge := camera.unproject_position(top + camera.global_basis.x * float(hull[0]))
		var width := clampf(edge.distance_to(at) * 2.0 * BAR_WIDTH_FACTOR, BAR_MIN_PX, BAR_MAX_PX)
		result.append({"unit": String(tank.name), "at": at, "width": width, "health": health, "shield": shield})
	return result


## The most recent acknowledgement marker ({} when none is showing): {"kind", "position", "left"}.
func last_ack() -> Dictionary:
	return _acks.back() if not _acks.is_empty() else {}


## A unit's route for waypoint markers: its current order, then its queue, as [{"kind": verb, "position"}]
## (attack and follow point at their target's position; orders without a place are skipped).
func waypoints(unit_name: String) -> Array:
	var route: Array = []
	if orders == null:
		return route
	for order: Dictionary in [orders.current(unit_name)] + orders.queue(unit_name):
		if order.is_empty():
			continue
		var at: Variant = null
		if order.has("target"):
			var target := game_match.tanks.get_node_or_null(NodePath(String(order["target"]))) as Tank
			if target != null and target.is_alive():
				at = Shown.ground(target)
		elif order.has("goal") and order["verb"] != "hold":
			at = Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
		if at != null:
			route.append({"kind": String(order["verb"]), "position": at})
	return route


func _acknowledge(command: Dictionary) -> void:
	var at: Variant = null
	var kind: String = command["verb"]
	if command.has("to"):
		at = Orders.clamp_to_arena(Vector3(float(command["to"][0]), 0.0, float(command["to"][1])))
	elif command.has("target"):
		var target := game_match.tanks.get_node_or_null(NodePath(String(command["target"]))) as Tank
		if target != null:
			at = Vector3(target.global_position.x, 0.0, target.global_position.z)
	else:
		# Stop and hold: a marker under the group's middle.
		var middle := Vector3.ZERO
		for unit_name: String in command["units"]:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null:
				middle += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		at = middle / maxf((command["units"] as Array).size(), 1.0)
	if at != null:
		_acks.append({"kind": kind, "position": at, "left": ACK_SECONDS})


# ---- Drawing ----------------------------------------------------------------------------------------------

func _draw() -> void:
	_draw_waypoints()
	_draw_acks()
	_draw_health()
	_draw_callouts()
	_draw_facing()
	_draw_order_marks()
	if _pause_text != "" and get_tree().paused:
		var font := CyberStyle.font()
		var text_size := roundi(22.0 * CyberStyle.ui_scale(size))
		var width := font.get_string_size(_pause_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var at := Vector2((size.x - width) / 2.0, size.y * 0.14)
		draw_rect(Rect2(at - Vector2(16, text_size * 1.1), Vector2(width + 32, text_size * 1.6)), Color(CyberStyle.CARD, 0.85))
		draw_string(font, at, _pause_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, CyberStyle.YELLOW)
	if mode != "":
		var mouse := get_local_mouse_position()
		var font := get_theme_default_font()
		draw_string_outline(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		draw_string(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, _order_color(mode))
	if _boxing and _press_at != null:
		var rect := Rect2(_press_at, _box_now - (_press_at as Vector2)).abs()
		var color: Color = GameTheme.ui["friendly"]
		draw_rect(rect, Color(color, 0.12))
		draw_rect(rect, Color(color, 0.9), false, 1.5)


## X5: words over our vehicles that nav reports as yielding or blocked, so a unit waiting its turn reads as waiting,
## not as ignoring the order: [{"unit", "at": Vector2 (screen), "word"}].
func callouts() -> Array:
	var result: Array = []
	if game_match == null or camera == null:
		return result
	var refused := {}
	for refusal: Dictionary in order_refusals():
		refused[refusal["unit"]] = refusal["why"]
	var screen := Rect2(Vector2.ZERO, size)
	for tank in game_match.sorted_team_tanks(team):
		if not tank.is_alive():
			continue
		# Round 8: an order not carried out outranks how the unit is moving.
		var word := String(refused.get(String(tank.name), ""))
		if word == "" and movement.provider.is_valid():
			word = movement.callout(String(tank.name))
		if word == "":
			continue
		var hull: Array = Units.stat(tank.unit_id, "hull_size")
		var top := Shown.at(tank) + Vector3.UP * (float(hull[1]) + BAR_ABOVE_M * 2.2)
		if camera.is_position_behind(top):
			continue
		var at := camera.unproject_position(top)
		if at.is_finite() and screen.has_point(at):
			result.append({"unit": String(tank.name), "at": at, "word": word})
	return result


func _draw_callouts() -> void:
	var font := CyberStyle.font()
	# On a dark plate, like the order pin's label: bare 12 px red on the arena floor was unreadable at the lead's 21°.
	var px := roundi(14.0 * CyberStyle.ui_scale(size))
	for callout: Dictionary in callouts():
		var word := String(callout["word"])
		var text_size := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var plate := Rect2(callout["at"] - Vector2(text_size.x / 2.0 + 5.0, text_size.y + 3.0), text_size + Vector2(10.0, 6.0))
		var color: Color = CyberStyle.YELLOW if word == "YIELDING" else GameTheme.ui["enemy"]
		draw_rect(plate, Color(0, 0, 0, 0.65))
		draw_rect(plate, Color(color, 0.8), false, 1.0)
		draw_string(font, plate.position + Vector2(5.0, 3.0 + font.get_ascent(px)), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## Round 7: orders you can see surviving the weave. nav and squad measured most of a unit's churn under an order as the
## evasion the lead asked for (jinking, strafing inside one decision), which can read as a unit that forgot its order.
## So for the selection, each order stays on screen until done: a ground ring at the ordered point in the verb's colour,
## the task's own symbol above it (the card's and the preview's), a lead line from the group, and "2/3 there".
## A squad on a task shows the TASK the player gave (Screen), not its leader's moves.
const ORDER_ARRIVED_M := 8.0
## Round 8: an order that isn't being carried out says so. The lead: "they don't obey and instead they shoot at whatever
## they were already shooting at" - learned by watching turrets. A gun gets this long to come round onto an ordered
## target before the unit is called out, with why: FIRING ON <what it is really shooting>, CAN'T SEE TARGET, NOT FIRING.
const COMPLY_GRACE_S := 2.0
## What a unit's gun is actually on (OrderExecutor.engaged_target_of, set by the mode). Unset: read the unit's brain.
var engaged_of: Callable
## unit name -> seconds its current attack order has gone unmet, and why.
var _unmet := {}
const ORDER_MARK_PX := 34.0
const ORDER_VERB_NAMES := {"move": "MOVE", "attack_move": "ATTACK-MOVE", "attack": "ATTACK", "follow": "FOLLOW",
		"hold": "HOLD", "screen": "SCREEN", "support_by_fire": "SUPPORT BY FIRE", "ambush": "AMBUSH"}


## What `unit_name`'s gun is on, whoever drives it.
func engaged_target(unit_name: String) -> String:
	if engaged_of.is_valid():
		return String(engaged_of.call(unit_name))
	var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
	return brain.engaged_target if brain != null else ""


## Why `unit_name` is not carrying out its attack order right now, or "" when it is (or is still closing to range).
func attack_shortfall(unit_name: String, order: Dictionary) -> String:
	var target := game_match.tanks.get_node_or_null(NodePath(String(order.get("target", "")))) as Tank
	var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	if target == null or not target.is_alive() or tank == null:
		return ""
	var engaged := engaged_target(unit_name)
	if engaged == String(target.name):
		return ""
	if engaged != "":
		var other := game_match.tanks.get_node_or_null(NodePath(engaged)) as Tank
		var what := String(Units.stat(other.unit_id, "display_name", other.unit_id)).to_upper() if other != null else engaged
		return "FIRING ON %s" % what
	if not game_match.is_visible_to(team, target):
		return "CAN'T SEE TARGET"
	var out_of_range := tank.global_position.distance_to(target.global_position) > float(tank.weapon.get("range", 0.0))
	if out_of_range and tank.estimated_velocity.length() > 0.5:
		return ""  # closing in: that is the order being carried out
	return "NOT FIRING"


## The target the PLAYER told `unit_name` to attack, or "": its own attack order, else its squad's attack task (a
## whole squad selected + right-click on an enemy is a task, and its leader decides who shoots - the lead's gesture).
func attack_intent(unit_name: String) -> String:
	var order := orders.current(unit_name)
	if String(order.get("verb", "")) == "attack":
		return String(order.get("target", ""))
	var element := elements.of(unit_name) if elements != null else null
	if element != null and String(element.task.get("verb", "")) == "attack":
		return String(element.task.get("target", ""))
	return ""


func _update_compliance(delta: float) -> void:
	if orders == null:
		return
	for tank in game_match.sorted_team_tanks(team):
		var unit_name := String(tank.name)
		var target := attack_intent(unit_name) if tank.is_alive() else ""
		var why := attack_shortfall(unit_name, {"target": target}) if target != "" else ""
		if why == "":
			_unmet.erase(unit_name)
		else:
			_unmet[unit_name] = {"s": float((_unmet.get(unit_name, {}) as Dictionary).get("s", 0.0)) + delta, "why": why,
					"target": target}


## [{"unit", "why", "target"}]: units whose attack order has gone unmet past COMPLY_GRACE_S. The reason is read fresh,
## so a gun that has just come round is not called out for a frame after.
func order_refusals() -> Array:
	var result: Array = []
	var names := _unmet.keys()
	names.sort()
	for unit_name: String in names:
		var entry: Dictionary = _unmet[unit_name]
		if float(entry["s"]) < COMPLY_GRACE_S:
			continue
		var why := attack_shortfall(unit_name, {"target": attack_intent(unit_name)})
		if why != "":
			result.append({"unit": unit_name, "why": why, "target": entry["target"]})
	return result


## [{"verb", "point": Vector3, "units": int, "arrived": int, "from": Vector3 (the group's middle), "task": bool}] for
## the selection. Runs every frame: one node lookup and one order read per unit (budgeted in test_control_scale).
func order_marks() -> Array:
	var result: Array = []
	if game_match == null or orders == null or selection.units.is_empty():
		return result
	var element := selected_element()
	var task_target := game_match.tanks.get_node_or_null(NodePath(String(element.task.get("target", "")))) as Tank \
			if element != null and String(element.task.get("verb", "")) == "attack" else null
	if task_target != null and task_target.is_alive():
		var aimed := {"verb": "attack", "task": true, "target": String(task_target.name),
				"point": Vector3(task_target.global_position.x, 0.0, task_target.global_position.z)}
		for unit_name in element.members():
			_count_into(aimed, String(unit_name), orders.current(String(unit_name)))
		result.append(_finish_mark(aimed))
		return result
	if element != null and not element.task.is_empty() and element.task.has("to"):
		var to: Array = element.task["to"]
		var verb := String(element.task.get("verb", ""))
		if verb == "move" and bool(element.task.get("drills", true)):
			verb = "attack_move"  # a move task with drills is what the player asked for as attack-move
		var mark := {"verb": verb, "point": Vector3(float(to[0]), 0.0, float(to[1])), "task": true}  # a task with a place
		for unit_name in element.members():
			_count_into(mark, String(unit_name), orders.current(String(unit_name)))
		result.append(_finish_mark(mark))
		return result
	var by_order := {}
	var ids: Array = []
	for unit_name in selection.units:
		var order := orders.current(unit_name)
		var aimed := String(order.get("verb", "")) == "attack"
		var target := game_match.tanks.get_node_or_null(NodePath(String(order.get("target", "")))) as Tank if aimed else null
		if not order.has("to") and target == null:
			continue
		var id := int(order.get("id", -1))
		if not by_order.has(id):
			ids.append(id)
			var point := Vector3(target.global_position.x, 0.0, target.global_position.z) if target != null \
					else Vector3(float(order["to"][0]), 0.0, float(order["to"][1]))
			by_order[id] = {"verb": String(order["verb"]), "point": point, "task": false}
			if target != null:
				by_order[id]["target"] = String(target.name)
		_count_into(by_order[id], unit_name, order)
	ids.sort()
	for id in ids:
		result.append(_finish_mark(by_order[id]))
	return result


func _count_into(mark: Dictionary, unit_name: String, order: Dictionary) -> void:
	var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	if tank == null or not tank.is_alive():
		return
	var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	mark["units"] = int(mark.get("units", 0)) + 1
	mark["from"] = (mark.get("from", Vector3.ZERO) as Vector3) + at
	if mark.has("target"):
		# An attack pin counts the guns that are really on its target (round 8), not who has arrived anywhere.
		if engaged_target(unit_name) == String(mark["target"]):
			mark["arrived"] = int(mark.get("arrived", 0)) + 1
		elif _unmet.has(unit_name) and float(_unmet[unit_name]["s"]) >= COMPLY_GRACE_S:
			mark["refusing"] = int(mark.get("refusing", 0)) + 1
		return
	var goal: Variant = Orders.goal_of(order, game_match) if not order.is_empty() else null
	var target: Vector3 = goal if goal is Vector3 else mark["point"]
	if order.is_empty() or at.distance_to(target) <= ORDER_ARRIVED_M:
		mark["arrived"] = int(mark.get("arrived", 0)) + 1


func _finish_mark(mark: Dictionary) -> Dictionary:
	mark["units"] = int(mark.get("units", 0))
	mark["arrived"] = int(mark.get("arrived", 0))
	mark["from"] = (mark.get("from", Vector3.ZERO) as Vector3) / maxf(mark["units"], 1.0)
	return mark


## "SCREEN · 2/3 there · 40 m" - what the marker says under its symbol.
func order_mark_label(mark: Dictionary) -> String:
	var words := String(ORDER_VERB_NAMES.get(mark["verb"], String(mark["verb"]).to_upper()))
	if mark.has("target"):
		var line := "%s · %d/%d on target" % [words, mark["arrived"], mark["units"]]
		return line + (" · %d NOT COMPLYING" % int(mark["refusing"]) if int(mark.get("refusing", 0)) > 0 else "")
	var left := (mark["from"] as Vector3).distance_to(mark["point"])
	if int(mark["arrived"]) >= int(mark["units"]):
		return "%s · there" % words
	return "%s · %d/%d there · %d m" % [words, mark["arrived"], mark["units"], roundi(left)]


func _draw_order_marks() -> void:
	var font := CyberStyle.font()
	var scale := CyberStyle.ui_scale(size)
	var px := roundi(14.0 * scale)
	var glyph_px := ORDER_MARK_PX * scale
	for mark: Dictionary in order_marks():
		var color := _order_color(String(mark["verb"]))
		if int(mark.get("refusing", 0)) > 0:
			color = GameTheme.ui["enemy"]  # an order not being carried out turns its pin red
		var at: Variant = _screen_point(mark["point"])
		if at == null:
			continue
		_draw_ground_ring(mark["point"], 6.0, Color(color, 0.8), 2.0)
		var from: Variant = _screen_point(mark["from"])
		# Direct orders already have each unit's dashed line (_draw_waypoints); a squad task gets one from its middle.
		if bool(mark.get("task", false)) and from != null and int(mark["arrived"]) < int(mark["units"]):
			draw_line(from, at, Color(color, 0.35), 1.5)
		# A pin: a stalk up from the ring to the task's symbol on a dark disc, readable over any ground at 21°.
		var head := (at as Vector2) - Vector2(0.0, glyph_px * 1.6)
		draw_line(at, head + Vector2(0.0, glyph_px * 0.5), Color(color, 0.7), 2.0)
		draw_circle(head, glyph_px * 0.62, Color(0, 0, 0, 0.6))
		draw_arc(head, glyph_px * 0.62, 0.0, TAU, 32, Color(color, 0.9), 1.5, true)
		var verb := String(mark["verb"])
		if CommandIcons.has_task_graphic(verb):
			draw_texture_rect(CommandIcons.task_texture(verb), Rect2(head - Vector2.ONE * glyph_px * 0.42, Vector2.ONE * glyph_px * 0.84), false, color)
		var label := order_mark_label(mark)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var plate := Rect2(head + Vector2(glyph_px * 0.8, -text_size.y * 0.5 - 3.0), text_size + Vector2(10.0, 6.0))
		draw_rect(plate, Color(0, 0, 0, 0.6))
		draw_string(font, plate.position + Vector2(5.0, 3.0 + font.get_ascent(px)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## Round 7 (A): which way each selected vehicle points - a chevron on the ground ahead of its hull - and, for a gun that
## cannot traverse all round, the edges of its fire arc. The lead: "has a good understanding of the orientation of the
## vehicle, which should be an important thing (i.e. trying to emplace units in an ambush)".
const FACING_ARROW_M := 7.0
const ARC_SHOWN_M := 16.0


func facing_marks() -> Array:
	var result: Array = []
	if game_match == null or camera == null:
		return result
	for unit_name in selection.units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		var at := Shown.ground(tank)
		var forward := -tank.global_basis.z
		forward.y = 0.0
		if forward.length() < 0.001:
			continue
		forward = forward.normalized()
		var mark := {"unit": unit_name, "from": at, "to": at + forward * FACING_ARROW_M, "arc": []}
		if tank.fire_arc_deg < 300.0:
			var half := deg_to_rad(tank.fire_arc_deg / 2.0)
			mark["arc"] = [at + forward.rotated(Vector3.UP, half) * ARC_SHOWN_M, at + forward.rotated(Vector3.UP, -half) * ARC_SHOWN_M]
		result.append(mark)
	return result


func _draw_facing() -> void:
	var color: Color = GameTheme.ui["friendly"]
	for mark: Dictionary in facing_marks():
		var a: Variant = _screen_point(mark["from"])
		var b: Variant = _screen_point(mark["to"])
		if a == null or b == null:
			continue
		var tip: Vector2 = b
		var direction := (tip - (a as Vector2)).normalized()
		if direction.length() < 0.5:
			continue
		var side := Vector2(-direction.y, direction.x)
		draw_line(a, tip, Color(color, 0.85), 2.0)
		draw_colored_polygon(PackedVector2Array([tip + direction * 7.0, tip + side * 5.0, tip - side * 5.0]), Color(color, 0.95))
		for edge: Vector3 in mark["arc"]:
			var e: Variant = _screen_point(edge)
			if e != null:
				draw_dashed_line(a, e, Color(color, 0.45), 1.5, 5.0)


## X6: a thin hull bar (and a shield sliver above it) over vehicles that are hurt or selected.
func _draw_health() -> void:
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	for bar: Dictionary in health_bars():
		var width: float = bar["width"]
		var at: Vector2 = bar["at"]
		var box := Rect2(at - Vector2(width / 2.0, 0.0), Vector2(width, BAR_HEIGHT_PX))
		draw_rect(box.grow(1.0), Color(0, 0, 0, 0.65))
		var health: float = bar["health"]
		# Red as it gets serious, so a glance across the field finds the vehicle about to die.
		var ink := friendly.lerp(enemy, clampf(1.0 - health, 0.0, 1.0))
		draw_rect(Rect2(box.position, Vector2(box.size.x * health, box.size.y)), ink)
		var shield: float = bar["shield"]
		if shield > 0.001:
			var strip := Rect2(box.position - Vector2(0.0, BAR_HEIGHT_PX * 0.75), Vector2(box.size.x * shield, BAR_HEIGHT_PX * 0.55))
			draw_rect(strip, Color(CyberStyle.CYAN, 0.9))


## Marker colors by verb: moves in the team color, attacks in the enemy color, attack-moves in the commander gold.
func _order_color(verb: String) -> Color:
	match verb:
		"attack":
			return GameTheme.ui["enemy"]
		"attack_move":
			return GameTheme.ui["commander"]
	return GameTheme.ui["friendly"]


## Selected units' routes: a line from each unit through its current and queued stops, a small mark at each stop.
func _draw_waypoints() -> void:
	for unit_name in selection.units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var route := waypoints(unit_name)
		if tank == null or route.is_empty():
			continue
		var from := Shown.ground(tank)
		# X5: the way nav means to drive there (N1 `path_points`), faint under the order line, so "why is it going
		# that way" has an answer on screen. Absent until nav's Movement is wired in.
		var path := movement.route(unit_name)
		if path.size() >= 1:
			var at: Variant = _screen_point(from)
			for point: Vector3 in path:
				var next: Variant = _screen_point(point)
				if at != null and next != null:
					draw_line(at, next, Color(_order_color(String(route[0]["kind"])), 0.3), 1.0)
				at = next
		for stop: Dictionary in route:
			var to: Vector3 = stop["position"]
			var color := _order_color(stop["kind"])
			var a: Variant = _screen_point(from)
			var b: Variant = _screen_point(to)
			if a != null and b != null:
				draw_dashed_line(a, b, Color(color, 0.55), 1.5, 8.0)
				draw_circle(b, 3.0, Color(color, 0.8))
			from = to


## Order acknowledgements: a ring on the ground that shrinks onto the spot as it fades.
func _draw_acks() -> void:
	for ack: Dictionary in _acks:
		var t := clampf(float(ack["left"]) / ACK_SECONDS, 0.0, 1.0)
		_draw_ground_ring(ack["position"], lerpf(1.0, 4.0, t), Color(_order_color(ack["kind"]), t), 2.5)


func _draw_ground_ring(center: Vector3, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * i / 24.0
		var world := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var at: Variant = _screen_point(world)
		if at == null:
			return
		points.append(at)
	draw_polyline(points, color, width, true)


## Where a ground point is on screen, or null when it can't be drawn sensibly: behind the camera, not finite (a camera
## not set up yet unprojects to NaN), or far off screen (points near the camera plane project 30k–100k px out, where
## the renderer loses precision: main 8dbe23e, the army-loop-smoke triangulation flake).
func _screen_point(world: Vector3) -> Variant:
	if camera == null or camera.is_position_behind(world):
		return null
	var at := camera.unproject_position(world)
	if not at.is_finite() or not Rect2(Vector2.ZERO, size).grow(OFF_SCREEN_PX).has_point(at):
		return null
	return at


## A player-facing summary of a command for the HUD ("Tank: attack-move", "3 units: follow Scout").
func describe(command: Dictionary) -> String:
	var units: Array = command.get("units", [])
	var who := "%d units" % units.size()
	if units.size() == 1:
		who = _unit_label(String(units[0]))
	var words: String = {"move": "move", "attack": "attack", "attack_move": "attack-move", "follow": "follow",
			"hold": "hold position", "stop": "stop"}.get(command.get("verb", ""), "?")
	if command.has("target"):
		words += " " + _unit_label(String(command["target"]))
	if command.get("queue", false) and command.get("verb") != "stop":
		words += " (queued)"
	return "%s: %s" % [who, words]


func _unit_label(unit_name: String) -> String:
	var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	if tank == null:
		return unit_name
	return ("%s %s" % ["enemy" if tank.team != team else "", String(Units.stat(tank.unit_id, "display_name", tank.unit_id))]).strip_edges()


func _draw_overlay() -> void:
	if mode != "":
		var mouse := _overlay.get_local_mouse_position()
		var font := get_theme_default_font()
		_overlay.draw_string_outline(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		_overlay.draw_string(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, _order_color(mode))
	_draw_tooltip(_overlay)


func _draw_tooltip(canvas: Control) -> void:
	var tip := tooltip()
	if tip.is_empty():
		return
	var font := CyberStyle.font()
	var s := CyberStyle.ui_scale(size)
	var title_size := roundi(17.0 * s)
	var line_size := roundi(14.0 * s)
	var lines: Array = tip["lines"]
	var width := font.get_string_size(tip["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x)
	var box := Rect2(_hover_at + Vector2(18, 18), Vector2(width + 20.0 * s, title_size * 1.6 + lines.size() * line_size * 1.35 + 8.0 * s))
	box.position.x = minf(box.position.x, size.x - box.size.x - 4.0)
	box.position.y = minf(box.position.y, size.y - box.size.y - 4.0)
	var accent: Color = GameTheme.ui["enemy"] if tip["enemy"] else GameTheme.ui["friendly"]
	canvas.draw_rect(box, Color(CyberStyle.HUD_BACKGROUND, 0.92))
	canvas.draw_rect(box, Color(accent, 0.8), false, 1.5)
	var y := box.position.y + title_size * 1.2
	canvas.draw_string(font, Vector2(box.position.x + 10.0 * s, y), tip["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, accent)
	for line: String in lines:
		y += line_size * 1.35
		canvas.draw_string(font, Vector2(box.position.x + 10.0 * s, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, CyberStyle.TEXT)
