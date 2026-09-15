class_name AnnouncerDirector
extends RefCounted
## The booth: turns match events into timed lines for the caller, the Veteran, and the arena PA.
##
## push_event(event) as K5 events happen, advance(seconds) as time passes; advance returns the cues that start now:
## {t, end, speaker, line_id, text, act, moment, reason, cut}. One speaker at a time. Moments wait in a priority
## queue and go stale; a much bigger moment interrupts (the current line is cut); kinds have cooldowns; no line
## repeats in a match while another fits; lulls get banter. Presentation only: the director has its own seeded
## random generator and never touches the simulation's (game_design.md "The director").

## Pause between lines inside one beat, and after a beat before the next moment starts.
const GAP_S := 0.3
const BREATH_S := 0.9
## A moment this much more important than the beat being spoken cuts it off.
const INTERRUPT_MARGIN := 30
## A follow-up (the Veteran's analysis) gives way to any moment a little more important than it.
const SOFT_INTERRUPT_MARGIN := 10
## A moment at least this important doesn't wait for the breath between beats.
const URGENT_PRIORITY := 70
## Quiet this long (after the last line ends) gets banter.
const LULL_MIN_S := 3.5
const LULL_MAX_S := 8.0
const MAX_QUEUE := 6
## Only moments this important ever cut someone off; a line this close to its end is allowed to finish.
const INTERRUPT_MIN := 50
const LET_FINISH_S := 1.2
## The caller's "hold on!" when cutting off the Veteran or the PA, not every time.
const INTERRUPT_LINE_CHANCE := 0.4
## Follow-up lines are this much less important than their moment when deciding whether to cut them off.
const SOFT_DISCOUNT := 40
## Kills still waiting to be called within this many seconds of each other merge into one call ("a flurry").
const MERGE_WINDOW_S := 4.0
## Each tag a line matches beyond the moment kind multiplies its chance: "first blood" lines beat generic kill calls.
const SPECIFIC_WEIGHT := 8.0
## Seconds after the last shot during which follow-ups from the Veteran and the PA are skipped (the fight is live).
const HEAT_S := 1.5

var library: AnnouncerLibrary
var memory: AnnouncerMemory
var rng := RandomNumberGenerator.new()
var now := 0.0
## Every cue spoken so far, and every decision not to speak (for the demo page's "why").
var cues: Array = []
var decisions: Array = []

var _queue: Array = []
var _current := {}
var _busy_until := 0.0
var _last_cue := {}
## line id -> time last used.
var _used := {}
## moment kind -> time its cooldown ends.
var _cooldown_until := {}
var _next_lull_at := -1.0
var _outro_done := false
var _heat_t := -100.0


func _init(line_library: AnnouncerLibrary, seed_value: int = 1) -> void:
	library = line_library
	memory = AnnouncerMemory.new(line_library)
	rng.seed = seed_value


## True when everything that will be said has been said.
func is_done() -> bool:
	return memory.finished and _current.is_empty() and _queue.is_empty() and now >= _busy_until


func push_event(event: Dictionary) -> void:
	if event["type"] in ["damage", "friendly_fire", "unit_destroyed", "first_contact"]:
		_heat_t = float(event["t"])
	for found in memory.observe(event):
		_offer(found)


## Shots are still flying: the Veteran and the PA wait for a gap, and nobody starts banter.
func _is_hot() -> bool:
	return now - _heat_t < HEAT_S


## Moves the booth's clock to `seconds`; returns the cues that started.
func advance(seconds: float) -> Array:
	now = maxf(now, seconds)
	var started: Array = []
	var guard := 0
	while now >= _busy_until and guard < 8:
		guard += 1
		var cue := _next_cue()
		if cue.is_empty():
			break
		started.append(cue)
	return started


## Runs a whole timeline offline (transcripts, tests). Returns every cue.
func run_timeline(events: Array, step_s: float = 0.1) -> Array:
	var index := 0
	var last_t := float(events[-1]["t"]) if not events.is_empty() else 0.0
	var step := 0
	while step < int((last_t + 90.0) / step_s):
		var t := step * step_s
		while index < events.size() and float(events[index]["t"]) <= t + 0.0001:
			push_event(events[index])
			index += 1
		advance(t)
		if index >= events.size() and is_done():
			break
		step += 1
	return cues


func _note(text: String) -> void:
	decisions.append({"t": snappedf(now, 0.01), "text": text})


