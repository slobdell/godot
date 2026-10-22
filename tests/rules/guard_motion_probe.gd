extends "res://tests/ai_scenarios/guard_line.gd"
## Round 37 (rules, the orchestrator's close-of-round question): in the guard lines, how much is each SIDE moving when it
## fires? The blob is ordered to drive; the CPU "defender" (tactics) fights at its own doctrine. If it fires on the move as
## often as the blob does, a motion tax (R1, R2) cannot favour it. The guard fight exactly as guard_line.gd plays it, plus a
## read-only listener on Match.weapon_fired: each direct-fire round tagged by its shooter's side and `moving`
## (|speed| / max_forward_speed, what Match._fire feeds shot_spread) as still < 0.15 (a crawl) <= slow < 0.5 <= fast.
##   godot ... --script res://tests/rules/guard_motion_probe.gd -- <guard_line.gd's flags>
## Prints GUARD_RESULT (unchanged) then GUARD_MOTION {"guard": .., "arena": .., "seed": .., "side": .., "shots": {"guard":
## {still, slow, fast}, "tactics": {..}}, "arc": {"guard": n, "tactics": n}}.

const SLOW := 0.15
const FAST := 0.5

var _motion := {"guard": {"still": 0, "slow": 0, "fast": 0}, "tactics": {"still": 0, "slow": 0, "fast": 0}}
var _arc := {"guard": 0, "tactics": 0}
var _listening := false


func _initialize() -> void:
	super._initialize()
	_listen.call_deferred()


## guard_line's _run instantiates main on its first deferred call; wait for its match, then listen.
func _listen() -> void:
	var guard_team := 1 if _flag("guard-side", "green") == "rust" else 0
	for frame in 600:
		await process_frame
		var main := root.get_node_or_null("Main")
		if main == null:
			for child in root.get_children():
				if child.get("game_match") != null:
					main = child
					break
		var game_match: Match = main.get("game_match") if main != null else null
		if game_match == null:
			continue
		game_match.weapon_fired.connect(func(event: Dictionary) -> void:
			var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
			if shooter == null:
				return
			var who := "guard" if shooter.team == guard_team else "tactics"
			if shooter.weapon["kind"] == Weapons.Kind.ARC:
				_arc[who] += 1
				return
			var moving := clampf(absf(shooter.speed()) / shooter.max_forward_speed, 0.0, 1.0)
			_motion[who]["still" if moving < SLOW else ("slow" if moving < FAST else "fast")] += 1)
		_listening = true
		return


func _report(game_match: Match, guard: String, side: int, result: Dictionary, capped: bool) -> void:
	var first := not _printed
	super._report(game_match, guard, side, result, capped)
	if not first:
		return
	print("GUARD_MOTION " + JSON.stringify({"guard": guard, "arena": String(Arena.active.get("name", "")),
			"seed": int(_flag("seed", "0")), "side": _flag("guard-side", "green"), "listening": _listening,
			"rules": RuleSwitches.describe(), "shots": _motion, "arc": _arc}))
