// Round 24 (native, N3d): TankBrain.decide (game/ai/tank_brain.gd) as ONE call: every option's score from the
// situation, the order's filter (_obey), the cooldowns, the flip-back penalty, the flat commitment bonus, the best
// candidate (the first strict maximum, in the candidates' order) and the ranked top three (_top). The candidates are
// built in the GDScript's order as the same Dictionaries, so ties break the same way: an EQUAL port, not a declared one.
// It runs in the default arm only (no `--tune=switch.cost=1`, no switch probe: NativeDecide.usable); the rarely used
// helpers (`_is_prey`, `rounds_barely_mark`, `ElementFeed.is_firing_base`, a variant's `matchups_for`,
// `SuppressionFeed.suppresses`) are asked of the live GDScript. Widths: every score is a GDScript float (double).
// tests/test_native_decide.gd decides both ways on real situations.
#include "tank_native.h"
#include "decide_native.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>

#include <cmath>

namespace godot {

namespace {

struct DN {
	StringName self{ "self" }, directives{ "directives" }, weapon{ "weapon" }, health{ "health" }, max_health{ "max_health" },
			max_shield{ "max_shield" }, shield{ "shield" }, contacts{ "contacts" }, objective{ "objective" }, leash{ "leash" },
			position{ "position" }, squad{ "squad" }, slot{ "slot" }, element{ "element" }, features{ "features" },
			tactics{ "tactics" }, squad_tactics{ "squad_tactics" }, fragile_threats{ "fragile_threats" },
			max_ammo{ "max_ammo" }, ammo{ "ammo" }, class_{ "class" }, heat{ "heat" }, visible{ "visible" },
			pinned{ "pinned" }, aiming_at_me{ "aiming_at_me" }, threatens_me{ "threatens_me" }, caution{ "caution" },
			verb{ "verb" }, in_resupply_zone{ "in_resupply_zone" }, cover{ "cover" }, option{ "option" }, target{ "target" },
			score{ "score" }, matchups{ "matchups" }, kill_rate{ "kill_rate" }, avoid_beaten{ "avoid_beaten" },
			range{ "range" }, reload_windows{ "reload_windows" }, name{ "name" }, age{ "age" }, target_priority{ "target_priority" },
			aggression{ "aggression" }, advantage{ "advantage" }, orbit{ "orbit" }, focus{ "focus" },
			cover_target{ "cover_target" }, suppress_proxy{ "suppress_proxy" }, flank_target{ "flank_target" },
			pinned_exposed{ "pinned_exposed" }, suppression{ "suppression" }, flanking{ "flanking" }, facing_ally{ "facing_ally" },
			exposed_face{ "exposed_face" }, memory_ticks{ "memory_ticks" }, cover_fire{ "cover_fire" }, unit{ "unit" },
			kind{ "kind" }, reload{ "reload" }, lane_blocked_ticks{ "lane_blocked_ticks" }, hold_for_friends{ "hold_for_friends" },
			commit_bonus{ "commit_bonus" }, allies{ "allies" }, squad_center{ "squad_center" }, cohesion{ "cohesion" },
			objective_radius{ "objective_radius" }, control{ "control" }, center{ "center" }, radius{ "radius" },
			owner{ "owner" }, team{ "team" }, moving{ "moving" }, overwatch{ "overwatch" }, cooldowns{ "cooldowns" },
			tick{ "tick" }, order{ "order" }, left{ "left" }, choice{ "choice" }, ranked{ "ranked" }, goal{ "goal" },
			target_alive{ "target_alive" }, denied_wait{ "denied_wait" }, no_loaded_peek{ "no_loaded_peek" },
			// helpers asked of the GDScript
			matchups_for{ "matchups_for" }, _is_prey_contact{ "_is_prey_contact" }, _is_prey{ "_is_prey" },
			rounds_barely_mark{ "rounds_barely_mark" }, suppresses{ "suppresses" }, is_firing_base{ "is_firing_base" },
			PROFILES{ "PROFILES" }, role{ "role" }, good_vs{ "good_vs" }, armor{ "armor" }, penetration{ "penetration" },
			burst_count{ "burst_count" };
	String RETREAT{ "RETREAT" }, RESUPPLY{ "RESUPPLY" }, TAKE_COVER{ "TAKE_COVER" }, RECHARGE{ "RECHARGE" }, ENGAGE{ "ENGAGE" },
			COVER_FIRE{ "COVER_FIRE" }, FLANK{ "FLANK" }, SUPPRESS{ "SUPPRESS" }, ORBIT{ "ORBIT" }, CLEAR_LANE{ "CLEAR_LANE" },
			BOMBARD{ "BOMBARD" }, SHADOW{ "SHADOW" }, SPOT{ "SPOT" }, INVESTIGATE{ "INVESTIGATE" }, REGROUP{ "REGROUP" },
			ADVANCE{ "ADVANCE" }, CONTEST{ "CONTEST" }, KEEP_SLOT{ "KEEP_SLOT" }, HOLD{ "HOLD" }, MOVE{ "MOVE" },
			FOLLOW{ "FOLLOW" }, PURSUE{ "PURSUE" }, empty{ "" }, scout{ "scout" }, artillery{ "artillery" }, tank{ "tank" },
			assault{ "assault" }, move{ "move" }, bound{ "bound" }, hold{ "hold" }, break_contact{ "break_contact" },
			stop{ "stop" }, attack{ "attack" }, attack_move{ "attack_move" }, follow{ "follow" }, idle{ "idle" },
			front{ "front" }, rear{ "rear" }, side{ "side" }, weakest{ "weakest" }, most_exposed{ "most_exposed" },
			threatening_allies{ "threatening_allies" }, mortar{ "mortar" }, overwatch_role{ "overwatch" },
			base_of_fire{ "base_of_fire" };
};
const DN &dn_() {
	static const DN n;
	return n;
}

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double lerpd(double a, double b, double t) {
	return a + (b - a) * t; // Math::lerp(double)
}
inline double snapped(double value, double step) {
	return step != 0.0 ? std::floor(value / step + 0.5) * step : value; // Math::snapped(double)
}
inline double num(const Dictionary &d, const StringName &key, const Variant &fallback) {
	return (double)d.get(key, fallback);
}

Dictionary candidate(const String &option, const Variant &target, double score) {
	const DN &k = dn_();
	Dictionary c;
	c[k.option] = option;
	c[k.target] = target;
	c[k.score] = score;
	return c;
}

// One contact's fields decide reads, read once (each Dictionary read crosses the GDExtension boundary).
struct ContactRow {
	Dictionary dict;
	Variant name;
	Vector3 position;
	int64_t age = 0;
	double health = 0.0, shield = 0.0, suppression = 0.0;
	String exposed_face;
	bool visible = false, pinned = false, aiming = false, threatens = false, facing_ally = false;
};

void read_rows(const DN &k, const Array &contacts, LocalVector<ContactRow> &rows) {
	rows.resize(contacts.size());
	for (int64_t i = 0; i < contacts.size(); i++) {
		ContactRow &r = rows[i];
		r.dict = contacts[i];
		r.name = r.dict[k.name];
		r.position = r.dict[k.position];
		r.age = r.dict[k.age];
		r.health = r.dict[k.health];
		r.shield = r.dict.get(k.shield, 0.0);
		r.suppression = r.dict.get(k.suppression, 0.0);
		r.exposed_face = r.dict[k.exposed_face];
		r.visible = r.dict[k.visible];
		r.pinned = r.dict.get(k.pinned, false);
		r.aiming = r.dict[k.aiming_at_me];
		// c.get("threatens_me", c["aiming_at_me"])
		r.threatens = r.dict.has(k.threatens_me) ? (bool)r.dict[k.threatens_me] : r.aiming;
		r.facing_ally = r.dict[k.facing_ally];
	}
}

// TankBrain._priority(rule, contact, distance), over a read row
double priority_row(const DecideConsts &c, const DN &k, const String &rule, const ContactRow &r, double distance) {
	if (rule == k.weakest) {
		return 1.0 - clampd((r.health + r.shield) / c.FULL_TANK_HEALTH, 0.0, 1.0);
	}
	if (rule == k.most_exposed) {
		return r.exposed_face == k.rear ? 1.0 : (r.exposed_face == k.side ? 0.7 : 0.3);
	}
	if (rule == k.threatening_allies) {
		return r.facing_ally ? 1.0 : 0.3;
	}
	return 1.0 - clampd(distance / 150.0, 0.0, 1.0);
}

// TankBrain._priority(rule, contact, distance)
double priority(const DecideConsts &c, const DN &k, const String &rule, const Dictionary &contact, double distance) {
	if (rule == k.weakest) {
		return 1.0 - clampd(((double)contact[k.health] + num(contact, k.shield, 0.0)) / c.FULL_TANK_HEALTH, 0.0, 1.0);
	}
	if (rule == k.most_exposed) {
		const String face = contact[k.exposed_face];
		// {"rear": 1.0, "side": 0.7, "front": 0.3}[face]
		return face == k.rear ? 1.0 : (face == k.side ? 0.7 : 0.3);
	}
	if (rule == k.threatening_allies) {
		return (bool)contact[k.facing_ally] ? 1.0 : 0.3;
	}
	return 1.0 - clampd(distance / 150.0, 0.0, 1.0);
}

// TankBrain.b1_part(features, part)
bool b1_part(const DN &k, const Dictionary &features, const StringName &part) {
	return (bool)features.get(part, features.get(k.no_loaded_peek, false));
}

// Matchups.penetration_multiplier (matchups.gd; the same as matchups_native.cpp's)
double penetration_multiplier(double penetration, double thickness) {
	if (thickness <= 0.0) {
		return 1.5;
	}
	if (penetration <= 0.0) {
		return 0.05;
	}
	return clampd(0.5 * std::log(1.6 * penetration / thickness) / std::log(2.0), 0.05, 1.5);
}

// TankBrain._is_prey(contact, my_unit): a mortar, or a unit whose role my unit is good against (Units' table).
bool is_prey(const DecideConsts &c, const DN &k, const Dictionary &profiles, const Dictionary &contact, const String &my_unit) {
	if (contact.get(k.weapon, k.empty) == Variant(k.mortar)) {
		return true;
	}
	const String unit = contact.get(k.unit, k.empty);
	const String role = profiles.has(unit) ? String(((Dictionary)profiles[unit]).get(k.role, k.empty)) : k.empty;
	return role != k.empty && ((Array)((Dictionary)profiles.get(my_unit, Dictionary())).get(k.good_vs, Array())).has(role);
}

// TankBrain.rounds_barely_mark(weapon, contact)
bool rounds_barely_mark(const DecideConsts &c, const DN &k, const Dictionary &profiles, const Dictionary &weapon,
		const Dictionary &contact) {
	if (!weapon.has(k.penetration)) {
		return false;
	}
	const Variant armor = ((Dictionary)profiles.get(String(contact.get(k.unit, k.empty)), Dictionary())).get(k.armor, Variant());
	if (armor.get_type() != Variant::DICTIONARY) {
		return false;
	}
	const double thickness = num((Dictionary)armor, StringName(String(contact.get(k.exposed_face, k.front))), 0.0);
	return thickness > 0.0 && penetration_multiplier((double)weapon[k.penetration], thickness) <= c.SUPPRESS_PENETRATION;
}

// TankBrain._obey
Array obey(const DecideConsts &c, const DN &k, const Array &candidates, const Dictionary &o, const Dictionary &s, bool critical,
		bool out_of_ammo) {
	const String verb = o[k.verb];
	const Array allowed = c.ORDER_OPTIONS.get(verb, Array());
	const String target = o.get(k.target, String());
	const Array contacts = s[k.contacts];
	bool target_fresh = false;
	bool anything_visible = false;
	for (int64_t i = 0; i < contacts.size(); i++) {
		const Dictionary cc = contacts[i];
		if (String(cc[k.name]) == target && (int64_t)cc[k.age] <= c.CONTACT_FRESH_TICKS) {
			target_fresh = true;
		}
		if ((bool)cc[k.visible]) {
			anything_visible = true;
		}
	}
	Array in_reach;
	const Dictionary me = s[k.self];
	const Vector3 my_position = me[k.position];
	const double reach = (double)((Dictionary)me[k.weapon])[k.range] + c.ATTACK_MOVE_REACH_MARGIN;
	for (int64_t i = 0; i < contacts.size(); i++) {
		const Dictionary cc = contacts[i];
		if ((bool)cc[k.visible] && (double)my_position.distance_to(cc[k.position]) <= reach) {
			in_reach.push_back(cc[k.name]);
		}
	}
	Array result;
	for (int64_t i = 0; i < candidates.size(); i++) {
		Dictionary cand = candidates[i];
		const String option = cand[k.option];
		if (!allowed.has(option)) {
			continue;
		}
		if (verb == k.hold) {
			cand[k.score] = 1.0;
		} else if (verb == k.attack) {
			if (cand[k.target] != Variant(target)) {
				continue;
			}
			cand[k.score] = 1.0 + (double)cand[k.score];
		} else if (verb == k.attack_move) {
			if (option == k.RETREAT) {
				if (!critical) {
					continue;
				}
				cand[k.score] = 0.99;
			} else if (target != k.empty && cand[k.target] != Variant(k.empty) && cand[k.target] != Variant(target)) {
				continue;
			} else if (in_reach.has(cand[k.target])) {
				cand[k.score] = c.ATTACK_MOVE_FIGHT + (double)cand[k.score];
			}
		} else if (verb == k.idle) {
			if ((option == k.SPOT && !anything_visible) || (option == k.RESUPPLY && !out_of_ammo)) {
				continue;
			}
		}
		result.push_back(cand);
	}
	const Variant goal = o.get(k.goal, Variant());
	if (verb == k.move || verb == k.stop) {
		if (goal.get_type() != Variant::NIL) {
			result.push_back(candidate(k.MOVE, k.empty, 1.0));
		}
	} else if (verb == k.attack_move) {
		if (goal.get_type() != Variant::NIL) {
			result.push_back(candidate(k.MOVE, k.empty, c.ATTACK_MOVE_WEIGHT));
		}
	} else if (verb == k.follow) {
		if ((bool)o.get(k.target_alive, false)) {
			result.push_back(candidate(k.FOLLOW, target, 1.0));
		}
	} else if (verb == k.attack) {
		if ((bool)o.get(k.target_alive, false) && !target_fresh) {
			result.push_back(candidate(k.PURSUE, target, 1.0));
		} else if (target_fresh) {
			bool any_positive = false;
			for (int64_t i = 0; i < result.size(); i++) {
				if ((double)((Dictionary)result[i])[k.score] > 0.0) {
					any_positive = true;
					break;
				}
			}
			if (!any_positive) {
				result.push_back(candidate(k.ENGAGE, target, 1.0));
			}
		}
	}
	if (result.is_empty()) {
		result.push_back(candidate(k.HOLD, k.empty, 0.1));
	}
	return result;
}

// TankBrain._top(candidates, count)
Array top(const DN &k, const Array &candidates, int count) {
	Array remaining = candidates.duplicate();
	Array result;
	while (result.size() < count && !remaining.is_empty()) {
		int64_t best_index = 0;
		for (int64_t i = 0; i < remaining.size(); i++) {
			if ((double)((Dictionary)remaining[i])[k.score] > (double)((Dictionary)remaining[best_index])[k.score]) {
				best_index = i;
			}
		}
		const Dictionary picked = remaining.pop_at(best_index);
		Dictionary entry;
		entry[k.option] = picked[k.option];
		entry[k.target] = picked[k.target];
		entry[k.score] = snapped((double)picked[k.score], 0.001);
		result.push_back(entry);
	}
	return result;
}

struct ScorePair {
	Variant name;
	double score;
	bool flag = false;
};

} // namespace

bool TankNative::decide_configure(const Dictionary &config) {
	DecideConsts &c = decide_consts;
	struct D {
		const char *name;
		double *field;
	};
	const D doubles[] = { { "HOT_FIREPOWER", &c.HOT_FIREPOWER }, { "PINNED_THREAT_FACTOR", &c.PINNED_THREAT_FACTOR },
		{ "PINNED_RETREAT_HP", &c.PINNED_RETREAT_HP }, { "CRITICAL_HP_MIN", &c.CRITICAL_HP_MIN },
		{ "CRITICAL_HP_MAX", &c.CRITICAL_HP_MAX }, { "RESUPPLY_TOP_UP", &c.RESUPPLY_TOP_UP },
		{ "REPAIR_TOP_UP", &c.REPAIR_TOP_UP }, { "PINNED_COVER", &c.PINNED_COVER },
		{ "SHIELD_DOWN_BREAK_HP", &c.SHIELD_DOWN_BREAK_HP }, { "RECHARGED", &c.RECHARGED },
		{ "ORBIT_KEEP_ADVANTAGE", &c.ORBIT_KEEP_ADVANTAGE }, { "ORBIT_START_ADVANTAGE", &c.ORBIT_START_ADVANTAGE },
		{ "FOCUS_BONUS", &c.FOCUS_BONUS }, { "COVER_TEAMMATE_BONUS", &c.COVER_TEAMMATE_BONUS },
		{ "FRAGILE_THREAT_BONUS", &c.FRAGILE_THREAT_BONUS }, { "ORDER_WEIGHT", &c.ORDER_WEIGHT },
		{ "SUPPRESS_KILL_RATIO", &c.SUPPRESS_KILL_RATIO }, { "PIN_HOLD_FRACTION", &c.PIN_HOLD_FRACTION },
		{ "PINNED_SUPPRESSION", &c.PINNED_SUPPRESSION }, { "SUPPRESS_WEIGHT", &c.SUPPRESS_WEIGHT },
		{ "PINNED_FLANK_BONUS", &c.PINNED_FLANK_BONUS }, { "FLANKER_APPETITE", &c.FLANKER_APPETITE },
		{ "SCOUT_FIGHT", &c.SCOUT_FIGHT }, { "SCOUT_HUNT", &c.SCOUT_HUNT }, { "SCOUT_HUNT_FLOOR", &c.SCOUT_HUNT_FLOOR },
		{ "COVER_FIRE_RELOAD_FLOOR", &c.COVER_FIRE_RELOAD_FLOOR }, { "PINNED_COVER_FIRE", &c.PINNED_COVER_FIRE },
		{ "SUPPRESS_UNDER_WINNABLE", &c.SUPPRESS_UNDER_WINNABLE }, { "COMMIT_BONUS", &c.COMMIT_BONUS },
		{ "CLEAR_LANE_EDGE", &c.CLEAR_LANE_EDGE }, { "SCOUT_STANDOFF", &c.SCOUT_STANDOFF },
		{ "SLOT_TOLERANCE", &c.SLOT_TOLERANCE }, { "COOLDOWN_FACTOR", &c.COOLDOWN_FACTOR }, { "REVISIT_S", &c.REVISIT_S },
		{ "REVISIT_FACTOR", &c.REVISIT_FACTOR }, { "ATTACK_MOVE_REACH_MARGIN", &c.ATTACK_MOVE_REACH_MARGIN },
		{ "ATTACK_MOVE_FIGHT", &c.ATTACK_MOVE_FIGHT }, { "ATTACK_MOVE_WEIGHT", &c.ATTACK_MOVE_WEIGHT },
		{ "LOW_AMMO_FRACTION", &c.LOW_AMMO_FRACTION }, { "FULL_TANK_HEALTH", &c.FULL_TANK_HEALTH } };
	for (const D &d : doubles) {
		if (!config.has(d.name)) {
			c.ready = false;
			return false;
		}
		*d.field = config[d.name];
	}
	struct I {
		const char *name;
		int64_t *field;
	};
	const I ints[] = { { "COVER_FIRE_MEMORY_TICKS", &c.COVER_FIRE_MEMORY_TICKS },
		{ "COVER_DENIED_MEMORY_TICKS", &c.COVER_DENIED_MEMORY_TICKS }, { "CONTACT_FRESH_TICKS", &c.CONTACT_FRESH_TICKS },
		{ "ORBIT_MEMORY_TICKS", &c.ORBIT_MEMORY_TICKS }, { "LANE_BLOCKED_TICKS", &c.LANE_BLOCKED_TICKS },
		{ "TICK_RATE", &c.TICK_RATE }, { "KIND_ARC", &c.KIND_ARC } };
	for (const I &d : ints) {
		if (!config.has(d.name)) {
			c.ready = false;
			return false;
		}
		*d.field = config[d.name];
	}
	c.ORDER_OPTIONS = config.get("ORDER_OPTIONS", Dictionary());
	c.FIGHT_OPTIONS = config.get("FIGHT_OPTIONS", Array());
	c.keep_brain = config.get("brain", Variant());
	c.keep_suppression = config.get("suppression_feed", Variant());
	c.keep_element = config.get("element_feed", Variant());
	c.keep_units = config.get("units", Variant());
	c.units = c.keep_units.get_validated_object();
	c.SUPPRESS_PENETRATION = config.get("SUPPRESS_PENETRATION", 0.0);
	c.SUPPRESSING_WEAPON = config.get("SUPPRESSING_WEAPON", 0.0);
	c.brain_script = c.keep_brain.get_validated_object();
	c.suppression_feed = c.keep_suppression.get_validated_object();
	c.element_feed = c.keep_element.get_validated_object();
	c.ready = c.brain_script != nullptr && c.suppression_feed != nullptr && c.element_feed != nullptr && c.units != nullptr &&
			config.has("SUPPRESS_PENETRATION") && config.has("SUPPRESSING_WEAPON");
	return c.ready;
}

Dictionary TankNative::decide(const Dictionary &s, const Dictionary &current) const {
	const DecideConsts &c = decide_consts;
	const DN &k = dn_();
	if (!c.ready) {
		return Dictionary();
	}
	const Dictionary me = s[k.self];
	const Dictionary d = s[k.directives];
	const Dictionary weapon = me[k.weapon];
	const double hp = (double)me[k.health] / (double)me[k.max_health];
	const double max_shield = num(me, k.max_shield, 0.0);
	const double shield = num(me, k.shield, 0.0);
	const double toughness = ((double)me[k.health] + shield) / ((double)me[k.max_health] + max_shield);
	const bool shield_down = max_shield > 0.0 && shield <= 0.0;
	const double confidence = lerpd(0.35, 1.0, toughness);
	const Array contacts = s[k.contacts];
	const Variant objective = s[k.objective];
	const double leash = d[k.leash];
	const Vector3 my_position = me[k.position];
	const Variant squad = s.get(k.squad, Variant());
	const bool commanded = squad.get_type() != Variant::NIL && ((Dictionary)squad)[k.slot].get_type() != Variant::NIL;
	const Variant element_v = s.get(k.element, Variant());
	const Dictionary element_context = element_v.get_type() != Variant::NIL ? (Dictionary)element_v : Dictionary();
	const Dictionary features = s.get(k.features, Dictionary());
	const Dictionary tactics = (bool)features.get(k.squad_tactics, true) ? (Dictionary)s.get(k.tactics, Dictionary()) : Dictionary();
	const Array fragile_threats = tactics.get(k.fragile_threats, Array());

	int64_t visible_threats = 0;
	int64_t threats_on_me = 0;
	const int64_t max_ammo = me.get(k.max_ammo, -1);
	const int64_t ammo = me.get(k.ammo, -1);
	const bool out_of_ammo = max_ammo > 0 && ammo == 0;
	const String unit_class = me.get(k.class_, k.tank);
	const bool is_scout = unit_class == k.scout;
	const bool is_artillery = unit_class == k.artillery;
	const double firepower = out_of_ammo ? 0.1 :
			lerpd(1.0, c.HOT_FIREPOWER, clampd((num(me, k.heat, 0.0) - 0.7) / 0.3, 0.0, 1.0));
	int64_t exposed_to = 0;
	LocalVector<ContactRow> rows;
	read_rows(k, contacts, rows);
	for (const ContactRow &r : rows) {
		if (r.visible) {
			visible_threats += 1;
			const double weight = r.pinned ? c.PINNED_THREAT_FACTOR : 1.0;
			if (r.aiming) {
				threats_on_me += weight >= 1.0 ? 1 : 0;
			}
			if (r.threatens) {
				exposed_to += weight >= 1.0 ? 1 : 0;
			}
		}
	}
	Array candidates;
	const bool pinned = me.get(k.pinned, false);
	const double caution = d[k.caution];
	const double retreat_threshold = lerpd(0.15, 0.55, caution) + (pinned ? c.PINNED_RETREAT_HP : 0.0);
	double retreat = 0.0;
	if (commanded && String(((Dictionary)squad)[k.verb]) != k.assault) {
		if (hp < lerpd(c.CRITICAL_HP_MIN, c.CRITICAL_HP_MAX, caution) && visible_threats > 0) {
			retreat = 0.99;
		}
	} else if (hp < retreat_threshold && visible_threats > 0) {
		retreat = 0.85 + 0.1 * caution;
	} else if (visible_threats >= 3 && hp < 0.6) {
		retreat = 0.45 * caution;
	}
	candidates.push_back(candidate(k.RETREAT, k.empty, retreat));
	double resupply = 0.0;
	if (max_ammo > 0) {
		const double ammo_ratio = (double)ammo / (double)max_ammo;
		if (out_of_ammo) {
			resupply = 0.9;
		} else if ((bool)me.get(k.in_resupply_zone, false) && ammo_ratio < c.RESUPPLY_TOP_UP) {
			resupply = visible_threats == 0 ? 0.9 : 0.5;
		} else if (ammo_ratio <= c.LOW_AMMO_FRACTION && visible_threats == 0) {
			resupply = 0.5;
		}
	}
	if ((bool)me.get(k.in_resupply_zone, false) && hp < c.REPAIR_TOP_UP && visible_threats == 0) {
		resupply = MAX(resupply, 0.85);
	} else if (hp < retreat_threshold && visible_threats == 0 && !commanded) {
		resupply = MAX(resupply, 0.6);
	}
	candidates.push_back(candidate(k.RESUPPLY, k.empty, resupply));
	double cover = 0.0;
	const bool has_cover = !((Array)s[k.cover]).is_empty();
	if (has_cover && MAX(threats_on_me, exposed_to) > 0) {
		cover = caution * MIN(1.0, (double)MAX(threats_on_me, exposed_to) / 2.0) * (1.0 - toughness) * 1.6;
	}
	if (pinned && has_cover) {
		cover = MAX(cover, c.PINNED_COVER);
	}
	candidates.push_back(candidate(k.TAKE_COVER, k.empty, cover));
	double recharge = 0.0;
	if (shield_down && threats_on_me > 0 && hp < c.SHIELD_DOWN_BREAK_HP) {
		recharge = 0.4 + 0.3 * caution;
	} else if (max_shield > 0.0 && String(current.get(k.option, k.empty)) == k.RECHARGE && shield < max_shield * c.RECHARGED &&
			visible_threats > 0) {
		recharge = 0.5;
	}
	candidates.push_back(candidate(k.RECHARGE, k.empty, recharge));
	const Dictionary matchups = (bool)features.get(k.matchups, true) ? (Dictionary)c.brain_script->call(k.matchups_for, s) : Dictionary();
	double best_kill_rate = 0.0;
	{
		const Array values = matchups.values();
		for (int64_t i = 0; i < values.size(); i++) {
			best_kill_rate = MAX(best_kill_rate, (double)((Dictionary)values[i])[k.kill_rate]);
		}
	}
	LocalVector<ScorePair> engages, flanks, orbits, investigates, suppressions;
	// SuppressionFeed.suppresses(weapon): weapon_suppression(weapon) >= SUPPRESSING_WEAPON
	const double weapon_suppression = weapon.has(k.suppression) ? MAX((double)weapon[k.suppression], 0.0) :
			MAX(num(weapon, k.burst_count, 1), 1.0) / MAX(num(weapon, k.reload, 1.0), 0.05) * 0.01;
	const bool suppresses = weapon_suppression >= c.SUPPRESSING_WEAPON && !out_of_ammo && (bool)features.get(k.avoid_beaten, true);
	const Dictionary profiles = c.units->get(k.PROFILES);
	const double weapon_range = weapon[k.range];
	const String current_option = current.get(k.option, k.empty);
	const Variant current_target = current.get(k.target, k.empty);
	const String target_priority = d[k.target_priority];
	const double aggression = d[k.aggression];
	const bool f_reload_windows = features.get(k.reload_windows, false);
	const bool f_denied_wait = b1_part(k, features, k.denied_wait);
	const bool f_suppress_proxy = features.get(k.suppress_proxy, false);
	const bool f_pinned_exposed = features.get(k.pinned_exposed, false);
	const Variant t_focus = tactics.get(k.focus, k.empty);
	const Variant t_cover_target = tactics.get(k.cover_target, k.empty);
	const Variant t_flank_target = tactics.get(k.flank_target, k.empty);
	const double d_flanking = d[k.flanking];
	const bool has_objective = objective.get_type() != Variant::NIL;
	const Vector3 objective_point = has_objective ? (Vector3)objective : Vector3();
	for (const ContactRow &row : rows) {
		const Dictionary &cc = row.dict;
		const Variant &cname = row.name;
		const double distance = my_position.distance_to(row.position);
		const bool in_leash = !has_objective || leash <= 0.0 ||
				(double)objective_point.distance_to(row.position) <= leash + weapon_range;
		const double leash_factor = in_leash ? 1.0 : 0.15;
		int64_t fresh_ticks = (f_reload_windows && current_option == k.COVER_FIRE &&
									  current_target == cname) ?
				c.COVER_FIRE_MEMORY_TICKS :
				c.CONTACT_FRESH_TICKS;
		if (fresh_ticks == c.COVER_FIRE_MEMORY_TICKS && f_denied_wait) {
			fresh_ticks = c.COVER_DENIED_MEMORY_TICKS;
		}
		if (current_option == k.ORBIT && current_target == cname) {
			fresh_ticks = c.ORBIT_MEMORY_TICKS;
		}
		if (row.age <= fresh_ticks) {
			double reach = 1.0;
			if (distance > weapon_range) {
				reach = clampd(1.0 - (distance - weapon_range) / 80.0, 0.15, 1.0);
			}
			const double prio = priority_row(c, k, target_priority, row, distance);
			double engage = (0.3 + 0.7 * aggression) * reach * (0.55 + 0.45 * prio) * confidence * leash_factor *
					(row.visible ? 1.0 : 0.75) * firepower;
			double matchup_factor = 1.0;
			if (matchups.has(cname) && best_kill_rate > 0.0) {
				const Dictionary m = matchups[cname];
				matchup_factor = (0.5 + 0.5 * (double)m[k.kill_rate] / best_kill_rate) *
						clampd(std::pow((double)m[k.advantage], 0.25), 0.8, 1.25);
				const bool keep_orbiting = current_option == k.ORBIT && current_target == cname;
				if ((bool)m.get(k.orbit, false) && (row.visible || keep_orbiting) &&
						(double)m[k.advantage] >= (keep_orbiting ? c.ORBIT_KEEP_ADVANTAGE : c.ORBIT_START_ADVANTAGE)) {
					orbits.push_back(ScorePair{ cname, MAX(engage * 1.2, 0.95 * confidence * firepower * leash_factor) });
				}
			}
			engage *= matchup_factor;
			double squad_bonus = 1.0;
			if (cname == t_focus) {
				squad_bonus *= c.FOCUS_BONUS;
			}
			if (cname == t_cover_target) {
				squad_bonus *= c.COVER_TEAMMATE_BONUS;
			}
			if (fragile_threats.has(cname)) {
				squad_bonus *= c.FRAGILE_THREAT_BONUS;
			}
			if (squad_bonus > 1.0) {
				const double boosted = engage * squad_bonus;
				engage = commanded ? MIN(boosted, MAX(engage, c.ORDER_WEIGHT - 0.1)) : boosted;
			}
			engages.push_back(ScorePair{ cname, engage });
			if (suppresses && row.visible && distance <= weapon_range) {
				bool poor_kill = best_kill_rate > 0.0 && matchups.has(cname) &&
						(double)((Dictionary)matchups[cname])[k.kill_rate] <= best_kill_rate * c.SUPPRESS_KILL_RATIO;
				if (!poor_kill && !matchups.has(cname) && f_suppress_proxy) {
					poor_kill = rounds_barely_mark(c, k, profiles, weapon, cc);
				}
				const bool own_flank = cname == t_flank_target;
				const bool flanker_fix = f_pinned_exposed;
				const bool holding_down = current_option == k.SUPPRESS && current_target == cname &&
						row.suppression >= c.PINNED_SUPPRESSION * c.PIN_HOLD_FRACTION;
				const bool keep_pinned = (row.pinned || holding_down) &&
						(!flanker_fix || rounds_barely_mark(c, k, profiles, weapon, cc) || poor_kill);
				const bool is_focus = cname == t_focus;
				const bool worth_pinning = poor_kill || keep_pinned || (own_flank && !flanker_fix) || is_focus;
				if (worth_pinning) {
					double suppress_score = c.SUPPRESS_WEIGHT * reach * confidence * leash_factor * firepower;
					// ElementFeed.is_firing_base(context): str(context.get("role")) in ["overwatch", "base_of_fire"]
					const Variant role_v = element_context.get(k.role, Variant());
					const String role_s = role_v.get_type() == Variant::NIL ? k.empty : (String)role_v.stringify();
					const bool firing_base = role_s == k.overwatch_role || role_s == k.base_of_fire;
					if ((own_flank && !flanker_fix) || firing_base) {
						suppress_score *= 1.25;
					}
					const bool only_poor_kill = !(keep_pinned || own_flank || firing_base || is_focus);
					suppressions.push_back(ScorePair{ cname, suppress_score, only_poor_kill });
				}
			}
			double flank = d_flanking * (row.facing_ally ? 1.0 : 0.55) * confidence * reach *
					leash_factor * firepower * MIN(matchup_factor, 1.0);
			if (row.pinned) {
				flank *= c.PINNED_FLANK_BONUS;
			}
			if (row.exposed_face != k.front) {
				flank *= 0.35;
			} else if (t_flank_target == cname &&
					(!commanded || String(((Dictionary)squad)[k.verb]) == k.assault)) {
				flank = MAX(flank, c.FLANKER_APPETITE * confidence * firepower * leash_factor);
				if (f_pinned_exposed && row.pinned) {
					flank = MAX(flank, c.FLANKER_APPETITE * c.PINNED_FLANK_BONUS * confidence * firepower * leash_factor);
				}
			}
			flanks.push_back(ScorePair{ cname, flank });
		} else {
			const double staleness = clampd((double)row.age / (double)(int64_t)s[k.memory_ticks], 0.0, 1.0);
			investigates.push_back(ScorePair{ cname, (0.25 + 0.4 * aggression) * (1.0 - staleness) * leash_factor });
		}
	}
	const double fight_scale = is_artillery ? 0.0 : (is_scout ? c.SCOUT_FIGHT : 1.0);
	const Variant cover_fire_v = s.get(k.cover_fire, Variant());
	const Dictionary cover_fire = cover_fire_v.get_type() != Variant::NIL ? (Dictionary)s.get(k.cover_fire, Dictionary()) : Dictionary();
	HashMap<String, bool> pinned_targets;
	for (const ContactRow &r : rows) {
		if (r.pinned) {
			pinned_targets.insert(r.name, true);
		}
	}
	const String my_unit = me.get(k.unit, k.empty);
	for (const ScorePair &pair : engages) {
		double score = pair.score * fight_scale;
		bool prey = false;
		if (is_scout) {
			// TankBrain._is_prey_contact(contacts, name, my_unit): the first contact of that name
			for (const ContactRow &r : rows) {
				if (r.name == pair.name) {
					prey = is_prey(c, k, profiles, r.dict, my_unit);
					break;
				}
			}
		}
		if (prey) {
			score = MAX(pair.score * c.SCOUT_HUNT, c.SCOUT_HUNT_FLOOR * confidence);
		}
		candidates.push_back(candidate(k.ENGAGE, pair.name, score));
		if ((bool)features.get(k.cover_fire, true) && !cover_fire.is_empty() && cover_fire[k.target] == pair.name &&
				(int64_t)weapon[k.kind] != c.KIND_ARC) {
			// UtilityCurves.linear(reload, COVER_FIRE_RELOAD_FLOOR, 2.0) and floor_at(score, 0.6)
			const double reload = weapon[k.reload];
			const double slow_reload = Math::is_equal_approx(c.COVER_FIRE_RELOAD_FLOOR, 2.0) ? (reload >= 2.0 ? 1.0 : 0.0) :
					clampd((reload - c.COVER_FIRE_RELOAD_FLOOR) / (2.0 - c.COVER_FIRE_RELOAD_FLOOR), 0.0, 1.0);
			const double spot_quality = lerpd(0.6, 1.0, clampd(num(cover_fire, k.score, 0.5), 0.0, 1.0));
			double cover_value = score * slow_reload * (1.08 + 0.3 * caution) * spot_quality;
			if ((bool)features.get(k.pinned_exposed, false) && pinned_targets.has(pair.name)) {
				cover_value *= c.PINNED_COVER_FIRE;
			}
			candidates.push_back(candidate(k.COVER_FIRE, pair.name, cover_value));
		}
	}
	for (const ScorePair &pair : flanks) {
		candidates.push_back(candidate(k.FLANK, pair.name, pair.score * fight_scale));
	}
	HashMap<String, bool> suppressed;
	for (const ScorePair &pair : suppressions) {
		suppressed.insert(pair.name, true);
	}
	double best_winnable = 0.0;
	for (const ScorePair &pair : engages) {
		if (!suppressed.has(pair.name)) {
			best_winnable = MAX(best_winnable, pair.score * fight_scale);
		}
	}
	for (const ScorePair &pair : suppressions) {
		double suppress = pair.score * fight_scale;
		if (pair.flag && best_winnable > 0.0) {
			suppress = MIN(suppress, best_winnable * c.SUPPRESS_UNDER_WINNABLE);
		}
		candidates.push_back(candidate(k.SUPPRESS, pair.name, suppress));
	}
	for (const ScorePair &pair : orbits) {
		candidates.push_back(candidate(k.ORBIT, pair.name, pair.score));
	}
	// CLEAR_LANE (the flat arm: SwitchingCost.cost_arm() is off in this path)
	if ((bool)features.get(k.hold_for_friends, true) && (int64_t)me.get(k.lane_blocked_ticks, 0) >= c.LANE_BLOCKED_TICKS &&
			current_target != Variant(k.empty)) {
		const double served = (double)features.get(k.commit_bonus, c.COMMIT_BONUS);
		for (const ScorePair &pair : engages) {
			if (pair.name == current[k.target]) {
				candidates.push_back(candidate(k.CLEAR_LANE, pair.name, MAX(pair.score * fight_scale, 0.3) * served * c.CLEAR_LANE_EDGE));
			}
		}
	}
	if (is_artillery) {
		for (const ContactRow &r : rows) {
			if (!r.visible) {
				continue;
			}
			const double reach = my_position.distance_to(r.position);
			if (reach > weapon_range + 40.0) {
				continue;
			}
			const double bombard = (0.6 + 0.3 * priority_row(c, k, target_priority, r, reach)) * confidence * firepower;
			candidates.push_back(candidate(k.BOMBARD, r.name, bombard));
		}
		double trail = 0.0;
		if (!((Array)s[k.allies]).is_empty()) {
			trail = visible_threats == 0 ? 0.55 : 0.3;
		}
		candidates.push_back(candidate(k.SHADOW, k.empty, trail));
	}
	double spot = 0.0;
	if (is_scout) {
		double nearest = INFINITY;
		for (const ContactRow &r : rows) {
			const Dictionary &cc = r.dict;
			const Variant &cname = r.name;
			bool orbitable = false;
			if (matchups.has(cname)) {
				const Dictionary m = matchups[cname];
				orbitable = (bool)m.get(k.orbit, false) && (double)m[k.advantage] >= c.ORBIT_KEEP_ADVANTAGE;
			}
			if (r.visible && !is_prey(c, k, profiles, cc, my_unit) && !orbitable) {
				nearest = MIN(nearest, (double)my_position.distance_to(r.position));
			}
		}
		if (nearest < c.SCOUT_STANDOFF - 10.0) {
			spot = 0.88;
		} else if (nearest < INFINITY) {
			spot = 0.7;
		} else {
			spot = 0.62;
		}
	}
	candidates.push_back(candidate(k.SPOT, k.empty, spot));
	for (const ScorePair &pair : investigates) {
		candidates.push_back(candidate(k.INVESTIGATE, pair.name, pair.score * (is_artillery ? 0.0 : 1.0)));
	}
	double regroup = 0.0;
	const Variant squad_center = s[k.squad_center];
	if (squad_center.get_type() != Variant::NIL && !commanded) {
		const double gap = my_position.distance_to(squad_center);
		regroup = (double)d[k.cohesion] * clampd((gap - 15.0) / 30.0, 0.0, 1.0) * 0.8;
	}
	candidates.push_back(candidate(k.REGROUP, k.empty, regroup));
	double advance = 0.0;
	bool at_objective = false;
	if (objective.get_type() != Variant::NIL) {
		const double to_objective = my_position.distance_to(objective);
		at_objective = to_objective <= (double)s[k.objective_radius];
		if (leash > 0.0 && to_objective > leash) {
			advance = recharge <= 0.0 ? 0.95 : 0.3;
		} else if (!at_objective) {
			advance = visible_threats == 0 ? 0.45 : 0.25;
		}
	} else if (visible_threats == 0 && hp >= retreat_threshold) {
		advance = 0.3;
	}
	if (commanded) {
		advance = 0.0;
	}
	candidates.push_back(candidate(k.ADVANCE, k.empty, advance));
	double contest = 0.0;
	const Variant control_v = s.get(k.control, Variant());
	if (control_v.get_type() != Variant::NIL && !commanded && !is_artillery && hp >= retreat_threshold) {
		const Dictionary control = control_v;
		const bool inside = (double)my_position.distance_to(control[k.center]) <= (double)control[k.radius] * 0.8;
		if ((int64_t)control[k.owner] != (int64_t)me[k.team]) {
			contest = visible_threats == 0 ? 0.72 : 0.5;
		} else if (inside) {
			contest = 0.4;
		} else {
			contest = visible_threats == 0 ? 0.45 : 0.2;
		}
		contest *= is_scout ? 0.8 : 1.0;
	}
	candidates.push_back(candidate(k.CONTEST, k.empty, contest));
	double keep_slot = 0.0;
	bool in_position = false;
	if (commanded) {
		const Dictionary sq = squad;
		const double gap = my_position.distance_to(sq[k.slot]);
		in_position = gap <= c.SLOT_TOLERANCE && !(bool)sq[k.moving];
		const String verb = sq[k.verb];
		if (verb == k.move) {
			keep_slot = in_position ? 0.0 : c.ORDER_WEIGHT;
		} else if (verb == k.bound) {
			const bool to_spot = (bool)sq[k.moving] || (bool)sq.get(k.overwatch, false);
			keep_slot = (to_spot && gap > 3.0) ? c.ORDER_WEIGHT : 0.0;
			in_position = !(bool)sq[k.moving] && (!(bool)sq.get(k.overwatch, false) || gap <= 3.0);
		} else if (verb == k.hold) {
			keep_slot = gap <= c.SLOT_TOLERANCE ? 0.0 : c.ORDER_WEIGHT;
		} else if (verb == k.assault) {
			keep_slot = in_position ? 0.0 : (visible_threats == 0 ? 0.5 : 0.15);
		} else if (verb == k.break_contact) {
			keep_slot = gap <= c.SLOT_TOLERANCE ? 0.0 : 0.97;
		}
	}
	candidates.push_back(candidate(k.KEEP_SLOT, k.empty, keep_slot));
	double hold = 0.1;
	if (at_objective) {
		hold = 0.3 + 0.35 * (1.0 - aggression);
	}
	if (in_position) {
		hold = MAX(hold, 0.72);
	}
	candidates.push_back(candidate(k.HOLD, k.empty, hold));
	const Dictionary cooldowns = s.get(k.cooldowns, Dictionary());
	if (!cooldowns.is_empty()) {
		const int64_t tick = s[k.tick];
		for (int64_t i = 0; i < candidates.size(); i++) {
			Dictionary cand = candidates[i];
			if ((int64_t)cooldowns.get(cand[k.option], -1) > tick) {
				cand[k.score] = (double)cand[k.score] * c.COOLDOWN_FACTOR;
			}
		}
	}
	const Variant order_context = s.get(k.order, Variant());
	if (order_context.get_type() != Variant::NIL) {
		const bool critical = hp < lerpd(c.CRITICAL_HP_MIN, c.CRITICAL_HP_MAX, caution) && visible_threats > 0;
		candidates = obey(c, k, candidates, order_context, s, critical, out_of_ammo);
		keep_slot = 0.0;
	}
	const Dictionary left = s.get(k.left, Dictionary());
	if (!left.is_empty() && (int64_t)s[k.tick] - (int64_t)left[k.tick] < (int64_t)std::llround(c.REVISIT_S * (double)c.TICK_RATE)) {
		for (int64_t i = 0; i < candidates.size(); i++) {
			Dictionary cand = candidates[i];
			if (c.FIGHT_OPTIONS.has(cand[k.option]) && cand[k.option] == left[k.option] && cand[k.target] == left[k.target]) {
				cand[k.score] = (double)cand[k.score] * c.REVISIT_FACTOR;
			}
		}
	}
	const bool order_pending = keep_slot > 0.0 && !(current_option == k.KEEP_SLOT || current_option == k.RETREAT);
	const double flat_bonus = features.get(k.commit_bonus, c.COMMIT_BONUS);
	if (!order_pending && !current.is_empty() && flat_bonus > 0.0) {
		for (int64_t i = 0; i < candidates.size(); i++) {
			Dictionary cand = candidates[i];
			if (cand[k.option] == current[k.option] && cand[k.target] == current[k.target]) {
				cand[k.score] = (double)cand[k.score] * flat_bonus;
			}
		}
	}
	Dictionary best = candidates[0];
	for (int64_t i = 0; i < candidates.size(); i++) {
		const Dictionary cand = candidates[i];
		if ((double)cand[k.score] > (double)best[k.score]) {
			best = cand;
		}
	}
	Dictionary choice;
	choice[k.option] = best[k.option];
	choice[k.target] = best[k.target];
	Dictionary decision;
	decision[k.choice] = choice;
	decision[k.ranked] = top(k, candidates, 3);
	return decision;
}

} // namespace godot
