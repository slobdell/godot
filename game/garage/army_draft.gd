class_name ArmyDraft
extends RefCounted
## An army being built: up to 5 squads of fixed unit types, bought on a budget. Pure data + rules, no UI;
## the army screen, presets, and codes all edit armies through it. Replaces round 1's Loadout.
##
## The army is kept in ARMY JSON v2 shape (contract C2, see ArmyFormat), so saving is writing it out:
##   {"name", "squads": [{"name", "formation", "directive": {"role"}, "verb": "hold", "units": [{"unit", "paint"?}]}]}
## Player squads start formed up and holding (`verb: hold`) for tactical-map orders.

signal changed

## Army JSON written by the builder. 2 = catalog v2 units (no weapons, components, or hardpoints).
const SCHEMA := 2
const SQUAD_NAMES := ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet"]
## Cosmetic paints ("" = team color). Free, never sold.
const PAINTS := ["", "#c8a02a", "#3a8fd0", "#d04a8c", "#35c0a0", "#e0e0e0", "#303030"]

var catalog: ArmyCatalog
var army: Dictionary
## Budget tier the army was built for (Progression.BUDGET_TIERS), recorded in saves.
var tier := 0
## Sentences about what a migration dropped (a round-1 save's weapons, unknown units).
var notes: PackedStringArray = []


func _init(p_catalog: ArmyCatalog, p_army: Dictionary = {}) -> void:
	catalog = p_catalog
	army = p_army if not p_army.is_empty() else {"name": "My Army", "squads": [new_squad("Alpha")]}
	if typeof(army.get("squads")) != TYPE_ARRAY:
		army["squads"] = []
	for squad_data: Dictionary in army["squads"]:
		if typeof(squad_data.get("units")) != TYPE_ARRAY:
			squad_data["units"] = []


static func new_squad(squad_name: String, formation := Formations.DEFAULT, role := "assault", hold := true) -> Dictionary:
	var squad_data := {"name": squad_name, "formation": formation, "directive": {"role": role}, "units": []}
	if hold:
		squad_data["verb"] = "hold"
	return squad_data


## Any army dictionary (v2, a round-1 save, a hand-written doctrine), migrated to v2.
static func from_doctrine(p_catalog: ArmyCatalog, doctrine: Dictionary) -> ArmyDraft:
	var migrated := ArmyFormat.migrate(doctrine, p_catalog)
	var copy: Dictionary = migrated["doctrine"]
	var garage: Variant = copy.get("garage")
	copy.erase("garage")
	var draft := ArmyDraft.new(p_catalog, copy)
	draft.notes = migrated["notes"]
	if typeof(garage) == TYPE_DICTIONARY:
		draft.tier = int(garage.get("tier", 0))
	return draft


## Make this an army the PLAYER commands: every squad starts formed up and holding for orders, with no
## CPU objective. The builder applies it to anything it opens (loads, presets, codes).
func make_player_army() -> void:
	for squad_data in squads():
		squad_data["verb"] = "hold"
		if not squad_data.has("formation"):
			squad_data["formation"] = Formations.DEFAULT
		if typeof(squad_data.get("directive")) == TYPE_DICTIONARY:
			squad_data["directive"].erase("objective")
		for entry in squad_data.get("units", []):
			if typeof(entry.get("directive")) == TYPE_DICTIONARY:
				entry["directive"].erase("objective")


# ---- Reading ------------------------------------------------------------------------------------

func squads() -> Array:
	return army.get("squads", [])


func squad(index: int) -> Dictionary:
	return squads()[index] if index >= 0 and index < squads().size() else {}


func units_of(squad_index: int) -> Array:
	return squad(squad_index).get("units", [])


func unit_at(squad_index: int, unit_index: int) -> Dictionary:
	var entries := units_of(squad_index)
	return entries[unit_index] if unit_index >= 0 and unit_index < entries.size() else {}