func _offer(found: Dictionary) -> void:
	var config: Dictionary = library.moments.get(found["kind"], {})
	if config.is_empty():
		return
	if memory.finished and not found["kind"] in ["result", "outro"]:
		return
	if found["kind"] == "contact":
		# Once the shooting starts, nobody reads out the armies anymore.
		_queue = _queue.filter(func(queued: Dictionary) -> bool: return not queued["kind"] in ["army", "preview"])
	if found["kind"] == "result":
		# The match is over: nothing that happened before the end is worth a call anymore, except the final kill.
		_queue = _queue.filter(func(queued: Dictionary) -> bool: return queued["tag_set"].has("final_kill"))
	var priority := int(config.get("priority", 10))
	var intensity := int(config.get("intensity", 1))
	for tag in found["tags"]:
		priority += int(library.tag_priority.get(tag, 0))
		intensity += int(library.tag_intensity.get(tag, 0))
	found["priority"] = priority
	found["intensity"] = clampi(intensity, 1, 3)
	found["stale_at"] = float(found["t"]) + float(config.get("stale_s", 5.0))
	if _is_follow_up(found):
		found["tags"].append("another")
		found["tag_set"]["another"] = true
	var cooldown_end := float(_cooldown_until.get(found["kind"], -1.0))
	if float(found["t"]) < cooldown_end and not found["tag_set"].has("another"):
		_note("skip %s (%s): %s is cooling down" % [found["kind"], found["detail"], found["kind"]])
		return
	var active := _is_speaking() or not _current.is_empty()
	var margin := INTERRUPT_MARGIN if not _is_speaking() or int(_last_cue["_priority"]) >= int(_last_cue["_moment"]["priority"]) \
			else SOFT_INTERRUPT_MARGIN
	if active and priority >= INTERRUPT_MIN and priority >= _active_priority() + margin:
		if _is_speaking() and float(_last_cue["end"]) - now <= LET_FINISH_S:
			# Almost done: let the sentence land, then skip the rest of that beat.
			_current = {}
		else:
			_interrupt(found)
			return
	_queue.append(found)
	if _queue.size() > MAX_QUEUE:
		_queue.sort_custom(_more_important)
		var dropped: Dictionary = _queue.pop_back()
		_note("skip %s (%s): the queue is full" % [dropped["kind"], dropped["detail"]])


## A kill by the team whose kill is being called right now: "and another!"
func _is_follow_up(found: Dictionary) -> bool:
	if found["kind"] != "kill":
		return false
	var active: Dictionary = _current.get("moment", {}) if not _current.is_empty() else {}
	if active.is_empty() and not _last_cue.is_empty() and now - float(_last_cue["end"]) < 2.0:
		active = _last_cue.get("_moment", {})
	return not active.is_empty() and active["kind"] == "kill" and active["team"] == found["team"] \
			and float(found["t"]) - float(active["t"]) <= 5.0


func _more_important(a: Dictionary, b: Dictionary) -> bool:
	if int(a["priority"]) != int(b["priority"]):
		return int(a["priority"]) > int(b["priority"])
	return float(a["t"]) < float(b["t"])


## How important what's being said right now is. The first line of a beat (the call) carries the moment's priority;
## follow-ups (the Veteran's analysis, a sponsor read) are soft, so a new kill cuts them off.
func _active_priority() -> int:
	if _is_speaking():
		return int(_last_cue["_priority"])
	if not _current.is_empty():
		return int(_current["priority"]) - SOFT_DISCOUNT
	return -1000


## Something waiting is important enough to skip a follow-up line of this priority: a kill beats the Veteran's
## thoughts on the previous kill.
func _queue_outranks(priority: int) -> bool:
	for queued in _queue:
		if int(queued["priority"]) >= INTERRUPT_MIN and int(queued["priority"]) > priority \
				and now <= float(queued["stale_at"]):
			return true
	return false


func _is_speaking() -> bool:
	return not _last_cue.is_empty() and now < float(_last_cue["end"])


func _interrupt(found: Dictionary) -> void:
	var cut_what: String = _last_cue["moment"] if _is_speaking() else String(_current.get("moment", {}).get("kind", "nothing"))
	if _is_speaking():
		_last_cue["full_seconds"] = snappedf(float(_last_cue["end"]) - float(_last_cue["t"]), 0.01)
		_last_cue["end"] = snappedf(maxf(now, float(_last_cue["t"]) + 0.4), 0.01)
		_last_cue["cut"] = true
		_busy_until = float(_last_cue["end"]) + 0.1
		found["interrupting"] = _last_cue["speaker"] != "caller" and rng.randf() < INTERRUPT_LINE_CHANCE
		found["cut_in"] = true
	_note("interrupt %s for %s (%s)" % [cut_what, found["kind"], found["detail"]])
	_current = {}
	_queue.push_front(found)


## The next line to say now, or {} to stay quiet.
func _next_cue() -> Dictionary:
	while true:
		if _current.is_empty():
			if not _start_next_beat():
				return {}
		var cue := _speak_step()
		if not cue.is_empty():
			return cue
		if _current.is_empty():
			continue
		if (_current["steps"] as Array).is_empty():
			_end_beat()
	return {}


