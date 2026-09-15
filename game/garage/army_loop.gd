class_name ArmyLoop
extends Node
## Y3, the match loop: army → skirmish → results → rematch or back to the army builder.
##
## GarageMode adds one under Main when FIGHT starts the skirmish. It records the fight (MatchReport); when
## the match ends it waits for the VICTORY/DEFEAT banner, pays credits (Progression.award), and shows the
## ResultsScreen. REMATCH and ARMY restart the game in-process with new launch flags (Main.next_flags +
## reload), so nothing from the finished match survives and it works the same in the browser.
##
## Flags (automated runs and screenshots):
##   --army-loop-time=S       end the skirmish after S simulated seconds (skips the planning pause)
##   --army-loop-auto=A,B,…   tap these in order on each results screen: rematch | army; "quit" quits when reached
##   --army-loop-delay=S      seconds between the match ending and the results screen (default RESULTS_DELAY)
## Prints ARMY_RESULTS outcome=<win|loss|draw> credits=<earned> balance=<n> tier=<n> enemy=<units> and
## ARMY_LOOP action=<rematch|army>.

const RESULTS_DELAY := 3.0
## Flags that describe how the builder was opened, carried into every restart.
const CARRIED_FLAGS := ["garage-scratch", "garage-settings", "profile", "mute", "no-shake", "fx-quality", "perf", "theme"]

var main: Main
var progression: Progression
## The army builder's catalog at the fight's tier (names and matchups for the results screen).
var catalog: ArmyCatalog
var army: Dictionary
var army_path := ""
var enemy := ""
var seed_value := 0
var tier := 0
var budget := 0
## A Challenges id when this fight is a challenge mission (pays its one-time reward instead of match credits).
var challenge := ""

var report: MatchReport
var results: ResultsScreen
var last_report: Dictionary
var last_paid: Dictionary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Start watching the match that just began.
func begin() -> void:
	report = MatchReport.new()
	report.name = "MatchReport"
	add_child(report)
	report.watch(main.game_match)
	report.unit_names = MatchReport.names_for(Match.TEAM_NAMES[Match.Team.GREEN], army)
	main.game_match.finished.connect(_on_finished)
	if main.flags.has("army-loop-time"):
		main.game_match.start_limits(0, float(main.flags.text("army-loop-time")))
		# Round 3: the node is TacticalMap (--touch-map) or RtsControls (default); both pause the same way.
		var tactical := main.hud.get_node_or_null("TacticalMap")
		if tactical != null and tactical.has_method("set_paused"):
			tactical.call("set_paused", false, "")


func _on_finished(result: Dictionary) -> void:
	last_report = report.build(result, budget, tier)
	if challenge != "":
		last_paid = challenge_pay(last_report, challenge, progression)
	else:
		last_paid = Progression.credits_for(last_report, Match.TEAM_NAMES[Match.Team.GREEN], tier)
		progression.award(last_report, Match.TEAM_NAMES[Match.Team.GREEN], tier)
	print("ARMY_RESULTS outcome=%s credits=%d balance=%d tier=%d enemy=%s" % [last_paid["outcome"], last_paid["credits"],
			progression.credits, tier, JSON.stringify(last_report["teams"]["rust"]["units"])])
	await get_tree().create_timer(float(main.flags.text("army-loop-delay", str(RESULTS_DELAY))), true).timeout
	show_results()


func show_results() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Results"
	layer.layer = 20
	results = ResultsScreen.new()
	results.name = "ResultsScreen"
	results.setup(last_report, last_paid, progression, catalog, enemy_label())
	if challenge != "":
		results.lesson = String(Challenges.info(challenge)["lesson"])
	layer.add_child(results)
	add_child(layer)
	results.rematch_requested.connect(rematch)
	results.army_requested.connect(back_to_army)
	var auto := main.flags.text("army-loop-auto").split(",", false)
	if not auto.is_empty():
		match auto[0]:
			"rematch":
				rematch.call_deferred()
			"army":
				back_to_army.call_deferred()
			"quit":
				get_tree().quit()


## A challenge's pay: its one-time reward on the first win, nothing on a replay or a loss (completes it on a win).
static func challenge_pay(p_report: Dictionary, challenge_id: String, p_progression: Progression) -> Dictionary:
	var winner := String(p_report.get("winner", "draw"))
	var outcome := "draw" if winner == "draw" else ("win" if winner == Match.TEAM_NAMES[Match.Team.GREEN] else "loss")
	var title := String(Challenges.info(challenge_id).get("title", challenge_id))
	if outcome != "win":
		return {"credits": 0, "outcome": outcome, "lines": [["%s not cleared yet: try again" % title, 0]]}
	var paid := p_progression.complete_challenge(challenge_id, Challenges.REWARD)
	return {"credits": paid, "outcome": outcome, "lines": [["%s cleared%s" % [title, "" if paid > 0 else " again (rewards pay once)"], paid]]}


func enemy_label() -> String:
	if challenge != "":
		return "Challenge: %s" % Challenges.info(challenge).get("title", challenge)
	var label := "CPU: %s" % enemy.trim_prefix("cpu:").capitalize() if enemy.begins_with("cpu:") else ("CPU: Random" if enemy == "cpu" else enemy)
	return "%s (seed %d)" % [label, seed_value]


## The same armies again: the saved army against the same seeded opponent at the same tier.
func rematch() -> void:
	print("ARMY_LOOP action=rematch")
	if challenge != "":
		restart({"garage": "", "challenge": challenge, "tier": str(tier)})
		return
	restart({"garage": "", "garage-rematch": "", "garage-army": army_path, "enemy": enemy, "seed": str(seed_value), "tier": str(tier)})


func back_to_army() -> void:
	print("ARMY_LOOP action=army")
	var values := {"garage": "", "enemy": enemy, "tier": str(tier)}
	if army_path != "":
		values["garage-army"] = army_path
	restart(values)


## Restart the game with `values` plus the carried flags (and what's left of --army-loop-auto).
func restart(values: Dictionary) -> void:
	Main.next_flags = ArmyLoop.restart_flags(main.flags, values)
	get_tree().paused = false
	get_tree().reload_current_scene()


## The flags a restart runs with: `values`, --garage-keep, the CARRIED_FLAGS and loop timing from `current`,
## and --army-loop-auto minus the step just taken.
static func restart_flags(current: LaunchFlags, values: Dictionary) -> LaunchFlags:
	var flags := LaunchFlags.new()
	flags.values = values.duplicate()
	flags.values["garage-keep"] = ""
	for key: String in CARRIED_FLAGS + ["army-loop-time", "army-loop-delay"]:
		if current.has(key):
			flags.values[key] = current.values[key]
	var auto := current.text("army-loop-auto").split(",", false)
	if auto.size() > 1:
		flags.values["army-loop-auto"] = ",".join(auto.slice(1))
	return flags
