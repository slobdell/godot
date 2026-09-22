extends TestCase
## S6 round 10, item 2: every window on a city block addressable one at a time (`_agents/lighting.md` section 4c).
## The falsifier from the brief: two windows on one block can differ by the channel's full range, and nothing is
## added to what the renderer draws -- no node, no surface, no light, no instance uniform.

const BLOCK_SHADER := "res://game/theme/fx/shaders/city_block.gdshader"
const SIZE := Vector3(40.0, 24.0, 40.0)


func _block_with_grid(grid: ShowWindowGrid, at := Vector3.ZERO, yaw_deg := 0.0, seed := 11) -> CityBlock:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw_deg)
	add_to_tree(holder)
	var block := CityBlock.new()
	holder.add_child(block)
	block.attach_windows(grid)
	block.setup({"tiers": 3, "seed": seed, "neon": "cyan"})
	return block


func test_a_block_has_windows_on_all_four_facades_above_the_shopfronts() -> void:
	var list := CityBlock.windows_of(SIZE, 3, 3.0, 3.6, Transform3D.IDENTITY)
	assert_true(list.size() > 100, "a 40 x 24 x 40 block has a real window grid (%d)" % list.size())
	var facades := {}
	for w: Dictionary in list:
		facades[w["facade"]] = true
		assert_true(w["centre"].y > CityBlock.SHOP_HEIGHT, "no window in the shopfront storey (y %.2f)" % w["centre"].y)
	assert_eq(facades.size(), 4, "every facade carries windows")


func test_every_window_on_a_block_has_its_own_texel() -> void:
	var grid := ShowWindowGrid.new()
	var a := _block_with_grid(grid, Vector3(40, 0, 0), 0.0, 11)
	var b := _block_with_grid(grid, Vector3(-40, 0, 0), 180.0, 11)
	assert_eq([a.block_index, b.block_index], [0, 1], "two blocks, two indices")
	var seen := {}
	for w: Dictionary in grid.windows:
		assert_true(not (seen.has(w["texel"])), "texel %s is claimed twice" % w["texel"])
		seen[w["texel"]] = true
	assert_eq(a.window_count() + b.window_count(), grid.window_count(), "the blocks account for every window")


func test_a_window_is_where_the_shader_looks_for_it() -> void:
	# The shader's arithmetic, re-done from the window's centre: storey = floor(y / 3.6), column = floor(along / bay)
	# with along = world z on a facade facing x and world x on a facade facing z. The centre must land inside the pane.
	var grid := ShowWindowGrid.new()
	var block := _block_with_grid(grid, Vector3(30, 0, -62), 180.0, 41)
	for w: Dictionary in grid.windows:
		var c: Vector3 = w["centre"]
		var along := c.z if int(w["facade"]) <= 1 else c.x
		var cell := Vector2(along / block.bay_m, c.y / ShowWindowGrid.FLOOR_M)
		assert_eq(Vector2i(floori(cell.x), floori(cell.y)), Vector2i(w["column"], w["row"]), "window %s" % w)
		var inside := cell - cell.floor()
		assert_true(inside.x > ShowWindowGrid.PANE_X.x and inside.x < ShowWindowGrid.PANE_X.y
				and inside.y > ShowWindowGrid.PANE_Y.x and inside.y < ShowWindowGrid.PANE_Y.y,
				"the centre is on the glass, not the pilaster (%s)" % inside)
		assert_eq(w["texel"], ShowWindowGrid.texel_of(block.block_index, w["facade"], w["row"], w["column"]),
				"the texel is the one the shader fetches")


