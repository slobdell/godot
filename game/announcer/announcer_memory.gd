class_name AnnouncerMemory
extends RefCounted
## What the announcers remember about a match, and the "moments" worth talking about.
##
## observe(event) folds a K5 event into the match state and returns the moments it creates: a kill becomes a `kill`
## moment tagged first_blood, upset, streak, last_unit, comeback, lead_change... The game never computes those; the
## booth notices them (tests/announcer/fixtures/README.md keeps the event contract small on purpose).
## A moment is {kind, t, tags: Array, tag_set: Dictionary, slots: Dictionary, team, detail}.

const TEAMS := ["green", "rust"]
## A kill streak worth calling: this many enemy kills by one team without losing a unit.
const STREAK := 3
## Army health lead (fraction) that counts as "ahead" for momentum.
const HEALTH_LEAD := 0.12
const MOMENTUM_REPEAT_S := 15.0
const WEAK_SPOT_MEMORY_S := 3.0

var library: AnnouncerLibrary
var arena := ""
var control_point := false
## team -> faction id (K4: condemned, gangs, law, syndicate).
var factions := {}
var units := {}
var alive := {"green": 0, "rust": 0}
var started := {"green": 0, "rust": 0}
var kills := {"green": 0, "rust": 0}
var losses := {"green": 0, "rust": 0}
var first_blood := ""
var streak_team := ""
var streak := 0
## The most units each team has trailed by at any point.
var worst_deficit := {"green": 0, "rust": 0}
var health := {"green": 1.0, "rust": 1.0}
var worst_health_deficit := {"green": 0.0, "rust": 0.0}
var health_leader := ""
var health_leader_since := -100.0
var friendly_hits := {"green": 0, "rust": 0}
var control_owner := "neutral"
var control_changes := 0
var started_contact := false
var finished := false
var end_t := 0.0
## Flags lines set and later lines need (predictions, running jokes).
var flags := {}
var _last_damage := {}
var _seen_upsets := {}
var _last_upset_t := -100.0
## Two "upsets" seconds apart stop being surprising: at most one this often.
const UPSET_GAP_S := 20.0


func _init(line_library: AnnouncerLibrary) -> void:
	library = line_library


static func other(team: String) -> String:
	return "rust" if team == "green" else "green"


func phase() -> String:
	if finished:
		return "post"
	if kills["green"] + kills["rust"] + losses["green"] + losses["rust"] == 0:
		return "early"
	if alive["green"] <= 1 or alive["rust"] <= 1:
		return "final"
	if alive["green"] <= 2 or alive["rust"] <= 2:
		return "late"
	return "mid"


## "leading" / "trailing" / "even" for a team, by units alive.
func standing(team: String) -> String:
	if alive[team] > alive[other(team)]:
		return "leading"
	if alive[team] < alive[other(team)]:
		return "trailing"
	return "even"


func leader() -> String:
	for team in TEAMS:
		if standing(team) == "leading":
			return team
	return ""


func moment(kind: String, t: float, tags: Array, slots: Dictionary, team: String = "", detail: String = "") -> Dictionary:
	var all_tags: Array = [kind, "phase_" + phase()]
	all_tags.append_array(tags)
	if team != "":
		slots["team"] = team
		slots["other_team"] = other(team)
		all_tags.append("team_" + standing(team))
		all_tags.append("team_" + team)
		all_tags.append("faction_" + String(factions.get(team, "condemned")))
		all_tags.append("other_faction_" + String(factions.get(other(team), "condemned")))
	var tag_set := {}
	for tag in all_tags:
		tag_set[tag] = true
	return {"kind": kind, "t": t, "tags": all_tags, "tag_set": tag_set, "slots": slots, "team": team, "detail": detail}


