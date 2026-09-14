class_name GameMode
extends RefCounted
## One way to run the game. Each mode owns its setup, so workstreams can change one mode
## without touching the others (see _agents/workstreams.md):
##   OfflineMode (gameplay)  SkirmishMode (gameplay)  MatchRunnerMode (gameplay/experiments)
##   ServerMode (netcode)    ClientMode (netcode)    HostMode (netcode: a player hosts via the relay)

var main: Main
var flags: LaunchFlags


## Which mode the flags ask for. Order matters: det-spike > match > skirmish > lobby > host > server > client > offline.
static func choose(p_flags: LaunchFlags) -> GameMode:
	if p_flags.has("det-spike"):
		return DetSpikeMode.new()
	if p_flags.has("match"):
		return MatchRunnerMode.new()
	if p_flags.has("skirmish"):
		return SkirmishMode.new()
	if p_flags.has("lobby"):
		return LobbyMode.new()
	if p_flags.has("host"):
		return HostMode.new()
	if p_flags.has("server") or (OS.has_feature("server") and not p_flags.has("connect")):
		return ServerMode.new()
	if p_flags.has("connect") or p_flags.has("join") or p_flags.has("replay"):
		return ClientMode.new()
	return OfflineMode.new()


## Printed in TANK_SQUAD_READY (smoke tests read it).
func role_name() -> String:
	return "OFFLINE"


## Headless processes normally cap their frame rate; the match runner wants to spin.
func caps_headless_fps() -> bool:
	return true


func start() -> void:
	pass
