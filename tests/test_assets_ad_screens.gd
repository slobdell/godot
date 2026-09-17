extends TestCase
## Assets X2: giant ad screens. One broadcast channel renders the ad (image or flipbook, slow pan and zoom, text
## overlaid by the engine) into a small viewport that every screen on the channel shows through one shared material;
## glitches between ads; each ad's average color tints the light the screens throw on the ground.

const SCREEN := preload("res://game/theme/arena_kit/prop_ad_screen.tscn")


func test_the_placeholder_playlist_is_complete_and_text_free() -> void:
	var ads := AdBroadcast.load_playlist()
	assert_true(ads.size() >= 5, "a playlist of at least five ads (%d)" % ads.size())
	var live := 0
	for ad: Dictionary in ads:
		assert_true(ResourceLoader.exists(ad["image"]), "%s has its image" % ad["id"])
		assert_true(String(ad["headline"]) != "" and String(ad["brand"]) != "", "%s has copy to overlay (text is never baked in)" % ad["id"])
		assert_true(Color.html_is_valid(ad["average_color"]), "%s knows the color of its light" % ad["id"])
		assert_true(float(ad["seconds"]) >= 4.0, "%s stays up long enough to read" % ad["id"])
		live += int(ad["kind"] == "live")
	assert_eq(live, 1, "one card carries live match content")


func test_a_channel_cycles_ads_with_a_glitch_between_them() -> void:
	var channel: AdBroadcast = add_to_tree(AdBroadcast.new())
	var first := channel.current_id()
	var seconds := float(channel.current()["seconds"])
	var peak := 0.0
	var t := 0.0
	while t < seconds + 1.0:
		channel.advance(0.05)
		peak = maxf(peak, channel.glitch)
		t += 0.05
	assert_true(channel.current_id() != first, "the next ad is up after %s s" % seconds)
	assert_true(peak > 0.8, "the switch hides behind a glitch (peak %.2f)" % peak)
	for i in 40:
		channel.advance(0.05)
	assert_near(channel.glitch, 0.0, 0.01, "the picture settles after the transition")
	var target := Color(channel.current()["average_color"])
	var light := channel.light_color()
	assert_true(Vector3(light.r - target.r, light.g - target.g, light.b - target.b).length() < 0.05,
			"the light spill takes the new ad's color")


func test_the_live_card_shows_what_the_match_posts() -> void:
	var channel: AdBroadcast = add_to_tree(AdBroadcast.new())
	channel.post_live({"headline": "RUST\n3 : 1", "fine_print": "GREEN lost a dozer"})
	channel.show_ad(channel.index_of("arena_live"))
	assert_eq(channel.headline_text(), "RUST\n3 : 1", "live content replaces the card's placeholder headline")
	assert_eq(channel.fine_print_text(), "GREEN lost a dozer", "and its fine print")
	channel.show_ad(channel.index_of("aquacorp"))
	assert_true(channel.headline_text().begins_with("CLEAN WATER"), "sponsor ads keep their own copy")


func test_screens_on_a_channel_share_one_feed_and_one_material() -> void:
	var a := _screen(Vector3(0, 0, 0), {})
	var b := _screen(Vector3(20, 0, 0), {})
	var c := _screen(Vector3(40, 0, 0), {"channel": "odds"})
	var panel_a := a.get_node("Panel") as MeshInstance3D
	var panel_b := b.get_node("Panel") as MeshInstance3D
	var panel_c := c.get_node("Panel") as MeshInstance3D
	assert_true(panel_a.material_override != null and panel_a.material_override == panel_b.material_override,
			"screens on the same channel draw with one shared material")
	assert_true(panel_c.material_override != panel_a.material_override, "another channel has its own feed")
	var feed: Texture2D = (panel_a.material_override as ShaderMaterial).get_shader_parameter("feed")
	assert_true(feed is ViewportTexture, "the panel shows the channel's rendered viewport")
	assert_true(AdBroadcast.channel(a, "odds") != AdBroadcast.channel(a, "arena"), "channels are found by name")


func test_the_spill_follows_the_channel_light() -> void:
	var screen := _screen(Vector3(0, 0, 60), {})
	var channel := AdBroadcast.channel(screen, "arena")
	channel.show_ad(channel.index_of("vireo"))
	for i in 60:
		channel.advance(0.05)
	var spill := (screen.get_node("Spill") as MeshInstance3D).material_override as ShaderMaterial
	var color: Color = spill.get_shader_parameter("color")
	var target := Color(channel.current()["average_color"])
	assert_true(absf(color.r - target.r) < 0.08 and absf(color.g - target.g) < 0.08, "the ground glows the color of the ad on screen")


func test_both_themes_fill_the_screen_slot() -> void:
	var previous := GameTheme.theme_name
	for theme in ["default", "cyberpunk"]:
		GameTheme.use(theme)
		var packed := GameTheme.scene("prop.ad_screen")
		var prop := packed.instantiate() if packed != null else null
		assert_true(prop != null and prop.has_method("setup"), "%s fills prop.ad_screen" % theme)
		if prop != null:
			prop.free()
	GameTheme.use(previous)


