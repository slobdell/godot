extends TestCase
## Feel X1 (round 6): the arithmetic behind `make crowd-look`. The pictures themselves need a GPU (the make target).


func _flat(color: Color) -> Image:
	var image := Image.create(8, 4, false, Image.FORMAT_RGB8)
	image.fill(color)
	return image


func test_compare_counts_only_pixels_the_crowd_changed() -> void:
	var without := _flat(Color(0.1, 0.1, 0.1))
	var with_crowd := without.duplicate() as Image
	with_crowd.set_pixel(1, 1, Color(0.5, 0.5, 0.5))
	with_crowd.set_pixel(2, 1, Color(0.4, 0.4, 0.4))
	with_crowd.set_pixel(3, 1, Color(0.11, 0.11, 0.11))  # below CHANGED: noise, not a person
	var result := CrowdLook.compare(with_crowd, without, true)
	assert_eq(result["changed"], 2, "two pixels changed by more than %.2f" % CrowdLook.CHANGED)
	assert_near(float(result["contrast"]), 0.35, 0.01, "mean change (0.4 + 0.3) / 2")
	var marked: Image = result["marked"]
	assert_eq(marked.get_pixel(1, 1), Color(1, 0, 1), "the crowd's pixels are marked magenta")
	assert_true(marked.get_pixel(0, 0).r < 0.05, "everything else is darkened")
	assert_eq(CrowdLook.compare(without, without)["changed"], 0, "identical frames change nothing")


func test_pitched_pose_keeps_pitch_and_distance_apart() -> void:
	var at := Vector3(10, 0, 90)
	for pitch_deg in [22.0, 50.0]:
		for distance in [40.0, 160.0]:
			var pose := CrowdLook.pitched_pose(at, 0.0, deg_to_rad(pitch_deg), distance)
			assert_near(pose.origin.distance_to(at), distance, 0.01, "the camera sits %d m out" % distance)
			assert_near(rad_to_deg(-pose.basis.get_euler().x), pitch_deg, 0.01, "looking down at %d degrees" % pitch_deg)
			assert_true(pose.origin.z > at.z, "heading 0 puts the camera south of the focus, looking north")
