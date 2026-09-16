class_name AnnouncerVariance
extends RefCounted
## Measures how much the booth repeats itself **across matches** (brief X1: the lead heard the PA open the same way
## in several matches in a row).
##
## It replays each fixture as N consecutive broadcasts — a new director seed each time, one shared
## [AnnouncerHistory] — and reports three numbers per fixture and overall:
##
##   in-match repeats   a line id said twice in one match (must be 0)
##   opener repeats     the share of matches whose opening line was also heard in the previous WINDOW-1 matches,
##                      for the first line of the broadcast and, separately, for the PA's welcome (what the lead noticed)
##   carryover          the share of a match's lines that were also said in the match right before it
##
## `make announcer-variance` runs it; the thresholds live there, not here.

## Matches a line is compared against: "an opener repeat rate under ~10% across five consecutive matches" (the brief).
const DEFAULT_WINDOW := 5
const DEFAULT_MATCHES := 50


## One fixture's numbers. `events` is a loaded K5 timeline.
static func measure_fixture(library: AnnouncerLibrary, events: Array, matches: int, window: int,
		history: AnnouncerHistory = null) -> Dictionary:
	var said: Array[Dictionary] = []          # per match: line id -> true
	var openers := PackedStringArray()        # per match: the first line said
	var welcomes := PackedStringArray()       # per match: the PA's first welcome ("" when she didn't open)
	var in_match_repeats := 0
	var line_uses := {}
	for index in matches:
		var director := AnnouncerDirector.new(library, index + 1)
		if history != null:
			director.history = history
		var cues := director.run_timeline(events)
		var ids := {}
		var opener := ""
		var welcome := ""
		for cue in cues:
			var id: String = cue["line_id"]
			if ids.has(id):
				in_match_repeats += 1
			ids[id] = true
			line_uses[id] = int(line_uses.get(id, 0)) + 1
			if opener == "":
				opener = id
			if welcome == "" and cue["speaker"] == "pa" and cue["act"] == "welcome":
				welcome = id
		said.append(ids)
		openers.append(opener)
		welcomes.append(welcome)
		if history != null:
			history.remember(ids.keys())
	return {
		"matches": matches,
		"in_match_repeats": in_match_repeats,
		"opener_repeat_rate": _repeat_rate(openers, window),
		"welcome_repeat_rate": _repeat_rate(welcomes, window),
		"carryover_rate": _carryover(said),
		"distinct_openers": _distinct(openers),
		"distinct_welcomes": _distinct(welcomes),
		"lines_per_match": _mean_size(said),
		"line_uses": line_uses,
	}


## The share of matches whose value was already heard in the previous `window - 1` matches. Empty values (the PA
## never welcomed) don't count either way.
static func _repeat_rate(values: PackedStringArray, window: int) -> float:
	var compared := 0
	var repeats := 0
	for index in values.size():
		if values[index] == "":
			continue
		var start := maxi(0, index - (window - 1))
		if start == index:
			continue
		compared += 1
		for before in range(start, index):
			if values[before] == values[index]:
				repeats += 1
				break
	return float(repeats) / float(compared) if compared > 0 else 0.0


static func _carryover(said: Array[Dictionary]) -> float:
	var total := 0.0
	var counted := 0
	for index in range(1, said.size()):
		if said[index].is_empty():
			continue
		var shared := 0
		for id in said[index]:
			if said[index - 1].has(id):
				shared += 1
		total += float(shared) / float(said[index].size())
		counted += 1
	return total / float(counted) if counted > 0 else 0.0


static func _distinct(values: PackedStringArray) -> int:
	var seen := {}
	for value in values:
		if value != "":
			seen[value] = true
	return seen.size()


static func _mean_size(said: Array[Dictionary]) -> float:
	if said.is_empty():
		return 0.0
	var total := 0
	for ids in said:
		total += ids.size()
	return float(total) / float(said.size())


## A readable report over several fixtures. `results` = fixture name -> measure_fixture().
static func report(results: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("%-22s %7s %8s %8s %9s %9s %9s" % ["fixture", "matches", "repeats", "opener%", "welcome%",
			"carry%", "lines"])
	for name in results:
		var r: Dictionary = results[name]
		out.append("%-22s %7d %8d %7.0f%% %8.0f%% %8.0f%% %9.1f" % [name, int(r["matches"]), int(r["in_match_repeats"]),
				float(r["opener_repeat_rate"]) * 100.0, float(r["welcome_repeat_rate"]) * 100.0,
				float(r["carryover_rate"]) * 100.0, float(r["lines_per_match"])])
	var totals := combine(results)
	out.append("%-22s %7d %8d %7.0f%% %8.0f%% %8.0f%% %9.1f" % ["ALL", int(totals["matches"]),
			int(totals["in_match_repeats"]), float(totals["opener_repeat_rate"]) * 100.0,
			float(totals["welcome_repeat_rate"]) * 100.0, float(totals["carryover_rate"]) * 100.0,
			float(totals["lines_per_match"])])
	return "\n".join(out)


## The mean of every fixture's numbers, weighted by matches.
static func combine(results: Dictionary) -> Dictionary:
	var matches := 0
	var repeats := 0
	var opener := 0.0
	var welcome := 0.0
	var carry := 0.0
	var lines := 0.0
	for name in results:
		var r: Dictionary = results[name]
		var weight := float(r["matches"])
		matches += int(r["matches"])
		repeats += int(r["in_match_repeats"])
		opener += float(r["opener_repeat_rate"]) * weight
		welcome += float(r["welcome_repeat_rate"]) * weight
		carry += float(r["carryover_rate"]) * weight
		lines += float(r["lines_per_match"]) * weight
	var total := float(maxi(matches, 1))
	return {"matches": matches, "in_match_repeats": repeats, "opener_repeat_rate": opener / total,
			"welcome_repeat_rate": welcome / total, "carryover_rate": carry / total, "lines_per_match": lines / total}


## The lines said most often across every fixture, worst first: where the library is thin.
static func hot_lines(results: Dictionary, top: int) -> Array:
	var uses := {}
	var total := 0
	for name in results:
		for id in results[name]["line_uses"]:
			uses[id] = int(uses.get(id, 0)) + int(results[name]["line_uses"][id])
			total += int(results[name]["line_uses"][id])
	var ids: Array = uses.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(uses[a]) > int(uses[b]) if int(uses[a]) != int(uses[b]) else a < b)
	var found: Array = []
	for id in ids.slice(0, top):
		found.append({"id": id, "uses": int(uses[id]), "share": float(uses[id]) / float(maxi(total, 1))})
	return found
