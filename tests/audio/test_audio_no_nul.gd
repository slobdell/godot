extends TestCase
## Round 17: a NUL in a GDScript string literal ("\u0000", weapon_fx.gd's old "no sound of its own" sentinel) makes
## the engine print "Unicode parsing error ... Unexpected NUL character" every time the script is parsed: six times
## on every launch, in every log. The engine's message cannot be caught from a test, so the source is checked: no
## script the audio stream owns or touches carries a NUL escape or a NUL byte. (Headless boot: 6 before, 0 after.)

const DIRS := ["res://game/theme/audio", "res://game/audio", "res://game/theme/fx"]


func _scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found


func test_no_script_carries_a_nul() -> void:
	var checked := 0
	for dir in DIRS:
		for path in _scripts(dir):
			var bytes := FileAccess.get_file_as_bytes(path)
			var text := bytes.get_string_from_utf8()
			assert_true(not text.contains("\\u0000") and not text.contains("\\x00"), "%s has no NUL escape" % path)
			assert_true(bytes.find(0) == -1, "%s has no NUL byte" % path)
			checked += 1
	assert_true(checked > 20, "the scripts were found (%d)" % checked)


func test_a_weapon_with_its_own_hit_sound_is_known_without_a_sentinel() -> void:
	assert_true(SfxWeapons.has_sound("sonic_emitter", "hit"), "the sonic emitter names its own hit")
	assert_eq(SfxWeapons.sound_for("sonic_emitter", "hit", "fallback"), "", "and it is silence")
	assert_true(not SfxWeapons.has_sound("cannon", "hit"), "a cannon takes the surface's sound")
