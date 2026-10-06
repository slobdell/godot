class_name ScoreBug
extends Control
## Round 19 (board, S2): the score bug, like a broadcast's, top centre. The lead (2026-10-05): *"there's very little
## indication that holding the center is what scores points, or that standing in the ring scores points"* -- so the
## bug is first of all an INDICATOR: each side's meter to the win (FIRST TO 90) with its points, the zones as lit chips
## named the way the map names them (a capture fills the chip in the colour of whoever stands in it), the meter's edge
## live while a side is scoring with a "+1" off the number each point, and a lower-third the moment a zone changes
## hands. Kills and the credits destroyed sit small under the meter ("one army eventually dies").
##
## Reads `Match.score_snapshot()` only (contract C19.4), redraws on `score_changed` and while an animation runs, and
## sleeps otherwise (`set_process(false)`): nothing here is per unit or per frame at rest. Visual only.

## The bug's size at 1080p; HudSkin places it and scales it by CyberStyle.ui_scale.
const SIZE_1080 := Vector2(780.0, 132.0)
## How long the lower-third ("CONDEMNED TAKE THE WEST RING") stays up, and the "+1" pop and the number flash last.
const FLARE_SECONDS := 3.6
const POP_SECONDS := 0.7
const FLASH_SECONDS := 0.5
## The points left at which a scoring side's number runs hot (the final seconds).
const CLOSING_POINTS := 15

## The team whose side is drawn on the LEFT and in the friendly colour (the local player's).
var team := Match.Team.GREEN
var game_match: Match:
	set(value):
		if game_match == value:
			return
		if game_match != null and game_match.score_changed.is_connected(set_snapshot):
			game_match.score_changed.disconnect(set_snapshot)
		game_match = value
		if game_match != null:
			game_match.score_changed.connect(set_snapshot)
			set_snapshot(game_match.score_snapshot())

var snapshot: Dictionary = {}
## The kit's type (C19.5, `_agents/ui_kit.md`): Share Tech Mono at the kit's named sizes.
var _font: Font = CyberStyle.font()
## Each side's faction crest (the kit's CyberCrest), left then right: the faction's colour marks the faction, the slab
## and the meter the team.
var _crests: Array[CyberCrest] = []
## Per side (by team): the points as shown (they roll up to the real value), the credits as shown, the seconds left
## on the "+1" pop and on the number's flash.
var _shown_points: Array[float] = [0.0, 0.0]
var _shown_credits: Array[float] = [0.0, 0.0]
var _pop: Array[float] = [0.0, 0.0]
var _flash: Array[float] = [0.0, 0.0]
var _kill_flash: Array[float] = [0.0, 0.0]
## The "+240 CR" off the credits on a kill: [amount, seconds left] per side.
var _credit_pop := [[0, 0.0], [0, 0.0]]
## How big the last kill's celebration is (1 an ordinary kill .. 3 a ghastly one), from the booth's cue.
var _scale: Array[float] = [1.0, 1.0]
## The lower-third: {text, team, left} (left = seconds), or empty.
var _flare: Dictionary = {}
var _lead_flare := 0.0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	for i in 2:
		var crest := CyberCrest.new()
		crest.name = "Crest%d" % i
		crest.visible = false
		_crests.append(crest)
		add_child(crest)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_crests()


## The crests sit at the outer ends, inside the team slabs, square to the name's line.
func _place_crests() -> void:
	var s := size.y / SIZE_1080.y
	var side := 46.0 * s
	for slot in 2:
		var crest := _crests[slot]
		crest.size = Vector2(side, side)
		crest.position = Vector2(18.0 * s if slot == 0 else size.x - 18.0 * s - side, 8.0 * s)
		if snapshot.is_empty():
			crest.visible = false
			continue
		var faction := String(snapshot["sides"][team if slot == 0 else 1 - team]["faction"])
		crest.faction = faction
		crest.visible = faction != ""