func unit_count() -> int:
	var count := 0
	for squad_data in squads():
		count += squad_data.get("units", []).size()
	return count


## {unit id: how many}, in the catalog's order.
func counts_by_unit() -> Dictionary:
	var counts := {}
	for unit_id in catalog.unit_ids():
		for squad_data in squads():
			for entry in squad_data.get("units", []):
				if String(entry.get("unit", "")) == unit_id:
					counts[unit_id] = int(counts.get(unit_id, 0)) + 1
	return counts


func unit_cost(entry: Dictionary) -> int:
	return catalog.unit_cost(String(entry.get("unit", "")))


func total_cost() -> int:
	var cost := 0
	for squad_data in squads():
		for entry in squad_data.get("units", []):
			cost += unit_cost(entry)
	return cost


func remaining_budget() -> int:
	return catalog.budget - total_cost()


## Every problem that stops this army from fighting, as sentences a player can act on. Empty = ready.
## `with_loader` also asks the game's own loader, for the game's catalog.
func problems(with_loader := true) -> PackedStringArray:
	var found: PackedStringArray = []
	if String(army.get("name", "")).strip_edges() == "":
		found.append("Give your army a name.")
	if unit_count() == 0:
		found.append("Buy a unit: tap + ADD on a unit card.")
	if squads().size() > catalog.max_squads:
		found.append("Too many squads: %d of %d." % [squads().size(), catalog.max_squads])
	for squad_data in squads():
		var entries: Array = squad_data.get("units", [])
		var squad_name := String(squad_data.get("name", "A squad"))
		if entries.is_empty() and unit_count() > 0:
			found.append("%s is empty: add a unit or remove the squad." % squad_name)
		elif entries.size() > catalog.max_squad_size:
			found.append("%s has %d units; a squad holds at most %d." % [squad_name, entries.size(), catalog.max_squad_size])
		var reported := {}
		for entry in entries:
			var problem := unit_problem(entry)
			if problem != "" and not reported.has(problem):
				reported[problem] = true
				found.append("%s: %s" % [squad_name, problem])
	if unit_count() > catalog.max_units:
		found.append("Too many units: %d of %d." % [unit_count(), catalog.max_units])
	if total_cost() > catalog.budget:
		found.append("Over budget by %d." % (total_cost() - catalog.budget))
	if found.is_empty() and with_loader and catalog.is_game:
		# The final word belongs to the loader the match uses.
		var parsed := Doctrine.parse(ArmyFormat.to_game_doctrine(to_doctrine()))
		if parsed.has("error"):
			found.append("The match can't load this army: %s" % parsed["error"])
	return found


func is_ready() -> bool:
	return problems().is_empty()


func unit_problem(entry: Dictionary) -> String:
	var unit_id := String(entry.get("unit", ""))
	if not catalog.has_unit(unit_id):
		return "unknown unit '%s'" % unit_id
	if not catalog.is_unlocked(unit_id):
		return "the %s is locked" % catalog.display_name(unit_id)
	var paint := String(entry.get("paint", ""))
	if paint != "" and not Color.html_is_valid(paint):
		return "paint '%s' is not a color" % paint
	return ""


# ---- Editing (each returns "" or a reason, and emits `changed` on success) -------------------------

func set_army_name(new_name: String) -> void:
	army["name"] = new_name
	changed.emit()


func add_squad() -> String:
	if squads().size() >= catalog.max_squads:
		return "An army has at most %d squads." % catalog.max_squads
	var taken := squads().map(func(s: Dictionary) -> String: return String(s.get("name", "")))
	for candidate: String in SQUAD_NAMES:
		if not taken.has(candidate):
			squads().append(new_squad(candidate))
			changed.emit()
			return ""
	return "No free squad name."


## The first squad that can take another unit (the preferred one first, adding a squad if allowed), or -1.
func squad_with_room(preferred := 0) -> int:
	if not squad(preferred).is_empty() and units_of(preferred).size() < catalog.max_squad_size:
		return preferred
	for index in squads().size():
		if units_of(index).size() < catalog.max_squad_size:
			return index
	return squads().size() - 1 if add_squad() == "" else -1


