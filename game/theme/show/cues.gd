class_name ShowCues
extends RefCounted
## S6: the cue book — what turns a bank of breathing lights into an entertainment event (`_agents/lighting.md`
## section 6). The lead: *"rather than just randomly having breathing lights ... we should immerse ourselves in this
## whole arena sporting event ... imagine light shows in Las Vegas."*
##
## A cue is DATA: a set of channel overrides with an attack and a release, selected from `MatchMood.current().state`
## (`lull`, `skirmish`, `battle`, `last_stand`, `victory`, `defeat`) or fired by a K5 event. Idle is the slow
## breathe; the cues are the show.
##
## One book for every arena, so an arena that declares a patch gets the show without declaring the show. An arena may
## override a state by putting the same shape under its own `show.cues`.
##
## Two rules the book cannot break, both enforced here rather than trusted:
##   * a cue never drives a channel outside the patch's floor and ceiling -- that clamp is what stops a cue blowing
##     past "a core fixture never goes fully dark" and "never full blast" (rules 5 and 6);
##   * a cue never jumps a channel's clock, only changes its rate, so a programme swap cannot tear.

const BOOK := "res://game/theme/show/cues.json"
## The mood states a cue may be bound to. Copied from `MatchMood.STATES` at load and checked against it, so a typo
## in the book is an error rather than a cue that never fires.
const IDLE_STATE := &"lull"
## Not a mood state: the moment the loading screen drops and the match becomes playable. `MatchMood` has no name for
## it -- it starts at `lull` -- so the show holds this one for `hold` seconds and then lets the mood take over.
const FIGHT_STATE := &"fight"
## A cue may run a channel faster than a PATCH is allowed to (lighting.md rule 10 governs the idle, not a stab of
## strobe), but not so fast it reads as a fault, and not so slow it reads as nothing.
const CUE_PERIOD_MIN_S := 0.8

## state -> {attack: float, release: float, set: {channel: {programme, period, floor, ceiling, color}}}
var states := {}
## event -> {attack, release, gain, speed}
var events := {}
var problem := ""


static func load_book(path := BOOK) -> ShowCues:
	var cues := ShowCues.new()
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		cues.problem = "no cue book at %s" % path
		return cues
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		cues.problem = "%s is not a JSON object" % path
		return cues
	cues.problem = cues.load_data(data, path)
	return cues


func load_data(data: Dictionary, where := "cues") -> String:
	states.clear()
	events.clear()
	var raw_states: Variant = data.get("states", {})
	if typeof(raw_states) != TYPE_DICTIONARY:
		return "%s.states must be an object keyed by mood state" % where
	for key: Variant in raw_states:
		if not MatchMood.STATES.has(str(key)) and StringName(str(key)) != FIGHT_STATE:
			return "%s.states: '%s' is not a mood state (have %s, or '%s')" \
					% [where, key, ", ".join(MatchMood.STATES), FIGHT_STATE]
		var cue: Variant = raw_states[key]
		if typeof(cue) != TYPE_DICTIONARY:
			return "%s.states.%s must be an object {attack, release, set}" % [where, key]
		var overrides: Variant = cue.get("set", {})
		if typeof(overrides) != TYPE_DICTIONARY:
			return "%s.states.%s.set must be an object of {channel: {...}}" % [where, key]
		for channel_key: Variant in overrides:
			var override: Variant = overrides[channel_key]
			if typeof(override) != TYPE_DICTIONARY:
				return "%s.states.%s.set.%s must be an object" % [where, key, channel_key]
			if override.has("programme") and not ShowChannel.PROGRAMMES.has(StringName(str(override["programme"]))):
				return "%s.states.%s.set.%s: unknown programme '%s'" % [where, key, channel_key, override["programme"]]
			if override.has("period") and float(override["period"]) < CUE_PERIOD_MIN_S:
				return "%s.states.%s.set.%s: period %.2f s is under %.2f s and would read as a fault" \
						% [where, key, channel_key, float(override["period"]), CUE_PERIOD_MIN_S]
		states[StringName(str(key))] = {
			"attack": maxf(float(cue.get("attack", 1.0)), 0.01),
			"release": maxf(float(cue.get("release", 2.0)), 0.01),
			"hold": maxf(float(cue.get("hold", 0.0)), 0.0),
			"set": overrides,
		}
	var raw_events: Variant = data.get("events", {})
	if typeof(raw_events) != TYPE_DICTIONARY:
		return "%s.events must be an object" % where
	for key: Variant in raw_events:
		var event: Variant = raw_events[key]
		if typeof(event) != TYPE_DICTIONARY:
			return "%s.events.%s must be an object" % [where, key]
		events[StringName(str(key))] = {
			"gain": float(event.get("gain", 1.0)),
			"speed": maxf(float(event.get("speed", 70.0)), 0.1),
			"life": maxf(float(event.get("life", 2.0)), 0.01),
			"min_weight": clampf(float(event.get("min_weight", 0.5)), 0.0, 1.0),
		}
	return ""