## A new snapshot: what changed starts its animation. Safe to call with the same snapshot twice.
func set_snapshot(snap: Dictionary) -> void:
	var previous := snapshot
	snapshot = snap
	if snap.is_empty():
		queue_redraw()
		return
	var sides: Array = snap["sides"]
	if previous.is_empty():
		for t in 2:
			_shown_points[t] = float(sides[t]["points"])
			_shown_credits[t] = float(sides[t]["points_destroyed"])
	else:
		var before: Array = previous["sides"]
		for t in 2:
			if int(sides[t]["points"]) > int(before[t]["points"]):
				_pop[t] = POP_SECONDS
				_flash[t] = FLASH_SECONDS
			if int(sides[t]["kills"]) > int(before[t]["kills"]):
				_kill_flash[t] = FLASH_SECONDS * 2.0
			if int(sides[t]["points_destroyed"]) > int(before[t]["points_destroyed"]):
				_credit_pop[t] = [int(sides[t]["points_destroyed"]) - int(before[t]["points_destroyed"]), POP_SECONDS * 1.6]
		_flare_for(previous, snap)
		if int(snap["leader"]) >= 0 and int(snap["leader"]) != int(previous["leader"]) and int(previous["leader"]) >= 0:
			_lead_flare = FLARE_SECONDS
			if _flare.is_empty():
				_flare = {"text": "LEAD CHANGE: %s IN FRONT" % sides[int(snap["leader"])]["name"],
						"team": int(snap["leader"]), "left": FLARE_SECONDS}
	_place_crests()
	_wake()
	queue_redraw()


## The lower-third for a zone changing hands: taken, lost to neutral. The first change in a snapshot wins.
func _flare_for(previous: Dictionary, snap: Dictionary) -> void:
	var was: Array = previous["objectives"]
	var now: Array = snap["objectives"]
	if was.size() != now.size():
		return
	for i in now.size():
		var before := int(was[i]["owner"])
		var after := int(now[i]["owner"])
		if before == after:
			continue
		var zone := String(now[i]["label"]).to_upper()
		if after >= 0:
			var name := String(snap["sides"][after]["name"])
			_flare = {"text": "%s TAKE %s  ·  SCORING" % [name, zone], "team": after, "left": FLARE_SECONDS}
		else:
			_flare = {"text": "%s IS NEUTRAL" % zone, "team": before, "left": FLARE_SECONDS}
		return


## Round 19 (board, S3): the booth's cue as it starts (AnnouncerBooth.line_started). A kill the booth calls ghastly
## (its moment tags: a streak, a rear or engine-deck shot, a side's last unit, an upset, first blood) gets the
## broadcast's graphic on the bug, in the colour of the side that did it, and the kill's flash and credits pop grow
## with the call's intensity. The words stay the booth's (the caption line); the bug shows the stat, as a broadcast
## does, played straight.
func on_cue(cue: Dictionary) -> void:
	if snapshot.is_empty() or String(cue.get("moment", "")) not in ["kill", "big_hit"]:
		return
	var t := ["green", "rust"].find(String(cue.get("team", "")))
	if t < 0:
		return
	var tags: Array = ((cue.get("_moment", {}) as Dictionary).get("tags", []) as Array)
	var text := stinger(tags, cue.get("slots", {}) as Dictionary, String(snapshot["sides"][t]["name"]),
			String(snapshot["sides"][1 - t]["name"]))
	_scale[t] = 1.0 + 0.25 * float(clampi(int(cue.get("intensity", 1)), 1, 3) - 1)
	_kill_flash[t] = maxf(_kill_flash[t], FLASH_SECONDS * 2.0 * _scale[t])
	if text != "" and (_flare.is_empty() or not String(_flare["text"]).contains("TAKE")):
		_flare = {"text": text, "team": t, "left": FLARE_SECONDS}
	_wake()
	queue_redraw()


## The graphic for a kill's moment tags, most remarkable first ("" for an ordinary kill). Pure.
static func stinger(tags: Array, slots: Dictionary, side: String, other: String) -> String:
	if tags.has("final_kill"):
		return ""  # the match is over: the VICTORY banner has it
	if tags.has("streak"):
		return "%s: %d STRAIGHT KILLS" % [side, int(slots.get("streak", 3))]
	if tags.has("last_unit"):
		return "%s DOWN TO THEIR LAST VEHICLE" % other
	if tags.has("rear"):
		return "%s: KILL FROM BEHIND" % side
	if tags.has("weak_spot"):
		return "%s: ENGINE DECK, CLEAN KILL" % side
	if tags.has("upset"):
		return "UPSET: %s" % side
	if tags.has("comeback"):
		return "%s ARE BACK IN IT" % side
	if tags.has("first_blood"):
		return "FIRST BLOOD: %s" % side
	return ""


func _wake() -> void:
	set_process(true)


func is_animating() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	var started := HudClock.begin()
	_animate(delta)
	HudClock.end(&"score_bug.process", started)