## Removing a squad also removes its units (they'd have nowhere to go).
func remove_squad(squad_index: int) -> String:
	if squad(squad_index).is_empty():
		return "No such squad."
	squads().remove_at(squad_index)
	changed.emit()
	return ""


func set_formation(squad_index: int, formation: String) -> String:
	if not Formations.NAMES.has(formation):
		return "Unknown formation %s." % formation
	squad(squad_index)["formation"] = formation
	changed.emit()
	return ""


func set_squad_role(squad_index: int, role: String) -> String:
	if not Directives.ROLES.has(role):
		return "Unknown role %s." % role
	var squad_data := squad(squad_index)
	if typeof(squad_data.get("directive")) != TYPE_DICTIONARY:
		squad_data["directive"] = {}
	squad_data["directive"]["role"] = role
	changed.emit()
	return ""


func add_unit(squad_index: int, unit_id: String) -> String:
	if squad(squad_index).is_empty():
		return "Pick a squad first."
	if not catalog.has_unit(unit_id):
		return "Unknown unit %s." % unit_id
	if not catalog.is_unlocked(unit_id):
		return "The %s is locked: unlock it with credits." % catalog.display_name(unit_id)
	if unit_count() >= catalog.max_units:
		return "The army is full: %d units max." % catalog.max_units
	if units_of(squad_index).size() >= catalog.max_squad_size:
		return "%s is full: %d units per squad." % [squad(squad_index)["name"], catalog.max_squad_size]
	if catalog.unit_cost(unit_id) > remaining_budget():
		return "Not enough budget: a %s costs %d, %d left." % [catalog.display_name(unit_id), catalog.unit_cost(unit_id), remaining_budget()]
	units_of(squad_index).append({"unit": unit_id})
	changed.emit()
	return ""


func remove_unit(squad_index: int, unit_index: int) -> String:
	var entries := units_of(squad_index)
	if unit_index < 0 or unit_index >= entries.size():
		return "No such unit."
	entries.remove_at(unit_index)
	changed.emit()
	return ""


## Move a unit to another squad (appended at the end).
func move_unit(from_squad: int, unit_index: int, to_squad: int) -> String:
	var source := units_of(from_squad)
	if unit_index < 0 or unit_index >= source.size() or squad(to_squad).is_empty():
		return "Can't move that unit there."
	if from_squad == to_squad:
		return ""
	if units_of(to_squad).size() >= catalog.max_squad_size:
		return "%s is full: %d units per squad." % [squad(to_squad)["name"], catalog.max_squad_size]
	units_of(to_squad).append(source.pop_at(unit_index))
	changed.emit()
	return ""


func set_paint(squad_index: int, unit_index: int, paint: String) -> String:
	var entry := unit_at(squad_index, unit_index)
	if entry.is_empty():
		return "No such unit."
	if paint != "" and not Color.html_is_valid(paint):
		return "Not a color: %s." % paint
	if paint == "":
		entry.erase("paint")
	else:
		entry["paint"] = paint
	changed.emit()
	return ""


## Squads with no units go (they can't fight); returns how many were removed.
func drop_empty_squads() -> int:
	var before := squads().size()
	army["squads"] = squads().filter(func(s: Dictionary) -> bool: return not s.get("units", []).is_empty())
	if squads().size() != before:
		changed.emit()
	return before - squads().size()


# ---- Output ---------------------------------------------------------------------------------------

## The army JSON v2 to save and load: a deep copy plus the builder's summary.
func to_doctrine() -> Dictionary:
	var doctrine: Dictionary = army.duplicate(true)
	doctrine["garage"] = {"schema": SCHEMA, "budget": catalog.budget, "cost": total_cost(), "tier": tier}
	return doctrine