## Folds one event in; returns the moments it creates (often none).
func observe(event: Dictionary) -> Array:
	var t := float(event["t"])
	match String(event["type"]):
		"match_start":
			return _on_start(event, t)
		"first_contact":
			started_contact = true
			return [moment("contact", t, ["unit_" + event["unit"], "target_" + event["target_unit"]],
					{"unit": event["unit"], "target_unit": event["target_unit"]}, event["team"],
					"%s %s opens fire on a %s" % [event["team"], event["unit"], event["target_unit"]])]
		"damage":
			return _on_damage(event, t)
		"unit_destroyed":
			return _on_destroyed(event, t)
		"friendly_fire":
			var team: String = event["team"]
			if bool(event["killed"]):
				return []  # the unit_destroyed event that follows counts it and makes the moment
			friendly_hits[team] += 1
			var tags: Array = ["shooter_" + event["shooter_unit"], "victim_" + event["victim_unit"]]
			if friendly_hits[team] >= 2:
				tags.append("repeat")
			return [moment("friendly_fire", t, tags, {"unit": event["shooter_unit"], "victim_unit": event["victim_unit"],
					"count": friendly_hits[team]}, team, "%s %s hits its own %s" % [team, event["shooter_unit"], event["victim_unit"]])]
		"close_call":
			var tags: Array = ["unit_" + event["unit"]]
			if alive[event["team"]] == 1:
				tags.append("last_unit")
			var survivor := moment("close_call", t, tags, {"unit": event["unit"]}, event["team"],
					"%s %s survives on %d%% hull" % [event["team"], event["unit"], roundi(float(event["hull_left"]) * 100)])
			survivor["subject"] = event["unit_id"]
			return [survivor]
		"control_changed":
			return _on_control(event, t)
		"squad_wiped":
			return [moment("squad_wiped", t, [], {}, event["team"], "%s loses squad %s" % [event["team"], event["squad"]])]
		"momentum":
			return _on_momentum(event, t)
		"match_end":
			return _on_end(event, t)
	return []


func _on_start(event: Dictionary, t: float) -> Array:
	arena = event["arena"]
	control_point = bool(event.get("control_point", false))
	var composition := {}
	for team_data in event["teams"]:
		var team: String = team_data["team"]
		factions[team] = String(team_data.get("faction", "condemned"))
		composition[team] = {}
		for unit in team_data["units"]:
			units[unit["id"]] = {"team": team, "unit": unit["unit"], "squad": unit.get("squad", ""), "alive": true}
			alive[team] += 1
			started[team] += 1
			composition[team][unit["unit"]] = composition[team].get(unit["unit"], 0) + 1
	var intro_tags: Array = ["arena_" + arena]
	if control_point:
		intro_tags.append("control_point")
	var found: Array = [moment("intro", t, intro_tags, {"arena": arena, "count": alive["green"] + alive["rust"]}, "",
			"%s: %d units on the floor" % [arena, alive["green"] + alive["rust"]])]
	var main_unit := {}
	for team in TEAMS:
		var best := ""
		for unit in composition[team]:
			if best == "" or composition[team][unit] > composition[team][best] \
					or (composition[team][unit] == composition[team][best] and unit < best):
				best = unit
		main_unit[team] = best
		var tags: Array = ["main_" + best, "introduce"]
		if composition[team].size() == 1:
			tags.append_array(["all_same", "all_" + best])
		elif composition[team][best] >= 3:
			tags.append_array(["heavy", "heavy_" + best])
		else:
			tags.append("mixed")
		if composition[team][best] >= 2:
			tags.append("several")
		found.append(moment("army", t, tags, {"units": best, "unit": best, "count": composition[team][best],
				"other_count": started[team]}, team, "%s: %d units, mostly %s" % [team, started[team], best]))
	# Tale of the tape: who has the numbers.
	var tape_team := "green" if started["green"] >= started["rust"] else "rust"
	found.append(moment("tape", t, ["outnumbers" if started["green"] != started["rust"] else "even_numbers"],
			{"count": started[tape_team], "other_count": started[other(tape_team)]}, tape_team,
			"tale of the tape: %s %d, %s %d" % [tape_team, started[tape_team], other(tape_team), started[other(tape_team)]]))
	var preview_tags: Array = []
	var preview_team := "green"
	for team in TEAMS:
		if main_unit[other(team)] in counters_of(main_unit[team]):
			preview_tags = ["counter"]
			preview_team = team
			break
	if composition["green"] == composition["rust"]:
		preview_tags = ["mirror"]
	found.append(moment("preview", t, preview_tags, {"units": main_unit[preview_team], "other_units": main_unit[other(preview_team)]},
			preview_team, "matchup: %s %s vs %s %s" % [preview_team, main_unit[preview_team], other(preview_team), main_unit[other(preview_team)]]))
	return found