func _animate(delta: float) -> void:
	_clock += delta
	var busy := false
	if not snapshot.is_empty():
		for t in 2:
			var side: Dictionary = snapshot["sides"][t]
			_shown_points[t] = move_toward(_shown_points[t], float(side["points"]), delta * maxf(6.0, absf(float(side["points"]) - _shown_points[t]) * 4.0))
			_shown_credits[t] = move_toward(_shown_credits[t], float(side["points_destroyed"]), delta * maxf(400.0, absf(float(side["points_destroyed"]) - _shown_credits[t]) * 3.0))
			_pop[t] = maxf(0.0, _pop[t] - delta)
			_flash[t] = maxf(0.0, _flash[t] - delta)
			_kill_flash[t] = maxf(0.0, _kill_flash[t] - delta)
			_credit_pop[t][1] = maxf(0.0, float(_credit_pop[t][1]) - delta)
			busy = busy or float(_credit_pop[t][1]) > 0.0
			if _kill_flash[t] <= 0.0:
				_scale[t] = 1.0
			busy = busy or _pop[t] > 0.0 or _flash[t] > 0.0 or _kill_flash[t] > 0.0 \
					or _shown_points[t] != float(side["points"]) or _shown_credits[t] != float(side["points_destroyed"])
			# A side that is scoring keeps its meter's edge alive (a slow breath), and the number hot near the end.
			busy = busy or float(side["rate"]) > 0.0
		for zone: Dictionary in snapshot["objectives"]:
			busy = busy or bool(zone.get("contested", false))
	if not _flare.is_empty():
		_flare["left"] = float(_flare["left"]) - delta
		if float(_flare["left"]) <= 0.0:
			_flare = {}
	_lead_flare = maxf(0.0, _lead_flare - delta)
	busy = busy or not _flare.is_empty() or _lead_flare > 0.0
	queue_redraw()
	if not busy:
		set_process(false)


func side_color(side_team: int) -> Color:
	return GameTheme.ui["friendly"] if side_team == team else GameTheme.ui["enemy"]


func _draw() -> void:
	var started := HudClock.begin()
	_draw_bug()
	HudClock.end(&"score_bug.draw", started)


