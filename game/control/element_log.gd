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