func counters_of(unit: String) -> Array:
	var found: Variant = library.counters.get(unit, [])
	return found if typeof(found) == TYPE_ARRAY else []


func _on_damage(event: Dictionary, t: float) -> Array:
	var victim: String = event["victim"]
	if not units.has(victim) or not units.has(event["shooter"]):
		return []
	_last_damage[victim] = {"t": t, "weak_spot": bool(event.get("weak_spot", false)), "face": String(event.get("face", ""))}
	var big := bool(event["critical"]) and (bool(event.get("weak_spot", false)) or float(event.get("amount", 0.0)) >= 0.3
			or float(event["hull"]) <= 0.25)
	if not big:
		return []
	var tags: Array = ["shooter_" + event["shooter_unit"], "victim_" + event["victim_unit"]]
	if bool(event.get("weak_spot", false)):
		tags.append("weak_spot")
	if event.get("face", "") == "rear":
		tags.append("rear")
	if float(event["hull"]) <= 0.35:
		tags.append("hurt")
	var team: String = units[event["shooter"]]["team"]
	var hit := moment("big_hit", t, tags, {"unit": event["shooter_unit"], "victim_unit": event["victim_unit"]}, team,
			"%s %s hits a %s%s, %d%% hull left" % [team, event["shooter_unit"], event["victim_unit"],
			" in a weak spot" if tags.has("weak_spot") else "", roundi(float(event["hull"]) * 100)])
	hit["subject"] = victim
	return [hit]


## A moment about a unit ("still in there!", "that tank is hurt!") is only worth saying while the unit lives.
func subject_alive(found: Dictionary) -> bool:
	return not found.has("subject") or bool(units.get(found["subject"], {}).get("alive", true))


func _on_destroyed(event: Dictionary, t: float) -> Array:
	var victim_team: String = event["victim_team"]
	var killer_team: String = event["killer_team"]
	var leader_before := leader()
	alive[victim_team] -= 1
	losses[victim_team] += 1
	if units.has(event["victim"]):
		units[event["victim"]]["alive"] = false
	var tags: Array = ["victim_" + event["victim_unit"]]
	var slots := {"victim_unit": event["victim_unit"], "count": alive[victim_team]}
	var team := victim_team
	var kind := "kill"
	var detail := ""
	if event["killer"] == "":
		kind = "hazard_kill"
		slots["unit"] = event["victim_unit"]
		detail = "%s %s destroyed by the arena" % [victim_team, event["victim_unit"]]
		_break_streak(victim_team)
	elif bool(event["friendly"]):
		kind = "friendly_kill"
		tags.append("killer_" + event["killer_unit"])
		slots["killer_unit"] = event["killer_unit"]
		slots["unit"] = event["killer_unit"]
		friendly_hits[victim_team] += 1
		if friendly_hits[victim_team] >= 2:
			tags.append("repeat")
		detail = "%s %s destroys its own %s" % [victim_team, event["killer_unit"], event["victim_unit"]]
		_break_streak(victim_team)
	else:
		team = killer_team
		kills[killer_team] += 1
		slots["killer_unit"] = event["killer_unit"]
		slots["unit"] = event["killer_unit"]
		tags.append("killer_" + event["killer_unit"])
		if first_blood == "":
			first_blood = killer_team
			tags.append("first_blood")
		if event["killer_unit"] == event["victim_unit"]:
			tags.append("mirror")
		elif event["victim_unit"] in counters_of(event["killer_unit"]):
			tags.append("counter")
		elif event["killer_unit"] in counters_of(event["victim_unit"]):
			# The second tank to beat a scout isn't a surprise anymore.
			var pair := "upset_%s_%s" % [event["killer_unit"], event["victim_unit"]]
			if not _seen_upsets.has(pair) and t - _last_upset_t >= UPSET_GAP_S:
				_seen_upsets[pair] = true
				_last_upset_t = t
				tags.append("upset")
		if streak_team == killer_team:
			streak += 1
		else:
			streak_team = killer_team
			streak = 1
		if streak >= STREAK:
			tags.append("streak")
			slots["streak"] = streak
		var recent: Dictionary = _last_damage.get(event["victim"], {})
		if not recent.is_empty() and t - float(recent["t"]) <= WEAK_SPOT_MEMORY_S:
			if recent["weak_spot"]:
				tags.append("weak_spot")
			if recent["face"] == "rear":
				tags.append("rear")
		detail = "%s %s destroys a %s %s" % [killer_team, event["killer_unit"], victim_team, event["victim_unit"]]
	if alive[victim_team] == 1:
		tags.append("last_unit")
	if alive[victim_team] == 0:
		tags.append("final_kill")
	if alive["green"] == alive["rust"] and alive["green"] > 0:
		tags.append("even")
	var leader_after := leader()
	if leader_after != "" and leader_after != leader_before and leader_before != "":
		tags.append("lead_change")
	for side in TEAMS:
		worst_deficit[side] = maxi(worst_deficit[side], alive[other(side)] - alive[side])
	if kind == "kill" and worst_deficit[killer_team] >= 2 and alive[killer_team] >= alive[victim_team]:
		tags.append("comeback")
	slots["other_count"] = alive[other(victim_team)]
	return [moment(kind, t, tags, slots, team, detail)]