func _draw_bug() -> void:
	if snapshot.is_empty():
		return
	var s := size.y / SIZE_1080.y
	var w := size.x
	var mono := CyberStyle.font()
	var sides: Array = snapshot["sides"]
	var control := bool(snapshot["control"])
	var to_win := int(snapshot["points_to_win"])
	# The panel: one chamfered card, the kit's fill, a thin rule in each side's colour along its half.
	var main_h := 92.0 * s
	var outline := CyberFrame.chamfer_polygon(Rect2(0, 0, w, main_h), 14.0 * s)
	draw_colored_polygon(outline, Color(CyberStyle.HUD_BACKGROUND, 0.82))
	var centre_w := 132.0 * s
	var half_w := (w - centre_w) / 2.0
	var order := [team, 1 - team]  # left, right
	for slot in 2:
		var t: int = order[slot]
		var side: Dictionary = sides[t]
		var colour := side_color(t)
		var left := slot == 0
		var x0 := 0.0 if left else half_w + centre_w
		var block := Rect2(x0, 0, half_w, main_h)
		var lead := int(snapshot["leader"]) == t
		# The side's colour bar on the outer edge, like a broadcast's team slab.
		var slab := Rect2(x0 if left else w - 10.0 * s, 0, 10.0 * s, main_h)
		draw_rect(slab, Color(colour, 0.9))
		# Name.
		var name_px := roundi(CyberKit.HEADING * s)
		var name := String(side["name"])
		var inset := (22.0 + (54.0 if String(side["faction"]) != "" else 0.0)) * s
		var name_x := x0 + inset if left else w - inset - _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
		draw_string(_font, Vector2(name_x, 36.0 * s), name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, CyberStyle.WHITE)
		# Points, big, at the inner edge (next to the centre column).
		var points_text := str(roundi(_shown_points[t])) if control else str(int(side["kills"]))
		var points_px := roundi(CyberKit.TITLE * s * (1.0 + 0.18 * _bump(_flash[t] / FLASH_SECONDS)))
		var hot := control and float(side["rate"]) > 0.0 and int(side["to_win"]) <= CLOSING_POINTS
		var points_colour := CyberStyle.WHITE.lerp(colour, clampf(_flash[t] / FLASH_SECONDS, 0.0, 1.0))
		if hot:
			points_colour = CyberStyle.YELLOW.lerp(CyberStyle.WHITE, 0.5 + 0.5 * sin(_clock * 8.0))
		var pw := _font.get_string_size(points_text, HORIZONTAL_ALIGNMENT_LEFT, -1, points_px).x
		var px := x0 + half_w - 14.0 * s - pw if left else x0 + 14.0 * s
		draw_string(_font, Vector2(px, 58.0 * s + (points_px - CyberKit.TITLE * s) * 0.35), points_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, points_px, points_colour)
		if _pop[t] > 0.0:
			var k := 1.0 - _pop[t] / POP_SECONDS
			draw_string(_font, Vector2(px + pw * 0.5 - 12.0 * s, 20.0 * s - k * 22.0 * s), "+1",
					HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(CyberKit.BODY * s), Color(colour, 1.0 - k))
		# The meter to the win: fills from the outer edge toward the centre column.
		if control:
			var meter := Rect2(x0 + 22.0 * s, 70.0 * s, half_w - 44.0 * s - pw * 0.0 - 56.0 * s, 12.0 * s)
			if not left:
				meter.position.x = x0 + half_w - 22.0 * s - meter.size.x
			# The kit's meter shape (CyberMeter: a chamfered bar at CyberKit.CUT), filling toward the centre column.
			var cut := minf(CyberKit.CUT * s * 0.6, meter.size.y * 0.5)
			draw_colored_polygon(CyberFrame.chamfer_polygon(meter, cut), Color(colour, 0.16))
			var fraction := clampf(_shown_points[t] / float(to_win), 0.0, 1.0)
			var filled := Rect2(meter.position, Vector2(meter.size.x * fraction, meter.size.y))
			if not left:
				filled.position.x = meter.end.x - filled.size.x
			if filled.size.x > 1.0:
				draw_colored_polygon(CyberFrame.chamfer_polygon(filled, minf(cut, filled.size.x * 0.5)), Color(colour, 0.95))
			for tick in range(10, to_win, 10):
				var tx := meter.position.x + meter.size.x * float(tick) / float(to_win)
				if not left:
					tx = meter.end.x - meter.size.x * float(tick) / float(to_win)
				draw_line(Vector2(tx, meter.position.y), Vector2(tx, meter.end.y), Color(CyberStyle.HUD_BACKGROUND, 0.8), maxf(1.0, 2.0 * s))
			if float(side["rate"]) > 0.0:
				# Scoring right now: the meter's edge breathes and a chevron runs along it toward the win.
				var edge_x := filled.end.x if left else filled.position.x
				var glow := 0.55 + 0.45 * sin(_clock * 6.0)
				draw_rect(Rect2(edge_x - 3.0 * s, meter.position.y - 4.0 * s, 6.0 * s, meter.size.y + 8.0 * s), Color(CyberStyle.WHITE, glow))
				var run := fposmod(_clock * 0.8, 1.0)
				var chevron_x := lerpf(edge_x, meter.end.x if left else meter.position.x, run)
				_chevron(Vector2(chevron_x, meter.get_center().y), 7.0 * s, left, Color(colour, 0.9 * (1.0 - run)))
			var rim := CyberFrame.chamfer_polygon(meter, cut)
			rim.append(rim[0])
			draw_polyline(rim, Color(colour, 0.6), maxf(1.0, 1.5 * s), true)
		# Lead marker: a small bar over the name.
		if lead:
			var lead_glow := 1.0 if _lead_flare <= 0.0 else 0.5 + 0.5 * sin(_clock * 14.0)
			# Along the panel's top edge over the leading side's half, like a broadcast's "possession" bar.
			draw_rect(Rect2(x0 + (10.0 * s if left else 0.0), 0.0, half_w - 10.0 * s, 4.0 * s), Color(colour, lead_glow))
		# Kills and credits destroyed, small, under the panel.
		var kills_text := "%d KILLS  ·  %s" % [int(side["kills"]), value_text(roundi(_shown_credits[t]))]
		var kills_px := roundi(CyberKit.SMALL * s)
		var kw := mono.get_string_size(kills_text, HORIZONTAL_ALIGNMENT_LEFT, -1, kills_px).x
		var kx := x0 + 22.0 * s if left else w - 22.0 * s - kw
		var kill_colour := Color(CyberStyle.TEXT, 0.85).lerp(colour, clampf(_kill_flash[t] / FLASH_SECONDS, 0.0, 1.0))
		draw_string(mono, Vector2(kx, main_h + 22.0 * s), kills_text, HORIZONTAL_ALIGNMENT_LEFT, -1, kills_px, kill_colour)
		if control and float(side["rate"]) > 0.0:
			# Said in words too, under the side's name (above its meter): this side is scoring right now.
			var rate := float(side["rate"])
			var tag := "SCORING  +%s/S" % ("1" if rate >= 1.0 else str(snappedf(rate, 0.01)))
			var tag_px := roundi(CyberKit.SMALL * s)
			var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_px).x
			var tx := name_x if left else w - inset - tw
			draw_string(_font, Vector2(tx, 60.0 * s), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_px,
					Color(colour, 0.75 + 0.25 * sin(_clock * 6.0)))
		if float(_credit_pop[t][1]) > 0.0:
			var k := 1.0 - float(_credit_pop[t][1]) / (POP_SECONDS * 1.6)
			var pop := "+" + value_text(int(_credit_pop[t][0]))
			var pop_px := roundi(CyberKit.SMALL * s * _scale[t])
			var pop_w := _font.get_string_size(pop, HORIZONTAL_ALIGNMENT_LEFT, -1, pop_px).x
			var pop_x := kx + kw + 10.0 * s if left else kx - pop_w - 10.0 * s
			draw_string(_font, Vector2(pop_x, main_h + 24.0 * s - k * 10.0 * s), pop, HORIZONTAL_ALIGNMENT_LEFT, -1,
					pop_px, Color(CyberStyle.YELLOW, 1.0 - k * k))
		var _unused := block
	# The centre column: the zones, as chips, each filling in the colour of whoever stands in it.
	_draw_centre(Rect2(half_w, 0, centre_w, main_h), s)
	# The outline over everything.
	var rim := outline.duplicate()
	rim.append(outline[0])
	draw_polyline(rim, Color(CyberStyle.BORDER_CYAN, 0.55), maxf(1.0, 2.0 * s), true)
	if not _flare.is_empty():
		_draw_flare(s, main_h)