func test_the_mesh_tells_the_shader_the_block_index_and_bay_exactly() -> void:
	var mesh := CityBlock.build(SIZE, 3, 3.0, Color.CYAN, 0.375, 5, 200)
	var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_true(colours.size() > 0, "the facade has vertex colours")
	assert_eq(int(round(colours[0].b * 255.0)), 5, "COLOR.b is the block index")
	assert_eq(int(round(colours[0].a * 255.0)), 200, "COLOR.a is the bay code")
	assert_near(CityBlock.bay_of(200), 3.0 + 1.5 * 200.0 / 255.0, 1e-6, "bay_of is the shader's formula")
	var src := FileAccess.get_file_as_string(BLOCK_SHADER)
	assert_true(src.contains("float bay_m = 3.0 + 1.5 * bay_code;"), "the shader reads the bay the CPU chose")
	assert_true(src.contains("const int SHOW_COLS = %d;" % ShowWindowGrid.COLS), "shader and grid agree on COLS")
	assert_true(src.contains("const int SHOW_ROWS = %d;" % ShowWindowGrid.ROWS), "shader and grid agree on ROWS")
	assert_true(src.contains("texelFetch(show_window_map, texel, 0)"), "the shader samples the window map")


func test_two_windows_on_one_block_differ_by_the_full_range_and_nothing_is_added_to_draw() -> void:
	var grid := ShowWindowGrid.new()
	var block := _block_with_grid(grid)
	var nodes_before := block.find_children("*", "", true, false).size()
	var surfaces_before := block.mesh_instance.mesh.get_surface_count()
	assert_true(block.window_count() > 2, "the block has windows")
	assert_true(block.set_window(0, 1.0), "window 0 set")
	assert_true(block.set_window(1, 0.0), "window 1 set")
	assert_eq(grid.get_window(grid.index_of(block.block_index, 0)), 1.0, "window 0 is at the top of the range")
	assert_eq(grid.get_window(grid.index_of(block.block_index, 1)), 0.0, "window 1 at the bottom, on the same block")
	assert_true(grid.flush(), "one upload")
	assert_true(not (grid.flush()), "and none on a frame where nothing changed")
	assert_eq(grid.uploads, 1, "exactly one texture update for any number of window writes in a frame")
	assert_eq(block.find_children("*", "", true, false).size(), nodes_before, "no node added")
	assert_eq(block.mesh_instance.mesh.get_surface_count(), surfaces_before, "no surface (draw call) added")
	assert_eq(block.find_children("*", "Light3D", true, false).size(), 0, "no light")
	assert_true(not FileAccess.get_file_as_string(BLOCK_SHADER).contains("instance uniform"),
			"no instance uniform (render X2: they cap the renderer)")
	assert_true(not (block.set_window(block.window_count(), 1.0)), "an index past the block's windows is refused")


func test_the_live_flag_follows_whether_any_window_is_lit() -> void:
	var grid := ShowWindowGrid.new()
	var block := _block_with_grid(grid)
	assert_true(not (grid.live), "nothing lit")
	block.set_window(3, 0.8)
	block.set_window(4, 0.5)
	assert_true(grid.live, "two lit")
	block.set_window(3, 0.0)
	assert_true(grid.live, "one still lit")
	block.set_window(4, 0.0)
	assert_true(not (grid.live), "none lit: the shader may skip the layer again")


func test_the_pixel_parameter_is_off_until_patched_and_its_wave_is_written_only_on_change() -> void:
	assert_eq(Show.identity_for(&"pixel"), Vector4(0, 0, 0, 1), "an unpatched pixel layer lights nothing")
	var show := Show.new()
	add_to_tree(show)
	var problem := show.load_patch({
		"channels": {"pix": {"programme": "breathe", "period": 12.0, "floor": 0.0, "ceiling": 0.4,
				"wave": {"row": -0.9, "scatter": 1.0, "jitter": 0.5}}},
		"patch": [{"fixture": "city_block", "parameter": "pixel", "channel": "pix"}]})
	assert_eq(problem, "", "a pixel patch loads with a floor of 0 (the layer is not a core surface)")
	var material := CityBlock.facade_material()
	show.add_fixture(&"city_block", material)
	assert_eq(material.get_shader_parameter("show_window_map"), show.window_grid().texture,
			"the block material samples the show's window grid")
	var first := show.apply(1.0)
	assert_eq(material.get_shader_parameter("show_pixel_wave"), Vector4(-0.9, 0.0, 1.0, 0.5), "the wave arrives")
	var second := show.apply(2.0)
	assert_true(second < first, "the wave and focus are not re-written every frame (%d then %d)" % [first, second])
	assert_eq(second, 1, "an idle frame is one write: the pixel channel itself")
	show.driving = false
	assert_eq(material.get_shader_parameter("show_pixel"), Vector4(0, 0, 0, 1), "off is the identity")


