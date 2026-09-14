class_name Loadout
extends RefCounted
## An army being built in the garage: squads of units, each with weapons by hardpoint, components,
## paint, and an optional role. Pure data + rules, no UI; the garage screen and CPU armies use it.
##
## The army is kept in DOCTRINE shape (game/ai/doctrine.gd), so saving is just writing it out and
## today's Doctrine.parse / Match.load_doctrine load it unchanged. Loadout fields per tank (the
## "Loadout fields in doctrine JSON" contract, _agents/workstreams.md):
##   {"unit": "tank", "weapon": "cannon", "weapons": {"main": "cannon"}, "components": ["heat_sink"],
##    "paint": "#d0a020", "directive": {"role": "flanker"}}
## `weapon` always mirrors the FIRST hardpoint so the simulation (which reads only `weapon` today)
## fights with the chosen main gun. Per squad the garage writes name, formation, directive.role,
## and optionally verb "hold" (player squads wait for tactical-map orders).
## The doctrine's top-level "garage" object records {schema, budget, cost} for tools and humans.

signal changed

const SCHEMA := 1
const SQUAD_NAMES := ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]
## Cosmetic paints offered in the garage ("" = team color).
const PAINTS := ["", "#c8a02a", "#3a8fd0", "#d04a8c", "#35c0a0", "#e0e0e0", "#303030"]

var catalog: GarageCatalog
var army: Dictionary


func _init(p_catalog: GarageCatalog, p_army: Dictionary = {}) -> void:
	catalog = p_catalog
	army = p_army if not p_army.is_empty() else {"name": "My Army", "squads": [new_squad("Alpha")]}
	if typeof(army.get("squads")) != TYPE_ARRAY:
		army["squads"] = []


static func new_squad(squad_name: String, formation := "wedge", role := "assault", hold := true) -> Dictionary:
	var squad := {"name": squad_name, "formation": formation, "directive": {"role": role}, "tanks": []}
	if hold:
		squad["verb"] = "hold"
	return squad


## A unit with each hardpoint holding the first weapon it accepts.
func new_unit(unit_id: String) -> Dictionary:
	var weapons := {}
	for hardpoint in catalog.hardpoints(unit_id):
		var accepts: Array = hardpoint.get("accepts", [])
		if not accepts.is_empty():
			weapons[String(hardpoint["id"])] = String(accepts[0])
	var tank := {"unit": unit_id, "weapons": weapons, "components": []}
	_sync_main_weapon(tank)
	return tank


## Accept any doctrine (a hand-written one has no loadout fields): fill unit, weapons, components.
static func from_doctrine(p_catalog: GarageCatalog, doctrine: Dictionary) -> Loadout:
	var copy: Dictionary = doctrine.duplicate(true)
	copy.erase("garage")
	var loadout := Loadout.new(p_catalog, copy)
	for squad in loadout.squads():
		if typeof(squad.get("tanks")) != TYPE_ARRAY:
			squad["tanks"] = []
		for tank: Dictionary in squad["tanks"]:
			if not tank.has("unit"):
				tank["unit"] = "tank"
			if typeof(tank.get("weapons")) != TYPE_DICTIONARY:
				var hardpoint_ids := p_catalog.hardpoints(tank["unit"]).map(func(h: Dictionary) -> String: return String(h["id"]))
				tank["weapons"] = {hardpoint_ids[0]: String(tank.get("weapon", Weapons.DEFAULT))} if not hardpoint_ids.is_empty() else {}
			if typeof(tank.get("components")) != TYPE_ARRAY:
				tank["components"] = []
			loadout._sync_main_weapon(tank)
	return loadout


# ---- Reading --------------------------------------------------------------------------

func squads() -> Array:
	return army.get("squads", [])


func squad(index: int) -> Dictionary:
	return squads()[index] if index >= 0 and index < squads().size() else {}


func unit_count() -> int:
	var count := 0
	for squad_data in squads():
		count += squad_data.get("tanks", []).size()
	return count


func unit_cost(tank: Dictionary) -> int:
	var cost := catalog.unit_cost(String(tank.get("unit", "")))
	for weapon_id in tank.get("weapons", {}).values():
		cost += catalog.weapon_cost(weapon_id)
	for component_id in tank.get("components", []):
		cost += catalog.component_cost(component_id)
	return cost


func total_cost() -> int:
	var cost := 0
	for squad_data in squads():
		for tank in squad_data.get("tanks", []):
			cost += unit_cost(tank)
	return cost


