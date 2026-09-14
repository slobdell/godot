class_name GarageAdvice
extends RefCounted
## Makes counters readable while an army is built: composition hints ("your tanks are weak vs scouts and
## nothing here counters them: add an IFV") and the COMPARE table. Pure data over the catalog's
## good_vs / weak_vs roles (design intent from catalog v2), so new units get advice without changes here.

## Columns in the comparison: [key, header]. "weapon", "good_vs", "weak_vs" are text; the rest numbers.
const UNIT_COLUMNS := [["cost", "Cost"], ["max_health", "Hull"], ["max_shield", "Shield"], ["max_forward_speed", "Speed"],
		["sight_radius", "Sight"], ["weapon", "Weapon"], ["good_vs", "Good vs"], ["weak_vs", "Weak vs"]]
## Stats where LOWER is better (highlighting picks the minimum).
const LOWER_IS_BETTER := ["cost"]


## Short, actionable hints about an army's composition, most important first.
static func composition_hints(draft: ArmyDraft) -> PackedStringArray:
	var catalog := draft.catalog
	var hints: PackedStringArray = []
	var counts := draft.counts_by_unit()
	if counts.is_empty():
		return hints
	var my_roles := {}
	for unit_id: String in counts:
		my_roles[catalog.role(unit_id)] = true
	# Each weakness of a unit I own that nothing I own is good against.
	var reported := {}
	for unit_id: String in counts:
		for threat: Variant in catalog.weak_vs(unit_id):
			var threat_role := String(threat)
			if reported.has(threat_role) or _army_counters(draft, threat_role):
				continue
			reported[threat_role] = true
			var fix := _counter_for(catalog, threat_role)
			hints.append("Your %s %s weak vs %s and nothing here counters them%s." % [_plural(catalog, unit_id, counts[unit_id]),
					"is" if counts[unit_id] == 1 else "are", _role_plural(threat_role),
					": add %s" % _with_article(catalog.display_name(fix)) if fix != "" else ""])
	if my_roles.has("artillery") and not my_roles.has("scout"):
		var scout := ArmyPresets.unit_for_role(catalog, "scout")
		if scout != "" and catalog.role(scout) == "scout":
			hints.append("Artillery hits what teammates see: a scout spots for it from far away.")
	if my_roles.size() == 1 and catalog.units.size() > 1:
		hints.append("One unit type is easy to counter: mix in a second type.")
	return hints


static func _army_counters(draft: ArmyDraft, threat_role: String) -> bool:
	for unit_id: String in draft.counts_by_unit():
		if draft.catalog.good_vs(unit_id).has(threat_role):
			return true
	return false


## An unlocked unit designed to beat `threat_role`, cheapest first; "" if none.
static func _counter_for(catalog: ArmyCatalog, threat_role: String) -> String:
	for unit_id in catalog.unit_ids():
		if catalog.is_unlocked(unit_id) and catalog.good_vs(unit_id).has(threat_role):
			return unit_id
	return ""


static func _plural(catalog: ArmyCatalog, unit_id: String, count: int) -> String:
	var unit_name := catalog.display_name(unit_id)
	return unit_name if count == 1 else _pluralize(unit_name)


static func _role_plural(role: String) -> String:
	return _pluralize(ArmyCatalog.role_label(role)).to_lower() if role != "ifv" else "IFVs"


static func _pluralize(word: String) -> String:
	if word.to_lower() == "artillery":
		return word
	if word.ends_with("y") and not word.ends_with("ey"):
		return word.trim_suffix("y") + "ies"
	return word + "s"


static func _with_article(word: String) -> String:
	if word.to_lower() == "artillery":
		return "artillery"
	return ("an " if word.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


## {"headers": [String], "rows": [[label, value text…]], "best": [[bool…]]} for every unit type.
static func unit_table(catalog: ArmyCatalog) -> Dictionary:
	var headers := [""]
	for column in UNIT_COLUMNS:
		headers.append(column[1])
	var ids := catalog.unit_ids()
	var rows := []
	var best := []
	for unit_id in ids:
		var row := [catalog.display_name(unit_id) + ("" if catalog.is_unlocked(unit_id) else " (locked)")]
		var marks := [false]
		for column in UNIT_COLUMNS:
			match String(column[0]):
				"weapon":
					row.append(catalog.weapon_name(unit_id))
					marks.append(false)
				"good_vs", "weak_vs":
					var roles: Array = catalog.unit(unit_id).get(column[0], [])
					row.append(", ".join(roles.map(func(r: Variant) -> String: return ArmyCatalog.role_label(String(r)))) if not roles.is_empty() else "-")
					marks.append(false)
				_:
					var value := float(catalog.unit(unit_id).get(column[0], 0.0))
					row.append(ArmyCatalog.number(value))
					marks.append(_is_best(catalog, ids, String(column[0]), value))
		rows.append(row)
		best.append(marks)
	return {"headers": headers, "rows": rows, "best": best}


## True if `value` is the best in its column, and the column isn't all ties.
static func _is_best(catalog: ArmyCatalog, ids: Array[String], key: String, value: float) -> bool:
	var values := ids.map(func(id: String) -> float: return float(catalog.unit(id).get(key, 0.0)))
	if values.min() == values.max():
		return false
	return is_equal_approx(value, values.min() if key in LOWER_IS_BETTER else values.max())
