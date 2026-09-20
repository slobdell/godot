class_name ElementLog
extends RefCounted
## Control X7 (round 6 stretch): "why did my element do that". The card's doctrine line says what a squad's leader
## decided NOW; this keeps the last few decisions per element with the match time they were made, so the player can
## read back "0:41 wedge, traveling  →  0:47 line, react to contact — contact ahead" when the squad did something
## surprising. Hover the doctrine line on the card to see it (SelectionPanel). Fed by L1's `element_changed`.

## Decisions kept per element.
const KEEP := 6

var game_match: Match
var elements: Elements
## element id -> [{"at": seconds into the match, "text": Element.describe()}], oldest first.
var _history := {}


func attach(p_elements: Elements, p_match: Match) -> void:
	elements = p_elements
	game_match = p_match
	if elements != null and not elements.element_changed.is_connected(_on_changed):
		elements.element_changed.connect(_on_changed)


func _on_changed(id: int) -> void:
	var element := elements.get_element(id) if elements != null else null
	if element == null:
		return
	var text := element.describe()
	var entries: Array = _history.get(id, [])
	if not entries.is_empty() and String(entries.back()["text"]) == text:
		return  # a roster or leader change that didn't change the decision
	var at := float(game_match.tick) / float(SimClock.TICK_RATE) if game_match != null else 0.0
	entries.append({"at": at, "text": text})
	if entries.size() > KEEP:
		entries = entries.slice(entries.size() - KEEP)
	_history[id] = entries


## S4 / A6 C-3 (round 9): a line the element did not decide for itself - "Alpha: under fire" when the legibility law
## gave way to a higher priority. It goes in the SAME history as the leader's own decisions, deliberately: the player
## asks one question ("why did my element do that") and gets one answer, in one place, in order. Repeats are dropped,
## so a cause that lasts ten seconds is one line and not three hundred.
## element id -> the last NOTE written for it. Deduping against the last HISTORY entry is not enough: the element's
## own decisions land in the same list, so a leader that re-decides between two identical causes separates them and
## every frame's cause becomes a new line ("expected 2, got 4" on builder0, where the timing differed from the
## laptop's - the remote check caught what the local run could not).
var _last_note := {}


## A cause has stopped: the next occurrence of the same one is news again rather than a repeat.
func clear_note(id: int) -> void:
	_last_note.erase(id)


func note(id: int, text: String) -> void:
	if String(_last_note.get(id, "")) == text:
		return
	_last_note[id] = text
	var entries: Array = _history.get(id, [])
	if not entries.is_empty() and String(entries.back()["text"]) == text:
		return
	var at := float(game_match.tick) / float(SimClock.TICK_RATE) if game_match != null else 0.0
	entries.append({"at": at, "text": text})
	if entries.size() > KEEP:
		entries = entries.slice(entries.size() - KEEP)
	_history[id] = entries


## The element's recent decisions, oldest first: [{"at", "text"}].
func history(id: int) -> Array:
	return _history.get(id, [])


## The same as lines for a tooltip: "0:47  line, react to contact — contact ahead" (the element's name dropped, since
## the tooltip is already about that element).
func lines(id: int) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in history(id):
		var seconds := int(entry["at"])
		var text := String(entry["text"])
		var colon := text.find(": ")
		result.append("%d:%02d  %s" % [seconds / 60, seconds % 60, text.substr(colon + 2) if colon >= 0 else text])
	return result
