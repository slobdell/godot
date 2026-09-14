class_name LaunchFlags
extends RefCounted
## Launch options: command line after a bare `--` (desktop, server), or the URL query
## string in the browser (index.html?skirmish&enemy=anvil_hammer). See game/main.gd for the list.

var values := {}


static func from_environment() -> LaunchFlags:
	var raw := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&", false):
			raw.append("--" + part.uri_decode())
	return LaunchFlags.parse(raw)


## ["--demo", "--server=9090"] -> {"demo": "", "server": "9090"}
static func parse(raw: PackedStringArray) -> LaunchFlags:
	var flags := LaunchFlags.new()
	for flag in raw:
		var parts := flag.trim_prefix("--").split("=", true, 1)
		flags.values[parts[0]] = parts[1] if parts.size() > 1 else ""
	return flags


func has(flag_name: String) -> bool:
	return values.has(flag_name)


func text(flag_name: String, default_value := "") -> String:
	return String(values.get(flag_name, default_value))


func integer(flag_name: String, default_value: int) -> int:
	var value := text(flag_name)
	return value.to_int() if value.is_valid_int() else default_value
