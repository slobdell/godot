class_name TaskPalette
extends RefCounted
## Round 6 X2 (contract N4): the command card's vocabulary, one row per button. The lead: *"I don't know what some of
## these buttons are (i.e. screen) ... there's a standard military symbol for support by fire, we should ideally use
## these"*. So every task button shows its **tactical task graphic** (after APP-6 / MIL-STD-2525 / FM 1-02.2, drawn by
## CommandIcons.draw_task), its **doctrinal name** ("Support by Fire", never "Base of fire"), its hotkey, and a
## one-sentence tooltip saying what the units will do.
##
## Rules the table keeps:
##   - A verb the mouse already expresses gets **no button** (move = right-click ground, follow = right-click a friend,
##     attack = right-click an enemy). Their keys may stay.
##   - A task only gets a button once squad has **demonstrated** its behaviour (`earned`). Unearned rows are drawn and
##     documented so the symbol is ready, and stay off the card. _agents/tactical_map.md "Task palette (N4)" is the
##     same table in words, and says which rows squad has earned.
##
## Row keys: id (what the card presses: an RtsControls verb or "formation") · name · hotkey · kind ("order" = a direct
## K1 order any selection can take, "task" = an L1 element task, "setting") · line (the tooltip, one sentence, what
## the player will see happen) · earned.

const ROWS := [
	{"id": "stop", "name": "Stop", "hotkey": "S", "kind": "order", "earned": true,
		"line": "Drop every order and stand still. They still shoot back."},
	{"id": "hold", "name": "Hold", "hotkey": "H", "kind": "order", "earned": true,
		"line": "Stay on this ground and fight from it. Nobody chases."},
	{"id": "attack_move", "name": "Attack-move", "hotkey": "A", "kind": "order", "earned": true,
		"line": "Click a spot: go there, fighting anything met on the way."},
	# Screen and Support by Fire were held off the card until squad showed the behaviour (with no enemy in sight a
	# support-by-fire task used to hold every unit where it stood). Earned 2026-09-18, squad `df736a8e`: SBF → a 30 m
	# line 54-56 m off the point, all facing it, firing, no contact drill selected; screen → a 42 m line across its point.
	# Posture tests: tests/test_tactics_tasks.gd, test_tactics_scenarios.gd (squad's, in make check).
	{"id": "screen", "name": "Screen", "hotkey": "E", "kind": "task", "earned": true,
		"line": "Click a spot: spread into a line across it, watch, and fight only what comes to you."},
	{"id": "support_by_fire", "name": "Support by Fire", "hotkey": "R", "kind": "task", "earned": true,
		"line": "Click a target area: take firing positions facing it, suppress it, and don't advance."},
	# squad's verb: a line facing the kill zone, holding fire until an enemy is in it (or they are found). Earned
	# 2026-09-18, squad 9ba36681 (on main 0f559857): TacticsScenarios.ambush in make check - 0 shots before the enemy
	# entered the kill zone, sprung ~1 s after, 8 after.
	{"id": "ambush", "name": "Ambush", "hotkey": "B", "kind": "task", "earned": true,
		"line": "Click a kill zone: hide in a line facing it and hold fire until the enemy is in it, or they are found."},
	{"id": "attack_by_fire", "name": "Attack by Fire", "hotkey": "", "kind": "task", "earned": false,
		"line": "Click a target: destroy it with fire from a distance, without closing."},
	{"id": "guard", "name": "Guard", "hotkey": "", "kind": "task", "earned": false,
		"line": "Click a flank: protect the army there, fighting to stop anything getting through."},
	{"id": "cover", "name": "Cover", "hotkey": "", "kind": "task", "earned": false,
		"line": "Click a spot ahead: operate out in front of the army, buying it time and space."},
	{"id": "fix", "name": "Fix", "hotkey": "", "kind": "task", "earned": false,
		"line": "Click an enemy: pin it where it is so the rest of the army can hit it."},
	{"id": "block", "name": "Block", "hotkey": "", "kind": "task", "earned": false,
		"line": "Click a route: deny the enemy passage along it."},
	{"id": "formation", "name": "Formation", "hotkey": "G", "kind": "setting", "earned": true,
		"line": "Choose the shape the next orders move in. Auto lets each squad pick."},
]
## Verbs the mouse already gives, which the card must never show (X1).
const MOUSE_VERBS := ["move", "follow", "attack"]


## The rows on the card, in order: earned, and not a mouse verb.
static func card() -> Array:
	return ROWS.filter(func(row: Dictionary) -> bool:
		return bool(row["earned"]) and not MOUSE_VERBS.has(String(row["id"])))


static func row(id: String) -> Dictionary:
	for entry: Dictionary in ROWS:
		if String(entry["id"]) == id:
			return entry
	return {}


## Buttons that only a whole element (a leader) can carry out.
static func element_only() -> Array:
	return ROWS.filter(func(entry: Dictionary) -> bool: return String(entry["kind"]) == "task") \
			.map(func(entry: Dictionary) -> String: return String(entry["id"]))