func remaining_budget() -> int:
	return catalog.budget - total_cost()


## Every problem that stops this army from fighting, as sentences a player can act on. Empty = ready.
## `with_loader` also runs today's Doctrine.parse (off only for catalogs richer than the game, in tests).
func problems(with_loader := true) -> PackedStringArray:
	var found: PackedStringArray = []
	if String(army.get("name", "")).strip_edges() == "":
		found.append("Give your army a name.")
	if squads().is_empty():
		found.append("Add a squad.")
	if squads().size() > catalog.max_squads:
		found.append("Too many squads: %d of %d." % [squads().size(), catalog.max_squads])
	for squad_data in squads():
		if squad_data.get("tanks", []).is_empty():
			found.append("%s has no units: add one or remove the squad." % squad_data.get("name", "A squad"))
		for tank in squad_data.get("tanks", []):
			var problem := unit_problem(tank)
			if problem != "":
				found.append("%s: %s" % [squad_data.get("name", "?"), problem])
	if unit_count() > catalog.max_units:
		found.append("Too many units: %d of %d." % [unit_count(), catalog.max_units])
	if total_cost() > catalog.budget:
		found.append("Over budget by %d." % (total_cost() - catalog.budget))
	if found.is_empty() and with_loader:
		# The final word belongs to the loader the match uses.
		var parsed := Doctrine.parse(to_doctrine())
		if parsed.has("error"):
			found.append("The match can't load this army: %s" % parsed["error"])
	return found


func is_ready() -> bool:
	return problems().is_empty()


func unit_problem(tank: Dictionary) -> String:
	var unit_id := String(tank.get("unit", ""))
	if not catalog.units.has(unit_id):
		return "unknown unit '%s'" % unit_id
	var unit_name := catalog.display_name(catalog.unit(unit_id), unit_id)
	var weapons: Dictionary = tank.get("weapons", {})
	for hardpoint in catalog.hardpoints(unit_id):
		var weapon_id := String(weapons.get(hardpoint["id"], ""))
		if weapon_id == "":
			return "%s needs a weapon on its %s hardpoint" % [unit_name, hardpoint["id"]]
		if not hardpoint.get("accepts", []).has(weapon_id):
			return "%s's %s hardpoint can't mount %s" % [unit_name, hardpoint["id"], weapon_id]
	for hardpoint_id in weapons:
		if not catalog.hardpoints(unit_id).any(func(h: Dictionary) -> bool: return h["id"] == hardpoint_id):
			return "%s has no %s hardpoint" % [unit_name, hardpoint_id]
	var components: Array = tank.get("components", [])
	if components.size() > catalog.component_slots(unit_id):
		return "%s has %d component slots, not %d" % [unit_name, catalog.component_slots(unit_id), components.size()]
	for component_id in components:
		if not catalog.components.has(component_id):
			return "unknown component '%s'" % component_id
	var paint := String(tank.get("paint", ""))
	if paint != "" and not Color.html_is_valid(paint):
		return "paint '%s' is not a color" % paint
	return ""


# ---- Editing (each returns "" or a reason, and emits `changed` on success) -------------------

func set_army_name(new_name: String) -> void:
	army["name"] = new_name
	changed.emit()


func add_squad() -> String:
	if squads().size() >= catalog.max_squads:
		return "An army has at most %d squads." % catalog.max_squads
	var taken := squads().map(func(s: Dictionary) -> String: return String(s["name"]))
	for candidate: String in SQUAD_NAMES:
		if not taken.has(candidate):
			squads().append(new_squad(candidate))
			changed.emit()
			return ""
	return "No free squad name."


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
	if not catalog.units.has(unit_id):
		return "Unknown unit %s." % unit_id
	if unit_count() >= catalog.max_units:
		return "The army is full: %d units max." % catalog.max_units
	var tank := new_unit(unit_id)
	if unit_cost(tank) > remaining_budget():
		return "Not enough budget: %s costs %d, %d left." % [
				catalog.display_name(catalog.unit(unit_id), unit_id), unit_cost(tank), remaining_budget()]
	squad(squad_index)["tanks"].append(tank)
	changed.emit()
	return ""


func remove_unit(squad_index: int, unit_index: int) -> String:
	var tanks: Array = squad(squad_index).get("tanks", [])
	if unit_index < 0 or unit_index >= tanks.size():
		return "No such unit."
	tanks.remove_at(unit_index)
	changed.emit()
	return ""


