extends TestCase
## Arena item 3 (round 10; research C11): every Terminus street READS passable from the lead's camera -- at his
## default heading, the part of each lane's narrowest throat he can actually see is wider on screen than the widest
## hull there. The measurement is `LaneReadability`; the frames are `make remote T=terminus-streets`.


## Positive control (B12): a wall of containers between the camera and a throat must hide it.
func test_something_in_front_of_a_throat_hides_it() -> void:
	var data := {"name": "probe", "half_size": 120.0, "obstacles": [],
			"lanes": [{"name": "cross street", "points": [[-60.0, 0.0], [60.0, 0.0]], "width": 18.0}]}
	# A cross street (along x) between two long walls at z = -10 and z = +10; the camera sits south (+z), looking north.
	for z: float in [-30.0, 30.0]:
		data["obstacles"].append({"type": "wall", "position": [0.0, z], "size": [200.0, 3.0, 40.0], "rotation_deg": 0.0})
	var open: Dictionary = LaneReadability.measure(data)[0]
	var tall := data.duplicate(true)
	tall["obstacles"][1]["size"] = [200.0, 24.0, 40.0]  # the near wall becomes a block
	var hidden: Dictionary = LaneReadability.measure(tall)[0]
	# C11's rule: a foreground object of height h hides h / tan(21°) ≈ 2.6 h of ground behind it, so a 3 m wall on the
	# near kerb hides the near ~7.8 m of a 20 m throat: about 40%.
	assert_true(open["visible_fraction"] > 0.5 and open["visible_fraction"] < 0.75,
			"a 3 m wall on the near kerb hides the near part of the throat (%.2f visible)" % open["visible_fraction"])
	# A 2.8 m container (below the cutaway's 6 m) is cover, never cut: it hides MORE ground than the 3 m wall does not.
	var cover := data.duplicate(true)
	cover["obstacles"].append({"type": "container_40", "position": [0.0, 8.5], "size": [12.19, 5.18, 2.44], "rotation_deg": 0.0})
	var behind_cover: Dictionary = LaneReadability.measure(cover)[0]
	assert_true(behind_cover["visible_fraction"] < open["visible_fraction"] - 0.1,
			"a two-high container at the near kerb hides more (%.2f vs %.2f)" % [behind_cover["visible_fraction"], open["visible_fraction"]])
	# A 24 m building between the camera and the throat is cut away by BlockCutaway, so it hides NOTHING more.
	assert_true(hidden["visible_fraction"] >= open["visible_fraction"] - 0.01,
			"a block in the way is cut away (%.2f vs %.2f)" % [hidden["visible_fraction"], open["visible_fraction"]])


func test_every_terminus_street_reads_passable_at_his_default_heading() -> void:
	var data: Dictionary = Arena.load_layout("terminus")["layout"]
	var failures: PackedStringArray = []
	for row: Dictionary in LaneReadability.measure(data):
		print("LANE_READ terminus %-22s heading %5.1f  throat %.2f m = %4.0f px, %3.0f%% visible = %4.0f px, widest hull %3.0f px, margin %+4.0f px" % [
				row["name"], row["heading_deg"], row["throat_m"], row["throat_px"], row["visible_fraction"] * 100.0,
				row["visible_px"], row["hull_px"], row["margin_px"]])
		if row["margin_px"] <= 0.0:
			failures.append("%s (%+.0f px)" % [row["name"], row["margin_px"]])
	for row: Dictionary in LaneReadability.measure(data, 0.0, true):
		print("LANE_READ terminus %-22s along %5.1f    throat %.2f m = %4.0f px, %3.0f%% visible = %4.0f px, widest hull %3.0f px, margin %+4.0f px" % [
				row["name"], row["heading_deg"], row["throat_m"], row["throat_px"], row["visible_fraction"] * 100.0,
				row["visible_px"], row["hull_px"], row["margin_px"]])
	assert_true(failures.is_empty(), "every street's visible throat is wider than the widest hull on screen: %s" % ", ".join(failures))