# --- the CPU-addressed effects: the capture fill and the facing facade -------------------------------------------

func test_the_capture_fill_climbs_the_nearest_block_floor_by_floor_then_goes_dark() -> void:
	var grid := ShowWindowGrid.new()
	var near := _block_with_grid(grid, Vector3(40, 0, 0), 0.0, 11)
	var far := _block_with_grid(grid, Vector3(-40, 0, 0), 180.0, 23)
	var effects := ShowWindowEffects.new()
	assert_eq(effects.start_fill(grid, Vector2(30, 5)), near.block_index, "the block nearest the objective fills")
	effects.advance(grid, 0.05)
	var rows := {}
	for i in near.window_count():
		var w: Dictionary = grid.windows[grid.index_of(near.block_index, i)]
		rows.get_or_add(int(w["row"]), []).append(grid.get_window(grid.index_of(near.block_index, i)))
	var order: Array = rows.keys()
	order.sort()
	assert_true(order.size() >= 3, "the block has storeys to climb (%d)" % order.size())
	assert_eq(rows[order[0]].max(), 1.0, "the lowest storey is lit first")
	assert_eq(rows[order[1]].max(), 0.0, "the one above is not yet")
	effects.advance(grid, float(order.size()) * ShowWindowEffects.FILL_STEP_S)
	for i in near.window_count():
		assert_eq(grid.get_window(grid.index_of(near.block_index, i)), 1.0, "every storey is lit at the top of the climb")
	for i in far.window_count():
		assert_eq(grid.get_window(grid.index_of(far.block_index, i)), 0.0, "the other block is untouched")
	effects.advance(grid, ShowWindowEffects.fill_life(order.size()))
	assert_true(not grid.live, "the fill fades to nothing")
	assert_eq(effects.fills.size(), 0, "and is forgotten")


func test_the_last_stand_facade_is_the_one_facing_the_losing_base() -> void:
	var grid := ShowWindowGrid.new()
	var block := _block_with_grid(grid, Vector3(0, 0, 0), 0.0, 11)
	var toward_south := ShowWindowEffects.facing_facade(grid, Vector2(0, -102))
	assert_eq(toward_south, Vector2i(block.block_index, 3), "a base at -z is faced by the -z facade")
	var toward_east := ShowWindowEffects.facing_facade(grid, Vector2(150, 5))
	assert_eq(toward_east, Vector2i(block.block_index, 0), "a point at +x is faced by the +x facade")


func test_a_capture_through_the_show_lights_the_map_and_arms_the_shader() -> void:
	var show := Show.new()
	add_to_tree(show)
	show.load_patch({"channels": {"pix": {"programme": "breathe", "period": 12.0, "floor": 0.0, "ceiling": 0.4}},
			"patch": [{"fixture": "city_block", "parameter": "pixel", "channel": "pix"}]})
	var material := CityBlock.facade_material()
	show.add_fixture(&"city_block", material)
	_block_with_grid(show.window_grid(), Vector3(40, 0, 0))
	show.apply(1.0)
	assert_eq((material.get_shader_parameter("show_pixel_focus") as Vector4).z, 0.0, "nothing in the map: layer idle")
	assert_true(show.fire_capture(Vector3(35, 0, 0)) >= 0, "the capture finds the block")
	show.apply(1.1, 0.1)
	assert_eq((material.get_shader_parameter("show_pixel_focus") as Vector4).z, 1.0, "the map is live")
	assert_true(show.window_grid().uploads > 0, "and uploaded")
	show.driving = false


func test_every_show_uniform_has_its_wave_uniform_named() -> void:
	for parameter: Variant in Show.UNIFORMS:
		var uniform: StringName = Show.UNIFORMS[parameter]
		assert_eq(Show.WAVE_UNIFORMS.get(uniform), StringName(str(uniform) + "_wave"),
				"%s has its wave spelled out (the per-frame loop looks it up)" % uniform)