func _break_streak(team: String) -> void:
	if streak_team != team:
		streak_team = ""
		streak = 0


func _on_control(event: Dictionary, t: float) -> Array:
	var owner: String = event["owner"]
	var previous: String = event.get("previous", control_owner)
	control_owner = owner
	control_changes += 1
	if owner == "neutral":
		return [moment("control", t, ["neutral"], {}, previous if previous in TEAMS else "", "the control point is neutral")]
	var tags: Array = ["stolen" if previous in TEAMS else "taken"]
	if control_changes >= 3:
		tags.append("again")
	return [moment("control", t, tags, {}, owner, "%s %s the control point" % [owner, "steals" if tags[0] == "stolen" else "takes"])]


func _on_momentum(event: Dictionary, t: float) -> Array:
	for team in TEAMS:
		health[team] = float(event["army_health"][team])
	for team in TEAMS:
		worst_health_deficit[team] = maxf(worst_health_deficit[team], health[other(team)] - health[team])
	var ahead := ""
	for team in TEAMS:
		if health[team] - health[other(team)] >= HEALTH_LEAD:
			ahead = team
	if ahead == "" or ahead == health_leader:
		return []
	var had_leader := health_leader != ""
	health_leader = ahead
	var quiet := t - health_leader_since < MOMENTUM_REPEAT_S
	health_leader_since = t
	if not started_contact or quiet:
		return []
	var tags: Array = ["shift" if had_leader else "edge"]
	if health[ahead] - health[other(ahead)] >= 0.4:
		tags.append("rout")
	return [moment("momentum", t, tags, {}, ahead, "%s ahead on army health %d%% to %d%%" % [ahead,
			roundi(health[ahead] * 100), roundi(health[other(ahead)] * 100)])]


func _on_end(event: Dictionary, t: float) -> Array:
	finished = true
	end_t = t
	var winner: String = event["winner"]
	var tags: Array = ["win_" + String(event["reason"])]
	var slots := {"duration": int(event["duration_seconds"])}
	var team := ""
	if winner == "draw":
		tags = ["draw"]
	else:
		team = winner
		var left := int(event["units_left"][winner])
		slots["count"] = left
		if left == started[winner]:
			tags.append("flawless")
		elif left == 1:
			tags.append("close")
		if worst_deficit[winner] >= 2 or worst_health_deficit[winner] >= 0.25:
			tags.append("comeback")
	if float(event["duration_seconds"]) >= 150.0:
		tags.append("long")
	elif float(event["duration_seconds"]) <= 60.0:
		tags.append("quick")
	var result := moment("result", t, tags, slots, team, "%s wins by %s after %d s" % [winner, event["reason"], int(event["duration_seconds"])]
			if winner != "draw" else "a draw after %d s" % int(event["duration_seconds"]))
	return [result, moment("outro", t, tags.duplicate(), slots.duplicate(), team, "sign-off")]