## Drag a unit to another squad (appended at the end).
func move_unit(from_squad: int, unit_index: int, to_squad: int) -> String:
	var source: Array = squad(from_squad).get("tanks", [])
	if unit_index < 0 or unit_index >= source.size() or squad(to_squad).is_empty():
		return "Can't move that unit there."
	if from_squad == to_squad:
		return ""
	squad(to_squad)["tanks"].append(source.pop_at(unit_index))
	changed.emit()
	return ""


func unit_at(squad_index: int, unit_index: int) -> Dictionary:
	var tanks: Array = squad(squad_index).get("tanks", [])
	return tanks[unit_index] if unit_index >= 0 and unit_index < tanks.size() else {}


func set_weapon(squad_index: int, unit_index: int, hardpoint_id: String, weapon_id: String) -> String:
	var tank := unit_at(squad_index, unit_index)
	if tank.is_empty():
		return "No such unit."
	var hardpoint: Dictionary = {}
	for candidate in catalog.hardpoints(tank["unit"]):
		if candidate["id"] == hardpoint_id:
			hardpoint = candidate
	if hardpoint.is_empty():
		return "No %s hardpoint." % hardpoint_id
	if not hardpoint.get("accepts", []).has(weapon_id):
		return "The %s hardpoint can't mount %s." % [hardpoint_id, weapon_id]
	var extra := catalog.weapon_cost(weapon_id) - catalog.weapon_cost(String(tank["weapons"].get(hardpoint_id, "")))
	if extra > remaining_budget():
		return "Not enough budget for %s: %d more, %d left." % [weapon_id, extra, remaining_budget()]
	tank["weapons"][hardpoint_id] = weapon_id
	_sync_main_weapon(tank)
	changed.emit()
	return ""


func add_component(squad_index: int, unit_index: int, component_id: String) -> String:
	var tank := unit_at(squad_index, unit_index)
	if tank.is_empty():
		return "No such unit."
	if not catalog.components.has(component_id):
		return "Unknown component %s." % component_id
	if tank["components"].size() >= catalog.component_slots(tank["unit"]):
		return "No free component slot."
	if catalog.component_cost(component_id) > remaining_budget():
		return "Not enough budget for %s." % catalog.display_name(catalog.component(component_id), component_id)
	tank["components"].append(component_id)
	changed.emit()
	return ""


func remove_component(squad_index: int, unit_index: int, component_index: int) -> String:
	var tank := unit_at(squad_index, unit_index)
	if tank.is_empty() or component_index < 0 or component_index >= tank["components"].size():
		return "No such component."
	tank["components"].remove_at(component_index)
	changed.emit()
	return ""


func set_unit_role(squad_index: int, unit_index: int, role: String) -> String:
	var tank := unit_at(squad_index, unit_index)
	if tank.is_empty():
		return "No such unit."
	if role == "":
		tank.erase("directive")
	elif not Directives.ROLES.has(role):
		return "Unknown role %s." % role
	else:
		tank["directive"] = {"role": role}
	changed.emit()
	return ""


func set_paint(squad_index: int, unit_index: int, paint: String) -> String:
	var tank := unit_at(squad_index, unit_index)
	if tank.is_empty():
		return "No such unit."
	if paint != "" and not Color.html_is_valid(paint):
		return "Not a color: %s." % paint
	if paint == "":
		tank.erase("paint")
	else:
		tank["paint"] = paint
	changed.emit()
	return ""


# ---- Output ---------------------------------------------------------------------------------

## The doctrine the match loads: a deep copy with `weapon` mirrored and the garage summary added.
func to_doctrine() -> Dictionary:
	var doctrine: Dictionary = army.duplicate(true)
	for squad_data in doctrine.get("squads", []):
		for tank in squad_data.get("tanks", []):
			_sync_main_weapon(tank)
	doctrine["garage"] = {"schema": SCHEMA, "budget": catalog.budget, "cost": total_cost()}
	return doctrine


func _sync_main_weapon(tank: Dictionary) -> void:
	var hardpoints := catalog.hardpoints(String(tank.get("unit", "")))
	if hardpoints.is_empty():
		return
	var main_weapon := String(tank.get("weapons", {}).get(hardpoints[0]["id"], ""))
	if main_weapon != "":
		tank["weapon"] = main_weapon
