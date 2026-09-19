class_name AudioDefaults
extends RefCounted
## Feel (round 6): what the booth and the music do when the launch doesn't say. The lead: "the audio is defaulted to
## off". Only `make skirmish` and `make audio-pass` passed `--announcer=voice --music=on`; the title's SKIRMISH, the
## garage's FIGHT and a bare launch of the game carried nothing, and both systems read a missing flag as "off", so the
## player's own way into the game had no announcer, no music and no match mood for the crowd to follow.
## A player-facing launch now sounds by default; a headless one (tests, servers, the match runner) stays silent, and
## `--announcer=off` / `--music=off` / `--mute` still turn it off, and the title's backdrop fight stays unannounced.

const ON := {"announcer": "voice", "music": "on"}


## The value of `name` ("announcer" or "music") for this launch: the flag when given, else on for a game with a
## window and off headless. Pure (headless passed in), for tests.
static func value(flags: LaunchFlags, name: String, headless: bool = DisplayServer.get_name() == "headless") -> String:
	if flags.has(name):
		return flags.text(name)
	# The title's live backdrop is a match too, but nobody is watching it: no booth calling it over the menu.
	if headless or flags.has("mute") or flags.has("title"):
		return "off"
	return String(ON[name])