## Replace every `strobe` in the book with a breathe at `period`. The comparison arm for the lead's call on whether
## the `last_stand` strobe -- the only one in the venue -- survives. Editing the loaded book rather than shipping a
## second one keeps the two arms honest: everything else about the cues is identical by construction.
func soften_strobes(period: float) -> void:
	for state: Variant in states:
		for channel: Variant in states[state]["set"]:
			var override: Dictionary = states[state]["set"][channel]
			if str(override.get("programme", "")) == "strobe":
				override["programme"] = "breathe"
				override["period"] = period


## The cue for a mood state, falling back to the idle one. Never null: an unlisted state is the idle breathe, which
## is the right answer and not an error.
func for_state(state: StringName) -> Dictionary:
	if states.has(state):
		return states[state]
	if states.has(IDLE_STATE):
		return states[IDLE_STATE]
	return {"attack": 1.0, "release": 2.0, "hold": 0.0, "set": {}}


## The channel a cue asks for, built from `base` so anything the cue does not mention is unchanged, and CLAMPED to
## the patch's floor and ceiling so a cue can never take a fixture outside the band the arena declared.
## `team_color` is what `"color": "winner"` resolves to -- the one team-coloured cue in the venue, and the reason it
## cannot simply be a hex in the book (art_direction.md: venue lighting must not read as a team, except this).
static func blend(base: ShowChannel, override: Dictionary, weight: float, team_color := Color.WHITE) -> ShowChannel:
	var target := base.duplicate_channel()
	if override.has("programme"):
		target.programme = StringName(str(override["programme"]))
		target.sharpness = float(ShowChannel.PROGRAMMES.get(target.programme, 1.0))
	if override.has("sharpness"):
		target.sharpness = float(override["sharpness"])
	if override.has("period"):
		target.period = float(override["period"])
	if override.has("floor"):
		target.level_floor = float(override["floor"])
	if override.has("ceiling"):
		target.level_ceiling = float(override["ceiling"])
	if override.has("wave"):
		target.wave = ShowChannel.wave_from(override["wave"])
	if override.has("color"):
		var wanted := str(override["color"])
		target.color = team_color if wanted == "winner" else Color(wanted)
		target.color_mix = float(override.get("color_mix", 1.0))
	# The clamp. A cue moves WITHIN the band the patch declared; it never widens it.
	target.level_floor = clampf(target.level_floor, base.level_floor, base.level_ceiling)
	target.level_ceiling = clampf(target.level_ceiling, target.level_floor, base.level_ceiling)
	if weight >= 1.0:
		return target
	var blended := base.duplicate_channel()
	blended.programme = target.programme if weight > 0.5 else base.programme
	blended.sharpness = lerpf(base.sharpness, target.sharpness, weight)
	blended.period = lerpf(base.period, target.period, weight)
	blended.level_floor = lerpf(base.level_floor, target.level_floor, weight)
	blended.level_ceiling = lerpf(base.level_ceiling, target.level_ceiling, weight)
	blended.color = target.color
	blended.color_mix = lerpf(base.color_mix, target.color_mix, weight)
	# The shape of the wave switches at the halfway point with the programme, rather than lerping through
	# meaningless intermediate shapes (a chase half-way to a twinkle is neither).
	blended.wave = target.wave if weight > 0.5 else base.wave
	return blended