func _screen(position: Vector3, obstacle: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.position = position
	add_to_tree(holder)
	var screen := SCREEN.instantiate() as Node3D
	if not obstacle.is_empty():
		screen.call("setup", obstacle)
	holder.add_child(screen)
	return screen


func test_the_arena_venue_raises_screens_over_the_short_walls() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var dressing: Node3D = add_to_tree((load(GameTheme.CYBERPUNK_SLOTS["arena.dressing"]) as PackedScene).instantiate())
	GameTheme.use(previous)
	var structures: Node3D = dressing.get("structures")
	var screens := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("AdScreen"))
	assert_eq(screens.size(), 4, "a screen either side of each gate")
	var channels := {}
	for node: Node3D in screens:
		assert_true(absf(node.position.x) > 121.0, "screens stand outside the walls (x %.1f)" % node.position.x)
		var facing := -node.global_basis.z
		assert_true(facing.dot(-node.global_position.normalized()) > 0.5, "each screen faces into the arena")
		channels[node.get("channel_name")] = true
	assert_eq(channels.size(), 2, "two channels, so neighboring screens don't mirror each other")
	dressing.call("setup", {"name": "small", "half_size": 80.0, "obstacles": []})
	structures = dressing.get("structures")
	for node in structures.get_children():
		if node.name.begins_with("AdScreen"):
			assert_true(absf((node as Node3D).position.x) > 81.0 and absf((node as Node3D).position.x) < 95.0,
					"screens move in with a smaller arena's walls")


func test_the_live_card_follows_kills_in_a_match() -> void:
	var channel: AdBroadcast = add_to_tree(AdBroadcast.new())
	var fake := FakeMatch.new()
	add_to_tree(fake)
	channel.watch_match(fake)
	var rust_scout := RustScout.new()
	add_to_tree(rust_scout)
	fake.tank_destroyed.emit(rust_scout, "Green_Alpha_0")
	fake.tank_destroyed.emit(rust_scout, "Green_Alpha_1")
	channel.show_ad(channel.index_of("arena_live"))
	assert_eq(channel.headline_text(), "GREEN  2\nRUST  0", "the card counts confirmed kills per team")
	assert_true(channel.fine_print_text().begins_with("Rust lost a scout"), "and says who just lost what (%s)" % channel.fine_print_text())
	assert_true(channel.fine_print_text().contains("GREEN 3:1"), "and the odds that follow (%s)" % channel.fine_print_text())


class FakeMatch extends Node:
	signal tank_destroyed(victim: Node, killer: String)


class RustScout extends Node:
	var team := 1
	var unit_id := "scout"


func test_neon_signs_crown_the_stands_in_one_draw() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var dressing: Node3D = add_to_tree((load(GameTheme.CYBERPUNK_SLOTS["arena.dressing"]) as PackedScene).instantiate())
	GameTheme.use(previous)
	var structures: Node3D = dressing.get("structures")
	var signs := structures.find_children("NeonSigns", "MultiMeshInstance3D", true, false)
	assert_eq(signs.size(), 1, "every neon sign in the venue is one MultiMesh")
	if signs.is_empty():
		return
	var multimesh := (signs[0] as MultiMeshInstance3D).multimesh
	var placements: Array = signs[0].get_meta("placements")
	assert_eq(multimesh.instance_count, placements.size(), "one instance per sign")
	assert_true(placements.size() >= 6, "signs along both grandstands (%d)" % placements.size())
	var cells := {}
	for placement: Dictionary in placements:
		cells[int(placement["cell"]) % NeonSigns.CELLS] = true
		var at: Vector3 = (placement["transform"] as Transform3D).origin
		assert_true(absf(at.z) > 121.0 and at.y > 8.0, "signs sit high on the stands, outside the walls (%s)" % at)
		var tint: Color = placement["color"]
		for team: Color in GameTheme.CYBERPUNK_TEAM_COLORS:
			assert_true(Vector3(tint.r - team.r, tint.g - team.g, tint.b - team.b).length() > 0.3, "sign neon never looks like a team color")
	assert_true(cells.size() >= 3, "a mix of signs, not one brand repeated (%d)" % cells.size())


func test_the_gates_are_barricaded_with_tagged_containers() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var dressing: Node3D = add_to_tree((load(GameTheme.CYBERPUNK_SLOTS["arena.dressing"]) as PackedScene).instantiate())
	GameTheme.use(previous)
	var structures: Node3D = dressing.get("structures")
	var barricades := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Barricade"))
	assert_eq(barricades.size(), 4, "container barricades either side of both gates")
	for node: Node3D in barricades:
		assert_true(absf(node.position.x) > 121.0, "barricades stay outside the walls, out of the fight (x %.1f)" % node.position.x)
		assert_eq(String(node.get("options").get("faction", "")), "gangs", "and wear the road gangs' tags and rust")


func test_the_playlist_is_the_leads_approved_copy() -> void:
	# The lead approved the twelve screen ads in assets/announcer/drafts/ad_copy.md as written (round 5): a headline of at
	# most four words over a small line, readable across the arena. Plus the live card between matches.
	var ads := AdBroadcast.load_playlist()
	var stills := ads.filter(func(ad: Dictionary) -> bool: return ad.get("kind", "still") != "live")
	assert_eq(stills.size(), 12, "twelve approved ads")
	var headlines := {}
	for ad: Dictionary in stills:
		var words := String(ad["headline"]).replace("\n", " ").split(" ", false)
		# The copy's rule is four words; the lead approved one five-word line as written ("THEY'LL BE TAKEN CARE OF").
		assert_true(words.size() <= 5, "%s: a headline short enough to read across the arena (%s)" % [ad["id"], ad["headline"]])
		assert_true(ResourceLoader.exists(String(ad["image"])), "%s has its art" % ad["id"])
		headlines[String(ad["headline"]).replace("\n", " ")] = true
	assert_true(headlines.has("CLEAN WATER. EVERY WEEK."), "AquaCorp's approved headline, not the placeholder")
	assert_true(headlines.has("ORDER IS A PUBLIC GOOD"), "The Law's")
	assert_eq(ads.filter(func(ad: Dictionary) -> bool: return ad.get("kind", "") == "live").size(), 1, "and the live card")