func _draw_centre(rect: Rect2, s: float) -> void:
	var mono := CyberStyle.font()
	var control := bool(snapshot["control"])
	var caption := "FIRST TO %d" % int(snapshot["points_to_win"]) if control else "KILLS"
	var cap_px := roundi(CyberKit.MICRO * s)
	var cw := mono.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_px).x
	draw_string(mono, Vector2(rect.get_center().x - cw / 2.0, rect.position.y + 20.0 * s), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, cap_px, Color(CyberStyle.TEXT, 0.8))
	if not control:
		return
	var zones: Array = snapshot["objectives"]
	var count := zones.size()
	if count == 0:
		return
	# Chips side by side, ordered west to east so they sit where the zones are on the map (the left chip is the zone
	# on the left of a map seen from the south, the skirmish camera's default).
	var order := range(count)
	order.sort_custom(func(a: int, b: int) -> bool: return (zones[a]["position"] as Vector3).x < (zones[b]["position"] as Vector3).x)
	var gap := 8.0 * s
	var chip_w := minf(52.0 * s, (rect.size.x - 16.0 * s - gap * float(count - 1)) / float(count))
	var chip_h := 36.0 * s
	var total := chip_w * float(count) + gap * float(count - 1)
	var x := rect.get_center().x - total / 2.0
	var y := rect.position.y + 32.0 * s
	for i in order:
		var zone: Dictionary = zones[i]
		var chip := Rect2(x, y, chip_w, chip_h)
		var owner := int(zone["owner"])
		var progress := float(zone["progress"])
		var capturer := Match.Team.GREEN if progress > 0.0 else Match.Team.RUST
		draw_rect(chip, Color(CyberStyle.CARD, 0.95))
		# The capture fill rises from the bottom in the colour of whoever is taking (or holds) it.
		var fill := absf(progress)
		if fill > 0.0:
			var c := side_color(capturer)
			var a := 0.95 if owner == capturer else 0.55
			draw_rect(Rect2(chip.position.x, chip.end.y - chip.size.y * fill, chip.size.x, chip.size.y * fill), Color(c, a))
		var border := Color(1, 1, 1, 0.55) if owner < 0 else side_color(owner)
		if owner >= 0:
			# Held and scoring: the chip's rim breathes.
			border = Color(border, 0.7 + 0.3 * sin(_clock * 6.0))
		var contested := bool(zone.get("contested", false))
		if contested:
			# Both sides inside: the capture is frozen. A hard yellow rim, blinking, as a broadcast flags a stoppage.
			border = Color(CyberStyle.YELLOW, 1.0 if fposmod(_clock, 0.5) < 0.3 else 0.35)
		draw_rect(chip, border, false, maxf(1.0, (3.0 if contested else 2.0) * s))
		var letter := _zone_letter(String(zone["label"]), zones, i)
		var lp := roundi(CyberKit.BODY * s)
		var lw := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lp).x
		draw_string(_font, Vector2(chip.get_center().x - lw / 2.0, chip.get_center().y + lp * 0.36), letter,
				HORIZONTAL_ALIGNMENT_LEFT, -1, lp, CyberStyle.WHITE)
		x += chip_w + gap
	# The zones' names under the chips (the map's own words, short).
	var names: Array = []
	for i in order:
		names.append(_short_label(String(zones[i]["label"])))
	var line := "  ".join(names) if count > 1 else String(names[0])
	var np := roundi(CyberKit.MICRO * s)
	var nw := mono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, np).x
	if nw > rect.size.x + 40.0 * s:
		np = maxi(9, floori(np * (rect.size.x + 40.0 * s) / nw))
		nw = mono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, np).x
	draw_string(mono, Vector2(rect.get_center().x - nw / 2.0, y + chip_h + 15.0 * s), line, HORIZONTAL_ALIGNMENT_LEFT, -1, np,
			Color(CyberStyle.TEXT, 0.75))