func _start_next_beat() -> bool:
	var fresh: Array = []
	for queued in _queue:
		if now > float(queued["stale_at"]):
			_note("skip %s (%s): stale after %.1f s" % [queued["kind"], queued["detail"], now - float(queued["t"])])
		else:
			fresh.append(queued)
	_queue = fresh
	_merge_kills()
	var in_breath := not _last_cue.is_empty() and now < float(_last_cue["end"]) + BREATH_S
	if not _queue.is_empty():
		_queue.sort_custom(_more_important)
		if in_breath and int(_queue[0]["priority"]) < URGENT_PRIORITY and not _queue[0].get("cut_in", false):
			return false
		return _begin(_queue.pop_front())
	if in_breath or memory.finished or memory.arena == "" or _is_hot():
		return false
	if _next_lull_at < 0.0:
		_next_lull_at = now + rng.randf_range(LULL_MIN_S, LULL_MAX_S)
	if now < _next_lull_at:
		return false
	_next_lull_at = -1.0
	var tags: Array = []
	if not memory.started_contact:
		tags.append("waiting")
	var lead := memory.leader()
	if lead == "":
		tags.append("level")
	var counted := lead if lead != "" else "green"
	var lull := memory.moment("lull", now, tags, {"arena": memory.arena, "count": memory.alive[counted],
			"other_count": memory.alive[AnnouncerMemory.other(counted)]}, lead, "a quiet moment")
	_offer(lull)
	if _queue.is_empty():
		return false
	_queue.sort_custom(_more_important)
	return _begin(_queue.pop_front())


## Several kills waiting to be called become one call about the newest: "flurry" (and "trade" when both teams
## lost units), so the caller never narrates a pile-up one stale kill at a time.
func _merge_kills() -> void:
	var kills: Array = []
	for queued in _queue:
		if queued["kind"] == "kill":
			kills.append(queued)
	if kills.size() < 2:
		return
	kills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var newest: Dictionary = kills[-1]
	var merged: Array = []
	var teams := {}
	for kill in kills:
		if float(newest["t"]) - float(kill["t"]) <= MERGE_WINDOW_S:
			merged.append(kill)
			teams[kill["team"]] = true
	if merged.size() < 2:
		return
	for kill in merged:
		if kill != newest:
			_queue.erase(kill)
	var added: Array = ["flurry"]
	if teams.size() > 1:
		added.append("trade")
	for tag in added:
		newest["tags"].append(tag)
		newest["tag_set"][tag] = true
	newest["slots"]["kills"] = merged.size()
	newest["priority"] = int(newest["priority"]) + 5
	newest["intensity"] = 3
	newest["detail"] = "%d kills in %.1f s, latest: %s" % [merged.size(), float(newest["t"]) - float(merged[0]["t"]), newest["detail"]]
	_note("merge %d kills into one call" % merged.size())


func _begin(found: Dictionary) -> bool:
	var config: Dictionary = library.moments[found["kind"]]
	if not memory.subject_alive(found):
		_note("skip %s (%s): that unit has been destroyed since" % [found["kind"], found["detail"]])
		return false
	var beat := _choose_beat(config.get("beats", []), found["tag_set"])
	if beat.is_empty():
		_note("skip %s (%s): no beat fits" % [found["kind"], found["detail"]])
		return false
	var steps: Array = (beat["steps"] as Array).duplicate(true)
	steps[0]["hard"] = true
	if found.get("interrupting", false):
		steps.push_front({"speaker": "caller", "act": "interrupt", "optional": true, "hard": true})
	_current = {"moment": found, "steps": steps, "priority": found["priority"], "topic": "", "spoken": 0,
			"beat": beat.get("name", "")}
	_cooldown_until[found["kind"]] = now + float(config.get("cooldown_s", 0.0))
	_next_lull_at = -1.0
	return true


func _choose_beat(beats: Array, tag_set: Dictionary) -> Dictionary:
	var fitting: Array = []
	var weights: Array = []
	for beat in beats:
		var fits := true
		for tag in beat.get("when", []):
			if not tag_set.has(tag):
				fits = false
		for tag in beat.get("unless", []):
			if tag_set.has(tag):
				fits = false
		if fits:
			fitting.append(beat)
			weights.append(float(beat.get("weight", 1.0)) * pow(4.0, (beat.get("when", []) as Array).size()))
	return fitting[_pick_index(weights)] if not fitting.is_empty() else {}


