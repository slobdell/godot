extends TestCase
## Round 23 (orders O2, C23.4). The alert strip ("Bravo under fire   [Q]") clears whatever is below it: the chips the
## off-screen elements pin along the bottom edge (perf's round-22 frame at ten squads: India's chip under the strip),
## the group bar (round 22's rule, kept) and the selection panel (its header line at a phone aspect). Pure geometry,
## as EdgeMarkers draws it, at his window and at a phone's.

const Fixture := preload("res://tests/support/control_fixture.gd")
## [view, ui scale]: his 1854x1011 desktop window, and a 1800x810 phone aspect with `--ui-touch` (1.5x).
const SIZES := [[Vector2(1854, 1011), 1011.0 / 1080.0], [Vector2(1800, 810), 810.0 / 1080.0 * 1.5]]
## A long first line: "Bravo under fire  (+3)   [Q]" at 17 px is about this wide per unit of scale.
const LINE_PX := 420.0


func _strip(view: Vector2, s: float, floor_top: float) -> Rect2:
	var text := float(roundi(17.0 * s))
	var y := EdgeMarkers.alert_y(view.y, text, s, floor_top)
	return EdgeMarkers.strip_box(view.x, y, text, s, LINE_PX * s)


func test_the_strip_clears_a_chip_on_the_bottom_edge_at_both_aspects() -> void:
	for entry: Array in SIZES:
		var view: Vector2 = entry[0]
		var s := float(entry[1])
		var chip := EdgeMarkers.bottom_chip_box(view, s, view.x / 2.0)  # right under the strip's middle
		var before := _strip(view, s, -1.0)  # round 22's rule with nothing below: ALERT_Y of the view
		assert_true(before.intersects(chip), "%s: at ALERT_Y the strip sat on the chip (strip %s, chip %s)" % [view, before, chip])
		var after := _strip(view, s, EdgeMarkers.chip_band_top(view.y, s))
		assert_true(not after.intersects(chip.grow(1.5)), "%s: above the chips' band the strip and the chip (and its outline) do not touch (strip %s, chip %s)" % [view, after, chip])
		assert_true(chip.position.y - after.end.y >= EdgeMarkers.ALERT_GAP * s - 2.5,
				"%s: the gap between them is about ALERT_GAP (%.1f px)" % [view, chip.position.y - after.end.y])
		assert_true(after.position.y > view.y * 0.66, "%s: the strip is still in the lower third, not up over the fight (top %.0f of %.0f)" % [view, after.position.y, view.y])
		# A chip at either end of the edge is as high as the one under the strip's middle: the band is one line.
		for x in [0.0, view.x]:
			assert_eq(EdgeMarkers.bottom_chip_box(view, s, x).position.y, chip.position.y, "%s: the band is level at x = %.0f" % [view, x])


func test_the_strip_clears_the_selection_panel_top_and_the_group_bar() -> void:
	for entry: Array in SIZES:
		var view: Vector2 = entry[0]
		var s := float(entry[1])
		# A panel top ABOVE the chips' band (not the case at any size today: the floor rule must still hold it).
		var panel_top := EdgeMarkers.chip_band_top(view.y, s) - 30.0
		var strip := _strip(view, s, minf(EdgeMarkers.chip_band_top(view.y, s), panel_top))
		assert_true(strip.end.y <= panel_top - EdgeMarkers.ALERT_GAP * s + 0.01,
				"%s: the strip's box ends above the panel's header line (%.1f <= %.1f)" % [view, strip.end.y, panel_top])
		# A two-row bar's top, higher still: round 22's rule, kept.
		var bar_top := panel_top - 40.0
		strip = _strip(view, s, bar_top)
		assert_true(strip.end.y <= bar_top - EdgeMarkers.ALERT_GAP * s + 0.01, "%s: the strip clears the bar (%.1f)" % [view, strip.end.y])


## Through the controls: the strip's floor reads the chips' band, and the panel and bar when they are up.
func test_the_floor_is_the_chip_band_and_lower_than_the_bar_and_panel_when_shown() -> void:
	var f := Fixture.new(self)
	await f.build()
	var view := Vector2(f.markers.size)
	assert_true(view.y > 0.0, "setup: the markers cover the view (%s)" % view)
	var s := CyberStyle.ui_scale(view)
	f.controls.selection.clear()
	await tree.process_frame
	var floor_top: float = f.markers._floor_top(s)
	assert_near(floor_top, EdgeMarkers.chip_band_top(view.y, s), 0.01, "nothing selected: the chips' band is the floor")
	f.controls.recall_group(1)
	await tree.process_frame
	await tree.process_frame
	var bar := f.controls.get_node_or_null("GroupBar") as Control
	var panel := f.controls.get_node_or_null("SelectionPanel") as Control
	if bar == null or panel == null or not panel.visible:
		return  # the fixture has no panel or bar: the pure tests above cover the rule
	floor_top = f.markers._floor_top(s)
	assert_true(floor_top <= bar.get_global_rect().position.y + 0.01, "a squad selected: the strip is above the bar (%.1f)" % floor_top)
	assert_true(floor_top <= panel.get_global_rect().position.y + 0.01, "and above the panel (%.1f)" % floor_top)
	assert_true(floor_top <= EdgeMarkers.chip_band_top(view.y, s) + 0.01, "and above the chips' band (%.1f)" % floor_top)