## The lower-third, under the bug: a side-coloured slab with the moment in capitals, sliding open.
func _draw_flare(s: float, main_h: float) -> void:
	var t := int(_flare["team"])
	var colour := side_color(t)
	var left := float(_flare["left"])
	var open := clampf((FLARE_SECONDS - left) / 0.25, 0.0, 1.0) * clampf(left / 0.3, 0.0, 1.0)
	var text := String(_flare["text"])
	var px := roundi(CyberKit.BODY * s)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var box_w := (tw + 48.0 * s) * CyberStyle.decelerate(open)
	var box := Rect2(size.x / 2.0 - box_w / 2.0, main_h + 32.0 * s, box_w, 38.0 * s)
	if box_w < 4.0:
		return
	draw_colored_polygon(CyberFrame.chamfer_polygon(box, 9.0 * s), Color(colour, 0.88))
	if open >= 0.95:
		draw_string(_font, Vector2(size.x / 2.0 - tw / 2.0, box.position.y + 28.0 * s), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, px, CyberStyle.HUD_BACKGROUND)


func _chevron(at: Vector2, r: float, pointing_right: bool, colour: Color) -> void:
	var d := 1.0 if pointing_right else -1.0
	draw_polyline(PackedVector2Array([at + Vector2(-r * 0.5 * d, -r), at + Vector2(r * 0.5 * d, 0), at + Vector2(-r * 0.5 * d, r)]),
			colour, maxf(1.0, r * 0.35), true)


## A chip's letter: the first letter of the zone's distinguishing word ("the west ring" → W, "the east ring" → E);
## "C" for the centre; a number when two would share a letter.
static func _zone_letter(label: String, zones: Array, index: int) -> String:
	var words := label.trim_prefix("the ").split(" ")
	var letter := words[0].left(1).to_upper() if not words.is_empty() and words[0] != "" else str(index + 1)
	for j in zones.size():
		if j != index:
			var other := String(zones[j]["label"]).trim_prefix("the ").split(" ")
			if not other.is_empty() and other[0].left(1).to_upper() == letter:
				return str(index + 1)
	return letter


## "the west ring" → "WEST RING".
static func _short_label(label: String) -> String:
	return label.trim_prefix("the ").to_upper()


## What `points` of destroyed vehicles read as: credits ("40 CR") through the garage's Credits once its prices are in
## the build (CP3; C19.4: the snapshot stays in points, the rules' unit), a bare number before (no unit word).
static func value_text(points: int) -> String:
	var credits := _credits_script()
	if credits != null:
		return "%s CR" % _thousands(int(credits.call("of_points", points)))
	return _thousands(points)


static var _credits: Script
static var _credits_looked := false


static func _credits_script() -> Script:
	if not _credits_looked:
		_credits_looked = true
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			if String(entry["class"]) == "Credits":
				var script := load(String(entry["path"])) as Script
				if script != null and script.get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == "of_points"):
					_credits = script
	return _credits


## 0 → 0, 0.5 → 1, 1 → 0, eased: the number's bump on a point.
static func _bump(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI)


static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if value < 0 else "") + text + out