func _pick_index(weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += float(weight)
	var roll := rng.randf() * total
	for index in weights.size():
		roll -= float(weights[index])
		if roll <= 0.0:
			return index
	return weights.size() - 1


## Speaks the current beat's next step; {} when the step was skipped (or the beat ended).
func _speak_step() -> Dictionary:
	var steps: Array = _current["steps"]
	if steps.is_empty():
		_end_beat()
		return {}
	var step: Dictionary = steps.pop_front()
	if not step.get("hard", false) and _queue_outranks(int(_current["priority"]) - SOFT_DISCOUNT):
		_end_beat()
		return {}
	if not step.get("hard", false) and step["speaker"] != "caller" and _is_hot() and not memory.finished:
		_note("skip a %s follow-up to %s: the fight is live" % [step["speaker"], _current["moment"]["kind"]])
		return {}
	var optional: bool = step.get("optional", false) or step.has("chance")
	if step.has("chance") and rng.randf() > float(step["chance"]):
		return {}
	var found: Dictionary = _current["moment"]
	var acts: Array = step["act"] if typeof(step["act"]) == TYPE_ARRAY else [step["act"]]
	var topic: String = _current["topic"] if step.get("answers", false) else ""
	var line := _choose_line(String(step["speaker"]), acts, found, topic, int(found["intensity"]), step.get("require", []))
	if line.is_empty():
		if optional and int(_current["spoken"]) > 0 or optional and not steps.is_empty():
			return {}
		_note("skip %s (%s): no unused %s line for %s" % [found["kind"], found["detail"], step["speaker"], "/".join(acts)])
		_current = {}
		return {}
	var text := library.fill(line, found["slots"])
	var duration := library.line_seconds(line, found["slots"], text)
	var start := snappedf(now, 0.01)
	var cue := {"t": start, "end": snappedf(start + duration, 0.01), "speaker": line["speaker"], "line_id": line["id"],
			"text": text, "act": line["act"], "moment": found["kind"], "event_t": found["t"], "cut": false,
			"slots": _slots_used(line, found["slots"]),
			"reason": _reason(found, line), "_moment": found,
			"_priority": int(found["priority"]) if step.get("hard", false) else int(found["priority"]) - SOFT_DISCOUNT}
	_used[line["id"]] = now
	for flag in line.get("sets", []):
		memory.flags[library.fill_flag(flag, found["slots"])] = now
	# What the audience has heard: "twice is a habit" needs the first time to have been called.
	if found["team"] != "":
		memory.flags["said_%s_%s" % [found["kind"], found["team"]]] = now
		if found["kind"] in ["friendly_fire", "friendly_kill"]:
			memory.flags["said_friendly_%s" % found["team"]] = now
	if line.has("topic"):
		_current["topic"] = line["topic"]
	_current["spoken"] = int(_current["spoken"]) + 1
	_busy_until = float(cue["end"]) + GAP_S
	_last_cue = cue
	cues.append(cue)
	if steps.is_empty():
		_end_beat()
	return cue


func _end_beat() -> void:
	if not _current.is_empty() and _current["moment"]["kind"] == "outro":
		_outro_done = true
	_current = {}


func _slots_used(line: Dictionary, slots: Dictionary) -> Dictionary:
	var used := {}
	for slot in line["slots"]:
		used[slot] = slots[AnnouncerLibrary.base_slot(slot)]
	return used


## A step's `require` tags keep only lines that carry them (a final kill wants a "that's the last one" line, not an
## "upset" line), falling back to any fitting line when none is left.
func _choose_line(speaker: String, acts: Array, found: Dictionary, topic: String, intensity: int, require: Array = []) -> Dictionary:
	var pool := library.candidates(speaker, acts, found, memory.flags, topic)
	if not require.is_empty():
		var required: Array = []
		for line in pool:
			var tags: Array = line.get("tags", [])
			if require.all(func(tag: String) -> bool: return tags.has(tag)) and not _used.has(line["id"]):
				required.append(line)
		if not required.is_empty():
			pool = required
	var fresh: Array = []
	var weights: Array = []
	for line in pool:
		if _used.has(line["id"]):
			continue
		var line_intensity := int(line.get("intensity", 0))
		if line_intensity > 0 and absi(line_intensity - intensity) > 1:
			continue
		fresh.append(line)
		var weight := pow(SPECIFIC_WEIGHT, library.specificity(line)) * (2.0 if line_intensity == intensity else 1.0)
		weights.append(weight)
	if fresh.is_empty():
		return {}
	return fresh[_pick_index(weights)]


func _reason(found: Dictionary, line: Dictionary) -> String:
	var matched: Array = []
	for tag in line.get("tags", []):
		if tag != found["kind"]:
			matched.append(tag)
	return "%s: %s → %s %s%s" % [found["kind"], found["detail"], line["speaker"], line["act"],
			(" [" + ", ".join(matched) + "]") if not matched.is_empty() else ""]
